{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur Java -> fichiers .class (bytecode JVM)
}

{ ============================================================================
  DESCRIPTION
  ============================================================================
  JAVAC est un compilateur Java complet ecrit en Pascal. A partir d'un ou de
  plusieurs fichiers source (.java) il produit un fichier .class par classe
  (classes, interfaces, enums, records, classes imbriquees, locales et
  anonymes), que l'on peut executer avec la machine virtuelle Java
  ("java Classe").

  Usage :  JAVAC [options] fichier.java [fichier2.java ...]
  Options :
    -d repertoire      repertoire de sortie des fichiers .class
    -cp chemin         classpath : repertoires et archives .jar / .zip
    -p chemin          chemin des modules (--module-path), ajoute au classpath
    -target N          version de classe visee (8 a 25, defaut 11)
    --release N        synonyme de -target
    -verbose           affiche chaque fichier .class ecrit
    -g -nowarn -Xlint  (acceptes, ignores : LineNumberTable toujours generee)
    -help              affiche cette aide

  PHASES DU COMPILATEUR
  ---------------------
    1. Analyse lexicale    : source -> jetons (Tokens)         [Lex...]
       (Unicode, litteraux hexadecimaux et flottants hexadecimaux, blocs
       de texte, sequences d'echappement)
    2. Analyse syntaxique  : jetons -> arbre syntaxique (AST)  [Parse...]
       (Java 21 : generiques, lambdas, references de methode, records,
       enums, interfaces, switch expressions, motifs, var, blocs de texte)
    3. Analyse semantique  : symboles, types, portees, verification des
                             methodes, surcharge, inference des types
                             generiques, constantes, exceptions verifiees,
                             accessibilite des instructions, definitions
                             en double, variables non initialisees
                             [Enter... Attrib...]
    4. Desucrage           : for-each, try-with-resources, switch sur String,
                             enum et motifs, lambdas (invokedynamic), classes
                             internes / locales / anonymes (this$0, val$x),
                             enum (values, valueOf, $VALUES), records,
                             assert, varargs, boxing, concatenation de
                             chaines, methodes pont (bridge), initialiseurs
                             [Prepare... Gen...]
    5. Generation du bytecode JVM : instructions, StackMapTable complete
                             (verification de type), table des exceptions,
                             LineNumberTable                    [Emit... Gen...]
    6. Ecriture des fichiers .class : pool de constantes, champs, methodes,
                             attributs (SourceFile, InnerClasses, NestHost,
                             NestMembers, EnclosingMethod, BootstrapMethods,
                             Signature, Exceptions, Record, Deprecated,
                             Runtime[In]VisibleAnnotations, annotations de
                             parametres et de type (TYPE_USE), AnnotationDefault)
                                                                [CP... Write...]

  ANNOTATIONS, MODULES ET GRANDES METHODES
  ----------------------------------------
  - Annotations : elles sont analysees (type, elements, constantes, enums,
    classes, tableaux, annotations imbriquees, @Repeatable, @Target,
    @Retention, @Override) puis ecrites dans les .class selon leur retention.
  - module-info.java produit module-info.class (attribut Module : requires,
    exports, opens, uses, provides, open module).
  - Super-constructeur qualifie : outer.super(...) pour une super-classe interne.
  - Methodes dont un saut depasse 32 Ko : regeneration automatique avec
    goto_w et conditions inversees (limite JVM de 64 Ko de code).

  BIBLIOTHEQUE STANDARD
  ---------------------
  Une table interne de signatures (generee par reflexion depuis le JDK)
  decrit les ~300 classes les plus courantes de java.lang, java.util,
  java.io, java.util.function, java.util.stream, java.math, java.time... Les
  autres classes sont lues directement dans les fichiers .class : classpath
  (repertoires et archives jar, avec decompression Deflate) puis image des
  modules du JDK (lib/modules, trouvee par JAVA_HOME ou /usr/lib/jvm).
  Aucune unite autre que DOS n'est utilisee.
  ============================================================================ }

Program JAVAC;

{$A-}
{$I-}
{$B-}
{$Q-}
{$R-}

{$IFDEF FPC}
 {$MODE DELPHI}
 {$H+}
{$ENDIF}

Uses Dos;

Const
  VERSION = 'JAVAC V1.0 - compilateur Java vers bytecode JVM';

  { Drapeaux d'acces JVM }
  ACC_PUBLIC       = $0001;
  ACC_PRIVATE      = $0002;
  ACC_PROTECTED    = $0004;
  ACC_STATIC       = $0008;
  ACC_FINAL        = $0010;
  ACC_SYNCHRONIZED = $0020;
  ACC_SUPER        = $0020;
  ACC_VOLATILE     = $0040;
  ACC_BRIDGE       = $0040;
  ACC_TRANSIENT    = $0080;
  ACC_VARARGS      = $0080;
  ACC_NATIVE       = $0100;
  ACC_INTERFACE    = $0200;
  ACC_ABSTRACT     = $0400;
  ACC_STRICT       = $0800;
  ACC_SYNTHETIC    = $1000;
  ACC_ANNOTATION   = $2000;
  ACC_ENUM         = $4000;
  { Modificateurs internes (hors format .class) }
  MOD_DEFAULT      = $10000;   { methode "default" d'interface }
  MOD_SEALED       = $20000;
  MOD_RECORD       = $40000;
  MOD_LOCAL        = $80000;   { classe locale ou anonyme }
  MOD_ANON         = $100000;  { classe anonyme }
  MOD_NONSEALED    = $200000;

  { Genres de jetons }
  TK_EOF     = 0;
  TK_IDENT   = 1;
  TK_KEYWORD = 2;
  TK_INT     = 3;
  TK_LONG    = 4;
  TK_FLOAT   = 5;
  TK_DOUBLE  = 6;
  TK_CHAR    = 7;
  TK_STRING  = 8;
  TK_OP      = 9;

  { Genres de noeuds de l'arbre syntaxique }
  N_NONE       = 0;
  N_TYPE       = 1;    { type : S=nom, A=arguments, N=dimensions, Aux=1 primitif }
  N_WILD       = 2;    { ?, ? extends T, ? super T }
  N_TPARAM     = 3;    { parametre de type : S=nom, A=bornes }
  N_LIT        = 10;
  N_NAME       = 11;
  N_SELECT     = 12;
  N_CALL       = 13;
  N_NEW        = 14;
  N_NEWARRAY   = 15;
  N_ARRAYINIT  = 16;
  N_INDEX      = 17;
  N_UNARY      = 18;
  N_BINARY     = 19;
  N_ASSIGN     = 20;
  N_ASSIGNOP   = 21;
  N_COND       = 22;
  N_CAST       = 23;
  N_INSTANCEOF = 24;
  N_LAMBDA     = 25;
  N_METHODREF  = 26;
  N_THIS       = 27;
  N_SUPER      = 28;
  N_CLASSLIT   = 29;
  N_SWITCHEXPR = 30;
  N_CONV       = 31;   { conversion implicite ou explicite (cast) }
  N_OUTERTHIS  = 32;   { instance englobante : Sym=classe }
  N_LET        = 33;   { variable temporaire : A=N_VARDECL, B=expression }
  N_INDY       = 34;   { invokedynamic (lambda) }
  N_TYPEEXPR   = 35;   { nom de classe utilise comme qualifiant }
  N_STRCAT     = 36;   { concatenation de chaines a plat : A=operandes }
  N_PKGREF     = 37;   { prefixe de paquetage }
  N_BLOCK      = 50;
  N_LOCALVAR   = 51;
  N_VARDECL    = 52;
  N_EXPRSTMT   = 53;
  N_IF         = 54;
  N_WHILE      = 55;
  N_DO         = 56;
  N_FOR        = 57;
  N_FOREACH    = 58;
  N_RETURN     = 59;
  N_BREAK      = 60;
  N_CONTINUE   = 61;
  N_THROW      = 62;
  N_TRY        = 63;
  N_CATCH      = 64;
  N_SWITCH     = 65;
  N_CASE       = 66;
  N_LABELED    = 67;
  N_SYNC       = 68;
  N_ASSERT     = 69;
  N_EMPTY      = 70;
  N_LOCALCLASS = 71;
  N_YIELD      = 72;
  N_ANNOT      = 73;   { annotation : S=nom, A=elements (N_ANNARG), Sym=classe }
  N_MODULE     = 75;   { declaration de module : S=nom, Mods=1 si open, A=directives }
  N_DIRECTIVE  = 76;   { directive : S=genre, CS=nom principal, B=noms (to / with), Mods=indicateurs }
  N_ANNARG     = 74;   { element d'annotation : S=nom, A=valeur, Sym=methode }
  N_CU         = 80;
  N_IMPORT     = 81;
  N_CLASS      = 82;
  N_FIELD      = 83;
  N_METHOD     = 84;
  N_PARAM      = 85;
  N_INIT       = 86;
  N_ENUMCONST  = 87;
  N_PATTERN    = 88;   { motif : A=type, S=nom lie, B=sous-motifs (record), Aux=1 record }

  { Operateurs }
  OP_ADD = 1;  OP_SUB = 2;  OP_MUL = 3;  OP_DIV = 4;  OP_REM = 5;
  OP_SHL = 6;  OP_SHR = 7;  OP_USHR = 8;
  OP_LT = 9;   OP_GT = 10;  OP_LE = 11;  OP_GE = 12;  OP_EQ = 13; OP_NE = 14;
  OP_AND = 15; OP_OR = 16;  OP_XOR = 17; OP_LAND = 18; OP_LOR = 19;
  OP_NOT = 20; OP_COMPL = 21; OP_NEG = 22; OP_PLUS = 23;
  OP_PREINC = 24; OP_PREDEC = 25; OP_POSTINC = 26; OP_POSTDEC = 27;

  { Genres de constantes }
  CK_NONE = 0;  CK_INT = 1;  CK_LONG = 2;  CK_FLOAT = 3;  CK_DOUBLE = 4;
  CK_STR = 5;

  { Genres de litteraux (N_LIT.Aux) }
  LIT_INT = 1;  LIT_LONG = 2;  LIT_FLOAT = 3;  LIT_DOUBLE = 4;  LIT_CHAR = 5;
  LIT_STRING = 6;  LIT_BOOL = 7;  LIT_NULL = 8;

  { Genres de classes (N_CLASS.Aux) }
  CLS_CLASS = 0;  CLS_INTERFACE = 1;  CLS_ENUM = 2;  CLS_ANNOTATION = 3;
  CLS_RECORD = 4;

Type
  TToken = Record
    Kind : Byte;
    Line : LongInt;
    Str  : String;
    Num  : Int64;
    Dbl  : Double;
    Aux  : LongInt;     { base du litteral entier, ou 1 si debordement decimal }
    Adj  : Boolean;     { jeton colle au suivant (pour les '>') }
  End;

  TNode = Record
    Kind : Word;
    Line : LongInt;
    A, B, C, D, E, Next : LongInt;
    Mods : LongInt;
    Aux  : LongInt;
    N    : Int64;
    S    : String;
    Typ  : LongInt;
    Sym  : LongInt;
    Ann  : LongInt;     { annotations de la declaration (chaine de N_ANNOT) }
    Dflt : LongInt;     { valeur par defaut d'un element d'annotation }
    Att  : Byte;
    CK   : Byte;
    CI   : Int64;
    CD   : Double;
    CS   : String;
  End;

  TDblBits = Record
    Case Byte Of
      0 : (D : Double);
      1 : (I : Int64);
      2 : (S : Single; Dummy : LongInt);
      3 : (L : LongInt; H : LongInt);
  End;

Var
  { Etat global du compilateur }
  ErrCount   : LongInt;
  WarnCount  : LongInt;
  CurFile    : String;     { nom du fichier source en cours }
  OptVerbose : Boolean;
  OptOutDir  : String;
  OptTarget  : LongInt;    { version de classe (major) }
  OptDumpAst : Boolean;
  OptParseOnly : Boolean;
  OptModulePath : Boolean;  { --module-path donne : les modules inconnus ne sont pas des erreurs }

  { Source et jetons }
  Src        : String;
  SrcLen     : LongInt;
  Toks       : Array Of TToken;
  NToks      : LongInt;
  TokCap     : LongInt;
  P          : LongInt;    { index du jeton courant }

  { Arbre syntaxique }
  Nodes      : Array Of TNode;
  NNodes     : LongInt;

{ ============================================================================
  UTILITAIRES
  ============================================================================ }

Function IStr(V : Int64) : String;
Var S : String;
Begin
  Str(V, S);
  IStr := S;
End;

Function HexStr2(V : LongInt) : String;
Const Digs : String = '0123456789ABCDEF';
Begin
  HexStr2 := Digs[((V Shr 4) And 15) + 1] + Digs[(V And 15) + 1];
End;

Function IsDigit(C : Char) : Boolean;
Begin
  IsDigit := (C >= '0') And (C <= '9');
End;

Function IsIdStart(C : Char) : Boolean;
Begin
  IsIdStart := ((C >= 'a') And (C <= 'z')) Or ((C >= 'A') And (C <= 'Z')) Or
               (C = '_') Or (C = '$') Or (Ord(C) >= 128);
End;

Function IsIdChar(C : Char) : Boolean;
Begin
  IsIdChar := IsIdStart(C) Or IsDigit(C);
End;

Function HexVal(C : Char) : LongInt;
Begin
  If (C >= '0') And (C <= '9') Then HexVal := Ord(C) - 48
  Else If (C >= 'a') And (C <= 'f') Then HexVal := Ord(C) - 87
  Else If (C >= 'A') And (C <= 'F') Then HexVal := Ord(C) - 55
  Else HexVal := -1;
End;

Function FileExists(Const Fn : String) : Boolean;
Var F : File;
Begin
  Assign(F, Fn);
  Reset(F, 1);
  If IOResult = 0 Then Begin Close(F); FileExists := True; End
  Else FileExists := False;
  If IOResult <> 0 Then ;
End;

{ Remplace toutes les occurrences de Old par New dans S }
Function ReplaceAll(Const S, Old, New : String) : String;
Var R : String; I, L : LongInt;
Begin
  R := '';
  L := Length(Old);
  I := 1;
  While I <= Length(S) Do Begin
    If (L > 0) And (Copy(S, I, L) = Old) Then Begin
      R := R + New;
      Inc(I, L);
    End
    Else Begin
      R := R + S[I];
      Inc(I);
    End;
  End;
  ReplaceAll := R;
End;

Function LastPos(C : Char; Const S : String) : LongInt;
Var I : LongInt;
Begin
  I := Length(S);
  While (I > 0) And (S[I] <> C) Do Dec(I);
  LastPos := I;
End;

Function StartsWith(Const S, Prefix : String) : Boolean;
Begin
  StartsWith := Copy(S, 1, Length(Prefix)) = Prefix;
End;

{ Ajoute un point de code Unicode en "modified UTF-8" (format du .class) }
Procedure AppendMUtf8(Var S : String; Cp : LongInt);
Begin
  If Cp = 0 Then S := S + Chr($C0) + Chr($80)
  Else If Cp < $80 Then S := S + Chr(Cp)
  Else If Cp < $800 Then
    S := S + Chr($C0 Or (Cp Shr 6)) + Chr($80 Or (Cp And $3F))
  Else If Cp < $10000 Then
    S := S + Chr($E0 Or (Cp Shr 12)) + Chr($80 Or ((Cp Shr 6) And $3F)) +
             Chr($80 Or (Cp And $3F))
  Else Begin
    Cp := Cp - $10000;
    AppendMUtf8(S, $D800 + (Cp Shr 10));
    AppendMUtf8(S, $DC00 + (Cp And $3FF));
  End;
End;

{ Affiche la ligne de source fautive (relue depuis le fichier) }
Procedure ShowSrcLine(Const Fn : String; Line : LongInt);
Var F : Text; S : String; K : LongInt;
Begin
  If (Line <= 0) Or (Fn = '') Then Exit;
  Assign(F, Fn);
  Reset(F);
  If IOResult <> 0 Then Exit;
  K := 0;
  S := '';
  While (K < Line) And Not Eof(F) Do Begin
    ReadLn(F, S);
    Inc(K);
  End;
  Close(F);
  If K = Line Then WriteLn('    ', S);
  If IOResult <> 0 Then ;
End;

Procedure ErrSummary;
Begin
  If ErrCount = 1 Then WriteLn('1 erreur') Else WriteLn(ErrCount, ' erreurs');
End;

{ Erreurs et avertissements }
Procedure Err(Line : LongInt; Const Msg : String);
Begin
  If Line > 0 Then Begin
    WriteLn(CurFile, ':', Line, ': erreur: ', Msg);
    ShowSrcLine(CurFile, Line);
  End
  Else
    WriteLn(CurFile, ': erreur: ', Msg);
  Inc(ErrCount);
End;

Procedure Warn(Line : LongInt; Const Msg : String);
Begin
  WriteLn(CurFile, ':', Line, ': avertissement: ', Msg);
  Inc(WarnCount);
End;

Procedure Fatal(Line : LongInt; Const Msg : String);
Begin
  Err(Line, Msg);
  ErrSummary;
  Halt(1);
End;

Procedure Internal(Const Msg : String);
Begin
  WriteLn(CurFile, ': erreur interne: ', Msg);
  Halt(2);
End;

{ ============================================================================
  TABLE DE HACHAGE CHAINE -> ENTIER (internement)
  ============================================================================ }

Type
  TStrMap = Record
    Keys  : Array Of String;
    Vals  : Array Of LongInt;
    Nexts : Array Of LongInt;
    Heads : Array Of LongInt;
    Count : LongInt;
    HSize : LongInt;
  End;

Function StrHash(Const S : String) : LongInt;
Var I : LongInt; H : Int64;
Begin
  H := 5381;
  For I := 1 To Length(S) Do
    H := (H * 33 + Ord(S[I])) And $7FFFFFFF;
  StrHash := H;
End;

Procedure MapInit(Var M : TStrMap; HSize : LongInt);
Var I : LongInt;
Begin
  M.Count := 0;
  M.HSize := HSize;
  SetLength(M.Heads, HSize);
  For I := 0 To HSize - 1 Do M.Heads[I] := -1;
  SetLength(M.Keys, 0);
  SetLength(M.Vals, 0);
  SetLength(M.Nexts, 0);
End;

Function MapFind(Var M : TStrMap; Const K : String) : LongInt;
Var I : LongInt;
Begin
  MapFind := -1;
  If M.HSize = 0 Then Exit;
  I := M.Heads[StrHash(K) Mod M.HSize];
  While I >= 0 Do Begin
    If M.Keys[I] = K Then Begin MapFind := M.Vals[I]; Exit; End;
    I := M.Nexts[I];
  End;
End;

Procedure MapPut(Var M : TStrMap; Const K : String; V : LongInt);
Var H, I : LongInt;
Begin
  H := StrHash(K) Mod M.HSize;
  I := M.Heads[H];
  While I >= 0 Do Begin
    If M.Keys[I] = K Then Begin M.Vals[I] := V; Exit; End;
    I := M.Nexts[I];
  End;
  If M.Count >= Length(M.Keys) Then Begin
    SetLength(M.Keys, M.Count * 2 + 64);
    SetLength(M.Vals, M.Count * 2 + 64);
    SetLength(M.Nexts, M.Count * 2 + 64);
  End;
  M.Keys[M.Count] := K;
  M.Vals[M.Count] := V;
  M.Nexts[M.Count] := M.Heads[H];
  M.Heads[H] := M.Count;
  Inc(M.Count);
End;

{ ----- tampons d'octets ---------------------------------------------------- }

Type
  TBuf = Record
    D : Array Of Byte;
    N : LongInt;
  End;

Procedure BInit(Var B : TBuf);
Begin
  B.N := 0;
  If Length(B.D) = 0 Then SetLength(B.D, 256);
End;

Procedure BEnsure(Var B : TBuf; Extra : LongInt);
Begin
  If B.N + Extra > Length(B.D) Then SetLength(B.D, (B.N + Extra) * 2 + 64);
End;

Procedure B1(Var B : TBuf; V : LongInt);
Begin
  BEnsure(B, 1);
  B.D[B.N] := V And $FF;
  Inc(B.N);
End;

Procedure B2(Var B : TBuf; V : LongInt);
Begin
  BEnsure(B, 2);
  B.D[B.N] := (V Shr 8) And $FF;
  B.D[B.N + 1] := V And $FF;
  Inc(B.N, 2);
End;

Procedure B4(Var B : TBuf; V : Int64);
Begin
  BEnsure(B, 4);
  B.D[B.N] := (V Shr 24) And $FF;
  B.D[B.N + 1] := (V Shr 16) And $FF;
  B.D[B.N + 2] := (V Shr 8) And $FF;
  B.D[B.N + 3] := V And $FF;
  Inc(B.N, 4);
End;

Procedure B8(Var B : TBuf; V : Int64);
Begin
  B4(B, (V Shr 32) And $FFFFFFFF);
  B4(B, V And $FFFFFFFF);
End;

Procedure BStr(Var B : TBuf; Const S : String);
Var I : LongInt;
Begin
  BEnsure(B, Length(S));
  For I := 1 To Length(S) Do Begin
    B.D[B.N] := Ord(S[I]);
    Inc(B.N);
  End;
End;

Procedure BAppend(Var B : TBuf; Var Src : TBuf);
Var I : LongInt;
Begin
  BEnsure(B, Src.N);
  For I := 0 To Src.N - 1 Do B.D[B.N + I] := Src.D[I];
  Inc(B.N, Src.N);
End;

Procedure BPatch2(Var B : TBuf; Pos, V : LongInt);
Begin
  B.D[Pos] := (V Shr 8) And $FF;
  B.D[Pos + 1] := V And $FF;
End;

Procedure BPatch4(Var B : TBuf; Pos : LongInt; V : Int64);
Begin
  B.D[Pos] := (V Shr 24) And $FF;
  B.D[Pos + 1] := (V Shr 16) And $FF;
  B.D[Pos + 2] := (V Shr 8) And $FF;
  B.D[Pos + 3] := V And $FF;
End;

{ ============================================================================
  1. ANALYSE LEXICALE
  ============================================================================ }

Const
  NKEYWORDS = 53;
  KeywordTab : Array[1..NKEYWORDS] Of String[16] = (
    'abstract', 'assert', 'boolean', 'break', 'byte', 'case', 'catch', 'char',
    'class', 'const', 'continue', 'default', 'do', 'double', 'else', 'enum',
    'extends', 'final', 'finally', 'float', 'for', 'goto', 'if', 'implements',
    'import', 'instanceof', 'int', 'interface', 'long', 'native', 'new',
    'package', 'private', 'protected', 'public', 'return', 'short', 'static',
    'strictfp', 'super', 'switch', 'synchronized', 'this', 'throw', 'throws',
    'transient', 'try', 'void', 'volatile', 'while', 'true', 'false', 'null');

Function IsKeyword(Const S : String) : Boolean;
Var I : LongInt;
Begin
  IsKeyword := False;
  If (Length(S) < 2) Or (Length(S) > 12) Then Exit;
  For I := 1 To NKEYWORDS Do
    If KeywordTab[I] = S Then Begin IsKeyword := True; Exit; End;
End;

Procedure AddTok(Kind : Byte; Const S : String; Line : LongInt);
Begin
  If NToks >= TokCap Then Begin
    TokCap := TokCap * 2 + 1024;
    SetLength(Toks, TokCap);
  End;
  Toks[NToks].Kind := Kind;
  Toks[NToks].Line := Line;
  Toks[NToks].Str := S;
  Toks[NToks].Num := 0;
  Toks[NToks].Dbl := 0;
  Toks[NToks].Aux := 0;
  Toks[NToks].Adj := False;
  Inc(NToks);
End;

{ Decode un point de code UTF-8 a la position I de Src. Retourne sa longueur
  en octets. Un octet invalide est traite comme du Latin-1. }
Function DecodeUtf8(I : LongInt; Var Cp : LongInt) : LongInt;
Var B, N, K : LongInt;
Begin
  B := Ord(Src[I]);
  If B < $80 Then Begin Cp := B; DecodeUtf8 := 1; Exit; End;
  If (B And $E0) = $C0 Then Begin N := 1; Cp := B And $1F; End
  Else If (B And $F0) = $E0 Then Begin N := 2; Cp := B And $0F; End
  Else If (B And $F8) = $F0 Then Begin N := 3; Cp := B And $07; End
  Else Begin Cp := B; DecodeUtf8 := 1; Exit; End;
  If I + N > SrcLen Then Begin Cp := B; DecodeUtf8 := 1; Exit; End;
  For K := 1 To N Do Begin
    If (Ord(Src[I + K]) And $C0) <> $80 Then Begin
      Cp := B; DecodeUtf8 := 1; Exit;
    End;
    Cp := (Cp Shl 6) Or (Ord(Src[I + K]) And $3F);
  End;
  DecodeUtf8 := N + 1;
End;

{ Lit une sequence d'echappement a partir de Src[I] (apres la barre
  oblique inverse). Ajoute le resultat a S en modified UTF-8. }
Procedure LexEscape(Var I : LongInt; Var S : String; Line : LongInt);
Var C : Char; V, K, Cnt : LongInt;
Begin
  If I > SrcLen Then Begin Err(Line, 'sequence d''echappement invalide'); Exit; End;
  C := Src[I];
  Inc(I);
  Case C Of
    'n' : S := S + #10;
    't' : S := S + #9;
    'b' : S := S + #8;
    'r' : S := S + #13;
    'f' : S := S + #12;
    's' : S := S + ' ';
    '''' : S := S + '''';
    '"' : S := S + '"';
    '\' : S := S + '\';
    'u' : Begin
      While (I <= SrcLen) And (Src[I] = 'u') Do Inc(I);
      V := 0;
      For K := 1 To 4 Do Begin
        If (I > SrcLen) Or (HexVal(Src[I]) < 0) Then Begin
          Err(Line, 'sequence \u illegale'); Exit;
        End;
        V := V * 16 + HexVal(Src[I]);
        Inc(I);
      End;
      AppendMUtf8(S, V);
    End;
    '0'..'7' : Begin
      V := Ord(C) - 48;
      If C <= '3' Then Cnt := 2 Else Cnt := 1;
      While (Cnt > 0) And (I <= SrcLen) And (Src[I] >= '0') And (Src[I] <= '7') Do Begin
        V := V * 8 + Ord(Src[I]) - 48;
        Inc(I);
        Dec(Cnt);
      End;
      AppendMUtf8(S, V);
    End;
  Else
    Err(Line, 'caractere d''echappement illegal : \' + C);
  End;
End;

{ Bloc de texte """ ... """ : retire l'indentation commune }
Procedure LexTextBlock(Var I : LongInt; Var Line : LongInt);
Var
  Raw, Out, Ln : String;
  Lines : Array Of String;
  NL, K, J, Ind, MinInd, StartLine : LongInt;
  Done, Blank : Boolean;
Begin
  StartLine := Line;
  { saute les blancs jusqu'a la fin de ligne }
  While (I <= SrcLen) And (Src[I] In [' ', #9, #13]) Do Inc(I);
  If (I <= SrcLen) And (Src[I] = #10) Then Begin Inc(I); Inc(Line); End
  Else Err(Line, 'un bloc de texte doit commencer par une fin de ligne');
  Raw := '';
  Done := False;
  While (I <= SrcLen) And Not Done Do Begin
    If (Src[I] = '"') And (I + 2 <= SrcLen) And (Src[I + 1] = '"') And (Src[I + 2] = '"') Then Begin
      Inc(I, 3);
      Done := True;
    End
    Else If Src[I] = '\' Then Begin
      Raw := Raw + Src[I];
      Inc(I);
      If I <= SrcLen Then Begin
        If Src[I] = #10 Then Inc(Line);
        Raw := Raw + Src[I];
        Inc(I);
      End;
    End
    Else Begin
      If Src[I] = #10 Then Inc(Line);
      If Src[I] <> #13 Then Raw := Raw + Src[I];
      Inc(I);
    End;
  End;
  If Not Done Then Err(StartLine, 'bloc de texte non termine');
  { decoupe en lignes }
  SetLength(Lines, 0);
  NL := 0;
  Ln := '';
  For K := 1 To Length(Raw) Do Begin
    If Raw[K] = #10 Then Begin
      SetLength(Lines, NL + 1); Lines[NL] := Ln; Inc(NL); Ln := '';
    End
    Else Ln := Ln + Raw[K];
  End;
  SetLength(Lines, NL + 1); Lines[NL] := Ln; Inc(NL);
  { indentation minimale (la derniere ligne compte toujours) }
  MinInd := 100000;
  For K := 0 To NL - 1 Do Begin
    Ln := Lines[K];
    Blank := True;
    Ind := 0;
    For J := 1 To Length(Ln) Do
      If Not (Ln[J] In [' ', #9]) Then Begin Blank := False; Break; End
      Else Inc(Ind);
    If (Not Blank) Or (K = NL - 1) Then
      If Ind < MinInd Then MinInd := Ind;
  End;
  If MinInd = 100000 Then MinInd := 0;
  Out := '';
  For K := 0 To NL - 1 Do Begin
    Ln := Lines[K];
    If Length(Ln) >= MinInd Then Ln := Copy(Ln, MinInd + 1, Length(Ln))
    Else Ln := '';
    While (Length(Ln) > 0) And (Ln[Length(Ln)] In [' ', #9]) Do
      Delete(Ln, Length(Ln), 1);
    If K < NL - 1 Then Out := Out + Ln + #10
    Else Out := Out + Ln;
  End;
  { traite les echappements et convertit en modified UTF-8 }
  Raw := Out;
  Out := '';
  K := 1;
  While K <= Length(Raw) Do Begin
    If Raw[K] = '\' Then Begin
      Inc(K);
      If K <= Length(Raw) Then Begin
        If Raw[K] = #10 Then Inc(K)
        Else Begin
          { reutilise LexEscape sur une copie du source }
          Case Raw[K] Of
            'n' : Out := Out + #10;
            't' : Out := Out + #9;
            'b' : Out := Out + #8;
            'r' : Out := Out + #13;
            'f' : Out := Out + #12;
            's' : Out := Out + ' ';
            '"' : Out := Out + '"';
            '''' : Out := Out + '''';
            '\' : Out := Out + '\';
          Else
            Out := Out + Raw[K];
          End;
          Inc(K);
        End;
      End;
    End
    Else Begin
      Out := Out + Raw[K];
      Inc(K);
    End;
  End;
  AddTok(TK_STRING, Out, StartLine);
End;

Procedure LexNumber(Var I : LongInt; Line : LongInt);
Var
  S, T : String;
  IsFloat, IsHex, IsBin, IsOct : Boolean;
  Radix, K, Code : LongInt;
  U, Lim : QWord;
  D : Double;
  Sg : Single;
  Dg : LongInt;
  Suffix : Char;
  Big : Boolean;
  HexMant : Double; HexFrac, HexExp : LongInt; HexNeg : Boolean;
Begin
  S := '';
  IsFloat := False; IsHex := False; IsBin := False; IsOct := False;
  Radix := 10;
  If (Src[I] = '0') And (I < SrcLen) And (Src[I + 1] In ['x', 'X']) Then Begin
    IsHex := True; Radix := 16; Inc(I, 2);
    While (I <= SrcLen) And ((HexVal(Src[I]) >= 0) Or (Src[I] = '_')) Do Begin
      If Src[I] <> '_' Then S := S + Src[I];
      Inc(I);
    End;
    { litteral flottant hexadecimal : 0x1.8p3 }
    If (I <= SrcLen) And ((Src[I] = '.') Or (Src[I] In ['p', 'P'])) Then Begin
      HexMant := 0; HexFrac := 0;
      For K := 1 To Length(S) Do HexMant := HexMant * 16 + HexVal(S[K]);
      If Src[I] = '.' Then Begin
        Inc(I);
        While (I <= SrcLen) And ((HexVal(Src[I]) >= 0) Or (Src[I] = '_')) Do Begin
          If Src[I] <> '_' Then Begin HexMant := HexMant * 16 + HexVal(Src[I]); Inc(HexFrac, 4); End;
          Inc(I);
        End;
      End;
      HexExp := 0;
      If (I <= SrcLen) And (Src[I] In ['p', 'P']) Then Begin
        Inc(I);
        HexNeg := False;
        If (I <= SrcLen) And (Src[I] In ['+', '-']) Then Begin HexNeg := Src[I] = '-'; Inc(I); End;
        While (I <= SrcLen) And IsDigit(Src[I]) Do Begin HexExp := HexExp * 10 + Ord(Src[I]) - 48; Inc(I); End;
        If HexNeg Then HexExp := -HexExp;
      End
      Else Err(Line, 'exposant binaire attendu dans le litteral flottant hexadecimal');
      HexExp := HexExp - HexFrac;
      D := HexMant;
      While HexExp > 0 Do Begin D := D * 2; Dec(HexExp); End;
      While HexExp < 0 Do Begin D := D / 2; Inc(HexExp); End;
      Suffix := ' ';
      If (I <= SrcLen) And (Src[I] In ['f', 'F', 'd', 'D']) Then Begin Suffix := UpCase(Src[I]); Inc(I); End;
      If Suffix = 'F' Then Begin
        AddTok(TK_FLOAT, 'hexfloat', Line);
        Sg := D;
        Toks[NToks - 1].Dbl := Sg;
      End
      Else Begin
        AddTok(TK_DOUBLE, 'hexfloat', Line);
        Toks[NToks - 1].Dbl := D;
      End;
      Exit;
    End;
  End
  Else If (Src[I] = '0') And (I < SrcLen) And (Src[I + 1] In ['b', 'B']) Then Begin
    IsBin := True; Radix := 2; Inc(I, 2);
    While (I <= SrcLen) And (Src[I] In ['0', '1', '_']) Do Begin
      If Src[I] <> '_' Then S := S + Src[I];
      Inc(I);
    End;
  End
  Else Begin
    While (I <= SrcLen) And (IsDigit(Src[I]) Or (Src[I] = '_')) Do Begin
      If Src[I] <> '_' Then S := S + Src[I];
      Inc(I);
    End;
    If (I <= SrcLen) And (Src[I] = '.') And (I < SrcLen) And IsDigit(Src[I + 1]) Then Begin
      IsFloat := True;
      S := S + '.';
      Inc(I);
      While (I <= SrcLen) And (IsDigit(Src[I]) Or (Src[I] = '_')) Do Begin
        If Src[I] <> '_' Then S := S + Src[I];
        Inc(I);
      End;
    End
    Else If (I <= SrcLen) And (Src[I] = '.') And (S <> '') And
            ((I = SrcLen) Or Not (IsIdStart(Src[I + 1]) Or (Src[I + 1] = '.'))) Then Begin
      IsFloat := True;
      S := S + '.0';
      Inc(I);
    End;
    If (I <= SrcLen) And (Src[I] In ['e', 'E']) Then Begin
      IsFloat := True;
      S := S + 'e';
      Inc(I);
      If (I <= SrcLen) And (Src[I] In ['+', '-']) Then Begin S := S + Src[I]; Inc(I); End;
      While (I <= SrcLen) And IsDigit(Src[I]) Do Begin S := S + Src[I]; Inc(I); End;
    End;
  End;
  Suffix := ' ';
  If (I <= SrcLen) And (Src[I] In ['l', 'L', 'f', 'F', 'd', 'D']) And
     Not (IsHex And (Src[I] In ['f', 'F', 'd', 'D'])) Then Begin
    Suffix := UpCase(Src[I]);
    Inc(I);
  End;
  If (Not IsHex) And (Not IsBin) And (Not IsFloat) And (Length(S) > 1) And
     (S[1] = '0') And (Suffix In ['L', ' ']) Then Begin
    IsOct := True; Radix := 8; S := Copy(S, 2, Length(S));
  End;
  If Not IsFloat And (Suffix In ['F', 'D']) Then IsFloat := True;
  If IsFloat Then Begin
    If S = '' Then S := '0';
    If Suffix = 'F' Then Begin
      Val(S, Sg, Code);
      If Code <> 0 Then Err(Line, 'numero de type float illegal');
      AddTok(TK_FLOAT, S, Line);
      Toks[NToks - 1].Dbl := Sg;
    End
    Else Begin
      Val(S, D, Code);
      If Code <> 0 Then Err(Line, 'numero de type double illegal');
      AddTok(TK_DOUBLE, S, Line);
      Toks[NToks - 1].Dbl := D;
    End;
    Exit;
  End;
  { entier }
  If S = '' Then Begin Err(Line, 'numero illegal'); S := '0'; End;
  U := 0;
  Big := False;
  Lim := QWord($FFFFFFFFFFFFFFFF) Div QWord(Radix);
  For K := 1 To Length(S) Do Begin
    Dg := HexVal(S[K]);
    If (Dg < 0) Or (Dg >= Radix) Then Begin Err(Line, 'chiffre illegal dans un numero'); Break; End;
    If U > Lim Then Big := True;
    U := U * QWord(Radix) + QWord(Dg);
  End;
  If Suffix = 'L' Then Begin
    AddTok(TK_LONG, S, Line);
    If Radix = 10 Then Begin
      If Big Or (U > QWord($8000000000000000)) Then Err(Line, 'numero entier trop grand');
      If U = QWord($8000000000000000) Then Toks[NToks - 1].Aux := 1;
    End
    Else If Big Then Err(Line, 'numero entier trop grand');
    Toks[NToks - 1].Num := Int64(U);
    If Radix <> 10 Then Toks[NToks - 1].Aux := 0;
  End
  Else Begin
    AddTok(TK_INT, S, Line);
    If Radix = 10 Then Begin
      If Big Or (U > QWord(2147483648)) Then Err(Line, 'numero entier trop grand');
      If U = QWord(2147483648) Then Toks[NToks - 1].Aux := 1;
      Toks[NToks - 1].Num := Int64(U);
    End
    Else Begin
      If Big Or (U > QWord($FFFFFFFF)) Then Err(Line, 'numero entier trop grand');
      Toks[NToks - 1].Num := LongInt(U And $FFFFFFFF);
    End;
  End;
End;

Procedure Lex;
Var
  I, Line, Cp, L : LongInt;
  C : Char;
  S, Op : String;
  Start : LongInt;
  Closed : Boolean;
Begin
  NToks := 0;
  I := 1;
  Line := 1;
  While I <= SrcLen Do Begin
    C := Src[I];
    If C = #10 Then Begin Inc(Line); Inc(I); End
    Else If C In [' ', #9, #13, #12] Then Inc(I)
    Else If (C = '/') And (I < SrcLen) And (Src[I + 1] = '/') Then Begin
      While (I <= SrcLen) And (Src[I] <> #10) Do Inc(I);
    End
    Else If (C = '/') And (I < SrcLen) And (Src[I + 1] = '*') Then Begin
      Start := Line;
      Inc(I, 2);
      Closed := False;
      While I <= SrcLen Do Begin
        If (Src[I] = '*') And (I < SrcLen) And (Src[I + 1] = '/') Then Begin
          Inc(I, 2); Closed := True; Break;
        End;
        If Src[I] = #10 Then Inc(Line);
        Inc(I);
      End;
      If Not Closed Then Err(Start, 'commentaire non termine');
    End
    Else If IsIdStart(C) Then Begin
      Start := I;
      While (I <= SrcLen) And IsIdChar(Src[I]) Do Inc(I);
      S := Copy(Src, Start, I - Start);
      If IsKeyword(S) Then AddTok(TK_KEYWORD, S, Line)
      Else AddTok(TK_IDENT, S, Line);
    End
    Else If IsDigit(C) Or ((C = '.') And (I < SrcLen) And IsDigit(Src[I + 1])) Then
      LexNumber(I, Line)
    Else If C = '"' Then Begin
      If (I + 2 <= SrcLen) And (Src[I + 1] = '"') And (Src[I + 2] = '"') Then Begin
        Inc(I, 3);
        LexTextBlock(I, Line);
      End
      Else Begin
        Start := Line;
        Inc(I);
        S := '';
        Closed := False;
        While I <= SrcLen Do Begin
          C := Src[I];
          If C = '"' Then Begin Inc(I); Closed := True; Break; End;
          If C = #10 Then Break;
          If C = '\' Then Begin
            Inc(I);
            LexEscape(I, S, Line);
          End
          Else Begin
            L := DecodeUtf8(I, Cp);
            AppendMUtf8(S, Cp);
            Inc(I, L);
          End;
        End;
        If Not Closed Then Err(Start, 'literal de chaine non termine');
        AddTok(TK_STRING, S, Start);
      End;
    End
    Else If C = '''' Then Begin
      Inc(I);
      Cp := 0;
      If (I <= SrcLen) And (Src[I] = '\') Then Begin
        Inc(I);
        S := '';
        LexEscape(I, S, Line);
        { relit la valeur du code Unicode produit }
        If Length(S) = 1 Then Cp := Ord(S[1])
        Else If (Length(S) = 2) And (Ord(S[1]) = $C0) Then Cp := 0
        Else If Length(S) = 2 Then Cp := ((Ord(S[1]) And $1F) Shl 6) Or (Ord(S[2]) And $3F)
        Else If Length(S) = 3 Then
          Cp := ((Ord(S[1]) And $0F) Shl 12) Or ((Ord(S[2]) And $3F) Shl 6) Or (Ord(S[3]) And $3F);
      End
      Else If (I <= SrcLen) And (Src[I] <> '''') And (Src[I] <> #10) Then Begin
        L := DecodeUtf8(I, Cp);
        Inc(I, L);
        If Cp > $FFFF Then Err(Line, 'literal de caractere trop long');
      End
      Else Err(Line, 'literal de caractere vide');
      If (I <= SrcLen) And (Src[I] = '''') Then Inc(I)
      Else Err(Line, 'literal de caractere non termine');
      AddTok(TK_CHAR, '', Line);
      Toks[NToks - 1].Num := Cp;
    End
    Else Begin
      { operateurs et separateurs }
      Op := '';
      If I + 3 <= SrcLen Then
        If Copy(Src, I, 3) = '...' Then Op := '...'
        Else If Copy(Src, I, 3) = '<<=' Then Op := '<<=';
      If Op = '' Then Begin
        If I < SrcLen Then Begin
          S := Copy(Src, I, 2);
          If (S = '==') Or (S = '!=') Or (S = '<=') Or (S = '&&') Or (S = '||') Or
             (S = '++') Or (S = '--') Or (S = '+=') Or (S = '-=') Or (S = '*=') Or
             (S = '/=') Or (S = '&=') Or (S = '|=') Or (S = '^=') Or (S = '%=') Or
             (S = '<<') Or (S = '->') Or (S = '::') Or (S = '>=') Then Op := S;
        End;
      End;
      If Op = '' Then Begin
        If C In ['(', ')', '{', '}', '[', ']', ';', ',', '.', '@', '=', '>', '<', '!',
                 '~', '?', ':', '+', '-', '*', '/', '&', '|', '^', '%'] Then
          Op := C
        Else Begin
          Err(Line, 'caractere illegal : ''' + C + '''');
          Inc(I);
          Continue;
        End;
      End;
      { '>' est toujours isole sauf ">=" : le parseur recompose >> >>> >>= >>>= }
      AddTok(TK_OP, Op, Line);
      Inc(I, Length(Op));
      If Op = '>' Then
        If (I <= SrcLen) And ((Src[I] = '>') Or (Src[I] = '=')) Then Toks[NToks - 1].Adj := True;
    End;
  End;
  AddTok(TK_EOF, '<fin de fichier>', Line);
End;

{ ============================================================================
  2. ANALYSE SYNTAXIQUE : jetons -> arbre syntaxique (AST)
  ============================================================================ }

Function NewNode(Kind : Word; Line : LongInt) : LongInt;
Begin
  If NNodes >= Length(Nodes) Then SetLength(Nodes, Length(Nodes) * 2 + 4096);
  Nodes[NNodes].Kind := Kind;
  Nodes[NNodes].Line := Line;
  NewNode := NNodes;
  Inc(NNodes);
End;

{ Ajoute le noeud Item a la fin de la chaine dont la tete est Head et
  dont la queue est Tail (les deux sont mis a jour). }
Procedure AppendNode(Var Head, Tail : LongInt; Item : LongInt);
Begin
  If Item = 0 Then Exit;
  If Head = 0 Then Head := Item
  Else Nodes[Tail].Next := Item;
  Tail := Item;
  While Nodes[Tail].Next <> 0 Do Tail := Nodes[Tail].Next;
End;

Function ChainLen(N : LongInt) : LongInt;
Var K : LongInt;
Begin
  K := 0;
  While N <> 0 Do Begin Inc(K); N := Nodes[N].Next; End;
  ChainLen := K;
End;

Function ChainNth(N, K : LongInt) : LongInt;
Begin
  While (K > 0) And (N <> 0) Do Begin N := Nodes[N].Next; Dec(K); End;
  ChainNth := N;
End;

{ ---------------------------------------------------------------------------
  Acces aux jetons
  --------------------------------------------------------------------------- }

Function TokIdx(K : LongInt) : LongInt;
Begin
  If P + K >= NToks Then TokIdx := NToks - 1 Else TokIdx := P + K;
End;

Function IsOpAt(K : LongInt; Const S : String) : Boolean;
Var T : LongInt;
Begin
  T := TokIdx(K);
  IsOpAt := (Toks[T].Kind = TK_OP) And (Toks[T].Str = S);
End;

Function IsKwAt(K : LongInt; Const S : String) : Boolean;
Var T : LongInt;
Begin
  T := TokIdx(K);
  IsKwAt := (Toks[T].Kind = TK_KEYWORD) And (Toks[T].Str = S);
End;

Function IsIdentAt(K : LongInt) : Boolean;
Begin
  IsIdentAt := Toks[TokIdx(K)].Kind = TK_IDENT;
End;

Function IsIdentStr(K : LongInt; Const S : String) : Boolean;
Var T : LongInt;
Begin
  T := TokIdx(K);
  IsIdentStr := (Toks[T].Kind = TK_IDENT) And (Toks[T].Str = S);
End;

Function IsOp(Const S : String) : Boolean;
Begin IsOp := IsOpAt(0, S); End;

Function IsKw(Const S : String) : Boolean;
Begin IsKw := IsKwAt(0, S); End;

Function CurLine : LongInt;
Begin CurLine := Toks[TokIdx(0)].Line; End;

Procedure SyntaxErr(Const Msg : String);
Begin
  Fatal(CurLine, Msg);
End;

Procedure Expect(Const S : String);
Begin
  If IsOp(S) Then Inc(P)
  Else SyntaxErr('''' + S + ''' attendu');
End;

Procedure ExpectKw(Const S : String);
Begin
  If IsKw(S) Then Inc(P)
  Else SyntaxErr('''' + S + ''' attendu');
End;

Function Accept(Const S : String) : Boolean;
Begin
  If IsOp(S) Then Begin Inc(P); Accept := True; End
  Else Accept := False;
End;

Function AcceptKw(Const S : String) : Boolean;
Begin
  If IsKw(S) Then Begin Inc(P); AcceptKw := True; End
  Else AcceptKw := False;
End;

Function ExpectIdent : String;
Begin
  If Toks[TokIdx(0)].Kind = TK_IDENT Then Begin
    ExpectIdent := Toks[P].Str;
    Inc(P);
  End
  Else Begin
    SyntaxErr('<identificateur> attendu');
    ExpectIdent := '';
  End;
End;

Function IsPrimKw(K : LongInt) : Boolean;
Var S : String; T : LongInt;
Begin
  T := TokIdx(K);
  IsPrimKw := False;
  If Toks[T].Kind <> TK_KEYWORD Then Exit;
  S := Toks[T].Str;
  IsPrimKw := (S = 'int') Or (S = 'long') Or (S = 'boolean') Or (S = 'char') Or
              (S = 'byte') Or (S = 'short') Or (S = 'float') Or (S = 'double');
End;

{ ---------------------------------------------------------------------------
  Annotations (analysees puis ignorees)
  --------------------------------------------------------------------------- }

Procedure SkipBalanced(Const Open, Close : String);
Var Depth : LongInt;
Begin
  Depth := 0;
  Repeat
    If Toks[TokIdx(0)].Kind = TK_EOF Then SyntaxErr('fin de fichier inattendue');
    If IsOp(Open) Then Inc(Depth)
    Else If IsOp(Close) Then Dec(Depth);
    Inc(P);
  Until Depth = 0;
End;

Procedure SkipAnnotation;
Begin
  { P est sur '@' }
  Inc(P);
  ExpectIdent;
  While IsOp('.') And IsIdentAt(1) Do Begin Inc(P, 2); End;
  If IsOp('(') Then SkipBalanced('(', ')');
End;

Procedure SkipAnnotations;
Begin
  While IsOp('@') And Not IsKwAt(1, 'interface') Do SkipAnnotation;
End;

{ ---------------------------------------------------------------------------
  Anticipation (lookahead) sur les types
  --------------------------------------------------------------------------- }

Function SkipTypeArgsAt(Q : LongInt) : LongInt; Forward;

{ Retourne l'index du jeton suivant le type commencant en Q, ou -1 }
Function SkipTypeAt(Q : LongInt) : LongInt;
Var T : LongInt;
  Function Tk(K : LongInt) : LongInt;
  Begin
    If K >= NToks Then Tk := NToks - 1 Else Tk := K;
  End;
Begin
  SkipTypeAt := -1;
  While (Toks[Tk(Q)].Kind = TK_OP) And (Toks[Tk(Q)].Str = '@') Do Begin
    Inc(Q);
    If Toks[Tk(Q)].Kind <> TK_IDENT Then Exit;
    Inc(Q);
  End;
  T := Tk(Q);
  If Toks[T].Kind = TK_KEYWORD Then Begin
    If (Toks[T].Str = 'int') Or (Toks[T].Str = 'long') Or (Toks[T].Str = 'boolean') Or
       (Toks[T].Str = 'char') Or (Toks[T].Str = 'byte') Or (Toks[T].Str = 'short') Or
       (Toks[T].Str = 'float') Or (Toks[T].Str = 'double') Then Inc(Q)
    Else Exit;
  End
  Else If Toks[T].Kind = TK_IDENT Then Begin
    Inc(Q);
    While True Do Begin
      If (Toks[Tk(Q)].Kind = TK_OP) And (Toks[Tk(Q)].Str = '<') Then Begin
        Q := SkipTypeArgsAt(Q);
        If Q < 0 Then Exit;
      End;
      If (Toks[Tk(Q)].Kind = TK_OP) And (Toks[Tk(Q)].Str = '.') And
         (Toks[Tk(Q + 1)].Kind = TK_IDENT) Then Inc(Q, 2)
      Else Break;
    End;
  End
  Else Exit;
  While (Toks[Tk(Q)].Kind = TK_OP) And (Toks[Tk(Q)].Str = '[') And
        (Toks[Tk(Q + 1)].Kind = TK_OP) And (Toks[Tk(Q + 1)].Str = ']') Do Inc(Q, 2);
  SkipTypeAt := Q;
End;

Function SkipTypeArgsAt(Q : LongInt) : LongInt;
Begin
  SkipTypeArgsAt := -1;
  { Toks[Q] = '<' }
  Inc(Q);
  If (Toks[Q].Kind = TK_OP) And (Toks[Q].Str = '>') Then Begin
    SkipTypeArgsAt := Q + 1; Exit;
  End;
  While True Do Begin
    If (Toks[Q].Kind = TK_OP) And (Toks[Q].Str = '?') Then Begin
      Inc(Q);
      If (Toks[Q].Kind = TK_KEYWORD) And ((Toks[Q].Str = 'extends') Or (Toks[Q].Str = 'super')) Then Begin
        Inc(Q);
        Q := SkipTypeAt(Q);
        If Q < 0 Then Exit;
      End;
    End
    Else Begin
      Q := SkipTypeAt(Q);
      If Q < 0 Then Exit;
    End;
    If (Toks[Q].Kind = TK_OP) And (Toks[Q].Str = ',') Then Inc(Q)
    Else If (Toks[Q].Kind = TK_OP) And (Toks[Q].Str = '>') Then Begin
      SkipTypeArgsAt := Q + 1; Exit;
    End
    Else Exit;
  End;
End;

{ ---------------------------------------------------------------------------
  Types
  --------------------------------------------------------------------------- }

Function ParseType : LongInt; Forward;

Function ParseTypeArgs : LongInt;
Var Head, Tail, N, W : LongInt;
Begin
  { P est sur '<' ; retourne la chaine des arguments, ou -1 pour le diamant }
  Head := 0; Tail := 0;
  Expect('<');
  If IsOp('>') Then Begin Inc(P); ParseTypeArgs := -1; Exit; End;
  While True Do Begin
    SkipAnnotations;
    If IsOp('?') Then Begin
      W := NewNode(N_WILD, CurLine);
      Inc(P);
      If IsKw('extends') Then Begin
        Inc(P); Nodes[W].Aux := 1; Nodes[W].A := ParseType;
      End
      Else If IsKw('super') Then Begin
        Inc(P); Nodes[W].Aux := 2; Nodes[W].A := ParseType;
      End;
      N := W;
    End
    Else N := ParseType;
    AppendNode(Head, Tail, N);
    If Accept(',') Then Continue;
    Expect('>');
    Break;
  End;
  ParseTypeArgs := Head;
End;

Function ParseType : LongInt;
Var N, Args : LongInt; S : String;
Begin
  SkipAnnotations;
  N := NewNode(N_TYPE, CurLine);
  If IsPrimKw(0) Or IsKw('void') Then Begin
    Nodes[N].S := Toks[P].Str;
    Nodes[N].Aux := 1;
    Inc(P);
  End
  Else Begin
    S := ExpectIdent;
    While True Do Begin
      If IsOp('<') Then Begin
        Args := ParseTypeArgs;
        If Args = -1 Then Nodes[N].Mods := 1
        Else Nodes[N].A := Args;
      End;
      If IsOp('.') And IsIdentAt(1) Then Begin
        Inc(P);
        S := S + '.' + ExpectIdent;
        Nodes[N].A := 0;
      End
      Else Break;
    End;
    Nodes[N].S := S;
  End;
  While IsOp('[') And IsOpAt(1, ']') Do Begin
    Inc(P, 2);
    Inc(Nodes[N].N);
  End;
  ParseType := N;
End;

{ <T extends A & B, U> : retourne la chaine des N_TPARAM }
Function ParseTypeParams : LongInt;
Var Head, Tail, N, Hb, Tb : LongInt;
Begin
  Head := 0; Tail := 0;
  Expect('<');
  While True Do Begin
    SkipAnnotations;
    N := NewNode(N_TPARAM, CurLine);
    Nodes[N].S := ExpectIdent;
    If IsKw('extends') Then Begin
      Inc(P);
      Hb := 0; Tb := 0;
      AppendNode(Hb, Tb, ParseType);
      While Accept('&') Do AppendNode(Hb, Tb, ParseType);
      Nodes[N].A := Hb;
    End;
    AppendNode(Head, Tail, N);
    If Accept(',') Then Continue;
    Expect('>');
    Break;
  End;
  ParseTypeParams := Head;
End;

{ ---------------------------------------------------------------------------
  Expressions
  --------------------------------------------------------------------------- }

Var InCaseLabel : Boolean;

Function ParseExpr : LongInt; Forward;
Function ParseUnary : LongInt; Forward;
Function ParseBlock : LongInt; Forward;
Function ParseStatement : LongInt; Forward;
Function ParseClassDecl(Mods : LongInt) : LongInt; Forward;
Function ParseArrayInit : LongInt; Forward;
Function ParseSwitchBody(IsExpr : Boolean) : LongInt; Forward;
Function ParseLambdaFrom(Line : LongInt) : LongInt; Forward;
Procedure ParseClassBody(Cls : LongInt); Forward;
Function ParsePattern : LongInt; Forward;

Function MkName(Const S : String; Line : LongInt) : LongInt;
Var N : LongInt;
Begin
  N := NewNode(N_NAME, Line);
  Nodes[N].S := S;
  MkName := N;
End;

Function ParseArgs : LongInt;
Var Head, Tail : LongInt;
Begin
  Head := 0; Tail := 0;
  Expect('(');
  If Not IsOp(')') Then Begin
    While True Do Begin
      AppendNode(Head, Tail, ParseExpr);
      If Not Accept(',') Then Break;
    End;
  End;
  Expect(')');
  ParseArgs := Head;
End;

{ Le '(' courant ouvre-t-il une lambda ? }
Function IsLambdaParen : Boolean;
Var Q, Depth : LongInt;
Begin
  IsLambdaParen := False;
  Q := P;
  Depth := 0;
  While Q < NToks - 1 Do Begin
    If Toks[Q].Kind = TK_OP Then Begin
      If Toks[Q].Str = '(' Then Inc(Depth)
      Else If Toks[Q].Str = ')' Then Begin
        Dec(Depth);
        If Depth = 0 Then Begin
          IsLambdaParen := (Toks[Q + 1].Kind = TK_OP) And (Toks[Q + 1].Str = '->');
          Exit;
        End;
      End
      Else If (Toks[Q].Str = ';') Or (Toks[Q].Str = '{') Or (Toks[Q].Str = '}') Then Exit;
    End;
    Inc(Q);
  End;
End;

Function ParseLambdaFrom(Line : LongInt) : LongInt;
Var L, Head, Tail, Prm : LongInt;
Begin
  L := NewNode(N_LAMBDA, Line);
  Head := 0; Tail := 0;
  If IsOp('(') Then Begin
    Inc(P);
    If Not IsOp(')') Then Begin
      While True Do Begin
        Prm := NewNode(N_PARAM, CurLine);
        While IsKw('final') Or IsOp('@') Do
          If IsOp('@') Then SkipAnnotation Else Begin Inc(P); Nodes[Prm].Mods := Nodes[Prm].Mods Or ACC_FINAL; End;
        If IsIdentAt(0) And (IsOpAt(1, ',') Or IsOpAt(1, ')')) Then
          Nodes[Prm].S := ExpectIdent
        Else Begin
          Nodes[Prm].A := ParseType;
          If IsOp('.') And IsOpAt(1, '.') Then Inc(P, 2);
          Nodes[Prm].S := ExpectIdent;
        End;
        AppendNode(Head, Tail, Prm);
        If Not Accept(',') Then Break;
      End;
    End;
    Expect(')');
  End
  Else Begin
    Prm := NewNode(N_PARAM, CurLine);
    Nodes[Prm].S := ExpectIdent;
    AppendNode(Head, Tail, Prm);
  End;
  Expect('->');
  Nodes[L].A := Head;
  If IsOp('{') Then Nodes[L].B := ParseBlock
  Else Begin
    Nodes[L].B := ParseExpr;
    Nodes[L].Aux := 1;   { corps-expression }
  End;
  ParseLambdaFrom := L;
End;

Function ParseNewExpr(Outer : LongInt) : LongInt;
Var N, T, Dims, Head, Tail, E, Line : LongInt;
Begin
  Line := CurLine;
  ExpectKw('new');
  SkipAnnotations;
  T := NewNode(N_TYPE, CurLine);
  If IsPrimKw(0) Then Begin
    Nodes[T].S := Toks[P].Str; Nodes[T].Aux := 1; Inc(P);
  End
  Else Begin
    Nodes[T].S := ExpectIdent;
    While True Do Begin
      If IsOp('<') Then Begin
        E := ParseTypeArgs;
        If E = -1 Then Nodes[T].Mods := 1 Else Nodes[T].A := E;
      End;
      If IsOp('.') And IsIdentAt(1) Then Begin
        Inc(P);
        Nodes[T].S := Nodes[T].S + '.' + ExpectIdent;
        Nodes[T].A := 0;
      End
      Else Break;
    End;
  End;
  If IsOp('[') Then Begin
    N := NewNode(N_NEWARRAY, Line);
    Nodes[N].A := T;
    Head := 0; Tail := 0; Dims := 0;
    While IsOp('[') Do Begin
      Inc(P);
      If IsOp(']') Then Begin
        Inc(P); Inc(Dims);
      End
      Else Begin
        If Dims > Nodes[N].N Then SyntaxErr('dimension attendue');
        AppendNode(Head, Tail, ParseExpr);
        Expect(']');
        Inc(Dims);
        Nodes[N].N := Dims;
      End;
    End;
    Nodes[N].B := Head;
    Nodes[N].Aux := Dims;     { nombre total de dimensions }
    If IsOp('{') Then Nodes[N].C := ParseArrayInit;
    If (Nodes[N].B = 0) And (Nodes[N].C = 0) Then SyntaxErr('dimension ou initialiseur de tableau attendu');
    ParseNewExpr := N;
    Exit;
  End;
  N := NewNode(N_NEW, Line);
  Nodes[N].A := T;
  Nodes[N].D := Outer;
  Nodes[N].B := ParseArgs;
  If IsOp('{') Then Begin
    { classe anonyme }
    E := NewNode(N_CLASS, CurLine);
    Nodes[E].Mods := MOD_ANON Or MOD_LOCAL;
    Nodes[E].Aux := CLS_CLASS;
    Nodes[N].C := E;
    ParseClassBody(E);
  End;
  ParseNewExpr := N;
End;

Function ParseArrayInit : LongInt;
Var N, Head, Tail : LongInt;
Begin
  N := NewNode(N_ARRAYINIT, CurLine);
  Head := 0; Tail := 0;
  Expect('{');
  While Not IsOp('}') Do Begin
    If IsOp('{') Then AppendNode(Head, Tail, ParseArrayInit)
    Else AppendNode(Head, Tail, ParseExpr);
    If Not Accept(',') Then Break;
  End;
  Expect('}');
  Nodes[N].A := Head;
  ParseArrayInit := N;
End;

Function ParseLiteral : LongInt;
Var N : LongInt; T : TToken;
Begin
  T := Toks[P];
  N := NewNode(N_LIT, T.Line);
  Case T.Kind Of
    TK_INT : Begin
      Nodes[N].Aux := LIT_INT; Nodes[N].CK := CK_INT; Nodes[N].CI := T.Num;
      If T.Aux = 1 Then Nodes[N].Mods := 1;   { 2147483648 : valide seulement apres '-' }
    End;
    TK_LONG : Begin
      Nodes[N].Aux := LIT_LONG; Nodes[N].CK := CK_LONG; Nodes[N].CI := T.Num;
      If T.Aux = 1 Then Nodes[N].Mods := 1;
    End;
    TK_FLOAT : Begin
      Nodes[N].Aux := LIT_FLOAT; Nodes[N].CK := CK_FLOAT; Nodes[N].CD := T.Dbl;
    End;
    TK_DOUBLE : Begin
      Nodes[N].Aux := LIT_DOUBLE; Nodes[N].CK := CK_DOUBLE; Nodes[N].CD := T.Dbl;
    End;
    TK_CHAR : Begin
      Nodes[N].Aux := LIT_CHAR; Nodes[N].CK := CK_INT; Nodes[N].CI := T.Num;
    End;
    TK_STRING : Begin
      Nodes[N].Aux := LIT_STRING; Nodes[N].CK := CK_STR; Nodes[N].CS := T.Str;
    End;
  End;
  Inc(P);
  ParseLiteral := N;
End;

{ Les arguments de type d'un appel generique explicite sont ignores }
Procedure SkipExplicitTypeArgs;
Var X : LongInt;
Begin
  X := ParseTypeArgs;
End;

Function ParsePrimary : LongInt;
Var N, T, Line, Q, A : LongInt; S : String;
Begin
  Line := CurLine;
  Case Toks[TokIdx(0)].Kind Of
    TK_INT, TK_LONG, TK_FLOAT, TK_DOUBLE, TK_CHAR, TK_STRING : Begin
      ParsePrimary := ParseLiteral; Exit;
    End;
    TK_KEYWORD : Begin
      S := Toks[P].Str;
      If (S = 'true') Or (S = 'false') Then Begin
        N := NewNode(N_LIT, Line);
        Nodes[N].Aux := LIT_BOOL; Nodes[N].CK := CK_INT;
        If S = 'true' Then Nodes[N].CI := 1 Else Nodes[N].CI := 0;
        Inc(P);
        ParsePrimary := N; Exit;
      End;
      If S = 'null' Then Begin
        N := NewNode(N_LIT, Line);
        Nodes[N].Aux := LIT_NULL;
        Inc(P);
        ParsePrimary := N; Exit;
      End;
      If S = 'this' Then Begin
        Inc(P);
        If IsOp('(') Then Begin
          N := NewNode(N_CALL, Line);
          Nodes[N].S := 'this';
          Nodes[N].Aux := 1;      { appel de constructeur }
          Nodes[N].B := ParseArgs;
        End
        Else N := NewNode(N_THIS, Line);
        ParsePrimary := N; Exit;
      End;
      If S = 'super' Then Begin
        Inc(P);
        If IsOp('(') Then Begin
          N := NewNode(N_CALL, Line);
          Nodes[N].S := 'super';
          Nodes[N].Aux := 1;
          Nodes[N].B := ParseArgs;
        End
        Else If IsOp('::') Then N := NewNode(N_SUPER, Line)
        Else Begin
          N := NewNode(N_SUPER, Line);
          If Not IsOp('.') Then SyntaxErr('''.'' attendu');
        End;
        ParsePrimary := N; Exit;
      End;
      If S = 'new' Then Begin
        ParsePrimary := ParseNewExpr(0); Exit;
      End;
      If S = 'switch' Then Begin
        N := NewNode(N_SWITCHEXPR, Line);
        Inc(P);
        Expect('(');
        Nodes[N].A := ParseExpr;
        Expect(')');
        Nodes[N].B := ParseSwitchBody(True);
        ParsePrimary := N; Exit;
      End;
      If IsPrimKw(0) Or (S = 'void') Then Begin
        { int.class, int[].class, int[]::new }
        T := ParseType;
        If IsOp('::') Then Begin
          Inc(P);
          N := NewNode(N_METHODREF, Line);
          Nodes[N].A := T;
          Nodes[N].Aux := 1;     { A est un type }
          If IsKw('new') Then Begin Inc(P); Nodes[N].S := 'new'; End
          Else Nodes[N].S := ExpectIdent;
          ParsePrimary := N; Exit;
        End;
        Expect('.');
        ExpectKw('class');
        N := NewNode(N_CLASSLIT, Line);
        Nodes[N].A := T;
        ParsePrimary := N; Exit;
      End;
      SyntaxErr('expression illegale au debut : ' + S);
    End;
    TK_IDENT : Begin
      If IsOpAt(1, '->') And Not InCaseLabel Then Begin
        ParsePrimary := ParseLambdaFrom(Line); Exit;
      End;
      If IsOpAt(1, '(') Then Begin
        N := NewNode(N_CALL, Line);
        Nodes[N].S := Toks[P].Str;
        Inc(P);
        Nodes[N].B := ParseArgs;
        ParsePrimary := N; Exit;
      End;
      { type generique ou tableau suivi de :: ou .class }
      If IsOpAt(1, '<') Or (IsOpAt(1, '[') And IsOpAt(2, ']')) Then Begin
        Q := SkipTypeAt(P);
        If (Q > 0) And (Toks[Q].Kind = TK_OP) And (Toks[Q].Str = '::') Then Begin
          T := ParseType;
          Inc(P);   { :: }
          N := NewNode(N_METHODREF, Line);
          Nodes[N].A := T;
          Nodes[N].Aux := 1;
          If IsKw('new') Then Begin Inc(P); Nodes[N].S := 'new'; End
          Else Nodes[N].S := ExpectIdent;
          ParsePrimary := N; Exit;
        End;
        If IsOpAt(1, '[') And (Q > 0) And (Toks[Q].Kind = TK_OP) And (Toks[Q].Str = '.') And
           (Toks[Q + 1].Kind = TK_KEYWORD) And (Toks[Q + 1].Str = 'class') Then Begin
          T := ParseType;
          Inc(P, 2);
          N := NewNode(N_CLASSLIT, Line);
          Nodes[N].A := T;
          ParsePrimary := N; Exit;
        End;
      End;
      ParsePrimary := MkName(ExpectIdent, Line);
      Exit;
    End;
    TK_OP : Begin
      If IsOp('(') Then Begin
        If IsLambdaParen Then Begin
          ParsePrimary := ParseLambdaFrom(Line); Exit;
        End;
        Inc(P);
        N := ParseExpr;
        Expect(')');
        { conserve le groupement : marque pour distinguer (a)=.. }
        ParsePrimary := N; Exit;
      End;
      SyntaxErr('expression illegale au debut : ' + Toks[P].Str);
    End;
  Else
    SyntaxErr('expression attendue');
  End;
  ParsePrimary := 0;
End;

Function ExprDottedP(N : LongInt) : String;
Begin
  ExprDottedP := '';
  Case Nodes[N].Kind Of
    N_NAME : ExprDottedP := Nodes[N].S;
    N_SELECT : ExprDottedP := ExprDottedP(Nodes[N].A) + '.' + Nodes[N].S;
  End;
End;

Function ParsePostfix(N : LongInt) : LongInt;
Var M, Line : LongInt;
Begin
  While True Do Begin
    Line := CurLine;
    If IsOp('.') Then Begin
      Inc(P);
      If IsOp('<') Then Begin
        SkipExplicitTypeArgs;
        M := NewNode(N_CALL, Line);
        Nodes[M].A := N;
        Nodes[M].S := ExpectIdent;
        Nodes[M].B := ParseArgs;
        N := M;
      End
      Else If IsKw('new') Then Begin
        N := ParseNewExpr(N);
      End
      Else If IsKw('this') Then Begin
        Inc(P);
        M := NewNode(N_THIS, Line);
        Nodes[M].A := N;
        N := M;
      End
      Else If IsKw('class') Then Begin
        Inc(P);
        M := NewNode(N_CLASSLIT, Line);
        Nodes[M].A := N;
        Nodes[M].Aux := 1;     { A est une expression-nom }
        N := M;
      End
      Else If IsKw('super') Then Begin
        Inc(P);
        If IsOp('(') Then Begin
          M := NewNode(N_CALL, Line);
          Nodes[M].S := 'super';
          Nodes[M].Aux := 1;
          Nodes[M].D := N;
          Nodes[M].B := ParseArgs;
        End
        Else Begin
          M := NewNode(N_SUPER, Line);
          Nodes[M].A := N;
        End;
        N := M;
      End
      Else Begin
        If IsIdentAt(0) And IsOpAt(1, '(') Then Begin
          M := NewNode(N_CALL, Line);
          Nodes[M].A := N;
          Nodes[M].S := Toks[P].Str;
          Inc(P);
          Nodes[M].B := ParseArgs;
        End
        Else Begin
          M := NewNode(N_SELECT, Line);
          Nodes[M].A := N;
          Nodes[M].S := ExpectIdent;
        End;
        N := M;
      End;
    End
    Else If IsOp('[') And IsOpAt(1, ']') And (Nodes[N].Kind In [N_NAME, N_SELECT]) Then Begin
      { Type[].class ou Type[]::new avec un nom qualifie }
      M := NewNode(N_TYPE, Line);
      Nodes[M].S := ExprDottedP(N);
      While IsOp('[') And IsOpAt(1, ']') Do Begin Inc(P, 2); Inc(Nodes[M].N); End;
      If IsOp('::') Then Begin
        Inc(P);
        N := NewNode(N_METHODREF, Line);
        Nodes[N].A := M;
        Nodes[N].Aux := 1;
        If IsKw('new') Then Begin Inc(P); Nodes[N].S := 'new'; End
        Else Nodes[N].S := ExpectIdent;
      End
      Else Begin
        Expect('.');
        ExpectKw('class');
        N := NewNode(N_CLASSLIT, Line);
        Nodes[N].A := M;
      End;
    End
    Else If IsOp('[') Then Begin
      Inc(P);
      M := NewNode(N_INDEX, Line);
      Nodes[M].A := N;
      Nodes[M].B := ParseExpr;
      Expect(']');
      N := M;
    End
    Else If IsOp('++') Or IsOp('--') Then Begin
      M := NewNode(N_UNARY, Line);
      If IsOp('++') Then Nodes[M].Aux := OP_POSTINC Else Nodes[M].Aux := OP_POSTDEC;
      Nodes[M].A := N;
      Inc(P);
      N := M;
    End
    Else If IsOp('::') Then Begin
      Inc(P);
      M := NewNode(N_METHODREF, Line);
      Nodes[M].A := N;
      If IsKw('new') Then Begin Inc(P); Nodes[M].S := 'new'; End
      Else Begin
        If IsOp('<') Then SkipExplicitTypeArgs;
        Nodes[M].S := ExpectIdent;
      End;
      N := M;
    End
    Else Break;
  End;
  ParsePostfix := N;
End;

{ Le '(' courant commence-t-il une conversion de type (cast) ? }
Function IsCastParen : Boolean;
Var Q : LongInt;
Begin
  IsCastParen := False;
  If IsPrimKw(1) Then Begin
    Q := SkipTypeAt(P + 1);
    IsCastParen := (Q > 0) And (Toks[Q].Kind = TK_OP) And (Toks[Q].Str = ')');
    Exit;
  End;
  If Not IsIdentAt(1) Then Exit;
  Q := SkipTypeAt(P + 1);
  { intersection de types : (A & B) }
  While (Q > 0) And (Toks[Q].Kind = TK_OP) And (Toks[Q].Str = '&') Do Q := SkipTypeAt(Q + 1);
  If (Q < 0) Or Not ((Toks[Q].Kind = TK_OP) And (Toks[Q].Str = ')')) Then Exit;
  Inc(Q);
  Case Toks[Q].Kind Of
    TK_IDENT, TK_INT, TK_LONG, TK_FLOAT, TK_DOUBLE, TK_CHAR, TK_STRING : IsCastParen := True;
    TK_KEYWORD : IsCastParen := (Toks[Q].Str = 'this') Or (Toks[Q].Str = 'new') Or
       (Toks[Q].Str = 'super') Or (Toks[Q].Str = 'true') Or (Toks[Q].Str = 'false') Or
       (Toks[Q].Str = 'null') Or (Toks[Q].Str = 'switch') Or
       (Toks[Q].Str = 'int') Or (Toks[Q].Str = 'long') Or (Toks[Q].Str = 'double') Or
       (Toks[Q].Str = 'char') Or (Toks[Q].Str = 'boolean') Or (Toks[Q].Str = 'byte') Or
       (Toks[Q].Str = 'short') Or (Toks[Q].Str = 'float');
    TK_OP : IsCastParen := (Toks[Q].Str = '(') Or (Toks[Q].Str = '!') Or (Toks[Q].Str = '~');
  End;
End;

Function ParseUnary : LongInt;
Var N, Line, T, M : LongInt; Op : LongInt;
Begin
  Line := CurLine;
  If IsOp('+') Or IsOp('-') Or IsOp('!') Or IsOp('~') Or IsOp('++') Or IsOp('--') Then Begin
    If IsOp('+') Then Op := OP_PLUS
    Else If IsOp('-') Then Op := OP_NEG
    Else If IsOp('!') Then Op := OP_NOT
    Else If IsOp('~') Then Op := OP_COMPL
    Else If IsOp('++') Then Op := OP_PREINC
    Else Op := OP_PREDEC;
    Inc(P);
    { -2147483648 et -9223372036854775808 }
    If (Op = OP_NEG) And ((Toks[TokIdx(0)].Kind = TK_INT) Or (Toks[TokIdx(0)].Kind = TK_LONG)) And
       (Toks[TokIdx(0)].Aux = 1) Then Begin
      N := ParseLiteral;
      Nodes[N].Mods := 0;
      If Nodes[N].Aux = LIT_INT Then Nodes[N].CI := -2147483648
      Else Nodes[N].CI := Low(Int64);
      ParseUnary := ParsePostfix(N);
      Exit;
    End;
    N := NewNode(N_UNARY, Line);
    Nodes[N].Aux := Op;
    Nodes[N].A := ParseUnary;
    ParseUnary := N;
    Exit;
  End;
  If IsOp('(') And Not IsLambdaParen And IsCastParen Then Begin
    Inc(P);
    N := NewNode(N_CAST, Line);
    T := ParseType;
    While Accept('&') Do M := ParseType;     { cast d'intersection : seul le premier type compte }
    Nodes[N].A := T;
    Expect(')');
    Nodes[N].B := ParseUnary;
    ParseUnary := N;
    Exit;
  End;
  N := ParsePrimary;
  ParseUnary := ParsePostfix(N);
End;

Function BinOpAt(Var Len : LongInt) : LongInt;
{ Reconnait l'operateur binaire au jeton courant ; Len = nombre de jetons }
Var S : String;
Begin
  Len := 1;
  BinOpAt := 0;
  If Toks[TokIdx(0)].Kind <> TK_OP Then Begin
    If IsKw('instanceof') Then BinOpAt := -1;
    Exit;
  End;
  S := Toks[P].Str;
  If S = '+' Then BinOpAt := OP_ADD
  Else If S = '-' Then BinOpAt := OP_SUB
  Else If S = '*' Then BinOpAt := OP_MUL
  Else If S = '/' Then BinOpAt := OP_DIV
  Else If S = '%' Then BinOpAt := OP_REM
  Else If S = '<<' Then BinOpAt := OP_SHL
  Else If S = '<' Then BinOpAt := OP_LT
  Else If S = '<=' Then BinOpAt := OP_LE
  Else If S = '>=' Then BinOpAt := OP_GE
  Else If S = '>' Then Begin
    If Toks[P].Adj And IsOpAt(1, '>') Then Begin
      If Toks[P + 1].Adj And IsOpAt(2, '>') Then Begin
        { >>> sauf si suivi de '>=' : alors >>>= }
        Len := 3; BinOpAt := OP_USHR;
      End
      Else If Toks[P + 1].Adj And IsOpAt(2, '>=') Then BinOpAt := 0
      Else Begin Len := 2; BinOpAt := OP_SHR; End;
    End
    Else If Toks[P].Adj And IsOpAt(1, '>=') Then BinOpAt := 0
    Else BinOpAt := OP_GT;
  End
  Else If S = '==' Then BinOpAt := OP_EQ
  Else If S = '!=' Then BinOpAt := OP_NE
  Else If S = '&' Then BinOpAt := OP_AND
  Else If S = '|' Then BinOpAt := OP_OR
  Else If S = '^' Then BinOpAt := OP_XOR
  Else If S = '&&' Then BinOpAt := OP_LAND
  Else If S = '||' Then BinOpAt := OP_LOR;
End;

Function BinPrec(Op : LongInt) : LongInt;
Begin
  Case Op Of
    OP_LOR : BinPrec := 1;
    OP_LAND : BinPrec := 2;
    OP_OR : BinPrec := 3;
    OP_XOR : BinPrec := 4;
    OP_AND : BinPrec := 5;
    OP_EQ, OP_NE : BinPrec := 6;
    OP_LT, OP_GT, OP_LE, OP_GE, -1 : BinPrec := 7;
    OP_SHL, OP_SHR, OP_USHR : BinPrec := 8;
    OP_ADD, OP_SUB : BinPrec := 9;
    OP_MUL, OP_DIV, OP_REM : BinPrec := 10;
  Else
    BinPrec := 0;
  End;
End;

Function ParseBinary(MinPrec : LongInt) : LongInt;
Var Lhs, Rhs, N, Op, Len, Prec, Line, V, Q : LongInt;
Begin
  Lhs := ParseUnary;
  While True Do Begin
    Op := BinOpAt(Len);
    If Op = 0 Then Break;
    Prec := BinPrec(Op);
    If Prec < MinPrec Then Break;
    Line := CurLine;
    If Op = -1 Then Begin
      { instanceof [final] Type [ident] }
      Inc(P);
      N := NewNode(N_INSTANCEOF, Line);
      Nodes[N].A := Lhs;
      AcceptKw('final');
      Q := SkipTypeAt(P);
      If (Q > 0) And (Toks[Q].Kind = TK_OP) And (Toks[Q].Str = '(') Then Begin
        { motif record : x instanceof Point(int a, int b) }
        Nodes[N].C := ParsePattern;
        Nodes[N].Aux := 1;
        Nodes[N].B := Nodes[Nodes[N].C].A;
      End
      Else Begin
        Nodes[N].B := ParseType;
        If IsIdentAt(0) And Not IsIdentStr(0, 'when') Then Begin
          V := NewNode(N_VARDECL, CurLine);
          Nodes[V].S := ExpectIdent;
          Nodes[N].C := V;
        End;
      End;
      Lhs := N;
      Continue;
    End;
    Inc(P, Len);
    Rhs := ParseBinary(Prec + 1);
    N := NewNode(N_BINARY, Line);
    Nodes[N].Aux := Op;
    Nodes[N].A := Lhs;
    Nodes[N].B := Rhs;
    Lhs := N;
  End;
  ParseBinary := Lhs;
End;

Function ParseTernary : LongInt;
Var C, N, Line : LongInt;
Begin
  C := ParseBinary(1);
  If IsOp('?') Then Begin
    Line := CurLine;
    Inc(P);
    N := NewNode(N_COND, Line);
    Nodes[N].A := C;
    Nodes[N].B := ParseExpr;
    Expect(':');
    Nodes[N].C := ParseTernary;
    ParseTernary := N;
    Exit;
  End;
  ParseTernary := C;
End;

Function AssignOpAt(Var Len : LongInt) : LongInt;
{ retourne 0 si pas d'affectation, -1 pour '=', sinon l'operateur compose }
Var S : String;
Begin
  Len := 1;
  AssignOpAt := 0;
  If Toks[TokIdx(0)].Kind <> TK_OP Then Exit;
  S := Toks[P].Str;
  If S = '=' Then AssignOpAt := -1
  Else If S = '+=' Then AssignOpAt := OP_ADD
  Else If S = '-=' Then AssignOpAt := OP_SUB
  Else If S = '*=' Then AssignOpAt := OP_MUL
  Else If S = '/=' Then AssignOpAt := OP_DIV
  Else If S = '%=' Then AssignOpAt := OP_REM
  Else If S = '&=' Then AssignOpAt := OP_AND
  Else If S = '|=' Then AssignOpAt := OP_OR
  Else If S = '^=' Then AssignOpAt := OP_XOR
  Else If S = '<<=' Then AssignOpAt := OP_SHL
  Else If (S = '>') And Toks[P].Adj And IsOpAt(1, '>=') Then Begin
    Len := 2; AssignOpAt := OP_SHR;
  End
  Else If (S = '>') And Toks[P].Adj And IsOpAt(1, '>') And Toks[P + 1].Adj And IsOpAt(2, '>=') Then Begin
    Len := 3; AssignOpAt := OP_USHR;
  End;
End;

Function ParseExpr : LongInt;
Var Lhs, N, Op, Len, Line : LongInt;
Begin
  Lhs := ParseTernary;
  Op := AssignOpAt(Len);
  If Op <> 0 Then Begin
    Line := CurLine;
    Inc(P, Len);
    If Op = -1 Then N := NewNode(N_ASSIGN, Line)
    Else Begin
      N := NewNode(N_ASSIGNOP, Line);
      Nodes[N].Aux := Op;
    End;
    Nodes[N].A := Lhs;
    Nodes[N].B := ParseExpr;
    ParseExpr := N;
    Exit;
  End;
  ParseExpr := Lhs;
End;

{ ---------------------------------------------------------------------------
  switch (instruction et expression)
  --------------------------------------------------------------------------- }

{ Un motif commence-t-il ici : Type ident, ou Type( ... ) ? }
Function IsPatternStart : Boolean;
Var Q : LongInt;
Begin
  IsPatternStart := False;
  If Not (IsIdentAt(0) Or IsPrimKw(0)) Then Exit;
  Q := SkipTypeAt(P);
  If Q < 0 Then Exit;
  If Toks[Q].Kind = TK_IDENT Then
    IsPatternStart := True
  Else If (Toks[Q].Kind = TK_OP) And (Toks[Q].Str = '(') And IsIdentAt(0) Then
    IsPatternStart := True;
End;

Function ParsePattern : LongInt;
Var N, T, Hd, Tl : LongInt;
Begin
  N := NewNode(N_PATTERN, CurLine);
  While IsKw('final') Do Inc(P);
  T := ParseType;
  Nodes[N].A := T;
  If IsOp('(') Then Begin
    Inc(P);
    Nodes[N].Aux := 1;
    Hd := 0; Tl := 0;
    If Not IsOp(')') Then Begin
      While True Do Begin
        AppendNode(Hd, Tl, ParsePattern);
        If Not Accept(',') Then Break;
      End;
    End;
    Expect(')');
    Nodes[N].B := Hd;
    If IsIdentAt(0) And Not IsIdentStr(0, 'when') Then Nodes[N].S := ExpectIdent;
  End
  Else If IsIdentAt(0) Then Nodes[N].S := ExpectIdent;
  ParsePattern := N;
End;

Function ParseSwitchBody(IsExpr : Boolean) : LongInt;
Var
  Head, Tail, C, LH, LT, SH, ST, S, Y, Line : LongInt;
  Arrow : Boolean;
Begin
  Head := 0; Tail := 0;
  Expect('{');
  While Not IsOp('}') Do Begin
    Line := CurLine;
    C := NewNode(N_CASE, Line);
    LH := 0; LT := 0;
    If IsKw('default') Then Begin
      Inc(P);
      Nodes[C].Aux := 1;
    End
    Else Begin
      ExpectKw('case');
      While True Do Begin
        If IsKw('default') Then Begin
          Inc(P); Nodes[C].Aux := Nodes[C].Aux Or 1;
        End
        Else If IsPatternStart Then AppendNode(LH, LT, ParsePattern)
        Else Begin
          InCaseLabel := True;
          AppendNode(LH, LT, ParseTernary);
          InCaseLabel := False;
        End;
        If Not Accept(',') Then Break;
      End;
    End;
    Nodes[C].A := LH;
    If IsIdentStr(0, 'when') Then Begin
      Inc(P);
      InCaseLabel := True;
      Nodes[C].E := ParseTernary;
      InCaseLabel := False;
    End;
    If IsOp('->') Then Begin
      Inc(P);
      Nodes[C].Aux := Nodes[C].Aux Or 2;
      If IsOp('{') Then Nodes[C].B := ParseBlock
      Else If IsKw('throw') Then Nodes[C].B := ParseStatement
      Else Begin
        S := ParseExpr;
        Expect(';');
        If IsExpr Then Begin
          Y := NewNode(N_YIELD, Nodes[S].Line);
          Nodes[Y].A := S;
          Nodes[C].B := Y;
        End
        Else Begin
          Y := NewNode(N_EXPRSTMT, Nodes[S].Line);
          Nodes[Y].A := S;
          Nodes[C].B := Y;
        End;
      End;
    End
    Else Begin
      Expect(':');
      SH := 0; ST := 0;
      While Not (IsKw('case') Or IsKw('default') Or IsOp('}')) Do
        AppendNode(SH, ST, ParseStatement);
      Nodes[C].B := SH;
    End;
    AppendNode(Head, Tail, C);
  End;
  Expect('}');
  ParseSwitchBody := Head;
End;

{ ---------------------------------------------------------------------------
  Instructions
  --------------------------------------------------------------------------- }

Function ParseBlock : LongInt;
Var N, Head, Tail : LongInt;
Begin
  N := NewNode(N_BLOCK, CurLine);
  Head := 0; Tail := 0;
  Expect('{');
  While Not IsOp('}') Do Begin
    If Toks[TokIdx(0)].Kind = TK_EOF Then SyntaxErr('fin de fichier inattendue (''}'' manquant)');
    AppendNode(Head, Tail, ParseStatement);
  End;
  Expect('}');
  Nodes[N].A := Head;
  ParseBlock := N;
End;

{ Le jeton courant commence-t-il une declaration de variable locale ? }
Function IsLocalVarDecl : Boolean;
Var Q : LongInt;
Begin
  IsLocalVarDecl := False;
  If IsPrimKw(0) Then Begin
    Q := SkipTypeAt(P);
    IsLocalVarDecl := (Q > 0) And (Toks[Q].Kind = TK_IDENT);
    Exit;
  End;
  If Not IsIdentAt(0) Then Exit;
  Q := SkipTypeAt(P);
  If (Q > 0) And (Toks[Q].Kind = TK_IDENT) Then
    IsLocalVarDecl := (Toks[Q + 1].Kind = TK_OP) And
      ((Toks[Q + 1].Str = '=') Or (Toks[Q + 1].Str = ';') Or (Toks[Q + 1].Str = ',') Or
       (Toks[Q + 1].Str = ':') Or (Toks[Q + 1].Str = '['));
End;

{ Declarateurs : a = 1, b[] = init, c ; le type TypeNode est partage }
Function ParseDeclarators(TypeNode : LongInt; Mods : LongInt) : LongInt;
Var Head, Tail, V : LongInt;
Begin
  Head := 0; Tail := 0;
  While True Do Begin
    V := NewNode(N_VARDECL, CurLine);
    Nodes[V].S := ExpectIdent;
    Nodes[V].Mods := Mods;
    While IsOp('[') And IsOpAt(1, ']') Do Begin Inc(P, 2); Inc(Nodes[V].N); End;
    If Accept('=') Then Begin
      If IsOp('{') Then Nodes[V].A := ParseArrayInit
      Else Nodes[V].A := ParseExpr;
    End;
    AppendNode(Head, Tail, V);
    If Not Accept(',') Then Break;
  End;
  ParseDeclarators := Head;
End;

Function ParseLocalVarDecl(Mods : LongInt) : LongInt;
Var N, T : LongInt;
Begin
  N := NewNode(N_LOCALVAR, CurLine);
  T := ParseType;
  Nodes[N].A := T;
  Nodes[N].Mods := Mods;
  Nodes[N].B := ParseDeclarators(T, Mods);
  ParseLocalVarDecl := N;
End;

Function ParseResource : LongInt;
Var V, T, Line : LongInt; Mods : LongInt;
Begin
  Line := CurLine;
  Mods := 0;
  While IsKw('final') Or IsOp('@') Do
    If IsOp('@') Then SkipAnnotation Else Begin Inc(P); Mods := Mods Or ACC_FINAL; End;
  If IsLocalVarDecl Then Begin
    V := NewNode(N_LOCALVAR, Line);
    T := ParseType;
    Nodes[V].A := T;
    Nodes[V].B := NewNode(N_VARDECL, CurLine);
    Nodes[Nodes[V].B].S := ExpectIdent;
    Expect('=');
    Nodes[Nodes[V].B].A := ParseExpr;
    ParseResource := V;
  End
  Else Begin
    V := NewNode(N_EXPRSTMT, Line);
    Nodes[V].A := ParseExpr;
    ParseResource := V;
  End;
End;

Function ParseStatement : LongInt;
Var N, Line, T, H, Tl, C, Mods, Q, Hc, Tc : LongInt; S : String;
Begin
  Line := CurLine;
  If IsOp('{') Then Begin ParseStatement := ParseBlock; Exit; End;
  If IsOp(';') Then Begin
    Inc(P);
    ParseStatement := NewNode(N_EMPTY, Line); Exit;
  End;
  If IsOp('@') And Not IsKwAt(1, 'interface') Then Begin
    SkipAnnotations;
    ParseStatement := ParseStatement; Exit;
  End;
  If Toks[TokIdx(0)].Kind = TK_KEYWORD Then Begin
    S := Toks[P].Str;
    If S = 'if' Then Begin
      Inc(P);
      N := NewNode(N_IF, Line);
      Expect('(');
      Nodes[N].A := ParseExpr;
      Expect(')');
      Nodes[N].B := ParseStatement;
      If AcceptKw('else') Then Nodes[N].C := ParseStatement;
      ParseStatement := N; Exit;
    End;
    If S = 'while' Then Begin
      Inc(P);
      N := NewNode(N_WHILE, Line);
      Expect('(');
      Nodes[N].A := ParseExpr;
      Expect(')');
      Nodes[N].B := ParseStatement;
      ParseStatement := N; Exit;
    End;
    If S = 'do' Then Begin
      Inc(P);
      N := NewNode(N_DO, Line);
      Nodes[N].A := ParseStatement;
      ExpectKw('while');
      Expect('(');
      Nodes[N].B := ParseExpr;
      Expect(')');
      Expect(';');
      ParseStatement := N; Exit;
    End;
    If S = 'for' Then Begin
      Inc(P);
      Expect('(');
      Mods := 0;
      While IsKw('final') Or IsOp('@') Do
        If IsOp('@') Then SkipAnnotation Else Begin Inc(P); Mods := Mods Or ACC_FINAL; End;
      { for-each : Type ident : expr }
      If (Mods <> 0) Or IsLocalVarDecl Then Begin
        Q := SkipTypeAt(P);
        If (Q > 0) And (Toks[Q].Kind = TK_IDENT) And (Toks[Q + 1].Kind = TK_OP) And
           (Toks[Q + 1].Str = ':') Then Begin
          N := NewNode(N_FOREACH, Line);
          Nodes[N].A := ParseType;
          Nodes[N].S := ExpectIdent;
          Nodes[N].Mods := Mods;
          Expect(':');
          Nodes[N].B := ParseExpr;
          Expect(')');
          Nodes[N].C := ParseStatement;
          ParseStatement := N; Exit;
        End;
      End;
      N := NewNode(N_FOR, Line);
      H := 0; Tl := 0;
      If Not IsOp(';') Then Begin
        If (Mods <> 0) Or IsLocalVarDecl Then
          AppendNode(H, Tl, ParseLocalVarDecl(Mods))
        Else Begin
          While True Do Begin
            T := NewNode(N_EXPRSTMT, CurLine);
            Nodes[T].A := ParseExpr;
            AppendNode(H, Tl, T);
            If Not Accept(',') Then Break;
          End;
        End;
      End;
      Nodes[N].A := H;
      Expect(';');
      If Not IsOp(';') Then Nodes[N].B := ParseExpr;
      Expect(';');
      H := 0; Tl := 0;
      If Not IsOp(')') Then Begin
        While True Do Begin
          T := NewNode(N_EXPRSTMT, CurLine);
          Nodes[T].A := ParseExpr;
          AppendNode(H, Tl, T);
          If Not Accept(',') Then Break;
        End;
      End;
      Nodes[N].C := H;
      Expect(')');
      Nodes[N].D := ParseStatement;
      ParseStatement := N; Exit;
    End;
    If S = 'return' Then Begin
      Inc(P);
      N := NewNode(N_RETURN, Line);
      If Not IsOp(';') Then Nodes[N].A := ParseExpr;
      Expect(';');
      ParseStatement := N; Exit;
    End;
    If S = 'break' Then Begin
      Inc(P);
      N := NewNode(N_BREAK, Line);
      If IsIdentAt(0) Then Nodes[N].S := ExpectIdent;
      Expect(';');
      ParseStatement := N; Exit;
    End;
    If S = 'continue' Then Begin
      Inc(P);
      N := NewNode(N_CONTINUE, Line);
      If IsIdentAt(0) Then Nodes[N].S := ExpectIdent;
      Expect(';');
      ParseStatement := N; Exit;
    End;
    If S = 'throw' Then Begin
      Inc(P);
      N := NewNode(N_THROW, Line);
      Nodes[N].A := ParseExpr;
      Expect(';');
      ParseStatement := N; Exit;
    End;
    If S = 'try' Then Begin
      Inc(P);
      N := NewNode(N_TRY, Line);
      If Accept('(') Then Begin
        H := 0; Tl := 0;
        While Not IsOp(')') Do Begin
          AppendNode(H, Tl, ParseResource);
          If Not Accept(';') Then Break;
        End;
        Expect(')');
        Nodes[N].A := H;
      End;
      Nodes[N].B := ParseBlock;
      H := 0; Tl := 0;
      While IsKw('catch') Do Begin
        C := NewNode(N_CATCH, CurLine);
        Inc(P);
        Expect('(');
        While IsKw('final') Or IsOp('@') Do
          If IsOp('@') Then SkipAnnotation Else Inc(P);
        Hc := 0; Tc := 0;
        AppendNode(Hc, Tc, ParseType);
        While Accept('|') Do AppendNode(Hc, Tc, ParseType);
        Nodes[C].A := Hc;
        Nodes[C].S := ExpectIdent;
        Expect(')');
        Nodes[C].B := ParseBlock;
        AppendNode(H, Tl, C);
      End;
      Nodes[N].C := H;
      If AcceptKw('finally') Then Nodes[N].D := ParseBlock;
      If (Nodes[N].A = 0) And (Nodes[N].C = 0) And (Nodes[N].D = 0) Then
        Err(Line, '''try'' sans ''catch'', ''finally'' ou ressources');
      ParseStatement := N; Exit;
    End;
    If S = 'switch' Then Begin
      Inc(P);
      N := NewNode(N_SWITCH, Line);
      Expect('(');
      Nodes[N].A := ParseExpr;
      Expect(')');
      Nodes[N].B := ParseSwitchBody(False);
      ParseStatement := N; Exit;
    End;
    If S = 'synchronized' Then Begin
      Inc(P);
      N := NewNode(N_SYNC, Line);
      Expect('(');
      Nodes[N].A := ParseExpr;
      Expect(')');
      Nodes[N].B := ParseBlock;
      ParseStatement := N; Exit;
    End;
    If S = 'assert' Then Begin
      Inc(P);
      N := NewNode(N_ASSERT, Line);
      Nodes[N].A := ParseExpr;
      If Accept(':') Then Nodes[N].B := ParseExpr;
      Expect(';');
      ParseStatement := N; Exit;
    End;
    If (S = 'class') Or (S = 'interface') Or (S = 'enum') Or (S = 'abstract') Or
       (S = 'final') Or (S = 'static') Or (S = 'strictfp') Then Begin
      Mods := 0;
      While IsKw('final') Or IsKw('abstract') Or IsKw('static') Or IsKw('strictfp') Do Begin
        If IsKw('final') Then Mods := Mods Or ACC_FINAL
        Else If IsKw('abstract') Then Mods := Mods Or ACC_ABSTRACT
        Else If IsKw('static') Then Mods := Mods Or ACC_STATIC;
        Inc(P);
        While IsOp('@') Do SkipAnnotation;
      End;
      If IsKw('class') Or IsKw('interface') Or IsKw('enum') Or IsIdentStr(0, 'record') Then Begin
        N := NewNode(N_LOCALCLASS, Line);
        Nodes[N].A := ParseClassDecl(Mods Or MOD_LOCAL);
        ParseStatement := N; Exit;
      End;
      N := ParseLocalVarDecl(Mods);
      Expect(';');
      ParseStatement := N; Exit;
    End;
    If (S = 'this') Or (S = 'super') Or (S = 'new') Or (S = 'true') Or (S = 'false') Or
       (S = 'null') Or IsPrimKw(0) Then Begin
      If IsPrimKw(0) And IsLocalVarDecl Then Begin
        N := ParseLocalVarDecl(0);
        Expect(';');
        ParseStatement := N; Exit;
      End;
      { expression }
    End
    Else Begin
      SyntaxErr('instruction illegale au debut : ' + S);
    End;
  End;
  { identificateur : etiquette, yield, record local, declaration ou expression }
  If IsIdentAt(0) Then Begin
    If IsOpAt(1, ':') And Not IsOpAt(1, '::') Then Begin
      N := NewNode(N_LABELED, Line);
      Nodes[N].S := Toks[P].Str;
      Inc(P, 2);
      Nodes[N].A := ParseStatement;
      ParseStatement := N; Exit;
    End;
    If IsIdentStr(0, 'yield') And Not (IsOpAt(1, '=') Or IsOpAt(1, '.') Or
                                       IsOpAt(1, '++') Or IsOpAt(1, '--') Or IsOpAt(1, '[')) Then Begin
      Inc(P);
      N := NewNode(N_YIELD, Line);
      Nodes[N].A := ParseExpr;
      Expect(';');
      ParseStatement := N; Exit;
    End;
    If IsIdentStr(0, 'record') And IsIdentAt(1) And (IsOpAt(2, '(') Or IsOpAt(2, '<')) Then Begin
      N := NewNode(N_LOCALCLASS, Line);
      Nodes[N].A := ParseClassDecl(MOD_LOCAL);
      ParseStatement := N; Exit;
    End;
  End;
  If IsLocalVarDecl Then Begin
    N := ParseLocalVarDecl(0);
    Expect(';');
    ParseStatement := N; Exit;
  End;
  N := NewNode(N_EXPRSTMT, Line);
  Nodes[N].A := ParseExpr;
  Expect(';');
  ParseStatement := N;
End;

{ ---------------------------------------------------------------------------
  Declarations
  --------------------------------------------------------------------------- }

{ Valeur d'un element d'annotation : expression, tableau entre accolades ou annotation imbriquee }
Function ParseAnnotation : LongInt; Forward;

Function ParseElemValue : LongInt;
Var N, Head, Tail : LongInt;
Begin
  If IsOp('@') Then ParseElemValue := ParseAnnotation
  Else If IsOp('{') Then Begin
    N := NewNode(N_ARRAYINIT, CurLine);
    Inc(P);
    Head := 0; Tail := 0;
    While Not IsOp('}') Do Begin
      AppendNode(Head, Tail, ParseElemValue);
      If Not Accept(',') Then Break;
    End;
    Expect('}');
    Nodes[N].A := Head;
    ParseElemValue := N;
  End
  Else ParseElemValue := ParseTernary;
End;

{ P est sur '@' : construit un N_ANNOT (S = nom, A = chaine de N_ANNARG) }
Function ParseAnnotation : LongInt;
Var N, G, Head, Tail : LongInt; S : String;
Begin
  N := NewNode(N_ANNOT, CurLine);
  Inc(P);
  S := ExpectIdent;
  While IsOp('.') And IsIdentAt(1) Do Begin
    Inc(P);
    S := S + '.' + ExpectIdent;
  End;
  Nodes[N].S := S;
  If IsOp('(') Then Begin
    Inc(P);
    Head := 0; Tail := 0;
    If Not IsOp(')') Then Begin
      If IsIdentAt(0) And IsOpAt(1, '=') Then Begin
        While True Do Begin
          G := NewNode(N_ANNARG, CurLine);
          Nodes[G].S := ExpectIdent;
          Expect('=');
          Nodes[G].A := ParseElemValue;
          AppendNode(Head, Tail, G);
          If Not Accept(',') Then Break;
        End;
      End
      Else Begin
        G := NewNode(N_ANNARG, CurLine);
        Nodes[G].S := 'value';
        Nodes[G].A := ParseElemValue;
        AppendNode(Head, Tail, G);
      End;
    End;
    Expect(')');
    Nodes[N].A := Head;
  End;
  ParseAnnotation := N;
End;

{ Annotations de declaration en tete : ajoutees a la chaine Head }
Procedure ParseAnnotationsInto(Var Head, Tail : LongInt);
Begin
  While IsOp('@') And Not IsKwAt(1, 'interface') Do AppendNode(Head, Tail, ParseAnnotation);
End;

Var PendAnn : LongInt;      { annotations lues par ParseModifiers, reprises par le constructeur de noeud }

Function ParseModifiers : LongInt;
Var M : LongInt; S : String; AnnTail : LongInt;
Begin
  M := 0;
  PendAnn := 0; AnnTail := 0;
  While True Do Begin
    If IsOp('@') And Not IsKwAt(1, 'interface') Then Begin AppendNode(PendAnn, AnnTail, ParseAnnotation); Continue; End;
    If Toks[TokIdx(0)].Kind = TK_KEYWORD Then Begin
      S := Toks[P].Str;
      If S = 'public' Then M := M Or ACC_PUBLIC
      Else If S = 'private' Then M := M Or ACC_PRIVATE
      Else If S = 'protected' Then M := M Or ACC_PROTECTED
      Else If S = 'static' Then M := M Or ACC_STATIC
      Else If S = 'final' Then M := M Or ACC_FINAL
      Else If S = 'abstract' Then M := M Or ACC_ABSTRACT
      Else If S = 'native' Then M := M Or ACC_NATIVE
      Else If S = 'synchronized' Then M := M Or ACC_SYNCHRONIZED
      Else If S = 'transient' Then M := M Or ACC_TRANSIENT
      Else If S = 'volatile' Then M := M Or ACC_VOLATILE
      Else If S = 'strictfp' Then M := M Or ACC_STRICT
      Else If (S = 'default') And Not IsOpAt(1, ':') And Not IsOpAt(1, '->') Then M := M Or MOD_DEFAULT
      Else Break;
      Inc(P);
    End
    Else If IsIdentStr(0, 'sealed') And (IsKwAt(1, 'class') Or IsKwAt(1, 'interface') Or
            IsKwAt(1, 'abstract') Or IsKwAt(1, 'public') Or IsKwAt(1, 'static')) Then Begin
      M := M Or MOD_SEALED; Inc(P);
    End
    Else If IsIdentStr(0, 'non') And IsOpAt(1, '-') And IsIdentStr(2, 'sealed') Then Begin
      M := M Or MOD_NONSEALED; Inc(P, 3);
    End
    Else Break;
  End;
  ParseModifiers := M;
End;

Function ParseParams : LongInt;
Var Head, Tail, Prm, PAnnT : LongInt;
Begin
  Head := 0; Tail := 0;
  Expect('(');
  If Not IsOp(')') Then Begin
    While True Do Begin
      Prm := NewNode(N_PARAM, CurLine);
      PAnnT := 0;
      While IsKw('final') Or IsOp('@') Do
        If IsOp('@') Then AppendNode(Nodes[Prm].Ann, PAnnT, ParseAnnotation) Else Begin Inc(P); Nodes[Prm].Mods := Nodes[Prm].Mods Or ACC_FINAL; End;
      Nodes[Prm].A := ParseType;
      If IsOp('.') And IsOpAt(1, '.') And IsOpAt(2, '.') Then Begin
        Inc(P, 3);
        Nodes[Prm].Aux := 1;   { varargs }
        Inc(Nodes[Nodes[Prm].A].N);
      End
      Else If IsOp('...') Then Begin
        Inc(P);
        Nodes[Prm].Aux := 1;
        Inc(Nodes[Nodes[Prm].A].N);
      End;
      If IsKw('this') Then Begin Inc(P); Accept(','); Continue; End;
      Nodes[Prm].S := ExpectIdent;
      While IsOp('[') And IsOpAt(1, ']') Do Begin
        Inc(P, 2);
        Inc(Nodes[Nodes[Prm].A].N);
      End;
      AppendNode(Head, Tail, Prm);
      If Not Accept(',') Then Break;
    End;
  End;
  Expect(')');
  ParseParams := Head;
End;

Function ParseMethodRest(Mods : LongInt; TParams, RetType : LongInt; Const Name : String;
                         Line : LongInt; IsCtor : Boolean) : LongInt;
Var M, Head, Tail : LongInt;
Begin
  M := NewNode(N_METHOD, Line);
  Nodes[M].S := Name;
  Nodes[M].Mods := Mods;
  Nodes[M].E := TParams;
  Nodes[M].A := RetType;
  If IsCtor Then Nodes[M].Aux := 1;
  Nodes[M].B := ParseParams;
  While IsOp('[') And IsOpAt(1, ']') Do Begin Inc(P, 2); If RetType <> 0 Then Inc(Nodes[RetType].N); End;
  If AcceptKw('throws') Then Begin
    Head := 0; Tail := 0;
    While True Do Begin
      AppendNode(Head, Tail, ParseType);
      If Not Accept(',') Then Break;
    End;
    Nodes[M].D := Head;
  End;
  If IsOp('{') Then Nodes[M].C := ParseBlock
  Else Begin
    If IsKw('default') Then Begin Inc(P); Nodes[M].Dflt := ParseElemValue; End;   { valeur par defaut d'annotation }
    Expect(';');
  End;
  ParseMethodRest := M;
End;

Function ParseEnumConst : LongInt;
Var N, E, At : LongInt;
Begin
  At := 0; E := 0;
  ParseAnnotationsInto(At, E);
  N := NewNode(N_ENUMCONST, CurLine);
  Nodes[N].Ann := At;
  Nodes[N].S := ExpectIdent;
  If IsOp('(') Then Nodes[N].A := ParseArgs;
  If IsOp('{') Then Begin
    E := NewNode(N_CLASS, CurLine);
    Nodes[E].Mods := MOD_ANON Or MOD_LOCAL;
    Nodes[E].Aux := CLS_CLASS;
    Nodes[N].B := E;
    ParseClassBody(E);
  End;
  ParseEnumConst := N;
End;

Procedure ParseClassBody(Cls : LongInt);
Var
  Head, Tail, M, Mods, TP, T, Line, V, Q, MAnn : LongInt;
  Name : String;
  IsIface : Boolean;
  Simple : String;
Begin
  Head := 0; Tail := 0;
  Simple := Nodes[Cls].S;
  IsIface := (Nodes[Cls].Aux = CLS_INTERFACE) Or (Nodes[Cls].Aux = CLS_ANNOTATION);
  Expect('{');
  { constantes d'enumeration }
  If Nodes[Cls].Aux = CLS_ENUM Then Begin
    While IsIdentAt(0) Or IsOp('@') Do Begin
      AppendNode(Head, Tail, ParseEnumConst);
      If Not Accept(',') Then Break;
    End;
    If Not IsOp('}') Then Expect(';');
  End;
  While Not IsOp('}') Do Begin
    If Toks[TokIdx(0)].Kind = TK_EOF Then SyntaxErr('fin de fichier inattendue (''}'' manquant)');
    If Accept(';') Then Continue;
    Line := CurLine;
    Mods := ParseModifiers;
    MAnn := PendAnn; PendAnn := 0;
    If IsOp('{') Then Begin
      M := NewNode(N_INIT, Line);
      Nodes[M].Mods := Mods;
      Nodes[M].A := ParseBlock;
      AppendNode(Head, Tail, M);
      Continue;
    End;
    If IsKw('class') Or IsKw('interface') Or IsKw('enum') Or (IsOp('@') And IsKwAt(1, 'interface')) Or
       (IsIdentStr(0, 'record') And IsIdentAt(1) And (IsOpAt(2, '(') Or IsOpAt(2, '<'))) Then Begin
      PendAnn := MAnn;
      AppendNode(Head, Tail, ParseClassDecl(Mods));
      Continue;
    End;
    TP := 0;
    If IsOp('<') Then TP := ParseTypeParams;
    { constructeur }
    If IsIdentAt(0) And IsOpAt(1, '(') And (Toks[P].Str = Simple) Then Begin
      Name := '<init>';
      Inc(P);
      M := ParseMethodRest(Mods, TP, 0, Name, Line, True);
      Nodes[M].Ann := MAnn;
      AppendNode(Head, Tail, M);
      Continue;
    End;
    { constructeur compact d'un record }
    If IsIdentAt(0) And IsOpAt(1, '{') And (Toks[P].Str = Simple) And (Nodes[Cls].Aux = CLS_RECORD) Then Begin
      Inc(P);
      M := NewNode(N_METHOD, Line);
      Nodes[M].S := '<init>';
      Nodes[M].Mods := Mods;
      Nodes[M].Aux := 3;          { constructeur compact }
      Nodes[M].Ann := MAnn;
      Nodes[M].C := ParseBlock;
      AppendNode(Head, Tail, M);
      Continue;
    End;
    T := ParseType;
    Name := ExpectIdent;
    If IsOp('(') Then Begin
      M := ParseMethodRest(Mods, TP, T, Name, Line, False);
      Nodes[M].Ann := MAnn;
      AppendNode(Head, Tail, M);
    End
    Else Begin
      { champ : on reprend le nom comme premier declarateur }
      Dec(P);
      M := NewNode(N_FIELD, Line);
      Nodes[M].Mods := Mods;
      Nodes[M].A := T;
      Nodes[M].B := ParseDeclarators(T, Mods);
      Nodes[M].Ann := MAnn;
      V := Nodes[M].B;
      While V <> 0 Do Begin Nodes[V].Ann := MAnn; Nodes[V].E := T; V := Nodes[V].Next; End;
      Expect(';');
      AppendNode(Head, Tail, M);
    End;
  End;
  Expect('}');
  Nodes[Cls].D := Head;
End;

Function ParseClassDecl(Mods : LongInt) : LongInt;
Var N, Head, Tail, Line : LongInt; Kind : LongInt;
Begin
  Line := CurLine;
  N := NewNode(N_CLASS, Line);
  Nodes[N].Mods := Mods;
  Nodes[N].Ann := PendAnn; PendAnn := 0;
  If IsKw('class') Then Begin Kind := CLS_CLASS; Inc(P); End
  Else If IsKw('interface') Then Begin Kind := CLS_INTERFACE; Inc(P); End
  Else If IsKw('enum') Then Begin Kind := CLS_ENUM; Inc(P); End
  Else If IsOp('@') Then Begin Kind := CLS_ANNOTATION; Inc(P, 2); End
  Else If IsIdentStr(0, 'record') Then Begin Kind := CLS_RECORD; Inc(P); End
  Else Begin SyntaxErr('class, interface ou enum attendu'); Kind := 0; End;
  Nodes[N].Aux := Kind;
  Nodes[N].S := ExpectIdent;
  If IsOp('<') Then Nodes[N].A := ParseTypeParams;
  If Kind = CLS_RECORD Then Nodes[N].E := ParseParams;
  If IsKw('extends') Then Begin
    Inc(P);
    If Kind = CLS_INTERFACE Then Begin
      Head := 0; Tail := 0;
      While True Do Begin
        AppendNode(Head, Tail, ParseType);
        If Not Accept(',') Then Break;
      End;
      Nodes[N].C := Head;
    End
    Else Nodes[N].B := ParseType;
  End;
  If IsKw('implements') Then Begin
    Inc(P);
    Head := 0; Tail := 0;
    While True Do Begin
      AppendNode(Head, Tail, ParseType);
      If Not Accept(',') Then Break;
    End;
    Nodes[N].C := Head;
  End;
  If IsIdentStr(0, 'permits') Then Begin
    Inc(P);
    Head := 0; Tail := 0;
    Repeat AppendNode(Head, Tail, ParseType) Until Not Accept(',');
    Nodes[N].Dflt := Head;       { classes permises (classe scellee) }
  End;
  ParseClassBody(N);
  ParseClassDecl := N;
End;

{ Nom pointe : a.b.c }
Function ParseDottedName : String;
Var S : String;
Begin
  S := ExpectIdent;
  While IsOp('.') And IsIdentAt(1) Do Begin
    Inc(P);
    S := S + '.' + ExpectIdent;
  End;
  ParseDottedName := S;
End;

{ module [open] nom, puis les directives entre accolades ; P est sur "open" ou "module" ;
  les annotations sont dans PendAnn }
Function ParseModuleDecl : LongInt;
Var N, D, Head, Tail, Hb, Tb, X : LongInt; Kind : String; Mods : LongInt;
Begin
  N := NewNode(N_MODULE, CurLine);
  Nodes[N].Ann := PendAnn; PendAnn := 0;
  If IsIdentStr(0, 'open') Then Begin Inc(P); Nodes[N].Mods := 1; End;
  Inc(P);   { module }
  Nodes[N].S := ParseDottedName;
  Expect('{');
  Head := 0; Tail := 0;
  While Not IsOp('}') Do Begin
    If Toks[TokIdx(0)].Kind = TK_EOF Then SyntaxErr('fin de fichier inattendue (accolade fermante manquante)');
    D := NewNode(N_DIRECTIVE, CurLine);
    Kind := ExpectIdent;
    Nodes[D].S := Kind;
    If Kind = 'requires' Then Begin
      Mods := 0;
      While (IsIdentStr(0, 'transitive') Or IsKw('static')) And Not IsOpAt(1, ';') And Not IsOpAt(1, '.') Do Begin
        If IsKw('static') Then Mods := Mods Or $40 Else Mods := Mods Or $20;
        Inc(P);
      End;
      Nodes[D].Mods := Mods;
      Nodes[D].CS := ParseDottedName;
    End
    Else If (Kind = 'exports') Or (Kind = 'opens') Then Begin
      Nodes[D].CS := ParseDottedName;
      If IsIdentStr(0, 'to') Then Begin
        Inc(P);
        Hb := 0; Tb := 0;
        Repeat
          X := NewNode(N_NAME, CurLine);
          Nodes[X].S := ParseDottedName;
          AppendNode(Hb, Tb, X);
        Until Not Accept(',');
        Nodes[D].B := Hb;
      End;
    End
    Else If Kind = 'uses' Then Nodes[D].CS := ParseDottedName
    Else If Kind = 'provides' Then Begin
      Nodes[D].CS := ParseDottedName;
      If Not IsIdentStr(0, 'with') Then SyntaxErr('with attendu');
      Inc(P);
      Hb := 0; Tb := 0;
      Repeat
        X := NewNode(N_NAME, CurLine);
        Nodes[X].S := ParseDottedName;
        AppendNode(Hb, Tb, X);
      Until Not Accept(',');
      Nodes[D].B := Hb;
    End
    Else SyntaxErr('directive de module inconnue : ' + Kind);
    Expect(';');
    AppendNode(Head, Tail, D);
  End;
  Expect('}');
  Nodes[N].A := Head;
  ParseModuleDecl := N;
End;

Function ParseCompilationUnit : LongInt;
Var N, Head, Tail, I, Mods, Line : LongInt; S : String;
Begin
  N := NewNode(N_CU, 1);
  Head := 0; Tail := 0;
  SkipAnnotations;
  If IsKw('package') Then Begin
    Inc(P);
    S := ExpectIdent;
    While Accept('.') Do S := S + '.' + ExpectIdent;
    Expect(';');
    Nodes[N].S := S;
  End;
  While IsKw('import') Do Begin
    Line := CurLine;
    Inc(P);
    I := NewNode(N_IMPORT, Line);
    If AcceptKw('static') Then Nodes[I].Mods := ACC_STATIC;
    S := ExpectIdent;
    While Accept('.') Do Begin
      If Accept('*') Then Begin Nodes[I].Aux := 1; Break; End;
      S := S + '.' + ExpectIdent;
    End;
    Expect(';');
    Nodes[I].S := S;
    AppendNode(Head, Tail, I);
  End;
  Nodes[N].A := Head;
  Head := 0; Tail := 0;
  While Toks[TokIdx(0)].Kind <> TK_EOF Do Begin
    If Accept(';') Then Continue;
    Mods := ParseModifiers;
    If (IsIdentStr(0, 'module') And IsIdentAt(1)) Or (IsIdentStr(0, 'open') And IsIdentStr(1, 'module')) Then
      Nodes[N].C := ParseModuleDecl
    Else If IsKw('class') Or IsKw('interface') Or IsKw('enum') Or (IsOp('@') And IsKwAt(1, 'interface')) Or
       (IsIdentStr(0, 'record') And IsIdentAt(1)) Then
      AppendNode(Head, Tail, ParseClassDecl(Mods))
    Else
      SyntaxErr('class, interface ou enum attendu');
  End;
  Nodes[N].B := Head;
  ParseCompilationUnit := N;
End;

{ ============================================================================
  TABLE DE LA BIBLIOTHEQUE STANDARD JAVA (signatures)
  Generee par reflexion a partir du JDK (classes java.lang, java.util, java.io,
  java.util.function, java.util.stream, java.math, java.time, ...).
  Format : C|acces|nom|signature de classe
           F|acces|nom|descripteur|signature generique|constante
           M|acces|nom|descripteur|signature generique
  Abreviations : ~S=String ~O=Object ~1=Ljava/lang/ ~2=Ljava/util/
                 ~3=Ljava/util/function/ ~4=Ljava/io/ ~5=Ljava/util/stream/
  ============================================================================ }

Const
  LIBN = 6304;
  LibTab : Array[0..LIBN - 1] Of String = (
'C|1|java/lang/Object|~O',
'M|1|<init>|()V||',
'M|4|finalize|()V||java/lang/Throwable',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|257|hashCode|()I||',
'M|273|getClass|()~1Class;|()~1Class<*>;|',
'M|260|clone|()~O||java/lang/CloneNotSupportedException',
'M|273|notify|()V||',
'M|273|notifyAll|()V||',
'M|17|wait|(J)V||java/lang/InterruptedException',
'M|17|wait|(JI)V||java/lang/InterruptedException',
'M|17|wait|()V||java/lang/InterruptedException',
'C|17|java/lang/String|~O~4Serializable;~1Comparable<~S>;~1CharSequence;~1constant/Constable;~1constant/ConstantDesc;',
'F|25|CASE_INSENSITIVE_ORDER|~2Comparator;|~2Comparator<~S>;|',
'M|1|<init>|(~1StringBuilder;)V||',
'M|1|<init>|([BIILjava/nio/charset/Charset;)V||',
'M|1|<init>|([B~S)V||java/io/UnsupportedEncodingException',
'M|1|<init>|([BLjava/nio/charset/Charset;)V||',
'M|1|<init>|([BII)V||',
'M|1|<init>|([B)V||',
'M|1|<init>|(~1StringBuffer;)V||',
'M|1|<init>|([CII)V||',
'M|1|<init>|([C)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'M|1|<init>|([BII~S)V||java/io/UnsupportedEncodingException',
'M|1|<init>|([BI)V||',
'M|1|<init>|([BIII)V||',
'M|1|<init>|([III)V||',
'M|1|equals|(~O)Z||',
'M|1|length|()I||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|getChars|(II[CI)V||',
'M|1|compareTo|(~S)I||',
'M|1|indexOf|(~SII)I||',
'M|1|indexOf|(~SI)I||',
'M|1|indexOf|(I)I||',
'M|1|indexOf|(II)I||',
'M|1|indexOf|(III)I||',
'M|1|indexOf|(~S)I||',
'M|9|valueOf|(J)~S||',
'M|9|valueOf|([C)~S||',
'M|9|valueOf|(~O)~S||',
'M|9|valueOf|([CII)~S||',
'M|9|valueOf|(F)~S||',
'M|9|valueOf|(D)~S||',
'M|9|valueOf|(C)~S||',
'M|9|valueOf|(Z)~S||',
'M|9|valueOf|(I)~S||',
'M|1|charAt|(I)C||',
'M|1|codePointAt|(I)I||',
'M|1|codePointBefore|(I)I||',
'M|1|codePointCount|(II)I||',
'M|1|offsetByCodePoints|(II)I||',
'M|1|getBytes|()[B||',
'M|1|getBytes|(II[BI)V||',
'M|1|getBytes|(~S)[B||java/io/UnsupportedEncodingException',
'M|1|getBytes|(Ljava/nio/charset/Charset;)[B||',
'M|1|contentEquals|(~1CharSequence;)Z||',
'M|1|contentEquals|(~1StringBuffer;)Z||',
'M|1|regionMatches|(I~SII)Z||',
'M|1|regionMatches|(ZI~SII)Z||',
'M|1|startsWith|(~S)Z||',
'M|1|startsWith|(~SI)Z||',
'M|1|lastIndexOf|(I)I||',
'M|1|lastIndexOf|(~S)I||',
'M|1|lastIndexOf|(II)I||',
'M|1|lastIndexOf|(~SI)I||',
'M|1|substring|(II)~S||',
'M|1|substring|(I)~S||',
'M|1|isEmpty|()Z||',
'M|1|replace|(CC)~S||',
'M|1|replace|(~1CharSequence;~1CharSequence;)~S||',
'M|1|matches|(~S)Z||',
'M|1|replaceFirst|(~S~S)~S||',
'M|1|replaceAll|(~S~S)~S||',
'M|1|split|(~S)[~S||',
'M|1|split|(~SI)[~S||',
'M|1|splitWithDelimiters|(~SI)[~S||',
'M|9|join|(~1CharSequence;~1Iterable;)~S|(~1CharSequence;~1Iterable<+~1CharSequence;>;)~S|',
'M|137|join|(~1CharSequence;[~1CharSequence;)~S||',
'M|1|toLowerCase|()~S||',
'M|1|toLowerCase|(~2Locale;)~S||',
'M|1|toUpperCase|()~S||',
'M|1|toUpperCase|(~2Locale;)~S||',
'M|1|trim|()~S||',
'M|1|strip|()~S||',
'M|1|stripLeading|()~S||',
'M|1|stripTrailing|()~S||',
'M|1|lines|()~5Stream;|()~5Stream<~S>;|',
'M|1|repeat|(I)~S||',
'M|1|isBlank|()Z||',
'M|1|toCharArray|()[C||',
'M|137|format|(~2Locale;~S[~O)~S||',
'M|137|format|(~S[~O)~S||',
'M|1|resolveConstantDesc|(~1invoke/MethodHandles$Lookup;)~S||',
'M|1|codePoints|()~5IntStream;||',
'M|1|equalsIgnoreCase|(~S)Z||',
'M|1|compareToIgnoreCase|(~S)I||',
'M|1|endsWith|(~S)Z||',
'M|1|subSequence|(II)~1CharSequence;||',
'M|1|concat|(~S)~S||',
'M|1|contains|(~1CharSequence;)Z||',
'M|1|indent|(I)~S||',
'M|1|stripIndent|()~S||',
'M|1|translateEscapes|()~S||',
'M|1|chars|()~5IntStream;||',
'M|1|transform|(~3Function;)~O|<R:~O>(~3Function<-~S+TR;>;)TR;|',
'M|129|formatted|([~O)~S||',
'M|9|copyValueOf|([CII)~S||',
'M|9|copyValueOf|([C)~S||',
'M|257|intern|()~S||',
'M|1|describeConstable|()~2Optional;|()~2Optional<~S>;|',
'C|1537|java/lang/CharSequence|~O',
'M|1025|length|()I||',
'M|1025|toString|()~S||',
'M|9|compare|(~1CharSequence;~1CharSequence;)I||',
'M|1025|charAt|(I)C||',
'M|65537|isEmpty|()Z||',
'M|65537|codePoints|()~5IntStream;||',
'M|1025|subSequence|(II)~1CharSequence;||',
'M|65537|chars|()~5IntStream;||',
'C|1537|java/lang/Comparable|<T:~O>~O',
'M|1025|compareTo|(~O)I|(TT;)I|',
'C|1537|java/lang/Iterable|<T:~O>~O',
'M|1025|iterator|()~2Iterator;|()~2Iterator<TT;>;|',
'M|65537|spliterator|()~2Spliterator;|()~2Spliterator<TT;>;|',
'M|65537|forEach|(~3Consumer;)V|(~3Consumer<-TT;>;)V|',
'C|1537|java/lang/Runnable|~O',
'M|1025|run|()V||',
'C|1537|java/lang/AutoCloseable|~O',
'M|1025|close|()V||java/lang/Exception',
'C|1537|java/lang/Cloneable|~O',
'C|1537|java/lang/Appendable|~O',
'M|1025|append|(~1CharSequence;)~1Appendable;||java/io/IOException',
'M|1025|append|(~1CharSequence;II)~1Appendable;||java/io/IOException',
'M|1025|append|(C)~1Appendable;||java/io/IOException',
'C|1537|java/lang/Readable|~O',
'M|1025|read|(Ljava/nio/CharBuffer;)I||java/io/IOException',
'C|17|java/lang/StringBuilder|~1AbstractStringBuilder;~1Appendable;~4Serializable;~1Comparable<~1StringBuilder;>;~1CharSequence;',
'M|1|<init>|(~1CharSequence;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|(I)V||',
'M|1|<init>|()V||',
'M|1|toString|()~S||',
'M|1|append|(~1CharSequence;)~1StringBuilder;||',
'M|1|append|(~1CharSequence;II)~1StringBuilder;||',
'M|1|append|([C)~1StringBuilder;||',
'M|1|append|([CII)~1StringBuilder;||',
'M|1|append|(~O)~1StringBuilder;||',
'M|1|append|(~S)~1StringBuilder;||',
'M|1|append|(~1StringBuffer;)~1StringBuilder;||',
'M|1|append|(J)~1StringBuilder;||',
'M|1|append|(F)~1StringBuilder;||',
'M|1|append|(D)~1StringBuilder;||',
'M|1|append|(Z)~1StringBuilder;||',
'M|1|append|(C)~1StringBuilder;||',
'M|1|append|(I)~1StringBuilder;||',
'M|1|reverse|()~1StringBuilder;||',
'M|1|compareTo|(~1StringBuilder;)I||',
'M|1|indexOf|(~SI)I||',
'M|1|indexOf|(~S)I||',
'M|1|insert|(I~1CharSequence;)~1StringBuilder;||',
'M|1|insert|(I~S)~1StringBuilder;||',
'M|1|insert|(I[C)~1StringBuilder;||',
'M|1|insert|(II)~1StringBuilder;||',
'M|1|insert|(ID)~1StringBuilder;||',
'M|1|insert|(IF)~1StringBuilder;||',
'M|1|insert|(IJ)~1StringBuilder;||',
'M|1|insert|(IC)~1StringBuilder;||',
'M|1|insert|(IZ)~1StringBuilder;||',
'M|1|insert|(I~1CharSequence;II)~1StringBuilder;||',
'M|1|insert|(I~O)~1StringBuilder;||',
'M|1|insert|(I[CII)~1StringBuilder;||',
'M|1|lastIndexOf|(~SI)I||',
'M|1|lastIndexOf|(~S)I||',
'M|1|replace|(II~S)~1StringBuilder;||',
'M|1|repeat|(~1CharSequence;I)~1StringBuilder;||',
'M|1|repeat|(II)~1StringBuilder;||',
'M|1|delete|(II)~1StringBuilder;||',
'M|1|appendCodePoint|(I)~1StringBuilder;||',
'M|1|deleteCharAt|(I)~1StringBuilder;||',
'C|17|java/lang/StringBuffer|~1AbstractStringBuilder;~1Appendable;~4Serializable;~1Comparable<~1StringBuffer;>;~1CharSequence;',
'M|1|<init>|(~1CharSequence;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|(I)V||',
'M|1|<init>|()V||',
'M|33|length|()I||',
'M|33|toString|()~S||',
'M|33|append|(I)~1StringBuffer;||',
'M|33|append|(J)~1StringBuffer;||',
'M|33|append|(F)~1StringBuffer;||',
'M|33|append|([C)~1StringBuffer;||',
'M|33|append|([CII)~1StringBuffer;||',
'M|33|append|(Z)~1StringBuffer;||',
'M|33|append|(C)~1StringBuffer;||',
'M|33|append|(D)~1StringBuffer;||',
'M|33|append|(~S)~1StringBuffer;||',
'M|33|append|(~1StringBuffer;)~1StringBuffer;||',
'M|33|append|(~1CharSequence;)~1StringBuffer;||',
'M|33|append|(~1CharSequence;II)~1StringBuffer;||',
'M|33|append|(~O)~1StringBuffer;||',
'M|33|reverse|()~1StringBuffer;||',
'M|33|getChars|(II[CI)V||',
'M|33|compareTo|(~1StringBuffer;)I||',
'M|33|indexOf|(~SI)I||',
'M|1|indexOf|(~S)I||',
'M|33|insert|(I~O)~1StringBuffer;||',
'M|33|insert|(I[CII)~1StringBuffer;||',
'M|33|insert|(I[C)~1StringBuffer;||',
'M|1|insert|(IF)~1StringBuffer;||',
'M|1|insert|(IJ)~1StringBuffer;||',
'M|33|insert|(I~S)~1StringBuffer;||',
'M|1|insert|(I~1CharSequence;)~1StringBuffer;||',
'M|1|insert|(ID)~1StringBuffer;||',
'M|33|insert|(I~1CharSequence;II)~1StringBuffer;||',
'M|1|insert|(IZ)~1StringBuffer;||',
'M|1|insert|(II)~1StringBuffer;||',
'M|33|insert|(IC)~1StringBuffer;||',
'M|33|charAt|(I)C||',
'M|33|codePointAt|(I)I||',
'M|33|codePointBefore|(I)I||',
'M|33|codePointCount|(II)I||',
'M|33|offsetByCodePoints|(II)I||',
'M|33|lastIndexOf|(~SI)I||',
'M|1|lastIndexOf|(~S)I||',
'M|33|substring|(I)~S||',
'M|33|substring|(II)~S||',
'M|33|replace|(II~S)~1StringBuffer;||',
'M|33|repeat|(~1CharSequence;I)~1StringBuffer;||',
'M|33|repeat|(II)~1StringBuffer;||',
'M|33|subSequence|(II)~1CharSequence;||',
'M|33|delete|(II)~1StringBuffer;||',
'M|33|setLength|(I)V||',
'M|33|capacity|()I||',
'M|33|ensureCapacity|(I)V||',
'M|33|trimToSize|()V||',
'M|33|setCharAt|(IC)V||',
'M|33|appendCodePoint|(I)~1StringBuffer;||',
'M|33|deleteCharAt|(I)~1StringBuffer;||',
'C|1024|java/lang/AbstractStringBuilder|~O~1Appendable;~1CharSequence;',
'M|1|length|()I||',
'M|1025|toString|()~S||',
'M|1|append|(~1CharSequence;)~1AbstractStringBuilder;||',
'M|1|append|(~1CharSequence;II)~1AbstractStringBuilder;||',
'M|1|append|([C)~1AbstractStringBuilder;||',
'M|1|append|(~O)~1AbstractStringBuilder;||',
'M|1|append|(~S)~1AbstractStringBuilder;||',
'M|1|append|(~1StringBuffer;)~1AbstractStringBuilder;||',
'M|1|append|(I)~1AbstractStringBuilder;||',
'M|1|append|(J)~1AbstractStringBuilder;||',
'M|1|append|(F)~1AbstractStringBuilder;||',
'M|1|append|(D)~1AbstractStringBuilder;||',
'M|1|append|(C)~1AbstractStringBuilder;||',
'M|1|append|(Z)~1AbstractStringBuilder;||',
'M|1|append|([CII)~1AbstractStringBuilder;||',
'M|1|reverse|()~1AbstractStringBuilder;||',
'M|1|getChars|(II[CI)V||',
'M|1|indexOf|(~SI)I||',
'M|1|indexOf|(~S)I||',
'M|1|insert|(I~1CharSequence;)~1AbstractStringBuilder;||',
'M|1|insert|(I[C)~1AbstractStringBuilder;||',
'M|1|insert|(I~1CharSequence;II)~1AbstractStringBuilder;||',
'M|1|insert|(I~S)~1AbstractStringBuilder;||',
'M|1|insert|(I~O)~1AbstractStringBuilder;||',
'M|1|insert|(II)~1AbstractStringBuilder;||',
'M|1|insert|(ID)~1AbstractStringBuilder;||',
'M|1|insert|(IC)~1AbstractStringBuilder;||',
'M|1|insert|(IF)~1AbstractStringBuilder;||',
'M|1|insert|(IJ)~1AbstractStringBuilder;||',
'M|1|insert|(I[CII)~1AbstractStringBuilder;||',
'M|1|insert|(IZ)~1AbstractStringBuilder;||',
'M|1|charAt|(I)C||',
'M|1|codePointAt|(I)I||',
'M|1|codePointBefore|(I)I||',
'M|1|codePointCount|(II)I||',
'M|1|offsetByCodePoints|(II)I||',
'M|1|lastIndexOf|(~S)I||',
'M|1|lastIndexOf|(~SI)I||',
'M|1|substring|(II)~S||',
'M|1|substring|(I)~S||',
'M|1|replace|(II~S)~1AbstractStringBuilder;||',
'M|1|repeat|(~1CharSequence;I)~1AbstractStringBuilder;||',
'M|1|repeat|(II)~1AbstractStringBuilder;||',
'M|1|codePoints|()~5IntStream;||',
'M|1|subSequence|(II)~1CharSequence;||',
'M|1|chars|()~5IntStream;||',
'M|1|delete|(II)~1AbstractStringBuilder;||',
'M|1|setLength|(I)V||',
'M|1|capacity|()I||',
'M|1|ensureCapacity|(I)V||',
'M|1|trimToSize|()V||',
'M|1|setCharAt|(IC)V||',
'M|1|appendCodePoint|(I)~1AbstractStringBuilder;||',
'M|1|deleteCharAt|(I)~1AbstractStringBuilder;||',
'C|17|java/lang/Math|~O',
'F|25|E|D||D4613303445314885481',
'F|25|PI|D||D4614256656552045848',
'F|25|TAU|D||D4618760256179416344',
'M|9|abs|(D)D||',
'M|9|abs|(F)F||',
'M|9|abs|(J)J||',
'M|9|abs|(I)I||',
'M|9|sin|(D)D||',
'M|9|cos|(D)D||',
'M|9|tan|(D)D||',
'M|9|atan2|(DD)D||',
'M|9|sqrt|(D)D||',
'M|9|log|(D)D||',
'M|9|log10|(D)D||',
'M|9|pow|(DD)D||',
'M|9|exp|(D)D||',
'M|9|min|(DD)D||',
'M|9|min|(FF)F||',
'M|9|min|(JJ)J||',
'M|9|min|(II)I||',
'M|9|max|(DD)D||',
'M|9|max|(FF)F||',
'M|9|max|(JJ)J||',
'M|9|max|(II)I||',
'M|9|floor|(D)D||',
'M|9|ceil|(D)D||',
'M|9|rint|(D)D||',
'M|9|round|(F)I||',
'M|9|round|(D)J||',
'M|9|addExact|(JJ)J||',
'M|9|addExact|(II)I||',
'M|9|decrementExact|(I)I||',
'M|9|decrementExact|(J)J||',
'M|9|incrementExact|(J)J||',
'M|9|incrementExact|(I)I||',
'M|9|multiplyExact|(JJ)J||',
'M|9|multiplyExact|(JI)J||',
'M|9|multiplyExact|(II)I||',
'M|9|multiplyHigh|(JJ)J||',
'M|9|unsignedMultiplyHigh|(JJ)J||',
'M|9|negateExact|(I)I||',
'M|9|negateExact|(J)J||',
'M|9|subtractExact|(JJ)J||',
'M|9|subtractExact|(II)I||',
'M|9|fma|(DDD)D||',
'M|9|fma|(FFF)F||',
'M|9|copySign|(DD)D||',
'M|9|copySign|(FF)F||',
'M|9|signum|(D)D||',
'M|9|signum|(F)F||',
'M|9|clamp|(FFF)F||',
'M|9|clamp|(JJJ)J||',
'M|9|clamp|(DDD)D||',
'M|9|clamp|(JII)I||',
'M|9|scalb|(FI)F||',
'M|9|scalb|(DI)D||',
'M|9|getExponent|(D)I||',
'M|9|getExponent|(F)I||',
'M|9|floorMod|(II)I||',
'M|9|floorMod|(JI)I||',
'M|9|floorMod|(JJ)J||',
'M|9|asin|(D)D||',
'M|9|acos|(D)D||',
'M|9|atan|(D)D||',
'M|9|cbrt|(D)D||',
'M|9|IEEEremainder|(DD)D||',
'M|9|floorDiv|(JJ)J||',
'M|9|floorDiv|(JI)J||',
'M|9|floorDiv|(II)I||',
'M|9|ceilDiv|(JJ)J||',
'M|9|ceilDiv|(JI)J||',
'M|9|ceilDiv|(II)I||',
'M|9|ceilMod|(JJ)J||',
'M|9|ceilMod|(JI)I||',
'M|9|ceilMod|(II)I||',
'M|9|sinh|(D)D||',
'M|9|cosh|(D)D||',
'M|9|tanh|(D)D||',
'M|9|hypot|(DD)D||',
'M|9|expm1|(D)D||',
'M|9|log1p|(D)D||',
'M|9|toRadians|(D)D||',
'M|9|toDegrees|(D)D||',
'M|9|random|()D||',
'M|9|divideExact|(II)I||',
'M|9|divideExact|(JJ)J||',
'M|9|floorDivExact|(JJ)J||',
'M|9|floorDivExact|(II)I||',
'M|9|ceilDivExact|(JJ)J||',
'M|9|ceilDivExact|(II)I||',
'M|9|toIntExact|(J)I||',
'M|9|multiplyFull|(II)J||',
'M|9|absExact|(J)J||',
'M|9|absExact|(I)I||',
'M|9|ulp|(D)D||',
'M|9|ulp|(F)F||',
'M|9|nextAfter|(FD)F||',
'M|9|nextAfter|(DD)D||',
'M|9|nextUp|(D)D||',
'M|9|nextUp|(F)F||',
'M|9|nextDown|(D)D||',
'M|9|nextDown|(F)F||',
'C|17|java/lang/StrictMath|~O',
'F|25|E|D||D4613303445314885481',
'F|25|PI|D||D4614256656552045848',
'F|25|TAU|D||D4618760256179416344',
'M|9|abs|(D)D||',
'M|9|abs|(F)F||',
'M|9|abs|(J)J||',
'M|9|abs|(I)I||',
'M|9|sin|(D)D||',
'M|9|cos|(D)D||',
'M|9|tan|(D)D||',
'M|9|atan2|(DD)D||',
'M|9|sqrt|(D)D||',
'M|9|log|(D)D||',
'M|9|log10|(D)D||',
'M|9|pow|(DD)D||',
'M|9|exp|(D)D||',
'M|9|min|(FF)F||',
'M|9|min|(II)I||',
'M|9|min|(DD)D||',
'M|9|min|(JJ)J||',
'M|9|max|(FF)F||',
'M|9|max|(II)I||',
'M|9|max|(DD)D||',
'M|9|max|(JJ)J||',
'M|9|floor|(D)D||',
'M|9|ceil|(D)D||',
'M|9|rint|(D)D||',
'M|9|round|(F)I||',
'M|9|round|(D)J||',
'M|9|addExact|(JJ)J||',
'M|9|addExact|(II)I||',
'M|9|decrementExact|(I)I||',
'M|9|decrementExact|(J)J||',
'M|9|incrementExact|(J)J||',
'M|9|incrementExact|(I)I||',
'M|9|multiplyExact|(JJ)J||',
'M|9|multiplyExact|(JI)J||',
'M|9|multiplyExact|(II)I||',
'M|9|multiplyHigh|(JJ)J||',
'M|9|unsignedMultiplyHigh|(JJ)J||',
'M|9|negateExact|(I)I||',
'M|9|negateExact|(J)J||',
'M|9|subtractExact|(II)I||',
'M|9|subtractExact|(JJ)J||',
'M|9|fma|(DDD)D||',
'M|9|fma|(FFF)F||',
'M|9|copySign|(DD)D||',
'M|9|copySign|(FF)F||',
'M|9|signum|(F)F||',
'M|9|signum|(D)D||',
'M|9|clamp|(FFF)F||',
'M|9|clamp|(DDD)D||',
'M|9|clamp|(JJJ)J||',
'M|9|clamp|(JII)I||',
'M|9|scalb|(FI)F||',
'M|9|scalb|(DI)D||',
'M|9|getExponent|(F)I||',
'M|9|getExponent|(D)I||',
'M|9|floorMod|(JI)I||',
'M|9|floorMod|(II)I||',
'M|9|floorMod|(JJ)J||',
'M|9|asin|(D)D||',
'M|9|acos|(D)D||',
'M|9|atan|(D)D||',
'M|9|cbrt|(D)D||',
'M|9|IEEEremainder|(DD)D||',
'M|9|floorDiv|(II)I||',
'M|9|floorDiv|(JJ)J||',
'M|9|floorDiv|(JI)J||',
'M|9|ceilDiv|(JJ)J||',
'M|9|ceilDiv|(JI)J||',
'M|9|ceilDiv|(II)I||',
'M|9|ceilMod|(JJ)J||',
'M|9|ceilMod|(JI)I||',
'M|9|ceilMod|(II)I||',
'M|9|sinh|(D)D||',
'M|9|cosh|(D)D||',
'M|9|tanh|(D)D||',
'M|9|hypot|(DD)D||',
'M|9|expm1|(D)D||',
'M|9|log1p|(D)D||',
'M|9|toRadians|(D)D||',
'M|9|toDegrees|(D)D||',
'M|9|random|()D||',
'M|9|divideExact|(II)I||',
'M|9|divideExact|(JJ)J||',
'M|9|floorDivExact|(II)I||',
'M|9|floorDivExact|(JJ)J||',
'M|9|ceilDivExact|(JJ)J||',
'M|9|ceilDivExact|(II)I||',
'M|9|toIntExact|(J)I||',
'M|9|multiplyFull|(II)J||',
'M|9|absExact|(J)J||',
'M|9|absExact|(I)I||',
'M|9|ulp|(D)D||',
'M|9|ulp|(F)F||',
'M|9|nextAfter|(FD)F||',
'M|9|nextAfter|(DD)D||',
'M|9|nextUp|(D)D||',
'M|9|nextUp|(F)F||',
'M|9|nextDown|(F)F||',
'M|9|nextDown|(D)D||',
'C|17|java/lang/System|~O',
'F|25|in|~4InputStream;||',
'F|25|out|~4PrintStream;||',
'F|25|err|~4PrintStream;||',
'M|9|exit|(I)V||',
'M|9|runFinalization|()V||',
'M|9|getProperty|(~S)~S||',
'M|9|getProperty|(~S~S)~S||',
'M|265|identityHashCode|(~O)I||',
'M|265|currentTimeMillis|()J||',
'M|265|nanoTime|()J||',
'M|265|arraycopy|(~OI~OII)V||',
'M|9|load|(~S)V||',
'M|9|getSecurityManager|()~1SecurityManager;||',
'M|9|loadLibrary|(~S)V||',
'M|9|console|()~4Console;||',
'M|9|inheritedChannel|()Ljava/nio/channels/Channel;||java/io/IOException',
'M|9|setSecurityManager|(~1SecurityManager;)V||',
'M|9|lineSeparator|()~S||',
'M|9|setProperty|(~S~S)~S||',
'M|9|getenv|(~S)~S||',
'M|9|getenv|()~2Map;|()~2Map<~S~S>;|',
'M|9|getLogger|(~S~2ResourceBundle;)~1System$Logger;||',
'M|9|getLogger|(~S)~1System$Logger;||',
'M|9|gc|()V||',
'M|9|setIn|(~4InputStream;)V||',
'M|9|setOut|(~4PrintStream;)V||',
'M|9|setErr|(~4PrintStream;)V||',
'M|9|getProperties|()~2Properties;||',
'M|9|setProperties|(~2Properties;)V||',
'M|9|clearProperty|(~S)~S||',
'M|265|mapLibraryName|(~S)~S||',
'C|17|java/lang/Integer|~1Number;~1Comparable<~1Integer;>;~1constant/Constable;~1constant/ConstantDesc;',
'F|25|MIN_VALUE|I||I-2147483648',
'F|25|MAX_VALUE|I||I2147483647',
'F|25|TYPE|~1Class;|~1Class<~1Integer;>;|',
'F|25|SIZE|I||I32',
'F|25|BYTES|I||I4',
'M|1|<init>|(~S)V||java/lang/NumberFormatException',
'M|1|<init>|(I)V||',
'M|9|numberOfLeadingZeros|(I)I||',
'M|9|numberOfTrailingZeros|(I)I||',
'M|9|bitCount|(I)I||',
'M|1|equals|(~O)Z||',
'M|9|toString|(I)~S||',
'M|1|toString|()~S||',
'M|9|toString|(II)~S||',
'M|1|hashCode|()I||',
'M|9|hashCode|(I)I||',
'M|9|min|(II)I||',
'M|9|max|(II)I||',
'M|9|signum|(I)I||',
'M|9|expand|(II)I||',
'M|9|compareUnsigned|(II)I||',
'M|9|divideUnsigned|(II)I||',
'M|9|remainderUnsigned|(II)I||',
'M|9|reverse|(I)I||',
'M|9|reverseBytes|(I)I||',
'M|9|compress|(II)I||',
'M|1|compareTo|(~1Integer;)I||',
'M|9|compare|(II)I||',
'M|1|byteValue|()B||',
'M|1|shortValue|()S||',
'M|1|intValue|()I||',
'M|1|longValue|()J||',
'M|1|floatValue|()F||',
'M|1|doubleValue|()D||',
'M|9|valueOf|(~S)~1Integer;||java/lang/NumberFormatException',
'M|9|valueOf|(I)~1Integer;||',
'M|9|valueOf|(~SI)~1Integer;||java/lang/NumberFormatException',
'M|9|toHexString|(I)~S||',
'M|9|decode|(~S)~1Integer;||java/lang/NumberFormatException',
'M|1|resolveConstantDesc|(~1invoke/MethodHandles$Lookup;)~1Integer;||',
'M|1|describeConstable|()~2Optional;|()~2Optional<~1Integer;>;|',
'M|9|parseInt|(~1CharSequence;III)I||java/lang/NumberFormatException',
'M|9|parseInt|(~S)I||java/lang/NumberFormatException',
'M|9|parseInt|(~SI)I||java/lang/NumberFormatException',
'M|9|toUnsignedLong|(I)J||',
'M|9|sum|(II)I||',
'M|9|toUnsignedString|(II)~S||',
'M|9|toUnsignedString|(I)~S||',
'M|9|parseUnsignedInt|(~SI)I||java/lang/NumberFormatException',
'M|9|parseUnsignedInt|(~1CharSequence;III)I||java/lang/NumberFormatException',
'M|9|parseUnsignedInt|(~S)I||java/lang/NumberFormatException',
'M|9|getInteger|(~S~1Integer;)~1Integer;||',
'M|9|getInteger|(~S)~1Integer;||',
'M|9|getInteger|(~SI)~1Integer;||',
'M|9|toOctalString|(I)~S||',
'M|9|toBinaryString|(I)~S||',
'M|9|highestOneBit|(I)I||',
'M|9|lowestOneBit|(I)I||',
'M|9|rotateLeft|(II)I||',
'M|9|rotateRight|(II)I||',
'C|17|java/lang/Long|~1Number;~1Comparable<~1Long;>;~1constant/Constable;~1constant/ConstantDesc;',
'F|25|MIN_VALUE|J||J-9223372036854775808',
'F|25|MAX_VALUE|J||J9223372036854775807',
'F|25|TYPE|~1Class;|~1Class<~1Long;>;|',
'F|25|SIZE|I||I64',
'F|25|BYTES|I||I8',
'M|1|<init>|(~S)V||java/lang/NumberFormatException',
'M|1|<init>|(J)V||',
'M|9|numberOfLeadingZeros|(J)I||',
'M|9|numberOfTrailingZeros|(J)I||',
'M|9|bitCount|(J)I||',
'M|1|equals|(~O)Z||',
'M|9|toString|(J)~S||',
'M|9|toString|(JI)~S||',
'M|1|toString|()~S||',
'M|9|hashCode|(J)I||',
'M|1|hashCode|()I||',
'M|9|min|(JJ)J||',
'M|9|max|(JJ)J||',
'M|9|signum|(J)I||',
'M|9|expand|(JJ)J||',
'M|9|compareUnsigned|(JJ)I||',
'M|9|divideUnsigned|(JJ)J||',
'M|9|remainderUnsigned|(JJ)J||',
'M|9|reverse|(J)J||',
'M|9|reverseBytes|(J)J||',
'M|9|compress|(JJ)J||',
'M|1|compareTo|(~1Long;)I||',
'M|9|getLong|(~SJ)~1Long;||',
'M|9|getLong|(~S~1Long;)~1Long;||',
'M|9|getLong|(~S)~1Long;||',
'M|9|compare|(JJ)I||',
'M|1|byteValue|()B||',
'M|1|shortValue|()S||',
'M|1|intValue|()I||',
'M|1|longValue|()J||',
'M|1|floatValue|()F||',
'M|1|doubleValue|()D||',
'M|9|valueOf|(J)~1Long;||',
'M|9|valueOf|(~S)~1Long;||java/lang/NumberFormatException',
'M|9|valueOf|(~SI)~1Long;||java/lang/NumberFormatException',
'M|9|toHexString|(J)~S||',
'M|9|decode|(~S)~1Long;||java/lang/NumberFormatException',
'M|1|resolveConstantDesc|(~1invoke/MethodHandles$Lookup;)~1Long;||',
'M|1|describeConstable|()~2Optional;|()~2Optional<~1Long;>;|',
'M|9|parseLong|(~SI)J||java/lang/NumberFormatException',
'M|9|parseLong|(~1CharSequence;III)J||java/lang/NumberFormatException',
'M|9|parseLong|(~S)J||java/lang/NumberFormatException',
'M|9|sum|(JJ)J||',
'M|9|toUnsignedString|(J)~S||',
'M|9|toUnsignedString|(JI)~S||',
'M|9|toOctalString|(J)~S||',
'M|9|toBinaryString|(J)~S||',
'M|9|highestOneBit|(J)J||',
'M|9|lowestOneBit|(J)J||',
'M|9|rotateLeft|(JI)J||',
'M|9|rotateRight|(JI)J||',
'M|9|parseUnsignedLong|(~SI)J||java/lang/NumberFormatException',
'M|9|parseUnsignedLong|(~1CharSequence;III)J||java/lang/NumberFormatException',
'M|9|parseUnsignedLong|(~S)J||java/lang/NumberFormatException',
'C|17|java/lang/Double|~1Number;~1Comparable<~1Double;>;~1constant/Constable;~1constant/ConstantDesc;',
'F|25|POSITIVE_INFINITY|D||D9218868437227405312',
'F|25|NEGATIVE_INFINITY|D||D-4503599627370496',
'F|25|NaN|D||D9221120237041090560',
'F|25|MAX_VALUE|D||D9218868437227405311',
'F|25|MIN_NORMAL|D||D4503599627370496',
'F|25|MIN_VALUE|D||D1',
'F|25|SIZE|I||I64',
'F|25|PRECISION|I||I53',
'F|25|MAX_EXPONENT|I||I1023',
'F|25|MIN_EXPONENT|I||I-1022',
'F|25|BYTES|I||I8',
'F|25|TYPE|~1Class;|~1Class<~1Double;>;|',
'M|1|<init>|(D)V||',
'M|1|<init>|(~S)V||java/lang/NumberFormatException',
'M|1|equals|(~O)Z||',
'M|9|toString|(D)~S||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|9|hashCode|(D)I||',
'M|9|min|(DD)D||',
'M|9|max|(DD)D||',
'M|1|isInfinite|()Z||',
'M|9|isInfinite|(D)Z||',
'M|9|isFinite|(D)Z||',
'M|265|doubleToRawLongBits|(D)J||',
'M|9|doubleToLongBits|(D)J||',
'M|265|longBitsToDouble|(J)D||',
'M|1|compareTo|(~1Double;)I||',
'M|9|compare|(DD)I||',
'M|1|byteValue|()B||',
'M|1|shortValue|()S||',
'M|1|intValue|()I||',
'M|1|longValue|()J||',
'M|1|floatValue|()F||',
'M|1|doubleValue|()D||',
'M|9|valueOf|(~S)~1Double;||java/lang/NumberFormatException',
'M|9|valueOf|(D)~1Double;||',
'M|9|toHexString|(D)~S||',
'M|1|resolveConstantDesc|(~1invoke/MethodHandles$Lookup;)~1Double;||',
'M|1|describeConstable|()~2Optional;|()~2Optional<~1Double;>;|',
'M|1|isNaN|()Z||',
'M|9|isNaN|(D)Z||',
'M|9|sum|(DD)D||',
'M|9|parseDouble|(~S)D||java/lang/NumberFormatException',
'C|17|java/lang/Float|~1Number;~1Comparable<~1Float;>;~1constant/Constable;~1constant/ConstantDesc;',
'F|25|POSITIVE_INFINITY|F||F2139095040',
'F|25|NEGATIVE_INFINITY|F||F-8388608',
'F|25|NaN|F||F2143289344',
'F|25|MAX_VALUE|F||F2139095039',
'F|25|MIN_NORMAL|F||F8388608',
'F|25|MIN_VALUE|F||F1',
'F|25|SIZE|I||I32',
'F|25|PRECISION|I||I24',
'F|25|MAX_EXPONENT|I||I127',
'F|25|MIN_EXPONENT|I||I-126',
'F|25|BYTES|I||I4',
'F|25|TYPE|~1Class;|~1Class<~1Float;>;|',
'M|1|<init>|(~S)V||java/lang/NumberFormatException',
'M|1|<init>|(D)V||',
'M|1|<init>|(F)V||',
'M|1|equals|(~O)Z||',
'M|9|toString|(F)~S||',
'M|1|toString|()~S||',
'M|9|hashCode|(F)I||',
'M|1|hashCode|()I||',
'M|9|min|(FF)F||',
'M|9|max|(FF)F||',
'M|9|isInfinite|(F)Z||',
'M|1|isInfinite|()Z||',
'M|9|isFinite|(F)Z||',
'M|265|floatToRawIntBits|(F)I||',
'M|9|floatToIntBits|(F)I||',
'M|265|intBitsToFloat|(I)F||',
'M|9|float16ToFloat|(S)F||',
'M|9|floatToFloat16|(F)S||',
'M|1|compareTo|(~1Float;)I||',
'M|9|compare|(FF)I||',
'M|1|byteValue|()B||',
'M|1|shortValue|()S||',
'M|1|intValue|()I||',
'M|1|longValue|()J||',
'M|1|floatValue|()F||',
'M|1|doubleValue|()D||',
'M|9|valueOf|(F)~1Float;||',
'M|9|valueOf|(~S)~1Float;||java/lang/NumberFormatException',
'M|9|toHexString|(F)~S||',
'M|1|resolveConstantDesc|(~1invoke/MethodHandles$Lookup;)~1Float;||',
'M|1|describeConstable|()~2Optional;|()~2Optional<~1Float;>;|',
'M|9|isNaN|(F)Z||',
'M|1|isNaN|()Z||',
'M|9|sum|(FF)F||',
'M|9|parseFloat|(~S)F||java/lang/NumberFormatException',
'C|17|java/lang/Short|~1Number;~1Comparable<~1Short;>;~1constant/Constable;',
'F|25|MIN_VALUE|S||I-32768',
'F|25|MAX_VALUE|S||I32767',
'F|25|TYPE|~1Class;|~1Class<~1Short;>;|',
'F|25|SIZE|I||I16',
'F|25|BYTES|I||I2',
'M|1|<init>|(S)V||',
'M|1|<init>|(~S)V||java/lang/NumberFormatException',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|9|toString|(S)~S||',
'M|9|hashCode|(S)I||',
'M|1|hashCode|()I||',
'M|9|compareUnsigned|(SS)I||',
'M|9|reverseBytes|(S)S||',
'M|1|compareTo|(~1Short;)I||',
'M|9|compare|(SS)I||',
'M|1|byteValue|()B||',
'M|1|shortValue|()S||',
'M|1|intValue|()I||',
'M|1|longValue|()J||',
'M|1|floatValue|()F||',
'M|1|doubleValue|()D||',
'M|9|valueOf|(~SI)~1Short;||java/lang/NumberFormatException',
'M|9|valueOf|(~S)~1Short;||java/lang/NumberFormatException',
'M|9|valueOf|(S)~1Short;||',
'M|9|decode|(~S)~1Short;||java/lang/NumberFormatException',
'M|1|describeConstable|()~2Optional;|()~2Optional<~1constant/DynamicConstantDesc<~1Short;>;>;|',
'M|9|toUnsignedLong|(S)J||',
'M|9|toUnsignedInt|(S)I||',
'M|9|parseShort|(~S)S||java/lang/NumberFormatException',
'M|9|parseShort|(~SI)S||java/lang/NumberFormatException',
'C|17|java/lang/Byte|~1Number;~1Comparable<~1Byte;>;~1constant/Constable;',
'F|25|MIN_VALUE|B||I-128',
'F|25|MAX_VALUE|B||I127',
'F|25|TYPE|~1Class;|~1Class<~1Byte;>;|',
'F|25|SIZE|I||I8',
'F|25|BYTES|I||I1',
'M|1|<init>|(B)V||',
'M|1|<init>|(~S)V||java/lang/NumberFormatException',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|9|toString|(B)~S||',
'M|9|hashCode|(B)I||',
'M|1|hashCode|()I||',
'M|9|compareUnsigned|(BB)I||',
'M|1|compareTo|(~1Byte;)I||',
'M|9|compare|(BB)I||',
'M|1|byteValue|()B||',
'M|1|shortValue|()S||',
'M|1|intValue|()I||',
'M|1|longValue|()J||',
'M|1|floatValue|()F||',
'M|1|doubleValue|()D||',
'M|9|valueOf|(~S)~1Byte;||java/lang/NumberFormatException',
'M|9|valueOf|(~SI)~1Byte;||java/lang/NumberFormatException',
'M|9|valueOf|(B)~1Byte;||',
'M|9|decode|(~S)~1Byte;||java/lang/NumberFormatException',
'M|1|describeConstable|()~2Optional;|()~2Optional<~1constant/DynamicConstantDesc<~1Byte;>;>;|',
'M|9|toUnsignedLong|(B)J||',
'M|9|toUnsignedInt|(B)I||',
'M|9|parseByte|(~S)B||java/lang/NumberFormatException',
'M|9|parseByte|(~SI)B||java/lang/NumberFormatException',
'C|17|java/lang/Character|~O~4Serializable;~1Comparable<~1Character;>;~1constant/Constable;',
'F|25|MIN_RADIX|I||I2',
'F|25|MAX_RADIX|I||I36',
'F|25|MIN_VALUE|C||C0',
'F|25|MAX_VALUE|C||C65535',
'F|25|TYPE|~1Class;|~1Class<~1Character;>;|',
'F|25|UNASSIGNED|B||I0',
'F|25|UPPERCASE_LETTER|B||I1',
'F|25|LOWERCASE_LETTER|B||I2',
'F|25|TITLECASE_LETTER|B||I3',
'F|25|MODIFIER_LETTER|B||I4',
'F|25|OTHER_LETTER|B||I5',
'F|25|NON_SPACING_MARK|B||I6',
'F|25|ENCLOSING_MARK|B||I7',
'F|25|COMBINING_SPACING_MARK|B||I8',
'F|25|DECIMAL_DIGIT_NUMBER|B||I9',
'F|25|LETTER_NUMBER|B||I10',
'F|25|OTHER_NUMBER|B||I11',
'F|25|SPACE_SEPARATOR|B||I12',
'F|25|LINE_SEPARATOR|B||I13',
'F|25|PARAGRAPH_SEPARATOR|B||I14',
'F|25|CONTROL|B||I15',
'F|25|FORMAT|B||I16',
'F|25|PRIVATE_USE|B||I18',
'F|25|SURROGATE|B||I19',
'F|25|DASH_PUNCTUATION|B||I20',
'F|25|START_PUNCTUATION|B||I21',
'F|25|END_PUNCTUATION|B||I22',
'F|25|CONNECTOR_PUNCTUATION|B||I23',
'F|25|OTHER_PUNCTUATION|B||I24',
'F|25|MATH_SYMBOL|B||I25',
'F|25|CURRENCY_SYMBOL|B||I26',
'F|25|MODIFIER_SYMBOL|B||I27',
'F|25|OTHER_SYMBOL|B||I28',
'F|25|INITIAL_QUOTE_PUNCTUATION|B||I29',
'F|25|FINAL_QUOTE_PUNCTUATION|B||I30',
'F|25|DIRECTIONALITY_UNDEFINED|B||I-1',
'F|25|DIRECTIONALITY_LEFT_TO_RIGHT|B||I0',
'F|25|DIRECTIONALITY_RIGHT_TO_LEFT|B||I1',
'F|25|DIRECTIONALITY_RIGHT_TO_LEFT_ARABIC|B||I2',
'F|25|DIRECTIONALITY_EUROPEAN_NUMBER|B||I3',
'F|25|DIRECTIONALITY_EUROPEAN_NUMBER_SEPARATOR|B||I4',
'F|25|DIRECTIONALITY_EUROPEAN_NUMBER_TERMINATOR|B||I5',
'F|25|DIRECTIONALITY_ARABIC_NUMBER|B||I6',
'F|25|DIRECTIONALITY_COMMON_NUMBER_SEPARATOR|B||I7',
'F|25|DIRECTIONALITY_NONSPACING_MARK|B||I8',
'F|25|DIRECTIONALITY_BOUNDARY_NEUTRAL|B||I9',
'F|25|DIRECTIONALITY_PARAGRAPH_SEPARATOR|B||I10',
'F|25|DIRECTIONALITY_SEGMENT_SEPARATOR|B||I11',
'F|25|DIRECTIONALITY_WHITESPACE|B||I12',
'F|25|DIRECTIONALITY_OTHER_NEUTRALS|B||I13',
'F|25|DIRECTIONALITY_LEFT_TO_RIGHT_EMBEDDING|B||I14',
'F|25|DIRECTIONALITY_LEFT_TO_RIGHT_OVERRIDE|B||I15',
'F|25|DIRECTIONALITY_RIGHT_TO_LEFT_EMBEDDING|B||I16',
'F|25|DIRECTIONALITY_RIGHT_TO_LEFT_OVERRIDE|B||I17',
'F|25|DIRECTIONALITY_POP_DIRECTIONAL_FORMAT|B||I18',
'F|25|DIRECTIONALITY_LEFT_TO_RIGHT_ISOLATE|B||I19',
'F|25|DIRECTIONALITY_RIGHT_TO_LEFT_ISOLATE|B||I20',
'F|25|DIRECTIONALITY_FIRST_STRONG_ISOLATE|B||I21',
'F|25|DIRECTIONALITY_POP_DIRECTIONAL_ISOLATE|B||I22',
'F|25|MIN_HIGH_SURROGATE|C||C55296',
'F|25|MAX_HIGH_SURROGATE|C||C56319',
'F|25|MIN_LOW_SURROGATE|C||C56320',
'F|25|MAX_LOW_SURROGATE|C||C57343',
'F|25|MIN_SURROGATE|C||C55296',
'F|25|MAX_SURROGATE|C||C57343',
'F|25|MIN_SUPPLEMENTARY_CODE_POINT|I||I65536',
'F|25|MIN_CODE_POINT|I||I0',
'F|25|MAX_CODE_POINT|I||I1114111',
'F|25|SIZE|I||I16',
'F|25|BYTES|I||I2',
'M|1|<init>|(C)V||',
'M|9|getName|(I)~S||',
'M|9|isJavaIdentifierStart|(C)Z||',
'M|9|isJavaIdentifierStart|(I)Z||',
'M|9|isJavaIdentifierPart|(C)Z||',
'M|9|isJavaIdentifierPart|(I)Z||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|9|toString|(I)~S||',
'M|9|toString|(C)~S||',
'M|1|hashCode|()I||',
'M|9|hashCode|(C)I||',
'M|9|reverseBytes|(C)C||',
'M|1|compareTo|(~1Character;)I||',
'M|9|isDigit|(C)Z||',
'M|9|isDigit|(I)Z||',
'M|9|isLowerCase|(C)Z||',
'M|9|isLowerCase|(I)Z||',
'M|9|isUpperCase|(I)Z||',
'M|9|isUpperCase|(C)Z||',
'M|9|isWhitespace|(C)Z||',
'M|9|isWhitespace|(I)Z||',
'M|9|compare|(CC)I||',
'M|1|charValue|()C||',
'M|9|valueOf|(C)~1Character;||',
'M|9|toChars|(I)[C||',
'M|9|toChars|(I[CI)I||',
'M|9|isHighSurrogate|(C)Z||',
'M|9|isLowSurrogate|(C)Z||',
'M|9|isSurrogate|(C)Z||',
'M|9|isSupplementaryCodePoint|(I)Z||',
'M|9|highSurrogate|(I)C||',
'M|9|lowSurrogate|(I)C||',
'M|9|toCodePoint|(CC)I||',
'M|9|codePointAt|(~1CharSequence;I)I||',
'M|9|codePointAt|([CII)I||',
'M|9|codePointAt|([CI)I||',
'M|9|codePointBefore|(~1CharSequence;I)I||',
'M|9|codePointBefore|([CI)I||',
'M|9|codePointBefore|([CII)I||',
'M|9|codePointCount|(~1CharSequence;II)I||',
'M|9|codePointCount|([CII)I||',
'M|9|offsetByCodePoints|([CIIII)I||',
'M|9|offsetByCodePoints|(~1CharSequence;II)I||',
'M|9|toLowerCase|(C)C||',
'M|9|toLowerCase|(I)I||',
'M|9|toUpperCase|(I)I||',
'M|9|toUpperCase|(C)C||',
'M|9|isBmpCodePoint|(I)Z||',
'M|1|describeConstable|()~2Optional;|()~2Optional<~1constant/DynamicConstantDesc<~1Character;>;>;|',
'M|9|getType|(C)I||',
'M|9|getType|(I)I||',
'M|9|isLetter|(C)Z||',
'M|9|isLetter|(I)Z||',
'M|9|isLetterOrDigit|(I)Z||',
'M|9|isLetterOrDigit|(C)Z||',
'M|9|isValidCodePoint|(I)Z||',
'M|9|isTitleCase|(I)Z||',
'M|9|isTitleCase|(C)Z||',
'M|9|isDefined|(C)Z||',
'M|9|isDefined|(I)Z||',
'M|9|isIdeographic|(I)Z||',
'M|9|isUnicodeIdentifierStart|(I)Z||',
'M|9|isUnicodeIdentifierStart|(C)Z||',
'M|9|isUnicodeIdentifierPart|(I)Z||',
'M|9|isUnicodeIdentifierPart|(C)Z||',
'M|9|isIdentifierIgnorable|(I)Z||',
'M|9|isIdentifierIgnorable|(C)Z||',
'M|9|isEmoji|(I)Z||',
'M|9|isEmojiPresentation|(I)Z||',
'M|9|isEmojiModifier|(I)Z||',
'M|9|isEmojiModifierBase|(I)Z||',
'M|9|isEmojiComponent|(I)Z||',
'M|9|isExtendedPictographic|(I)Z||',
'M|9|toTitleCase|(C)C||',
'M|9|toTitleCase|(I)I||',
'M|9|digit|(CI)I||',
'M|9|digit|(II)I||',
'M|9|getNumericValue|(I)I||',
'M|9|getNumericValue|(C)I||',
'M|9|isSpaceChar|(C)Z||',
'M|9|isSpaceChar|(I)Z||',
'M|9|isISOControl|(I)Z||',
'M|9|isISOControl|(C)Z||',
'M|9|getDirectionality|(C)B||',
'M|9|getDirectionality|(I)B||',
'M|9|isMirrored|(C)Z||',
'M|9|isMirrored|(I)Z||',
'M|9|isSurrogatePair|(CC)Z||',
'M|9|charCount|(I)I||',
'M|9|isJavaLetter|(C)Z||',
'M|9|isJavaLetterOrDigit|(C)Z||',
'M|9|isAlphabetic|(I)Z||',
'M|9|isSpace|(C)Z||',
'M|9|forDigit|(II)C||',
'M|9|codePointOf|(~S)I||',
'C|17|java/lang/Boolean|~O~4Serializable;~1Comparable<~1Boolean;>;~1constant/Constable;',
'F|25|TRUE|~1Boolean;||',
'F|25|FALSE|~1Boolean;||',
'F|25|TYPE|~1Class;|~1Class<~1Boolean;>;|',
'M|1|<init>|(Z)V||',
'M|1|<init>|(~S)V||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|9|toString|(Z)~S||',
'M|1|hashCode|()I||',
'M|9|hashCode|(Z)I||',
'M|1|compareTo|(~1Boolean;)I||',
'M|9|getBoolean|(~S)Z||',
'M|9|compare|(ZZ)I||',
'M|1|booleanValue|()Z||',
'M|9|valueOf|(~S)~1Boolean;||',
'M|9|valueOf|(Z)~1Boolean;||',
'M|1|describeConstable|()~2Optional;|()~2Optional<~1constant/DynamicConstantDesc<~1Boolean;>;>;|',
'M|9|parseBoolean|(~S)Z||',
'M|9|logicalAnd|(ZZ)Z||',
'M|9|logicalOr|(ZZ)Z||',
'M|9|logicalXor|(ZZ)Z||',
'C|1025|java/lang/Number|~O~4Serializable;',
'M|1|<init>|()V||',
'M|1|byteValue|()B||',
'M|1|shortValue|()S||',
'M|1025|intValue|()I||',
'M|1025|longValue|()J||',
'M|1025|floatValue|()F||',
'M|1025|doubleValue|()D||',
'C|17|java/lang/Void|~O',
'F|25|TYPE|~1Class;|~1Class<~1Void;>;|',
'C|1025|java/lang/Enum|<E:~1Enum<TE;>;>~O~1constant/Constable;~1Comparable<TE;>;~4Serializable;',
'M|4|<init>|(~SI)V||',
'M|17|name|()~S||',
'M|20|finalize|()V||',
'M|17|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|17|hashCode|()I||',
'M|20|clone|()~O||java/lang/CloneNotSupportedException',
'M|17|compareTo|(~1Enum;)I|(TE;)I|',
'M|9|valueOf|(~1Class;~S)~1Enum;|<T:~1Enum<TT;>;>(~1Class<TT;>;~S)TT;|',
'M|17|describeConstable|()~2Optional;|()~2Optional<~1Enum$EnumDesc<TE;>;>;|',
'M|17|getDeclaringClass|()~1Class;|()~1Class<TE;>;|',
'M|17|ordinal|()I||',
'C|1025|java/lang/Record|~O',
'M|4|<init>|()V||',
'M|1025|equals|(~O)Z||',
'M|1025|toString|()~S||',
'M|1025|hashCode|()I||',
'C|1|java/lang/Thread|~O~1Runnable;',
'F|25|MIN_PRIORITY|I||I1',
'F|25|NORM_PRIORITY|I||I5',
'F|25|MAX_PRIORITY|I||I10',
'M|1|<init>|()V||',
'M|1|<init>|(~1Runnable;)V||',
'M|1|<init>|(~1ThreadGroup;~1Runnable;~SJZ)V||',
'M|1|<init>|(~1ThreadGroup;~1Runnable;~SJ)V||',
'M|1|<init>|(~1ThreadGroup;~1Runnable;~S)V||',
'M|1|<init>|(~1Runnable;~S)V||',
'M|1|<init>|(~1ThreadGroup;~1Runnable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|(~1ThreadGroup;~S)V||',
'M|17|getName|()~S||',
'M|1|getStackTrace|()[~1StackTraceElement;||',
'M|1|run|()V||',
'M|1|interrupt|()V||',
'M|1|toString|()~S||',
'M|4|clone|()~O||java/lang/CloneNotSupportedException',
'M|265|currentThread|()~1Thread;||',
'M|9|onSpinWait|()V||',
'M|17|isVirtual|()Z||',
'M|17|join|(J)V||java/lang/InterruptedException',
'M|17|join|(JI)V||java/lang/InterruptedException',
'M|17|join|()V||java/lang/InterruptedException',
'M|17|join|(Ljava/time/Duration;)Z||java/lang/InterruptedException',
'M|1|setContextClassLoader|(~1ClassLoader;)V||',
'M|17|getThreadGroup|()~1ThreadGroup;||',
'M|17|checkAccess|()V||',
'M|9|dumpStack|()V||',
'M|17|setPriority|(I)V||',
'M|17|setDaemon|(Z)V||',
'M|1|start|()V||',
'M|1|getContextClassLoader|()~1ClassLoader;||',
'M|17|getPriority|()I||',
'M|17|isDaemon|()Z||',
'M|9|interrupted|()Z||',
'M|9|activeCount|()I||',
'M|9|enumerate|([~1Thread;)I||',
'M|17|isAlive|()Z||',
'M|17|threadId|()J||',
'M|9|setDefaultUncaughtExceptionHandler|(~1Thread$UncaughtExceptionHandler;)V||',
'M|1|getUncaughtExceptionHandler|()~1Thread$UncaughtExceptionHandler;||',
'M|9|yield|()V||',
'M|9|sleep|(JI)V||java/lang/InterruptedException',
'M|9|sleep|(Ljava/time/Duration;)V||java/lang/InterruptedException',
'M|9|sleep|(J)V||java/lang/InterruptedException',
'M|9|ofPlatform|()~1Thread$Builder$OfPlatform;||',
'M|9|ofVirtual|()~1Thread$Builder$OfVirtual;||',
'M|9|startVirtualThread|(~1Runnable;)~1Thread;||',
'M|17|stop|()V||',
'M|1|isInterrupted|()Z||',
'M|17|suspend|()V||',
'M|17|resume|()V||',
'M|49|setName|(~S)V||',
'M|1|countStackFrames|()I||',
'M|265|holdsLock|(~O)Z||',
'M|9|getAllStackTraces|()~2Map;|()~2Map<~1Thread;[~1StackTraceElement;>;|',
'M|1|getId|()J||',
'M|1|getState|()~1Thread$State;||',
'M|9|getDefaultUncaughtExceptionHandler|()~1Thread$UncaughtExceptionHandler;||',
'M|1|setUncaughtExceptionHandler|(~1Thread$UncaughtExceptionHandler;)V||',
'C|16401|java/lang/Thread$State|~1Enum<~1Thread$State;>;',
'F|16409|NEW|~1Thread$State;||',
'F|16409|RUNNABLE|~1Thread$State;||',
'F|16409|BLOCKED|~1Thread$State;||',
'F|16409|WAITING|~1Thread$State;||',
'F|16409|TIMED_WAITING|~1Thread$State;||',
'F|16409|TERMINATED|~1Thread$State;||',
'C|1537|java/lang/Thread$UncaughtExceptionHandler|~O',
'M|1025|uncaughtException|(~1Thread;~1Throwable;)V||',
'C|1|java/lang/ThreadLocal|<T:~O>~O',
'M|1|<init>|()V||',
'M|1|remove|()V||',
'M|1|get|()~O|()TT;|',
'M|1|set|(~O)V|(TT;)V|',
'M|4|initialValue|()~O|()TT;|',
'M|9|withInitial|(~3Supplier;)~1ThreadLocal;|<S:~O>(~3Supplier<+TS;>;)~1ThreadLocal<TS;>;|',
'C|1|java/lang/Throwable|~O~4Serializable;',
'M|4|<init>|(~S~1Throwable;ZZ)V||',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'M|1|printStackTrace|(~4PrintWriter;)V||',
'M|1|printStackTrace|()V||',
'M|1|printStackTrace|(~4PrintStream;)V||',
'M|1|getStackTrace|()[~1StackTraceElement;||',
'M|33|fillInStackTrace|()~1Throwable;||',
'M|33|getCause|()~1Throwable;||',
'M|33|initCause|(~1Throwable;)~1Throwable;||',
'M|1|toString|()~S||',
'M|1|getMessage|()~S||',
'M|49|getSuppressed|()[~1Throwable;||',
'M|1|getLocalizedMessage|()~S||',
'M|1|setStackTrace|([~1StackTraceElement;)V||',
'M|49|addSuppressed|(~1Throwable;)V||',
'C|1|java/lang/Exception|~1Throwable;',
'M|4|<init>|(~S~1Throwable;ZZ)V||',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'C|1|java/lang/RuntimeException|~1Exception;',
'M|4|<init>|(~S~1Throwable;ZZ)V||',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'C|1|java/lang/Error|~1Throwable;',
'M|4|<init>|(~S~1Throwable;ZZ)V||',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'C|1|java/lang/IllegalArgumentException|~1RuntimeException;',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'C|1|java/lang/IllegalStateException|~1RuntimeException;',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'C|1|java/lang/ArithmeticException|~1RuntimeException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/lang/NullPointerException|~1RuntimeException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'M|33|fillInStackTrace|()~1Throwable;||',
'M|1|getMessage|()~S||',
'C|1|java/lang/ArrayIndexOutOfBoundsException|~1IndexOutOfBoundsException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|(I)V||',
'C|1|java/lang/IndexOutOfBoundsException|~1RuntimeException;',
'M|1|<init>|(J)V||',
'M|1|<init>|(I)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'C|1|java/lang/StringIndexOutOfBoundsException|~1IndexOutOfBoundsException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|(I)V||',
'C|1|java/lang/ClassCastException|~1RuntimeException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/lang/NumberFormatException|~1IllegalArgumentException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/lang/UnsupportedOperationException|~1RuntimeException;',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'C|1|java/lang/StackOverflowError|~1VirtualMachineError;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/lang/OutOfMemoryError|~1VirtualMachineError;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1025|java/lang/VirtualMachineError|~1Error;',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'C|1|java/lang/LinkageError|~1Error;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'C|1|java/lang/InterruptedException|~1Exception;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/lang/CloneNotSupportedException|~1Exception;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/lang/ArrayStoreException|~1RuntimeException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/lang/NegativeArraySizeException|~1RuntimeException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/lang/SecurityException|~1RuntimeException;',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'C|1|java/lang/AssertionError|~1Error;',
'M|1|<init>|(I)V||',
'M|1|<init>|(J)V||',
'M|1|<init>|(F)V||',
'M|1|<init>|(D)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|()V||',
'M|1|<init>|(~O)V||',
'M|1|<init>|(Z)V||',
'M|1|<init>|(C)V||',
'C|1|java/lang/ReflectiveOperationException|~1Exception;',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'C|1|java/lang/ClassNotFoundException|~1ReflectiveOperationException;',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'M|1|getException|()~1Throwable;||',
'C|1|java/lang/NoSuchMethodException|~1ReflectiveOperationException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/lang/NoSuchFieldException|~1ReflectiveOperationException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/lang/IllegalAccessException|~1ReflectiveOperationException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/lang/InstantiationException|~1ReflectiveOperationException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/lang/ExceptionInInitializerError|~1LinkageError;',
'M|1|<init>|(~S)V||',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|()V||',
'M|1|getException|()~1Throwable;||',
'C|1|java/lang/InternalError|~1VirtualMachineError;',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'C|17|java/lang/Class|<T:~O>~O~4Serializable;~1reflect/GenericDeclaration;~1reflect/Type;~1reflect/AnnotatedElement;~1invoke/TypeDescriptor$OfField<~1Class<*>;>;~1constant/Constable;',
'M|1|getName|()~S||',
'M|9|forName|(~SZ~1ClassLoader;)~1Class;|(~SZ~1ClassLoader;)~1Class<*>;|java/lang/ClassNotFoundException',
'M|9|forName|(~1Module;~S)~1Class;|(~1Module;~S)~1Class<*>;|',
'M|9|forName|(~S)~1Class;|(~S)~1Class<*>;|java/lang/ClassNotFoundException',
'M|1|toString|()~S||',
'M|1|getModule|()~1Module;||',
'M|1|getProtectionDomain|()Ljava/security/ProtectionDomain;||',
'M|257|isAssignableFrom|(~1Class;)Z|(~1Class<*>;)Z|',
'M|257|isInstance|(~O)Z||',
'M|257|getModifiers|()I||',
'M|257|isInterface|()Z||',
'M|257|isArray|()Z||',
'M|257|isPrimitive|()Z||',
'M|257|isHidden|()Z||',
'M|257|getSuperclass|()~1Class;|()~1Class<-TT;>;|',
'M|1|cast|(~O)~O|(~O)TT;|',
'M|1|componentType|()~1Class;|()~1Class<*>;|',
'M|1|describeConstable|()~2Optional;|()~2Optional<~1constant/ClassDesc;>;|',
'M|1|getComponentType|()~1Class;|()~1Class<*>;|',
'M|1|isAnnotation|()Z||',
'M|1|isEnum|()Z||',
'M|1|isRecord|()Z||',
'M|1|getTypeParameters|()[~1reflect/TypeVariable;|()[~1reflect/TypeVariable<~1Class<TT;>;>;|',
'M|1|getClassLoader|()~1ClassLoader;||',
'M|1|newInstance|()~O|()TT;|java/lang/InstantiationException,java/lang/IllegalAccessException',
'M|1|getInterfaces|()[~1Class;|()[~1Class<*>;|',
'M|1|isMemberClass|()Z||',
'M|1|isLocalClass|()Z||',
'M|1|isAnonymousClass|()Z||',
'M|1|getEnclosingClass|()~1Class;|()~1Class<*>;|java/lang/SecurityException',
'M|1|isUnnamedClass|()Z||',
'M|1|getSimpleName|()~S||',
'M|1|getCanonicalName|()~S||',
'M|1|isSynthetic|()Z||',
'M|1|getResourceAsStream|(~S)~4InputStream;||',
'M|1|getResource|(~S)Ljava/net/URL;||',
'M|1|getPackageName|()~S||',
'M|1|desiredAssertionStatus|()Z||',
'M|129|getMethod|(~S[~1Class;)~1reflect/Method;|(~S[~1Class<*>;)~1reflect/Method;|java/lang/NoSuchMethodException,java/lang/SecurityException',
'M|1|isAnnotationPresent|(~1Class;)Z|(~1Class<+~1annotation/Annotation;>;)Z|',
'M|1|getNestHost|()~1Class;|()~1Class<*>;|',
'M|1|descriptorString|()~S||',
'M|1|getPermittedSubclasses|()[~1Class;|()[~1Class<*>;|',
'M|1|arrayType|()~1Class;|()~1Class<*>;|',
'M|1|toGenericString|()~S||',
'M|1|getGenericSuperclass|()~1reflect/Type;||',
'M|1|getPackage|()~1Package;||',
'M|1|getGenericInterfaces|()[~1reflect/Type;||',
'M|1|accessFlags|()~2Set;|()~2Set<~1reflect/AccessFlag;>;|',
'M|257|getSigners|()[~O||',
'M|1|getEnclosingMethod|()~1reflect/Method;||java/lang/SecurityException',
'M|1|getEnclosingConstructor|()~1reflect/Constructor;|()~1reflect/Constructor<*>;|java/lang/SecurityException',
'M|1|getDeclaringClass|()~1Class;|()~1Class<*>;|java/lang/SecurityException',
'M|1|getTypeName|()~S||',
'M|1|getClasses|()[~1Class;|()[~1Class<*>;|',
'M|1|getFields|()[~1reflect/Field;||java/lang/SecurityException',
'M|1|getMethods|()[~1reflect/Method;||java/lang/SecurityException',
'M|1|getConstructors|()[~1reflect/Constructor;|()[~1reflect/Constructor<*>;|java/lang/SecurityException',
'M|1|getField|(~S)~1reflect/Field;||java/lang/NoSuchFieldException,java/lang/SecurityException',
'M|129|getConstructor|([~1Class;)~1reflect/Constructor;|([~1Class<*>;)~1reflect/Constructor<TT;>;|java/lang/NoSuchMethodException,java/lang/SecurityException',
'M|1|getDeclaredClasses|()[~1Class;|()[~1Class<*>;|java/lang/SecurityException',
'M|1|getDeclaredFields|()[~1reflect/Field;||java/lang/SecurityException',
'M|1|getRecordComponents|()[~1reflect/RecordComponent;||',
'M|1|getDeclaredMethods|()[~1reflect/Method;||java/lang/SecurityException',
'M|1|getDeclaredConstructors|()[~1reflect/Constructor;|()[~1reflect/Constructor<*>;|java/lang/SecurityException',
'M|1|getDeclaredField|(~S)~1reflect/Field;||java/lang/NoSuchFieldException,java/lang/SecurityException',
'M|129|getDeclaredMethod|(~S[~1Class;)~1reflect/Method;|(~S[~1Class<*>;)~1reflect/Method;|java/lang/NoSuchMethodException,java/lang/SecurityException',
'M|129|getDeclaredConstructor|([~1Class;)~1reflect/Constructor;|([~1Class<*>;)~1reflect/Constructor<TT;>;|java/lang/NoSuchMethodException,java/lang/SecurityException',
'M|1|getEnumConstants|()[~O|()[TT;|',
'M|1|asSubclass|(~1Class;)~1Class;|<U:~O>(~1Class<TU;>;)~1Class<+TU;>;|',
'M|1|getAnnotation|(~1Class;)~1annotation/Annotation;|<A::~1annotation/Annotation;>(~1Class<TA;>;)TA;|',
'M|1|getAnnotationsByType|(~1Class;)[~1annotation/Annotation;|<A::~1annotation/Annotation;>(~1Class<TA;>;)[TA;|',
'M|1|getAnnotations|()[~1annotation/Annotation;||',
'M|1|getDeclaredAnnotation|(~1Class;)~1annotation/Annotation;|<A::~1annotation/Annotation;>(~1Class<TA;>;)TA;|',
'M|1|getDeclaredAnnotationsByType|(~1Class;)[~1annotation/Annotation;|<A::~1annotation/Annotation;>(~1Class<TA;>;)[TA;|',
'M|1|getDeclaredAnnotations|()[~1annotation/Annotation;||',
'M|1|getAnnotatedSuperclass|()~1reflect/AnnotatedType;||',
'M|1|getAnnotatedInterfaces|()[~1reflect/AnnotatedType;||',
'M|1|isNestmateOf|(~1Class;)Z|(~1Class<*>;)Z|',
'M|1|getNestMembers|()[~1Class;|()[~1Class<*>;|',
'M|1|isSealed|()Z||',
'C|1025|java/lang/ClassLoader|~O',
'M|4|<init>|(~1ClassLoader;)V||',
'M|4|<init>|(~S~1ClassLoader;)V||',
'M|4|<init>|()V||',
'M|1|getName|()~S||',
'M|4|loadClass|(~SZ)~1Class;|(~SZ)~1Class<*>;|java/lang/ClassNotFoundException',
'M|1|loadClass|(~S)~1Class;|(~S)~1Class<*>;|java/lang/ClassNotFoundException',
'M|9|getPlatformClassLoader|()~1ClassLoader;||',
'M|9|getSystemClassLoader|()~1ClassLoader;||',
'M|4|definePackage|(~S~S~S~S~S~S~SLjava/net/URL;)~1Package;||',
'M|4|findResource|(~S~S)Ljava/net/URL;||java/io/IOException',
'M|4|findResource|(~S)Ljava/net/URL;||',
'M|9|getSystemResourceAsStream|(~S)~4InputStream;||',
'M|1|getResourceAsStream|(~S)~4InputStream;||',
'M|9|getSystemResource|(~S)Ljava/net/URL;||',
'M|1|getResource|(~S)Ljava/net/URL;||',
'M|4|getPackage|(~S)~1Package;||',
'M|20|setSigners|(~1Class;[~O)V|(~1Class<*>;[~O)V|',
'M|4|getClassLoadingLock|(~S)~O||',
'M|20|findLoadedClass|(~S)~1Class;|(~S)~1Class<*>;|',
'M|4|findClass|(~S)~1Class;|(~S)~1Class<*>;|java/lang/ClassNotFoundException',
'M|4|findClass|(~S~S)~1Class;|(~S~S)~1Class<*>;|',
'M|20|resolveClass|(~1Class;)V|(~1Class<*>;)V|',
'M|20|defineClass|(~S[BIILjava/security/ProtectionDomain;)~1Class;|(~S[BIILjava/security/ProtectionDomain;)~1Class<*>;|java/lang/ClassFormatError',
'M|20|defineClass|(~S[BII)~1Class;|(~S[BII)~1Class<*>;|java/lang/ClassFormatError',
'M|20|defineClass|(~SLjava/nio/ByteBuffer;Ljava/security/ProtectionDomain;)~1Class;|(~SLjava/nio/ByteBuffer;Ljava/security/ProtectionDomain;)~1Class<*>;|java/lang/ClassFormatError',
'M|20|defineClass|([BII)~1Class;|([BII)~1Class<*>;|java/lang/ClassFormatError',
'M|1|getResources|(~S)~2Enumeration;|(~S)~2Enumeration<Ljava/net/URL;>;|java/io/IOException',
'M|4|findResources|(~S)~2Enumeration;|(~S)~2Enumeration<Ljava/net/URL;>;|java/io/IOException',
'M|12|registerAsParallelCapable|()Z||',
'M|17|getDefinedPackage|(~S)~1Package;||',
'M|4|findLibrary|(~S)~S||',
'M|20|findSystemClass|(~S)~1Class;|(~S)~1Class<*>;|java/lang/ClassNotFoundException',
'M|1|resources|(~S)~5Stream;|(~S)~5Stream<Ljava/net/URL;>;|',
'M|17|isRegisteredAsParallelCapable|()Z||',
'M|9|getSystemResources|(~S)~2Enumeration;|(~S)~2Enumeration<Ljava/net/URL;>;|java/io/IOException',
'M|17|getParent|()~1ClassLoader;||',
'M|17|getUnnamedModule|()~1Module;||',
'M|17|getDefinedPackages|()[~1Package;||',
'M|4|getPackages|()[~1Package;||',
'M|1|setDefaultAssertionStatus|(Z)V||',
'M|1|setPackageAssertionStatus|(~SZ)V||',
'M|1|setClassAssertionStatus|(~SZ)V||',
'M|1|clearAssertionStatus|()V||',
'C|1|java/lang/Runtime|~O',
'M|9|getRuntime|()~1Runtime;||',
'M|1|exit|(I)V||',
'M|1|runFinalization|()V||',
'M|9|version|()~1Runtime$Version;||',
'M|1|load|(~S)V||',
'M|1|loadLibrary|(~S)V||',
'M|257|gc|()V||',
'M|257|availableProcessors|()I||',
'M|257|freeMemory|()J||',
'M|257|maxMemory|()J||',
'M|1|exec|([~S)~1Process;||java/io/IOException',
'M|1|exec|(~S[~S~4File;)~1Process;||java/io/IOException',
'M|1|exec|(~S)~1Process;||java/io/IOException',
'M|1|exec|(~S[~S)~1Process;||java/io/IOException',
'M|1|exec|([~S[~S)~1Process;||java/io/IOException',
'M|1|exec|([~S[~S~4File;)~1Process;||java/io/IOException',
'M|1|halt|(I)V||',
'M|1|addShutdownHook|(~1Thread;)V||',
'M|1|removeShutdownHook|(~1Thread;)Z||',
'M|257|totalMemory|()J||',
'C|1025|java/lang/Process|~O',
'M|1|<init>|()V||',
'M|1|info|()~1ProcessHandle$Info;||',
'M|1|onExit|()~2concurrent/CompletableFuture;|()~2concurrent/CompletableFuture<~1Process;>;|',
'M|1|isAlive|()Z||',
'M|1025|destroy|()V||',
'M|1025|getInputStream|()~4InputStream;||',
'M|1|pid|()J||',
'M|1025|getErrorStream|()~4InputStream;||',
'M|1|waitFor|(J~2concurrent/TimeUnit;)Z||java/lang/InterruptedException',
'M|1025|waitFor|()I||java/lang/InterruptedException',
'M|1|children|()~5Stream;|()~5Stream<~1ProcessHandle;>;|',
'M|17|inputReader|(Ljava/nio/charset/Charset;)~4BufferedReader;||',
'M|17|inputReader|()~4BufferedReader;||',
'M|17|errorReader|(Ljava/nio/charset/Charset;)~4BufferedReader;||',
'M|17|errorReader|()~4BufferedReader;||',
'M|17|outputWriter|(Ljava/nio/charset/Charset;)~4BufferedWriter;||',
'M|17|outputWriter|()~4BufferedWriter;||',
'M|1025|getOutputStream|()~4OutputStream;||',
'M|1025|exitValue|()I||',
'M|1|toHandle|()~1ProcessHandle;||',
'M|1|descendants|()~5Stream;|()~5Stream<~1ProcessHandle;>;|',
'M|1|destroyForcibly|()~1Process;||',
'M|1|supportsNormalTermination|()Z||',
'C|17|java/lang/ProcessBuilder|~O',
'M|1|<init>|(~2List;)V|(~2List<~S>;)V|',
'M|129|<init>|([~S)V||',
'M|1|directory|(~4File;)~1ProcessBuilder;||',
'M|1|directory|()~4File;||',
'M|1|start|()~1Process;||java/io/IOException',
'M|1|environment|()~2Map;|()~2Map<~S~S>;|',
'M|1|command|()~2List;|()~2List<~S>;|',
'M|129|command|([~S)~1ProcessBuilder;||',
'M|1|command|(~2List;)~1ProcessBuilder;|(~2List<~S>;)~1ProcessBuilder;|',
'M|1|redirectInput|()~1ProcessBuilder$Redirect;||',
'M|1|redirectInput|(~4File;)~1ProcessBuilder;||',
'M|1|redirectInput|(~1ProcessBuilder$Redirect;)~1ProcessBuilder;||',
'M|1|redirectOutput|(~1ProcessBuilder$Redirect;)~1ProcessBuilder;||',
'M|1|redirectOutput|()~1ProcessBuilder$Redirect;||',
'M|1|redirectOutput|(~4File;)~1ProcessBuilder;||',
'M|1|redirectError|(~4File;)~1ProcessBuilder;||',
'M|1|redirectError|()~1ProcessBuilder$Redirect;||',
'M|1|redirectError|(~1ProcessBuilder$Redirect;)~1ProcessBuilder;||',
'M|1|redirectErrorStream|(Z)~1ProcessBuilder;||',
'M|1|redirectErrorStream|()Z||',
'M|1|inheritIO|()~1ProcessBuilder;||',
'M|9|startPipeline|(~2List;)~2List;|(~2List<~1ProcessBuilder;>;)~2List<~1Process;>;|java/io/IOException',
'C|17|java/lang/StackTraceElement|~O~4Serializable;',
'M|1|<init>|(~S~S~S~S~S~SI)V||',
'M|1|<init>|(~S~S~SI)V||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|getClassName|()~S||',
'M|1|isNativeMethod|()Z||',
'M|1|getFileName|()~S||',
'M|1|getLineNumber|()I||',
'M|1|getModuleName|()~S||',
'M|1|getModuleVersion|()~S||',
'M|1|getClassLoaderName|()~S||',
'M|1|getMethodName|()~S||',
'C|9729|java/lang/FunctionalInterface|~O~1annotation/Annotation;',
'C|9729|java/lang/Override|~O~1annotation/Annotation;',
'C|9729|java/lang/Deprecated|~O~1annotation/Annotation;',
'M|1025|since|()~S||',
'M|1025|forRemoval|()Z||',
'C|9729|java/lang/SuppressWarnings|~O~1annotation/Annotation;',
'M|1025|value|()[~S||',
'C|9729|java/lang/SafeVarargs|~O~1annotation/Annotation;',
'C|17|java/lang/reflect/Method|~1reflect/Executable;',
'M|129|invoke|(~O[~O)~O||java/lang/IllegalAccessException,java/lang/reflect/InvocationTargetException',
'M|1|getName|()~S||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|getModifiers|()I||',
'M|1|getTypeParameters|()[~1reflect/TypeVariable;|()[~1reflect/TypeVariable<~1reflect/Method;>;|',
'M|1|getReturnType|()~1Class;|()~1Class<*>;|',
'M|1|getParameterTypes|()[~1Class;|()[~1Class<*>;|',
'M|1|isSynthetic|()Z||',
'M|1|toGenericString|()~S||',
'M|1|getDeclaringClass|()~1Class;|()~1Class<*>;|',
'M|1|getAnnotation|(~1Class;)~1annotation/Annotation;|<T::~1annotation/Annotation;>(~1Class<TT;>;)TT;|',
'M|1|getDeclaredAnnotations|()[~1annotation/Annotation;||',
'M|1|setAccessible|(Z)V||',
'M|1|isVarArgs|()Z||',
'M|1|getParameterCount|()I||',
'M|1|getParameterAnnotations|()[[~1annotation/Annotation;||',
'M|1|getGenericParameterTypes|()[~1reflect/Type;||',
'M|1|getGenericExceptionTypes|()[~1reflect/Type;||',
'M|1|isDefault|()Z||',
'M|1|getGenericReturnType|()~1reflect/Type;||',
'M|1|getExceptionTypes|()[~1Class;|()[~1Class<*>;|',
'M|1|isBridge|()Z||',
'M|1|getDefaultValue|()~O||',
'M|1|getAnnotatedReturnType|()~1reflect/AnnotatedType;||',
'C|17|java/lang/reflect/Field|~1reflect/AccessibleObject;~1reflect/Member;',
'M|1|getName|()~S||',
'M|1|get|(~O)~O||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|getModifiers|()I||',
'M|1|getBoolean|(~O)Z||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|getByte|(~O)B||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|getShort|(~O)S||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|getChar|(~O)C||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|getInt|(~O)I||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|getLong|(~O)J||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|getFloat|(~O)F||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|getDouble|(~O)D||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|isSynthetic|()Z||',
'M|1|toGenericString|()~S||',
'M|1|accessFlags|()~2Set;|()~2Set<~1reflect/AccessFlag;>;|',
'M|1|getDeclaringClass|()~1Class;|()~1Class<*>;|',
'M|1|getAnnotation|(~1Class;)~1annotation/Annotation;|<T::~1annotation/Annotation;>(~1Class<TT;>;)TT;|',
'M|1|getAnnotationsByType|(~1Class;)[~1annotation/Annotation;|<T::~1annotation/Annotation;>(~1Class<TT;>;)[TT;|',
'M|1|getDeclaredAnnotations|()[~1annotation/Annotation;||',
'M|1|set|(~O~O)V||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|setAccessible|(Z)V||',
'M|1|getGenericType|()~1reflect/Type;||',
'M|1|getType|()~1Class;|()~1Class<*>;|',
'M|1|setBoolean|(~OZ)V||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|setByte|(~OB)V||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|setChar|(~OC)V||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|setShort|(~OS)V||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|setInt|(~OI)V||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|setLong|(~OJ)V||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|setFloat|(~OF)V||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|setDouble|(~OD)V||java/lang/IllegalArgumentException,java/lang/IllegalAccessException',
'M|1|isEnumConstant|()Z||',
'M|1|getAnnotatedType|()~1reflect/AnnotatedType;||',
'C|17|java/lang/reflect/Constructor|<T:~O>~1reflect/Executable;',
'M|1|getName|()~S||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|getModifiers|()I||',
'M|1|getTypeParameters|()[~1reflect/TypeVariable;|()[~1reflect/TypeVariable<~1reflect/Constructor<TT;>;>;|',
'M|129|newInstance|([~O)~O|([~O)TT;|java/lang/InstantiationException,java/lang/IllegalAccessException,java/lang/IllegalArgumentException,java/lang/reflect/InvocationTargetException',
'M|1|getParameterTypes|()[~1Class;|()[~1Class<*>;|',
'M|1|isSynthetic|()Z||',
'M|1|toGenericString|()~S||',
'M|1|getDeclaringClass|()~1Class;|()~1Class<TT;>;|',
'M|1|getAnnotation|(~1Class;)~1annotation/Annotation;|<T::~1annotation/Annotation;>(~1Class<TT;>;)TT;|',
'M|1|getDeclaredAnnotations|()[~1annotation/Annotation;||',
'M|1|setAccessible|(Z)V||',
'M|1|isVarArgs|()Z||',
'M|1|getParameterCount|()I||',
'M|1|getParameterAnnotations|()[[~1annotation/Annotation;||',
'M|1|getGenericParameterTypes|()[~1reflect/Type;||',
'M|1|getGenericExceptionTypes|()[~1reflect/Type;||',
'M|1|getExceptionTypes|()[~1Class;|()[~1Class<*>;|',
'M|1|getAnnotatedReturnType|()~1reflect/AnnotatedType;||',
'M|1|getAnnotatedReceiverType|()~1reflect/AnnotatedType;||',
'C|17|java/lang/reflect/Array|~O',
'M|265|get|(~OI)~O||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|getLength|(~O)I||java/lang/IllegalArgumentException',
'M|265|getBoolean|(~OI)Z||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|getByte|(~OI)B||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|getShort|(~OI)S||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|getChar|(~OI)C||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|getInt|(~OI)I||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|getLong|(~OI)J||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|getFloat|(~OI)F||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|getDouble|(~OI)D||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|9|newInstance|(~1Class;I)~O|(~1Class<*>;I)~O|java/lang/NegativeArraySizeException',
'M|137|newInstance|(~1Class;[I)~O|(~1Class<*>;[I)~O|java/lang/IllegalArgumentException,java/lang/NegativeArraySizeException',
'M|265|set|(~OI~O)V||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|setBoolean|(~OIZ)V||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|setByte|(~OIB)V||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|setChar|(~OIC)V||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|setShort|(~OIS)V||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|setInt|(~OII)V||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|setLong|(~OIJ)V||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|setFloat|(~OIF)V||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'M|265|setDouble|(~OID)V||java/lang/IllegalArgumentException,java/lang/ArrayIndexOutOfBoundsException',
'C|1|java/lang/reflect/Modifier|~O',
'F|25|PUBLIC|I||I1',
'F|25|PRIVATE|I||I2',
'F|25|PROTECTED|I||I4',
'F|25|STATIC|I||I8',
'F|25|FINAL|I||I16',
'F|25|SYNCHRONIZED|I||I32',
'F|25|VOLATILE|I||I64',
'F|25|TRANSIENT|I||I128',
'F|25|NATIVE|I||I256',
'F|25|INTERFACE|I||I512',
'F|25|ABSTRACT|I||I1024',
'F|25|STRICT|I||I2048',
'M|9|toString|(I)~S||',
'M|9|isInterface|(I)Z||',
'M|9|classModifiers|()I||',
'M|9|isFinal|(I)Z||',
'M|9|isStatic|(I)Z||',
'M|9|isPublic|(I)Z||',
'M|9|isProtected|(I)Z||',
'M|9|methodModifiers|()I||',
'M|9|constructorModifiers|()I||',
'M|9|isAbstract|(I)Z||',
'M|9|isVolatile|(I)Z||',
'M|9|isPrivate|(I)Z||',
'M|9|isNative|(I)Z||',
'M|9|isSynchronized|(I)Z||',
'M|9|isTransient|(I)Z||',
'M|9|isStrict|(I)Z||',
'M|9|interfaceModifiers|()I||',
'M|9|fieldModifiers|()I||',
'M|9|parameterModifiers|()I||',
'C|1|java/lang/reflect/InvocationTargetException|~1ReflectiveOperationException;',
'M|1|<init>|(~1Throwable;~S)V||',
'M|1|<init>|(~1Throwable;)V||',
'M|4|<init>|()V||',
'M|1|getCause|()~1Throwable;||',
'M|1|getTargetException|()~1Throwable;||',
'C|1|java/io/PrintStream|~4FilterOutputStream;~1Appendable;~4Closeable;',
'M|1|<init>|(~4OutputStream;Z~S)V||java/io/UnsupportedEncodingException',
'M|1|<init>|(~4OutputStream;ZLjava/nio/charset/Charset;)V||',
'M|1|<init>|(~S)V||java/io/FileNotFoundException',
'M|1|<init>|(~S~S)V||java/io/FileNotFoundException,java/io/UnsupportedEncodingException',
'M|1|<init>|(~SLjava/nio/charset/Charset;)V||java/io/IOException',
'M|1|<init>|(~4File;~S)V||java/io/FileNotFoundException,java/io/UnsupportedEncodingException',
'M|1|<init>|(~4File;)V||java/io/FileNotFoundException',
'M|1|<init>|(~4File;Ljava/nio/charset/Charset;)V||java/io/IOException',
'M|1|<init>|(~4OutputStream;)V||',
'M|1|<init>|(~4OutputStream;Z)V||',
'M|1|println|(~S)V||',
'M|1|println|(~O)V||',
'M|1|println|(F)V||',
'M|1|println|([C)V||',
'M|1|println|(D)V||',
'M|1|println|()V||',
'M|1|println|(Z)V||',
'M|1|println|(C)V||',
'M|1|println|(I)V||',
'M|1|println|(J)V||',
'M|1|append|(~1CharSequence;)~4PrintStream;||',
'M|1|append|(~1CharSequence;II)~4PrintStream;||',
'M|1|append|(C)~4PrintStream;||',
'M|1|flush|()V||',
'M|129|format|(~2Locale;~S[~O)~4PrintStream;||',
'M|129|format|(~S[~O)~4PrintStream;||',
'M|1|charset|()Ljava/nio/charset/Charset;||',
'M|129|printf|(~2Locale;~S[~O)~4PrintStream;||',
'M|129|printf|(~S[~O)~4PrintStream;||',
'M|1|write|([B)V||java/io/IOException',
'M|1|write|([BII)V||',
'M|1|write|(I)V||',
'M|1|print|(~S)V||',
'M|1|print|([C)V||',
'M|1|print|(~O)V||',
'M|1|print|(Z)V||',
'M|1|print|(C)V||',
'M|1|print|(I)V||',
'M|1|print|(D)V||',
'M|1|print|(F)V||',
'M|1|print|(J)V||',
'M|1|close|()V||',
'M|1|writeBytes|([B)V||',
'M|1|checkError|()Z||',
'M|4|setError|()V||',
'M|4|clearError|()V||',
'C|1025|java/io/InputStream|~O~4Closeable;',
'M|1|<init>|()V||',
'M|1|reset|()V||java/io/IOException',
'M|1|read|([B)I||java/io/IOException',
'M|1|read|([BII)I||java/io/IOException',
'M|1025|read|()I||java/io/IOException',
'M|1|close|()V||java/io/IOException',
'M|1|readAllBytes|()[B||java/io/IOException',
'M|1|mark|(I)V||',
'M|1|readNBytes|([BII)I||java/io/IOException',
'M|1|readNBytes|(I)[B||java/io/IOException',
'M|1|transferTo|(~4OutputStream;)J||java/io/IOException',
'M|1|skip|(J)J||java/io/IOException',
'M|1|available|()I||java/io/IOException',
'M|1|markSupported|()Z||',
'M|9|nullInputStream|()~4InputStream;||',
'M|1|skipNBytes|(J)V||java/io/IOException',
'C|1025|java/io/OutputStream|~O~4Closeable;~4Flushable;',
'M|1|<init>|()V||',
'M|1|flush|()V||java/io/IOException',
'M|1|write|([B)V||java/io/IOException',
'M|1|write|([BII)V||java/io/IOException',
'M|1025|write|(I)V||java/io/IOException',
'M|1|close|()V||java/io/IOException',
'M|9|nullOutputStream|()~4OutputStream;||',
'C|1|java/io/FilterInputStream|~4InputStream;',
'F|68|in|~4InputStream;||',
'M|4|<init>|(~4InputStream;)V||',
'M|1|reset|()V||java/io/IOException',
'M|1|read|([BII)I||java/io/IOException',
'M|1|read|()I||java/io/IOException',
'M|1|read|([B)I||java/io/IOException',
'M|1|close|()V||java/io/IOException',
'M|1|mark|(I)V||',
'M|1|skip|(J)J||java/io/IOException',
'M|1|available|()I||java/io/IOException',
'M|1|markSupported|()Z||',
'C|1|java/io/FilterOutputStream|~4OutputStream;',
'F|4|out|~4OutputStream;||',
'M|1|<init>|(~4OutputStream;)V||',
'M|1|flush|()V||java/io/IOException',
'M|1|write|([BII)V||java/io/IOException',
'M|1|write|([B)V||java/io/IOException',
'M|1|write|(I)V||java/io/IOException',
'M|1|close|()V||java/io/IOException',
'C|1025|java/io/Reader|~O~1Readable;~4Closeable;',
'F|4|lock|~O||',
'M|4|<init>|(~O)V||',
'M|4|<init>|()V||',
'M|1|reset|()V||java/io/IOException',
'M|1|read|([C)I||java/io/IOException',
'M|1025|read|([CII)I||java/io/IOException',
'M|1|read|(Ljava/nio/CharBuffer;)I||java/io/IOException',
'M|1|read|()I||java/io/IOException',
'M|1025|close|()V||java/io/IOException',
'M|1|mark|(I)V||java/io/IOException',
'M|1|transferTo|(~4Writer;)J||java/io/IOException',
'M|1|skip|(J)J||java/io/IOException',
'M|1|markSupported|()Z||',
'M|9|nullReader|()~4Reader;||',
'M|1|ready|()Z||java/io/IOException',
'C|1025|java/io/Writer|~O~1Appendable;~4Closeable;~4Flushable;',
'F|4|lock|~O||',
'M|4|<init>|()V||',
'M|4|<init>|(~O)V||',
'M|1|append|(C)~4Writer;||java/io/IOException',
'M|1|append|(~1CharSequence;II)~4Writer;||java/io/IOException',
'M|1|append|(~1CharSequence;)~4Writer;||java/io/IOException',
'M|1025|flush|()V||java/io/IOException',
'M|1|write|(I)V||java/io/IOException',
'M|1025|write|([CII)V||java/io/IOException',
'M|1|write|(~S)V||java/io/IOException',
'M|1|write|(~SII)V||java/io/IOException',
'M|1|write|([C)V||java/io/IOException',
'M|1025|close|()V||java/io/IOException',
'M|9|nullWriter|()~4Writer;||',
'C|1|java/io/BufferedReader|~4Reader;',
'M|1|<init>|(~4Reader;I)V||',
'M|1|<init>|(~4Reader;)V||',
'M|1|reset|()V||java/io/IOException',
'M|1|lines|()~5Stream;|()~5Stream<~S>;|',
'M|1|read|([CII)I||java/io/IOException',
'M|1|read|()I||java/io/IOException',
'M|1|readLine|()~S||java/io/IOException',
'M|1|close|()V||java/io/IOException',
'M|1|mark|(I)V||java/io/IOException',
'M|1|skip|(J)J||java/io/IOException',
'M|1|markSupported|()Z||',
'M|1|ready|()Z||java/io/IOException',
'C|1|java/io/BufferedWriter|~4Writer;',
'M|1|<init>|(~4Writer;)V||',
'M|1|<init>|(~4Writer;I)V||',
'M|1|flush|()V||java/io/IOException',
'M|1|write|(I)V||java/io/IOException',
'M|1|write|(~SII)V||java/io/IOException',
'M|1|write|([CII)V||java/io/IOException',
'M|1|newLine|()V||java/io/IOException',
'M|1|close|()V||java/io/IOException',
'C|1|java/io/InputStreamReader|~4Reader;',
'M|1|<init>|(~4InputStream;Ljava/nio/charset/Charset;)V||',
'M|1|<init>|(~4InputStream;~S)V||java/io/UnsupportedEncodingException',
'M|1|<init>|(~4InputStream;)V||',
'M|1|<init>|(~4InputStream;Ljava/nio/charset/CharsetDecoder;)V||',
'M|1|read|([CII)I||java/io/IOException',
'M|1|read|(Ljava/nio/CharBuffer;)I||java/io/IOException',
'M|1|read|()I||java/io/IOException',
'M|1|close|()V||java/io/IOException',
'M|1|getEncoding|()~S||',
'M|1|ready|()Z||java/io/IOException',
'C|1|java/io/OutputStreamWriter|~4Writer;',
'M|1|<init>|(~4OutputStream;Ljava/nio/charset/CharsetEncoder;)V||',
'M|1|<init>|(~4OutputStream;)V||',
'M|1|<init>|(~4OutputStream;~S)V||java/io/UnsupportedEncodingException',
'M|1|<init>|(~4OutputStream;Ljava/nio/charset/Charset;)V||',
'M|1|append|(~1CharSequence;)~4Writer;||java/io/IOException',
'M|1|append|(~1CharSequence;II)~4Writer;||java/io/IOException',
'M|1|flush|()V||java/io/IOException',
'M|1|write|(~SII)V||java/io/IOException',
'M|1|write|([CII)V||java/io/IOException',
'M|1|write|(I)V||java/io/IOException',
'M|1|close|()V||java/io/IOException',
'M|1|getEncoding|()~S||',
'C|1|java/io/FileReader|~4InputStreamReader;',
'M|1|<init>|(~4File;Ljava/nio/charset/Charset;)V||java/io/IOException',
'M|1|<init>|(~SLjava/nio/charset/Charset;)V||java/io/IOException',
'M|1|<init>|(~4FileDescriptor;)V||',
'M|1|<init>|(~4File;)V||java/io/FileNotFoundException',
'M|1|<init>|(~S)V||java/io/FileNotFoundException',
'C|1|java/io/FileWriter|~4OutputStreamWriter;',
'M|1|<init>|(~4FileDescriptor;)V||',
'M|1|<init>|(~SLjava/nio/charset/Charset;)V||java/io/IOException',
'M|1|<init>|(~SLjava/nio/charset/Charset;Z)V||java/io/IOException',
'M|1|<init>|(~4File;Ljava/nio/charset/Charset;)V||java/io/IOException',
'M|1|<init>|(~4File;Ljava/nio/charset/Charset;Z)V||java/io/IOException',
'M|1|<init>|(~S)V||java/io/IOException',
'M|1|<init>|(~SZ)V||java/io/IOException',
'M|1|<init>|(~4File;)V||java/io/IOException',
'M|1|<init>|(~4File;Z)V||java/io/IOException',
'C|1|java/io/FileInputStream|~4InputStream;',
'M|1|<init>|(~4FileDescriptor;)V||',
'M|1|<init>|(~4File;)V||java/io/FileNotFoundException',
'M|1|<init>|(~S)V||java/io/FileNotFoundException',
'M|1|read|()I||java/io/IOException',
'M|1|read|([B)I||java/io/IOException',
'M|1|read|([BII)I||java/io/IOException',
'M|1|close|()V||java/io/IOException',
'M|1|readAllBytes|()[B||java/io/IOException',
'M|1|readNBytes|(I)[B||java/io/IOException',
'M|1|transferTo|(~4OutputStream;)J||java/io/IOException',
'M|1|skip|(J)J||java/io/IOException',
'M|1|available|()I||java/io/IOException',
'M|1|getChannel|()Ljava/nio/channels/FileChannel;||',
'M|17|getFD|()~4FileDescriptor;||java/io/IOException',
'C|1|java/io/FileOutputStream|~4OutputStream;',
'M|1|<init>|(~4FileDescriptor;)V||',
'M|1|<init>|(~4File;Z)V||java/io/FileNotFoundException',
'M|1|<init>|(~4File;)V||java/io/FileNotFoundException',
'M|1|<init>|(~SZ)V||java/io/FileNotFoundException',
'M|1|<init>|(~S)V||java/io/FileNotFoundException',
'M|1|write|(I)V||java/io/IOException',
'M|1|write|([B)V||java/io/IOException',
'M|1|write|([BII)V||java/io/IOException',
'M|1|close|()V||java/io/IOException',
'M|1|getChannel|()Ljava/nio/channels/FileChannel;||',
'M|17|getFD|()~4FileDescriptor;||java/io/IOException',
'C|1|java/io/File|~O~4Serializable;~1Comparable<~4File;>;',
'F|25|separatorChar|C||C47',
'F|25|separator|~S||S/',
'F|25|pathSeparatorChar|C||C58',
'F|25|pathSeparator|~S||S:',
'M|1|<init>|(~S)V||',
'M|1|<init>|(~S~S)V||',
'M|1|<init>|(Ljava/net/URI;)V||',
'M|1|<init>|(~4File;~S)V||',
'M|1|getName|()~S||',
'M|1|equals|(~O)Z||',
'M|1|length|()J||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|isHidden|()Z||',
'M|1|compareTo|(~4File;)I||',
'M|1|list|()[~S||',
'M|1|list|(~4FilenameFilter;)[~S||',
'M|1|isAbsolute|()Z||',
'M|1|getParent|()~S||',
'M|1|delete|()Z||',
'M|1|setReadOnly|()Z||',
'M|1|canRead|()Z||',
'M|1|getPath|()~S||',
'M|1|toURI|()Ljava/net/URI;||',
'M|1|toURL|()Ljava/net/URL;||java/net/MalformedURLException',
'M|1|getAbsolutePath|()~S||',
'M|1|exists|()Z||',
'M|1|createNewFile|()Z||java/io/IOException',
'M|1|renameTo|(~4File;)Z||',
'M|1|isDirectory|()Z||',
'M|1|getCanonicalPath|()~S||java/io/IOException',
'M|1|getAbsoluteFile|()~4File;||',
'M|1|mkdir|()Z||',
'M|1|getCanonicalFile|()~4File;||java/io/IOException',
'M|1|getParentFile|()~4File;||',
'M|1|mkdirs|()Z||',
'M|1|setWritable|(Z)Z||',
'M|1|setWritable|(ZZ)Z||',
'M|1|setReadable|(ZZ)Z||',
'M|1|setReadable|(Z)Z||',
'M|1|setExecutable|(ZZ)Z||',
'M|1|setExecutable|(Z)Z||',
'M|9|listRoots|()[~4File;||',
'M|9|createTempFile|(~S~S)~4File;||java/io/IOException',
'M|9|createTempFile|(~S~S~4File;)~4File;||java/io/IOException',
'M|1|canWrite|()Z||',
'M|1|isFile|()Z||',
'M|1|lastModified|()J||',
'M|1|deleteOnExit|()V||',
'M|1|listFiles|(~4FileFilter;)[~4File;||',
'M|1|listFiles|(~4FilenameFilter;)[~4File;||',
'M|1|listFiles|()[~4File;||',
'M|1|setLastModified|(J)Z||',
'M|1|canExecute|()Z||',
'M|1|getTotalSpace|()J||',
'M|1|getFreeSpace|()J||',
'M|1|getUsableSpace|()J||',
'M|1|toPath|()Ljava/nio/file/Path;||',
'C|1|java/io/IOException|~1Exception;',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'C|1|java/io/FileNotFoundException|~4IOException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/io/UncheckedIOException|~1RuntimeException;',
'M|1|<init>|(~S~4IOException;)V||',
'M|1|<init>|(~4IOException;)V||',
'M|1|getCause|()~4IOException;||',
'C|1|java/io/EOFException|~4IOException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/io/PrintWriter|~4Writer;',
'F|4|out|~4Writer;||',
'M|1|<init>|(~S~S)V||java/io/FileNotFoundException,java/io/UnsupportedEncodingException',
'M|1|<init>|(~S)V||java/io/FileNotFoundException',
'M|1|<init>|(~SLjava/nio/charset/Charset;)V||java/io/IOException',
'M|1|<init>|(~4File;Ljava/nio/charset/Charset;)V||java/io/IOException',
'M|1|<init>|(~4File;~S)V||java/io/FileNotFoundException,java/io/UnsupportedEncodingException',
'M|1|<init>|(~4File;)V||java/io/FileNotFoundException',
'M|1|<init>|(~4Writer;)V||',
'M|1|<init>|(~4Writer;Z)V||',
'M|1|<init>|(~4OutputStream;)V||',
'M|1|<init>|(~4OutputStream;Z)V||',
'M|1|<init>|(~4OutputStream;ZLjava/nio/charset/Charset;)V||',
'M|1|println|([C)V||',
'M|1|println|(D)V||',
'M|1|println|(F)V||',
'M|1|println|(~S)V||',
'M|1|println|(~O)V||',
'M|1|println|()V||',
'M|1|println|(C)V||',
'M|1|println|(I)V||',
'M|1|println|(J)V||',
'M|1|println|(Z)V||',
'M|1|append|(C)~4PrintWriter;||',
'M|1|append|(~1CharSequence;II)~4PrintWriter;||',
'M|1|append|(~1CharSequence;)~4PrintWriter;||',
'M|1|flush|()V||',
'M|129|format|(~2Locale;~S[~O)~4PrintWriter;||',
'M|129|format|(~S[~O)~4PrintWriter;||',
'M|129|printf|(~S[~O)~4PrintWriter;||',
'M|129|printf|(~2Locale;~S[~O)~4PrintWriter;||',
'M|1|write|(I)V||',
'M|1|write|([CII)V||',
'M|1|write|([C)V||',
'M|1|write|(~SII)V||',
'M|1|write|(~S)V||',
'M|1|print|(F)V||',
'M|1|print|(J)V||',
'M|1|print|(I)V||',
'M|1|print|(C)V||',
'M|1|print|(Z)V||',
'M|1|print|(~O)V||',
'M|1|print|(~S)V||',
'M|1|print|([C)V||',
'M|1|print|(D)V||',
'M|1|close|()V||',
'M|1|checkError|()Z||',
'M|4|setError|()V||',
'M|4|clearError|()V||',
'C|1537|java/io/Closeable|~O~1AutoCloseable;',
'M|1025|close|()V||java/io/IOException',
'C|1537|java/io/Flushable|~O',
'M|1025|flush|()V||java/io/IOException',
'C|1537|java/io/Serializable|~O',
'C|1|java/io/ByteArrayOutputStream|~4OutputStream;',
'F|4|buf|[B||',
'F|4|count|I||',
'M|1|<init>|()V||',
'M|1|<init>|(I)V||',
'M|33|size|()I||',
'M|33|reset|()V||',
'M|33|toString|(~S)~S||java/io/UnsupportedEncodingException',
'M|33|toString|(Ljava/nio/charset/Charset;)~S||',
'M|33|toString|(I)~S||',
'M|33|toString|()~S||',
'M|33|write|([BII)V||',
'M|33|write|(I)V||',
'M|1|close|()V||java/io/IOException',
'M|1|writeBytes|([B)V||',
'M|1|writeTo|(~4OutputStream;)V||java/io/IOException',
'M|33|toByteArray|()[B||',
'C|1|java/io/ByteArrayInputStream|~4InputStream;',
'F|4|buf|[B||',
'F|4|pos|I||',
'F|4|mark|I||',
'F|4|count|I||',
'M|1|<init>|([B)V||',
'M|1|<init>|([BII)V||',
'M|33|reset|()V||',
'M|33|read|()I||',
'M|33|read|([BII)I||',
'M|1|close|()V||java/io/IOException',
'M|33|readAllBytes|()[B||',
'M|1|mark|(I)V||',
'M|1|readNBytes|([BII)I||',
'M|33|transferTo|(~4OutputStream;)J||java/io/IOException',
'M|33|skip|(J)J||',
'M|33|available|()I||',
'M|1|markSupported|()Z||',
'C|1|java/io/DataInputStream|~4FilterInputStream;~4DataInput;',
'M|1|<init>|(~4InputStream;)V||',
'M|17|read|([B)I||java/io/IOException',
'M|17|read|([BII)I||java/io/IOException',
'M|17|readLine|()~S||java/io/IOException',
'M|17|readInt|()I||java/io/IOException',
'M|17|readUTF|()~S||java/io/IOException',
'M|25|readUTF|(~4DataInput;)~S||java/io/IOException',
'M|17|readChar|()C||java/io/IOException',
'M|17|readFloat|()F||java/io/IOException',
'M|17|readFully|([B)V||java/io/IOException',
'M|17|readFully|([BII)V||java/io/IOException',
'M|17|skipBytes|(I)I||java/io/IOException',
'M|17|readBoolean|()Z||java/io/IOException',
'M|17|readByte|()B||java/io/IOException',
'M|17|readUnsignedByte|()I||java/io/IOException',
'M|17|readShort|()S||java/io/IOException',
'M|17|readUnsignedShort|()I||java/io/IOException',
'M|17|readLong|()J||java/io/IOException',
'M|17|readDouble|()D||java/io/IOException',
'C|1|java/io/DataOutputStream|~4FilterOutputStream;~4DataOutput;',
'F|4|written|I||',
'M|1|<init>|(~4OutputStream;)V||',
'M|17|size|()I||',
'M|1|flush|()V||java/io/IOException',
'M|33|write|(I)V||java/io/IOException',
'M|33|write|([BII)V||java/io/IOException',
'M|17|writeInt|(I)V||java/io/IOException',
'M|17|writeUTF|(~S)V||java/io/IOException',
'M|17|writeBytes|(~S)V||java/io/IOException',
'M|17|writeChar|(I)V||java/io/IOException',
'M|17|writeFloat|(F)V||java/io/IOException',
'M|17|writeBoolean|(Z)V||java/io/IOException',
'M|17|writeByte|(I)V||java/io/IOException',
'M|17|writeShort|(I)V||java/io/IOException',
'M|17|writeLong|(J)V||java/io/IOException',
'M|17|writeDouble|(D)V||java/io/IOException',
'M|17|writeChars|(~S)V||java/io/IOException',
'C|1537|java/io/DataInput|~O',
'M|1025|readLine|()~S||java/io/IOException',
'M|1025|readInt|()I||java/io/IOException',
'M|1025|readUTF|()~S||java/io/IOException',
'M|1025|readChar|()C||java/io/IOException',
'M|1025|readFloat|()F||java/io/IOException',
'M|1025|readFully|([B)V||java/io/IOException',
'M|1025|readFully|([BII)V||java/io/IOException',
'M|1025|skipBytes|(I)I||java/io/IOException',
'M|1025|readBoolean|()Z||java/io/IOException',
'M|1025|readByte|()B||java/io/IOException',
'M|1025|readUnsignedByte|()I||java/io/IOException',
'M|1025|readShort|()S||java/io/IOException',
'M|1025|readUnsignedShort|()I||java/io/IOException',
'M|1025|readLong|()J||java/io/IOException',
'M|1025|readDouble|()D||java/io/IOException',
'C|1537|java/io/DataOutput|~O',
'M|1025|write|([BII)V||java/io/IOException',
'M|1025|write|([B)V||java/io/IOException',
'M|1025|write|(I)V||java/io/IOException',
'M|1025|writeInt|(I)V||java/io/IOException',
'M|1025|writeUTF|(~S)V||java/io/IOException',
'M|1025|writeBytes|(~S)V||java/io/IOException',
'M|1025|writeChar|(I)V||java/io/IOException',
'M|1025|writeFloat|(F)V||java/io/IOException',
'M|1025|writeBoolean|(Z)V||java/io/IOException',
'M|1025|writeByte|(I)V||java/io/IOException',
'M|1025|writeShort|(I)V||java/io/IOException',
'M|1025|writeLong|(J)V||java/io/IOException',
'M|1025|writeDouble|(D)V||java/io/IOException',
'M|1025|writeChars|(~S)V||java/io/IOException',
'C|1|java/io/StringReader|~4Reader;',
'M|1|<init>|(~S)V||',
'M|1|reset|()V||java/io/IOException',
'M|1|read|([CII)I||java/io/IOException',
'M|1|read|()I||java/io/IOException',
'M|1|close|()V||',
'M|1|mark|(I)V||java/io/IOException',
'M|1|skip|(J)J||java/io/IOException',
'M|1|markSupported|()Z||',
'M|1|ready|()Z||java/io/IOException',
'C|1|java/io/StringWriter|~4Writer;',
'M|1|<init>|()V||',
'M|1|<init>|(I)V||',
'M|1|toString|()~S||',
'M|1|append|(~1CharSequence;II)~4StringWriter;||',
'M|1|append|(C)~4StringWriter;||',
'M|1|append|(~1CharSequence;)~4StringWriter;||',
'M|1|flush|()V||',
'M|1|write|([CII)V||',
'M|1|write|(~SII)V||',
'M|1|write|(~S)V||',
'M|1|write|(I)V||',
'M|1|close|()V||java/io/IOException',
'M|1|getBuffer|()~1StringBuffer;||',
'C|1|java/io/ObjectInputStream|~4InputStream;~4ObjectInput;~4ObjectStreamConstants;',
'M|1|<init>|(~4InputStream;)V||java/io/IOException',
'M|4|<init>|()V||java/io/IOException,java/lang/SecurityException',
'M|4|resolveClass|(~4ObjectStreamClass;)~1Class;|(~4ObjectStreamClass;)~1Class<*>;|java/io/IOException,java/lang/ClassNotFoundException',
'M|1|defaultReadObject|()V||java/io/IOException,java/lang/ClassNotFoundException',
'M|17|readObject|()~O||java/io/IOException,java/lang/ClassNotFoundException',
'M|1|read|([BII)I||java/io/IOException',
'M|1|read|()I||java/io/IOException',
'M|1|readFields|()~4ObjectInputStream$GetField;||java/io/IOException,java/lang/ClassNotFoundException',
'M|1|readLine|()~S||java/io/IOException',
'M|1|close|()V||java/io/IOException',
'M|1|readInt|()I||java/io/IOException',
'M|1|available|()I||java/io/IOException',
'M|1|readUTF|()~S||java/io/IOException',
'M|1|readChar|()C||java/io/IOException',
'M|1|readFloat|()F||java/io/IOException',
'M|1|readFully|([B)V||java/io/IOException',
'M|1|readFully|([BII)V||java/io/IOException',
'M|1|skipBytes|(I)I||java/io/IOException',
'M|1|readBoolean|()Z||java/io/IOException',
'M|1|readByte|()B||java/io/IOException',
'M|1|readUnsignedByte|()I||java/io/IOException',
'M|1|readShort|()S||java/io/IOException',
'M|1|readUnsignedShort|()I||java/io/IOException',
'M|1|readLong|()J||java/io/IOException',
'M|1|readDouble|()D||java/io/IOException',
'M|4|readStreamHeader|()V||java/io/IOException,java/io/StreamCorruptedException',
'M|4|readObjectOverride|()~O||java/io/IOException,java/lang/ClassNotFoundException',
'M|4|resolveObject|(~O)~O||java/io/IOException',
'M|4|resolveProxyClass|([~S)~1Class;|([~S)~1Class<*>;|java/io/IOException,java/lang/ClassNotFoundException',
'M|4|readClassDescriptor|()~4ObjectStreamClass;||java/io/IOException,java/lang/ClassNotFoundException',
'M|1|readUnshared|()~O||java/io/IOException,java/lang/ClassNotFoundException',
'M|1|registerValidation|(~4ObjectInputValidation;I)V||java/io/NotActiveException,java/io/InvalidObjectException',
'M|4|enableResolveObject|(Z)Z||java/lang/SecurityException',
'M|17|getObjectInputFilter|()~4ObjectInputFilter;||',
'M|17|setObjectInputFilter|(~4ObjectInputFilter;)V||',
'C|1|java/io/ObjectOutputStream|~4OutputStream;~4ObjectOutput;~4ObjectStreamConstants;',
'M|1|<init>|(~4OutputStream;)V||java/io/IOException',
'M|4|<init>|()V||java/io/IOException,java/lang/SecurityException',
'M|1|reset|()V||java/io/IOException',
'M|1|flush|()V||java/io/IOException',
'M|1|write|(I)V||java/io/IOException',
'M|1|write|([B)V||java/io/IOException',
'M|1|write|([BII)V||java/io/IOException',
'M|1|defaultWriteObject|()V||java/io/IOException',
'M|17|writeObject|(~O)V||java/io/IOException',
'M|1|putFields|()~4ObjectOutputStream$PutField;||java/io/IOException',
'M|1|writeFields|()V||java/io/IOException',
'M|1|close|()V||java/io/IOException',
'M|1|writeInt|(I)V||java/io/IOException',
'M|1|writeUTF|(~S)V||java/io/IOException',
'M|1|writeBytes|(~S)V||java/io/IOException',
'M|1|writeChar|(I)V||java/io/IOException',
'M|1|writeFloat|(F)V||java/io/IOException',
'M|1|writeBoolean|(Z)V||java/io/IOException',
'M|1|writeByte|(I)V||java/io/IOException',
'M|1|writeShort|(I)V||java/io/IOException',
'M|1|writeLong|(J)V||java/io/IOException',
'M|1|writeDouble|(D)V||java/io/IOException',
'M|1|writeChars|(~S)V||java/io/IOException',
'M|4|writeStreamHeader|()V||java/io/IOException',
'M|4|writeObjectOverride|(~O)V||java/io/IOException',
'M|4|drain|()V||java/io/IOException',
'M|4|replaceObject|(~O)~O||java/io/IOException',
'M|4|annotateProxyClass|(~1Class;)V|(~1Class<*>;)V|java/io/IOException',
'M|4|writeClassDescriptor|(~4ObjectStreamClass;)V||java/io/IOException',
'M|4|annotateClass|(~1Class;)V|(~1Class<*>;)V|java/io/IOException',
'M|1|useProtocolVersion|(I)V||java/io/IOException',
'M|1|writeUnshared|(~O)V||java/io/IOException',
'M|4|enableReplaceObject|(Z)Z||java/lang/SecurityException',
'C|1|java/io/BufferedInputStream|~4FilterInputStream;',
'F|68|buf|[B||',
'F|4|count|I||',
'F|4|pos|I||',
'F|4|markpos|I||',
'F|4|marklimit|I||',
'M|1|<init>|(~4InputStream;I)V||',
'M|1|<init>|(~4InputStream;)V||',
'M|1|reset|()V||java/io/IOException',
'M|1|read|([BII)I||java/io/IOException',
'M|1|read|()I||java/io/IOException',
'M|1|close|()V||java/io/IOException',
'M|1|mark|(I)V||',
'M|1|transferTo|(~4OutputStream;)J||java/io/IOException',
'M|1|skip|(J)J||java/io/IOException',
'M|1|available|()I||java/io/IOException',
'M|1|markSupported|()Z||',
'C|1|java/io/BufferedOutputStream|~4FilterOutputStream;',
'F|4|buf|[B||',
'F|4|count|I||',
'M|1|<init>|(~4OutputStream;)V||',
'M|1|<init>|(~4OutputStream;I)V||',
'M|1|flush|()V||java/io/IOException',
'M|1|write|([BII)V||java/io/IOException',
'M|1|write|(I)V||java/io/IOException',
'C|1|java/io/Console|~O~4Flushable;',
'M|1|flush|()V||',
'M|129|format|(~S[~O)~4Console;||',
'M|1|charset|()Ljava/nio/charset/Charset;||',
'M|129|printf|(~S[~O)~4Console;||',
'M|1|readLine|()~S||',
'M|129|readLine|(~S[~O)~S||',
'M|1|reader|()~4Reader;||',
'M|1|writer|()~4PrintWriter;||',
'M|1|readPassword|()[C||',
'M|129|readPassword|(~S[~O)[C||',
'C|1537|java/util/List|<E:~O>~O~2SequencedCollection<TE;>;',
'M|1025|remove|(~O)Z||',
'M|1025|remove|(I)~O|(I)TE;|',
'M|1025|size|()I||',
'M|1025|get|(I)~O|(I)TE;|',
'M|1025|equals|(~O)Z||',
'M|1025|hashCode|()I||',
'M|9|copyOf|(~2Collection;)~2List;|<E:~O>(~2Collection<+TE;>;)~2List<TE;>;|',
'M|1025|indexOf|(~O)I||',
'M|1025|clear|()V||',
'M|1025|lastIndexOf|(~O)I||',
'M|1025|isEmpty|()Z||',
'M|65537|replaceAll|(~3UnaryOperator;)V|(~3UnaryOperator<TE;>;)V|',
'M|1025|add|(~O)Z|(TE;)Z|',
'M|1025|add|(I~O)V|(ITE;)V|',
'M|1025|subList|(II)~2List;|(II)~2List<TE;>;|',
'M|1025|toArray|()[~O||',
'M|1025|toArray|([~O)[~O|<T:~O>([TT;)[TT;|',
'M|1025|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|9|of|(~O~O~O)~2List;|<E:~O>(TE;TE;TE;)~2List<TE;>;|',
'M|9|of|(~O~O~O~O)~2List;|<E:~O>(TE;TE;TE;TE;)~2List<TE;>;|',
'M|9|of|(~O~O~O~O~O)~2List;|<E:~O>(TE;TE;TE;TE;TE;)~2List<TE;>;|',
'M|9|of|(~O~O~O~O~O~O~O~O~O~O)~2List;|<E:~O>(TE;TE;TE;TE;TE;TE;TE;TE;TE;TE;)~2List<TE;>;|',
'M|9|of|(~O~O~O~O~O~O~O~O~O)~2List;|<E:~O>(TE;TE;TE;TE;TE;TE;TE;TE;TE;)~2List<TE;>;|',
'M|9|of|()~2List;|<E:~O>()~2List<TE;>;|',
'M|9|of|(~O)~2List;|<E:~O>(TE;)~2List<TE;>;|',
'M|9|of|(~O~O)~2List;|<E:~O>(TE;TE;)~2List<TE;>;|',
'M|9|of|(~O~O~O~O~O~O~O)~2List;|<E:~O>(TE;TE;TE;TE;TE;TE;TE;)~2List<TE;>;|',
'M|9|of|(~O~O~O~O~O~O~O~O)~2List;|<E:~O>(TE;TE;TE;TE;TE;TE;TE;TE;)~2List<TE;>;|',
'M|137|of|([~O)~2List;|<E:~O>([TE;)~2List<TE;>;|',
'M|9|of|(~O~O~O~O~O~O)~2List;|<E:~O>(TE;TE;TE;TE;TE;TE;)~2List<TE;>;|',
'M|1025|contains|(~O)Z||',
'M|65537|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|1025|addAll|(~2Collection;)Z|(~2Collection<+TE;>;)Z|',
'M|1025|addAll|(I~2Collection;)Z|(I~2Collection<+TE;>;)Z|',
'M|1025|set|(I~O)~O|(ITE;)TE;|',
'M|65537|sort|(~2Comparator;)V|(~2Comparator<-TE;>;)V|',
'M|65537|getFirst|()~O|()TE;|',
'M|65537|getLast|()~O|()TE;|',
'M|65537|addFirst|(~O)V|(TE;)V|',
'M|65537|addLast|(~O)V|(TE;)V|',
'M|65537|removeFirst|()~O|()TE;|',
'M|65537|removeLast|()~O|()TE;|',
'M|1025|removeAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1025|retainAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1025|listIterator|()~2ListIterator;|()~2ListIterator<TE;>;|',
'M|1025|listIterator|(I)~2ListIterator;|(I)~2ListIterator<TE;>;|',
'M|65537|reversed|()~2List;|()~2List<TE;>;|',
'M|1025|containsAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'C|1|java/util/ArrayList|<E:~O>~2AbstractList<TE;>;~2List<TE;>;~2RandomAccess;~1Cloneable;~4Serializable;',
'M|1|<init>|(~2Collection;)V|(~2Collection<+TE;>;)V|',
'M|1|<init>|()V||',
'M|1|<init>|(I)V||',
'M|1|remove|(~O)Z||',
'M|1|remove|(I)~O|(I)TE;|',
'M|1|size|()I||',
'M|1|get|(I)~O|(I)TE;|',
'M|1|equals|(~O)Z||',
'M|1|hashCode|()I||',
'M|1|clone|()~O||',
'M|1|indexOf|(~O)I||',
'M|1|clear|()V||',
'M|1|lastIndexOf|(~O)I||',
'M|1|isEmpty|()Z||',
'M|1|replaceAll|(~3UnaryOperator;)V|(~3UnaryOperator<TE;>;)V|',
'M|1|add|(I~O)V|(ITE;)V|',
'M|1|add|(~O)Z|(TE;)Z|',
'M|1|subList|(II)~2List;|(II)~2List<TE;>;|',
'M|1|toArray|()[~O||',
'M|1|toArray|([~O)[~O|<T:~O>([TT;)[TT;|',
'M|1|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1|contains|(~O)Z||',
'M|1|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|1|addAll|(I~2Collection;)Z|(I~2Collection<+TE;>;)Z|',
'M|1|addAll|(~2Collection;)Z|(~2Collection<+TE;>;)Z|',
'M|1|set|(I~O)~O|(ITE;)TE;|',
'M|1|forEach|(~3Consumer;)V|(~3Consumer<-TE;>;)V|',
'M|1|sort|(~2Comparator;)V|(~2Comparator<-TE;>;)V|',
'M|1|ensureCapacity|(I)V||',
'M|1|trimToSize|()V||',
'M|1|removeIf|(~3Predicate;)Z|(~3Predicate<-TE;>;)Z|',
'M|1|getFirst|()~O|()TE;|',
'M|1|getLast|()~O|()TE;|',
'M|1|addFirst|(~O)V|(TE;)V|',
'M|1|addLast|(~O)V|(TE;)V|',
'M|1|removeFirst|()~O|()TE;|',
'M|1|removeLast|()~O|()TE;|',
'M|4|removeRange|(II)V||',
'M|1|removeAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|retainAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|listIterator|(I)~2ListIterator;|(I)~2ListIterator<TE;>;|',
'M|1|listIterator|()~2ListIterator;|()~2ListIterator<TE;>;|',
'C|1|java/util/LinkedList|<E:~O>~2AbstractSequentialList<TE;>;~2List<TE;>;~2Deque<TE;>;~1Cloneable;~4Serializable;',
'M|1|<init>|()V||',
'M|1|<init>|(~2Collection;)V|(~2Collection<+TE;>;)V|',
'M|1|remove|()~O|()TE;|',
'M|1|remove|(~O)Z||',
'M|1|remove|(I)~O|(I)TE;|',
'M|1|size|()I||',
'M|1|get|(I)~O|(I)TE;|',
'M|1|clone|()~O||',
'M|1|indexOf|(~O)I||',
'M|1|clear|()V||',
'M|1|lastIndexOf|(~O)I||',
'M|1|add|(I~O)V|(ITE;)V|',
'M|1|add|(~O)Z|(TE;)Z|',
'M|1|toArray|()[~O||',
'M|1|toArray|([~O)[~O|<T:~O>([TT;)[TT;|',
'M|1|contains|(~O)Z||',
'M|1|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|1|addAll|(I~2Collection;)Z|(I~2Collection<+TE;>;)Z|',
'M|1|addAll|(~2Collection;)Z|(~2Collection<+TE;>;)Z|',
'M|1|set|(I~O)~O|(ITE;)TE;|',
'M|1|peek|()~O|()TE;|',
'M|1|getFirst|()~O|()TE;|',
'M|1|getLast|()~O|()TE;|',
'M|1|element|()~O|()TE;|',
'M|1|addFirst|(~O)V|(TE;)V|',
'M|1|addLast|(~O)V|(TE;)V|',
'M|1|removeFirst|()~O|()TE;|',
'M|1|removeLast|()~O|()TE;|',
'M|1|listIterator|(I)~2ListIterator;|(I)~2ListIterator<TE;>;|',
'M|1|reversed|()~2LinkedList;|()~2LinkedList<TE;>;|',
'M|1|poll|()~O|()TE;|',
'M|1|push|(~O)V|(TE;)V|',
'M|1|pop|()~O|()TE;|',
'M|1|pollFirst|()~O|()TE;|',
'M|1|pollLast|()~O|()TE;|',
'M|1|offerLast|(~O)Z|(TE;)Z|',
'M|1|peekFirst|()~O|()TE;|',
'M|1|removeFirstOccurrence|(~O)Z||',
'M|1|offerFirst|(~O)Z|(TE;)Z|',
'M|1|peekLast|()~O|()TE;|',
'M|1|removeLastOccurrence|(~O)Z||',
'M|1|offer|(~O)Z|(TE;)Z|',
'M|1|descendingIterator|()~2Iterator;|()~2Iterator<TE;>;|',
'C|1537|java/util/Map|<K:~OV:~O>~O',
'M|65537|remove|(~O~O)Z||',
'M|1025|remove|(~O)~O|(~O)TV;|',
'M|1025|size|()I||',
'M|1025|get|(~O)~O|(~O)TV;|',
'M|1025|put|(~O~O)~O|(TK;TV;)TV;|',
'M|1025|equals|(~O)Z||',
'M|1025|values|()~2Collection;|()~2Collection<TV;>;|',
'M|1025|hashCode|()I||',
'M|9|copyOf|(~2Map;)~2Map;|<K:~OV:~O>(~2Map<+TK;+TV;>;)~2Map<TK;TV;>;|',
'M|1025|clear|()V||',
'M|1025|isEmpty|()Z||',
'M|65537|replace|(~O~O~O)Z|(TK;TV;TV;)Z|',
'M|65537|replace|(~O~O)~O|(TK;TV;)TV;|',
'M|65537|replaceAll|(~3BiFunction;)V|(~3BiFunction<-TK;-TV;+TV;>;)V|',
'M|9|of|(~O~O~O~O~O~O~O~O)~2Map;|<K:~OV:~O>(TK;TV;TK;TV;TK;TV;TK;TV;)~2Map<TK;TV;>;|',
'M|9|of|()~2Map;|<K:~OV:~O>()~2Map<TK;TV;>;|',
'M|9|of|(~O~O)~2Map;|<K:~OV:~O>(TK;TV;)~2Map<TK;TV;>;|',
'M|9|of|(~O~O~O~O)~2Map;|<K:~OV:~O>(TK;TV;TK;TV;)~2Map<TK;TV;>;|',
'M|9|of|(~O~O~O~O~O~O)~2Map;|<K:~OV:~O>(TK;TV;TK;TV;TK;TV;)~2Map<TK;TV;>;|',
'M|9|of|(~O~O~O~O~O~O~O~O~O~O~O~O~O~O~O~O~O~O~O~O)~2Map;|<K:~OV:~O>(TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;)~2Map<TK;TV;>;|',
'M|9|of|(~O~O~O~O~O~O~O~O~O~O~O~O~O~O~O~O~O~O)~2Map;|<K:~OV:~O>(TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;)~2Map<TK;TV;>;|',
'M|9|of|(~O~O~O~O~O~O~O~O~O~O~O~O~O~O~O~O)~2Map;|<K:~OV:~O>(TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;)~2Map<TK;TV;>;|',
'M|9|of|(~O~O~O~O~O~O~O~O~O~O~O~O~O~O)~2Map;|<K:~OV:~O>(TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;)~2Map<TK;TV;>;|',
'M|9|of|(~O~O~O~O~O~O~O~O~O~O~O~O)~2Map;|<K:~OV:~O>(TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;)~2Map<TK;TV;>;|',
'M|9|of|(~O~O~O~O~O~O~O~O~O~O)~2Map;|<K:~OV:~O>(TK;TV;TK;TV;TK;TV;TK;TV;TK;TV;)~2Map<TK;TV;>;|',
'M|65537|merge|(~O~O~3BiFunction;)~O|(TK;TV;~3BiFunction<-TV;-TV;+TV;>;)TV;|',
'M|1025|entrySet|()~2Set;|()~2Set<~2Map$Entry<TK;TV;>;>;|',
'M|1025|putAll|(~2Map;)V|(~2Map<+TK;+TV;>;)V|',
'M|65537|putIfAbsent|(~O~O)~O|(TK;TV;)TV;|',
'M|65537|compute|(~O~3BiFunction;)~O|(TK;~3BiFunction<-TK;-TV;+TV;>;)TV;|',
'M|9|entry|(~O~O)~2Map$Entry;|<K:~OV:~O>(TK;TV;)~2Map$Entry<TK;TV;>;|',
'M|65537|forEach|(~3BiConsumer;)V|(~3BiConsumer<-TK;-TV;>;)V|',
'M|1025|containsKey|(~O)Z||',
'M|65537|computeIfAbsent|(~O~3Function;)~O|(TK;~3Function<-TK;+TV;>;)TV;|',
'M|1025|keySet|()~2Set;|()~2Set<TK;>;|',
'M|1025|containsValue|(~O)Z||',
'M|65537|getOrDefault|(~O~O)~O|(~OTV;)TV;|',
'M|65537|computeIfPresent|(~O~3BiFunction;)~O|(TK;~3BiFunction<-TK;-TV;+TV;>;)TV;|',
'M|137|ofEntries|([~2Map$Entry;)~2Map;|<K:~OV:~O>([~2Map$Entry<+TK;+TV;>;)~2Map<TK;TV;>;|',
'C|1537|java/util/Map$Entry|<K:~OV:~O>~O',
'M|1025|equals|(~O)Z||',
'M|1025|hashCode|()I||',
'M|9|copyOf|(~2Map$Entry;)~2Map$Entry;|<K:~OV:~O>(~2Map$Entry<+TK;+TV;>;)~2Map$Entry<TK;TV;>;|',
'M|1025|getValue|()~O|()TV;|',
'M|1025|getKey|()~O|()TK;|',
'M|9|comparingByKey|(~2Comparator;)~2Comparator;|<K:~OV:~O>(~2Comparator<-TK;>;)~2Comparator<~2Map$Entry<TK;TV;>;>;|',
'M|9|comparingByKey|()~2Comparator;|<K::~1Comparable<-TK;>;V:~O>()~2Comparator<~2Map$Entry<TK;TV;>;>;|',
'M|1025|setValue|(~O)~O|(TV;)TV;|',
'M|9|comparingByValue|()~2Comparator;|<K:~OV::~1Comparable<-TV;>;>()~2Comparator<~2Map$Entry<TK;TV;>;>;|',
'M|9|comparingByValue|(~2Comparator;)~2Comparator;|<K:~OV:~O>(~2Comparator<-TV;>;)~2Comparator<~2Map$Entry<TK;TV;>;>;|',
'C|1|java/util/HashMap|<K:~OV:~O>~2AbstractMap<TK;TV;>;~2Map<TK;TV;>;~1Cloneable;~4Serializable;',
'M|1|<init>|(I)V||',
'M|1|<init>|(IF)V||',
'M|1|<init>|()V||',
'M|1|<init>|(~2Map;)V|(~2Map<+TK;+TV;>;)V|',
'M|1|remove|(~O)~O|(~O)TV;|',
'M|1|remove|(~O~O)Z||',
'M|1|size|()I||',
'M|1|get|(~O)~O|(~O)TV;|',
'M|1|put|(~O~O)~O|(TK;TV;)TV;|',
'M|1|values|()~2Collection;|()~2Collection<TV;>;|',
'M|1|clone|()~O||',
'M|1|clear|()V||',
'M|1|isEmpty|()Z||',
'M|1|replace|(~O~O)~O|(TK;TV;)TV;|',
'M|1|replace|(~O~O~O)Z|(TK;TV;TV;)Z|',
'M|1|replaceAll|(~3BiFunction;)V|(~3BiFunction<-TK;-TV;+TV;>;)V|',
'M|1|merge|(~O~O~3BiFunction;)~O|(TK;TV;~3BiFunction<-TV;-TV;+TV;>;)TV;|',
'M|9|newHashMap|(I)~2HashMap;|<K:~OV:~O>(I)~2HashMap<TK;TV;>;|',
'M|1|entrySet|()~2Set;|()~2Set<~2Map$Entry<TK;TV;>;>;|',
'M|1|putAll|(~2Map;)V|(~2Map<+TK;+TV;>;)V|',
'M|1|putIfAbsent|(~O~O)~O|(TK;TV;)TV;|',
'M|1|compute|(~O~3BiFunction;)~O|(TK;~3BiFunction<-TK;-TV;+TV;>;)TV;|',
'M|1|forEach|(~3BiConsumer;)V|(~3BiConsumer<-TK;-TV;>;)V|',
'M|1|containsKey|(~O)Z||',
'M|1|computeIfAbsent|(~O~3Function;)~O|(TK;~3Function<-TK;+TV;>;)TV;|',
'M|1|keySet|()~2Set;|()~2Set<TK;>;|',
'M|1|containsValue|(~O)Z||',
'M|1|getOrDefault|(~O~O)~O|(~OTV;)TV;|',
'M|1|computeIfPresent|(~O~3BiFunction;)~O|(TK;~3BiFunction<-TK;-TV;+TV;>;)TV;|',
'C|1|java/util/LinkedHashMap|<K:~OV:~O>~2HashMap<TK;TV;>;~2SequencedMap<TK;TV;>;',
'M|1|<init>|(~2Map;)V|(~2Map<+TK;+TV;>;)V|',
'M|1|<init>|(I)V||',
'M|1|<init>|(IF)V||',
'M|1|<init>|(IFZ)V||',
'M|1|<init>|()V||',
'M|1|get|(~O)~O|(~O)TV;|',
'M|1|values|()~2Collection;|()~2Collection<TV;>;|',
'M|1|clear|()V||',
'M|1|replaceAll|(~3BiFunction;)V|(~3BiFunction<-TK;-TV;+TV;>;)V|',
'M|1|entrySet|()~2Set;|()~2Set<~2Map$Entry<TK;TV;>;>;|',
'M|9|newLinkedHashMap|(I)~2LinkedHashMap;|<K:~OV:~O>(I)~2LinkedHashMap<TK;TV;>;|',
'M|1|forEach|(~3BiConsumer;)V|(~3BiConsumer<-TK;-TV;>;)V|',
'M|1|keySet|()~2Set;|()~2Set<TK;>;|',
'M|1|containsValue|(~O)Z||',
'M|1|getOrDefault|(~O~O)~O|(~OTV;)TV;|',
'M|1|reversed|()~2SequencedMap;|()~2SequencedMap<TK;TV;>;|',
'M|4|removeEldestEntry|(~2Map$Entry;)Z|(~2Map$Entry<TK;TV;>;)Z|',
'M|1|sequencedKeySet|()~2SequencedSet;|()~2SequencedSet<TK;>;|',
'M|1|sequencedValues|()~2SequencedCollection;|()~2SequencedCollection<TV;>;|',
'M|1|sequencedEntrySet|()~2SequencedSet;|()~2SequencedSet<~2Map$Entry<TK;TV;>;>;|',
'M|1|putFirst|(~O~O)~O|(TK;TV;)TV;|',
'M|1|putLast|(~O~O)~O|(TK;TV;)TV;|',
'C|1|java/util/TreeMap|<K:~OV:~O>~2AbstractMap<TK;TV;>;~2NavigableMap<TK;TV;>;~1Cloneable;~4Serializable;',
'M|1|<init>|(~2SortedMap;)V|(~2SortedMap<TK;+TV;>;)V|',
'M|1|<init>|(~2Map;)V|(~2Map<+TK;+TV;>;)V|',
'M|1|<init>|(~2Comparator;)V|(~2Comparator<-TK;>;)V|',
'M|1|<init>|()V||',
'M|1|remove|(~O)~O|(~O)TV;|',
'M|1|size|()I||',
'M|1|get|(~O)~O|(~O)TV;|',
'M|1|put|(~O~O)~O|(TK;TV;)TV;|',
'M|1|values|()~2Collection;|()~2Collection<TV;>;|',
'M|1|clone|()~O||',
'M|1|clear|()V||',
'M|1|replace|(~O~O~O)Z|(TK;TV;TV;)Z|',
'M|1|replace|(~O~O)~O|(TK;TV;)TV;|',
'M|1|replaceAll|(~3BiFunction;)V|(~3BiFunction<-TK;-TV;+TV;>;)V|',
'M|1|merge|(~O~O~3BiFunction;)~O|(TK;TV;~3BiFunction<-TV;-TV;+TV;>;)TV;|',
'M|1|entrySet|()~2Set;|()~2Set<~2Map$Entry<TK;TV;>;>;|',
'M|1|putAll|(~2Map;)V|(~2Map<+TK;+TV;>;)V|',
'M|1|putIfAbsent|(~O~O)~O|(TK;TV;)TV;|',
'M|1|compute|(~O~3BiFunction;)~O|(TK;~3BiFunction<-TK;-TV;+TV;>;)TV;|',
'M|1|forEach|(~3BiConsumer;)V|(~3BiConsumer<-TK;-TV;>;)V|',
'M|1|containsKey|(~O)Z||',
'M|1|computeIfAbsent|(~O~3Function;)~O|(TK;~3Function<-TK;+TV;>;)TV;|',
'M|1|keySet|()~2Set;|()~2Set<TK;>;|',
'M|1|containsValue|(~O)Z||',
'M|1|computeIfPresent|(~O~3BiFunction;)~O|(TK;~3BiFunction<-TK;-TV;+TV;>;)TV;|',
'M|1|comparator|()~2Comparator;|()~2Comparator<-TK;>;|',
'M|1|firstKey|()~O|()TK;|',
'M|1|putFirst|(~O~O)~O|(TK;TV;)TV;|',
'M|1|putLast|(~O~O)~O|(TK;TV;)TV;|',
'M|1|firstEntry|()~2Map$Entry;|()~2Map$Entry<TK;TV;>;|',
'M|1|lastEntry|()~2Map$Entry;|()~2Map$Entry<TK;TV;>;|',
'M|1|pollFirstEntry|()~2Map$Entry;|()~2Map$Entry<TK;TV;>;|',
'M|1|pollLastEntry|()~2Map$Entry;|()~2Map$Entry<TK;TV;>;|',
'M|1|descendingMap|()~2NavigableMap;|()~2NavigableMap<TK;TV;>;|',
'M|1|lowerEntry|(~O)~2Map$Entry;|(TK;)~2Map$Entry<TK;TV;>;|',
'M|1|lowerKey|(~O)~O|(TK;)TK;|',
'M|1|floorEntry|(~O)~2Map$Entry;|(TK;)~2Map$Entry<TK;TV;>;|',
'M|1|floorKey|(~O)~O|(TK;)TK;|',
'M|1|ceilingEntry|(~O)~2Map$Entry;|(TK;)~2Map$Entry<TK;TV;>;|',
'M|1|ceilingKey|(~O)~O|(TK;)TK;|',
'M|1|higherEntry|(~O)~2Map$Entry;|(TK;)~2Map$Entry<TK;TV;>;|',
'M|1|higherKey|(~O)~O|(TK;)TK;|',
'M|1|navigableKeySet|()~2NavigableSet;|()~2NavigableSet<TK;>;|',
'M|1|descendingKeySet|()~2NavigableSet;|()~2NavigableSet<TK;>;|',
'M|1|subMap|(~O~O)~2SortedMap;|(TK;TK;)~2SortedMap<TK;TV;>;|',
'M|1|subMap|(~OZ~OZ)~2NavigableMap;|(TK;ZTK;Z)~2NavigableMap<TK;TV;>;|',
'M|1|headMap|(~OZ)~2NavigableMap;|(TK;Z)~2NavigableMap<TK;TV;>;|',
'M|1|headMap|(~O)~2SortedMap;|(TK;)~2SortedMap<TK;TV;>;|',
'M|1|tailMap|(~O)~2SortedMap;|(TK;)~2SortedMap<TK;TV;>;|',
'M|1|tailMap|(~OZ)~2NavigableMap;|(TK;Z)~2NavigableMap<TK;TV;>;|',
'M|1|lastKey|()~O|()TK;|',
'C|1025|java/util/AbstractMap|<K:~OV:~O>~O~2Map<TK;TV;>;',
'M|4|<init>|()V||',
'M|1|remove|(~O)~O|(~O)TV;|',
'M|1|size|()I||',
'M|1|get|(~O)~O|(~O)TV;|',
'M|1|put|(~O~O)~O|(TK;TV;)TV;|',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|values|()~2Collection;|()~2Collection<TV;>;|',
'M|1|hashCode|()I||',
'M|4|clone|()~O||java/lang/CloneNotSupportedException',
'M|1|clear|()V||',
'M|1|isEmpty|()Z||',
'M|1025|entrySet|()~2Set;|()~2Set<~2Map$Entry<TK;TV;>;>;|',
'M|1|putAll|(~2Map;)V|(~2Map<+TK;+TV;>;)V|',
'M|1|containsKey|(~O)Z||',
'M|1|keySet|()~2Set;|()~2Set<TK;>;|',
'M|1|containsValue|(~O)Z||',
'C|1|java/util/AbstractMap$SimpleEntry|<K:~OV:~O>~O~2Map$Entry<TK;TV;>;~4Serializable;',
'M|1|<init>|(~O~O)V|(TK;TV;)V|',
'M|1|<init>|(~2Map$Entry;)V|(~2Map$Entry<+TK;+TV;>;)V|',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|getValue|()~O|()TV;|',
'M|1|getKey|()~O|()TK;|',
'M|1|setValue|(~O)~O|(TV;)TV;|',
'C|1|java/util/AbstractMap$SimpleImmutableEntry|<K:~OV:~O>~O~2Map$Entry<TK;TV;>;~4Serializable;',
'M|1|<init>|(~O~O)V|(TK;TV;)V|',
'M|1|<init>|(~2Map$Entry;)V|(~2Map$Entry<+TK;+TV;>;)V|',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|getValue|()~O|()TV;|',
'M|1|getKey|()~O|()TK;|',
'M|1|setValue|(~O)~O|(TV;)TV;|',
'C|1537|java/util/Set|<E:~O>~O~2Collection<TE;>;',
'M|1025|remove|(~O)Z||',
'M|1025|size|()I||',
'M|1025|equals|(~O)Z||',
'M|1025|hashCode|()I||',
'M|9|copyOf|(~2Collection;)~2Set;|<E:~O>(~2Collection<+TE;>;)~2Set<TE;>;|',
'M|1025|clear|()V||',
'M|1025|isEmpty|()Z||',
'M|1025|add|(~O)Z|(TE;)Z|',
'M|1025|toArray|()[~O||',
'M|1025|toArray|([~O)[~O|<T:~O>([TT;)[TT;|',
'M|1025|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|9|of|(~O~O~O~O~O~O)~2Set;|<E:~O>(TE;TE;TE;TE;TE;TE;)~2Set<TE;>;|',
'M|9|of|(~O~O~O~O~O)~2Set;|<E:~O>(TE;TE;TE;TE;TE;)~2Set<TE;>;|',
'M|9|of|(~O~O~O~O)~2Set;|<E:~O>(TE;TE;TE;TE;)~2Set<TE;>;|',
'M|9|of|()~2Set;|<E:~O>()~2Set<TE;>;|',
'M|9|of|(~O~O~O~O~O~O~O~O~O~O)~2Set;|<E:~O>(TE;TE;TE;TE;TE;TE;TE;TE;TE;TE;)~2Set<TE;>;|',
'M|9|of|(~O~O~O~O~O~O~O~O~O)~2Set;|<E:~O>(TE;TE;TE;TE;TE;TE;TE;TE;TE;)~2Set<TE;>;|',
'M|9|of|(~O~O~O~O~O~O~O~O)~2Set;|<E:~O>(TE;TE;TE;TE;TE;TE;TE;TE;)~2Set<TE;>;|',
'M|9|of|(~O~O~O~O~O~O~O)~2Set;|<E:~O>(TE;TE;TE;TE;TE;TE;TE;)~2Set<TE;>;|',
'M|137|of|([~O)~2Set;|<E:~O>([TE;)~2Set<TE;>;|',
'M|9|of|(~O~O~O)~2Set;|<E:~O>(TE;TE;TE;)~2Set<TE;>;|',
'M|9|of|(~O)~2Set;|<E:~O>(TE;)~2Set<TE;>;|',
'M|9|of|(~O~O)~2Set;|<E:~O>(TE;TE;)~2Set<TE;>;|',
'M|1025|contains|(~O)Z||',
'M|65537|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|1025|addAll|(~2Collection;)Z|(~2Collection<+TE;>;)Z|',
'M|1025|removeAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1025|retainAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1025|containsAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'C|1|java/util/HashSet|<E:~O>~2AbstractSet<TE;>;~2Set<TE;>;~1Cloneable;~4Serializable;',
'M|1|<init>|(I)V||',
'M|1|<init>|(IF)V||',
'M|1|<init>|(~2Collection;)V|(~2Collection<+TE;>;)V|',
'M|1|<init>|()V||',
'M|1|remove|(~O)Z||',
'M|1|size|()I||',
'M|1|clone|()~O||',
'M|1|clear|()V||',
'M|1|isEmpty|()Z||',
'M|1|add|(~O)Z|(TE;)Z|',
'M|1|toArray|([~O)[~O|<T:~O>([TT;)[TT;|',
'M|1|toArray|()[~O||',
'M|1|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1|contains|(~O)Z||',
'M|1|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|9|newHashSet|(I)~2HashSet;|<T:~O>(I)~2HashSet<TT;>;|',
'C|1|java/util/LinkedHashSet|<E:~O>~2HashSet<TE;>;~2SequencedSet<TE;>;~1Cloneable;~4Serializable;',
'M|1|<init>|(~2Collection;)V|(~2Collection<+TE;>;)V|',
'M|1|<init>|()V||',
'M|1|<init>|(I)V||',
'M|1|<init>|(IF)V||',
'M|1|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|1|getFirst|()~O|()TE;|',
'M|1|getLast|()~O|()TE;|',
'M|1|addFirst|(~O)V|(TE;)V|',
'M|1|addLast|(~O)V|(TE;)V|',
'M|1|removeFirst|()~O|()TE;|',
'M|1|removeLast|()~O|()TE;|',
'M|1|reversed|()~2SequencedSet;|()~2SequencedSet<TE;>;|',
'M|9|newLinkedHashSet|(I)~2LinkedHashSet;|<T:~O>(I)~2LinkedHashSet<TT;>;|',
'C|1|java/util/TreeSet|<E:~O>~2AbstractSet<TE;>;~2NavigableSet<TE;>;~1Cloneable;~4Serializable;',
'M|1|<init>|(~2SortedSet;)V|(~2SortedSet<TE;>;)V|',
'M|1|<init>|(~2Collection;)V|(~2Collection<+TE;>;)V|',
'M|1|<init>|(~2Comparator;)V|(~2Comparator<-TE;>;)V|',
'M|1|<init>|()V||',
'M|1|remove|(~O)Z||',
'M|1|size|()I||',
'M|1|clone|()~O||',
'M|1|floor|(~O)~O|(TE;)TE;|',
'M|1|clear|()V||',
'M|1|isEmpty|()Z||',
'M|1|add|(~O)Z|(TE;)Z|',
'M|1|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1|contains|(~O)Z||',
'M|1|last|()~O|()TE;|',
'M|1|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|1|addAll|(~2Collection;)Z|(~2Collection<+TE;>;)Z|',
'M|1|first|()~O|()TE;|',
'M|1|addFirst|(~O)V|(TE;)V|',
'M|1|addLast|(~O)V|(TE;)V|',
'M|1|lower|(~O)~O|(TE;)TE;|',
'M|1|comparator|()~2Comparator;|()~2Comparator<-TE;>;|',
'M|1|pollFirst|()~O|()TE;|',
'M|1|pollLast|()~O|()TE;|',
'M|1|descendingIterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1|descendingSet|()~2NavigableSet;|()~2NavigableSet<TE;>;|',
'M|1|ceiling|(~O)~O|(TE;)TE;|',
'M|1|higher|(~O)~O|(TE;)TE;|',
'M|1|subSet|(~OZ~OZ)~2NavigableSet;|(TE;ZTE;Z)~2NavigableSet<TE;>;|',
'M|1|subSet|(~O~O)~2SortedSet;|(TE;TE;)~2SortedSet<TE;>;|',
'M|1|headSet|(~OZ)~2NavigableSet;|(TE;Z)~2NavigableSet<TE;>;|',
'M|1|headSet|(~O)~2SortedSet;|(TE;)~2SortedSet<TE;>;|',
'M|1|tailSet|(~OZ)~2NavigableSet;|(TE;Z)~2NavigableSet<TE;>;|',
'M|1|tailSet|(~O)~2SortedSet;|(TE;)~2SortedSet<TE;>;|',
'C|1537|java/util/Collection|<E:~O>~O~1Iterable<TE;>;',
'M|1025|remove|(~O)Z||',
'M|1025|size|()I||',
'M|1025|equals|(~O)Z||',
'M|1025|hashCode|()I||',
'M|1025|clear|()V||',
'M|1025|isEmpty|()Z||',
'M|1025|add|(~O)Z|(TE;)Z|',
'M|1025|toArray|([~O)[~O|<T:~O>([TT;)[TT;|',
'M|65537|toArray|(~3IntFunction;)[~O|<T:~O>(~3IntFunction<[TT;>;)[TT;|',
'M|1025|toArray|()[~O||',
'M|1025|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|65537|stream|()~5Stream;|()~5Stream<TE;>;|',
'M|1025|contains|(~O)Z||',
'M|65537|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|1025|addAll|(~2Collection;)Z|(~2Collection<+TE;>;)Z|',
'M|65537|removeIf|(~3Predicate;)Z|(~3Predicate<-TE;>;)Z|',
'M|1025|removeAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1025|retainAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1025|containsAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|65537|parallelStream|()~5Stream;|()~5Stream<TE;>;|',
'C|1025|java/util/AbstractCollection|<E:~O>~O~2Collection<TE;>;',
'M|4|<init>|()V||',
'M|1|remove|(~O)Z||',
'M|1025|size|()I||',
'M|1|toString|()~S||',
'M|1|clear|()V||',
'M|1|isEmpty|()Z||',
'M|1|add|(~O)Z|(TE;)Z|',
'M|1|toArray|([~O)[~O|<T:~O>([TT;)[TT;|',
'M|1|toArray|()[~O||',
'M|1025|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1|contains|(~O)Z||',
'M|1|addAll|(~2Collection;)Z|(~2Collection<+TE;>;)Z|',
'M|1|removeAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|retainAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|containsAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'C|1025|java/util/AbstractList|<E:~O>~2AbstractCollection<TE;>;~2List<TE;>;',
'F|132|modCount|I||',
'M|4|<init>|()V||',
'M|1|remove|(I)~O|(I)TE;|',
'M|1025|get|(I)~O|(I)TE;|',
'M|1|equals|(~O)Z||',
'M|1|hashCode|()I||',
'M|1|indexOf|(~O)I||',
'M|1|clear|()V||',
'M|1|lastIndexOf|(~O)I||',
'M|1|add|(I~O)V|(ITE;)V|',
'M|1|add|(~O)Z|(TE;)Z|',
'M|1|subList|(II)~2List;|(II)~2List<TE;>;|',
'M|1|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1|addAll|(I~2Collection;)Z|(I~2Collection<+TE;>;)Z|',
'M|1|set|(I~O)~O|(ITE;)TE;|',
'M|4|removeRange|(II)V||',
'M|1|listIterator|()~2ListIterator;|()~2ListIterator<TE;>;|',
'M|1|listIterator|(I)~2ListIterator;|(I)~2ListIterator<TE;>;|',
'C|1025|java/util/AbstractSet|<E:~O>~2AbstractCollection<TE;>;~2Set<TE;>;',
'M|4|<init>|()V||',
'M|1|equals|(~O)Z||',
'M|1|hashCode|()I||',
'M|1|removeAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'C|1025|java/util/AbstractQueue|<E:~O>~2AbstractCollection<TE;>;~2Queue<TE;>;',
'M|4|<init>|()V||',
'M|1|remove|()~O|()TE;|',
'M|1|clear|()V||',
'M|1|add|(~O)Z|(TE;)Z|',
'M|1|addAll|(~2Collection;)Z|(~2Collection<+TE;>;)Z|',
'M|1|element|()~O|()TE;|',
'C|1025|java/util/AbstractSequentialList|<E:~O>~2AbstractList<TE;>;',
'M|4|<init>|()V||',
'M|1|remove|(I)~O|(I)TE;|',
'M|1|get|(I)~O|(I)TE;|',
'M|1|add|(I~O)V|(ITE;)V|',
'M|1|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1|addAll|(I~2Collection;)Z|(I~2Collection<+TE;>;)Z|',
'M|1|set|(I~O)~O|(ITE;)TE;|',
'M|1025|listIterator|(I)~2ListIterator;|(I)~2ListIterator<TE;>;|',
'C|1537|java/util/Iterator|<E:~O>~O',
'M|65537|remove|()V||',
'M|65537|forEachRemaining|(~3Consumer;)V|(~3Consumer<-TE;>;)V|',
'M|1025|hasNext|()Z||',
'M|1025|next|()~O|()TE;|',
'C|1537|java/util/ListIterator|<E:~O>~O~2Iterator<TE;>;',
'M|1025|remove|()V||',
'M|1025|add|(~O)V|(TE;)V|',
'M|1025|hasNext|()Z||',
'M|1025|next|()~O|()TE;|',
'M|1025|set|(~O)V|(TE;)V|',
'M|1025|nextIndex|()I||',
'M|1025|previousIndex|()I||',
'M|1025|hasPrevious|()Z||',
'M|1025|previous|()~O|()TE;|',
'C|1|java/util/Collections|~O',
'F|25|EMPTY_SET|~2Set;||',
'F|25|EMPTY_LIST|~2List;||',
'F|25|EMPTY_MAP|~2Map;||',
'M|9|min|(~2Collection;~2Comparator;)~O|<T:~O>(~2Collection<+TT;>;~2Comparator<-TT;>;)TT;|',
'M|9|min|(~2Collection;)~O|<T:~O:~1Comparable<-TT;>;>(~2Collection<+TT;>;)TT;|',
'M|9|max|(~2Collection;)~O|<T:~O:~1Comparable<-TT;>;>(~2Collection<+TT;>;)TT;|',
'M|9|max|(~2Collection;~2Comparator;)~O|<T:~O>(~2Collection<+TT;>;~2Comparator<-TT;>;)TT;|',
'M|9|reverse|(~2List;)V|(~2List<*>;)V|',
'M|9|replaceAll|(~2List;~O~O)Z|<T:~O>(~2List<TT;>;TT;TT;)Z|',
'M|9|fill|(~2List;~O)V|<T:~O>(~2List<-TT;>;TT;)V|',
'M|9|list|(~2Enumeration;)~2ArrayList;|<T:~O>(~2Enumeration<TT;>;)~2ArrayList<TT;>;|',
'M|137|addAll|(~2Collection;[~O)Z|<T:~O>(~2Collection<-TT;>;[TT;)Z|',
'M|9|emptyEnumeration|()~2Enumeration;|<T:~O>()~2Enumeration<TT;>;|',
'M|9|newSetFromMap|(~2Map;)~2Set;|<E:~O>(~2Map<TE;~1Boolean;>;)~2Set<TE;>;|',
'M|25|emptyList|()~2List;|<T:~O>()~2List<TT;>;|',
'M|9|sort|(~2List;)V|<T::~1Comparable<-TT;>;>(~2List<TT;>;)V|',
'M|9|sort|(~2List;~2Comparator;)V|<T:~O>(~2List<TT;>;~2Comparator<-TT;>;)V|',
'M|9|unmodifiableSet|(~2Set;)~2Set;|<T:~O>(~2Set<+TT;>;)~2Set<TT;>;|',
'M|9|enumeration|(~2Collection;)~2Enumeration;|<T:~O>(~2Collection<TT;>;)~2Enumeration<TT;>;|',
'M|9|synchronizedSet|(~2Set;)~2Set;|<T:~O>(~2Set<TT;>;)~2Set<TT;>;|',
'M|9|synchronizedCollection|(~2Collection;)~2Collection;|<T:~O>(~2Collection<TT;>;)~2Collection<TT;>;|',
'M|9|emptyIterator|()~2Iterator;|<T:~O>()~2Iterator<TT;>;|',
'M|9|copy|(~2List;~2List;)V|<T:~O>(~2List<-TT;>;~2List<+TT;>;)V|',
'M|9|nCopies|(I~O)~2List;|<T:~O>(ITT;)~2List<TT;>;|',
'M|9|reverseOrder|(~2Comparator;)~2Comparator;|<T:~O>(~2Comparator<TT;>;)~2Comparator<TT;>;|',
'M|9|reverseOrder|()~2Comparator;|<T:~O>()~2Comparator<TT;>;|',
'M|9|unmodifiableMap|(~2Map;)~2Map;|<K:~OV:~O>(~2Map<+TK;+TV;>;)~2Map<TK;TV;>;|',
'M|9|swap|(~2List;II)V|(~2List<*>;II)V|',
'M|9|binarySearch|(~2List;~O~2Comparator;)I|<T:~O>(~2List<+TT;>;TT;~2Comparator<-TT;>;)I|',
'M|9|binarySearch|(~2List;~O)I|<T:~O>(~2List<+~1Comparable<-TT;>;>;TT;)I|',
'M|9|shuffle|(~2List;~2Random;)V|(~2List<*>;~2Random;)V|',
'M|9|shuffle|(~2List;~2random/RandomGenerator;)V|(~2List<*>;~2random/RandomGenerator;)V|',
'M|9|shuffle|(~2List;)V|(~2List<*>;)V|',
'M|9|rotate|(~2List;I)V|(~2List<*>;I)V|',
'M|9|indexOfSubList|(~2List;~2List;)I|(~2List<*>;~2List<*>;)I|',
'M|9|lastIndexOfSubList|(~2List;~2List;)I|(~2List<*>;~2List<*>;)I|',
'M|9|unmodifiableCollection|(~2Collection;)~2Collection;|<T:~O>(~2Collection<+TT;>;)~2Collection<TT;>;|',
'M|9|unmodifiableSequencedCollection|(~2SequencedCollection;)~2SequencedCollection;|<T:~O>(~2SequencedCollection<+TT;>;)~2SequencedCollection<TT;>;|',
'M|9|unmodifiableSequencedSet|(~2SequencedSet;)~2SequencedSet;|<T:~O>(~2SequencedSet<+TT;>;)~2SequencedSet<TT;>;|',
'M|9|unmodifiableSortedSet|(~2SortedSet;)~2SortedSet;|<T:~O>(~2SortedSet<TT;>;)~2SortedSet<TT;>;|',
'M|9|unmodifiableNavigableSet|(~2NavigableSet;)~2NavigableSet;|<T:~O>(~2NavigableSet<TT;>;)~2NavigableSet<TT;>;|',
'M|9|unmodifiableList|(~2List;)~2List;|<T:~O>(~2List<+TT;>;)~2List<TT;>;|',
'M|9|unmodifiableSequencedMap|(~2SequencedMap;)~2SequencedMap;|<K:~OV:~O>(~2SequencedMap<+TK;+TV;>;)~2SequencedMap<TK;TV;>;|',
'M|9|unmodifiableSortedMap|(~2SortedMap;)~2SortedMap;|<K:~OV:~O>(~2SortedMap<TK;+TV;>;)~2SortedMap<TK;TV;>;|',
'M|9|unmodifiableNavigableMap|(~2NavigableMap;)~2NavigableMap;|<K:~OV:~O>(~2NavigableMap<TK;+TV;>;)~2NavigableMap<TK;TV;>;|',
'M|9|synchronizedSortedSet|(~2SortedSet;)~2SortedSet;|<T:~O>(~2SortedSet<TT;>;)~2SortedSet<TT;>;|',
'M|9|synchronizedNavigableSet|(~2NavigableSet;)~2NavigableSet;|<T:~O>(~2NavigableSet<TT;>;)~2NavigableSet<TT;>;|',
'M|9|synchronizedList|(~2List;)~2List;|<T:~O>(~2List<TT;>;)~2List<TT;>;|',
'M|9|synchronizedMap|(~2Map;)~2Map;|<K:~OV:~O>(~2Map<TK;TV;>;)~2Map<TK;TV;>;|',
'M|9|synchronizedSortedMap|(~2SortedMap;)~2SortedMap;|<K:~OV:~O>(~2SortedMap<TK;TV;>;)~2SortedMap<TK;TV;>;|',
'M|9|synchronizedNavigableMap|(~2NavigableMap;)~2NavigableMap;|<K:~OV:~O>(~2NavigableMap<TK;TV;>;)~2NavigableMap<TK;TV;>;|',
'M|9|checkedCollection|(~2Collection;~1Class;)~2Collection;|<E:~O>(~2Collection<TE;>;~1Class<TE;>;)~2Collection<TE;>;|',
'M|9|checkedQueue|(~2Queue;~1Class;)~2Queue;|<E:~O>(~2Queue<TE;>;~1Class<TE;>;)~2Queue<TE;>;|',
'M|9|checkedSet|(~2Set;~1Class;)~2Set;|<E:~O>(~2Set<TE;>;~1Class<TE;>;)~2Set<TE;>;|',
'M|9|checkedSortedSet|(~2SortedSet;~1Class;)~2SortedSet;|<E:~O>(~2SortedSet<TE;>;~1Class<TE;>;)~2SortedSet<TE;>;|',
'M|9|checkedNavigableSet|(~2NavigableSet;~1Class;)~2NavigableSet;|<E:~O>(~2NavigableSet<TE;>;~1Class<TE;>;)~2NavigableSet<TE;>;|',
'M|9|checkedList|(~2List;~1Class;)~2List;|<E:~O>(~2List<TE;>;~1Class<TE;>;)~2List<TE;>;|',
'M|9|checkedMap|(~2Map;~1Class;~1Class;)~2Map;|<K:~OV:~O>(~2Map<TK;TV;>;~1Class<TK;>;~1Class<TV;>;)~2Map<TK;TV;>;|',
'M|9|checkedSortedMap|(~2SortedMap;~1Class;~1Class;)~2SortedMap;|<K:~OV:~O>(~2SortedMap<TK;TV;>;~1Class<TK;>;~1Class<TV;>;)~2SortedMap<TK;TV;>;|',
'M|9|checkedNavigableMap|(~2NavigableMap;~1Class;~1Class;)~2NavigableMap;|<K:~OV:~O>(~2NavigableMap<TK;TV;>;~1Class<TK;>;~1Class<TV;>;)~2NavigableMap<TK;TV;>;|',
'M|9|emptyListIterator|()~2ListIterator;|<T:~O>()~2ListIterator<TT;>;|',
'M|25|emptySet|()~2Set;|<T:~O>()~2Set<TT;>;|',
'M|9|emptySortedSet|()~2SortedSet;|<E:~O>()~2SortedSet<TE;>;|',
'M|9|emptyNavigableSet|()~2NavigableSet;|<E:~O>()~2NavigableSet<TE;>;|',
'M|25|emptyMap|()~2Map;|<K:~OV:~O>()~2Map<TK;TV;>;|',
'M|25|emptySortedMap|()~2SortedMap;|<K:~OV:~O>()~2SortedMap<TK;TV;>;|',
'M|25|emptyNavigableMap|()~2NavigableMap;|<K:~OV:~O>()~2NavigableMap<TK;TV;>;|',
'M|9|singleton|(~O)~2Set;|<T:~O>(TT;)~2Set<TT;>;|',
'M|9|singletonList|(~O)~2List;|<T:~O>(TT;)~2List<TT;>;|',
'M|9|singletonMap|(~O~O)~2Map;|<K:~OV:~O>(TK;TV;)~2Map<TK;TV;>;|',
'M|9|frequency|(~2Collection;~O)I|(~2Collection<*>;~O)I|',
'M|9|disjoint|(~2Collection;~2Collection;)Z|(~2Collection<*>;~2Collection<*>;)Z|',
'M|9|newSequencedSetFromMap|(~2SequencedMap;)~2SequencedSet;|<E:~O>(~2SequencedMap<TE;~1Boolean;>;)~2SequencedSet<TE;>;|',
'M|9|asLifoQueue|(~2Deque;)~2Queue;|<T:~O>(~2Deque<TT;>;)~2Queue<TT;>;|',
'C|17|java/util/Arrays|~O',
'M|9|equals|([D[D)Z||',
'M|9|equals|([ZII[ZII)Z||',
'M|9|equals|([Z[Z)Z||',
'M|9|equals|([BII[BII)Z||',
'M|9|equals|([B[B)Z||',
'M|9|equals|([~OII[~OII)Z||',
'M|9|equals|([~O[~O~2Comparator;)Z|<T:~O>([TT;[TT;~2Comparator<-TT;>;)Z|',
'M|9|equals|([~OII[~OII~2Comparator;)Z|<T:~O>([TT;II[TT;II~2Comparator<-TT;>;)Z|',
'M|9|equals|([~O[~O)Z||',
'M|9|equals|([FII[FII)Z||',
'M|9|equals|([F[F)Z||',
'M|9|equals|([DII[DII)Z||',
'M|9|equals|([III[III)Z||',
'M|9|equals|([CII[CII)Z||',
'M|9|equals|([JII[JII)Z||',
'M|9|equals|([J[J)Z||',
'M|9|equals|([S[S)Z||',
'M|9|equals|([SII[SII)Z||',
'M|9|equals|([C[C)Z||',
'M|9|equals|([I[I)Z||',
'M|9|toString|([C)~S||',
'M|9|toString|([F)~S||',
'M|9|toString|([D)~S||',
'M|9|toString|([~O)~S||',
'M|9|toString|([B)~S||',
'M|9|toString|([Z)~S||',
'M|9|toString|([J)~S||',
'M|9|toString|([I)~S||',
'M|9|toString|([S)~S||',
'M|9|hashCode|([F)I||',
'M|9|hashCode|([B)I||',
'M|9|hashCode|([Z)I||',
'M|9|hashCode|([D)I||',
'M|9|hashCode|([~O)I||',
'M|9|hashCode|([J)I||',
'M|9|hashCode|([I)I||',
'M|9|hashCode|([S)I||',
'M|9|hashCode|([C)I||',
'M|9|compareUnsigned|([B[B)I||',
'M|9|compareUnsigned|([S[S)I||',
'M|9|compareUnsigned|([BII[BII)I||',
'M|9|compareUnsigned|([JII[JII)I||',
'M|9|compareUnsigned|([SII[SII)I||',
'M|9|compareUnsigned|([J[J)I||',
'M|9|compareUnsigned|([III[III)I||',
'M|9|compareUnsigned|([I[I)I||',
'M|9|copyOf|([DI)[D||',
'M|9|copyOf|([SI)[S||',
'M|9|copyOf|([BI)[B||',
'M|9|copyOf|([~OI~1Class;)[~O|<T:~OU:~O>([TU;I~1Class<+[TT;>;)[TT;|',
'M|9|copyOf|([~OI)[~O|<T:~O>([TT;I)[TT;|',
'M|9|copyOf|([ZI)[Z||',
'M|9|copyOf|([CI)[C||',
'M|9|copyOf|([JI)[J||',
'M|9|copyOf|([II)[I||',
'M|9|copyOf|([FI)[F||',
'M|9|copyOfRange|([CII)[C||',
'M|9|copyOfRange|([JII)[J||',
'M|9|copyOfRange|([III)[I||',
'M|9|copyOfRange|([SII)[S||',
'M|9|copyOfRange|([FII)[F||',
'M|9|copyOfRange|([DII)[D||',
'M|9|copyOfRange|([ZII)[Z||',
'M|9|copyOfRange|([~OII)[~O|<T:~O>([TT;II)[TT;|',
'M|9|copyOfRange|([~OII~1Class;)[~O|<T:~OU:~O>([TU;II~1Class<+[TT;>;)[TT;|',
'M|9|copyOfRange|([BII)[B||',
'M|9|compare|([BII[BII)I||',
'M|9|compare|([B[B)I||',
'M|9|compare|([DII[DII)I||',
'M|9|compare|([S[S)I||',
'M|9|compare|([SII[SII)I||',
'M|9|compare|([~1Comparable;II[~1Comparable;II)I|<T::~1Comparable<-TT;>;>([TT;II[TT;II)I|',
'M|9|compare|([~O[~O~2Comparator;)I|<T:~O>([TT;[TT;~2Comparator<-TT;>;)I|',
'M|9|compare|([~OII[~OII~2Comparator;)I|<T:~O>([TT;II[TT;II~2Comparator<-TT;>;)I|',
'M|9|compare|([~1Comparable;[~1Comparable;)I|<T::~1Comparable<-TT;>;>([TT;[TT;)I|',
'M|9|compare|([J[J)I||',
'M|9|compare|([JII[JII)I||',
'M|9|compare|([F[F)I||',
'M|9|compare|([FII[FII)I||',
'M|9|compare|([D[D)I||',
'M|9|compare|([C[C)I||',
'M|9|compare|([CII[CII)I||',
'M|9|compare|([I[I)I||',
'M|9|compare|([III[III)I||',
'M|9|compare|([ZII[ZII)I||',
'M|9|compare|([Z[Z)I||',
'M|9|mismatch|([J[J)I||',
'M|9|mismatch|([D[D)I||',
'M|9|mismatch|([FII[FII)I||',
'M|9|mismatch|([F[F)I||',
'M|9|mismatch|([JII[JII)I||',
'M|9|mismatch|([~OII[~OII~2Comparator;)I|<T:~O>([TT;II[TT;II~2Comparator<-TT;>;)I|',
'M|9|mismatch|([~O[~O~2Comparator;)I|<T:~O>([TT;[TT;~2Comparator<-TT;>;)I|',
'M|9|mismatch|([~OII[~OII)I||',
'M|9|mismatch|([~O[~O)I||',
'M|9|mismatch|([DII[DII)I||',
'M|9|mismatch|([C[C)I||',
'M|9|mismatch|([BII[BII)I||',
'M|9|mismatch|([S[S)I||',
'M|9|mismatch|([CII[CII)I||',
'M|9|mismatch|([B[B)I||',
'M|9|mismatch|([SII[SII)I||',
'M|9|mismatch|([III[III)I||',
'M|9|mismatch|([I[I)I||',
'M|9|mismatch|([Z[Z)I||',
'M|9|mismatch|([ZII[ZII)I||',
'M|9|stream|([I)~5IntStream;||',
'M|9|stream|([J)~5LongStream;||',
'M|9|stream|([III)~5IntStream;||',
'M|9|stream|([D)~5DoubleStream;||',
'M|9|stream|([JII)~5LongStream;||',
'M|9|stream|([DII)~5DoubleStream;||',
'M|9|stream|([~O)~5Stream;|<T:~O>([TT;)~5Stream<TT;>;|',
'M|9|stream|([~OII)~5Stream;|<T:~O>([TT;II)~5Stream<TT;>;|',
'M|9|fill|([SIIS)V||',
'M|9|fill|([ZZ)V||',
'M|9|fill|([ZIIZ)V||',
'M|9|fill|([SS)V||',
'M|9|fill|([DD)V||',
'M|9|fill|([CIIC)V||',
'M|9|fill|([BB)V||',
'M|9|fill|([CC)V||',
'M|9|fill|([BIIB)V||',
'M|9|fill|([~O~O)V||',
'M|9|fill|([II)V||',
'M|9|fill|([JIIJ)V||',
'M|9|fill|([JJ)V||',
'M|9|fill|([~OII~O)V||',
'M|9|fill|([DIID)V||',
'M|9|fill|([IIII)V||',
'M|9|fill|([FF)V||',
'M|9|fill|([FIIF)V||',
'M|9|spliterator|([~O)~2Spliterator;|<T:~O>([TT;)~2Spliterator<TT;>;|',
'M|9|spliterator|([J)~2Spliterator$OfLong;||',
'M|9|spliterator|([JII)~2Spliterator$OfLong;||',
'M|9|spliterator|([D)~2Spliterator$OfDouble;||',
'M|9|spliterator|([DII)~2Spliterator$OfDouble;||',
'M|9|spliterator|([I)~2Spliterator$OfInt;||',
'M|9|spliterator|([III)~2Spliterator$OfInt;||',
'M|9|spliterator|([~OII)~2Spliterator;|<T:~O>([TT;II)~2Spliterator<TT;>;|',
'M|9|sort|([III)V||',
'M|9|sort|([CII)V||',
'M|9|sort|([~O~2Comparator;)V|<T:~O>([TT;~2Comparator<-TT;>;)V|',
'M|9|sort|([~OII~2Comparator;)V|<T:~O>([TT;II~2Comparator<-TT;>;)V|',
'M|9|sort|([C)V||',
'M|9|sort|([SII)V||',
'M|9|sort|([BII)V||',
'M|9|sort|([F)V||',
'M|9|sort|([B)V||',
'M|9|sort|([FII)V||',
'M|9|sort|([D)V||',
'M|9|sort|([DII)V||',
'M|9|sort|([I)V||',
'M|9|sort|([JII)V||',
'M|9|sort|([J)V||',
'M|9|sort|([S)V||',
'M|9|sort|([~OII)V||',
'M|9|sort|([~O)V||',
'M|137|asList|([~O)~2List;|<T:~O>([TT;)~2List<TT;>;|',
'M|9|deepEquals|([~O[~O)Z||',
'M|9|deepHashCode|([~O)I||',
'M|9|deepToString|([~O)~S||',
'M|9|parallelSort|([III)V||',
'M|9|parallelSort|([J)V||',
'M|9|parallelSort|([JII)V||',
'M|9|parallelSort|([F)V||',
'M|9|parallelSort|([I)V||',
'M|9|parallelSort|([SII)V||',
'M|9|parallelSort|([S)V||',
'M|9|parallelSort|([~O~2Comparator;)V|<T:~O>([TT;~2Comparator<-TT;>;)V|',
'M|9|parallelSort|([~1Comparable;II)V|<T::~1Comparable<-TT;>;>([TT;II)V|',
'M|9|parallelSort|([~1Comparable;)V|<T::~1Comparable<-TT;>;>([TT;)V|',
'M|9|parallelSort|([DII)V||',
'M|9|parallelSort|([D)V||',
'M|9|parallelSort|([~OII~2Comparator;)V|<T:~O>([TT;II~2Comparator<-TT;>;)V|',
'M|9|parallelSort|([FII)V||',
'M|9|parallelSort|([B)V||',
'M|9|parallelSort|([BII)V||',
'M|9|parallelSort|([CII)V||',
'M|9|parallelSort|([C)V||',
'M|9|parallelPrefix|([DII~3DoubleBinaryOperator;)V||',
'M|9|parallelPrefix|([I~3IntBinaryOperator;)V||',
'M|9|parallelPrefix|([JII~3LongBinaryOperator;)V||',
'M|9|parallelPrefix|([III~3IntBinaryOperator;)V||',
'M|9|parallelPrefix|([D~3DoubleBinaryOperator;)V||',
'M|9|parallelPrefix|([~OII~3BinaryOperator;)V|<T:~O>([TT;II~3BinaryOperator<TT;>;)V|',
'M|9|parallelPrefix|([~O~3BinaryOperator;)V|<T:~O>([TT;~3BinaryOperator<TT;>;)V|',
'M|9|parallelPrefix|([J~3LongBinaryOperator;)V||',
'M|9|binarySearch|([FIIF)I||',
'M|9|binarySearch|([FF)I||',
'M|9|binarySearch|([SS)I||',
'M|9|binarySearch|([SIIS)I||',
'M|9|binarySearch|([~O~O)I||',
'M|9|binarySearch|([~OII~O)I||',
'M|9|binarySearch|([~O~O~2Comparator;)I|<T:~O>([TT;TT;~2Comparator<-TT;>;)I|',
'M|9|binarySearch|([DD)I||',
'M|9|binarySearch|([BIIB)I||',
'M|9|binarySearch|([DIID)I||',
'M|9|binarySearch|([BB)I||',
'M|9|binarySearch|([CIIC)I||',
'M|9|binarySearch|([CC)I||',
'M|9|binarySearch|([IIII)I||',
'M|9|binarySearch|([JJ)I||',
'M|9|binarySearch|([JIIJ)I||',
'M|9|binarySearch|([II)I||',
'M|9|binarySearch|([~OII~O~2Comparator;)I|<T:~O>([TT;IITT;~2Comparator<-TT;>;)I|',
'M|9|setAll|([D~3IntToDoubleFunction;)V||',
'M|9|setAll|([I~3IntUnaryOperator;)V||',
'M|9|setAll|([J~3IntToLongFunction;)V||',
'M|9|setAll|([~O~3IntFunction;)V|<T:~O>([TT;~3IntFunction<+TT;>;)V|',
'M|9|parallelSetAll|([D~3IntToDoubleFunction;)V||',
'M|9|parallelSetAll|([J~3IntToLongFunction;)V||',
'M|9|parallelSetAll|([~O~3IntFunction;)V|<T:~O>([TT;~3IntFunction<+TT;>;)V|',
'M|9|parallelSetAll|([I~3IntUnaryOperator;)V||',
'C|17|java/util/Objects|~O',
'M|9|equals|(~O~O)Z||',
'M|9|toString|(~O)~S||',
'M|9|toString|(~O~S)~S||',
'M|9|checkIndex|(II)I||',
'M|9|checkIndex|(JJ)J||',
'M|9|hashCode|(~O)I||',
'M|9|compare|(~O~O~2Comparator;)I|<T:~O>(TT;TT;~2Comparator<-TT;>;)I|',
'M|137|hash|([~O)I||',
'M|9|requireNonNull|(~O~3Supplier;)~O|<T:~O>(TT;~3Supplier<~S>;)TT;|',
'M|9|requireNonNull|(~O~S)~O|<T:~O>(TT;~S)TT;|',
'M|9|requireNonNull|(~O)~O|<T:~O>(TT;)TT;|',
'M|9|checkFromToIndex|(JJJ)J||',
'M|9|checkFromToIndex|(III)I||',
'M|9|checkFromIndexSize|(III)I||',
'M|9|checkFromIndexSize|(JJJ)J||',
'M|9|deepEquals|(~O~O)Z||',
'M|9|toIdentityString|(~O)~S||',
'M|9|isNull|(~O)Z||',
'M|9|nonNull|(~O)Z||',
'M|9|requireNonNullElse|(~O~O)~O|<T:~O>(TT;TT;)TT;|',
'M|9|requireNonNullElseGet|(~O~3Supplier;)~O|<T:~O>(TT;~3Supplier<+TT;>;)TT;|',
'C|17|java/util/Optional|<T:~O>~O',
'M|1|get|()~O|()TT;|',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|isEmpty|()Z||',
'M|1|map|(~3Function;)~2Optional;|<U:~O>(~3Function<-TT;+TU;>;)~2Optional<TU;>;|',
'M|1|stream|()~5Stream;|()~5Stream<TT;>;|',
'M|9|of|(~O)~2Optional;|<T:~O>(TT;)~2Optional<TT;>;|',
'M|1|filter|(~3Predicate;)~2Optional;|(~3Predicate<-TT;>;)~2Optional<TT;>;|',
'M|9|empty|()~2Optional;|<T:~O>()~2Optional<TT;>;|',
'M|1|flatMap|(~3Function;)~2Optional;|<U:~O>(~3Function<-TT;+~2Optional<+TU;>;>;)~2Optional<TU;>;|',
'M|1|isPresent|()Z||',
'M|1|orElse|(~O)~O|(TT;)TT;|',
'M|1|orElseThrow|(~3Supplier;)~O|<X:~1Throwable;>(~3Supplier<+TX;>;)TT;|java/lang/Throwable',
'M|1|orElseThrow|()~O|()TT;|',
'M|9|ofNullable|(~O)~2Optional;|<T:~O>(TT;)~2Optional<TT;>;|',
'M|1|ifPresent|(~3Consumer;)V|(~3Consumer<-TT;>;)V|',
'M|1|ifPresentOrElse|(~3Consumer;~1Runnable;)V|(~3Consumer<-TT;>;~1Runnable;)V|',
'M|1|or|(~3Supplier;)~2Optional;|(~3Supplier<+~2Optional<+TT;>;>;)~2Optional<TT;>;|',
'M|1|orElseGet|(~3Supplier;)~O|(~3Supplier<+TT;>;)TT;|',
'C|17|java/util/OptionalInt|~O',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|isEmpty|()Z||',
'M|1|stream|()~5IntStream;||',
'M|9|of|(I)~2OptionalInt;||',
'M|9|empty|()~2OptionalInt;||',
'M|1|isPresent|()Z||',
'M|1|orElse|(I)I||',
'M|1|orElseThrow|(~3Supplier;)I|<X:~1Throwable;>(~3Supplier<+TX;>;)I|java/lang/Throwable',
'M|1|orElseThrow|()I||',
'M|1|ifPresent|(~3IntConsumer;)V||',
'M|1|ifPresentOrElse|(~3IntConsumer;~1Runnable;)V||',
'M|1|orElseGet|(~3IntSupplier;)I||',
'M|1|getAsInt|()I||',
'C|17|java/util/OptionalDouble|~O',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|isEmpty|()Z||',
'M|1|stream|()~5DoubleStream;||',
'M|9|of|(D)~2OptionalDouble;||',
'M|9|empty|()~2OptionalDouble;||',
'M|1|isPresent|()Z||',
'M|1|orElse|(D)D||',
'M|1|orElseThrow|(~3Supplier;)D|<X:~1Throwable;>(~3Supplier<+TX;>;)D|java/lang/Throwable',
'M|1|orElseThrow|()D||',
'M|1|ifPresent|(~3DoubleConsumer;)V||',
'M|1|ifPresentOrElse|(~3DoubleConsumer;~1Runnable;)V||',
'M|1|orElseGet|(~3DoubleSupplier;)D||',
'M|1|getAsDouble|()D||',
'C|17|java/util/OptionalLong|~O',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|isEmpty|()Z||',
'M|1|stream|()~5LongStream;||',
'M|9|of|(J)~2OptionalLong;||',
'M|9|empty|()~2OptionalLong;||',
'M|1|isPresent|()Z||',
'M|1|orElse|(J)J||',
'M|1|orElseThrow|(~3Supplier;)J|<X:~1Throwable;>(~3Supplier<+TX;>;)J|java/lang/Throwable',
'M|1|orElseThrow|()J||',
'M|1|ifPresent|(~3LongConsumer;)V||',
'M|1|ifPresentOrElse|(~3LongConsumer;~1Runnable;)V||',
'M|1|orElseGet|(~3LongSupplier;)J||',
'M|1|getAsLong|()J||',
'C|17|java/util/Scanner|~O~2Iterator<~S>;~4Closeable;',
'M|1|<init>|(~4InputStream;~S)V||',
'M|1|<init>|(~4InputStream;)V||',
'M|1|<init>|(~1Readable;)V||',
'M|1|<init>|(~4File;)V||java/io/FileNotFoundException',
'M|1|<init>|(~4File;Ljava/nio/charset/Charset;)V||java/io/IOException',
'M|1|<init>|(~4InputStream;Ljava/nio/charset/Charset;)V||',
'M|1|<init>|(Ljava/nio/channels/ReadableByteChannel;)V||',
'M|1|<init>|(Ljava/nio/channels/ReadableByteChannel;~S)V||',
'M|1|<init>|(Ljava/nio/channels/ReadableByteChannel;Ljava/nio/charset/Charset;)V||',
'M|1|<init>|(~4File;~S)V||java/io/FileNotFoundException',
'M|1|<init>|(Ljava/nio/file/Path;)V||java/io/IOException',
'M|1|<init>|(Ljava/nio/file/Path;~S)V||java/io/IOException',
'M|1|<init>|(Ljava/nio/file/Path;Ljava/nio/charset/Charset;)V||java/io/IOException',
'M|1|<init>|(~S)V||',
'M|1|remove|()V||',
'M|1|reset|()~2Scanner;||',
'M|1|toString|()~S||',
'M|1|hasNext|(~2regex/Pattern;)Z||',
'M|1|hasNext|()Z||',
'M|1|hasNext|(~S)Z||',
'M|1|next|(~2regex/Pattern;)~S||',
'M|1|next|(~S)~S||',
'M|1|next|()~S||',
'M|1|delimiter|()~2regex/Pattern;||',
'M|1|locale|()~2Locale;||',
'M|1|match|()~2regex/MatchResult;||',
'M|1|close|()V||',
'M|1|skip|(~2regex/Pattern;)~2Scanner;||',
'M|1|skip|(~S)~2Scanner;||',
'M|1|radix|()I||',
'M|1|nextDouble|()D||',
'M|1|nextInt|(I)I||',
'M|1|nextInt|()I||',
'M|1|findAll|(~S)~5Stream;|(~S)~5Stream<~2regex/MatchResult;>;|',
'M|1|findAll|(~2regex/Pattern;)~5Stream;|(~2regex/Pattern;)~5Stream<~2regex/MatchResult;>;|',
'M|1|ioException|()~4IOException;||',
'M|1|nextLong|(I)J||',
'M|1|nextLong|()J||',
'M|1|nextBoolean|()Z||',
'M|1|nextFloat|()F||',
'M|1|nextLine|()~S||',
'M|1|tokens|()~5Stream;|()~5Stream<~S>;|',
'M|1|useLocale|(~2Locale;)~2Scanner;||',
'M|1|findWithinHorizon|(~2regex/Pattern;I)~S||',
'M|1|findWithinHorizon|(~SI)~S||',
'M|1|findInLine|(~S)~S||',
'M|1|findInLine|(~2regex/Pattern;)~S||',
'M|1|hasNextByte|(I)Z||',
'M|1|hasNextByte|()Z||',
'M|1|nextByte|()B||',
'M|1|nextByte|(I)B||',
'M|1|hasNextShort|(I)Z||',
'M|1|hasNextShort|()Z||',
'M|1|nextShort|()S||',
'M|1|nextShort|(I)S||',
'M|1|hasNextInt|(I)Z||',
'M|1|hasNextInt|()Z||',
'M|1|hasNextLong|(I)Z||',
'M|1|hasNextLong|()Z||',
'M|1|hasNextBigInteger|(I)Z||',
'M|1|hasNextBigInteger|()Z||',
'M|1|nextBigInteger|(I)Ljava/math/BigInteger;||',
'M|1|nextBigInteger|()Ljava/math/BigInteger;||',
'M|1|useRadix|(I)~2Scanner;||',
'M|1|useDelimiter|(~S)~2Scanner;||',
'M|1|useDelimiter|(~2regex/Pattern;)~2Scanner;||',
'M|1|hasNextLine|()Z||',
'M|1|hasNextBoolean|()Z||',
'M|1|hasNextFloat|()Z||',
'M|1|hasNextDouble|()Z||',
'M|1|hasNextBigDecimal|()Z||',
'M|1|nextBigDecimal|()Ljava/math/BigDecimal;||',
'C|1|java/util/Random|~O~2random/RandomGenerator;~4Serializable;',
'M|1|<init>|(J)V||',
'M|1|<init>|()V||',
'M|4|next|(I)I||',
'M|9|from|(~2random/RandomGenerator;)~2Random;||',
'M|1|nextDouble|()D||',
'M|1|nextInt|()I||',
'M|1|nextInt|(I)I||',
'M|1|nextBytes|([B)V||',
'M|33|setSeed|(J)V||',
'M|1|ints|(J)~5IntStream;||',
'M|1|ints|()~5IntStream;||',
'M|1|ints|(JII)~5IntStream;||',
'M|1|ints|(II)~5IntStream;||',
'M|1|longs|(J)~5LongStream;||',
'M|1|longs|(JJ)~5LongStream;||',
'M|1|longs|(JJJ)~5LongStream;||',
'M|1|longs|()~5LongStream;||',
'M|1|doubles|(J)~5DoubleStream;||',
'M|1|doubles|(JDD)~5DoubleStream;||',
'M|1|doubles|(DD)~5DoubleStream;||',
'M|1|doubles|()~5DoubleStream;||',
'M|1|nextLong|()J||',
'M|1|nextBoolean|()Z||',
'M|1|nextFloat|()F||',
'M|33|nextGaussian|()D||',
'C|1|java/util/Stack|<E:~O>~2Vector<TE;>;',
'M|1|<init>|()V||',
'M|1|empty|()Z||',
'M|33|peek|()~O|()TE;|',
'M|33|search|(~O)I||',
'M|1|push|(~O)~O|(TE;)TE;|',
'M|33|pop|()~O|()TE;|',
'C|1|java/util/Vector|<E:~O>~2AbstractList<TE;>;~2List<TE;>;~2RandomAccess;~1Cloneable;~4Serializable;',
'F|4|elementData|[~O||',
'F|4|elementCount|I||',
'F|4|capacityIncrement|I||',
'M|1|<init>|(~2Collection;)V|(~2Collection<+TE;>;)V|',
'M|1|<init>|()V||',
'M|1|<init>|(I)V||',
'M|1|<init>|(II)V||',
'M|33|remove|(I)~O|(I)TE;|',
'M|1|remove|(~O)Z||',
'M|33|size|()I||',
'M|33|get|(I)~O|(I)TE;|',
'M|33|equals|(~O)Z||',
'M|33|toString|()~S||',
'M|33|hashCode|()I||',
'M|33|clone|()~O||',
'M|33|indexOf|(~OI)I||',
'M|1|indexOf|(~O)I||',
'M|1|clear|()V||',
'M|33|lastIndexOf|(~OI)I||',
'M|33|lastIndexOf|(~O)I||',
'M|33|isEmpty|()Z||',
'M|33|replaceAll|(~3UnaryOperator;)V|(~3UnaryOperator<TE;>;)V|',
'M|33|add|(~O)Z|(TE;)Z|',
'M|1|add|(I~O)V|(ITE;)V|',
'M|33|subList|(II)~2List;|(II)~2List<TE;>;|',
'M|33|toArray|()[~O||',
'M|33|toArray|([~O)[~O|<T:~O>([TT;)[TT;|',
'M|33|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1|contains|(~O)Z||',
'M|1|elements|()~2Enumeration;|()~2Enumeration<TE;>;|',
'M|1|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|1|addAll|(~2Collection;)Z|(~2Collection<+TE;>;)Z|',
'M|33|addAll|(I~2Collection;)Z|(I~2Collection<+TE;>;)Z|',
'M|33|set|(I~O)~O|(ITE;)TE;|',
'M|33|forEach|(~3Consumer;)V|(~3Consumer<-TE;>;)V|',
'M|33|sort|(~2Comparator;)V|(~2Comparator<-TE;>;)V|',
'M|33|capacity|()I||',
'M|33|ensureCapacity|(I)V||',
'M|33|trimToSize|()V||',
'M|33|elementAt|(I)~O|(I)TE;|',
'M|1|removeIf|(~3Predicate;)Z|(~3Predicate<-TE;>;)Z|',
'M|36|removeRange|(II)V||',
'M|1|removeAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|retainAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|33|listIterator|()~2ListIterator;|()~2ListIterator<TE;>;|',
'M|33|listIterator|(I)~2ListIterator;|(I)~2ListIterator<TE;>;|',
'M|33|containsAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|33|setSize|(I)V||',
'M|33|copyInto|([~O)V||',
'M|33|addElement|(~O)V|(TE;)V|',
'M|33|removeElementAt|(I)V||',
'M|33|removeElement|(~O)Z||',
'M|33|insertElementAt|(~OI)V|(TE;I)V|',
'M|33|removeAllElements|()V||',
'M|33|firstElement|()~O|()TE;|',
'M|33|lastElement|()~O|()TE;|',
'M|33|setElementAt|(~OI)V|(TE;I)V|',
'C|1537|java/util/Queue|<E:~O>~O~2Collection<TE;>;',
'M|1025|remove|()~O|()TE;|',
'M|1025|add|(~O)Z|(TE;)Z|',
'M|1025|peek|()~O|()TE;|',
'M|1025|element|()~O|()TE;|',
'M|1025|poll|()~O|()TE;|',
'M|1025|offer|(~O)Z|(TE;)Z|',
'C|1537|java/util/Deque|<E:~O>~O~2Queue<TE;>;~2SequencedCollection<TE;>;',
'M|1025|remove|(~O)Z||',
'M|1025|remove|()~O|()TE;|',
'M|1025|size|()I||',
'M|1025|add|(~O)Z|(TE;)Z|',
'M|1025|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1025|contains|(~O)Z||',
'M|1025|addAll|(~2Collection;)Z|(~2Collection<+TE;>;)Z|',
'M|1025|peek|()~O|()TE;|',
'M|1025|getFirst|()~O|()TE;|',
'M|1025|getLast|()~O|()TE;|',
'M|1025|element|()~O|()TE;|',
'M|1025|addFirst|(~O)V|(TE;)V|',
'M|1025|addLast|(~O)V|(TE;)V|',
'M|1025|removeFirst|()~O|()TE;|',
'M|1025|removeLast|()~O|()TE;|',
'M|65537|reversed|()~2Deque;|()~2Deque<TE;>;|',
'M|1025|poll|()~O|()TE;|',
'M|1025|push|(~O)V|(TE;)V|',
'M|1025|pop|()~O|()TE;|',
'M|1025|pollFirst|()~O|()TE;|',
'M|1025|pollLast|()~O|()TE;|',
'M|1025|offerLast|(~O)Z|(TE;)Z|',
'M|1025|peekFirst|()~O|()TE;|',
'M|1025|removeFirstOccurrence|(~O)Z||',
'M|1025|offerFirst|(~O)Z|(TE;)Z|',
'M|1025|peekLast|()~O|()TE;|',
'M|1025|removeLastOccurrence|(~O)Z||',
'M|1025|offer|(~O)Z|(TE;)Z|',
'M|1025|descendingIterator|()~2Iterator;|()~2Iterator<TE;>;|',
'C|1|java/util/ArrayDeque|<E:~O>~2AbstractCollection<TE;>;~2Deque<TE;>;~1Cloneable;~4Serializable;',
'M|1|<init>|(I)V||',
'M|1|<init>|()V||',
'M|1|<init>|(~2Collection;)V|(~2Collection<+TE;>;)V|',
'M|1|remove|()~O|()TE;|',
'M|1|remove|(~O)Z||',
'M|1|size|()I||',
'M|1|clone|()~2ArrayDeque;|()~2ArrayDeque<TE;>;|',
'M|1|clear|()V||',
'M|1|isEmpty|()Z||',
'M|1|add|(~O)Z|(TE;)Z|',
'M|1|toArray|([~O)[~O|<T:~O>([TT;)[TT;|',
'M|1|toArray|()[~O||',
'M|1|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1|contains|(~O)Z||',
'M|1|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|1|addAll|(~2Collection;)Z|(~2Collection<+TE;>;)Z|',
'M|1|forEach|(~3Consumer;)V|(~3Consumer<-TE;>;)V|',
'M|1|peek|()~O|()TE;|',
'M|1|removeIf|(~3Predicate;)Z|(~3Predicate<-TE;>;)Z|',
'M|1|getFirst|()~O|()TE;|',
'M|1|getLast|()~O|()TE;|',
'M|1|element|()~O|()TE;|',
'M|1|addFirst|(~O)V|(TE;)V|',
'M|1|addLast|(~O)V|(TE;)V|',
'M|1|removeFirst|()~O|()TE;|',
'M|1|removeLast|()~O|()TE;|',
'M|1|removeAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|retainAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|poll|()~O|()TE;|',
'M|1|push|(~O)V|(TE;)V|',
'M|1|pop|()~O|()TE;|',
'M|1|pollFirst|()~O|()TE;|',
'M|1|pollLast|()~O|()TE;|',
'M|1|offerLast|(~O)Z|(TE;)Z|',
'M|1|peekFirst|()~O|()TE;|',
'M|1|removeFirstOccurrence|(~O)Z||',
'M|1|offerFirst|(~O)Z|(TE;)Z|',
'M|1|peekLast|()~O|()TE;|',
'M|1|removeLastOccurrence|(~O)Z||',
'M|1|offer|(~O)Z|(TE;)Z|',
'M|1|descendingIterator|()~2Iterator;|()~2Iterator<TE;>;|',
'C|1|java/util/PriorityQueue|<E:~O>~2AbstractQueue<TE;>;~4Serializable;',
'M|1|<init>|(I~2Comparator;)V|(I~2Comparator<-TE;>;)V|',
'M|1|<init>|(~2Collection;)V|(~2Collection<+TE;>;)V|',
'M|1|<init>|(~2PriorityQueue;)V|(~2PriorityQueue<+TE;>;)V|',
'M|1|<init>|(~2SortedSet;)V|(~2SortedSet<+TE;>;)V|',
'M|1|<init>|()V||',
'M|1|<init>|(I)V||',
'M|1|<init>|(~2Comparator;)V|(~2Comparator<-TE;>;)V|',
'M|1|remove|(~O)Z||',
'M|1|size|()I||',
'M|1|clear|()V||',
'M|1|add|(~O)Z|(TE;)Z|',
'M|1|toArray|()[~O||',
'M|1|toArray|([~O)[~O|<T:~O>([TT;)[TT;|',
'M|1|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1|contains|(~O)Z||',
'M|17|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|1|forEach|(~3Consumer;)V|(~3Consumer<-TE;>;)V|',
'M|1|peek|()~O|()TE;|',
'M|1|removeIf|(~3Predicate;)Z|(~3Predicate<-TE;>;)Z|',
'M|1|removeAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|retainAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|comparator|()~2Comparator;|()~2Comparator<-TE;>;|',
'M|1|poll|()~O|()TE;|',
'M|1|offer|(~O)Z|(TE;)Z|',
'C|1537|java/util/Comparator|<T:~O>~O',
'M|1025|equals|(~O)Z||',
'M|1025|compare|(~O~O)I|(TT;TT;)I|',
'M|65537|reversed|()~2Comparator;|()~2Comparator<TT;>;|',
'M|9|reverseOrder|()~2Comparator;|<T::~1Comparable<-TT;>;>()~2Comparator<TT;>;|',
'M|9|comparing|(~3Function;)~2Comparator;|<T:~OU::~1Comparable<-TU;>;>(~3Function<-TT;+TU;>;)~2Comparator<TT;>;|',
'M|9|comparing|(~3Function;~2Comparator;)~2Comparator;|<T:~OU:~O>(~3Function<-TT;+TU;>;~2Comparator<-TU;>;)~2Comparator<TT;>;|',
'M|65537|thenComparing|(~3Function;~2Comparator;)~2Comparator;|<U:~O>(~3Function<-TT;+TU;>;~2Comparator<-TU;>;)~2Comparator<TT;>;|',
'M|65537|thenComparing|(~2Comparator;)~2Comparator;|(~2Comparator<-TT;>;)~2Comparator<TT;>;|',
'M|65537|thenComparing|(~3Function;)~2Comparator;|<U::~1Comparable<-TU;>;>(~3Function<-TT;+TU;>;)~2Comparator<TT;>;|',
'M|9|comparingInt|(~3ToIntFunction;)~2Comparator;|<T:~O>(~3ToIntFunction<-TT;>;)~2Comparator<TT;>;|',
'M|9|comparingLong|(~3ToLongFunction;)~2Comparator;|<T:~O>(~3ToLongFunction<-TT;>;)~2Comparator<TT;>;|',
'M|9|comparingDouble|(~3ToDoubleFunction;)~2Comparator;|<T:~O>(~3ToDoubleFunction<-TT;>;)~2Comparator<TT;>;|',
'M|65537|thenComparingInt|(~3ToIntFunction;)~2Comparator;|(~3ToIntFunction<-TT;>;)~2Comparator<TT;>;|',
'M|65537|thenComparingLong|(~3ToLongFunction;)~2Comparator;|(~3ToLongFunction<-TT;>;)~2Comparator<TT;>;|',
'M|65537|thenComparingDouble|(~3ToDoubleFunction;)~2Comparator;|(~3ToDoubleFunction<-TT;>;)~2Comparator<TT;>;|',
'M|9|naturalOrder|()~2Comparator;|<T::~1Comparable<-TT;>;>()~2Comparator<TT;>;|',
'M|9|nullsFirst|(~2Comparator;)~2Comparator;|<T:~O>(~2Comparator<-TT;>;)~2Comparator<TT;>;|',
'M|9|nullsLast|(~2Comparator;)~2Comparator;|<T:~O>(~2Comparator<-TT;>;)~2Comparator<TT;>;|',
'C|17|java/util/StringJoiner|~O',
'M|1|<init>|(~1CharSequence;)V||',
'M|1|<init>|(~1CharSequence;~1CharSequence;~1CharSequence;)V||',
'M|1|length|()I||',
'M|1|toString|()~S||',
'M|1|add|(~1CharSequence;)~2StringJoiner;||',
'M|1|merge|(~2StringJoiner;)~2StringJoiner;||',
'M|1|setEmptyValue|(~1CharSequence;)~2StringJoiner;||',
'C|1|java/util/StringTokenizer|~O~2Enumeration<~O>;',
'M|1|<init>|(~S~S)V||',
'M|1|<init>|(~S~SZ)V||',
'M|1|<init>|(~S)V||',
'M|1|countTokens|()I||',
'M|1|hasMoreElements|()Z||',
'M|1|nextToken|(~S)~S||',
'M|1|nextToken|()~S||',
'M|1|nextElement|()~O||',
'M|1|hasMoreTokens|()Z||',
'C|1|java/util/BitSet|~O~1Cloneable;~4Serializable;',
'M|1|<init>|(I)V||',
'M|1|<init>|()V||',
'M|1|size|()I||',
'M|1|get|(I)Z||',
'M|1|get|(II)~2BitSet;||',
'M|1|equals|(~O)Z||',
'M|1|length|()I||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|clone|()~O||',
'M|9|valueOf|([J)~2BitSet;||',
'M|9|valueOf|([B)~2BitSet;||',
'M|9|valueOf|(Ljava/nio/LongBuffer;)~2BitSet;||',
'M|9|valueOf|(Ljava/nio/ByteBuffer;)~2BitSet;||',
'M|1|clear|(II)V||',
'M|1|clear|()V||',
'M|1|clear|(I)V||',
'M|1|isEmpty|()Z||',
'M|1|stream|()~5IntStream;||',
'M|1|set|(IZ)V||',
'M|1|set|(I)V||',
'M|1|set|(II)V||',
'M|1|set|(IIZ)V||',
'M|1|flip|(II)V||',
'M|1|flip|(I)V||',
'M|1|nextClearBit|(I)I||',
'M|1|or|(~2BitSet;)V||',
'M|1|toByteArray|()[B||',
'M|1|and|(~2BitSet;)V||',
'M|1|xor|(~2BitSet;)V||',
'M|1|andNot|(~2BitSet;)V||',
'M|1|cardinality|()I||',
'M|1|nextSetBit|(I)I||',
'M|1|toLongArray|()[J||',
'M|1|previousSetBit|(I)I||',
'M|1|previousClearBit|(I)I||',
'M|1|intersects|(~2BitSet;)Z||',
'C|17|java/util/UUID|~O~4Serializable;~1Comparable<~2UUID;>;',
'M|1|<init>|(JJ)V||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|version|()I||',
'M|1|hashCode|()I||',
'M|1|compareTo|(~2UUID;)I||',
'M|1|timestamp|()J||',
'M|1|node|()J||',
'M|1|variant|()I||',
'M|9|randomUUID|()~2UUID;||',
'M|9|nameUUIDFromBytes|([B)~2UUID;||',
'M|9|fromString|(~S)~2UUID;||',
'M|1|getLeastSignificantBits|()J||',
'M|1|getMostSignificantBits|()J||',
'M|1|clockSequence|()I||',
'C|1|java/util/Date|~O~4Serializable;~1Cloneable;~1Comparable<~2Date;>;',
'M|1|<init>|(~S)V||',
'M|1|<init>|(IIIIII)V||',
'M|1|<init>|(IIIII)V||',
'M|1|<init>|()V||',
'M|1|<init>|(J)V||',
'M|1|<init>|(III)V||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|clone|()~O||',
'M|1|compareTo|(~2Date;)I||',
'M|9|from|(Ljava/time/Instant;)~2Date;||',
'M|9|UTC|(IIIIII)J||',
'M|9|parse|(~S)J||',
'M|1|before|(~2Date;)Z||',
'M|1|after|(~2Date;)Z||',
'M|1|getTime|()J||',
'M|1|toInstant|()Ljava/time/Instant;||',
'M|1|getYear|()I||',
'M|1|setTime|(J)V||',
'M|1|getSeconds|()I||',
'M|1|getMonth|()I||',
'M|1|setDate|(I)V||',
'M|1|setMonth|(I)V||',
'M|1|getHours|()I||',
'M|1|setHours|(I)V||',
'M|1|getMinutes|()I||',
'M|1|setMinutes|(I)V||',
'M|1|setSeconds|(I)V||',
'M|1|setYear|(I)V||',
'M|1|getDate|()I||',
'M|1|getDay|()I||',
'M|1|toLocaleString|()~S||',
'M|1|toGMTString|()~S||',
'M|1|getTimezoneOffset|()I||',
'C|1025|java/util/Calendar|~O~4Serializable;~1Cloneable;~1Comparable<~2Calendar;>;',
'F|25|ERA|I||I0',
'F|25|YEAR|I||I1',
'F|25|MONTH|I||I2',
'F|25|WEEK_OF_YEAR|I||I3',
'F|25|WEEK_OF_MONTH|I||I4',
'F|25|DATE|I||I5',
'F|25|DAY_OF_MONTH|I||I5',
'F|25|DAY_OF_YEAR|I||I6',
'F|25|DAY_OF_WEEK|I||I7',
'F|25|DAY_OF_WEEK_IN_MONTH|I||I8',
'F|25|AM_PM|I||I9',
'F|25|HOUR|I||I10',
'F|25|HOUR_OF_DAY|I||I11',
'F|25|MINUTE|I||I12',
'F|25|SECOND|I||I13',
'F|25|MILLISECOND|I||I14',
'F|25|ZONE_OFFSET|I||I15',
'F|25|DST_OFFSET|I||I16',
'F|25|FIELD_COUNT|I||I17',
'F|25|SUNDAY|I||I1',
'F|25|MONDAY|I||I2',
'F|25|TUESDAY|I||I3',
'F|25|WEDNESDAY|I||I4',
'F|25|THURSDAY|I||I5',
'F|25|FRIDAY|I||I6',
'F|25|SATURDAY|I||I7',
'F|25|JANUARY|I||I0',
'F|25|FEBRUARY|I||I1',
'F|25|MARCH|I||I2',
'F|25|APRIL|I||I3',
'F|25|MAY|I||I4',
'F|25|JUNE|I||I5',
'F|25|JULY|I||I6',
'F|25|AUGUST|I||I7',
'F|25|SEPTEMBER|I||I8',
'F|25|OCTOBER|I||I9',
'F|25|NOVEMBER|I||I10',
'F|25|DECEMBER|I||I11',
'F|25|UNDECIMBER|I||I12',
'F|25|AM|I||I0',
'F|25|PM|I||I1',
'F|25|ALL_STYLES|I||I0',
'F|25|SHORT|I||I1',
'F|25|LONG|I||I2',
'F|25|NARROW_FORMAT|I||I4',
'F|25|NARROW_STANDALONE|I||I32772',
'F|25|SHORT_FORMAT|I||I1',
'F|25|LONG_FORMAT|I||I2',
'F|25|SHORT_STANDALONE|I||I32769',
'F|25|LONG_STANDALONE|I||I32770',
'F|4|fields|[I||',
'F|4|isSet|[Z||',
'F|4|time|J||',
'F|4|isTimeSet|Z||',
'F|4|areFieldsSet|Z||',
'M|4|<init>|()V||',
'M|4|<init>|(~2TimeZone;~2Locale;)V||',
'M|1|get|(I)I||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|clone|()~O||',
'M|1|compareTo|(~2Calendar;)I||',
'M|17|clear|(I)V||',
'M|17|clear|()V||',
'M|1025|add|(II)V||',
'M|9|getInstance|()~2Calendar;||',
'M|9|getInstance|(~2TimeZone;~2Locale;)~2Calendar;||',
'M|9|getInstance|(~2TimeZone;)~2Calendar;||',
'M|9|getInstance|(~2Locale;)~2Calendar;||',
'M|17|set|(IIIIII)V||',
'M|17|set|(IIIII)V||',
'M|17|set|(III)V||',
'M|1|set|(II)V||',
'M|17|isSet|(I)Z||',
'M|1|getTimeZone|()~2TimeZone;||',
'M|1|setTimeZone|(~2TimeZone;)V||',
'M|1|before|(~O)Z||',
'M|1|after|(~O)Z||',
'M|17|getTime|()~2Date;||',
'M|1|getDisplayName|(II~2Locale;)~S||',
'M|17|toInstant|()Ljava/time/Instant;||',
'M|41|getAvailableLocales|()[~2Locale;||',
'M|1|setLenient|(Z)V||',
'M|1|isLenient|()Z||',
'M|1|getFirstDayOfWeek|()I||',
'M|1|getMinimalDaysInFirstWeek|()I||',
'M|1|setTimeInMillis|(J)V||',
'M|17|setTime|(~2Date;)V||',
'M|1|isWeekDateSupported|()Z||',
'M|1|getWeekYear|()I||',
'M|1025|getMaximum|(I)I||',
'M|1025|getLeastMaximum|(I)I||',
'M|1|getDisplayNames|(II~2Locale;)~2Map;|(II~2Locale;)~2Map<~S~1Integer;>;|',
'M|1|getCalendarType|()~S||',
'M|1025|getMinimum|(I)I||',
'M|1|getTimeInMillis|()J||',
'M|1028|computeFields|()V||',
'M|4|complete|()V||',
'M|20|internalGet|(I)I||',
'M|1|roll|(II)V||',
'M|1025|roll|(IZ)V||',
'M|1025|getGreatestMinimum|(I)I||',
'M|1028|computeTime|()V||',
'M|9|getAvailableCalendarTypes|()~2Set;|()~2Set<~S>;|',
'M|1|setFirstDayOfWeek|(I)V||',
'M|1|setMinimalDaysInFirstWeek|(I)V||',
'M|1|setWeekDate|(III)V||',
'M|1|getWeeksInWeekYear|()I||',
'M|1|getActualMinimum|(I)I||',
'M|1|getActualMaximum|(I)I||',
'C|1|java/util/GregorianCalendar|~2Calendar;',
'F|25|BC|I||I0',
'F|25|AD|I||I1',
'M|1|<init>|(III)V||',
'M|1|<init>|(IIIII)V||',
'M|1|<init>|(IIIIII)V||',
'M|1|<init>|()V||',
'M|1|<init>|(~2TimeZone;)V||',
'M|1|<init>|(~2Locale;)V||',
'M|1|<init>|(~2TimeZone;~2Locale;)V||',
'M|1|equals|(~O)Z||',
'M|1|hashCode|()I||',
'M|1|clone|()~O||',
'M|1|add|(II)V||',
'M|9|from|(Ljava/time/ZonedDateTime;)~2GregorianCalendar;||',
'M|1|getTimeZone|()~2TimeZone;||',
'M|1|setTimeZone|(~2TimeZone;)V||',
'M|17|isWeekDateSupported|()Z||',
'M|1|getWeekYear|()I||',
'M|1|getMaximum|(I)I||',
'M|1|getLeastMaximum|(I)I||',
'M|1|isLeapYear|(I)Z||',
'M|1|getCalendarType|()~S||',
'M|1|getMinimum|(I)I||',
'M|4|computeFields|()V||',
'M|1|roll|(IZ)V||',
'M|1|roll|(II)V||',
'M|1|getGreatestMinimum|(I)I||',
'M|4|computeTime|()V||',
'M|1|setWeekDate|(III)V||',
'M|1|getWeeksInWeekYear|()I||',
'M|1|getActualMinimum|(I)I||',
'M|1|getActualMaximum|(I)I||',
'M|1|setGregorianChange|(~2Date;)V||',
'M|17|getGregorianChange|()~2Date;||',
'M|1|toZonedDateTime|()Ljava/time/ZonedDateTime;||',
'C|17|java/util/Locale|~O~1Cloneable;~4Serializable;',
'F|25|ENGLISH|~2Locale;||',
'F|25|FRENCH|~2Locale;||',
'F|25|GERMAN|~2Locale;||',
'F|25|ITALIAN|~2Locale;||',
'F|25|JAPANESE|~2Locale;||',
'F|25|KOREAN|~2Locale;||',
'F|25|CHINESE|~2Locale;||',
'F|25|SIMPLIFIED_CHINESE|~2Locale;||',
'F|25|TRADITIONAL_CHINESE|~2Locale;||',
'F|25|FRANCE|~2Locale;||',
'F|25|GERMANY|~2Locale;||',
'F|25|ITALY|~2Locale;||',
'F|25|JAPAN|~2Locale;||',
'F|25|KOREA|~2Locale;||',
'F|25|UK|~2Locale;||',
'F|25|US|~2Locale;||',
'F|25|CANADA|~2Locale;||',
'F|25|CANADA_FRENCH|~2Locale;||',
'F|25|ROOT|~2Locale;||',
'F|25|CHINA|~2Locale;||',
'F|25|PRC|~2Locale;||',
'F|25|TAIWAN|~2Locale;||',
'F|25|PRIVATE_USE_EXTENSION|C||C120',
'F|25|UNICODE_LOCALE_EXTENSION|C||C117',
'M|1|<init>|(~S)V||',
'M|1|<init>|(~S~S~S)V||',
'M|1|<init>|(~S~S)V||',
'M|1|equals|(~O)Z||',
'M|17|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|clone|()~O||',
'M|9|getDefault|()~2Locale;||',
'M|9|getDefault|(~2Locale$Category;)~2Locale;||',
'M|9|of|(~S~S)~2Locale;||',
'M|9|of|(~S~S~S)~2Locale;||',
'M|9|of|(~S)~2Locale;||',
'M|9|lookup|(~2List;~2Collection;)~2Locale;|(~2List<~2Locale$LanguageRange;>;~2Collection<~2Locale;>;)~2Locale;|',
'M|9|filter|(~2List;~2Collection;)~2List;|(~2List<~2Locale$LanguageRange;>;~2Collection<~2Locale;>;)~2List<~2Locale;>;|',
'M|9|filter|(~2List;~2Collection;~2Locale$FilteringMode;)~2List;|(~2List<~2Locale$LanguageRange;>;~2Collection<~2Locale;>;~2Locale$FilteringMode;)~2List<~2Locale;>;|',
'M|1|getLanguage|()~S||',
'M|17|getDisplayName|()~S||',
'M|1|getDisplayName|(~2Locale;)~S||',
'M|9|getAvailableLocales|()[~2Locale;||',
'M|1|getUnicodeLocaleType|(~S)~S||',
'M|1|getCountry|()~S||',
'M|1|stripExtensions|()~2Locale;||',
'M|1|hasExtensions|()Z||',
'M|1|getVariant|()~S||',
'M|41|setDefault|(~2Locale$Category;~2Locale;)V||',
'M|41|setDefault|(~2Locale;)V||',
'M|1|getScript|()~S||',
'M|1|getUnicodeLocaleAttributes|()~2Set;|()~2Set<~S>;|',
'M|1|getUnicodeLocaleKeys|()~2Set;|()~2Set<~S>;|',
'M|17|getDisplayLanguage|()~S||',
'M|1|getDisplayLanguage|(~2Locale;)~S||',
'M|1|getDisplayScript|(~2Locale;)~S||',
'M|1|getDisplayScript|()~S||',
'M|1|getDisplayCountry|(~2Locale;)~S||',
'M|17|getDisplayCountry|()~S||',
'M|1|getDisplayVariant|(~2Locale;)~S||',
'M|17|getDisplayVariant|()~S||',
'M|9|filterTags|(~2List;~2Collection;)~2List;|(~2List<~2Locale$LanguageRange;>;~2Collection<~S>;)~2List<~S>;|',
'M|9|filterTags|(~2List;~2Collection;~2Locale$FilteringMode;)~2List;|(~2List<~2Locale$LanguageRange;>;~2Collection<~S>;~2Locale$FilteringMode;)~2List<~S>;|',
'M|9|lookupTag|(~2List;~2Collection;)~S|(~2List<~2Locale$LanguageRange;>;~2Collection<~S>;)~S|',
'M|9|availableLocales|()~5Stream;|()~5Stream<~2Locale;>;|',
'M|9|getISOCountries|(~2Locale$IsoCountryCode;)~2Set;|(~2Locale$IsoCountryCode;)~2Set<~S>;|',
'M|9|getISOCountries|()[~S||',
'M|9|getISOLanguages|()[~S||',
'M|1|getExtension|(C)~S||',
'M|1|getExtensionKeys|()~2Set;|()~2Set<~1Character;>;|',
'M|1|toLanguageTag|()~S||',
'M|9|caseFoldLanguageTag|(~S)~S||',
'M|9|forLanguageTag|(~S)~2Locale;||',
'M|1|getISO3Language|()~S||java/util/MissingResourceException',
'M|1|getISO3Country|()~S||java/util/MissingResourceException',
'C|1|java/util/NoSuchElementException|~1RuntimeException;',
'M|1|<init>|(~S)V||',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|()V||',
'C|1|java/util/ConcurrentModificationException|~1RuntimeException;',
'M|1|<init>|(~S~1Throwable;)V||',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'C|1|java/util/InputMismatchException|~2NoSuchElementException;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1|java/util/EmptyStackException|~1RuntimeException;',
'M|1|<init>|()V||',
'C|1537|java/util/SortedMap|<K:~OV:~O>~O~2SequencedMap<TK;TV;>;',
'M|1025|values|()~2Collection;|()~2Collection<TV;>;|',
'M|1025|entrySet|()~2Set;|()~2Set<~2Map$Entry<TK;TV;>;>;|',
'M|1025|keySet|()~2Set;|()~2Set<TK;>;|',
'M|65537|reversed|()~2SortedMap;|()~2SortedMap<TK;TV;>;|',
'M|1025|comparator|()~2Comparator;|()~2Comparator<-TK;>;|',
'M|1025|firstKey|()~O|()TK;|',
'M|65537|putFirst|(~O~O)~O|(TK;TV;)TV;|',
'M|65537|putLast|(~O~O)~O|(TK;TV;)TV;|',
'M|1025|subMap|(~O~O)~2SortedMap;|(TK;TK;)~2SortedMap<TK;TV;>;|',
'M|1025|headMap|(~O)~2SortedMap;|(TK;)~2SortedMap<TK;TV;>;|',
'M|1025|tailMap|(~O)~2SortedMap;|(TK;)~2SortedMap<TK;TV;>;|',
'M|1025|lastKey|()~O|()TK;|',
'C|1537|java/util/NavigableMap|<K:~OV:~O>~O~2SortedMap<TK;TV;>;',
'M|65537|reversed|()~2NavigableMap;|()~2NavigableMap<TK;TV;>;|',
'M|1025|firstEntry|()~2Map$Entry;|()~2Map$Entry<TK;TV;>;|',
'M|1025|lastEntry|()~2Map$Entry;|()~2Map$Entry<TK;TV;>;|',
'M|1025|pollFirstEntry|()~2Map$Entry;|()~2Map$Entry<TK;TV;>;|',
'M|1025|pollLastEntry|()~2Map$Entry;|()~2Map$Entry<TK;TV;>;|',
'M|1025|descendingMap|()~2NavigableMap;|()~2NavigableMap<TK;TV;>;|',
'M|1025|lowerEntry|(~O)~2Map$Entry;|(TK;)~2Map$Entry<TK;TV;>;|',
'M|1025|lowerKey|(~O)~O|(TK;)TK;|',
'M|1025|floorEntry|(~O)~2Map$Entry;|(TK;)~2Map$Entry<TK;TV;>;|',
'M|1025|floorKey|(~O)~O|(TK;)TK;|',
'M|1025|ceilingEntry|(~O)~2Map$Entry;|(TK;)~2Map$Entry<TK;TV;>;|',
'M|1025|ceilingKey|(~O)~O|(TK;)TK;|',
'M|1025|higherEntry|(~O)~2Map$Entry;|(TK;)~2Map$Entry<TK;TV;>;|',
'M|1025|higherKey|(~O)~O|(TK;)TK;|',
'M|1025|navigableKeySet|()~2NavigableSet;|()~2NavigableSet<TK;>;|',
'M|1025|descendingKeySet|()~2NavigableSet;|()~2NavigableSet<TK;>;|',
'M|1025|subMap|(~O~O)~2SortedMap;|(TK;TK;)~2SortedMap<TK;TV;>;|',
'M|1025|subMap|(~OZ~OZ)~2NavigableMap;|(TK;ZTK;Z)~2NavigableMap<TK;TV;>;|',
'M|1025|headMap|(~OZ)~2NavigableMap;|(TK;Z)~2NavigableMap<TK;TV;>;|',
'M|1025|headMap|(~O)~2SortedMap;|(TK;)~2SortedMap<TK;TV;>;|',
'M|1025|tailMap|(~OZ)~2NavigableMap;|(TK;Z)~2NavigableMap<TK;TV;>;|',
'M|1025|tailMap|(~O)~2SortedMap;|(TK;)~2SortedMap<TK;TV;>;|',
'C|1537|java/util/SortedSet|<E:~O>~O~2Set<TE;>;~2SequencedSet<TE;>;',
'M|1025|last|()~O|()TE;|',
'M|65537|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|1025|first|()~O|()TE;|',
'M|65537|getFirst|()~O|()TE;|',
'M|65537|getLast|()~O|()TE;|',
'M|65537|addFirst|(~O)V|(TE;)V|',
'M|65537|addLast|(~O)V|(TE;)V|',
'M|65537|removeFirst|()~O|()TE;|',
'M|65537|removeLast|()~O|()TE;|',
'M|65537|reversed|()~2SortedSet;|()~2SortedSet<TE;>;|',
'M|1025|comparator|()~2Comparator;|()~2Comparator<-TE;>;|',
'M|1025|subSet|(~O~O)~2SortedSet;|(TE;TE;)~2SortedSet<TE;>;|',
'M|1025|headSet|(~O)~2SortedSet;|(TE;)~2SortedSet<TE;>;|',
'M|1025|tailSet|(~O)~2SortedSet;|(TE;)~2SortedSet<TE;>;|',
'C|1537|java/util/NavigableSet|<E:~O>~O~2SortedSet<TE;>;',
'M|1025|floor|(~O)~O|(TE;)TE;|',
'M|1025|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|65537|removeFirst|()~O|()TE;|',
'M|65537|removeLast|()~O|()TE;|',
'M|65537|reversed|()~2NavigableSet;|()~2NavigableSet<TE;>;|',
'M|1025|lower|(~O)~O|(TE;)TE;|',
'M|1025|pollFirst|()~O|()TE;|',
'M|1025|pollLast|()~O|()TE;|',
'M|1025|descendingIterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1025|descendingSet|()~2NavigableSet;|()~2NavigableSet<TE;>;|',
'M|1025|ceiling|(~O)~O|(TE;)TE;|',
'M|1025|higher|(~O)~O|(TE;)TE;|',
'M|1025|subSet|(~OZ~OZ)~2NavigableSet;|(TE;ZTE;Z)~2NavigableSet<TE;>;|',
'M|1025|subSet|(~O~O)~2SortedSet;|(TE;TE;)~2SortedSet<TE;>;|',
'M|1025|headSet|(~OZ)~2NavigableSet;|(TE;Z)~2NavigableSet<TE;>;|',
'M|1025|headSet|(~O)~2SortedSet;|(TE;)~2SortedSet<TE;>;|',
'M|1025|tailSet|(~OZ)~2NavigableSet;|(TE;Z)~2NavigableSet<TE;>;|',
'M|1025|tailSet|(~O)~2SortedSet;|(TE;)~2SortedSet<TE;>;|',
'C|1537|java/util/Enumeration|<E:~O>~O',
'M|65537|asIterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1025|hasMoreElements|()Z||',
'M|1025|nextElement|()~O|()TE;|',
'C|1|java/util/Hashtable|<K:~OV:~O>~2Dictionary<TK;TV;>;~2Map<TK;TV;>;~1Cloneable;~4Serializable;',
'M|1|<init>|(~2Map;)V|(~2Map<+TK;+TV;>;)V|',
'M|1|<init>|()V||',
'M|1|<init>|(I)V||',
'M|1|<init>|(IF)V||',
'M|33|remove|(~O~O)Z||',
'M|33|remove|(~O)~O|(~O)TV;|',
'M|33|size|()I||',
'M|33|get|(~O)~O|(~O)TV;|',
'M|33|put|(~O~O)~O|(TK;TV;)TV;|',
'M|33|equals|(~O)Z||',
'M|33|toString|()~S||',
'M|1|values|()~2Collection;|()~2Collection<TV;>;|',
'M|33|hashCode|()I||',
'M|33|clone|()~O||',
'M|33|clear|()V||',
'M|33|isEmpty|()Z||',
'M|33|replace|(~O~O~O)Z|(TK;TV;TV;)Z|',
'M|33|replace|(~O~O)~O|(TK;TV;)TV;|',
'M|33|replaceAll|(~3BiFunction;)V|(~3BiFunction<-TK;-TV;+TV;>;)V|',
'M|33|contains|(~O)Z||',
'M|33|elements|()~2Enumeration;|()~2Enumeration<TV;>;|',
'M|33|merge|(~O~O~3BiFunction;)~O|(TK;TV;~3BiFunction<-TV;-TV;+TV;>;)TV;|',
'M|1|entrySet|()~2Set;|()~2Set<~2Map$Entry<TK;TV;>;>;|',
'M|33|putAll|(~2Map;)V|(~2Map<+TK;+TV;>;)V|',
'M|33|putIfAbsent|(~O~O)~O|(TK;TV;)TV;|',
'M|33|compute|(~O~3BiFunction;)~O|(TK;~3BiFunction<-TK;-TV;+TV;>;)TV;|',
'M|33|forEach|(~3BiConsumer;)V|(~3BiConsumer<-TK;-TV;>;)V|',
'M|33|containsKey|(~O)Z||',
'M|33|computeIfAbsent|(~O~3Function;)~O|(TK;~3Function<-TK;+TV;>;)TV;|',
'M|33|keys|()~2Enumeration;|()~2Enumeration<TK;>;|',
'M|1|keySet|()~2Set;|()~2Set<TK;>;|',
'M|1|containsValue|(~O)Z||',
'M|33|getOrDefault|(~O~O)~O|(~OTV;)TV;|',
'M|33|computeIfPresent|(~O~3BiFunction;)~O|(TK;~3BiFunction<-TK;-TV;+TV;>;)TV;|',
'M|4|rehash|()V||',
'C|1025|java/util/Dictionary|<K:~OV:~O>~O',
'M|1|<init>|()V||',
'M|1025|remove|(~O)~O|(~O)TV;|',
'M|1025|size|()I||',
'M|1025|get|(~O)~O|(~O)TV;|',
'M|1025|put|(~O~O)~O|(TK;TV;)TV;|',
'M|1025|isEmpty|()Z||',
'M|1025|elements|()~2Enumeration;|()~2Enumeration<TV;>;|',
'M|1025|keys|()~2Enumeration;|()~2Enumeration<TK;>;|',
'C|1|java/util/EnumMap|<K:~1Enum<TK;>;V:~O>~2AbstractMap<TK;TV;>;~4Serializable;~1Cloneable;',
'M|1|<init>|(~2EnumMap;)V|(~2EnumMap<TK;+TV;>;)V|',
'M|1|<init>|(~2Map;)V|(~2Map<TK;+TV;>;)V|',
'M|1|<init>|(~1Class;)V|(~1Class<TK;>;)V|',
'M|1|remove|(~O)~O|(~O)TV;|',
'M|1|size|()I||',
'M|1|get|(~O)~O|(~O)TV;|',
'M|1|put|(~1Enum;~O)~O|(TK;TV;)TV;|',
'M|1|equals|(~O)Z||',
'M|1|values|()~2Collection;|()~2Collection<TV;>;|',
'M|1|hashCode|()I||',
'M|1|clone|()~2EnumMap;|()~2EnumMap<TK;TV;>;|',
'M|1|clear|()V||',
'M|1|entrySet|()~2Set;|()~2Set<~2Map$Entry<TK;TV;>;>;|',
'M|1|putAll|(~2Map;)V|(~2Map<+TK;+TV;>;)V|',
'M|1|containsKey|(~O)Z||',
'M|1|keySet|()~2Set;|()~2Set<TK;>;|',
'M|1|containsValue|(~O)Z||',
'C|1025|java/util/EnumSet|<E:~1Enum<TE;>;>~2AbstractSet<TE;>;~1Cloneable;~4Serializable;',
'M|1|clone|()~2EnumSet;|()~2EnumSet<TE;>;|',
'M|9|copyOf|(~2Collection;)~2EnumSet;|<E:~1Enum<TE;>;>(~2Collection<TE;>;)~2EnumSet<TE;>;|',
'M|9|copyOf|(~2EnumSet;)~2EnumSet;|<E:~1Enum<TE;>;>(~2EnumSet<TE;>;)~2EnumSet<TE;>;|',
'M|9|of|(~1Enum;~1Enum;~1Enum;)~2EnumSet;|<E:~1Enum<TE;>;>(TE;TE;TE;)~2EnumSet<TE;>;|',
'M|9|of|(~1Enum;~1Enum;)~2EnumSet;|<E:~1Enum<TE;>;>(TE;TE;)~2EnumSet<TE;>;|',
'M|9|of|(~1Enum;~1Enum;~1Enum;~1Enum;)~2EnumSet;|<E:~1Enum<TE;>;>(TE;TE;TE;TE;)~2EnumSet<TE;>;|',
'M|137|of|(~1Enum;[~1Enum;)~2EnumSet;|<E:~1Enum<TE;>;>(TE;[TE;)~2EnumSet<TE;>;|',
'M|9|of|(~1Enum;)~2EnumSet;|<E:~1Enum<TE;>;>(TE;)~2EnumSet<TE;>;|',
'M|9|of|(~1Enum;~1Enum;~1Enum;~1Enum;~1Enum;)~2EnumSet;|<E:~1Enum<TE;>;>(TE;TE;TE;TE;TE;)~2EnumSet<TE;>;|',
'M|9|noneOf|(~1Class;)~2EnumSet;|<E:~1Enum<TE;>;>(~1Class<TE;>;)~2EnumSet<TE;>;|',
'M|9|range|(~1Enum;~1Enum;)~2EnumSet;|<E:~1Enum<TE;>;>(TE;TE;)~2EnumSet<TE;>;|',
'M|9|allOf|(~1Class;)~2EnumSet;|<E:~1Enum<TE;>;>(~1Class<TE;>;)~2EnumSet<TE;>;|',
'M|9|complementOf|(~2EnumSet;)~2EnumSet;|<E:~1Enum<TE;>;>(~2EnumSet<TE;>;)~2EnumSet<TE;>;|',
'C|1|java/util/IdentityHashMap|<K:~OV:~O>~2AbstractMap<TK;TV;>;~2Map<TK;TV;>;~4Serializable;~1Cloneable;',
'M|1|<init>|(~2Map;)V|(~2Map<+TK;+TV;>;)V|',
'M|1|<init>|()V||',
'M|1|<init>|(I)V||',
'M|1|remove|(~O~O)Z||',
'M|1|remove|(~O)~O|(~O)TV;|',
'M|1|size|()I||',
'M|1|get|(~O)~O|(~O)TV;|',
'M|1|put|(~O~O)~O|(TK;TV;)TV;|',
'M|1|equals|(~O)Z||',
'M|1|values|()~2Collection;|()~2Collection<TV;>;|',
'M|1|hashCode|()I||',
'M|1|clone|()~O||',
'M|1|clear|()V||',
'M|1|isEmpty|()Z||',
'M|1|replace|(~O~O~O)Z|(TK;TV;TV;)Z|',
'M|1|replaceAll|(~3BiFunction;)V|(~3BiFunction<-TK;-TV;+TV;>;)V|',
'M|1|entrySet|()~2Set;|()~2Set<~2Map$Entry<TK;TV;>;>;|',
'M|1|putAll|(~2Map;)V|(~2Map<+TK;+TV;>;)V|',
'M|1|forEach|(~3BiConsumer;)V|(~3BiConsumer<-TK;-TV;>;)V|',
'M|1|containsKey|(~O)Z||',
'M|1|keySet|()~2Set;|()~2Set<TK;>;|',
'M|1|containsValue|(~O)Z||',
'C|1|java/util/Properties|~2Hashtable<~O~O>;',
'F|68|defaults|~2Properties;||',
'M|1|<init>|(~2Properties;)V||',
'M|1|<init>|(I)V||',
'M|1|<init>|()V||',
'M|33|remove|(~O~O)Z||',
'M|33|remove|(~O)~O||',
'M|1|size|()I||',
'M|1|get|(~O)~O||',
'M|33|put|(~O~O)~O||',
'M|1|getProperty|(~S~S)~S||',
'M|1|getProperty|(~S)~S||',
'M|33|equals|(~O)Z||',
'M|33|toString|()~S||',
'M|1|values|()~2Collection;|()~2Collection<~O>;|',
'M|33|hashCode|()I||',
'M|33|clone|()~O||',
'M|33|load|(~4InputStream;)V||java/io/IOException',
'M|33|load|(~4Reader;)V||java/io/IOException',
'M|1|store|(~4OutputStream;~S)V||java/io/IOException',
'M|1|store|(~4Writer;~S)V||java/io/IOException',
'M|33|clear|()V||',
'M|1|isEmpty|()Z||',
'M|33|replace|(~O~O)~O||',
'M|33|replace|(~O~O~O)Z||',
'M|33|replaceAll|(~3BiFunction;)V|(~3BiFunction<-~O-~O*>;)V|',
'M|1|contains|(~O)Z||',
'M|1|list|(~4PrintStream;)V||',
'M|1|list|(~4PrintWriter;)V||',
'M|1|elements|()~2Enumeration;|()~2Enumeration<~O>;|',
'M|33|merge|(~O~O~3BiFunction;)~O|(~O~O~3BiFunction<-~O-~O*>;)~O|',
'M|1|entrySet|()~2Set;|()~2Set<~2Map$Entry<~O~O>;>;|',
'M|33|putAll|(~2Map;)V|(~2Map<**>;)V|',
'M|33|putIfAbsent|(~O~O)~O||',
'M|33|compute|(~O~3BiFunction;)~O|(~O~3BiFunction<-~O-~O*>;)~O|',
'M|33|setProperty|(~S~S)~O||',
'M|33|forEach|(~3BiConsumer;)V|(~3BiConsumer<-~O-~O>;)V|',
'M|1|containsKey|(~O)Z||',
'M|33|computeIfAbsent|(~O~3Function;)~O|(~O~3Function<-~O*>;)~O|',
'M|1|storeToXML|(~4OutputStream;~S)V||java/io/IOException',
'M|1|storeToXML|(~4OutputStream;~S~S)V||java/io/IOException',
'M|1|storeToXML|(~4OutputStream;~SLjava/nio/charset/Charset;)V||java/io/IOException',
'M|1|keys|()~2Enumeration;|()~2Enumeration<~O>;|',
'M|1|keySet|()~2Set;|()~2Set<~O>;|',
'M|1|containsValue|(~O)Z||',
'M|1|getOrDefault|(~O~O)~O||',
'M|33|computeIfPresent|(~O~3BiFunction;)~O|(~O~3BiFunction<-~O-~O*>;)~O|',
'M|1|save|(~4OutputStream;~S)V||',
'M|33|loadFromXML|(~4InputStream;)V||java/io/IOException,java/util/InvalidPropertiesFormatException',
'M|1|propertyNames|()~2Enumeration;|()~2Enumeration<*>;|',
'M|1|stringPropertyNames|()~2Set;|()~2Set<~S>;|',
'M|4|rehash|()V||',
'C|1537|java/util/RandomAccess|~O',
'C|1537|java/util/Spliterator|<T:~O>~O',
'F|25|ORDERED|I||I16',
'F|25|DISTINCT|I||I1',
'F|25|SORTED|I||I4',
'F|25|SIZED|I||I64',
'F|25|NONNULL|I||I256',
'F|25|IMMUTABLE|I||I1024',
'F|25|CONCURRENT|I||I4096',
'F|25|SUBSIZED|I||I16384',
'M|65537|forEachRemaining|(~3Consumer;)V|(~3Consumer<-TT;>;)V|',
'M|1025|characteristics|()I||',
'M|1025|trySplit|()~2Spliterator;|()~2Spliterator<TT;>;|',
'M|1025|tryAdvance|(~3Consumer;)Z|(~3Consumer<-TT;>;)Z|',
'M|1025|estimateSize|()J||',
'M|65537|getExactSizeIfKnown|()J||',
'M|65537|hasCharacteristics|(I)Z||',
'M|65537|getComparator|()~2Comparator;|()~2Comparator<-TT;>;|',
'C|1537|java/util/PrimitiveIterator|<T:~OT_CONS:~O>~O~2Iterator<TT;>;',
'M|1025|forEachRemaining|(~O)V|(TT_CONS;)V|',
'C|1537|java/util/PrimitiveIterator$OfInt|~O~2PrimitiveIterator<~1Integer;~3IntConsumer;>;',
'M|65537|forEachRemaining|(~3IntConsumer;)V||',
'M|65537|forEachRemaining|(~3Consumer;)V|(~3Consumer<-~1Integer;>;)V|',
'M|65537|next|()~1Integer;||',
'M|1025|nextInt|()I||',
'C|1|java/util/IntSummaryStatistics|~O~3IntConsumer;',
'M|1|<init>|()V||',
'M|1|<init>|(JIIJ)V||java/lang/IllegalArgumentException',
'M|1|toString|()~S||',
'M|1|accept|(I)V||',
'M|1|combine|(~2IntSummaryStatistics;)V||',
'M|17|getCount|()J||',
'M|17|getSum|()J||',
'M|17|getMin|()I||',
'M|17|getAverage|()D||',
'M|17|getMax|()I||',
'C|1|java/util/DoubleSummaryStatistics|~O~3DoubleConsumer;',
'M|1|<init>|()V||',
'M|1|<init>|(JDDD)V||java/lang/IllegalArgumentException',
'M|1|toString|()~S||',
'M|1|accept|(D)V||',
'M|1|combine|(~2DoubleSummaryStatistics;)V||',
'M|17|getCount|()J||',
'M|17|getSum|()D||',
'M|17|getMin|()D||',
'M|17|getAverage|()D||',
'M|17|getMax|()D||',
'C|1|java/util/LongSummaryStatistics|~O~3LongConsumer;~3IntConsumer;',
'M|1|<init>|()V||',
'M|1|<init>|(JJJJ)V||java/lang/IllegalArgumentException',
'M|1|toString|()~S||',
'M|1|accept|(I)V||',
'M|1|accept|(J)V||',
'M|1|combine|(~2LongSummaryStatistics;)V||',
'M|17|getCount|()J||',
'M|17|getSum|()J||',
'M|17|getMin|()J||',
'M|17|getAverage|()D||',
'M|17|getMax|()J||',
'C|1537|java/util/function/Function|<T:~OR:~O>~O',
'M|1025|apply|(~O)~O|(TT;)TR;|',
'M|9|identity|()~3Function;|<T:~O>()~3Function<TT;TT;>;|',
'M|65537|compose|(~3Function;)~3Function;|<V:~O>(~3Function<-TV;+TT;>;)~3Function<TV;TR;>;|',
'M|65537|andThen|(~3Function;)~3Function;|<V:~O>(~3Function<-TR;+TV;>;)~3Function<TT;TV;>;|',
'C|1537|java/util/function/BiFunction|<T:~OU:~OR:~O>~O',
'M|1025|apply|(~O~O)~O|(TT;TU;)TR;|',
'M|65537|andThen|(~3Function;)~3BiFunction;|<V:~O>(~3Function<-TR;+TV;>;)~3BiFunction<TT;TU;TV;>;|',
'C|1537|java/util/function/Supplier|<T:~O>~O',
'M|1025|get|()~O|()TT;|',
'C|1537|java/util/function/Consumer|<T:~O>~O',
'M|1025|accept|(~O)V|(TT;)V|',
'M|65537|andThen|(~3Consumer;)~3Consumer;|(~3Consumer<-TT;>;)~3Consumer<TT;>;|',
'C|1537|java/util/function/BiConsumer|<T:~OU:~O>~O',
'M|1025|accept|(~O~O)V|(TT;TU;)V|',
'M|65537|andThen|(~3BiConsumer;)~3BiConsumer;|(~3BiConsumer<-TT;-TU;>;)~3BiConsumer<TT;TU;>;|',
'C|1537|java/util/function/Predicate|<T:~O>~O',
'M|1025|test|(~O)Z|(TT;)Z|',
'M|65537|or|(~3Predicate;)~3Predicate;|(~3Predicate<-TT;>;)~3Predicate<TT;>;|',
'M|65537|negate|()~3Predicate;|()~3Predicate<TT;>;|',
'M|65537|and|(~3Predicate;)~3Predicate;|(~3Predicate<-TT;>;)~3Predicate<TT;>;|',
'M|9|not|(~3Predicate;)~3Predicate;|<T:~O>(~3Predicate<-TT;>;)~3Predicate<TT;>;|',
'M|9|isEqual|(~O)~3Predicate;|<T:~O>(~O)~3Predicate<TT;>;|',
'C|1537|java/util/function/BiPredicate|<T:~OU:~O>~O',
'M|1025|test|(~O~O)Z|(TT;TU;)Z|',
'M|65537|or|(~3BiPredicate;)~3BiPredicate;|(~3BiPredicate<-TT;-TU;>;)~3BiPredicate<TT;TU;>;|',
'M|65537|negate|()~3BiPredicate;|()~3BiPredicate<TT;TU;>;|',
'M|65537|and|(~3BiPredicate;)~3BiPredicate;|(~3BiPredicate<-TT;-TU;>;)~3BiPredicate<TT;TU;>;|',
'C|1537|java/util/function/UnaryOperator|<T:~O>~O~3Function<TT;TT;>;',
'M|9|identity|()~3UnaryOperator;|<T:~O>()~3UnaryOperator<TT;>;|',
'C|1537|java/util/function/BinaryOperator|<T:~O>~O~3BiFunction<TT;TT;TT;>;',
'M|9|minBy|(~2Comparator;)~3BinaryOperator;|<T:~O>(~2Comparator<-TT;>;)~3BinaryOperator<TT;>;|',
'M|9|maxBy|(~2Comparator;)~3BinaryOperator;|<T:~O>(~2Comparator<-TT;>;)~3BinaryOperator<TT;>;|',
'C|1537|java/util/function/IntFunction|<R:~O>~O',
'M|1025|apply|(I)~O|(I)TR;|',
'C|1537|java/util/function/IntPredicate|~O',
'M|1025|test|(I)Z||',
'M|65537|or|(~3IntPredicate;)~3IntPredicate;||',
'M|65537|negate|()~3IntPredicate;||',
'M|65537|and|(~3IntPredicate;)~3IntPredicate;||',
'C|1537|java/util/function/IntUnaryOperator|~O',
'M|9|identity|()~3IntUnaryOperator;||',
'M|1025|applyAsInt|(I)I||',
'M|65537|compose|(~3IntUnaryOperator;)~3IntUnaryOperator;||',
'M|65537|andThen|(~3IntUnaryOperator;)~3IntUnaryOperator;||',
'C|1537|java/util/function/IntBinaryOperator|~O',
'M|1025|applyAsInt|(II)I||',
'C|1537|java/util/function/IntConsumer|~O',
'M|1025|accept|(I)V||',
'M|65537|andThen|(~3IntConsumer;)~3IntConsumer;||',
'C|1537|java/util/function/IntSupplier|~O',
'M|1025|getAsInt|()I||',
'C|1537|java/util/function/IntToDoubleFunction|~O',
'M|1025|applyAsDouble|(I)D||',
'C|1537|java/util/function/IntToLongFunction|~O',
'M|1025|applyAsLong|(I)J||',
'C|1537|java/util/function/ToIntFunction|<T:~O>~O',
'M|1025|applyAsInt|(~O)I|(TT;)I|',
'C|1537|java/util/function/ToLongFunction|<T:~O>~O',
'M|1025|applyAsLong|(~O)J|(TT;)J|',
'C|1537|java/util/function/ToDoubleFunction|<T:~O>~O',
'M|1025|applyAsDouble|(~O)D|(TT;)D|',
'C|1537|java/util/function/ToIntBiFunction|<T:~OU:~O>~O',
'M|1025|applyAsInt|(~O~O)I|(TT;TU;)I|',
'C|1537|java/util/function/ToDoubleBiFunction|<T:~OU:~O>~O',
'M|1025|applyAsDouble|(~O~O)D|(TT;TU;)D|',
'C|1537|java/util/function/ToLongBiFunction|<T:~OU:~O>~O',
'M|1025|applyAsLong|(~O~O)J|(TT;TU;)J|',
'C|1537|java/util/function/BooleanSupplier|~O',
'M|1025|getAsBoolean|()Z||',
'C|1537|java/util/function/DoubleSupplier|~O',
'M|1025|getAsDouble|()D||',
'C|1537|java/util/function/LongSupplier|~O',
'M|1025|getAsLong|()J||',
'C|1537|java/util/function/DoubleUnaryOperator|~O',
'M|9|identity|()~3DoubleUnaryOperator;||',
'M|1025|applyAsDouble|(D)D||',
'M|65537|compose|(~3DoubleUnaryOperator;)~3DoubleUnaryOperator;||',
'M|65537|andThen|(~3DoubleUnaryOperator;)~3DoubleUnaryOperator;||',
'C|1537|java/util/function/DoubleBinaryOperator|~O',
'M|1025|applyAsDouble|(DD)D||',
'C|1537|java/util/function/DoubleFunction|<R:~O>~O',
'M|1025|apply|(D)~O|(D)TR;|',
'C|1537|java/util/function/DoublePredicate|~O',
'M|1025|test|(D)Z||',
'M|65537|or|(~3DoublePredicate;)~3DoublePredicate;||',
'M|65537|negate|()~3DoublePredicate;||',
'M|65537|and|(~3DoublePredicate;)~3DoublePredicate;||',
'C|1537|java/util/function/DoubleConsumer|~O',
'M|1025|accept|(D)V||',
'M|65537|andThen|(~3DoubleConsumer;)~3DoubleConsumer;||',
'C|1537|java/util/function/DoubleToIntFunction|~O',
'M|1025|applyAsInt|(D)I||',
'C|1537|java/util/function/LongFunction|<R:~O>~O',
'M|1025|apply|(J)~O|(J)TR;|',
'C|1537|java/util/function/LongPredicate|~O',
'M|1025|test|(J)Z||',
'M|65537|or|(~3LongPredicate;)~3LongPredicate;||',
'M|65537|negate|()~3LongPredicate;||',
'M|65537|and|(~3LongPredicate;)~3LongPredicate;||',
'C|1537|java/util/function/LongUnaryOperator|~O',
'M|9|identity|()~3LongUnaryOperator;||',
'M|1025|applyAsLong|(J)J||',
'M|65537|compose|(~3LongUnaryOperator;)~3LongUnaryOperator;||',
'M|65537|andThen|(~3LongUnaryOperator;)~3LongUnaryOperator;||',
'C|1537|java/util/function/LongBinaryOperator|~O',
'M|1025|applyAsLong|(JJ)J||',
'C|1537|java/util/function/LongConsumer|~O',
'M|1025|accept|(J)V||',
'M|65537|andThen|(~3LongConsumer;)~3LongConsumer;||',
'C|1537|java/util/function/ObjIntConsumer|<T:~O>~O',
'M|1025|accept|(~OI)V|(TT;I)V|',
'C|1537|java/util/stream/Stream|<T:~O>~O~5BaseStream<TT;~5Stream<TT;>;>;',
'M|1025|min|(~2Comparator;)~2Optional;|(~2Comparator<-TT;>;)~2Optional<TT;>;|',
'M|1025|max|(~2Comparator;)~2Optional;|(~2Comparator<-TT;>;)~2Optional<TT;>;|',
'M|1025|toArray|()[~O||',
'M|1025|toArray|(~3IntFunction;)[~O|<A:~O>(~3IntFunction<[TA;>;)[TA;|',
'M|1025|map|(~3Function;)~5Stream;|<R:~O>(~3Function<-TT;+TR;>;)~5Stream<TR;>;|',
'M|1025|collect|(~3Supplier;~3BiConsumer;~3BiConsumer;)~O|<R:~O>(~3Supplier<TR;>;~3BiConsumer<TR;-TT;>;~3BiConsumer<TR;TR;>;)TR;|',
'M|1025|collect|(~5Collector;)~O|<R:~OA:~O>(~5Collector<-TT;TA;TR;>;)TR;|',
'M|65537|toList|()~2List;|()~2List<TT;>;|',
'M|137|of|([~O)~5Stream;|<T:~O>([TT;)~5Stream<TT;>;|',
'M|9|of|(~O)~5Stream;|<T:~O>(TT;)~5Stream<TT;>;|',
'M|1025|count|()J||',
'M|9|builder|()~5Stream$Builder;|<T:~O>()~5Stream$Builder<TT;>;|',
'M|9|concat|(~5Stream;~5Stream;)~5Stream;|<T:~O>(~5Stream<+TT;>;~5Stream<+TT;>;)~5Stream<TT;>;|',
'M|1025|limit|(J)~5Stream;|(J)~5Stream<TT;>;|',
'M|1025|filter|(~3Predicate;)~5Stream;|(~3Predicate<-TT;>;)~5Stream<TT;>;|',
'M|9|empty|()~5Stream;|<T:~O>()~5Stream<TT;>;|',
'M|1025|anyMatch|(~3Predicate;)Z|(~3Predicate<-TT;>;)Z|',
'M|1025|flatMap|(~3Function;)~5Stream;|<R:~O>(~3Function<-TT;+~5Stream<+TR;>;>;)~5Stream<TR;>;|',
'M|1025|forEach|(~3Consumer;)V|(~3Consumer<-TT;>;)V|',
'M|1025|findAny|()~2Optional;|()~2Optional<TT;>;|',
'M|1025|skip|(J)~5Stream;|(J)~5Stream<TT;>;|',
'M|1025|peek|(~3Consumer;)~5Stream;|(~3Consumer<-TT;>;)~5Stream<TT;>;|',
'M|1025|reduce|(~O~3BiFunction;~3BinaryOperator;)~O|<U:~O>(TU;~3BiFunction<TU;-TT;TU;>;~3BinaryOperator<TU;>;)TU;|',
'M|1025|reduce|(~O~3BinaryOperator;)~O|(TT;~3BinaryOperator<TT;>;)TT;|',
'M|1025|reduce|(~3BinaryOperator;)~2Optional;|(~3BinaryOperator<TT;>;)~2Optional<TT;>;|',
'M|9|iterate|(~O~3UnaryOperator;)~5Stream;|<T:~O>(TT;~3UnaryOperator<TT;>;)~5Stream<TT;>;|',
'M|9|iterate|(~O~3Predicate;~3UnaryOperator;)~5Stream;|<T:~O>(TT;~3Predicate<-TT;>;~3UnaryOperator<TT;>;)~5Stream<TT;>;|',
'M|1025|distinct|()~5Stream;|()~5Stream<TT;>;|',
'M|9|ofNullable|(~O)~5Stream;|<T:~O>(TT;)~5Stream<TT;>;|',
'M|1025|findFirst|()~2Optional;|()~2Optional<TT;>;|',
'M|1025|allMatch|(~3Predicate;)Z|(~3Predicate<-TT;>;)Z|',
'M|1025|noneMatch|(~3Predicate;)Z|(~3Predicate<-TT;>;)Z|',
'M|1025|sorted|(~2Comparator;)~5Stream;|(~2Comparator<-TT;>;)~5Stream<TT;>;|',
'M|1025|sorted|()~5Stream;|()~5Stream<TT;>;|',
'M|9|generate|(~3Supplier;)~5Stream;|<T:~O>(~3Supplier<+TT;>;)~5Stream<TT;>;|',
'M|1025|forEachOrdered|(~3Consumer;)V|(~3Consumer<-TT;>;)V|',
'M|1025|mapToInt|(~3ToIntFunction;)~5IntStream;|(~3ToIntFunction<-TT;>;)~5IntStream;|',
'M|1025|mapToLong|(~3ToLongFunction;)~5LongStream;|(~3ToLongFunction<-TT;>;)~5LongStream;|',
'M|1025|mapToDouble|(~3ToDoubleFunction;)~5DoubleStream;|(~3ToDoubleFunction<-TT;>;)~5DoubleStream;|',
'M|1025|flatMapToInt|(~3Function;)~5IntStream;|(~3Function<-TT;+~5IntStream;>;)~5IntStream;|',
'M|1025|flatMapToDouble|(~3Function;)~5DoubleStream;|(~3Function<-TT;+~5DoubleStream;>;)~5DoubleStream;|',
'M|1025|flatMapToLong|(~3Function;)~5LongStream;|(~3Function<-TT;+~5LongStream;>;)~5LongStream;|',
'M|65537|mapMulti|(~3BiConsumer;)~5Stream;|<R:~O>(~3BiConsumer<-TT;-~3Consumer<TR;>;>;)~5Stream<TR;>;|',
'M|65537|mapMultiToInt|(~3BiConsumer;)~5IntStream;|(~3BiConsumer<-TT;-~3IntConsumer;>;)~5IntStream;|',
'M|65537|mapMultiToLong|(~3BiConsumer;)~5LongStream;|(~3BiConsumer<-TT;-~3LongConsumer;>;)~5LongStream;|',
'M|65537|mapMultiToDouble|(~3BiConsumer;)~5DoubleStream;|(~3BiConsumer<-TT;-~3DoubleConsumer;>;)~5DoubleStream;|',
'M|65537|takeWhile|(~3Predicate;)~5Stream;|(~3Predicate<-TT;>;)~5Stream<TT;>;|',
'M|65537|dropWhile|(~3Predicate;)~5Stream;|(~3Predicate<-TT;>;)~5Stream<TT;>;|',
'C|1537|java/util/stream/Stream$Builder|<T:~O>~O~3Consumer<TT;>;',
'M|65537|add|(~O)~5Stream$Builder;|(TT;)~5Stream$Builder<TT;>;|',
'M|1025|accept|(~O)V|(TT;)V|',
'M|1025|build|()~5Stream;|()~5Stream<TT;>;|',
'C|1537|java/util/stream/IntStream|~O~5BaseStream<~1Integer;~5IntStream;>;',
'M|1025|min|()~2OptionalInt;||',
'M|1025|max|()~2OptionalInt;||',
'M|1025|toArray|()[I||',
'M|1025|iterator|()~2PrimitiveIterator$OfInt;||',
'M|1025|map|(~3IntUnaryOperator;)~5IntStream;||',
'M|1025|collect|(~3Supplier;~3ObjIntConsumer;~3BiConsumer;)~O|<R:~O>(~3Supplier<TR;>;~3ObjIntConsumer<TR;>;~3BiConsumer<TR;TR;>;)TR;|',
'M|9|of|(I)~5IntStream;||',
'M|137|of|([I)~5IntStream;||',
'M|1025|count|()J||',
'M|9|builder|()~5IntStream$Builder;||',
'M|9|concat|(~5IntStream;~5IntStream;)~5IntStream;||',
'M|1025|limit|(J)~5IntStream;||',
'M|1025|spliterator|()~2Spliterator$OfInt;||',
'M|1025|filter|(~3IntPredicate;)~5IntStream;||',
'M|9|empty|()~5IntStream;||',
'M|1025|anyMatch|(~3IntPredicate;)Z||',
'M|1025|flatMap|(~3IntFunction;)~5IntStream;|(~3IntFunction<+~5IntStream;>;)~5IntStream;|',
'M|1025|forEach|(~3IntConsumer;)V||',
'M|1025|findAny|()~2OptionalInt;||',
'M|1025|skip|(J)~5IntStream;||',
'M|1025|peek|(~3IntConsumer;)~5IntStream;||',
'M|1025|sum|()I||',
'M|1025|reduce|(I~3IntBinaryOperator;)I||',
'M|1025|reduce|(~3IntBinaryOperator;)~2OptionalInt;||',
'M|9|range|(II)~5IntStream;||',
'M|1025|parallel|()~5IntStream;||',
'M|9|iterate|(I~3IntPredicate;~3IntUnaryOperator;)~5IntStream;||',
'M|9|iterate|(I~3IntUnaryOperator;)~5IntStream;||',
'M|1025|distinct|()~5IntStream;||',
'M|1025|findFirst|()~2OptionalInt;||',
'M|1025|allMatch|(~3IntPredicate;)Z||',
'M|1025|noneMatch|(~3IntPredicate;)Z||',
'M|1025|sorted|()~5IntStream;||',
'M|9|generate|(~3IntSupplier;)~5IntStream;||',
'M|1025|mapToObj|(~3IntFunction;)~5Stream;|<U:~O>(~3IntFunction<+TU;>;)~5Stream<TU;>;|',
'M|9|rangeClosed|(II)~5IntStream;||',
'M|1025|sequential|()~5IntStream;||',
'M|1025|forEachOrdered|(~3IntConsumer;)V||',
'M|1025|boxed|()~5Stream;|()~5Stream<~1Integer;>;|',
'M|1025|mapToLong|(~3IntToLongFunction;)~5LongStream;||',
'M|1025|mapToDouble|(~3IntToDoubleFunction;)~5DoubleStream;||',
'M|65537|mapMulti|(~5IntStream$IntMapMultiConsumer;)~5IntStream;||',
'M|65537|takeWhile|(~3IntPredicate;)~5IntStream;||',
'M|65537|dropWhile|(~3IntPredicate;)~5IntStream;||',
'M|1025|average|()~2OptionalDouble;||',
'M|1025|summaryStatistics|()~2IntSummaryStatistics;||',
'M|1025|asLongStream|()~5LongStream;||',
'M|1025|asDoubleStream|()~5DoubleStream;||',
'C|1537|java/util/stream/LongStream|~O~5BaseStream<~1Long;~5LongStream;>;',
'M|1025|min|()~2OptionalLong;||',
'M|1025|max|()~2OptionalLong;||',
'M|1025|toArray|()[J||',
'M|1025|iterator|()~2PrimitiveIterator$OfLong;||',
'M|1025|map|(~3LongUnaryOperator;)~5LongStream;||',
'M|1025|collect|(~3Supplier;~3ObjLongConsumer;~3BiConsumer;)~O|<R:~O>(~3Supplier<TR;>;~3ObjLongConsumer<TR;>;~3BiConsumer<TR;TR;>;)TR;|',
'M|9|of|(J)~5LongStream;||',
'M|137|of|([J)~5LongStream;||',
'M|1025|count|()J||',
'M|9|builder|()~5LongStream$Builder;||',
'M|9|concat|(~5LongStream;~5LongStream;)~5LongStream;||',
'M|1025|limit|(J)~5LongStream;||',
'M|1025|spliterator|()~2Spliterator$OfLong;||',
'M|1025|filter|(~3LongPredicate;)~5LongStream;||',
'M|9|empty|()~5LongStream;||',
'M|1025|anyMatch|(~3LongPredicate;)Z||',
'M|1025|flatMap|(~3LongFunction;)~5LongStream;|(~3LongFunction<+~5LongStream;>;)~5LongStream;|',
'M|1025|forEach|(~3LongConsumer;)V||',
'M|1025|findAny|()~2OptionalLong;||',
'M|1025|skip|(J)~5LongStream;||',
'M|1025|peek|(~3LongConsumer;)~5LongStream;||',
'M|1025|sum|()J||',
'M|1025|reduce|(~3LongBinaryOperator;)~2OptionalLong;||',
'M|1025|reduce|(J~3LongBinaryOperator;)J||',
'M|9|range|(JJ)~5LongStream;||',
'M|1025|parallel|()~5LongStream;||',
'M|9|iterate|(J~3LongUnaryOperator;)~5LongStream;||',
'M|9|iterate|(J~3LongPredicate;~3LongUnaryOperator;)~5LongStream;||',
'M|1025|distinct|()~5LongStream;||',
'M|1025|findFirst|()~2OptionalLong;||',
'M|1025|allMatch|(~3LongPredicate;)Z||',
'M|1025|noneMatch|(~3LongPredicate;)Z||',
'M|1025|sorted|()~5LongStream;||',
'M|9|generate|(~3LongSupplier;)~5LongStream;||',
'M|1025|mapToObj|(~3LongFunction;)~5Stream;|<U:~O>(~3LongFunction<+TU;>;)~5Stream<TU;>;|',
'M|9|rangeClosed|(JJ)~5LongStream;||',
'M|1025|sequential|()~5LongStream;||',
'M|1025|forEachOrdered|(~3LongConsumer;)V||',
'M|1025|boxed|()~5Stream;|()~5Stream<~1Long;>;|',
'M|1025|mapToInt|(~3LongToIntFunction;)~5IntStream;||',
'M|1025|mapToDouble|(~3LongToDoubleFunction;)~5DoubleStream;||',
'M|65537|mapMulti|(~5LongStream$LongMapMultiConsumer;)~5LongStream;||',
'M|65537|takeWhile|(~3LongPredicate;)~5LongStream;||',
'M|65537|dropWhile|(~3LongPredicate;)~5LongStream;||',
'M|1025|average|()~2OptionalDouble;||',
'M|1025|summaryStatistics|()~2LongSummaryStatistics;||',
'M|1025|asDoubleStream|()~5DoubleStream;||',
'C|1537|java/util/stream/DoubleStream|~O~5BaseStream<~1Double;~5DoubleStream;>;',
'M|1025|min|()~2OptionalDouble;||',
'M|1025|max|()~2OptionalDouble;||',
'M|1025|toArray|()[D||',
'M|1025|iterator|()~2PrimitiveIterator$OfDouble;||',
'M|1025|map|(~3DoubleUnaryOperator;)~5DoubleStream;||',
'M|1025|collect|(~3Supplier;~3ObjDoubleConsumer;~3BiConsumer;)~O|<R:~O>(~3Supplier<TR;>;~3ObjDoubleConsumer<TR;>;~3BiConsumer<TR;TR;>;)TR;|',
'M|9|of|(D)~5DoubleStream;||',
'M|137|of|([D)~5DoubleStream;||',
'M|1025|count|()J||',
'M|9|builder|()~5DoubleStream$Builder;||',
'M|9|concat|(~5DoubleStream;~5DoubleStream;)~5DoubleStream;||',
'M|1025|limit|(J)~5DoubleStream;||',
'M|1025|spliterator|()~2Spliterator$OfDouble;||',
'M|1025|filter|(~3DoublePredicate;)~5DoubleStream;||',
'M|9|empty|()~5DoubleStream;||',
'M|1025|anyMatch|(~3DoublePredicate;)Z||',
'M|1025|flatMap|(~3DoubleFunction;)~5DoubleStream;|(~3DoubleFunction<+~5DoubleStream;>;)~5DoubleStream;|',
'M|1025|forEach|(~3DoubleConsumer;)V||',
'M|1025|findAny|()~2OptionalDouble;||',
'M|1025|skip|(J)~5DoubleStream;||',
'M|1025|peek|(~3DoubleConsumer;)~5DoubleStream;||',
'M|1025|sum|()D||',
'M|1025|reduce|(D~3DoubleBinaryOperator;)D||',
'M|1025|reduce|(~3DoubleBinaryOperator;)~2OptionalDouble;||',
'M|1025|parallel|()~5DoubleStream;||',
'M|9|iterate|(D~3DoubleUnaryOperator;)~5DoubleStream;||',
'M|9|iterate|(D~3DoublePredicate;~3DoubleUnaryOperator;)~5DoubleStream;||',
'M|1025|distinct|()~5DoubleStream;||',
'M|1025|findFirst|()~2OptionalDouble;||',
'M|1025|allMatch|(~3DoublePredicate;)Z||',
'M|1025|noneMatch|(~3DoublePredicate;)Z||',
'M|1025|sorted|()~5DoubleStream;||',
'M|9|generate|(~3DoubleSupplier;)~5DoubleStream;||',
'M|1025|mapToObj|(~3DoubleFunction;)~5Stream;|<U:~O>(~3DoubleFunction<+TU;>;)~5Stream<TU;>;|',
'M|1025|sequential|()~5DoubleStream;||',
'M|1025|forEachOrdered|(~3DoubleConsumer;)V||',
'M|1025|boxed|()~5Stream;|()~5Stream<~1Double;>;|',
'M|1025|mapToInt|(~3DoubleToIntFunction;)~5IntStream;||',
'M|1025|mapToLong|(~3DoubleToLongFunction;)~5LongStream;||',
'M|65537|mapMulti|(~5DoubleStream$DoubleMapMultiConsumer;)~5DoubleStream;||',
'M|65537|takeWhile|(~3DoublePredicate;)~5DoubleStream;||',
'M|65537|dropWhile|(~3DoublePredicate;)~5DoubleStream;||',
'M|1025|average|()~2OptionalDouble;||',
'M|1025|summaryStatistics|()~2DoubleSummaryStatistics;||',
'C|1537|java/util/stream/BaseStream|<T:~OS::~5BaseStream<TT;TS;>;>~O~1AutoCloseable;',
'M|1025|iterator|()~2Iterator;|()~2Iterator<TT;>;|',
'M|1025|spliterator|()~2Spliterator;|()~2Spliterator<TT;>;|',
'M|1025|close|()V||',
'M|1025|parallel|()~5BaseStream;|()TS;|',
'M|1025|onClose|(~1Runnable;)~5BaseStream;|(~1Runnable;)TS;|',
'M|1025|sequential|()~5BaseStream;|()TS;|',
'M|1025|isParallel|()Z||',
'M|1025|unordered|()~5BaseStream;|()TS;|',
'C|17|java/util/stream/Collectors|~O',
'M|9|joining|()~5Collector;|()~5Collector<~1CharSequence;*~S>;|',
'M|9|joining|(~1CharSequence;~1CharSequence;~1CharSequence;)~5Collector;|(~1CharSequence;~1CharSequence;~1CharSequence;)~5Collector<~1CharSequence;*~S>;|',
'M|9|joining|(~1CharSequence;)~5Collector;|(~1CharSequence;)~5Collector<~1CharSequence;*~S>;|',
'M|9|toList|()~5Collector;|<T:~O>()~5Collector<TT;*~2List<TT;>;>;|',
'M|9|toMap|(~3Function;~3Function;)~5Collector;|<T:~OK:~OU:~O>(~3Function<-TT;+TK;>;~3Function<-TT;+TU;>;)~5Collector<TT;*~2Map<TK;TU;>;>;|',
'M|9|toMap|(~3Function;~3Function;~3BinaryOperator;)~5Collector;|<T:~OK:~OU:~O>(~3Function<-TT;+TK;>;~3Function<-TT;+TU;>;~3BinaryOperator<TU;>;)~5Collector<TT;*~2Map<TK;TU;>;>;|',
'M|9|toMap|(~3Function;~3Function;~3BinaryOperator;~3Supplier;)~5Collector;|<T:~OK:~OU:~OM::~2Map<TK;TU;>;>(~3Function<-TT;+TK;>;~3Function<-TT;+TU;>;~3BinaryOperator<TU;>;~3Supplier<TM;>;)~5Collector<TT;*TM;>;|',
'M|9|toSet|()~5Collector;|<T:~O>()~5Collector<TT;*~2Set<TT;>;>;|',
'M|9|mapping|(~3Function;~5Collector;)~5Collector;|<T:~OU:~OA:~OR:~O>(~3Function<-TT;+TU;>;~5Collector<-TU;TA;TR;>;)~5Collector<TT;*TR;>;|',
'M|9|groupingBy|(~3Function;)~5Collector;|<T:~OK:~O>(~3Function<-TT;+TK;>;)~5Collector<TT;*~2Map<TK;~2List<TT;>;>;>;|',
'M|9|groupingBy|(~3Function;~5Collector;)~5Collector;|<T:~OK:~OA:~OD:~O>(~3Function<-TT;+TK;>;~5Collector<-TT;TA;TD;>;)~5Collector<TT;*~2Map<TK;TD;>;>;|',
'M|9|groupingBy|(~3Function;~3Supplier;~5Collector;)~5Collector;|<T:~OK:~OD:~OA:~OM::~2Map<TK;TD;>;>(~3Function<-TT;+TK;>;~3Supplier<TM;>;~5Collector<-TT;TA;TD;>;)~5Collector<TT;*TM;>;|',
'M|9|minBy|(~2Comparator;)~5Collector;|<T:~O>(~2Comparator<-TT;>;)~5Collector<TT;*~2Optional<TT;>;>;|',
'M|9|maxBy|(~2Comparator;)~5Collector;|<T:~O>(~2Comparator<-TT;>;)~5Collector<TT;*~2Optional<TT;>;>;|',
'M|9|toCollection|(~3Supplier;)~5Collector;|<T:~OC::~2Collection<TT;>;>(~3Supplier<TC;>;)~5Collector<TT;*TC;>;|',
'M|9|summingLong|(~3ToLongFunction;)~5Collector;|<T:~O>(~3ToLongFunction<-TT;>;)~5Collector<TT;*~1Long;>;|',
'M|9|reducing|(~O~3Function;~3BinaryOperator;)~5Collector;|<T:~OU:~O>(TU;~3Function<-TT;+TU;>;~3BinaryOperator<TU;>;)~5Collector<TT;*TU;>;|',
'M|9|reducing|(~3BinaryOperator;)~5Collector;|<T:~O>(~3BinaryOperator<TT;>;)~5Collector<TT;*~2Optional<TT;>;>;|',
'M|9|reducing|(~O~3BinaryOperator;)~5Collector;|<T:~O>(TT;~3BinaryOperator<TT;>;)~5Collector<TT;*TT;>;|',
'M|9|groupingByConcurrent|(~3Function;~5Collector;)~5Collector;|<T:~OK:~OA:~OD:~O>(~3Function<-TT;+TK;>;~5Collector<-TT;TA;TD;>;)~5Collector<TT;*~2concurrent/ConcurrentMap<TK;TD;>;>;|',
'M|9|groupingByConcurrent|(~3Function;~3Supplier;~5Collector;)~5Collector;|<T:~OK:~OA:~OD:~OM::~2concurrent/ConcurrentMap<TK;TD;>;>(~3Function<-TT;+TK;>;~3Supplier<TM;>;~5Collector<-TT;TA;TD;>;)~5Collector<TT;*TM;>;|',
'M|9|groupingByConcurrent|(~3Function;)~5Collector;|<T:~OK:~O>(~3Function<-TT;+TK;>;)~5Collector<TT;*~2concurrent/ConcurrentMap<TK;~2List<TT;>;>;>;|',
'M|9|partitioningBy|(~3Predicate;)~5Collector;|<T:~O>(~3Predicate<-TT;>;)~5Collector<TT;*~2Map<~1Boolean;~2List<TT;>;>;>;|',
'M|9|partitioningBy|(~3Predicate;~5Collector;)~5Collector;|<T:~OD:~OA:~O>(~3Predicate<-TT;>;~5Collector<-TT;TA;TD;>;)~5Collector<TT;*~2Map<~1Boolean;TD;>;>;|',
'M|9|collectingAndThen|(~5Collector;~3Function;)~5Collector;|<T:~OA:~OR:~ORR:~O>(~5Collector<TT;TA;TR;>;~3Function<TR;TRR;>;)~5Collector<TT;TA;TRR;>;|',
'M|9|toConcurrentMap|(~3Function;~3Function;)~5Collector;|<T:~OK:~OU:~O>(~3Function<-TT;+TK;>;~3Function<-TT;+TU;>;)~5Collector<TT;*~2concurrent/ConcurrentMap<TK;TU;>;>;|',
'M|9|toConcurrentMap|(~3Function;~3Function;~3BinaryOperator;~3Supplier;)~5Collector;|<T:~OK:~OU:~OM::~2concurrent/ConcurrentMap<TK;TU;>;>(~3Function<-TT;+TK;>;~3Function<-TT;+TU;>;~3BinaryOperator<TU;>;~3Supplier<TM;>;)~5Collector<TT;*TM;>;|',
'M|9|toConcurrentMap|(~3Function;~3Function;~3BinaryOperator;)~5Collector;|<T:~OK:~OU:~O>(~3Function<-TT;+TK;>;~3Function<-TT;+TU;>;~3BinaryOperator<TU;>;)~5Collector<TT;*~2concurrent/ConcurrentMap<TK;TU;>;>;|',
'M|9|toUnmodifiableList|()~5Collector;|<T:~O>()~5Collector<TT;*~2List<TT;>;>;|',
'M|9|toUnmodifiableSet|()~5Collector;|<T:~O>()~5Collector<TT;*~2Set<TT;>;>;|',
'M|9|flatMapping|(~3Function;~5Collector;)~5Collector;|<T:~OU:~OA:~OR:~O>(~3Function<-TT;+~5Stream<+TU;>;>;~5Collector<-TU;TA;TR;>;)~5Collector<TT;*TR;>;|',
'M|9|filtering|(~3Predicate;~5Collector;)~5Collector;|<T:~OA:~OR:~O>(~3Predicate<-TT;>;~5Collector<-TT;TA;TR;>;)~5Collector<TT;*TR;>;|',
'M|9|counting|()~5Collector;|<T:~O>()~5Collector<TT;*~1Long;>;|',
'M|9|summingInt|(~3ToIntFunction;)~5Collector;|<T:~O>(~3ToIntFunction<-TT;>;)~5Collector<TT;*~1Integer;>;|',
'M|9|summingDouble|(~3ToDoubleFunction;)~5Collector;|<T:~O>(~3ToDoubleFunction<-TT;>;)~5Collector<TT;*~1Double;>;|',
'M|9|averagingInt|(~3ToIntFunction;)~5Collector;|<T:~O>(~3ToIntFunction<-TT;>;)~5Collector<TT;*~1Double;>;|',
'M|9|averagingLong|(~3ToLongFunction;)~5Collector;|<T:~O>(~3ToLongFunction<-TT;>;)~5Collector<TT;*~1Double;>;|',
'M|9|averagingDouble|(~3ToDoubleFunction;)~5Collector;|<T:~O>(~3ToDoubleFunction<-TT;>;)~5Collector<TT;*~1Double;>;|',
'M|9|toUnmodifiableMap|(~3Function;~3Function;)~5Collector;|<T:~OK:~OU:~O>(~3Function<-TT;+TK;>;~3Function<-TT;+TU;>;)~5Collector<TT;*~2Map<TK;TU;>;>;|',
'M|9|toUnmodifiableMap|(~3Function;~3Function;~3BinaryOperator;)~5Collector;|<T:~OK:~OU:~O>(~3Function<-TT;+TK;>;~3Function<-TT;+TU;>;~3BinaryOperator<TU;>;)~5Collector<TT;*~2Map<TK;TU;>;>;|',
'M|9|summarizingInt|(~3ToIntFunction;)~5Collector;|<T:~O>(~3ToIntFunction<-TT;>;)~5Collector<TT;*~2IntSummaryStatistics;>;|',
'M|9|summarizingLong|(~3ToLongFunction;)~5Collector;|<T:~O>(~3ToLongFunction<-TT;>;)~5Collector<TT;*~2LongSummaryStatistics;>;|',
'M|9|summarizingDouble|(~3ToDoubleFunction;)~5Collector;|<T:~O>(~3ToDoubleFunction<-TT;>;)~5Collector<TT;*~2DoubleSummaryStatistics;>;|',
'M|9|teeing|(~5Collector;~5Collector;~3BiFunction;)~5Collector;|<T:~OR1:~OR2:~OR:~O>(~5Collector<-TT;*TR1;>;~5Collector<-TT;*TR2;>;~3BiFunction<-TR1;-TR2;TR;>;)~5Collector<TT;*TR;>;|',
'C|1537|java/util/stream/Collector|<T:~OA:~OR:~O>~O',
'M|137|of|(~3Supplier;~3BiConsumer;~3BinaryOperator;~3Function;[~5Collector$Characteristics;)~5Collector;|<T:~OA:~OR:~O>(~3Supplier<TA;>;~3BiConsumer<TA;TT;>;~3BinaryOperator<TA;>;~3Function<TA;TR;>;[~5Collector$Characteristics;)~5Collector<TT;TA;TR;>;|',
'M|137|of|(~3Supplier;~3BiConsumer;~3BinaryOperator;[~5Collector$Characteristics;)~5Collector;|<T:~OR:~O>(~3Supplier<TR;>;~3BiConsumer<TR;TT;>;~3BinaryOperator<TR;>;[~5Collector$Characteristics;)~5Collector<TT;TR;TR;>;|',
'M|1025|characteristics|()~2Set;|()~2Set<~5Collector$Characteristics;>;|',
'M|1025|combiner|()~3BinaryOperator;|()~3BinaryOperator<TA;>;|',
'M|1025|supplier|()~3Supplier;|()~3Supplier<TA;>;|',
'M|1025|accumulator|()~3BiConsumer;|()~3BiConsumer<TA;TT;>;|',
'M|1025|finisher|()~3Function;|()~3Function<TA;TR;>;|',
'C|1|java/util/concurrent/ConcurrentHashMap|<K:~OV:~O>~2AbstractMap<TK;TV;>;~2concurrent/ConcurrentMap<TK;TV;>;~4Serializable;',
'M|1|<init>|()V||',
'M|1|<init>|(~2Map;)V|(~2Map<+TK;+TV;>;)V|',
'M|1|<init>|(IF)V||',
'M|1|<init>|(IFI)V||',
'M|1|<init>|(I)V||',
'M|1|remove|(~O)~O|(~O)TV;|',
'M|1|remove|(~O~O)Z||',
'M|1|size|()I||',
'M|1|get|(~O)~O|(~O)TV;|',
'M|1|put|(~O~O)~O|(TK;TV;)TV;|',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|values|()~2Collection;|()~2Collection<TV;>;|',
'M|1|hashCode|()I||',
'M|1|clear|()V||',
'M|1|isEmpty|()Z||',
'M|1|replace|(~O~O)~O|(TK;TV;)TV;|',
'M|1|replace|(~O~O~O)Z|(TK;TV;TV;)Z|',
'M|1|replaceAll|(~3BiFunction;)V|(~3BiFunction<-TK;-TV;+TV;>;)V|',
'M|1|contains|(~O)Z||',
'M|1|elements|()~2Enumeration;|()~2Enumeration<TV;>;|',
'M|1|merge|(~O~O~3BiFunction;)~O|(TK;TV;~3BiFunction<-TV;-TV;+TV;>;)TV;|',
'M|1|entrySet|()~2Set;|()~2Set<~2Map$Entry<TK;TV;>;>;|',
'M|1|putAll|(~2Map;)V|(~2Map<+TK;+TV;>;)V|',
'M|1|putIfAbsent|(~O~O)~O|(TK;TV;)TV;|',
'M|1|compute|(~O~3BiFunction;)~O|(TK;~3BiFunction<-TK;-TV;+TV;>;)TV;|',
'M|1|forEach|(J~3BiConsumer;)V|(J~3BiConsumer<-TK;-TV;>;)V|',
'M|1|forEach|(J~3BiFunction;~3Consumer;)V|<U:~O>(J~3BiFunction<-TK;-TV;+TU;>;~3Consumer<-TU;>;)V|',
'M|1|forEach|(~3BiConsumer;)V|(~3BiConsumer<-TK;-TV;>;)V|',
'M|1|containsKey|(~O)Z||',
'M|1|computeIfAbsent|(~O~3Function;)~O|(TK;~3Function<-TK;+TV;>;)TV;|',
'M|1|keys|()~2Enumeration;|()~2Enumeration<TK;>;|',
'M|1|keySet|(~O)~2concurrent/ConcurrentHashMap$KeySetView;|(TV;)~2concurrent/ConcurrentHashMap$KeySetView<TK;TV;>;|',
'M|1|keySet|()~2concurrent/ConcurrentHashMap$KeySetView;|()~2concurrent/ConcurrentHashMap$KeySetView<TK;TV;>;|',
'M|1|containsValue|(~O)Z||',
'M|1|getOrDefault|(~O~O)~O|(~OTV;)TV;|',
'M|1|computeIfPresent|(~O~3BiFunction;)~O|(TK;~3BiFunction<-TK;-TV;+TV;>;)TV;|',
'M|1|mappingCount|()J||',
'M|9|newKeySet|(I)~2concurrent/ConcurrentHashMap$KeySetView;|<K:~O>(I)~2concurrent/ConcurrentHashMap$KeySetView<TK;~1Boolean;>;|',
'M|9|newKeySet|()~2concurrent/ConcurrentHashMap$KeySetView;|<K:~O>()~2concurrent/ConcurrentHashMap$KeySetView<TK;~1Boolean;>;|',
'M|1|search|(J~3BiFunction;)~O|<U:~O>(J~3BiFunction<-TK;-TV;+TU;>;)TU;|',
'M|1|reduce|(J~3BiFunction;~3BiFunction;)~O|<U:~O>(J~3BiFunction<-TK;-TV;+TU;>;~3BiFunction<-TU;-TU;+TU;>;)TU;|',
'M|1|reduceToDouble|(J~3ToDoubleBiFunction;D~3DoubleBinaryOperator;)D|(J~3ToDoubleBiFunction<-TK;-TV;>;D~3DoubleBinaryOperator;)D|',
'M|1|reduceToLong|(J~3ToLongBiFunction;J~3LongBinaryOperator;)J|(J~3ToLongBiFunction<-TK;-TV;>;J~3LongBinaryOperator;)J|',
'M|1|reduceToInt|(J~3ToIntBiFunction;I~3IntBinaryOperator;)I|(J~3ToIntBiFunction<-TK;-TV;>;I~3IntBinaryOperator;)I|',
'M|1|forEachKey|(J~3Consumer;)V|(J~3Consumer<-TK;>;)V|',
'M|1|forEachKey|(J~3Function;~3Consumer;)V|<U:~O>(J~3Function<-TK;+TU;>;~3Consumer<-TU;>;)V|',
'M|1|searchKeys|(J~3Function;)~O|<U:~O>(J~3Function<-TK;+TU;>;)TU;|',
'M|1|reduceKeys|(J~3BiFunction;)~O|(J~3BiFunction<-TK;-TK;+TK;>;)TK;|',
'M|1|reduceKeys|(J~3Function;~3BiFunction;)~O|<U:~O>(J~3Function<-TK;+TU;>;~3BiFunction<-TU;-TU;+TU;>;)TU;|',
'M|1|reduceKeysToDouble|(J~3ToDoubleFunction;D~3DoubleBinaryOperator;)D|(J~3ToDoubleFunction<-TK;>;D~3DoubleBinaryOperator;)D|',
'M|1|reduceKeysToLong|(J~3ToLongFunction;J~3LongBinaryOperator;)J|(J~3ToLongFunction<-TK;>;J~3LongBinaryOperator;)J|',
'M|1|reduceKeysToInt|(J~3ToIntFunction;I~3IntBinaryOperator;)I|(J~3ToIntFunction<-TK;>;I~3IntBinaryOperator;)I|',
'M|1|forEachValue|(J~3Function;~3Consumer;)V|<U:~O>(J~3Function<-TV;+TU;>;~3Consumer<-TU;>;)V|',
'M|1|forEachValue|(J~3Consumer;)V|(J~3Consumer<-TV;>;)V|',
'M|1|searchValues|(J~3Function;)~O|<U:~O>(J~3Function<-TV;+TU;>;)TU;|',
'M|1|reduceValues|(J~3BiFunction;)~O|(J~3BiFunction<-TV;-TV;+TV;>;)TV;|',
'M|1|reduceValues|(J~3Function;~3BiFunction;)~O|<U:~O>(J~3Function<-TV;+TU;>;~3BiFunction<-TU;-TU;+TU;>;)TU;|',
'M|1|reduceValuesToDouble|(J~3ToDoubleFunction;D~3DoubleBinaryOperator;)D|(J~3ToDoubleFunction<-TV;>;D~3DoubleBinaryOperator;)D|',
'M|1|reduceValuesToLong|(J~3ToLongFunction;J~3LongBinaryOperator;)J|(J~3ToLongFunction<-TV;>;J~3LongBinaryOperator;)J|',
'M|1|reduceValuesToInt|(J~3ToIntFunction;I~3IntBinaryOperator;)I|(J~3ToIntFunction<-TV;>;I~3IntBinaryOperator;)I|',
'M|1|forEachEntry|(J~3Consumer;)V|(J~3Consumer<-~2Map$Entry<TK;TV;>;>;)V|',
'M|1|forEachEntry|(J~3Function;~3Consumer;)V|<U:~O>(J~3Function<~2Map$Entry<TK;TV;>;+TU;>;~3Consumer<-TU;>;)V|',
'M|1|searchEntries|(J~3Function;)~O|<U:~O>(J~3Function<~2Map$Entry<TK;TV;>;+TU;>;)TU;|',
'M|1|reduceEntries|(J~3BiFunction;)~2Map$Entry;|(J~3BiFunction<~2Map$Entry<TK;TV;>;~2Map$Entry<TK;TV;>;+~2Map$Entry<TK;TV;>;>;)~2Map$Entry<TK;TV;>;|',
'M|1|reduceEntries|(J~3Function;~3BiFunction;)~O|<U:~O>(J~3Function<~2Map$Entry<TK;TV;>;+TU;>;~3BiFunction<-TU;-TU;+TU;>;)TU;|',
'M|1|reduceEntriesToDouble|(J~3ToDoubleFunction;D~3DoubleBinaryOperator;)D|(J~3ToDoubleFunction<~2Map$Entry<TK;TV;>;>;D~3DoubleBinaryOperator;)D|',
'M|1|reduceEntriesToLong|(J~3ToLongFunction;J~3LongBinaryOperator;)J|(J~3ToLongFunction<~2Map$Entry<TK;TV;>;>;J~3LongBinaryOperator;)J|',
'M|1|reduceEntriesToInt|(J~3ToIntFunction;I~3IntBinaryOperator;)I|(J~3ToIntFunction<~2Map$Entry<TK;TV;>;>;I~3IntBinaryOperator;)I|',
'C|1537|java/util/concurrent/ConcurrentMap|<K:~OV:~O>~O~2Map<TK;TV;>;',
'M|1025|remove|(~O~O)Z||',
'M|1025|replace|(~O~O~O)Z|(TK;TV;TV;)Z|',
'M|1025|replace|(~O~O)~O|(TK;TV;)TV;|',
'M|65537|replaceAll|(~3BiFunction;)V|(~3BiFunction<-TK;-TV;+TV;>;)V|',
'M|65537|merge|(~O~O~3BiFunction;)~O|(TK;TV;~3BiFunction<-TV;-TV;+TV;>;)TV;|',
'M|1025|putIfAbsent|(~O~O)~O|(TK;TV;)TV;|',
'M|65537|compute|(~O~3BiFunction;)~O|(TK;~3BiFunction<-TK;-TV;+TV;>;)TV;|',
'M|65537|forEach|(~3BiConsumer;)V|(~3BiConsumer<-TK;-TV;>;)V|',
'M|65537|computeIfAbsent|(~O~3Function;)~O|(TK;~3Function<-TK;+TV;>;)TV;|',
'M|65537|getOrDefault|(~O~O)~O|(~OTV;)TV;|',
'M|65537|computeIfPresent|(~O~3BiFunction;)~O|(TK;~3BiFunction<-TK;-TV;+TV;>;)TV;|',
'C|1|java/util/concurrent/atomic/AtomicInteger|~1Number;~4Serializable;',
'M|1|<init>|(I)V||',
'M|1|<init>|()V||',
'M|17|get|()I||',
'M|1|toString|()~S||',
'M|1|intValue|()I||',
'M|1|longValue|()J||',
'M|1|floatValue|()F||',
'M|1|doubleValue|()D||',
'M|17|set|(I)V||',
'M|17|getOpaque|()I||',
'M|17|setOpaque|(I)V||',
'M|17|getAcquire|()I||',
'M|17|setRelease|(I)V||',
'M|17|compareAndSet|(II)Z||',
'M|17|compareAndExchange|(II)I||',
'M|17|compareAndExchangeAcquire|(II)I||',
'M|17|compareAndExchangeRelease|(II)I||',
'M|17|weakCompareAndSetPlain|(II)Z||',
'M|17|weakCompareAndSet|(II)Z||',
'M|17|weakCompareAndSetAcquire|(II)Z||',
'M|17|weakCompareAndSetRelease|(II)Z||',
'M|17|getAndSet|(I)I||',
'M|17|getAndAdd|(I)I||',
'M|17|lazySet|(I)V||',
'M|17|incrementAndGet|()I||',
'M|17|weakCompareAndSetVolatile|(II)Z||',
'M|17|getAndIncrement|()I||',
'M|17|getAndDecrement|()I||',
'M|17|decrementAndGet|()I||',
'M|17|addAndGet|(I)I||',
'M|17|getAndUpdate|(~3IntUnaryOperator;)I||',
'M|17|updateAndGet|(~3IntUnaryOperator;)I||',
'M|17|getAndAccumulate|(I~3IntBinaryOperator;)I||',
'M|17|accumulateAndGet|(I~3IntBinaryOperator;)I||',
'M|17|getPlain|()I||',
'M|17|setPlain|(I)V||',
'C|1|java/util/concurrent/atomic/AtomicLong|~1Number;~4Serializable;',
'M|1|<init>|()V||',
'M|1|<init>|(J)V||',
'M|17|get|()J||',
'M|1|toString|()~S||',
'M|1|intValue|()I||',
'M|1|longValue|()J||',
'M|1|floatValue|()F||',
'M|1|doubleValue|()D||',
'M|17|set|(J)V||',
'M|17|getOpaque|()J||',
'M|17|setOpaque|(J)V||',
'M|17|getAcquire|()J||',
'M|17|setRelease|(J)V||',
'M|17|compareAndSet|(JJ)Z||',
'M|17|compareAndExchange|(JJ)J||',
'M|17|compareAndExchangeAcquire|(JJ)J||',
'M|17|compareAndExchangeRelease|(JJ)J||',
'M|17|weakCompareAndSetPlain|(JJ)Z||',
'M|17|weakCompareAndSet|(JJ)Z||',
'M|17|weakCompareAndSetAcquire|(JJ)Z||',
'M|17|weakCompareAndSetRelease|(JJ)Z||',
'M|17|getAndSet|(J)J||',
'M|17|getAndAdd|(J)J||',
'M|17|lazySet|(J)V||',
'M|17|incrementAndGet|()J||',
'M|17|weakCompareAndSetVolatile|(JJ)Z||',
'M|17|getAndIncrement|()J||',
'M|17|getAndDecrement|()J||',
'M|17|decrementAndGet|()J||',
'M|17|addAndGet|(J)J||',
'M|17|getAndUpdate|(~3LongUnaryOperator;)J||',
'M|17|updateAndGet|(~3LongUnaryOperator;)J||',
'M|17|getAndAccumulate|(J~3LongBinaryOperator;)J||',
'M|17|accumulateAndGet|(J~3LongBinaryOperator;)J||',
'M|17|getPlain|()J||',
'M|17|setPlain|(J)V||',
'C|1|java/util/concurrent/atomic/AtomicBoolean|~O~4Serializable;',
'M|1|<init>|(Z)V||',
'M|1|<init>|()V||',
'M|17|get|()Z||',
'M|1|toString|()~S||',
'M|17|set|(Z)V||',
'M|17|getOpaque|()Z||',
'M|17|setOpaque|(Z)V||',
'M|17|getAcquire|()Z||',
'M|17|setRelease|(Z)V||',
'M|17|compareAndSet|(ZZ)Z||',
'M|17|compareAndExchange|(ZZ)Z||',
'M|17|compareAndExchangeAcquire|(ZZ)Z||',
'M|17|compareAndExchangeRelease|(ZZ)Z||',
'M|1|weakCompareAndSetPlain|(ZZ)Z||',
'M|1|weakCompareAndSet|(ZZ)Z||',
'M|17|weakCompareAndSetAcquire|(ZZ)Z||',
'M|17|weakCompareAndSetRelease|(ZZ)Z||',
'M|17|getAndSet|(Z)Z||',
'M|17|lazySet|(Z)V||',
'M|17|weakCompareAndSetVolatile|(ZZ)Z||',
'M|17|getPlain|()Z||',
'M|17|setPlain|(Z)V||',
'C|1|java/util/concurrent/atomic/AtomicReference|<V:~O>~O~4Serializable;',
'M|1|<init>|(~O)V|(TV;)V|',
'M|1|<init>|()V||',
'M|17|get|()~O|()TV;|',
'M|1|toString|()~S||',
'M|17|set|(~O)V|(TV;)V|',
'M|17|getOpaque|()~O|()TV;|',
'M|17|setOpaque|(~O)V|(TV;)V|',
'M|17|getAcquire|()~O|()TV;|',
'M|17|setRelease|(~O)V|(TV;)V|',
'M|17|compareAndSet|(~O~O)Z|(TV;TV;)Z|',
'M|17|compareAndExchange|(~O~O)~O|(TV;TV;)TV;|',
'M|17|compareAndExchangeAcquire|(~O~O)~O|(TV;TV;)TV;|',
'M|17|compareAndExchangeRelease|(~O~O)~O|(TV;TV;)TV;|',
'M|17|weakCompareAndSetPlain|(~O~O)Z|(TV;TV;)Z|',
'M|17|weakCompareAndSet|(~O~O)Z|(TV;TV;)Z|',
'M|17|weakCompareAndSetAcquire|(~O~O)Z|(TV;TV;)Z|',
'M|17|weakCompareAndSetRelease|(~O~O)Z|(TV;TV;)Z|',
'M|17|getAndSet|(~O)~O|(TV;)TV;|',
'M|17|lazySet|(~O)V|(TV;)V|',
'M|17|weakCompareAndSetVolatile|(~O~O)Z|(TV;TV;)Z|',
'M|17|getAndUpdate|(~3UnaryOperator;)~O|(~3UnaryOperator<TV;>;)TV;|',
'M|17|updateAndGet|(~3UnaryOperator;)~O|(~3UnaryOperator<TV;>;)TV;|',
'M|17|getAndAccumulate|(~O~3BinaryOperator;)~O|(TV;~3BinaryOperator<TV;>;)TV;|',
'M|17|accumulateAndGet|(~O~3BinaryOperator;)~O|(TV;~3BinaryOperator<TV;>;)TV;|',
'M|17|getPlain|()~O|()TV;|',
'M|17|setPlain|(~O)V|(TV;)V|',
'C|16401|java/util/concurrent/TimeUnit|~1Enum<~2concurrent/TimeUnit;>;',
'F|16409|NANOSECONDS|~2concurrent/TimeUnit;||',
'F|16409|MICROSECONDS|~2concurrent/TimeUnit;||',
'F|16409|MILLISECONDS|~2concurrent/TimeUnit;||',
'F|16409|SECONDS|~2concurrent/TimeUnit;||',
'F|16409|MINUTES|~2concurrent/TimeUnit;||',
'F|16409|HOURS|~2concurrent/TimeUnit;||',
'F|16409|DAYS|~2concurrent/TimeUnit;||',
'M|1|convert|(Ljava/time/Duration;)J||',
'M|1|convert|(J~2concurrent/TimeUnit;)J||',
'M|9|of|(Ljava/time/temporal/ChronoUnit;)~2concurrent/TimeUnit;||',
'M|1|toNanos|(J)J||',
'M|1|toMillis|(J)J||',
'M|1|sleep|(J)V||java/lang/InterruptedException',
'M|1|toDays|(J)J||',
'M|1|toSeconds|(J)J||',
'M|1|toHours|(J)J||',
'M|1|toMinutes|(J)J||',
'M|1|toMicros|(J)J||',
'M|1|timedWait|(~OJ)V||java/lang/InterruptedException',
'M|1|timedJoin|(~1Thread;J)V||java/lang/InterruptedException',
'M|1|toChronoUnit|()Ljava/time/temporal/ChronoUnit;||',
'C|1537|java/util/concurrent/ExecutorService|~O~2concurrent/Executor;~1AutoCloseable;',
'M|1025|shutdown|()V||',
'M|1025|isTerminated|()Z||',
'M|65537|close|()V||',
'M|1025|isShutdown|()Z||',
'M|1025|submit|(~1Runnable;~O)~2concurrent/Future;|<T:~O>(~1Runnable;TT;)~2concurrent/Future<TT;>;|',
'M|1025|submit|(~1Runnable;)~2concurrent/Future;|(~1Runnable;)~2concurrent/Future<*>;|',
'M|1025|submit|(~2concurrent/Callable;)~2concurrent/Future;|<T:~O>(~2concurrent/Callable<TT;>;)~2concurrent/Future<TT;>;|',
'M|1025|invokeAny|(~2Collection;)~O|<T:~O>(~2Collection<+~2concurrent/Callable<TT;>;>;)TT;|java/lang/InterruptedException,java/util/concurrent/ExecutionException',
'M|1025|invokeAny|(~2Collection;J~2concurrent/TimeUnit;)~O|<T:~O>(~2Collection<+~2concurrent/Callable<TT;>;>;J~2concurrent/TimeUnit;)TT;|java/lang/InterruptedException,java/util/concurrent/ExecutionException,java/util/concurrent/TimeoutException',
'M|1025|invokeAll|(~2Collection;)~2List;|<T:~O>(~2Collection<+~2concurrent/Callable<TT;>;>;)~2List<~2concurrent/Future<TT;>;>;|java/lang/InterruptedException',
'M|1025|invokeAll|(~2Collection;J~2concurrent/TimeUnit;)~2List;|<T:~O>(~2Collection<+~2concurrent/Callable<TT;>;>;J~2concurrent/TimeUnit;)~2List<~2concurrent/Future<TT;>;>;|java/lang/InterruptedException',
'M|1025|awaitTermination|(J~2concurrent/TimeUnit;)Z||java/lang/InterruptedException',
'M|1025|shutdownNow|()~2List;|()~2List<~1Runnable;>;|',
'C|1537|java/util/concurrent/Executor|~O',
'M|1025|execute|(~1Runnable;)V||',
'C|1|java/util/concurrent/Executors|~O',
'M|9|newScheduledThreadPool|(I~2concurrent/ThreadFactory;)~2concurrent/ScheduledExecutorService;||',
'M|9|newScheduledThreadPool|(I)~2concurrent/ScheduledExecutorService;||',
'M|9|callable|(~1Runnable;~O)~2concurrent/Callable;|<T:~O>(~1Runnable;TT;)~2concurrent/Callable<TT;>;|',
'M|9|callable|(~1Runnable;)~2concurrent/Callable;|(~1Runnable;)~2concurrent/Callable<~O>;|',
'M|9|callable|(Ljava/security/PrivilegedAction;)~2concurrent/Callable;|(Ljava/security/PrivilegedAction<*>;)~2concurrent/Callable<~O>;|',
'M|9|callable|(Ljava/security/PrivilegedExceptionAction;)~2concurrent/Callable;|(Ljava/security/PrivilegedExceptionAction<*>;)~2concurrent/Callable<~O>;|',
'M|9|defaultThreadFactory|()~2concurrent/ThreadFactory;||',
'M|9|newSingleThreadExecutor|(~2concurrent/ThreadFactory;)~2concurrent/ExecutorService;||',
'M|9|newSingleThreadExecutor|()~2concurrent/ExecutorService;||',
'M|9|newThreadPerTaskExecutor|(~2concurrent/ThreadFactory;)~2concurrent/ExecutorService;||',
'M|9|newFixedThreadPool|(I)~2concurrent/ExecutorService;||',
'M|9|newFixedThreadPool|(I~2concurrent/ThreadFactory;)~2concurrent/ExecutorService;||',
'M|9|newWorkStealingPool|()~2concurrent/ExecutorService;||',
'M|9|newWorkStealingPool|(I)~2concurrent/ExecutorService;||',
'M|9|newCachedThreadPool|(~2concurrent/ThreadFactory;)~2concurrent/ExecutorService;||',
'M|9|newCachedThreadPool|()~2concurrent/ExecutorService;||',
'M|9|newVirtualThreadPerTaskExecutor|()~2concurrent/ExecutorService;||',
'M|9|newSingleThreadScheduledExecutor|(~2concurrent/ThreadFactory;)~2concurrent/ScheduledExecutorService;||',
'M|9|newSingleThreadScheduledExecutor|()~2concurrent/ScheduledExecutorService;||',
'M|9|unconfigurableExecutorService|(~2concurrent/ExecutorService;)~2concurrent/ExecutorService;||',
'M|9|unconfigurableScheduledExecutorService|(~2concurrent/ScheduledExecutorService;)~2concurrent/ScheduledExecutorService;||',
'M|9|privilegedThreadFactory|()~2concurrent/ThreadFactory;||',
'M|9|privilegedCallable|(~2concurrent/Callable;)~2concurrent/Callable;|<T:~O>(~2concurrent/Callable<TT;>;)~2concurrent/Callable<TT;>;|',
'M|9|privilegedCallableUsingCurrentClassLoader|(~2concurrent/Callable;)~2concurrent/Callable;|<T:~O>(~2concurrent/Callable<TT;>;)~2concurrent/Callable<TT;>;|',
'C|1537|java/util/concurrent/Callable|<V:~O>~O',
'M|1025|call|()~O|()TV;|java/lang/Exception',
'C|1537|java/util/concurrent/Future|<V:~O>~O',
'M|1025|get|(J~2concurrent/TimeUnit;)~O|(J~2concurrent/TimeUnit;)TV;|java/lang/InterruptedException,java/util/concurrent/ExecutionException,java/util/concurrent/TimeoutException',
'M|1025|get|()~O|()TV;|java/lang/InterruptedException,java/util/concurrent/ExecutionException',
'M|65537|state|()~2concurrent/Future$State;||',
'M|1025|isDone|()Z||',
'M|1025|cancel|(Z)Z||',
'M|1025|isCancelled|()Z||',
'M|65537|resultNow|()~O|()TV;|',
'M|65537|exceptionNow|()~1Throwable;||',
'C|1|java/util/concurrent/CompletableFuture|<T:~O>~O~2concurrent/Future<TT;>;~2concurrent/CompletionStage<TT;>;',
'M|1|<init>|()V||',
'M|1|get|(J~2concurrent/TimeUnit;)~O|(J~2concurrent/TimeUnit;)TT;|java/lang/InterruptedException,java/util/concurrent/ExecutionException,java/util/concurrent/TimeoutException',
'M|1|get|()~O|()TT;|java/lang/InterruptedException,java/util/concurrent/ExecutionException',
'M|1|toString|()~S||',
'M|1|join|()~O|()TT;|',
'M|1|state|()~2concurrent/Future$State;||',
'M|1|isDone|()Z||',
'M|1|cancel|(Z)Z||',
'M|1|copy|()~2concurrent/CompletableFuture;|()~2concurrent/CompletableFuture<TT;>;|',
'M|1|handle|(~3BiFunction;)~2concurrent/CompletableFuture;|<U:~O>(~3BiFunction<-TT;~1Throwable;+TU;>;)~2concurrent/CompletableFuture<TU;>;|',
'M|1|complete|(~O)Z|(TT;)Z|',
'M|137|allOf|([~2concurrent/CompletableFuture;)~2concurrent/CompletableFuture;|([~2concurrent/CompletableFuture<*>;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|isCancelled|()Z||',
'M|1|resultNow|()~O|()TT;|',
'M|1|exceptionNow|()~1Throwable;||',
'M|1|completeExceptionally|(~1Throwable;)Z||',
'M|9|supplyAsync|(~3Supplier;)~2concurrent/CompletableFuture;|<U:~O>(~3Supplier<TU;>;)~2concurrent/CompletableFuture<TU;>;|',
'M|9|supplyAsync|(~3Supplier;~2concurrent/Executor;)~2concurrent/CompletableFuture;|<U:~O>(~3Supplier<TU;>;~2concurrent/Executor;)~2concurrent/CompletableFuture<TU;>;|',
'M|1|newIncompleteFuture|()~2concurrent/CompletableFuture;|<U:~O>()~2concurrent/CompletableFuture<TU;>;|',
'M|1|toCompletableFuture|()~2concurrent/CompletableFuture;|()~2concurrent/CompletableFuture<TT;>;|',
'M|1|defaultExecutor|()~2concurrent/Executor;||',
'M|1|completeAsync|(~3Supplier;)~2concurrent/CompletableFuture;|(~3Supplier<+TT;>;)~2concurrent/CompletableFuture<TT;>;|',
'M|1|completeAsync|(~3Supplier;~2concurrent/Executor;)~2concurrent/CompletableFuture;|(~3Supplier<+TT;>;~2concurrent/Executor;)~2concurrent/CompletableFuture<TT;>;|',
'M|1|whenComplete|(~3BiConsumer;)~2concurrent/CompletableFuture;|(~3BiConsumer<-TT;-~1Throwable;>;)~2concurrent/CompletableFuture<TT;>;|',
'M|1|exceptionallyComposeAsync|(~3Function;~2concurrent/Executor;)~2concurrent/CompletableFuture;|(~3Function<~1Throwable;+~2concurrent/CompletionStage<TT;>;>;~2concurrent/Executor;)~2concurrent/CompletableFuture<TT;>;|',
'M|1|exceptionallyComposeAsync|(~3Function;)~2concurrent/CompletableFuture;|(~3Function<~1Throwable;+~2concurrent/CompletionStage<TT;>;>;)~2concurrent/CompletableFuture<TT;>;|',
'M|1|exceptionallyCompose|(~3Function;)~2concurrent/CompletableFuture;|(~3Function<~1Throwable;+~2concurrent/CompletionStage<TT;>;>;)~2concurrent/CompletableFuture<TT;>;|',
'M|1|exceptionallyAsync|(~3Function;)~2concurrent/CompletableFuture;|(~3Function<~1Throwable;+TT;>;)~2concurrent/CompletableFuture<TT;>;|',
'M|1|exceptionallyAsync|(~3Function;~2concurrent/Executor;)~2concurrent/CompletableFuture;|(~3Function<~1Throwable;+TT;>;~2concurrent/Executor;)~2concurrent/CompletableFuture<TT;>;|',
'M|1|exceptionally|(~3Function;)~2concurrent/CompletableFuture;|(~3Function<~1Throwable;+TT;>;)~2concurrent/CompletableFuture<TT;>;|',
'M|1|whenCompleteAsync|(~3BiConsumer;~2concurrent/Executor;)~2concurrent/CompletableFuture;|(~3BiConsumer<-TT;-~1Throwable;>;~2concurrent/Executor;)~2concurrent/CompletableFuture<TT;>;|',
'M|1|whenCompleteAsync|(~3BiConsumer;)~2concurrent/CompletableFuture;|(~3BiConsumer<-TT;-~1Throwable;>;)~2concurrent/CompletableFuture<TT;>;|',
'M|1|handleAsync|(~3BiFunction;~2concurrent/Executor;)~2concurrent/CompletableFuture;|<U:~O>(~3BiFunction<-TT;~1Throwable;+TU;>;~2concurrent/Executor;)~2concurrent/CompletableFuture<TU;>;|',
'M|1|handleAsync|(~3BiFunction;)~2concurrent/CompletableFuture;|<U:~O>(~3BiFunction<-TT;~1Throwable;+TU;>;)~2concurrent/CompletableFuture<TU;>;|',
'M|1|thenComposeAsync|(~3Function;)~2concurrent/CompletableFuture;|<U:~O>(~3Function<-TT;+~2concurrent/CompletionStage<TU;>;>;)~2concurrent/CompletableFuture<TU;>;|',
'M|1|thenComposeAsync|(~3Function;~2concurrent/Executor;)~2concurrent/CompletableFuture;|<U:~O>(~3Function<-TT;+~2concurrent/CompletionStage<TU;>;>;~2concurrent/Executor;)~2concurrent/CompletableFuture<TU;>;|',
'M|1|thenCompose|(~3Function;)~2concurrent/CompletableFuture;|<U:~O>(~3Function<-TT;+~2concurrent/CompletionStage<TU;>;>;)~2concurrent/CompletableFuture<TU;>;|',
'M|1|runAfterEitherAsync|(~2concurrent/CompletionStage;~1Runnable;)~2concurrent/CompletableFuture;|(~2concurrent/CompletionStage<*>;~1Runnable;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|runAfterEitherAsync|(~2concurrent/CompletionStage;~1Runnable;~2concurrent/Executor;)~2concurrent/CompletableFuture;|(~2concurrent/CompletionStage<*>;~1Runnable;~2concurrent/Executor;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|runAfterEither|(~2concurrent/CompletionStage;~1Runnable;)~2concurrent/CompletableFuture;|(~2concurrent/CompletionStage<*>;~1Runnable;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|acceptEitherAsync|(~2concurrent/CompletionStage;~3Consumer;~2concurrent/Executor;)~2concurrent/CompletableFuture;|(~2concurrent/CompletionStage<+TT;>;~3Consumer<-TT;>;~2concurrent/Executor;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|acceptEitherAsync|(~2concurrent/CompletionStage;~3Consumer;)~2concurrent/CompletableFuture;|(~2concurrent/CompletionStage<+TT;>;~3Consumer<-TT;>;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|acceptEither|(~2concurrent/CompletionStage;~3Consumer;)~2concurrent/CompletableFuture;|(~2concurrent/CompletionStage<+TT;>;~3Consumer<-TT;>;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|applyToEitherAsync|(~2concurrent/CompletionStage;~3Function;~2concurrent/Executor;)~2concurrent/CompletableFuture;|<U:~O>(~2concurrent/CompletionStage<+TT;>;~3Function<-TT;TU;>;~2concurrent/Executor;)~2concurrent/CompletableFuture<TU;>;|',
'M|1|applyToEitherAsync|(~2concurrent/CompletionStage;~3Function;)~2concurrent/CompletableFuture;|<U:~O>(~2concurrent/CompletionStage<+TT;>;~3Function<-TT;TU;>;)~2concurrent/CompletableFuture<TU;>;|',
'M|1|applyToEither|(~2concurrent/CompletionStage;~3Function;)~2concurrent/CompletableFuture;|<U:~O>(~2concurrent/CompletionStage<+TT;>;~3Function<-TT;TU;>;)~2concurrent/CompletableFuture<TU;>;|',
'M|1|runAfterBothAsync|(~2concurrent/CompletionStage;~1Runnable;)~2concurrent/CompletableFuture;|(~2concurrent/CompletionStage<*>;~1Runnable;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|runAfterBothAsync|(~2concurrent/CompletionStage;~1Runnable;~2concurrent/Executor;)~2concurrent/CompletableFuture;|(~2concurrent/CompletionStage<*>;~1Runnable;~2concurrent/Executor;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|runAfterBoth|(~2concurrent/CompletionStage;~1Runnable;)~2concurrent/CompletableFuture;|(~2concurrent/CompletionStage<*>;~1Runnable;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|thenAcceptBothAsync|(~2concurrent/CompletionStage;~3BiConsumer;)~2concurrent/CompletableFuture;|<U:~O>(~2concurrent/CompletionStage<+TU;>;~3BiConsumer<-TT;-TU;>;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|thenAcceptBothAsync|(~2concurrent/CompletionStage;~3BiConsumer;~2concurrent/Executor;)~2concurrent/CompletableFuture;|<U:~O>(~2concurrent/CompletionStage<+TU;>;~3BiConsumer<-TT;-TU;>;~2concurrent/Executor;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|thenAcceptBoth|(~2concurrent/CompletionStage;~3BiConsumer;)~2concurrent/CompletableFuture;|<U:~O>(~2concurrent/CompletionStage<+TU;>;~3BiConsumer<-TT;-TU;>;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|thenCombineAsync|(~2concurrent/CompletionStage;~3BiFunction;)~2concurrent/CompletableFuture;|<U:~OV:~O>(~2concurrent/CompletionStage<+TU;>;~3BiFunction<-TT;-TU;+TV;>;)~2concurrent/CompletableFuture<TV;>;|',
'M|1|thenCombineAsync|(~2concurrent/CompletionStage;~3BiFunction;~2concurrent/Executor;)~2concurrent/CompletableFuture;|<U:~OV:~O>(~2concurrent/CompletionStage<+TU;>;~3BiFunction<-TT;-TU;+TV;>;~2concurrent/Executor;)~2concurrent/CompletableFuture<TV;>;|',
'M|1|thenCombine|(~2concurrent/CompletionStage;~3BiFunction;)~2concurrent/CompletableFuture;|<U:~OV:~O>(~2concurrent/CompletionStage<+TU;>;~3BiFunction<-TT;-TU;+TV;>;)~2concurrent/CompletableFuture<TV;>;|',
'M|1|thenRunAsync|(~1Runnable;)~2concurrent/CompletableFuture;|(~1Runnable;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|thenRunAsync|(~1Runnable;~2concurrent/Executor;)~2concurrent/CompletableFuture;|(~1Runnable;~2concurrent/Executor;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|thenRun|(~1Runnable;)~2concurrent/CompletableFuture;|(~1Runnable;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|thenAcceptAsync|(~3Consumer;)~2concurrent/CompletableFuture;|(~3Consumer<-TT;>;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|thenAcceptAsync|(~3Consumer;~2concurrent/Executor;)~2concurrent/CompletableFuture;|(~3Consumer<-TT;>;~2concurrent/Executor;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|thenAccept|(~3Consumer;)~2concurrent/CompletableFuture;|(~3Consumer<-TT;>;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|1|thenApplyAsync|(~3Function;~2concurrent/Executor;)~2concurrent/CompletableFuture;|<U:~O>(~3Function<-TT;+TU;>;~2concurrent/Executor;)~2concurrent/CompletableFuture<TU;>;|',
'M|1|thenApplyAsync|(~3Function;)~2concurrent/CompletableFuture;|<U:~O>(~3Function<-TT;+TU;>;)~2concurrent/CompletableFuture<TU;>;|',
'M|1|thenApply|(~3Function;)~2concurrent/CompletableFuture;|<U:~O>(~3Function<-TT;+TU;>;)~2concurrent/CompletableFuture<TU;>;|',
'M|9|runAsync|(~1Runnable;~2concurrent/Executor;)~2concurrent/CompletableFuture;|(~1Runnable;~2concurrent/Executor;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|9|runAsync|(~1Runnable;)~2concurrent/CompletableFuture;|(~1Runnable;)~2concurrent/CompletableFuture<~1Void;>;|',
'M|9|completedFuture|(~O)~2concurrent/CompletableFuture;|<U:~O>(TU;)~2concurrent/CompletableFuture<TU;>;|',
'M|1|getNow|(~O)~O|(TT;)TT;|',
'M|137|anyOf|([~2concurrent/CompletableFuture;)~2concurrent/CompletableFuture;|([~2concurrent/CompletableFuture<*>;)~2concurrent/CompletableFuture<~O>;|',
'M|1|isCompletedExceptionally|()Z||',
'M|1|obtrudeValue|(~O)V|(TT;)V|',
'M|1|obtrudeException|(~1Throwable;)V||',
'M|1|getNumberOfDependents|()I||',
'M|1|minimalCompletionStage|()~2concurrent/CompletionStage;|()~2concurrent/CompletionStage<TT;>;|',
'M|1|orTimeout|(J~2concurrent/TimeUnit;)~2concurrent/CompletableFuture;|(J~2concurrent/TimeUnit;)~2concurrent/CompletableFuture<TT;>;|',
'M|1|completeOnTimeout|(~OJ~2concurrent/TimeUnit;)~2concurrent/CompletableFuture;|(TT;J~2concurrent/TimeUnit;)~2concurrent/CompletableFuture<TT;>;|',
'M|9|delayedExecutor|(J~2concurrent/TimeUnit;~2concurrent/Executor;)~2concurrent/Executor;||',
'M|9|delayedExecutor|(J~2concurrent/TimeUnit;)~2concurrent/Executor;||',
'M|9|completedStage|(~O)~2concurrent/CompletionStage;|<U:~O>(TU;)~2concurrent/CompletionStage<TU;>;|',
'M|9|failedFuture|(~1Throwable;)~2concurrent/CompletableFuture;|<U:~O>(~1Throwable;)~2concurrent/CompletableFuture<TU;>;|',
'M|9|failedStage|(~1Throwable;)~2concurrent/CompletionStage;|<U:~O>(~1Throwable;)~2concurrent/CompletionStage<TU;>;|',
'C|1|java/util/concurrent/CountDownLatch|~O',
'M|1|<init>|(I)V||',
'M|1|toString|()~S||',
'M|1|getCount|()J||',
'M|1|countDown|()V||',
'M|1|await|()V||java/lang/InterruptedException',
'M|1|await|(J~2concurrent/TimeUnit;)Z||java/lang/InterruptedException',
'C|1537|java/util/concurrent/locks/Lock|~O',
'M|1025|lock|()V||',
'M|1025|unlock|()V||',
'M|1025|newCondition|()~2concurrent/locks/Condition;||',
'M|1025|lockInterruptibly|()V||java/lang/InterruptedException',
'M|1025|tryLock|()Z||',
'M|1025|tryLock|(J~2concurrent/TimeUnit;)Z||java/lang/InterruptedException',
'C|1|java/util/concurrent/locks/ReentrantLock|~O~2concurrent/locks/Lock;~4Serializable;',
'M|1|<init>|()V||',
'M|1|<init>|(Z)V||',
'M|1|lock|()V||',
'M|1|toString|()~S||',
'M|1|unlock|()V||',
'M|1|newCondition|()~2concurrent/locks/Condition;||',
'M|1|lockInterruptibly|()V||java/lang/InterruptedException',
'M|1|tryLock|()Z||',
'M|1|tryLock|(J~2concurrent/TimeUnit;)Z||java/lang/InterruptedException',
'M|1|getHoldCount|()I||',
'M|1|isLocked|()Z||',
'M|4|getOwner|()~1Thread;||',
'M|17|hasQueuedThreads|()Z||',
'M|17|getQueueLength|()I||',
'M|4|getQueuedThreads|()~2Collection;|()~2Collection<~1Thread;>;|',
'M|1|hasWaiters|(~2concurrent/locks/Condition;)Z||',
'M|1|getWaitQueueLength|(~2concurrent/locks/Condition;)I||',
'M|4|getWaitingThreads|(~2concurrent/locks/Condition;)~2Collection;|(~2concurrent/locks/Condition;)~2Collection<~1Thread;>;|',
'M|1|isHeldByCurrentThread|()Z||',
'M|17|isFair|()Z||',
'M|17|hasQueuedThread|(~1Thread;)Z||',
'C|1|java/util/concurrent/CopyOnWriteArrayList|<E:~O>~O~2List<TE;>;~2RandomAccess;~1Cloneable;~4Serializable;',
'M|1|<init>|(~2Collection;)V|(~2Collection<+TE;>;)V|',
'M|1|<init>|()V||',
'M|1|<init>|([~O)V|([TE;)V|',
'M|1|remove|(I)~O|(I)TE;|',
'M|1|remove|(~O)Z||',
'M|1|size|()I||',
'M|1|get|(I)~O|(I)TE;|',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|clone|()~O||',
'M|1|indexOf|(~O)I||',
'M|1|indexOf|(~OI)I|(TE;I)I|',
'M|1|clear|()V||',
'M|1|lastIndexOf|(~OI)I|(TE;I)I|',
'M|1|lastIndexOf|(~O)I||',
'M|1|isEmpty|()Z||',
'M|1|replaceAll|(~3UnaryOperator;)V|(~3UnaryOperator<TE;>;)V|',
'M|1|add|(I~O)V|(ITE;)V|',
'M|1|add|(~O)Z|(TE;)Z|',
'M|1|subList|(II)~2List;|(II)~2List<TE;>;|',
'M|1|toArray|()[~O||',
'M|1|toArray|([~O)[~O|<T:~O>([TT;)[TT;|',
'M|1|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1|contains|(~O)Z||',
'M|1|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|1|addAll|(~2Collection;)Z|(~2Collection<+TE;>;)Z|',
'M|1|addAll|(I~2Collection;)Z|(I~2Collection<+TE;>;)Z|',
'M|1|set|(I~O)~O|(ITE;)TE;|',
'M|1|forEach|(~3Consumer;)V|(~3Consumer<-TE;>;)V|',
'M|1|sort|(~2Comparator;)V|(~2Comparator<-TE;>;)V|',
'M|1|removeIf|(~3Predicate;)Z|(~3Predicate<-TE;>;)Z|',
'M|1|getFirst|()~O|()TE;|',
'M|1|getLast|()~O|()TE;|',
'M|1|addFirst|(~O)V|(TE;)V|',
'M|1|addLast|(~O)V|(TE;)V|',
'M|1|removeFirst|()~O|()TE;|',
'M|1|removeLast|()~O|()TE;|',
'M|1|removeAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|retainAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|listIterator|(I)~2ListIterator;|(I)~2ListIterator<TE;>;|',
'M|1|listIterator|()~2ListIterator;|()~2ListIterator<TE;>;|',
'M|1|reversed|()~2List;|()~2List<TE;>;|',
'M|1|containsAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|addIfAbsent|(~O)Z|(TE;)Z|',
'M|1|addAllAbsent|(~2Collection;)I|(~2Collection<+TE;>;)I|',
'C|17|java/util/concurrent/ThreadLocalRandom|~2Random;',
'M|4|next|(I)I||',
'M|9|current|()~2concurrent/ThreadLocalRandom;||',
'M|1|nextDouble|()D||',
'M|1|nextDouble|(DD)D||',
'M|1|nextDouble|(D)D||',
'M|1|nextInt|()I||',
'M|1|nextInt|(II)I||',
'M|1|nextInt|(I)I||',
'M|1|setSeed|(J)V||',
'M|1|ints|(II)~5IntStream;||',
'M|1|ints|(JII)~5IntStream;||',
'M|1|ints|()~5IntStream;||',
'M|1|ints|(J)~5IntStream;||',
'M|1|longs|(JJ)~5LongStream;||',
'M|1|longs|(JJJ)~5LongStream;||',
'M|1|longs|(J)~5LongStream;||',
'M|1|longs|()~5LongStream;||',
'M|1|doubles|(DD)~5DoubleStream;||',
'M|1|doubles|(J)~5DoubleStream;||',
'M|1|doubles|(JDD)~5DoubleStream;||',
'M|1|doubles|()~5DoubleStream;||',
'M|1|nextLong|(JJ)J||',
'M|1|nextLong|(J)J||',
'M|1|nextLong|()J||',
'M|1|nextBoolean|()Z||',
'M|1|nextFloat|(FF)F||',
'M|1|nextFloat|()F||',
'M|1|nextFloat|(F)F||',
'C|1|java/util/concurrent/ExecutionException|~1Exception;',
'M|1|<init>|(~1Throwable;)V||',
'M|1|<init>|(~S~1Throwable;)V||',
'M|4|<init>|(~S)V||',
'M|4|<init>|()V||',
'C|1|java/util/concurrent/TimeoutException|~1Exception;',
'M|1|<init>|()V||',
'M|1|<init>|(~S)V||',
'C|1537|java/util/concurrent/BlockingQueue|<E:~O>~O~2Queue<TE;>;',
'M|1025|remove|(~O)Z||',
'M|1025|put|(~O)V|(TE;)V|java/lang/InterruptedException',
'M|1025|add|(~O)Z|(TE;)Z|',
'M|1025|contains|(~O)Z||',
'M|1025|poll|(J~2concurrent/TimeUnit;)~O|(J~2concurrent/TimeUnit;)TE;|java/lang/InterruptedException',
'M|1025|offer|(~O)Z|(TE;)Z|',
'M|1025|offer|(~OJ~2concurrent/TimeUnit;)Z|(TE;J~2concurrent/TimeUnit;)Z|java/lang/InterruptedException',
'M|1025|take|()~O|()TE;|java/lang/InterruptedException',
'M|1025|remainingCapacity|()I||',
'M|1025|drainTo|(~2Collection;)I|(~2Collection<-TE;>;)I|',
'M|1025|drainTo|(~2Collection;I)I|(~2Collection<-TE;>;I)I|',
'C|1|java/util/concurrent/LinkedBlockingQueue|<E:~O>~2AbstractQueue<TE;>;~2concurrent/BlockingQueue<TE;>;~4Serializable;',
'M|1|<init>|(I)V||',
'M|1|<init>|()V||',
'M|1|<init>|(~2Collection;)V|(~2Collection<+TE;>;)V|',
'M|1|remove|(~O)Z||',
'M|1|size|()I||',
'M|1|put|(~O)V|(TE;)V|java/lang/InterruptedException',
'M|1|toString|()~S||',
'M|1|clear|()V||',
'M|1|toArray|([~O)[~O|<T:~O>([TT;)[TT;|',
'M|1|toArray|()[~O||',
'M|1|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1|contains|(~O)Z||',
'M|1|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|1|forEach|(~3Consumer;)V|(~3Consumer<-TE;>;)V|',
'M|1|peek|()~O|()TE;|',
'M|1|removeIf|(~3Predicate;)Z|(~3Predicate<-TE;>;)Z|',
'M|1|removeAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|retainAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|poll|()~O|()TE;|',
'M|1|poll|(J~2concurrent/TimeUnit;)~O|(J~2concurrent/TimeUnit;)TE;|java/lang/InterruptedException',
'M|1|offer|(~OJ~2concurrent/TimeUnit;)Z|(TE;J~2concurrent/TimeUnit;)Z|java/lang/InterruptedException',
'M|1|offer|(~O)Z|(TE;)Z|',
'M|1|take|()~O|()TE;|java/lang/InterruptedException',
'M|1|remainingCapacity|()I||',
'M|1|drainTo|(~2Collection;I)I|(~2Collection<-TE;>;I)I|',
'M|1|drainTo|(~2Collection;)I|(~2Collection<-TE;>;)I|',
'C|1|java/util/concurrent/ConcurrentLinkedQueue|<E:~O>~2AbstractQueue<TE;>;~2Queue<TE;>;~4Serializable;',
'M|1|<init>|()V||',
'M|1|<init>|(~2Collection;)V|(~2Collection<+TE;>;)V|',
'M|1|remove|(~O)Z||',
'M|1|size|()I||',
'M|1|toString|()~S||',
'M|1|clear|()V||',
'M|1|isEmpty|()Z||',
'M|1|add|(~O)Z|(TE;)Z|',
'M|1|toArray|([~O)[~O|<T:~O>([TT;)[TT;|',
'M|1|toArray|()[~O||',
'M|1|iterator|()~2Iterator;|()~2Iterator<TE;>;|',
'M|1|contains|(~O)Z||',
'M|1|spliterator|()~2Spliterator;|()~2Spliterator<TE;>;|',
'M|1|addAll|(~2Collection;)Z|(~2Collection<+TE;>;)Z|',
'M|1|forEach|(~3Consumer;)V|(~3Consumer<-TE;>;)V|',
'M|1|peek|()~O|()TE;|',
'M|1|removeIf|(~3Predicate;)Z|(~3Predicate<-TE;>;)Z|',
'M|1|removeAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|retainAll|(~2Collection;)Z|(~2Collection<*>;)Z|',
'M|1|poll|()~O|()TE;|',
'M|1|offer|(~O)Z|(TE;)Z|',
'C|1|java/util/concurrent/Semaphore|~O~4Serializable;',
'M|1|<init>|(I)V||',
'M|1|<init>|(IZ)V||',
'M|1|drainPermits|()I||',
'M|4|reducePermits|(I)V||',
'M|1|acquireUninterruptibly|(I)V||',
'M|1|acquireUninterruptibly|()V||',
'M|1|availablePermits|()I||',
'M|1|toString|()~S||',
'M|1|release|()V||',
'M|1|release|(I)V||',
'M|17|hasQueuedThreads|()Z||',
'M|17|getQueueLength|()I||',
'M|4|getQueuedThreads|()~2Collection;|()~2Collection<~1Thread;>;|',
'M|1|isFair|()Z||',
'M|1|tryAcquire|(IJ~2concurrent/TimeUnit;)Z||java/lang/InterruptedException',
'M|1|tryAcquire|(I)Z||',
'M|1|tryAcquire|()Z||',
'M|1|tryAcquire|(J~2concurrent/TimeUnit;)Z||java/lang/InterruptedException',
'M|1|acquire|(I)V||java/lang/InterruptedException',
'M|1|acquire|()V||java/lang/InterruptedException',
'C|1|java/math/BigInteger|~1Number;~1Comparable<Ljava/math/BigInteger;>;',
'F|25|ZERO|Ljava/math/BigInteger;||',
'F|25|ONE|Ljava/math/BigInteger;||',
'F|25|TWO|Ljava/math/BigInteger;||',
'F|25|TEN|Ljava/math/BigInteger;||',
'M|1|<init>|(I~2Random;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|(II~2Random;)V||',
'M|1|<init>|(I[BII)V||',
'M|1|<init>|([B)V||',
'M|1|<init>|([BII)V||',
'M|1|<init>|(~SI)V||',
'M|1|<init>|(I[B)V||',
'M|1|bitCount|()I||',
'M|1|equals|(~O)Z||',
'M|1|toString|(I)~S||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|abs|()Ljava/math/BigInteger;||',
'M|1|sqrt|()Ljava/math/BigInteger;||',
'M|1|pow|(I)Ljava/math/BigInteger;||',
'M|1|min|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|max|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|signum|()I||',
'M|1|compareTo|(Ljava/math/BigInteger;)I||',
'M|1|intValue|()I||',
'M|1|longValue|()J||',
'M|1|floatValue|()F||',
'M|1|doubleValue|()D||',
'M|9|valueOf|(J)Ljava/math/BigInteger;||',
'M|1|add|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|mod|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|setBit|(I)Ljava/math/BigInteger;||',
'M|1|shiftLeft|(I)Ljava/math/BigInteger;||',
'M|1|multiply|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|or|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|toByteArray|()[B||',
'M|1|remainder|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|bitLength|()I||',
'M|1|testBit|(I)Z||',
'M|1|subtract|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|shiftRight|(I)Ljava/math/BigInteger;||',
'M|1|getLowestSetBit|()I||',
'M|1|modPow|(Ljava/math/BigInteger;Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|negate|()Ljava/math/BigInteger;||',
'M|1|modInverse|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|divide|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|divideAndRemainder|(Ljava/math/BigInteger;)[Ljava/math/BigInteger;||',
'M|9|probablePrime|(I~2Random;)Ljava/math/BigInteger;||',
'M|1|nextProbablePrime|()Ljava/math/BigInteger;||',
'M|1|parallelMultiply|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|sqrtAndRemainder|()[Ljava/math/BigInteger;||',
'M|1|gcd|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|and|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|xor|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|not|()Ljava/math/BigInteger;||',
'M|1|andNot|(Ljava/math/BigInteger;)Ljava/math/BigInteger;||',
'M|1|clearBit|(I)Ljava/math/BigInteger;||',
'M|1|flipBit|(I)Ljava/math/BigInteger;||',
'M|1|isProbablePrime|(I)Z||',
'M|1|longValueExact|()J||',
'M|1|intValueExact|()I||',
'M|1|shortValueExact|()S||',
'M|1|byteValueExact|()B||',
'C|1|java/math/BigDecimal|~1Number;~1Comparable<Ljava/math/BigDecimal;>;',
'F|25|ZERO|Ljava/math/BigDecimal;||',
'F|25|ONE|Ljava/math/BigDecimal;||',
'F|25|TWO|Ljava/math/BigDecimal;||',
'F|25|TEN|Ljava/math/BigDecimal;||',
'F|25|ROUND_UP|I||I0',
'F|25|ROUND_DOWN|I||I1',
'F|25|ROUND_CEILING|I||I2',
'F|25|ROUND_FLOOR|I||I3',
'F|25|ROUND_HALF_UP|I||I4',
'F|25|ROUND_HALF_DOWN|I||I5',
'F|25|ROUND_HALF_EVEN|I||I6',
'F|25|ROUND_UNNECESSARY|I||I7',
'M|1|<init>|(Ljava/math/BigInteger;I)V||',
'M|1|<init>|(Ljava/math/BigInteger;Ljava/math/MathContext;)V||',
'M|1|<init>|(Ljava/math/BigInteger;)V||',
'M|1|<init>|(JLjava/math/MathContext;)V||',
'M|1|<init>|(DLjava/math/MathContext;)V||',
'M|1|<init>|(J)V||',
'M|1|<init>|(ILjava/math/MathContext;)V||',
'M|1|<init>|(I)V||',
'M|1|<init>|(Ljava/math/BigInteger;ILjava/math/MathContext;)V||',
'M|1|<init>|([C)V||',
'M|1|<init>|([CIILjava/math/MathContext;)V||',
'M|1|<init>|([CII)V||',
'M|1|<init>|(D)V||',
'M|1|<init>|(~SLjava/math/MathContext;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|([CLjava/math/MathContext;)V||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|abs|()Ljava/math/BigDecimal;||',
'M|1|abs|(Ljava/math/MathContext;)Ljava/math/BigDecimal;||',
'M|1|sqrt|(Ljava/math/MathContext;)Ljava/math/BigDecimal;||',
'M|1|pow|(I)Ljava/math/BigDecimal;||',
'M|1|pow|(ILjava/math/MathContext;)Ljava/math/BigDecimal;||',
'M|1|min|(Ljava/math/BigDecimal;)Ljava/math/BigDecimal;||',
'M|1|max|(Ljava/math/BigDecimal;)Ljava/math/BigDecimal;||',
'M|1|round|(Ljava/math/MathContext;)Ljava/math/BigDecimal;||',
'M|1|signum|()I||',
'M|1|compareTo|(Ljava/math/BigDecimal;)I||',
'M|1|intValue|()I||',
'M|1|longValue|()J||',
'M|1|floatValue|()F||',
'M|1|doubleValue|()D||',
'M|9|valueOf|(J)Ljava/math/BigDecimal;||',
'M|9|valueOf|(JI)Ljava/math/BigDecimal;||',
'M|9|valueOf|(D)Ljava/math/BigDecimal;||',
'M|1|scale|()I||',
'M|1|add|(Ljava/math/BigDecimal;Ljava/math/MathContext;)Ljava/math/BigDecimal;||',
'M|1|add|(Ljava/math/BigDecimal;)Ljava/math/BigDecimal;||',
'M|1|multiply|(Ljava/math/BigDecimal;Ljava/math/MathContext;)Ljava/math/BigDecimal;||',
'M|1|multiply|(Ljava/math/BigDecimal;)Ljava/math/BigDecimal;||',
'M|1|ulp|()Ljava/math/BigDecimal;||',
'M|1|remainder|(Ljava/math/BigDecimal;Ljava/math/MathContext;)Ljava/math/BigDecimal;||',
'M|1|remainder|(Ljava/math/BigDecimal;)Ljava/math/BigDecimal;||',
'M|1|subtract|(Ljava/math/BigDecimal;)Ljava/math/BigDecimal;||',
'M|1|subtract|(Ljava/math/BigDecimal;Ljava/math/MathContext;)Ljava/math/BigDecimal;||',
'M|1|negate|()Ljava/math/BigDecimal;||',
'M|1|negate|(Ljava/math/MathContext;)Ljava/math/BigDecimal;||',
'M|1|toBigInteger|()Ljava/math/BigInteger;||',
'M|1|divide|(Ljava/math/BigDecimal;Ljava/math/MathContext;)Ljava/math/BigDecimal;||',
'M|1|divide|(Ljava/math/BigDecimal;II)Ljava/math/BigDecimal;||',
'M|1|divide|(Ljava/math/BigDecimal;ILjava/math/RoundingMode;)Ljava/math/BigDecimal;||',
'M|1|divide|(Ljava/math/BigDecimal;I)Ljava/math/BigDecimal;||',
'M|1|divide|(Ljava/math/BigDecimal;)Ljava/math/BigDecimal;||',
'M|1|divide|(Ljava/math/BigDecimal;Ljava/math/RoundingMode;)Ljava/math/BigDecimal;||',
'M|1|divideAndRemainder|(Ljava/math/BigDecimal;Ljava/math/MathContext;)[Ljava/math/BigDecimal;||',
'M|1|divideAndRemainder|(Ljava/math/BigDecimal;)[Ljava/math/BigDecimal;||',
'M|1|longValueExact|()J||',
'M|1|intValueExact|()I||',
'M|1|shortValueExact|()S||',
'M|1|byteValueExact|()B||',
'M|1|scaleByPowerOfTen|(I)Ljava/math/BigDecimal;||',
'M|1|plus|(Ljava/math/MathContext;)Ljava/math/BigDecimal;||',
'M|1|plus|()Ljava/math/BigDecimal;||',
'M|1|divideToIntegralValue|(Ljava/math/BigDecimal;)Ljava/math/BigDecimal;||',
'M|1|divideToIntegralValue|(Ljava/math/BigDecimal;Ljava/math/MathContext;)Ljava/math/BigDecimal;||',
'M|1|movePointRight|(I)Ljava/math/BigDecimal;||',
'M|1|toBigIntegerExact|()Ljava/math/BigInteger;||',
'M|1|precision|()I||',
'M|1|unscaledValue|()Ljava/math/BigInteger;||',
'M|1|setScale|(ILjava/math/RoundingMode;)Ljava/math/BigDecimal;||',
'M|1|setScale|(II)Ljava/math/BigDecimal;||',
'M|1|setScale|(I)Ljava/math/BigDecimal;||',
'M|1|stripTrailingZeros|()Ljava/math/BigDecimal;||',
'M|1|movePointLeft|(I)Ljava/math/BigDecimal;||',
'M|1|toEngineeringString|()~S||',
'M|1|toPlainString|()~S||',
'C|16401|java/math/RoundingMode|~1Enum<Ljava/math/RoundingMode;>;',
'F|16409|UP|Ljava/math/RoundingMode;||',
'F|16409|DOWN|Ljava/math/RoundingMode;||',
'F|16409|CEILING|Ljava/math/RoundingMode;||',
'F|16409|FLOOR|Ljava/math/RoundingMode;||',
'F|16409|HALF_UP|Ljava/math/RoundingMode;||',
'F|16409|HALF_DOWN|Ljava/math/RoundingMode;||',
'F|16409|HALF_EVEN|Ljava/math/RoundingMode;||',
'F|16409|UNNECESSARY|Ljava/math/RoundingMode;||',
'C|17|java/math/MathContext|~O~4Serializable;',
'F|25|UNLIMITED|Ljava/math/MathContext;||',
'F|25|DECIMAL32|Ljava/math/MathContext;||',
'F|25|DECIMAL64|Ljava/math/MathContext;||',
'F|25|DECIMAL128|Ljava/math/MathContext;||',
'M|1|<init>|(~S)V||',
'M|1|<init>|(ILjava/math/RoundingMode;)V||',
'M|1|<init>|(I)V||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|getRoundingMode|()Ljava/math/RoundingMode;||',
'M|1|getPrecision|()I||',
'C|1|java/text/DecimalFormat|Ljava/text/NumberFormat;',
'M|1|<init>|(~SLjava/text/DecimalFormatSymbols;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'M|1|equals|(~O)Z||',
'M|1|hashCode|()I||',
'M|1|clone|()~O||',
'M|1|format|(D~1StringBuffer;Ljava/text/FieldPosition;)~1StringBuffer;||',
'M|17|format|(~O~1StringBuffer;Ljava/text/FieldPosition;)~1StringBuffer;||',
'M|1|format|(J~1StringBuffer;Ljava/text/FieldPosition;)~1StringBuffer;||',
'M|1|parse|(~SLjava/text/ParsePosition;)~1Number;||',
'M|1|formatToCharacterIterator|(~O)Ljava/text/AttributedCharacterIterator;||',
'M|1|getMaximumIntegerDigits|()I||',
'M|1|getMinimumIntegerDigits|()I||',
'M|1|getMaximumFractionDigits|()I||',
'M|1|getMinimumFractionDigits|()I||',
'M|1|applyPattern|(~S)V||',
'M|1|isParseBigDecimal|()Z||',
'M|1|setGroupingUsed|(Z)V||',
'M|1|toPattern|()~S||',
'M|1|setMinimumIntegerDigits|(I)V||',
'M|1|setMaximumIntegerDigits|(I)V||',
'M|1|setMaximumFractionDigits|(I)V||',
'M|1|setMinimumFractionDigits|(I)V||',
'M|1|setDecimalSeparatorAlwaysShown|(Z)V||',
'M|1|getCurrency|()~2Currency;||',
'M|1|setCurrency|(~2Currency;)V||',
'M|1|setRoundingMode|(Ljava/math/RoundingMode;)V||',
'M|1|getRoundingMode|()Ljava/math/RoundingMode;||',
'M|1|getDecimalFormatSymbols|()Ljava/text/DecimalFormatSymbols;||',
'M|1|setDecimalFormatSymbols|(Ljava/text/DecimalFormatSymbols;)V||',
'M|1|getPositivePrefix|()~S||',
'M|1|setPositivePrefix|(~S)V||',
'M|1|getNegativePrefix|()~S||',
'M|1|setNegativePrefix|(~S)V||',
'M|1|getPositiveSuffix|()~S||',
'M|1|setPositiveSuffix|(~S)V||',
'M|1|getNegativeSuffix|()~S||',
'M|1|setNegativeSuffix|(~S)V||',
'M|1|getMultiplier|()I||',
'M|1|setMultiplier|(I)V||',
'M|1|getGroupingSize|()I||',
'M|1|setGroupingSize|(I)V||',
'M|1|isDecimalSeparatorAlwaysShown|()Z||',
'M|1|setParseBigDecimal|(Z)V||',
'M|1|toLocalizedPattern|()~S||',
'M|1|applyLocalizedPattern|(~S)V||',
'C|1025|java/text/NumberFormat|Ljava/text/Format;',
'F|25|INTEGER_FIELD|I||I0',
'F|25|FRACTION_FIELD|I||I1',
'M|4|<init>|()V||',
'M|1|equals|(~O)Z||',
'M|1|hashCode|()I||',
'M|1|clone|()~O||',
'M|1025|format|(J~1StringBuffer;Ljava/text/FieldPosition;)~1StringBuffer;||',
'M|1025|format|(D~1StringBuffer;Ljava/text/FieldPosition;)~1StringBuffer;||',
'M|1|format|(~O~1StringBuffer;Ljava/text/FieldPosition;)~1StringBuffer;||',
'M|17|format|(D)~S||',
'M|17|format|(J)~S||',
'M|25|getInstance|()Ljava/text/NumberFormat;||',
'M|9|getInstance|(~2Locale;)Ljava/text/NumberFormat;||',
'M|1025|parse|(~SLjava/text/ParsePosition;)~1Number;||',
'M|1|parse|(~S)~1Number;||java/text/ParseException',
'M|9|getAvailableLocales|()[~2Locale;||',
'M|17|parseObject|(~SLjava/text/ParsePosition;)~O||',
'M|1|getMaximumIntegerDigits|()I||',
'M|1|getMinimumIntegerDigits|()I||',
'M|1|getMaximumFractionDigits|()I||',
'M|1|getMinimumFractionDigits|()I||',
'M|1|isGroupingUsed|()Z||',
'M|1|isParseIntegerOnly|()Z||',
'M|1|setGroupingUsed|(Z)V||',
'M|1|setMinimumIntegerDigits|(I)V||',
'M|1|setMaximumIntegerDigits|(I)V||',
'M|1|setMaximumFractionDigits|(I)V||',
'M|1|setMinimumFractionDigits|(I)V||',
'M|1|getCurrency|()~2Currency;||',
'M|1|setCurrency|(~2Currency;)V||',
'M|1|setRoundingMode|(Ljava/math/RoundingMode;)V||',
'M|1|getRoundingMode|()Ljava/math/RoundingMode;||',
'M|25|getNumberInstance|()Ljava/text/NumberFormat;||',
'M|9|getNumberInstance|(~2Locale;)Ljava/text/NumberFormat;||',
'M|25|getPercentInstance|()Ljava/text/NumberFormat;||',
'M|9|getPercentInstance|(~2Locale;)Ljava/text/NumberFormat;||',
'M|9|getCurrencyInstance|(~2Locale;)Ljava/text/NumberFormat;||',
'M|25|getCurrencyInstance|()Ljava/text/NumberFormat;||',
'M|9|getIntegerInstance|(~2Locale;)Ljava/text/NumberFormat;||',
'M|25|getIntegerInstance|()Ljava/text/NumberFormat;||',
'M|9|getCompactNumberInstance|()Ljava/text/NumberFormat;||',
'M|9|getCompactNumberInstance|(~2Locale;Ljava/text/NumberFormat$Style;)Ljava/text/NumberFormat;||',
'M|1|setParseIntegerOnly|(Z)V||',
'C|1025|java/text/Format|~O~4Serializable;~1Cloneable;',
'M|4|<init>|()V||',
'M|1|clone|()~O||',
'M|1025|format|(~O~1StringBuffer;Ljava/text/FieldPosition;)~1StringBuffer;||',
'M|17|format|(~O)~S||',
'M|1|parseObject|(~S)~O||java/text/ParseException',
'M|1025|parseObject|(~SLjava/text/ParsePosition;)~O||',
'M|1|formatToCharacterIterator|(~O)Ljava/text/AttributedCharacterIterator;||',
'C|1|java/text/SimpleDateFormat|Ljava/text/DateFormat;',
'M|1|<init>|(~SLjava/text/DateFormatSymbols;)V||',
'M|1|<init>|(~S~2Locale;)V||',
'M|1|<init>|(~S)V||',
'M|1|<init>|()V||',
'M|1|equals|(~O)Z||',
'M|1|hashCode|()I||',
'M|1|clone|()~O||',
'M|1|format|(~2Date;~1StringBuffer;Ljava/text/FieldPosition;)~1StringBuffer;||',
'M|1|parse|(~SLjava/text/ParsePosition;)~2Date;||',
'M|1|formatToCharacterIterator|(~O)Ljava/text/AttributedCharacterIterator;||',
'M|1|applyPattern|(~S)V||',
'M|1|toPattern|()~S||',
'M|1|toLocalizedPattern|()~S||',
'M|1|applyLocalizedPattern|(~S)V||',
'M|1|set2DigitYearStart|(~2Date;)V||',
'M|1|get2DigitYearStart|()~2Date;||',
'M|1|getDateFormatSymbols|()Ljava/text/DateFormatSymbols;||',
'M|1|setDateFormatSymbols|(Ljava/text/DateFormatSymbols;)V||',
'C|1025|java/text/DateFormat|Ljava/text/Format;',
'F|4|calendar|~2Calendar;||',
'F|4|numberFormat|Ljava/text/NumberFormat;||',
'F|25|ERA_FIELD|I||I0',
'F|25|YEAR_FIELD|I||I1',
'F|25|MONTH_FIELD|I||I2',
'F|25|DATE_FIELD|I||I3',
'F|25|HOUR_OF_DAY1_FIELD|I||I4',
'F|25|HOUR_OF_DAY0_FIELD|I||I5',
'F|25|MINUTE_FIELD|I||I6',
'F|25|SECOND_FIELD|I||I7',
'F|25|MILLISECOND_FIELD|I||I8',
'F|25|DAY_OF_WEEK_FIELD|I||I9',
'F|25|DAY_OF_YEAR_FIELD|I||I10',
'F|25|DAY_OF_WEEK_IN_MONTH_FIELD|I||I11',
'F|25|WEEK_OF_YEAR_FIELD|I||I12',
'F|25|WEEK_OF_MONTH_FIELD|I||I13',
'F|25|AM_PM_FIELD|I||I14',
'F|25|HOUR1_FIELD|I||I15',
'F|25|HOUR0_FIELD|I||I16',
'F|25|TIMEZONE_FIELD|I||I17',
'F|25|FULL|I||I0',
'F|25|LONG|I||I1',
'F|25|MEDIUM|I||I2',
'F|25|SHORT|I||I3',
'F|25|DEFAULT|I||I2',
'M|4|<init>|()V||',
'M|1|equals|(~O)Z||',
'M|1|hashCode|()I||',
'M|1|clone|()~O||',
'M|17|format|(~O~1StringBuffer;Ljava/text/FieldPosition;)~1StringBuffer;||',
'M|17|format|(~2Date;)~S||',
'M|1025|format|(~2Date;~1StringBuffer;Ljava/text/FieldPosition;)~1StringBuffer;||',
'M|25|getInstance|()Ljava/text/DateFormat;||',
'M|1|getTimeZone|()~2TimeZone;||',
'M|1|setTimeZone|(~2TimeZone;)V||',
'M|1|parse|(~S)~2Date;||java/text/ParseException',
'M|1025|parse|(~SLjava/text/ParsePosition;)~2Date;||',
'M|25|getDateTimeInstance|(II~2Locale;)Ljava/text/DateFormat;||',
'M|25|getDateTimeInstance|()Ljava/text/DateFormat;||',
'M|25|getDateTimeInstance|(II)Ljava/text/DateFormat;||',
'M|9|getAvailableLocales|()[~2Locale;||',
'M|1|setLenient|(Z)V||',
'M|1|isLenient|()Z||',
'M|25|getDateInstance|(I)Ljava/text/DateFormat;||',
'M|25|getDateInstance|(I~2Locale;)Ljava/text/DateFormat;||',
'M|25|getDateInstance|()Ljava/text/DateFormat;||',
'M|25|getTimeInstance|(I~2Locale;)Ljava/text/DateFormat;||',
'M|25|getTimeInstance|(I)Ljava/text/DateFormat;||',
'M|25|getTimeInstance|()Ljava/text/DateFormat;||',
'M|1|parseObject|(~SLjava/text/ParsePosition;)~O||',
'M|1|setCalendar|(~2Calendar;)V||',
'M|1|getCalendar|()~2Calendar;||',
'M|1|setNumberFormat|(Ljava/text/NumberFormat;)V||',
'M|1|getNumberFormat|()Ljava/text/NumberFormat;||',
'C|17|java/time/LocalDate|~OLjava/time/temporal/Temporal;Ljava/time/temporal/TemporalAdjuster;Ljava/time/chrono/ChronoLocalDate;~4Serializable;',
'F|25|MIN|Ljava/time/LocalDate;||',
'F|25|MAX|Ljava/time/LocalDate;||',
'F|25|EPOCH|Ljava/time/LocalDate;||',
'M|1|get|(Ljava/time/temporal/TemporalField;)I||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|compareTo|(Ljava/time/chrono/ChronoLocalDate;)I||',
'M|1|getLong|(Ljava/time/temporal/TemporalField;)J||',
'M|1|format|(Ljava/time/format/DateTimeFormatter;)~S||',
'M|9|of|(III)Ljava/time/LocalDate;||',
'M|9|of|(ILjava/time/Month;I)Ljava/time/LocalDate;||',
'M|9|from|(Ljava/time/temporal/TemporalAccessor;)Ljava/time/LocalDate;||',
'M|1|isSupported|(Ljava/time/temporal/TemporalUnit;)Z||',
'M|1|isSupported|(Ljava/time/temporal/TemporalField;)Z||',
'M|9|parse|(~1CharSequence;)Ljava/time/LocalDate;||',
'M|9|parse|(~1CharSequence;Ljava/time/format/DateTimeFormatter;)Ljava/time/LocalDate;||',
'M|1|with|(Ljava/time/temporal/TemporalAdjuster;)Ljava/time/LocalDate;||',
'M|1|with|(Ljava/time/temporal/TemporalField;J)Ljava/time/LocalDate;||',
'M|1|query|(Ljava/time/temporal/TemporalQuery;)~O|<R:~O>(Ljava/time/temporal/TemporalQuery<TR;>;)TR;|',
'M|1|range|(Ljava/time/temporal/TemporalField;)Ljava/time/temporal/ValueRange;||',
'M|9|now|()Ljava/time/LocalDate;||',
'M|9|now|(Ljava/time/Clock;)Ljava/time/LocalDate;||',
'M|9|now|(Ljava/time/ZoneId;)Ljava/time/LocalDate;||',
'M|1|getYear|()I||',
'M|1|getMonthValue|()I||',
'M|1|getDayOfMonth|()I||',
'M|1|minus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/LocalDate;||',
'M|1|minus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/LocalDate;||',
'M|1|plus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/LocalDate;||',
'M|1|plus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/LocalDate;||',
'M|1|until|(Ljava/time/chrono/ChronoLocalDate;)Ljava/time/Period;||',
'M|1|until|(Ljava/time/temporal/Temporal;Ljava/time/temporal/TemporalUnit;)J||',
'M|1|plusDays|(J)Ljava/time/LocalDate;||',
'M|1|minusDays|(J)Ljava/time/LocalDate;||',
'M|1|adjustInto|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'M|9|ofInstant|(Ljava/time/Instant;Ljava/time/ZoneId;)Ljava/time/LocalDate;||',
'M|1|isAfter|(Ljava/time/chrono/ChronoLocalDate;)Z||',
'M|1|isBefore|(Ljava/time/chrono/ChronoLocalDate;)Z||',
'M|1|isLeapYear|()Z||',
'M|9|ofEpochDay|(J)Ljava/time/LocalDate;||',
'M|1|lengthOfMonth|()I||',
'M|1|lengthOfYear|()I||',
'M|1|getMonth|()Ljava/time/Month;||',
'M|1|toEpochDay|()J||',
'M|1|getDayOfWeek|()Ljava/time/DayOfWeek;||',
'M|1|getDayOfYear|()I||',
'M|1|withDayOfMonth|(I)Ljava/time/LocalDate;||',
'M|1|withDayOfYear|(I)Ljava/time/LocalDate;||',
'M|1|plusWeeks|(J)Ljava/time/LocalDate;||',
'M|1|withMonth|(I)Ljava/time/LocalDate;||',
'M|1|plusMonths|(J)Ljava/time/LocalDate;||',
'M|1|withYear|(I)Ljava/time/LocalDate;||',
'M|9|ofYearDay|(II)Ljava/time/LocalDate;||',
'M|1|plusYears|(J)Ljava/time/LocalDate;||',
'M|1|minusMonths|(J)Ljava/time/LocalDate;||',
'M|1|atTime|(Ljava/time/LocalTime;)Ljava/time/LocalDateTime;||',
'M|1|atTime|(IIII)Ljava/time/LocalDateTime;||',
'M|1|atTime|(Ljava/time/OffsetTime;)Ljava/time/OffsetDateTime;||',
'M|1|atTime|(III)Ljava/time/LocalDateTime;||',
'M|1|atTime|(II)Ljava/time/LocalDateTime;||',
'M|1|isEqual|(Ljava/time/chrono/ChronoLocalDate;)Z||',
'M|1|getEra|()Ljava/time/chrono/IsoEra;||',
'M|1|getChronology|()Ljava/time/chrono/IsoChronology;||',
'M|1|minusYears|(J)Ljava/time/LocalDate;||',
'M|1|minusWeeks|(J)Ljava/time/LocalDate;||',
'M|1|datesUntil|(Ljava/time/LocalDate;Ljava/time/Period;)~5Stream;|(Ljava/time/LocalDate;Ljava/time/Period;)~5Stream<Ljava/time/LocalDate;>;|',
'M|1|datesUntil|(Ljava/time/LocalDate;)~5Stream;|(Ljava/time/LocalDate;)~5Stream<Ljava/time/LocalDate;>;|',
'M|1|atStartOfDay|()Ljava/time/LocalDateTime;||',
'M|1|atStartOfDay|(Ljava/time/ZoneId;)Ljava/time/ZonedDateTime;||',
'M|1|toEpochSecond|(Ljava/time/LocalTime;Ljava/time/ZoneOffset;)J||',
'C|17|java/time/LocalDateTime|~OLjava/time/temporal/Temporal;Ljava/time/temporal/TemporalAdjuster;Ljava/time/chrono/ChronoLocalDateTime<Ljava/time/LocalDate;>;~4Serializable;',
'F|25|MIN|Ljava/time/LocalDateTime;||',
'F|25|MAX|Ljava/time/LocalDateTime;||',
'M|1|get|(Ljava/time/temporal/TemporalField;)I||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|compareTo|(Ljava/time/chrono/ChronoLocalDateTime;)I|(Ljava/time/chrono/ChronoLocalDateTime<*>;)I|',
'M|1|getLong|(Ljava/time/temporal/TemporalField;)J||',
'M|1|format|(Ljava/time/format/DateTimeFormatter;)~S||',
'M|9|of|(IIIII)Ljava/time/LocalDateTime;||',
'M|9|of|(ILjava/time/Month;IIIII)Ljava/time/LocalDateTime;||',
'M|9|of|(ILjava/time/Month;IIII)Ljava/time/LocalDateTime;||',
'M|9|of|(ILjava/time/Month;III)Ljava/time/LocalDateTime;||',
'M|9|of|(Ljava/time/LocalDate;Ljava/time/LocalTime;)Ljava/time/LocalDateTime;||',
'M|9|of|(IIIIIII)Ljava/time/LocalDateTime;||',
'M|9|of|(IIIIII)Ljava/time/LocalDateTime;||',
'M|9|from|(Ljava/time/temporal/TemporalAccessor;)Ljava/time/LocalDateTime;||',
'M|1|isSupported|(Ljava/time/temporal/TemporalUnit;)Z||',
'M|1|isSupported|(Ljava/time/temporal/TemporalField;)Z||',
'M|9|parse|(~1CharSequence;)Ljava/time/LocalDateTime;||',
'M|9|parse|(~1CharSequence;Ljava/time/format/DateTimeFormatter;)Ljava/time/LocalDateTime;||',
'M|1|with|(Ljava/time/temporal/TemporalField;J)Ljava/time/LocalDateTime;||',
'M|1|with|(Ljava/time/temporal/TemporalAdjuster;)Ljava/time/LocalDateTime;||',
'M|1|query|(Ljava/time/temporal/TemporalQuery;)~O|<R:~O>(Ljava/time/temporal/TemporalQuery<TR;>;)TR;|',
'M|1|range|(Ljava/time/temporal/TemporalField;)Ljava/time/temporal/ValueRange;||',
'M|9|now|()Ljava/time/LocalDateTime;||',
'M|9|now|(Ljava/time/Clock;)Ljava/time/LocalDateTime;||',
'M|9|now|(Ljava/time/ZoneId;)Ljava/time/LocalDateTime;||',
'M|1|getNano|()I||',
'M|9|ofEpochSecond|(JILjava/time/ZoneOffset;)Ljava/time/LocalDateTime;||',
'M|1|getYear|()I||',
'M|1|getMonthValue|()I||',
'M|1|getDayOfMonth|()I||',
'M|1|getHour|()I||',
'M|1|getMinute|()I||',
'M|1|getSecond|()I||',
'M|1|minus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/LocalDateTime;||',
'M|1|minus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/LocalDateTime;||',
'M|1|plus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/LocalDateTime;||',
'M|1|plus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/LocalDateTime;||',
'M|1|until|(Ljava/time/temporal/Temporal;Ljava/time/temporal/TemporalUnit;)J||',
'M|1|plusNanos|(J)Ljava/time/LocalDateTime;||',
'M|1|plusSeconds|(J)Ljava/time/LocalDateTime;||',
'M|1|plusDays|(J)Ljava/time/LocalDateTime;||',
'M|1|plusHours|(J)Ljava/time/LocalDateTime;||',
'M|1|plusMinutes|(J)Ljava/time/LocalDateTime;||',
'M|1|minusDays|(J)Ljava/time/LocalDateTime;||',
'M|1|minusHours|(J)Ljava/time/LocalDateTime;||',
'M|1|minusMinutes|(J)Ljava/time/LocalDateTime;||',
'M|1|minusSeconds|(J)Ljava/time/LocalDateTime;||',
'M|1|minusNanos|(J)Ljava/time/LocalDateTime;||',
'M|1|truncatedTo|(Ljava/time/temporal/TemporalUnit;)Ljava/time/LocalDateTime;||',
'M|1|adjustInto|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'M|9|ofInstant|(Ljava/time/Instant;Ljava/time/ZoneId;)Ljava/time/LocalDateTime;||',
'M|1|atOffset|(Ljava/time/ZoneOffset;)Ljava/time/OffsetDateTime;||',
'M|1|atZone|(Ljava/time/ZoneId;)Ljava/time/ZonedDateTime;||',
'M|1|isAfter|(Ljava/time/chrono/ChronoLocalDateTime;)Z|(Ljava/time/chrono/ChronoLocalDateTime<*>;)Z|',
'M|1|isBefore|(Ljava/time/chrono/ChronoLocalDateTime;)Z|(Ljava/time/chrono/ChronoLocalDateTime<*>;)Z|',
'M|1|getMonth|()Ljava/time/Month;||',
'M|1|getDayOfWeek|()Ljava/time/DayOfWeek;||',
'M|1|getDayOfYear|()I||',
'M|1|withDayOfMonth|(I)Ljava/time/LocalDateTime;||',
'M|1|withDayOfYear|(I)Ljava/time/LocalDateTime;||',
'M|1|plusWeeks|(J)Ljava/time/LocalDateTime;||',
'M|1|withMonth|(I)Ljava/time/LocalDateTime;||',
'M|1|plusMonths|(J)Ljava/time/LocalDateTime;||',
'M|1|withYear|(I)Ljava/time/LocalDateTime;||',
'M|1|plusYears|(J)Ljava/time/LocalDateTime;||',
'M|1|minusMonths|(J)Ljava/time/LocalDateTime;||',
'M|1|toLocalTime|()Ljava/time/LocalTime;||',
'M|1|isEqual|(Ljava/time/chrono/ChronoLocalDateTime;)Z|(Ljava/time/chrono/ChronoLocalDateTime<*>;)Z|',
'M|1|minusYears|(J)Ljava/time/LocalDateTime;||',
'M|1|minusWeeks|(J)Ljava/time/LocalDateTime;||',
'M|1|withHour|(I)Ljava/time/LocalDateTime;||',
'M|1|withMinute|(I)Ljava/time/LocalDateTime;||',
'M|1|withSecond|(I)Ljava/time/LocalDateTime;||',
'M|1|withNano|(I)Ljava/time/LocalDateTime;||',
'M|1|toLocalDate|()Ljava/time/LocalDate;||',
'C|17|java/time/LocalTime|~OLjava/time/temporal/Temporal;Ljava/time/temporal/TemporalAdjuster;~1Comparable<Ljava/time/LocalTime;>;~4Serializable;',
'F|25|MIN|Ljava/time/LocalTime;||',
'F|25|MAX|Ljava/time/LocalTime;||',
'F|25|MIDNIGHT|Ljava/time/LocalTime;||',
'F|25|NOON|Ljava/time/LocalTime;||',
'M|1|get|(Ljava/time/temporal/TemporalField;)I||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|compareTo|(Ljava/time/LocalTime;)I||',
'M|1|getLong|(Ljava/time/temporal/TemporalField;)J||',
'M|1|format|(Ljava/time/format/DateTimeFormatter;)~S||',
'M|9|of|(III)Ljava/time/LocalTime;||',
'M|9|of|(IIII)Ljava/time/LocalTime;||',
'M|9|of|(II)Ljava/time/LocalTime;||',
'M|9|from|(Ljava/time/temporal/TemporalAccessor;)Ljava/time/LocalTime;||',
'M|1|isSupported|(Ljava/time/temporal/TemporalUnit;)Z||',
'M|1|isSupported|(Ljava/time/temporal/TemporalField;)Z||',
'M|9|parse|(~1CharSequence;)Ljava/time/LocalTime;||',
'M|9|parse|(~1CharSequence;Ljava/time/format/DateTimeFormatter;)Ljava/time/LocalTime;||',
'M|1|with|(Ljava/time/temporal/TemporalAdjuster;)Ljava/time/LocalTime;||',
'M|1|with|(Ljava/time/temporal/TemporalField;J)Ljava/time/LocalTime;||',
'M|1|query|(Ljava/time/temporal/TemporalQuery;)~O|<R:~O>(Ljava/time/temporal/TemporalQuery<TR;>;)TR;|',
'M|1|range|(Ljava/time/temporal/TemporalField;)Ljava/time/temporal/ValueRange;||',
'M|9|now|()Ljava/time/LocalTime;||',
'M|9|now|(Ljava/time/Clock;)Ljava/time/LocalTime;||',
'M|9|now|(Ljava/time/ZoneId;)Ljava/time/LocalTime;||',
'M|1|getNano|()I||',
'M|1|getHour|()I||',
'M|1|getMinute|()I||',
'M|1|getSecond|()I||',
'M|1|minus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/LocalTime;||',
'M|1|minus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/LocalTime;||',
'M|1|plus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/LocalTime;||',
'M|1|plus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/LocalTime;||',
'M|1|until|(Ljava/time/temporal/Temporal;Ljava/time/temporal/TemporalUnit;)J||',
'M|1|plusNanos|(J)Ljava/time/LocalTime;||',
'M|1|plusSeconds|(J)Ljava/time/LocalTime;||',
'M|1|plusHours|(J)Ljava/time/LocalTime;||',
'M|1|plusMinutes|(J)Ljava/time/LocalTime;||',
'M|1|minusHours|(J)Ljava/time/LocalTime;||',
'M|1|minusMinutes|(J)Ljava/time/LocalTime;||',
'M|1|minusSeconds|(J)Ljava/time/LocalTime;||',
'M|1|minusNanos|(J)Ljava/time/LocalTime;||',
'M|1|truncatedTo|(Ljava/time/temporal/TemporalUnit;)Ljava/time/LocalTime;||',
'M|1|adjustInto|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'M|9|ofInstant|(Ljava/time/Instant;Ljava/time/ZoneId;)Ljava/time/LocalTime;||',
'M|1|atOffset|(Ljava/time/ZoneOffset;)Ljava/time/OffsetTime;||',
'M|1|isAfter|(Ljava/time/LocalTime;)Z||',
'M|1|isBefore|(Ljava/time/LocalTime;)Z||',
'M|1|toSecondOfDay|()I||',
'M|1|toEpochSecond|(Ljava/time/LocalDate;Ljava/time/ZoneOffset;)J||',
'M|9|ofNanoOfDay|(J)Ljava/time/LocalTime;||',
'M|1|withHour|(I)Ljava/time/LocalTime;||',
'M|1|withMinute|(I)Ljava/time/LocalTime;||',
'M|1|withSecond|(I)Ljava/time/LocalTime;||',
'M|1|withNano|(I)Ljava/time/LocalTime;||',
'M|1|toNanoOfDay|()J||',
'M|9|ofSecondOfDay|(J)Ljava/time/LocalTime;||',
'M|1|atDate|(Ljava/time/LocalDate;)Ljava/time/LocalDateTime;||',
'C|17|java/time/Duration|~OLjava/time/temporal/TemporalAmount;~1Comparable<Ljava/time/Duration;>;~4Serializable;',
'F|25|ZERO|Ljava/time/Duration;||',
'M|1|get|(Ljava/time/temporal/TemporalUnit;)J||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|abs|()Ljava/time/Duration;||',
'M|1|compareTo|(Ljava/time/Duration;)I||',
'M|9|of|(JLjava/time/temporal/TemporalUnit;)Ljava/time/Duration;||',
'M|9|from|(Ljava/time/temporal/TemporalAmount;)Ljava/time/Duration;||',
'M|1|toNanos|()J||',
'M|1|toMillis|()J||',
'M|9|parse|(~1CharSequence;)Ljava/time/Duration;||',
'M|9|between|(Ljava/time/temporal/Temporal;Ljava/time/temporal/Temporal;)Ljava/time/Duration;||',
'M|1|isZero|()Z||',
'M|1|getNano|()I||',
'M|1|toDays|()J||',
'M|1|toSeconds|()J||',
'M|1|isNegative|()Z||',
'M|1|minus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/Duration;||',
'M|1|minus|(Ljava/time/Duration;)Ljava/time/Duration;||',
'M|1|isPositive|()Z||',
'M|1|plus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/Duration;||',
'M|1|plus|(Ljava/time/Duration;)Ljava/time/Duration;||',
'M|1|getUnits|()~2List;|()~2List<Ljava/time/temporal/TemporalUnit;>;|',
'M|9|ofSeconds|(JJ)Ljava/time/Duration;||',
'M|9|ofSeconds|(J)Ljava/time/Duration;||',
'M|1|negated|()Ljava/time/Duration;||',
'M|9|ofNanos|(J)Ljava/time/Duration;||',
'M|1|getSeconds|()J||',
'M|1|plusNanos|(J)Ljava/time/Duration;||',
'M|1|plusSeconds|(J)Ljava/time/Duration;||',
'M|1|plusMillis|(J)Ljava/time/Duration;||',
'M|1|multipliedBy|(J)Ljava/time/Duration;||',
'M|1|plusDays|(J)Ljava/time/Duration;||',
'M|1|plusHours|(J)Ljava/time/Duration;||',
'M|1|plusMinutes|(J)Ljava/time/Duration;||',
'M|1|toHours|()J||',
'M|1|toMinutes|()J||',
'M|9|ofDays|(J)Ljava/time/Duration;||',
'M|9|ofHours|(J)Ljava/time/Duration;||',
'M|9|ofMinutes|(J)Ljava/time/Duration;||',
'M|9|ofMillis|(J)Ljava/time/Duration;||',
'M|1|withSeconds|(J)Ljava/time/Duration;||',
'M|1|withNanos|(I)Ljava/time/Duration;||',
'M|1|minusDays|(J)Ljava/time/Duration;||',
'M|1|minusHours|(J)Ljava/time/Duration;||',
'M|1|minusMinutes|(J)Ljava/time/Duration;||',
'M|1|minusSeconds|(J)Ljava/time/Duration;||',
'M|1|minusMillis|(J)Ljava/time/Duration;||',
'M|1|minusNanos|(J)Ljava/time/Duration;||',
'M|1|dividedBy|(J)Ljava/time/Duration;||',
'M|1|dividedBy|(Ljava/time/Duration;)J||',
'M|1|addTo|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'M|1|subtractFrom|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'M|1|toDaysPart|()J||',
'M|1|toHoursPart|()I||',
'M|1|toMinutesPart|()I||',
'M|1|toSecondsPart|()I||',
'M|1|toMillisPart|()I||',
'M|1|toNanosPart|()I||',
'M|1|truncatedTo|(Ljava/time/temporal/TemporalUnit;)Ljava/time/Duration;||',
'C|17|java/time/Instant|~OLjava/time/temporal/Temporal;Ljava/time/temporal/TemporalAdjuster;~1Comparable<Ljava/time/Instant;>;~4Serializable;',
'F|25|EPOCH|Ljava/time/Instant;||',
'F|25|MIN|Ljava/time/Instant;||',
'F|25|MAX|Ljava/time/Instant;||',
'M|1|get|(Ljava/time/temporal/TemporalField;)I||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|1|compareTo|(Ljava/time/Instant;)I||',
'M|1|getLong|(Ljava/time/temporal/TemporalField;)J||',
'M|9|from|(Ljava/time/temporal/TemporalAccessor;)Ljava/time/Instant;||',
'M|1|isSupported|(Ljava/time/temporal/TemporalUnit;)Z||',
'M|1|isSupported|(Ljava/time/temporal/TemporalField;)Z||',
'M|9|parse|(~1CharSequence;)Ljava/time/Instant;||',
'M|1|with|(Ljava/time/temporal/TemporalField;J)Ljava/time/Instant;||',
'M|1|with|(Ljava/time/temporal/TemporalAdjuster;)Ljava/time/Instant;||',
'M|1|query|(Ljava/time/temporal/TemporalQuery;)~O|<R:~O>(Ljava/time/temporal/TemporalQuery<TR;>;)TR;|',
'M|1|range|(Ljava/time/temporal/TemporalField;)Ljava/time/temporal/ValueRange;||',
'M|9|now|()Ljava/time/Instant;||',
'M|9|now|(Ljava/time/Clock;)Ljava/time/Instant;||',
'M|1|getEpochSecond|()J||',
'M|1|getNano|()I||',
'M|9|ofEpochSecond|(J)Ljava/time/Instant;||',
'M|9|ofEpochSecond|(JJ)Ljava/time/Instant;||',
'M|1|minus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/Instant;||',
'M|1|minus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/Instant;||',
'M|1|toEpochMilli|()J||',
'M|1|plus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/Instant;||',
'M|1|plus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/Instant;||',
'M|1|until|(Ljava/time/temporal/Temporal;Ljava/time/temporal/TemporalUnit;)J||',
'M|1|plusNanos|(J)Ljava/time/Instant;||',
'M|1|plusSeconds|(J)Ljava/time/Instant;||',
'M|1|plusMillis|(J)Ljava/time/Instant;||',
'M|1|minusSeconds|(J)Ljava/time/Instant;||',
'M|1|minusMillis|(J)Ljava/time/Instant;||',
'M|1|minusNanos|(J)Ljava/time/Instant;||',
'M|1|truncatedTo|(Ljava/time/temporal/TemporalUnit;)Ljava/time/Instant;||',
'M|1|adjustInto|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'M|9|ofEpochMilli|(J)Ljava/time/Instant;||',
'M|1|atOffset|(Ljava/time/ZoneOffset;)Ljava/time/OffsetDateTime;||',
'M|1|atZone|(Ljava/time/ZoneId;)Ljava/time/ZonedDateTime;||',
'M|1|isAfter|(Ljava/time/Instant;)Z||',
'M|1|isBefore|(Ljava/time/Instant;)Z||',
'C|17|java/time/Period|~OLjava/time/chrono/ChronoPeriod;~4Serializable;',
'F|25|ZERO|Ljava/time/Period;||',
'M|1|get|(Ljava/time/temporal/TemporalUnit;)J||',
'M|1|equals|(~O)Z||',
'M|1|toString|()~S||',
'M|1|hashCode|()I||',
'M|9|of|(III)Ljava/time/Period;||',
'M|9|from|(Ljava/time/temporal/TemporalAmount;)Ljava/time/Period;||',
'M|9|parse|(~1CharSequence;)Ljava/time/Period;||',
'M|9|between|(Ljava/time/LocalDate;Ljava/time/LocalDate;)Ljava/time/Period;||',
'M|1|normalized|()Ljava/time/Period;||',
'M|1|isZero|()Z||',
'M|1|getMonths|()I||',
'M|1|isNegative|()Z||',
'M|1|minus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/Period;||',
'M|1|plus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/Period;||',
'M|1|getUnits|()~2List;|()~2List<Ljava/time/temporal/TemporalUnit;>;|',
'M|1|negated|()Ljava/time/Period;||',
'M|1|multipliedBy|(I)Ljava/time/Period;||',
'M|1|plusDays|(J)Ljava/time/Period;||',
'M|9|ofDays|(I)Ljava/time/Period;||',
'M|1|minusDays|(J)Ljava/time/Period;||',
'M|1|addTo|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'M|1|subtractFrom|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'M|1|plusMonths|(J)Ljava/time/Period;||',
'M|1|toTotalMonths|()J||',
'M|1|getDays|()I||',
'M|1|plusYears|(J)Ljava/time/Period;||',
'M|1|minusMonths|(J)Ljava/time/Period;||',
'M|1|getChronology|()Ljava/time/chrono/IsoChronology;||',
'M|1|minusYears|(J)Ljava/time/Period;||',
'M|1|getYears|()I||',
'M|9|ofYears|(I)Ljava/time/Period;||',
'M|9|ofMonths|(I)Ljava/time/Period;||',
'M|9|ofWeeks|(I)Ljava/time/Period;||',
'M|1|withYears|(I)Ljava/time/Period;||',
'M|1|withMonths|(I)Ljava/time/Period;||',
'M|1|withDays|(I)Ljava/time/Period;||',
'C|16401|java/time/DayOfWeek|~1Enum<Ljava/time/DayOfWeek;>;Ljava/time/temporal/TemporalAccessor;Ljava/time/temporal/TemporalAdjuster;',
'F|16409|MONDAY|Ljava/time/DayOfWeek;||',
'F|16409|TUESDAY|Ljava/time/DayOfWeek;||',
'F|16409|WEDNESDAY|Ljava/time/DayOfWeek;||',
'F|16409|THURSDAY|Ljava/time/DayOfWeek;||',
'F|16409|FRIDAY|Ljava/time/DayOfWeek;||',
'F|16409|SATURDAY|Ljava/time/DayOfWeek;||',
'F|16409|SUNDAY|Ljava/time/DayOfWeek;||',
'M|1|get|(Ljava/time/temporal/TemporalField;)I||',
'M|1|getLong|(Ljava/time/temporal/TemporalField;)J||',
'M|1|getValue|()I||',
'M|9|of|(I)Ljava/time/DayOfWeek;||',
'M|9|from|(Ljava/time/temporal/TemporalAccessor;)Ljava/time/DayOfWeek;||',
'M|1|isSupported|(Ljava/time/temporal/TemporalField;)Z||',
'M|1|query|(Ljava/time/temporal/TemporalQuery;)~O|<R:~O>(Ljava/time/temporal/TemporalQuery<TR;>;)TR;|',
'M|1|range|(Ljava/time/temporal/TemporalField;)Ljava/time/temporal/ValueRange;||',
'M|1|getDisplayName|(Ljava/time/format/TextStyle;~2Locale;)~S||',
'M|1|minus|(J)Ljava/time/DayOfWeek;||',
'M|1|plus|(J)Ljava/time/DayOfWeek;||',
'M|1|adjustInto|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'C|16401|java/time/Month|~1Enum<Ljava/time/Month;>;Ljava/time/temporal/TemporalAccessor;Ljava/time/temporal/TemporalAdjuster;',
'F|16409|JANUARY|Ljava/time/Month;||',
'F|16409|FEBRUARY|Ljava/time/Month;||',
'F|16409|MARCH|Ljava/time/Month;||',
'F|16409|APRIL|Ljava/time/Month;||',
'F|16409|MAY|Ljava/time/Month;||',
'F|16409|JUNE|Ljava/time/Month;||',
'F|16409|JULY|Ljava/time/Month;||',
'F|16409|AUGUST|Ljava/time/Month;||',
'F|16409|SEPTEMBER|Ljava/time/Month;||',
'F|16409|OCTOBER|Ljava/time/Month;||',
'F|16409|NOVEMBER|Ljava/time/Month;||',
'F|16409|DECEMBER|Ljava/time/Month;||',
'M|1|firstMonthOfQuarter|()Ljava/time/Month;||',
'M|1|get|(Ljava/time/temporal/TemporalField;)I||',
'M|1|length|(Z)I||',
'M|1|getLong|(Ljava/time/temporal/TemporalField;)J||',
'M|1|getValue|()I||',
'M|9|of|(I)Ljava/time/Month;||',
'M|9|from|(Ljava/time/temporal/TemporalAccessor;)Ljava/time/Month;||',
'M|1|isSupported|(Ljava/time/temporal/TemporalField;)Z||',
'M|1|query|(Ljava/time/temporal/TemporalQuery;)~O|<R:~O>(Ljava/time/temporal/TemporalQuery<TR;>;)TR;|',
'M|1|range|(Ljava/time/temporal/TemporalField;)Ljava/time/temporal/ValueRange;||',
'M|1|minLength|()I||',
'M|1|getDisplayName|(Ljava/time/format/TextStyle;~2Locale;)~S||',
'M|1|minus|(J)Ljava/time/Month;||',
'M|1|plus|(J)Ljava/time/Month;||',
'M|1|adjustInto|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'M|1|firstDayOfYear|(Z)I||',
'M|1|maxLength|()I||',
'C|17|java/time/format/DateTimeFormatter|~O',
'F|25|ISO_LOCAL_DATE|Ljava/time/format/DateTimeFormatter;||',
'F|25|ISO_OFFSET_DATE|Ljava/time/format/DateTimeFormatter;||',
'F|25|ISO_DATE|Ljava/time/format/DateTimeFormatter;||',
'F|25|ISO_LOCAL_TIME|Ljava/time/format/DateTimeFormatter;||',
'F|25|ISO_OFFSET_TIME|Ljava/time/format/DateTimeFormatter;||',
'F|25|ISO_TIME|Ljava/time/format/DateTimeFormatter;||',
'F|25|ISO_LOCAL_DATE_TIME|Ljava/time/format/DateTimeFormatter;||',
'F|25|ISO_OFFSET_DATE_TIME|Ljava/time/format/DateTimeFormatter;||',
'F|25|ISO_ZONED_DATE_TIME|Ljava/time/format/DateTimeFormatter;||',
'F|25|ISO_DATE_TIME|Ljava/time/format/DateTimeFormatter;||',
'F|25|ISO_ORDINAL_DATE|Ljava/time/format/DateTimeFormatter;||',
'F|25|ISO_WEEK_DATE|Ljava/time/format/DateTimeFormatter;||',
'F|25|ISO_INSTANT|Ljava/time/format/DateTimeFormatter;||',
'F|25|BASIC_ISO_DATE|Ljava/time/format/DateTimeFormatter;||',
'F|25|RFC_1123_DATE_TIME|Ljava/time/format/DateTimeFormatter;||',
'M|1|toString|()~S||',
'M|1|format|(Ljava/time/temporal/TemporalAccessor;)~S||',
'M|1|parse|(~1CharSequence;Ljava/text/ParsePosition;)Ljava/time/temporal/TemporalAccessor;||',
'M|1|parse|(~1CharSequence;Ljava/time/temporal/TemporalQuery;)~O|<T:~O>(~1CharSequence;Ljava/time/temporal/TemporalQuery<TT;>;)TT;|',
'M|1|parse|(~1CharSequence;)Ljava/time/temporal/TemporalAccessor;||',
'M|1|getLocale|()~2Locale;||',
'M|1|getZone|()Ljava/time/ZoneId;||',
'M|1|withZone|(Ljava/time/ZoneId;)Ljava/time/format/DateTimeFormatter;||',
'M|1|getChronology|()Ljava/time/chrono/Chronology;||',
'M|1|formatTo|(Ljava/time/temporal/TemporalAccessor;~1Appendable;)V||',
'M|9|ofPattern|(~S)Ljava/time/format/DateTimeFormatter;||',
'M|9|ofPattern|(~S~2Locale;)Ljava/time/format/DateTimeFormatter;||',
'M|9|ofLocalizedDate|(Ljava/time/format/FormatStyle;)Ljava/time/format/DateTimeFormatter;||',
'M|9|ofLocalizedTime|(Ljava/time/format/FormatStyle;)Ljava/time/format/DateTimeFormatter;||',
'M|9|ofLocalizedDateTime|(Ljava/time/format/FormatStyle;Ljava/time/format/FormatStyle;)Ljava/time/format/DateTimeFormatter;||',
'M|9|ofLocalizedDateTime|(Ljava/time/format/FormatStyle;)Ljava/time/format/DateTimeFormatter;||',
'M|9|ofLocalizedPattern|(~S)Ljava/time/format/DateTimeFormatter;||',
'M|25|parsedExcessDays|()Ljava/time/temporal/TemporalQuery;|()Ljava/time/temporal/TemporalQuery<Ljava/time/Period;>;|',
'M|25|parsedLeapSecond|()Ljava/time/temporal/TemporalQuery;|()Ljava/time/temporal/TemporalQuery<~1Boolean;>;|',
'M|1|withLocale|(~2Locale;)Ljava/time/format/DateTimeFormatter;||',
'M|1|localizedBy|(~2Locale;)Ljava/time/format/DateTimeFormatter;||',
'M|1|getDecimalStyle|()Ljava/time/format/DecimalStyle;||',
'M|1|withDecimalStyle|(Ljava/time/format/DecimalStyle;)Ljava/time/format/DateTimeFormatter;||',
'M|1|withChronology|(Ljava/time/chrono/Chronology;)Ljava/time/format/DateTimeFormatter;||',
'M|1|getResolverStyle|()Ljava/time/format/ResolverStyle;||',
'M|1|withResolverStyle|(Ljava/time/format/ResolverStyle;)Ljava/time/format/DateTimeFormatter;||',
'M|1|getResolverFields|()~2Set;|()~2Set<Ljava/time/temporal/TemporalField;>;|',
'M|129|withResolverFields|([Ljava/time/temporal/TemporalField;)Ljava/time/format/DateTimeFormatter;||',
'M|1|withResolverFields|(~2Set;)Ljava/time/format/DateTimeFormatter;|(~2Set<Ljava/time/temporal/TemporalField;>;)Ljava/time/format/DateTimeFormatter;|',
'M|129|parseBest|(~1CharSequence;[Ljava/time/temporal/TemporalQuery;)Ljava/time/temporal/TemporalAccessor;|(~1CharSequence;[Ljava/time/temporal/TemporalQuery<*>;)Ljava/time/temporal/TemporalAccessor;|',
'M|1|parseUnresolved|(~1CharSequence;Ljava/text/ParsePosition;)Ljava/time/temporal/TemporalAccessor;||',
'M|1|toFormat|(Ljava/time/temporal/TemporalQuery;)Ljava/text/Format;|(Ljava/time/temporal/TemporalQuery<*>;)Ljava/text/Format;|',
'M|1|toFormat|()Ljava/text/Format;||',
'C|17|java/nio/file/Files|~O',
'M|9|size|(Ljava/nio/file/Path;)J||java/io/IOException',
'M|9|isHidden|(Ljava/nio/file/Path;)Z||java/io/IOException',
'M|9|mismatch|(Ljava/nio/file/Path;Ljava/nio/file/Path;)J||java/io/IOException',
'M|9|lines|(Ljava/nio/file/Path;)~5Stream;|(Ljava/nio/file/Path;)~5Stream<~S>;|java/io/IOException',
'M|9|lines|(Ljava/nio/file/Path;Ljava/nio/charset/Charset;)~5Stream;|(Ljava/nio/file/Path;Ljava/nio/charset/Charset;)~5Stream<~S>;|java/io/IOException',
'M|9|list|(Ljava/nio/file/Path;)~5Stream;|(Ljava/nio/file/Path;)~5Stream<Ljava/nio/file/Path;>;|java/io/IOException',
'M|137|find|(Ljava/nio/file/Path;I~3BiPredicate;[Ljava/nio/file/FileVisitOption;)~5Stream;|(Ljava/nio/file/Path;I~3BiPredicate<Ljava/nio/file/Path;Ljava/nio/file/attribute/BasicFileAttributes;>;[Ljava/nio/file/FileVisitOption;)~5Stream<Ljava/nio/file/Path;>;|java/io/IOException',
'M|137|write|(Ljava/nio/file/Path;[B[Ljava/nio/file/OpenOption;)Ljava/nio/file/Path;||java/io/IOException',
'M|137|write|(Ljava/nio/file/Path;~1Iterable;Ljava/nio/charset/Charset;[Ljava/nio/file/OpenOption;)Ljava/nio/file/Path;|(Ljava/nio/file/Path;~1Iterable<+~1CharSequence;>;Ljava/nio/charset/Charset;[Ljava/nio/file/OpenOption;)Ljava/nio/file/Path;|java/io/IOException',
'M|137|write|(Ljava/nio/file/Path;~1Iterable;[Ljava/nio/file/OpenOption;)Ljava/nio/file/Path;|(Ljava/nio/file/Path;~1Iterable<+~1CharSequence;>;[Ljava/nio/file/OpenOption;)Ljava/nio/file/Path;|java/io/IOException',
'M|9|delete|(Ljava/nio/file/Path;)V||java/io/IOException',
'M|9|readAllBytes|(Ljava/nio/file/Path;)[B||java/io/IOException',
'M|137|copy|(Ljava/nio/file/Path;Ljava/nio/file/Path;[Ljava/nio/file/CopyOption;)Ljava/nio/file/Path;||java/io/IOException',
'M|9|copy|(Ljava/nio/file/Path;~4OutputStream;)J||java/io/IOException',
'M|137|copy|(~4InputStream;Ljava/nio/file/Path;[Ljava/nio/file/CopyOption;)J||java/io/IOException',
'M|137|walk|(Ljava/nio/file/Path;[Ljava/nio/file/FileVisitOption;)~5Stream;|(Ljava/nio/file/Path;[Ljava/nio/file/FileVisitOption;)~5Stream<Ljava/nio/file/Path;>;|java/io/IOException',
'M|137|walk|(Ljava/nio/file/Path;I[Ljava/nio/file/FileVisitOption;)~5Stream;|(Ljava/nio/file/Path;I[Ljava/nio/file/FileVisitOption;)~5Stream<Ljava/nio/file/Path;>;|java/io/IOException',
'M|137|exists|(Ljava/nio/file/Path;[Ljava/nio/file/LinkOption;)Z||',
'M|137|isDirectory|(Ljava/nio/file/Path;[Ljava/nio/file/LinkOption;)Z||',
'M|137|getOwner|(Ljava/nio/file/Path;[Ljava/nio/file/LinkOption;)Ljava/nio/file/attribute/UserPrincipal;||java/io/IOException',
'M|137|getLastModifiedTime|(Ljava/nio/file/Path;[Ljava/nio/file/LinkOption;)Ljava/nio/file/attribute/FileTime;||java/io/IOException',
'M|137|createDirectory|(Ljava/nio/file/Path;[Ljava/nio/file/attribute/FileAttribute;)Ljava/nio/file/Path;|(Ljava/nio/file/Path;[Ljava/nio/file/attribute/FileAttribute<*>;)Ljava/nio/file/Path;|java/io/IOException',
'M|9|setLastModifiedTime|(Ljava/nio/file/Path;Ljava/nio/file/attribute/FileTime;)Ljava/nio/file/Path;||java/io/IOException',
'M|137|createTempFile|(~S~S[Ljava/nio/file/attribute/FileAttribute;)Ljava/nio/file/Path;|(~S~S[Ljava/nio/file/attribute/FileAttribute<*>;)Ljava/nio/file/Path;|java/io/IOException',
'M|137|createTempFile|(Ljava/nio/file/Path;~S~S[Ljava/nio/file/attribute/FileAttribute;)Ljava/nio/file/Path;|(Ljava/nio/file/Path;~S~S[Ljava/nio/file/attribute/FileAttribute<*>;)Ljava/nio/file/Path;|java/io/IOException',
'M|137|isRegularFile|(Ljava/nio/file/Path;[Ljava/nio/file/LinkOption;)Z||',
'M|137|newInputStream|(Ljava/nio/file/Path;[Ljava/nio/file/OpenOption;)~4InputStream;||java/io/IOException',
'M|137|newOutputStream|(Ljava/nio/file/Path;[Ljava/nio/file/OpenOption;)~4OutputStream;||java/io/IOException',
'M|137|newByteChannel|(Ljava/nio/file/Path;[Ljava/nio/file/OpenOption;)Ljava/nio/channels/SeekableByteChannel;||java/io/IOException',
'M|137|newByteChannel|(Ljava/nio/file/Path;~2Set;[Ljava/nio/file/attribute/FileAttribute;)Ljava/nio/channels/SeekableByteChannel;|(Ljava/nio/file/Path;~2Set<+Ljava/nio/file/OpenOption;>;[Ljava/nio/file/attribute/FileAttribute<*>;)Ljava/nio/channels/SeekableByteChannel;|java/io/IOException',
'M|9|newDirectoryStream|(Ljava/nio/file/Path;Ljava/nio/file/DirectoryStream$Filter;)Ljava/nio/file/DirectoryStream;|(Ljava/nio/file/Path;Ljava/nio/file/DirectoryStream$Filter<-Ljava/nio/file/Path;>;)Ljava/nio/file/DirectoryStream<Ljava/nio/file/Path;>;|java/io/IOException',
'M|9|newDirectoryStream|(Ljava/nio/file/Path;)Ljava/nio/file/DirectoryStream;|(Ljava/nio/file/Path;)Ljava/nio/file/DirectoryStream<Ljava/nio/file/Path;>;|java/io/IOException',
'M|9|newDirectoryStream|(Ljava/nio/file/Path;~S)Ljava/nio/file/DirectoryStream;|(Ljava/nio/file/Path;~S)Ljava/nio/file/DirectoryStream<Ljava/nio/file/Path;>;|java/io/IOException',
'M|137|createTempDirectory|(Ljava/nio/file/Path;~S[Ljava/nio/file/attribute/FileAttribute;)Ljava/nio/file/Path;|(Ljava/nio/file/Path;~S[Ljava/nio/file/attribute/FileAttribute<*>;)Ljava/nio/file/Path;|java/io/IOException',
'M|137|createTempDirectory|(~S[Ljava/nio/file/attribute/FileAttribute;)Ljava/nio/file/Path;|(~S[Ljava/nio/file/attribute/FileAttribute<*>;)Ljava/nio/file/Path;|java/io/IOException',
'M|137|createSymbolicLink|(Ljava/nio/file/Path;Ljava/nio/file/Path;[Ljava/nio/file/attribute/FileAttribute;)Ljava/nio/file/Path;|(Ljava/nio/file/Path;Ljava/nio/file/Path;[Ljava/nio/file/attribute/FileAttribute<*>;)Ljava/nio/file/Path;|java/io/IOException',
'M|9|createLink|(Ljava/nio/file/Path;Ljava/nio/file/Path;)Ljava/nio/file/Path;||java/io/IOException',
'M|9|deleteIfExists|(Ljava/nio/file/Path;)Z||java/io/IOException',
'M|137|move|(Ljava/nio/file/Path;Ljava/nio/file/Path;[Ljava/nio/file/CopyOption;)Ljava/nio/file/Path;||java/io/IOException',
'M|9|readSymbolicLink|(Ljava/nio/file/Path;)Ljava/nio/file/Path;||java/io/IOException',
'M|9|getFileStore|(Ljava/nio/file/Path;)Ljava/nio/file/FileStore;||java/io/IOException',
'M|9|isSameFile|(Ljava/nio/file/Path;Ljava/nio/file/Path;)Z||java/io/IOException',
'M|9|probeContentType|(Ljava/nio/file/Path;)~S||java/io/IOException',
'M|137|getFileAttributeView|(Ljava/nio/file/Path;~1Class;[Ljava/nio/file/LinkOption;)Ljava/nio/file/attribute/FileAttributeView;|<V::Ljava/nio/file/attribute/FileAttributeView;>(Ljava/nio/file/Path;~1Class<TV;>;[Ljava/nio/file/LinkOption;)TV;|',
'M|137|readAttributes|(Ljava/nio/file/Path;~S[Ljava/nio/file/LinkOption;)~2Map;|(Ljava/nio/file/Path;~S[Ljava/nio/file/LinkOption;)~2Map<~S~O>;|java/io/IOException',
'M|137|readAttributes|(Ljava/nio/file/Path;~1Class;[Ljava/nio/file/LinkOption;)Ljava/nio/file/attribute/BasicFileAttributes;|<A::Ljava/nio/file/attribute/BasicFileAttributes;>(Ljava/nio/file/Path;~1Class<TA;>;[Ljava/nio/file/LinkOption;)TA;|java/io/IOException',
'M|137|setAttribute|(Ljava/nio/file/Path;~S~O[Ljava/nio/file/LinkOption;)Ljava/nio/file/Path;||java/io/IOException',
'M|9|setOwner|(Ljava/nio/file/Path;Ljava/nio/file/attribute/UserPrincipal;)Ljava/nio/file/Path;||java/io/IOException',
'M|9|isSymbolicLink|(Ljava/nio/file/Path;)Z||',
'M|9|isReadable|(Ljava/nio/file/Path;)Z||',
'M|9|isWritable|(Ljava/nio/file/Path;)Z||',
'M|9|isExecutable|(Ljava/nio/file/Path;)Z||',
'M|9|walkFileTree|(Ljava/nio/file/Path;~2Set;ILjava/nio/file/FileVisitor;)Ljava/nio/file/Path;|(Ljava/nio/file/Path;~2Set<Ljava/nio/file/FileVisitOption;>;ILjava/nio/file/FileVisitor<-Ljava/nio/file/Path;>;)Ljava/nio/file/Path;|java/io/IOException',
'M|9|walkFileTree|(Ljava/nio/file/Path;Ljava/nio/file/FileVisitor;)Ljava/nio/file/Path;|(Ljava/nio/file/Path;Ljava/nio/file/FileVisitor<-Ljava/nio/file/Path;>;)Ljava/nio/file/Path;|java/io/IOException',
'M|9|newBufferedReader|(Ljava/nio/file/Path;)~4BufferedReader;||java/io/IOException',
'M|9|newBufferedReader|(Ljava/nio/file/Path;Ljava/nio/charset/Charset;)~4BufferedReader;||java/io/IOException',
'M|137|newBufferedWriter|(Ljava/nio/file/Path;[Ljava/nio/file/OpenOption;)~4BufferedWriter;||java/io/IOException',
'M|137|newBufferedWriter|(Ljava/nio/file/Path;Ljava/nio/charset/Charset;[Ljava/nio/file/OpenOption;)~4BufferedWriter;||java/io/IOException',
'M|9|readString|(Ljava/nio/file/Path;Ljava/nio/charset/Charset;)~S||java/io/IOException',
'M|9|readString|(Ljava/nio/file/Path;)~S||java/io/IOException',
'M|9|readAllLines|(Ljava/nio/file/Path;Ljava/nio/charset/Charset;)~2List;|(Ljava/nio/file/Path;Ljava/nio/charset/Charset;)~2List<~S>;|java/io/IOException',
'M|9|readAllLines|(Ljava/nio/file/Path;)~2List;|(Ljava/nio/file/Path;)~2List<~S>;|java/io/IOException',
'M|137|writeString|(Ljava/nio/file/Path;~1CharSequence;Ljava/nio/charset/Charset;[Ljava/nio/file/OpenOption;)Ljava/nio/file/Path;||java/io/IOException',
'M|137|writeString|(Ljava/nio/file/Path;~1CharSequence;[Ljava/nio/file/OpenOption;)Ljava/nio/file/Path;||java/io/IOException',
'M|137|createFile|(Ljava/nio/file/Path;[Ljava/nio/file/attribute/FileAttribute;)Ljava/nio/file/Path;|(Ljava/nio/file/Path;[Ljava/nio/file/attribute/FileAttribute<*>;)Ljava/nio/file/Path;|java/io/IOException',
'M|137|createDirectories|(Ljava/nio/file/Path;[Ljava/nio/file/attribute/FileAttribute;)Ljava/nio/file/Path;|(Ljava/nio/file/Path;[Ljava/nio/file/attribute/FileAttribute<*>;)Ljava/nio/file/Path;|java/io/IOException',
'M|137|getAttribute|(Ljava/nio/file/Path;~S[Ljava/nio/file/LinkOption;)~O||java/io/IOException',
'M|137|getPosixFilePermissions|(Ljava/nio/file/Path;[Ljava/nio/file/LinkOption;)~2Set;|(Ljava/nio/file/Path;[Ljava/nio/file/LinkOption;)~2Set<Ljava/nio/file/attribute/PosixFilePermission;>;|java/io/IOException',
'M|9|setPosixFilePermissions|(Ljava/nio/file/Path;~2Set;)Ljava/nio/file/Path;|(Ljava/nio/file/Path;~2Set<Ljava/nio/file/attribute/PosixFilePermission;>;)Ljava/nio/file/Path;|java/io/IOException',
'M|137|notExists|(Ljava/nio/file/Path;[Ljava/nio/file/LinkOption;)Z||',
'C|17|java/nio/file/Paths|~O',
'M|137|get|(~S[~S)Ljava/nio/file/Path;||',
'M|9|get|(Ljava/net/URI;)Ljava/nio/file/Path;||',
'C|1537|java/nio/file/Path|~O~1Comparable<Ljava/nio/file/Path;>;~1Iterable<Ljava/nio/file/Path;>;Ljava/nio/file/Watchable;',
'M|1025|getName|(I)Ljava/nio/file/Path;||',
'M|1025|equals|(~O)Z||',
'M|1025|toString|()~S||',
'M|1025|hashCode|()I||',
'M|1025|compareTo|(Ljava/nio/file/Path;)I||',
'M|65537|startsWith|(~S)Z||',
'M|1025|startsWith|(Ljava/nio/file/Path;)Z||',
'M|65537|iterator|()~2Iterator;|()~2Iterator<Ljava/nio/file/Path;>;|',
'M|137|of|(~S[~S)Ljava/nio/file/Path;||',
'M|9|of|(Ljava/net/URI;)Ljava/nio/file/Path;||',
'M|65537|endsWith|(~S)Z||',
'M|1025|endsWith|(Ljava/nio/file/Path;)Z||',
'M|1153|register|(Ljava/nio/file/WatchService;[Ljava/nio/file/WatchEvent$Kind;[Ljava/nio/file/WatchEvent$Modifier;)Ljava/nio/file/WatchKey;|(Ljava/nio/file/WatchService;[Ljava/nio/file/WatchEvent$Kind<*>;[Ljava/nio/file/WatchEvent$Modifier;)Ljava/nio/file/WatchKey;|java/io/IOException',
'M|65665|register|(Ljava/nio/file/WatchService;[Ljava/nio/file/WatchEvent$Kind;)Ljava/nio/file/WatchKey;|(Ljava/nio/file/WatchService;[Ljava/nio/file/WatchEvent$Kind<*>;)Ljava/nio/file/WatchKey;|java/io/IOException',
'M|1025|isAbsolute|()Z||',
'M|1025|resolve|(Ljava/nio/file/Path;)Ljava/nio/file/Path;||',
'M|65537|resolve|(~S)Ljava/nio/file/Path;||',
'M|1025|getParent|()Ljava/nio/file/Path;||',
'M|1025|getRoot|()Ljava/nio/file/Path;||',
'M|1153|toRealPath|([Ljava/nio/file/LinkOption;)Ljava/nio/file/Path;||java/io/IOException',
'M|65537|toFile|()~4File;||',
'M|1025|getFileName|()Ljava/nio/file/Path;||',
'M|1025|normalize|()Ljava/nio/file/Path;||',
'M|1025|getFileSystem|()Ljava/nio/file/FileSystem;||',
'M|1025|relativize|(Ljava/nio/file/Path;)Ljava/nio/file/Path;||',
'M|1025|getNameCount|()I||',
'M|1025|toAbsolutePath|()Ljava/nio/file/Path;||',
'M|65537|resolveSibling|(Ljava/nio/file/Path;)Ljava/nio/file/Path;||',
'M|65537|resolveSibling|(~S)Ljava/nio/file/Path;||',
'M|1025|subpath|(II)Ljava/nio/file/Path;||',
'M|1025|toUri|()Ljava/net/URI;||',
'C|17|java/nio/charset/StandardCharsets|~O',
'F|25|US_ASCII|Ljava/nio/charset/Charset;||',
'F|25|ISO_8859_1|Ljava/nio/charset/Charset;||',
'F|25|UTF_8|Ljava/nio/charset/Charset;||',
'F|25|UTF_16BE|Ljava/nio/charset/Charset;||',
'F|25|UTF_16LE|Ljava/nio/charset/Charset;||',
'F|25|UTF_16|Ljava/nio/charset/Charset;||',
'C|1025|java/nio/charset/Charset|~O~1Comparable<Ljava/nio/charset/Charset;>;',
'M|4|<init>|(~S[~S)V||',
'M|17|name|()~S||',
'M|9|forName|(~SLjava/nio/charset/Charset;)Ljava/nio/charset/Charset;||',
'M|9|forName|(~S)Ljava/nio/charset/Charset;||',
'M|17|equals|(~O)Z||',
'M|17|toString|()~S||',
'M|17|hashCode|()I||',
'M|17|compareTo|(Ljava/nio/charset/Charset;)I||',
'M|1025|newDecoder|()Ljava/nio/charset/CharsetDecoder;||',
'M|17|decode|(Ljava/nio/ByteBuffer;)Ljava/nio/CharBuffer;||',
'M|1025|newEncoder|()Ljava/nio/charset/CharsetEncoder;||',
'M|17|encode|(Ljava/nio/CharBuffer;)Ljava/nio/ByteBuffer;||',
'M|17|encode|(~S)Ljava/nio/ByteBuffer;||',
'M|9|defaultCharset|()Ljava/nio/charset/Charset;||',
'M|1|canEncode|()Z||',
'M|1025|contains|(Ljava/nio/charset/Charset;)Z||',
'M|17|isRegistered|()Z||',
'M|9|isSupported|(~S)Z||',
'M|17|aliases|()~2Set;|()~2Set<~S>;|',
'M|9|availableCharsets|()~2SortedMap;|()~2SortedMap<~SLjava/nio/charset/Charset;>;|',
'M|1|displayName|(~2Locale;)~S||',
'M|1|displayName|()~S||',
'C|17|java/util/regex/Pattern|~O~4Serializable;',
'F|25|UNIX_LINES|I||I1',
'F|25|CASE_INSENSITIVE|I||I2',
'F|25|COMMENTS|I||I4',
'F|25|MULTILINE|I||I8',
'F|25|LITERAL|I||I16',
'F|25|DOTALL|I||I32',
'F|25|UNICODE_CASE|I||I64',
'F|25|CANON_EQ|I||I128',
'F|25|UNICODE_CHARACTER_CLASS|I||I256',
'M|1|toString|()~S||',
'M|1|flags|()I||',
'M|9|matches|(~S~1CharSequence;)Z||',
'M|9|compile|(~S)~2regex/Pattern;||',
'M|9|compile|(~SI)~2regex/Pattern;||',
'M|1|matcher|(~1CharSequence;)~2regex/Matcher;||',
'M|1|split|(~1CharSequence;I)[~S||',
'M|1|split|(~1CharSequence;)[~S||',
'M|1|splitWithDelimiters|(~1CharSequence;I)[~S||',
'M|1|pattern|()~S||',
'M|9|quote|(~S)~S||',
'M|1|namedGroups|()~2Map;|()~2Map<~S~1Integer;>;|',
'M|1|asPredicate|()~3Predicate;|()~3Predicate<~S>;|',
'M|1|asMatchPredicate|()~3Predicate;|()~3Predicate<~S>;|',
'M|1|splitAsStream|(~1CharSequence;)~5Stream;|(~1CharSequence;)~5Stream<~S>;|',
'C|17|java/util/regex/Matcher|~O~2regex/MatchResult;',
'M|1|group|(I)~S||',
'M|1|group|()~S||',
'M|1|group|(~S)~S||',
'M|1|reset|(~1CharSequence;)~2regex/Matcher;||',
'M|1|reset|()~2regex/Matcher;||',
'M|1|toString|()~S||',
'M|1|end|(I)I||',
'M|1|end|()I||',
'M|1|end|(~S)I||',
'M|1|matches|()Z||',
'M|1|replaceFirst|(~S)~S||',
'M|1|replaceFirst|(~3Function;)~S|(~3Function<~2regex/MatchResult;~S>;)~S|',
'M|1|replaceAll|(~S)~S||',
'M|1|replaceAll|(~3Function;)~S|(~3Function<~2regex/MatchResult;~S>;)~S|',
'M|1|pattern|()~2regex/Pattern;||',
'M|1|find|()Z||',
'M|1|find|(I)Z||',
'M|1|start|(I)I||',
'M|1|start|(~S)I||',
'M|1|start|()I||',
'M|1|results|()~5Stream;|()~5Stream<~2regex/MatchResult;>;|',
'M|1|region|(II)~2regex/Matcher;||',
'M|1|namedGroups|()~2Map;|()~2Map<~S~1Integer;>;|',
'M|1|groupCount|()I||',
'M|1|hasMatch|()Z||',
'M|1|appendReplacement|(~1StringBuffer;~S)~2regex/Matcher;||',
'M|1|appendReplacement|(~1StringBuilder;~S)~2regex/Matcher;||',
'M|1|appendTail|(~1StringBuffer;)~1StringBuffer;||',
'M|1|appendTail|(~1StringBuilder;)~1StringBuilder;||',
'M|1|regionStart|()I||',
'M|1|regionEnd|()I||',
'M|1|hitEnd|()Z||',
'M|1|requireEnd|()Z||',
'M|1|toMatchResult|()~2regex/MatchResult;||',
'M|1|usePattern|(~2regex/Pattern;)~2regex/Matcher;||',
'M|1|lookingAt|()Z||',
'M|9|quoteReplacement|(~S)~S||',
'M|1|hasTransparentBounds|()Z||',
'M|1|useTransparentBounds|(Z)~2regex/Matcher;||',
'M|1|hasAnchoringBounds|()Z||',
'M|1|useAnchoringBounds|(Z)~2regex/Matcher;||',
'C|1537|java/util/regex/MatchResult|~O',
'M|1025|group|(I)~S||',
'M|65537|group|(~S)~S||',
'M|1025|group|()~S||',
'M|65537|end|(~S)I||',
'M|1025|end|(I)I||',
'M|1025|end|()I||',
'M|1025|start|()I||',
'M|65537|start|(~S)I||',
'M|1025|start|(I)I||',
'M|65537|namedGroups|()~2Map;|()~2Map<~S~1Integer;>;|',
'M|1025|groupCount|()I||',
'M|65537|hasMatch|()Z||',
'C|9729|java/lang/annotation/Retention|~O~1annotation/Annotation;',
'M|1025|value|()~1annotation/RetentionPolicy;||',
'C|16401|java/lang/annotation/RetentionPolicy|~1Enum<~1annotation/RetentionPolicy;>;',
'F|16409|SOURCE|~1annotation/RetentionPolicy;||',
'F|16409|CLASS|~1annotation/RetentionPolicy;||',
'F|16409|RUNTIME|~1annotation/RetentionPolicy;||',
'C|9729|java/lang/annotation/Target|~O~1annotation/Annotation;',
'M|1025|value|()[~1annotation/ElementType;||',
'C|16401|java/lang/annotation/ElementType|~1Enum<~1annotation/ElementType;>;',
'F|16409|TYPE|~1annotation/ElementType;||',
'F|16409|FIELD|~1annotation/ElementType;||',
'F|16409|METHOD|~1annotation/ElementType;||',
'F|16409|PARAMETER|~1annotation/ElementType;||',
'F|16409|CONSTRUCTOR|~1annotation/ElementType;||',
'F|16409|LOCAL_VARIABLE|~1annotation/ElementType;||',
'F|16409|ANNOTATION_TYPE|~1annotation/ElementType;||',
'F|16409|PACKAGE|~1annotation/ElementType;||',
'F|16409|TYPE_PARAMETER|~1annotation/ElementType;||',
'F|16409|TYPE_USE|~1annotation/ElementType;||',
'F|16409|MODULE|~1annotation/ElementType;||',
'F|16409|RECORD_COMPONENT|~1annotation/ElementType;||',
'C|9729|java/lang/annotation/Documented|~O~1annotation/Annotation;',
'C|9729|java/lang/annotation/Inherited|~O~1annotation/Annotation;',
'C|9729|java/lang/annotation/Repeatable|~O~1annotation/Annotation;',
'M|1025|value|()~1Class;|()~1Class<+~1annotation/Annotation;>;|',
'C|9729|java/lang/annotation/Native|~O~1annotation/Annotation;',
'C|1537|java/lang/constant/Constable|~O',
'M|1025|describeConstable|()~2Optional;|()~2Optional<+~1constant/ConstantDesc;>;|',
'C|1537|java/lang/constant/ConstantDesc|~O',
'M|1025|resolveConstantDesc|(~1invoke/MethodHandles$Lookup;)~O||java/lang/ReflectiveOperationException',
'C|1537|java/lang/reflect/GenericDeclaration|~O~1reflect/AnnotatedElement;',
'M|1025|getTypeParameters|()[~1reflect/TypeVariable;|()[~1reflect/TypeVariable<*>;|',
'C|1537|java/lang/reflect/Type|~O',
'M|65537|getTypeName|()~S||',
'C|1537|java/lang/reflect/AnnotatedElement|~O',
'M|65537|isAnnotationPresent|(~1Class;)Z|(~1Class<+~1annotation/Annotation;>;)Z|',
'M|1025|getAnnotation|(~1Class;)~1annotation/Annotation;|<T::~1annotation/Annotation;>(~1Class<TT;>;)TT;|',
'M|65537|getAnnotationsByType|(~1Class;)[~1annotation/Annotation;|<T::~1annotation/Annotation;>(~1Class<TT;>;)[TT;|',
'M|1025|getAnnotations|()[~1annotation/Annotation;||',
'M|65537|getDeclaredAnnotation|(~1Class;)~1annotation/Annotation;|<T::~1annotation/Annotation;>(~1Class<TT;>;)TT;|',
'M|65537|getDeclaredAnnotationsByType|(~1Class;)[~1annotation/Annotation;|<T::~1annotation/Annotation;>(~1Class<TT;>;)[TT;|',
'M|1025|getDeclaredAnnotations|()[~1annotation/Annotation;||',
'C|1537|java/lang/invoke/TypeDescriptor$OfField|<F::~1invoke/TypeDescriptor$OfField<TF;>;>~O~1invoke/TypeDescriptor;',
'M|1025|isArray|()Z||',
'M|1025|isPrimitive|()Z||',
'M|1025|componentType|()~1invoke/TypeDescriptor$OfField;|()TF;|',
'M|1025|arrayType|()~1invoke/TypeDescriptor$OfField;|()TF;|',
'C|1537|java/lang/annotation/Annotation|~O',
'M|1025|equals|(~O)Z||',
'M|1025|toString|()~S||',
'M|1025|hashCode|()I||',
'M|1025|annotationType|()~1Class;|()~1Class<+~1annotation/Annotation;>;|',
'C|1025|java/lang/reflect/Executable|~1reflect/AccessibleObject;~1reflect/Member;~1reflect/GenericDeclaration;',
'M|1025|getName|()~S||',
'M|1025|getModifiers|()I||',
'M|1025|getTypeParameters|()[~1reflect/TypeVariable;|()[~1reflect/TypeVariable<*>;|',
'M|1025|getParameterTypes|()[~1Class;|()[~1Class<*>;|',
'M|1|isSynthetic|()Z||',
'M|1025|toGenericString|()~S||',
'M|1|accessFlags|()~2Set;|()~2Set<~1reflect/AccessFlag;>;|',
'M|1025|getDeclaringClass|()~1Class;|()~1Class<*>;|',
'M|1|getAnnotation|(~1Class;)~1annotation/Annotation;|<T::~1annotation/Annotation;>(~1Class<TT;>;)TT;|',
'M|1|getAnnotationsByType|(~1Class;)[~1annotation/Annotation;|<T::~1annotation/Annotation;>(~1Class<TT;>;)[TT;|',
'M|1|getDeclaredAnnotations|()[~1annotation/Annotation;||',
'M|1|isVarArgs|()Z||',
'M|1|getAnnotatedParameterTypes|()[~1reflect/AnnotatedType;||',
'M|1025|getParameterCount|()I||',
'M|1025|getParameterAnnotations|()[[~1annotation/Annotation;||',
'M|1|getGenericParameterTypes|()[~1reflect/Type;||',
'M|1|getGenericExceptionTypes|()[~1reflect/Type;||',
'M|1025|getExceptionTypes|()[~1Class;|()[~1Class<*>;|',
'M|1025|getAnnotatedReturnType|()~1reflect/AnnotatedType;||',
'M|1|getParameters|()[~1reflect/Parameter;||',
'M|1|getAnnotatedReceiverType|()~1reflect/AnnotatedType;||',
'M|1|getAnnotatedExceptionTypes|()[~1reflect/AnnotatedType;||',
'C|1|java/lang/reflect/AccessibleObject|~O~1reflect/AnnotatedElement;',
'M|4|<init>|()V||',
'M|1|isAnnotationPresent|(~1Class;)Z|(~1Class<+~1annotation/Annotation;>;)Z|',
'M|1|getAnnotation|(~1Class;)~1annotation/Annotation;|<T::~1annotation/Annotation;>(~1Class<TT;>;)TT;|',
'M|1|getAnnotationsByType|(~1Class;)[~1annotation/Annotation;|<T::~1annotation/Annotation;>(~1Class<TT;>;)[TT;|',
'M|1|getAnnotations|()[~1annotation/Annotation;||',
'M|1|getDeclaredAnnotation|(~1Class;)~1annotation/Annotation;|<T::~1annotation/Annotation;>(~1Class<TT;>;)TT;|',
'M|1|getDeclaredAnnotationsByType|(~1Class;)[~1annotation/Annotation;|<T::~1annotation/Annotation;>(~1Class<TT;>;)[TT;|',
'M|1|getDeclaredAnnotations|()[~1annotation/Annotation;||',
'M|9|setAccessible|([~1reflect/AccessibleObject;Z)V||',
'M|1|setAccessible|(Z)V||',
'M|17|trySetAccessible|()Z||',
'M|17|canAccess|(~O)Z||',
'M|1|isAccessible|()Z||',
'C|1537|java/lang/reflect/Member|~O',
'F|25|PUBLIC|I||I0',
'F|25|DECLARED|I||I1',
'M|1025|getName|()~S||',
'M|1025|getModifiers|()I||',
'M|1025|isSynthetic|()Z||',
'M|65537|accessFlags|()~2Set;|()~2Set<~1reflect/AccessFlag;>;|',
'M|1025|getDeclaringClass|()~1Class;|()~1Class<*>;|',
'C|1537|java/io/ObjectInput|~O~4DataInput;~1AutoCloseable;',
'M|1025|readObject|()~O||java/lang/ClassNotFoundException,java/io/IOException',
'M|1025|read|([BII)I||java/io/IOException',
'M|1025|read|([B)I||java/io/IOException',
'M|1025|read|()I||java/io/IOException',
'M|1025|close|()V||java/io/IOException',
'M|1025|skip|(J)J||java/io/IOException',
'M|1025|available|()I||java/io/IOException',
'C|1537|java/io/ObjectStreamConstants|~O',
'F|25|STREAM_MAGIC|S||I-21267',
'F|25|STREAM_VERSION|S||I5',
'F|25|TC_BASE|B||I112',
'F|25|TC_NULL|B||I112',
'F|25|TC_REFERENCE|B||I113',
'F|25|TC_CLASSDESC|B||I114',
'F|25|TC_OBJECT|B||I115',
'F|25|TC_STRING|B||I116',
'F|25|TC_ARRAY|B||I117',
'F|25|TC_CLASS|B||I118',
'F|25|TC_BLOCKDATA|B||I119',
'F|25|TC_ENDBLOCKDATA|B||I120',
'F|25|TC_RESET|B||I121',
'F|25|TC_BLOCKDATALONG|B||I122',
'F|25|TC_EXCEPTION|B||I123',
'F|25|TC_LONGSTRING|B||I124',
'F|25|TC_PROXYCLASSDESC|B||I125',
'F|25|TC_ENUM|B||I126',
'F|25|TC_MAX|B||I126',
'F|25|baseWireHandle|I||I8257536',
'F|25|SC_WRITE_METHOD|B||I1',
'F|25|SC_BLOCK_DATA|B||I8',
'F|25|SC_SERIALIZABLE|B||I2',
'F|25|SC_EXTERNALIZABLE|B||I4',
'F|25|SC_ENUM|B||I16',
'F|25|SUBSTITUTION_PERMISSION|~4SerializablePermission;||',
'F|25|SUBCLASS_IMPLEMENTATION_PERMISSION|~4SerializablePermission;||',
'F|25|SERIAL_FILTER_PERMISSION|~4SerializablePermission;||',
'F|25|PROTOCOL_VERSION_1|I||I1',
'F|25|PROTOCOL_VERSION_2|I||I2',
'C|1537|java/io/ObjectOutput|~O~4DataOutput;~1AutoCloseable;',
'M|1025|flush|()V||java/io/IOException',
'M|1025|write|([BII)V||java/io/IOException',
'M|1025|write|([B)V||java/io/IOException',
'M|1025|write|(I)V||java/io/IOException',
'M|1025|writeObject|(~O)V||java/io/IOException',
'M|1025|close|()V||java/io/IOException',
'C|1537|java/util/SequencedCollection|<E:~O>~O~2Collection<TE;>;',
'M|65537|getFirst|()~O|()TE;|',
'M|65537|getLast|()~O|()TE;|',
'M|65537|addFirst|(~O)V|(TE;)V|',
'M|65537|addLast|(~O)V|(TE;)V|',
'M|65537|removeFirst|()~O|()TE;|',
'M|65537|removeLast|()~O|()TE;|',
'M|1025|reversed|()~2SequencedCollection;|()~2SequencedCollection<TE;>;|',
'C|1537|java/util/SequencedMap|<K:~OV:~O>~O~2Map<TK;TV;>;',
'M|1025|reversed|()~2SequencedMap;|()~2SequencedMap<TK;TV;>;|',
'M|65537|sequencedKeySet|()~2SequencedSet;|()~2SequencedSet<TK;>;|',
'M|65537|sequencedValues|()~2SequencedCollection;|()~2SequencedCollection<TV;>;|',
'M|65537|sequencedEntrySet|()~2SequencedSet;|()~2SequencedSet<~2Map$Entry<TK;TV;>;>;|',
'M|65537|putFirst|(~O~O)~O|(TK;TV;)TV;|',
'M|65537|putLast|(~O~O)~O|(TK;TV;)TV;|',
'M|65537|firstEntry|()~2Map$Entry;|()~2Map$Entry<TK;TV;>;|',
'M|65537|lastEntry|()~2Map$Entry;|()~2Map$Entry<TK;TV;>;|',
'M|65537|pollFirstEntry|()~2Map$Entry;|()~2Map$Entry<TK;TV;>;|',
'M|65537|pollLastEntry|()~2Map$Entry;|()~2Map$Entry<TK;TV;>;|',
'C|1537|java/util/SequencedSet|<E:~O>~O~2SequencedCollection<TE;>;~2Set<TE;>;',
'M|1025|reversed|()~2SequencedSet;|()~2SequencedSet<TE;>;|',
'C|1537|java/util/random/RandomGenerator|~O',
'M|9|getDefault|()~2random/RandomGenerator;||',
'M|9|of|(~S)~2random/RandomGenerator;||',
'M|65537|nextDouble|(D)D||',
'M|65537|nextDouble|()D||',
'M|65537|nextDouble|(DD)D||',
'M|65537|nextInt|(I)I||',
'M|65537|nextInt|(II)I||',
'M|65537|nextInt|()I||',
'M|65537|nextBytes|([B)V||',
'M|65537|ints|(II)~5IntStream;||',
'M|65537|ints|()~5IntStream;||',
'M|65537|ints|(J)~5IntStream;||',
'M|65537|ints|(JII)~5IntStream;||',
'M|65537|longs|(JJJ)~5LongStream;||',
'M|65537|longs|(JJ)~5LongStream;||',
'M|65537|longs|()~5LongStream;||',
'M|65537|longs|(J)~5LongStream;||',
'M|65537|doubles|()~5DoubleStream;||',
'M|65537|doubles|(JDD)~5DoubleStream;||',
'M|65537|doubles|(DD)~5DoubleStream;||',
'M|65537|doubles|(J)~5DoubleStream;||',
'M|65537|nextLong|(JJ)J||',
'M|1025|nextLong|()J||',
'M|65537|nextLong|(J)J||',
'M|65537|nextBoolean|()Z||',
'M|65537|nextFloat|()F||',
'M|65537|nextFloat|(F)F||',
'M|65537|nextFloat|(FF)F||',
'M|65537|nextGaussian|(DD)D||',
'M|65537|nextGaussian|()D||',
'M|65537|isDeprecated|()Z||',
'M|65537|nextExponential|()D||',
'C|1537|java/util/concurrent/CompletionStage|<T:~O>~O',
'M|1025|handle|(~3BiFunction;)~2concurrent/CompletionStage;|<U:~O>(~3BiFunction<-TT;~1Throwable;+TU;>;)~2concurrent/CompletionStage<TU;>;|',
'M|1025|toCompletableFuture|()~2concurrent/CompletableFuture;|()~2concurrent/CompletableFuture<TT;>;|',
'M|1025|whenComplete|(~3BiConsumer;)~2concurrent/CompletionStage;|(~3BiConsumer<-TT;-~1Throwable;>;)~2concurrent/CompletionStage<TT;>;|',
'M|65537|exceptionallyComposeAsync|(~3Function;~2concurrent/Executor;)~2concurrent/CompletionStage;|(~3Function<~1Throwable;+~2concurrent/CompletionStage<TT;>;>;~2concurrent/Executor;)~2concurrent/CompletionStage<TT;>;|',
'M|65537|exceptionallyComposeAsync|(~3Function;)~2concurrent/CompletionStage;|(~3Function<~1Throwable;+~2concurrent/CompletionStage<TT;>;>;)~2concurrent/CompletionStage<TT;>;|',
'M|65537|exceptionallyCompose|(~3Function;)~2concurrent/CompletionStage;|(~3Function<~1Throwable;+~2concurrent/CompletionStage<TT;>;>;)~2concurrent/CompletionStage<TT;>;|',
'M|65537|exceptionallyAsync|(~3Function;~2concurrent/Executor;)~2concurrent/CompletionStage;|(~3Function<~1Throwable;+TT;>;~2concurrent/Executor;)~2concurrent/CompletionStage<TT;>;|',
'M|65537|exceptionallyAsync|(~3Function;)~2concurrent/CompletionStage;|(~3Function<~1Throwable;+TT;>;)~2concurrent/CompletionStage<TT;>;|',
'M|1025|exceptionally|(~3Function;)~2concurrent/CompletionStage;|(~3Function<~1Throwable;+TT;>;)~2concurrent/CompletionStage<TT;>;|',
'M|1025|whenCompleteAsync|(~3BiConsumer;~2concurrent/Executor;)~2concurrent/CompletionStage;|(~3BiConsumer<-TT;-~1Throwable;>;~2concurrent/Executor;)~2concurrent/CompletionStage<TT;>;|',
'M|1025|whenCompleteAsync|(~3BiConsumer;)~2concurrent/CompletionStage;|(~3BiConsumer<-TT;-~1Throwable;>;)~2concurrent/CompletionStage<TT;>;|',
'M|1025|handleAsync|(~3BiFunction;~2concurrent/Executor;)~2concurrent/CompletionStage;|<U:~O>(~3BiFunction<-TT;~1Throwable;+TU;>;~2concurrent/Executor;)~2concurrent/CompletionStage<TU;>;|',
'M|1025|handleAsync|(~3BiFunction;)~2concurrent/CompletionStage;|<U:~O>(~3BiFunction<-TT;~1Throwable;+TU;>;)~2concurrent/CompletionStage<TU;>;|',
'M|1025|thenComposeAsync|(~3Function;~2concurrent/Executor;)~2concurrent/CompletionStage;|<U:~O>(~3Function<-TT;+~2concurrent/CompletionStage<TU;>;>;~2concurrent/Executor;)~2concurrent/CompletionStage<TU;>;|',
'M|1025|thenComposeAsync|(~3Function;)~2concurrent/CompletionStage;|<U:~O>(~3Function<-TT;+~2concurrent/CompletionStage<TU;>;>;)~2concurrent/CompletionStage<TU;>;|',
'M|1025|thenCompose|(~3Function;)~2concurrent/CompletionStage;|<U:~O>(~3Function<-TT;+~2concurrent/CompletionStage<TU;>;>;)~2concurrent/CompletionStage<TU;>;|',
'M|1025|runAfterEitherAsync|(~2concurrent/CompletionStage;~1Runnable;)~2concurrent/CompletionStage;|(~2concurrent/CompletionStage<*>;~1Runnable;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|runAfterEitherAsync|(~2concurrent/CompletionStage;~1Runnable;~2concurrent/Executor;)~2concurrent/CompletionStage;|(~2concurrent/CompletionStage<*>;~1Runnable;~2concurrent/Executor;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|runAfterEither|(~2concurrent/CompletionStage;~1Runnable;)~2concurrent/CompletionStage;|(~2concurrent/CompletionStage<*>;~1Runnable;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|acceptEitherAsync|(~2concurrent/CompletionStage;~3Consumer;)~2concurrent/CompletionStage;|(~2concurrent/CompletionStage<+TT;>;~3Consumer<-TT;>;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|acceptEitherAsync|(~2concurrent/CompletionStage;~3Consumer;~2concurrent/Executor;)~2concurrent/CompletionStage;|(~2concurrent/CompletionStage<+TT;>;~3Consumer<-TT;>;~2concurrent/Executor;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|acceptEither|(~2concurrent/CompletionStage;~3Consumer;)~2concurrent/CompletionStage;|(~2concurrent/CompletionStage<+TT;>;~3Consumer<-TT;>;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|applyToEitherAsync|(~2concurrent/CompletionStage;~3Function;~2concurrent/Executor;)~2concurrent/CompletionStage;|<U:~O>(~2concurrent/CompletionStage<+TT;>;~3Function<-TT;TU;>;~2concurrent/Executor;)~2concurrent/CompletionStage<TU;>;|',
'M|1025|applyToEitherAsync|(~2concurrent/CompletionStage;~3Function;)~2concurrent/CompletionStage;|<U:~O>(~2concurrent/CompletionStage<+TT;>;~3Function<-TT;TU;>;)~2concurrent/CompletionStage<TU;>;|',
'M|1025|applyToEither|(~2concurrent/CompletionStage;~3Function;)~2concurrent/CompletionStage;|<U:~O>(~2concurrent/CompletionStage<+TT;>;~3Function<-TT;TU;>;)~2concurrent/CompletionStage<TU;>;|',
'M|1025|runAfterBothAsync|(~2concurrent/CompletionStage;~1Runnable;~2concurrent/Executor;)~2concurrent/CompletionStage;|(~2concurrent/CompletionStage<*>;~1Runnable;~2concurrent/Executor;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|runAfterBothAsync|(~2concurrent/CompletionStage;~1Runnable;)~2concurrent/CompletionStage;|(~2concurrent/CompletionStage<*>;~1Runnable;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|runAfterBoth|(~2concurrent/CompletionStage;~1Runnable;)~2concurrent/CompletionStage;|(~2concurrent/CompletionStage<*>;~1Runnable;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|thenAcceptBothAsync|(~2concurrent/CompletionStage;~3BiConsumer;)~2concurrent/CompletionStage;|<U:~O>(~2concurrent/CompletionStage<+TU;>;~3BiConsumer<-TT;-TU;>;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|thenAcceptBothAsync|(~2concurrent/CompletionStage;~3BiConsumer;~2concurrent/Executor;)~2concurrent/CompletionStage;|<U:~O>(~2concurrent/CompletionStage<+TU;>;~3BiConsumer<-TT;-TU;>;~2concurrent/Executor;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|thenAcceptBoth|(~2concurrent/CompletionStage;~3BiConsumer;)~2concurrent/CompletionStage;|<U:~O>(~2concurrent/CompletionStage<+TU;>;~3BiConsumer<-TT;-TU;>;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|thenCombineAsync|(~2concurrent/CompletionStage;~3BiFunction;~2concurrent/Executor;)~2concurrent/CompletionStage;|<U:~OV:~O>(~2concurrent/CompletionStage<+TU;>;~3BiFunction<-TT;-TU;+TV;>;~2concurrent/Executor;)~2concurrent/CompletionStage<TV;>;|',
'M|1025|thenCombineAsync|(~2concurrent/CompletionStage;~3BiFunction;)~2concurrent/CompletionStage;|<U:~OV:~O>(~2concurrent/CompletionStage<+TU;>;~3BiFunction<-TT;-TU;+TV;>;)~2concurrent/CompletionStage<TV;>;|',
'M|1025|thenCombine|(~2concurrent/CompletionStage;~3BiFunction;)~2concurrent/CompletionStage;|<U:~OV:~O>(~2concurrent/CompletionStage<+TU;>;~3BiFunction<-TT;-TU;+TV;>;)~2concurrent/CompletionStage<TV;>;|',
'M|1025|thenRunAsync|(~1Runnable;~2concurrent/Executor;)~2concurrent/CompletionStage;|(~1Runnable;~2concurrent/Executor;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|thenRunAsync|(~1Runnable;)~2concurrent/CompletionStage;|(~1Runnable;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|thenRun|(~1Runnable;)~2concurrent/CompletionStage;|(~1Runnable;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|thenAcceptAsync|(~3Consumer;)~2concurrent/CompletionStage;|(~3Consumer<-TT;>;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|thenAcceptAsync|(~3Consumer;~2concurrent/Executor;)~2concurrent/CompletionStage;|(~3Consumer<-TT;>;~2concurrent/Executor;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|thenAccept|(~3Consumer;)~2concurrent/CompletionStage;|(~3Consumer<-TT;>;)~2concurrent/CompletionStage<~1Void;>;|',
'M|1025|thenApplyAsync|(~3Function;~2concurrent/Executor;)~2concurrent/CompletionStage;|<U:~O>(~3Function<-TT;+TU;>;~2concurrent/Executor;)~2concurrent/CompletionStage<TU;>;|',
'M|1025|thenApplyAsync|(~3Function;)~2concurrent/CompletionStage;|<U:~O>(~3Function<-TT;+TU;>;)~2concurrent/CompletionStage<TU;>;|',
'M|1025|thenApply|(~3Function;)~2concurrent/CompletionStage;|<U:~O>(~3Function<-TT;+TU;>;)~2concurrent/CompletionStage<TU;>;|',
'C|1537|java/time/temporal/Temporal|~OLjava/time/temporal/TemporalAccessor;',
'M|1025|isSupported|(Ljava/time/temporal/TemporalUnit;)Z||',
'M|1025|with|(Ljava/time/temporal/TemporalField;J)Ljava/time/temporal/Temporal;||',
'M|65537|with|(Ljava/time/temporal/TemporalAdjuster;)Ljava/time/temporal/Temporal;||',
'M|65537|minus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/temporal/Temporal;||',
'M|65537|minus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/temporal/Temporal;||',
'M|1025|plus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/temporal/Temporal;||',
'M|65537|plus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/temporal/Temporal;||',
'M|1025|until|(Ljava/time/temporal/Temporal;Ljava/time/temporal/TemporalUnit;)J||',
'C|1537|java/time/temporal/TemporalAdjuster|~O',
'M|1025|adjustInto|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'C|1537|java/time/chrono/ChronoLocalDate|~OLjava/time/temporal/Temporal;Ljava/time/temporal/TemporalAdjuster;~1Comparable<Ljava/time/chrono/ChronoLocalDate;>;',
'M|1025|equals|(~O)Z||',
'M|1025|toString|()~S||',
'M|1025|hashCode|()I||',
'M|65537|compareTo|(Ljava/time/chrono/ChronoLocalDate;)I||',
'M|65537|format|(Ljava/time/format/DateTimeFormatter;)~S||',
'M|9|from|(Ljava/time/temporal/TemporalAccessor;)Ljava/time/chrono/ChronoLocalDate;||',
'M|65537|isSupported|(Ljava/time/temporal/TemporalUnit;)Z||',
'M|65537|isSupported|(Ljava/time/temporal/TemporalField;)Z||',
'M|65537|with|(Ljava/time/temporal/TemporalField;J)Ljava/time/chrono/ChronoLocalDate;||',
'M|65537|with|(Ljava/time/temporal/TemporalAdjuster;)Ljava/time/chrono/ChronoLocalDate;||',
'M|65537|query|(Ljava/time/temporal/TemporalQuery;)~O|<R:~O>(Ljava/time/temporal/TemporalQuery<TR;>;)TR;|',
'M|65537|minus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/chrono/ChronoLocalDate;||',
'M|65537|minus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/chrono/ChronoLocalDate;||',
'M|65537|plus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/chrono/ChronoLocalDate;||',
'M|65537|plus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/chrono/ChronoLocalDate;||',
'M|1025|until|(Ljava/time/temporal/Temporal;Ljava/time/temporal/TemporalUnit;)J||',
'M|1025|until|(Ljava/time/chrono/ChronoLocalDate;)Ljava/time/chrono/ChronoPeriod;||',
'M|65537|adjustInto|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'M|65537|isAfter|(Ljava/time/chrono/ChronoLocalDate;)Z||',
'M|65537|isBefore|(Ljava/time/chrono/ChronoLocalDate;)Z||',
'M|65537|isLeapYear|()Z||',
'M|1025|lengthOfMonth|()I||',
'M|65537|lengthOfYear|()I||',
'M|65537|toEpochDay|()J||',
'M|65537|atTime|(Ljava/time/LocalTime;)Ljava/time/chrono/ChronoLocalDateTime;|(Ljava/time/LocalTime;)Ljava/time/chrono/ChronoLocalDateTime<*>;|',
'M|65537|isEqual|(Ljava/time/chrono/ChronoLocalDate;)Z||',
'M|65537|getEra|()Ljava/time/chrono/Era;||',
'M|1025|getChronology|()Ljava/time/chrono/Chronology;||',
'M|9|timeLineOrder|()~2Comparator;|()~2Comparator<Ljava/time/chrono/ChronoLocalDate;>;|',
'C|1537|java/time/chrono/ChronoLocalDateTime|<D::Ljava/time/chrono/ChronoLocalDate;>~OLjava/time/temporal/Temporal;Ljava/time/temporal/TemporalAdjuster;~1Comparable<Ljava/time/chrono/ChronoLocalDateTime<*>;>;',
'M|1025|equals|(~O)Z||',
'M|1025|toString|()~S||',
'M|1025|hashCode|()I||',
'M|65537|compareTo|(Ljava/time/chrono/ChronoLocalDateTime;)I|(Ljava/time/chrono/ChronoLocalDateTime<*>;)I|',
'M|65537|format|(Ljava/time/format/DateTimeFormatter;)~S||',
'M|9|from|(Ljava/time/temporal/TemporalAccessor;)Ljava/time/chrono/ChronoLocalDateTime;|(Ljava/time/temporal/TemporalAccessor;)Ljava/time/chrono/ChronoLocalDateTime<*>;|',
'M|1025|isSupported|(Ljava/time/temporal/TemporalField;)Z||',
'M|65537|isSupported|(Ljava/time/temporal/TemporalUnit;)Z||',
'M|65537|with|(Ljava/time/temporal/TemporalAdjuster;)Ljava/time/chrono/ChronoLocalDateTime;|(Ljava/time/temporal/TemporalAdjuster;)Ljava/time/chrono/ChronoLocalDateTime<TD;>;|',
'M|1025|with|(Ljava/time/temporal/TemporalField;J)Ljava/time/chrono/ChronoLocalDateTime;|(Ljava/time/temporal/TemporalField;J)Ljava/time/chrono/ChronoLocalDateTime<TD;>;|',
'M|65537|query|(Ljava/time/temporal/TemporalQuery;)~O|<R:~O>(Ljava/time/temporal/TemporalQuery<TR;>;)TR;|',
'M|65537|toInstant|(Ljava/time/ZoneOffset;)Ljava/time/Instant;||',
'M|65537|minus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/chrono/ChronoLocalDateTime;|(Ljava/time/temporal/TemporalAmount;)Ljava/time/chrono/ChronoLocalDateTime<TD;>;|',
'M|65537|minus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/chrono/ChronoLocalDateTime;|(JLjava/time/temporal/TemporalUnit;)Ljava/time/chrono/ChronoLocalDateTime<TD;>;|',
'M|1025|plus|(JLjava/time/temporal/TemporalUnit;)Ljava/time/chrono/ChronoLocalDateTime;|(JLjava/time/temporal/TemporalUnit;)Ljava/time/chrono/ChronoLocalDateTime<TD;>;|',
'M|65537|plus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/chrono/ChronoLocalDateTime;|(Ljava/time/temporal/TemporalAmount;)Ljava/time/chrono/ChronoLocalDateTime<TD;>;|',
'M|65537|adjustInto|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'M|1025|atZone|(Ljava/time/ZoneId;)Ljava/time/chrono/ChronoZonedDateTime;|(Ljava/time/ZoneId;)Ljava/time/chrono/ChronoZonedDateTime<TD;>;|',
'M|65537|isAfter|(Ljava/time/chrono/ChronoLocalDateTime;)Z|(Ljava/time/chrono/ChronoLocalDateTime<*>;)Z|',
'M|65537|isBefore|(Ljava/time/chrono/ChronoLocalDateTime;)Z|(Ljava/time/chrono/ChronoLocalDateTime<*>;)Z|',
'M|1025|toLocalTime|()Ljava/time/LocalTime;||',
'M|65537|isEqual|(Ljava/time/chrono/ChronoLocalDateTime;)Z|(Ljava/time/chrono/ChronoLocalDateTime<*>;)Z|',
'M|65537|getChronology|()Ljava/time/chrono/Chronology;||',
'M|65537|toEpochSecond|(Ljava/time/ZoneOffset;)J||',
'M|9|timeLineOrder|()~2Comparator;|()~2Comparator<Ljava/time/chrono/ChronoLocalDateTime<*>;>;|',
'M|1025|toLocalDate|()Ljava/time/chrono/ChronoLocalDate;|()TD;|',
'C|1537|java/time/temporal/TemporalAmount|~O',
'M|1025|get|(Ljava/time/temporal/TemporalUnit;)J||',
'M|1025|getUnits|()~2List;|()~2List<Ljava/time/temporal/TemporalUnit;>;|',
'M|1025|addTo|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'M|1025|subtractFrom|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'C|1537|java/time/chrono/ChronoPeriod|~OLjava/time/temporal/TemporalAmount;',
'M|1025|get|(Ljava/time/temporal/TemporalUnit;)J||',
'M|1025|equals|(~O)Z||',
'M|1025|toString|()~S||',
'M|1025|hashCode|()I||',
'M|9|between|(Ljava/time/chrono/ChronoLocalDate;Ljava/time/chrono/ChronoLocalDate;)Ljava/time/chrono/ChronoPeriod;||',
'M|1025|normalized|()Ljava/time/chrono/ChronoPeriod;||',
'M|65537|isZero|()Z||',
'M|65537|isNegative|()Z||',
'M|1025|minus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/chrono/ChronoPeriod;||',
'M|1025|plus|(Ljava/time/temporal/TemporalAmount;)Ljava/time/chrono/ChronoPeriod;||',
'M|1025|getUnits|()~2List;|()~2List<Ljava/time/temporal/TemporalUnit;>;|',
'M|65537|negated|()Ljava/time/chrono/ChronoPeriod;||',
'M|1025|multipliedBy|(I)Ljava/time/chrono/ChronoPeriod;||',
'M|1025|addTo|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'M|1025|subtractFrom|(Ljava/time/temporal/Temporal;)Ljava/time/temporal/Temporal;||',
'M|1025|getChronology|()Ljava/time/chrono/Chronology;||',
'C|1537|java/time/temporal/TemporalAccessor|~O',
'M|65537|get|(Ljava/time/temporal/TemporalField;)I||',
'M|1025|getLong|(Ljava/time/temporal/TemporalField;)J||',
'M|1025|isSupported|(Ljava/time/temporal/TemporalField;)Z||',
'M|65537|query|(Ljava/time/temporal/TemporalQuery;)~O|<R:~O>(Ljava/time/temporal/TemporalQuery<TR;>;)TR;|',
'M|65537|range|(Ljava/time/temporal/TemporalField;)Ljava/time/temporal/ValueRange;||',
'C|1537|java/nio/file/Watchable|~O',
'M|1153|register|(Ljava/nio/file/WatchService;[Ljava/nio/file/WatchEvent$Kind;[Ljava/nio/file/WatchEvent$Modifier;)Ljava/nio/file/WatchKey;|(Ljava/nio/file/WatchService;[Ljava/nio/file/WatchEvent$Kind<*>;[Ljava/nio/file/WatchEvent$Modifier;)Ljava/nio/file/WatchKey;|java/io/IOException',
'M|1153|register|(Ljava/nio/file/WatchService;[Ljava/nio/file/WatchEvent$Kind;)Ljava/nio/file/WatchKey;|(Ljava/nio/file/WatchService;[Ljava/nio/file/WatchEvent$Kind<*>;)Ljava/nio/file/WatchKey;|java/io/IOException',
'C|1537|java/lang/invoke/TypeDescriptor|~O',
'M|1025|descriptorString|()~S||'
  );
{ ============================================================================
  3. TYPES, SYMBOLES ET BIBLIOTHEQUE STANDARD
  ============================================================================ }

Const
  TY_NONE    = 0;     { erreur / inconnu }
  TY_VOID    = 1;
  TY_BOOLEAN = 2;
  TY_BYTE    = 3;
  TY_CHAR    = 4;
  TY_SHORT   = 5;
  TY_INT     = 6;
  TY_LONG    = 7;
  TY_FLOAT   = 8;
  TY_DOUBLE  = 9;
  TY_NULL    = 10;
  TY_FIRSTDYN = 11;

  TYK_PRIM  = 1;
  TYK_CLASS = 2;
  TYK_ARRAY = 3;
  TYK_TVAR  = 4;
  TYK_ANY   = 5;      { reference inconnue (inference incomplete) }

  MAXTARGS = 4;

Type
  TTypeRec = Record
    Kind  : Byte;
    Cls   : LongInt;
    Elem  : LongInt;
    NArgs : LongInt;
    Args  : Array[0..MAXTARGS - 1] Of LongInt;
    TV    : LongInt;
  End;

  TTVarRec = Record
    Name  : String;
    Bound : LongInt;
    Ty    : LongInt;
  End;

  TFieldRec = Record
    Name       : String;
    Owner      : LongInt;
    Flags      : LongInt;
    Typ        : LongInt;
    Next       : LongInt;
    CK         : Byte;
    CI         : Int64;
    CD         : Double;
    CS         : String;
    ConstState : Byte;     { 0 non evaluee, 1 en cours, 2 faite }
    Decl       : LongInt;  { noeud N_VARDECL }
    ConstInit  : LongInt;  { expression d'initialisation }
  End;

  TMethRec = Record
    Name    : String;
    Owner   : LongInt;
    Flags   : LongInt;
    NPar    : LongInt;
    Par     : Array Of LongInt;
    ParNames: Array Of String;
    Ret     : LongInt;
    TPar    : Array Of LongInt;
    Desc    : String;
    Next    : LongInt;
    Decl    : LongInt;
    Varargs : Boolean;
    Lambda  : LongInt;     { >= 0 si methode synthetique issue d'une lambda }
    Bridge  : LongInt;     { methode ciblee par un pont }
    Synth   : LongInt;     { genre de methode generee (0 = normale) }
    PreLoc  : Array Of LongInt;   { parametres synthetiques en tete }
    PostLoc : Array Of LongInt;   { parametres synthetiques en queue }
    BodyN   : LongInt;     { noeud du corps pour les methodes synthetiques }
    Thr     : Array Of LongInt;   { classes des exceptions declarees (throws) }
  End;

  TClassRec = Record
    Name, Simple : String;
    Flags        : LongInt;
    Super        : LongInt;
    Ifaces       : Array Of LongInt;
    Permits      : Array Of LongInt;   { classes permises (classe scellee), explicites ou deduites }
    PermitsState : Byte;               { 0 non calcule, 2 calcule }
    TPars        : Array Of LongInt;
    Outer        : LongInt;
    IsSrc        : Boolean;
    Loaded       : Byte;
    LibLine      : LongInt;
    FirstField, LastField, FirstMeth, LastMeth : LongInt;
    Decl         : LongInt;
    Nested       : Array Of LongInt;
    HdrState     : Byte;
    MemState     : Byte;
    IsInner      : Boolean;       { possede this$0 }
    InStatic     : Boolean;       { declaree dans un contexte statique }
    Caps         : Array Of LongInt;   { variables locales capturees }
    CapFields    : Array Of LongInt;   { champs val$x correspondants }
    ThisField    : LongInt;       { champ this$0 ou -1 }
    CU           : LongInt;
    AnonCount    : LongInt;
    LocalCount   : LongInt;
    TopClass     : LongInt;
    Ctx          : LongInt;       { contexte de declaration (classe locale) }
    EnumCount    : LongInt;
    HasAssert    : Boolean;
    Lowered      : Boolean;
    InnerList    : Array Of LongInt;   { classes imbriquees directes (pour InnerClasses) }
    NewSites     : Array Of LongInt;   { classes locales instanciees depuis ce contexte }
    ClsCtx       : LongInt;
    AnonCtor     : LongInt;
  End;

  TCURec = Record
    Pkg, FileName : String;
    Imports       : LongInt;
    Root          : LongInt;
  End;

Var
  NCPath   : LongInt;
  ExtMemo  : TStrMap;
  Types    : Array Of TTypeRec;
  NTypes   : LongInt;
  TypeMap  : TStrMap;
  TVars    : Array Of TTVarRec;
  NTVars   : LongInt;

  Classes  : Array Of TClassRec;
  NClasses : LongInt;
  ClassMap : TStrMap;
  LibIndex : TStrMap;
  Fields   : Array Of TFieldRec;
  NFields  : LongInt;
  Meths    : Array Of TMethRec;
  NMeths   : LongInt;
  CUs      : Array Of TCURec;
  NCUs     : LongInt;
  SubMap   : TStrMap;

  { Classes et types connus }
  C_OBJECT, C_STRING, C_CLASS, C_THROWABLE, C_ENUM, C_ITERABLE, C_ITERATOR, C_NUMBER,
  C_RUNTIMEEX, C_ERROR, C_STRINGBUILDER, C_CHARSEQ, C_CLONEABLE, C_SERIAL, C_RECORD,
  C_COMPARABLE, C_ASSERTERR : LongInt;
  T_OBJECT, T_STRING, T_CLASS, T_THROWABLE, T_ANY : LongInt;
  BoxCls   : Array[TY_BOOLEAN..TY_DOUBLE] Of LongInt;

  { Echelle des variables de type pendant la lecture d'une signature }
  SigNames : Array Of String;
  SigTys   : Array Of LongInt;
  NSig     : LongInt;

{ ----- types ------------------------------------------------------------ }

Function InternType(Var R : TTypeRec) : LongInt;
Var K : String; I, Id : LongInt;
Begin
  K := IStr(R.Kind) + '|' + IStr(R.Cls) + '|' + IStr(R.Elem) + '|' + IStr(R.TV);
  For I := 0 To R.NArgs - 1 Do K := K + '|' + IStr(R.Args[I]);
  Id := MapFind(TypeMap, K);
  If Id >= 0 Then Begin InternType := Id; Exit; End;
  If NTypes >= Length(Types) Then SetLength(Types, NTypes * 2 + 256);
  Types[NTypes] := R;
  MapPut(TypeMap, K, NTypes);
  InternType := NTypes;
  Inc(NTypes);
End;

Function ClassT(C : LongInt) : LongInt;
Var R : TTypeRec;
Begin
  FillChar(R, SizeOf(R), 0);
  R.Kind := TYK_CLASS; R.Cls := C;
  ClassT := InternType(R);
End;

Function ClassTA(C : LongInt; N : LongInt; Const A : Array Of LongInt) : LongInt;
Var R : TTypeRec; I : LongInt;
Begin
  FillChar(R, SizeOf(R), 0);
  R.Kind := TYK_CLASS; R.Cls := C;
  If N > MAXTARGS Then N := MAXTARGS;
  R.NArgs := N;
  For I := 0 To N - 1 Do R.Args[I] := A[I];
  ClassTA := InternType(R);
End;

Function ClassT1(C, A : LongInt) : LongInt;
Var Ar : Array[0..0] Of LongInt;
Begin
  Ar[0] := A;
  ClassT1 := ClassTA(C, 1, Ar);
End;

Function ArrayT(Elem : LongInt) : LongInt;
Var R : TTypeRec;
Begin
  FillChar(R, SizeOf(R), 0);
  R.Kind := TYK_ARRAY; R.Elem := Elem;
  ArrayT := InternType(R);
End;

Function NewTVar(Const Name : String; Bound : LongInt) : LongInt;
Var R : TTypeRec;
Begin
  If NTVars >= Length(TVars) Then SetLength(TVars, NTVars * 2 + 64);
  TVars[NTVars].Name := Name;
  TVars[NTVars].Bound := Bound;
  FillChar(R, SizeOf(R), 0);
  R.Kind := TYK_TVAR; R.TV := NTVars;
  TVars[NTVars].Ty := InternType(R);
  NewTVar := TVars[NTVars].Ty;
  Inc(NTVars);
End;

Function TK(T : LongInt) : Byte;
Begin
  If (T >= TY_BOOLEAN) And (T <= TY_DOUBLE) Then TK := TYK_PRIM
  Else If T <= TY_VOID Then TK := 0
  Else If T = TY_NULL Then TK := TYK_PRIM
  Else TK := Types[T].Kind;
End;

Function IsPrim(T : LongInt) : Boolean;
Begin IsPrim := (T >= TY_BOOLEAN) And (T <= TY_DOUBLE); End;

Function IsNumeric(T : LongInt) : Boolean;
Begin IsNumeric := (T >= TY_BYTE) And (T <= TY_DOUBLE); End;

Function IsIntegral(T : LongInt) : Boolean;
Begin IsIntegral := (T >= TY_BYTE) And (T <= TY_LONG); End;

Function IsIntLike(T : LongInt) : Boolean;     { type represente par int sur la pile }
Begin IsIntLike := (T >= TY_BOOLEAN) And (T <= TY_INT); End;

Function IsRef(T : LongInt) : Boolean;
Begin
  IsRef := (T = TY_NULL) Or ((T >= TY_FIRSTDYN) And (Types[T].Kind In [TYK_CLASS, TYK_ARRAY, TYK_TVAR, TYK_ANY]));
End;

Function IsClassT(T : LongInt) : Boolean;
Begin IsClassT := (T >= TY_FIRSTDYN) And (Types[T].Kind = TYK_CLASS); End;

Function IsArrayT(T : LongInt) : Boolean;
Begin IsArrayT := (T >= TY_FIRSTDYN) And (Types[T].Kind = TYK_ARRAY); End;

Function IsTVarT(T : LongInt) : Boolean;
Begin IsTVarT := (T >= TY_FIRSTDYN) And (Types[T].Kind = TYK_TVAR); End;

Function ClsOf(T : LongInt) : LongInt;
Begin
  If IsClassT(T) Then ClsOf := Types[T].Cls Else ClsOf := -1;
End;

Function ElemOf(T : LongInt) : LongInt;
Begin
  If IsArrayT(T) Then ElemOf := Types[T].Elem Else ElemOf := TY_NONE;
End;

{ Taille sur la pile : 2 pour long/double, 0 pour void, 1 sinon }
Function TypeSize(T : LongInt) : LongInt;
Begin
  If (T = TY_LONG) Or (T = TY_DOUBLE) Then TypeSize := 2
  Else If (T = TY_VOID) Or (T = TY_NONE) Then TypeSize := 0
  Else TypeSize := 1;
End;

{ ----- classes ---------------------------------------------------------- }

Function NewClass(Const Name : String) : LongInt;
Var I : LongInt;
Begin
  If NClasses >= Length(Classes) Then SetLength(Classes, NClasses * 2 + 256);
  FillChar(Classes[NClasses], SizeOf(TClassRec), 0);
  Classes[NClasses].Name := Name;
  I := LastPos('/', Name);
  Classes[NClasses].Simple := Copy(Name, I + 1, Length(Name));
  Classes[NClasses].Outer := -1;
  Classes[NClasses].FirstField := -1; Classes[NClasses].LastField := -1;
  Classes[NClasses].FirstMeth := -1; Classes[NClasses].LastMeth := -1;
  Classes[NClasses].ThisField := -1;
  Classes[NClasses].TopClass := NClasses;
  Classes[NClasses].Ctx := -1;
  Classes[NClasses].CU := -1;
  MapPut(ClassMap, Name, NClasses);
  NewClass := NClasses;
  Inc(NClasses);
End;

Function ExtFind(Const Name : String; UseJdk : Boolean) : Boolean; Forward;
Procedure LoadExtClass(C : LongInt); Forward;

{ Cherche une classe par nom interne ; cree une entree si elle figure dans la
  table de la bibliotheque. Retourne -1 si inconnue. }
Function LookupClass(Const Name : String) : LongInt;
Var I, L : LongInt;
Begin
  I := MapFind(ClassMap, Name);
  If I >= 0 Then Begin LookupClass := I; Exit; End;
  If (NCPath > 0) And ExtFind(Name, False) Then Begin
    I := NewClass(Name);
    Classes[I].LibLine := -2;
    Classes[I].Loaded := 0;
    LookupClass := I;
    Exit;
  End;
  L := MapFind(LibIndex, Name);
  If L < 0 Then Begin
    If ExtFind(Name, True) Then Begin
      I := NewClass(Name);
      Classes[I].LibLine := -2;
      Classes[I].Loaded := 0;
      LookupClass := I;
    End
    Else LookupClass := -1;
    Exit;
  End;
  I := NewClass(Name);
  Classes[I].LibLine := L;
  Classes[I].Loaded := 0;
  LookupClass := I;
End;

{ Comme LookupClass mais cree une classe vide (sans membres) si inconnue }
Function GetClass(Const Name : String) : LongInt;
Var I : LongInt;
Begin
  I := LookupClass(Name);
  If I < 0 Then Begin
    I := NewClass(Name);
    Classes[I].LibLine := -1;
    Classes[I].Loaded := 2;
    Classes[I].Flags := ACC_PUBLIC;
    Classes[I].Super := T_OBJECT;
  End;
  GetClass := I;
End;

Procedure ResolveSrcHeader(C : LongInt); Forward;
Procedure LoadLibHeader(C : LongInt); Forward;
Procedure LoadLibMembers(C : LongInt); Forward;
Procedure EnterMembers(C : LongInt); Forward;

Procedure EnsureHeader(C : LongInt);
Begin
  If C < 0 Then Exit;
  If Classes[C].IsSrc Then Begin
    If Classes[C].HdrState = 0 Then ResolveSrcHeader(C);
  End
  Else If Classes[C].Loaded = 0 Then LoadLibHeader(C);
End;

Procedure EnsureMembers(C : LongInt);
Begin
  If C < 0 Then Exit;
  EnsureHeader(C);
  If Classes[C].IsSrc Then Begin
    If Classes[C].MemState = 0 Then EnterMembers(C);
  End
  Else If Classes[C].Loaded < 2 Then LoadLibMembers(C);
End;

Function SuperClsOf(C : LongInt) : LongInt;
Begin
  EnsureHeader(C);
  If Classes[C].Super = 0 Then SuperClsOf := -1
  Else SuperClsOf := ClsOf(Classes[C].Super);
End;

Function IsInterfaceC(C : LongInt) : Boolean;
Begin
  EnsureHeader(C);
  IsInterfaceC := (Classes[C].Flags And ACC_INTERFACE) <> 0;
End;

Function IsSubClass(C, D : LongInt) : Boolean;
Var K : String; R, I, S : LongInt;
Begin
  If C = D Then Begin IsSubClass := True; Exit; End;
  If D = C_OBJECT Then Begin IsSubClass := True; Exit; End;
  K := IStr(C) + ',' + IStr(D);
  R := MapFind(SubMap, K);
  If R >= 0 Then Begin IsSubClass := R = 1; Exit; End;
  EnsureHeader(C);
  MapPut(SubMap, K, 0);      { garde anti-cycle }
  R := 0;
  S := SuperClsOf(C);
  If (S >= 0) And IsSubClass(S, D) Then R := 1;
  If R = 0 Then
    For I := 0 To Length(Classes[C].Ifaces) - 1 Do
      If IsSubClass(ClsOf(Classes[C].Ifaces[I]), D) Then Begin R := 1; Break; End;
  MapPut(SubMap, K, R);
  IsSubClass := R = 1;
End;

{ ----- erasure, descriptors, chaines ------------------------------------ }

Function Erasure(T : LongInt) : LongInt;
Begin
  If T < TY_FIRSTDYN Then Begin Erasure := T; Exit; End;
  Case Types[T].Kind Of
    TYK_CLASS : If Types[T].NArgs = 0 Then Erasure := T Else Erasure := ClassT(Types[T].Cls);
    TYK_ARRAY : Erasure := ArrayT(Erasure(Types[T].Elem));
    TYK_TVAR  : Begin
      If TVars[Types[T].TV].Bound = 0 Then Erasure := T_OBJECT
      Else Erasure := Erasure(TVars[Types[T].TV].Bound);
    End;
    TYK_ANY   : Erasure := T_OBJECT;
  Else
    Erasure := T;
  End;
End;

Function TypeDesc(T : LongInt) : String;
Begin
  If T < TY_FIRSTDYN Then Begin
    Case T Of
      TY_VOID : TypeDesc := 'V';
      TY_BOOLEAN : TypeDesc := 'Z';
      TY_BYTE : TypeDesc := 'B';
      TY_CHAR : TypeDesc := 'C';
      TY_SHORT : TypeDesc := 'S';
      TY_INT : TypeDesc := 'I';
      TY_LONG : TypeDesc := 'J';
      TY_FLOAT : TypeDesc := 'F';
      TY_DOUBLE : TypeDesc := 'D';
      TY_NULL : TypeDesc := 'Ljava/lang/Object;';
    Else
      TypeDesc := 'V';
    End;
    Exit;
  End;
  Case Types[T].Kind Of
    TYK_CLASS : TypeDesc := 'L' + Classes[Types[T].Cls].Name + ';';
    TYK_ARRAY : TypeDesc := '[' + TypeDesc(Types[T].Elem);
  Else
    TypeDesc := TypeDesc(Erasure(T));
  End;
End;

{ Nom interne utilise dans un CONSTANT_Class : classe -> nom, tableau -> descripteur }
Function TypeClassName(T : LongInt) : String;
Var E : LongInt;
Begin
  E := Erasure(T);
  If IsArrayT(E) Then TypeClassName := TypeDesc(E)
  Else If IsClassT(E) Then TypeClassName := Classes[Types[E].Cls].Name
  Else TypeClassName := 'java/lang/Object';
End;

Function TypeStr(T : LongInt) : String;
Var S : String; I : LongInt;
Begin
  If T < TY_FIRSTDYN Then Begin
    Case T Of
      TY_NONE : TypeStr := '<erreur>';
      TY_VOID : TypeStr := 'void';
      TY_BOOLEAN : TypeStr := 'boolean';
      TY_BYTE : TypeStr := 'byte';
      TY_CHAR : TypeStr := 'char';
      TY_SHORT : TypeStr := 'short';
      TY_INT : TypeStr := 'int';
      TY_LONG : TypeStr := 'long';
      TY_FLOAT : TypeStr := 'float';
      TY_DOUBLE : TypeStr := 'double';
      TY_NULL : TypeStr := '<null>';
    Else
      TypeStr := '?';
    End;
    Exit;
  End;
  Case Types[T].Kind Of
    TYK_CLASS : Begin
      S := Classes[Types[T].Cls].Name;
      I := LastPos('/', S);
      S := Copy(S, I + 1, Length(S));
      S := ReplaceAll(S, '$', '.');
      If Types[T].NArgs > 0 Then Begin
        S := S + '<';
        For I := 0 To Types[T].NArgs - 1 Do Begin
          If I > 0 Then S := S + ',';
          S := S + TypeStr(Types[T].Args[I]);
        End;
        S := S + '>';
      End;
      TypeStr := S;
    End;
    TYK_ARRAY : TypeStr := TypeStr(Types[T].Elem) + '[]';
    TYK_TVAR : TypeStr := TVars[Types[T].TV].Name;
    TYK_ANY : TypeStr := 'Object';
  Else
    TypeStr := '?';
  End;
End;

{ ----- lecture des signatures de la bibliotheque ------------------------- }

Function ExpandAbbr(Const S : String) : String;
Var R : String; I : LongInt;
Begin
  If Pos('~', S) = 0 Then Begin ExpandAbbr := S; Exit; End;
  R := '';
  I := 1;
  While I <= Length(S) Do Begin
    If S[I] = '~' Then Begin
      Inc(I);
      Case S[I] Of
        'S' : R := R + 'Ljava/lang/String;';
        'O' : R := R + 'Ljava/lang/Object;';
        '1' : R := R + 'Ljava/lang/';
        '2' : R := R + 'Ljava/util/';
        '3' : R := R + 'Ljava/util/function/';
        '4' : R := R + 'Ljava/io/';
        '5' : R := R + 'Ljava/util/stream/';
      End;
    End
    Else R := R + S[I];
    Inc(I);
  End;
  ExpandAbbr := R;
End;

Function BarField(Const S : String; K : LongInt) : String;
Var I, N, Start : LongInt;
Begin
  N := 0;
  Start := 1;
  For I := 1 To Length(S) Do
    If S[I] = '|' Then Begin
      If N = K Then Begin BarField := Copy(S, Start, I - Start); Exit; End;
      Inc(N);
      Start := I + 1;
    End;
  If N = K Then BarField := Copy(S, Start, Length(S)) Else BarField := '';
End;

Function ToInt(Const S : String) : LongInt;
Var V, Code : LongInt;
Begin
  Val(S, V, Code);
  If Code <> 0 Then V := 0;
  ToInt := V;
End;

Function ToInt64(Const S : String) : Int64;
Var V : Int64; Code : LongInt;
Begin
  Val(S, V, Code);
  If Code <> 0 Then V := 0;
  ToInt64 := V;
End;

Procedure PushSig(Const Name : String; Ty : LongInt);
Begin
  If NSig >= Length(SigNames) Then Begin
    SetLength(SigNames, NSig * 2 + 32);
    SetLength(SigTys, NSig * 2 + 32);
  End;
  SigNames[NSig] := Name;
  SigTys[NSig] := Ty;
  Inc(NSig);
End;

Function ParseSigType(Const S : String; Var I : LongInt) : LongInt;
Var Name : String; C : LongInt; Args : Array[0..MAXTARGS - 1] Of LongInt; N, A, J : LongInt;
Begin
  ParseSigType := TY_NONE;
  If I > Length(S) Then Exit;
  Case S[I] Of
    'B' : Begin ParseSigType := TY_BYTE; Inc(I); End;
    'C' : Begin ParseSigType := TY_CHAR; Inc(I); End;
    'D' : Begin ParseSigType := TY_DOUBLE; Inc(I); End;
    'F' : Begin ParseSigType := TY_FLOAT; Inc(I); End;
    'I' : Begin ParseSigType := TY_INT; Inc(I); End;
    'J' : Begin ParseSigType := TY_LONG; Inc(I); End;
    'S' : Begin ParseSigType := TY_SHORT; Inc(I); End;
    'Z' : Begin ParseSigType := TY_BOOLEAN; Inc(I); End;
    'V' : Begin ParseSigType := TY_VOID; Inc(I); End;
    '*' : Begin ParseSigType := T_OBJECT; Inc(I); End;
    '+', '-' : Begin Inc(I); ParseSigType := ParseSigType(S, I); End;
    '[' : Begin Inc(I); ParseSigType := ArrayT(ParseSigType(S, I)); End;
    'T' : Begin
      Inc(I);
      Name := '';
      While (I <= Length(S)) And (S[I] <> ';') Do Begin Name := Name + S[I]; Inc(I); End;
      Inc(I);
      ParseSigType := T_OBJECT;
      For J := NSig - 1 Downto 0 Do
        If SigNames[J] = Name Then Begin ParseSigType := SigTys[J]; Break; End;
    End;
    'L' : Begin
      Inc(I);
      Name := '';
      While (I <= Length(S)) And (S[I] <> ';') And (S[I] <> '<') Do Begin Name := Name + S[I]; Inc(I); End;
      C := GetClass(Name);
      N := 0;
      If (I <= Length(S)) And (S[I] = '<') Then Begin
        Inc(I);
        While (I <= Length(S)) And (S[I] <> '>') Do Begin
          A := ParseSigType(S, I);
          If N < MAXTARGS Then Begin Args[N] := A; Inc(N); End;
        End;
        Inc(I);
      End;
      If (I <= Length(S)) And (S[I] = ';') Then Inc(I);
      If N = 0 Then ParseSigType := ClassT(C)
      Else ParseSigType := ClassTA(C, N, Args);
    End;
  Else
    Inc(I);
  End;
End;

{ Lit <T:bound...> et enregistre les variables dans l'echelle ; retourne leurs
  types dans Res }
Procedure ParseTParams(Const S : String; Var I : LongInt; Var Res : Array Of LongInt; Var N : LongInt);
Var Name : String; Ty, B, First : LongInt;
Begin
  N := 0;
  If (I > Length(S)) Or (S[I] <> '<') Then Exit;
  Inc(I);
  While (I <= Length(S)) And (S[I] <> '>') Do Begin
    Name := '';
    While (I <= Length(S)) And (S[I] <> ':') Do Begin Name := Name + S[I]; Inc(I); End;
    Ty := NewTVar(Name, 0);
    PushSig(Name, Ty);
    If N <= High(Res) Then Begin Res[N] := Ty; Inc(N); End;
    First := 1;
    While (I <= Length(S)) And (S[I] = ':') Do Begin
      Inc(I);
      If (I <= Length(S)) And (S[I] <> ':') Then Begin
        B := ParseSigType(S, I);
        If First = 1 Then TVars[Types[Ty].TV].Bound := B;
      End;
      First := 0;
    End;
  End;
  Inc(I);
End;

Procedure LoadLibHeader(C : LongInt);
Var Line, Sig : String; I, N, Base, K : LongInt; Tp : Array[0..15] Of LongInt; T : LongInt;
    Ifs : Array Of LongInt; NI : LongInt;
Begin
  If Classes[C].LibLine = -2 Then Begin LoadExtClass(C); Exit; End;
  Classes[C].Loaded := 1;
  Line := ExpandAbbr(LibTab[Classes[C].LibLine]);
  Classes[C].Flags := ToInt(BarField(Line, 1));
  Sig := BarField(Line, 3);
  Base := NSig;
  I := 1;
  ParseTParams(Sig, I, Tp, N);
  SetLength(Classes[C].TPars, N);
  For K := 0 To N - 1 Do Classes[C].TPars[K] := Tp[K];
  T := ParseSigType(Sig, I);
  If C = C_OBJECT Then Classes[C].Super := 0
  Else If (Classes[C].Flags And ACC_INTERFACE) <> 0 Then Classes[C].Super := T_OBJECT
  Else Classes[C].Super := T;
  NI := 0;
  SetLength(Ifs, 0);
  While I <= Length(Sig) Do Begin
    T := ParseSigType(Sig, I);
    If T <> TY_NONE Then Begin
      SetLength(Ifs, NI + 1);
      Ifs[NI] := T;
      Inc(NI);
    End;
  End;
  Classes[C].Ifaces := Ifs;
  NSig := Base;
  { classe imbriquee : lien avec la classe englobante }
  K := LastPos('$', Classes[C].Name);
  If K > 0 Then Begin
    Classes[C].Outer := LookupClass(Copy(Classes[C].Name, 1, K - 1));
    Classes[C].Simple := Copy(Classes[C].Name, K + 1, Length(Classes[C].Name));
    If Classes[C].Outer >= 0 Then Begin
      N := Length(Classes[Classes[C].Outer].Nested);
      SetLength(Classes[Classes[C].Outer].Nested, N + 1);
      Classes[Classes[C].Outer].Nested[N] := C;
    End;
  End;
End;

Function NewField(C : LongInt; Const Name : String; Flags, Typ : LongInt) : LongInt;
Begin
  If NFields >= Length(Fields) Then SetLength(Fields, NFields * 2 + 512);
  Fields[NFields].Name := Name;
  Fields[NFields].Owner := C;
  Fields[NFields].Flags := Flags;
  Fields[NFields].Typ := Typ;
  Fields[NFields].Next := -1;
  Fields[NFields].CK := 0;
  Fields[NFields].ConstState := 2;
  Fields[NFields].Decl := 0;
  Fields[NFields].ConstInit := 0;
  If Classes[C].LastField >= 0 Then Fields[Classes[C].LastField].Next := NFields
  Else Classes[C].FirstField := NFields;
  Classes[C].LastField := NFields;
  NewField := NFields;
  Inc(NFields);
End;

Function NewMeth(C : LongInt; Const Name : String; Flags : LongInt) : LongInt;
Begin
  If NMeths >= Length(Meths) Then SetLength(Meths, NMeths * 2 + 512);
  Meths[NMeths].Name := Name;
  Meths[NMeths].Owner := C;
  Meths[NMeths].Flags := Flags;
  Meths[NMeths].NPar := 0;
  SetLength(Meths[NMeths].Par, 0);
  SetLength(Meths[NMeths].ParNames, 0);
  SetLength(Meths[NMeths].TPar, 0);
  Meths[NMeths].Ret := TY_VOID;
  Meths[NMeths].Desc := '';
  Meths[NMeths].Next := -1;
  Meths[NMeths].Decl := 0;
  Meths[NMeths].Varargs := False;
  Meths[NMeths].Lambda := -1;
  Meths[NMeths].Bridge := -1;
  Meths[NMeths].Synth := 0;
  SetLength(Meths[NMeths].PreLoc, 0);
  SetLength(Meths[NMeths].PostLoc, 0);
  Meths[NMeths].BodyN := 0;
  SetLength(Meths[NMeths].Thr, 0);
  If Classes[C].LastMeth >= 0 Then Meths[Classes[C].LastMeth].Next := NMeths
  Else Classes[C].FirstMeth := NMeths;
  Classes[C].LastMeth := NMeths;
  NewMeth := NMeths;
  Inc(NMeths);
End;

Function NewSynMethod(C : LongInt; Const Name : String; Flags, Synth : LongInt; Const Desc : String; Ret : LongInt) : LongInt;
Var M : LongInt;
Begin
  M := NewMeth(C, Name, Flags);
  Meths[M].Synth := Synth;
  Meths[M].Desc := Desc;
  Meths[M].Ret := Ret;
  NewSynMethod := M;
End;

Procedure LoadLibMembers(C : LongInt);
Var
  K, I, N, Base, F, M, Fl, Np, T : LongInt;
  Line, Sig, Desc, Cv : String;
  Tp : Array[0..15] Of LongInt;
  Cn, K2 : LongInt;
  Bits : TDblBits;
Begin
  Classes[C].Loaded := 2;
  If Classes[C].LibLine < 0 Then Exit;
  Base := NSig;
  For K := 0 To Length(Classes[C].TPars) - 1 Do
    PushSig(TVars[Types[Classes[C].TPars[K]].TV].Name, Classes[C].TPars[K]);
  K := Classes[C].LibLine + 1;
  While (K < LIBN) And (LibTab[K][1] <> 'C') Do Begin
    Line := ExpandAbbr(LibTab[K]);
    Inc(K);
    Fl := ToInt(BarField(Line, 1));
    If Line[1] = 'F' Then Begin
      Desc := BarField(Line, 3);
      Sig := BarField(Line, 4);
      If Sig = '' Then Sig := Desc;
      I := 1;
      T := ParseSigType(Sig, I);
      F := NewField(C, BarField(Line, 2), Fl, T);
      Cv := BarField(Line, 5);
      If Cv <> '' Then Begin
        Case Cv[1] Of
          'I', 'Z', 'C' : Begin Fields[F].CK := CK_INT; Fields[F].CI := ToInt64(Copy(Cv, 2, 40)); End;
          'J' : Begin Fields[F].CK := CK_LONG; Fields[F].CI := ToInt64(Copy(Cv, 2, 40)); End;
          'F' : Begin
            Fields[F].CK := CK_FLOAT;
            Bits.I := 0;
            Bits.L := ToInt(Copy(Cv, 2, 40));
            Fields[F].CD := Bits.S;
          End;
          'D' : Begin
            Fields[F].CK := CK_DOUBLE;
            Bits.I := ToInt64(Copy(Cv, 2, 40));
            Fields[F].CD := Bits.D;
          End;
          'S' : Begin Fields[F].CK := CK_STR; Fields[F].CS := Copy(Cv, 2, 100); End;
        End;
      End;
    End
    Else Begin
      Desc := BarField(Line, 3);
      Sig := BarField(Line, 4);
      If Sig = '' Then Sig := Desc;
      M := NewMeth(C, BarField(Line, 2), Fl And $FFFF);
      If (Fl And MOD_DEFAULT) <> 0 Then Meths[M].Flags := Meths[M].Flags Or MOD_DEFAULT;
      Meths[M].Desc := Desc;
      Meths[M].Varargs := (Fl And ACC_VARARGS) <> 0;
      Meths[M].Flags := Meths[M].Flags And Not ACC_VARARGS;
      If Meths[M].Varargs Then Meths[M].Flags := Meths[M].Flags Or ACC_VARARGS;
      I := 1;
      N := 0;
      Cn := NSig;
      ParseTParams(Sig, I, Tp, N);
      SetLength(Meths[M].TPar, N);
      For T := 0 To N - 1 Do Meths[M].TPar[T] := Tp[T];
      Inc(I);    { '(' }
      Np := 0;
      While (I <= Length(Sig)) And (Sig[I] <> ')') Do Begin
        SetLength(Meths[M].Par, Np + 1);
        Meths[M].Par[Np] := ParseSigType(Sig, I);
        Inc(Np);
      End;
      Inc(I);
      Meths[M].NPar := Np;
      Meths[M].Ret := ParseSigType(Sig, I);
      NSig := Cn;
      Cv := BarField(Line, 5);
      If Cv <> '' Then Begin
        K2 := 1;
        While K2 <= Length(Cv) Do Begin
          T := Pos(',', Copy(Cv, K2, Length(Cv)));
          If T = 0 Then T := Length(Cv) - K2 + 2;
          SetLength(Meths[M].Thr, Length(Meths[M].Thr) + 1);
          Meths[M].Thr[Length(Meths[M].Thr) - 1] := GetClass(Copy(Cv, K2, T - 1));
          Inc(K2, T);
        End;
      End;
    End;
  End;
  NSig := Base;
End;

Procedure InitLibrary;
Var I : LongInt;
Begin
  MapInit(LibIndex, 4099);
  For I := 0 To LIBN - 1 Do
    If LibTab[I][1] = 'C' Then
      MapPut(LibIndex, BarField(LibTab[I], 2), I);
End;

{ ----- boites (boxing) --------------------------------------------------- }

Function BoxClassName(P : LongInt) : String;
Begin
  Case P Of
    TY_BOOLEAN : BoxClassName := 'java/lang/Boolean';
    TY_BYTE    : BoxClassName := 'java/lang/Byte';
    TY_CHAR    : BoxClassName := 'java/lang/Character';
    TY_SHORT   : BoxClassName := 'java/lang/Short';
    TY_INT     : BoxClassName := 'java/lang/Integer';
    TY_LONG    : BoxClassName := 'java/lang/Long';
    TY_FLOAT   : BoxClassName := 'java/lang/Float';
    TY_DOUBLE  : BoxClassName := 'java/lang/Double';
  Else
    BoxClassName := '';
  End;
End;

Function BoxedType(P : LongInt) : LongInt;
Begin
  If IsPrim(P) Then BoxedType := ClassT(BoxCls[P]) Else BoxedType := P;
End;

{ Type primitif correspondant a une classe enveloppe, ou TY_NONE }
Function UnboxedType(T : LongInt) : LongInt;
Var P, C : LongInt;
Begin
  UnboxedType := TY_NONE;
  If Not IsClassT(T) Then Exit;
  C := Types[T].Cls;
  For P := TY_BOOLEAN To TY_DOUBLE Do
    If BoxCls[P] = C Then Begin UnboxedType := P; Exit; End;
End;

Procedure InitTypes;
Var I : LongInt; S : String; R : TTypeRec;
Begin
  { types primitifs reserves : indices 0..10 }
  NTypes := 0;
  MapInit(TypeMap, 8191);
  SetLength(Types, 1024);
  For I := 0 To TY_FIRSTDYN - 1 Do Begin
    FillChar(Types[I], SizeOf(TTypeRec), 0);
    Types[I].Kind := TYK_PRIM;
  End;
  NTypes := TY_FIRSTDYN;
  NTVars := 0;
  MapInit(ClassMap, 8191);
  MapInit(SubMap, 8191);
  MapInit(ExtMemo, 4099);
  NClasses := 0; NFields := 0; NMeths := 0; NSig := 0;
  InitLibrary;
  C_OBJECT := GetClass('java/lang/Object');
  T_OBJECT := ClassT(C_OBJECT);
  Classes[C_OBJECT].Super := 0;
  C_STRING := GetClass('java/lang/String');
  T_STRING := ClassT(C_STRING);
  C_CLASS := GetClass('java/lang/Class');
  T_CLASS := ClassT(C_CLASS);
  C_THROWABLE := GetClass('java/lang/Throwable');
  T_THROWABLE := ClassT(C_THROWABLE);
  C_ENUM := GetClass('java/lang/Enum');
  C_ITERABLE := GetClass('java/lang/Iterable');
  C_ITERATOR := GetClass('java/util/Iterator');
  C_NUMBER := GetClass('java/lang/Number');
  C_RUNTIMEEX := GetClass('java/lang/RuntimeException');
  C_ERROR := GetClass('java/lang/Error');
  C_STRINGBUILDER := GetClass('java/lang/StringBuilder');
  C_CHARSEQ := GetClass('java/lang/CharSequence');
  C_CLONEABLE := GetClass('java/lang/Cloneable');
  C_SERIAL := GetClass('java/io/Serializable');
  C_RECORD := GetClass('java/lang/Record');
  C_COMPARABLE := GetClass('java/lang/Comparable');
  C_ASSERTERR := GetClass('java/lang/AssertionError');
  For I := TY_BOOLEAN To TY_DOUBLE Do Begin
    S := BoxClassName(I);
    BoxCls[I] := GetClass(S);
  End;
  { type "reference inconnue" }
  Begin
    FillChar(R, SizeOf(R), 0);
    R.Kind := TYK_ANY;
    T_ANY := InternType(R);
  End;
End;

{ ============================================================================
  3b. CLASSES EXTERNES : lecture de fichiers .class (repertoires et archives
      jar/zip du classpath, image des modules du JDK : lib/modules)
  ============================================================================ }

Type
  TZipEnt = Record
    Name   : String;
    Off    : LongInt;
    CSize  : LongInt;
    USize  : LongInt;
    Method : LongInt;
  End;

  TCPEnt = Record
    Kind : Byte;                { 1 = repertoire, 2 = archive }
    Path : String;
    Ents : Array Of TZipEnt;
    NEnts: LongInt;
    Map  : TStrMap;
  End;

Var
  CPath     : Array Of TCPEnt;
  JdkImage  : String;            { chemin de lib/modules }
  JdkReady  : Boolean;
  JdkTried  : Boolean;
  JdkTabLen, JdkLocSize, JdkStrSize, JdkIndexSize : LongInt;
  JdkRedirect, JdkOffsets, JdkLocs, JdkStrs : TBuf;
  JdkModuleOf : TStrMap;

Const
  NJMODS = 22;
  JdkMods : Array[1..NJMODS] Of String = (
    'java.base', 'java.desktop', 'java.sql', 'java.xml', 'java.logging', 'java.management',
    'java.naming', 'java.net.http', 'java.prefs', 'java.rmi', 'java.scripting',
    'java.security.jgss', 'java.sql.rowset', 'java.compiler', 'java.datatransfer',
    'java.instrument', 'java.xml.crypto', 'jdk.httpserver', 'jdk.unsupported',
    'java.management.rmi', 'jdk.compiler', 'jdk.jfr');

{ ----- lecture de fichiers ----------------------------------------------------- }

Function ReadFileRange(Const Fn : String; Off, Cnt : LongInt; Var B : TBuf) : Boolean;
Var F : File; Got : LongInt;
Begin
  ReadFileRange := False;
  Assign(F, Fn);
  Reset(F, 1);
  If IOResult <> 0 Then Exit;
  If Off + Cnt > FileSize(F) Then Cnt := FileSize(F) - Off;
  If Cnt < 0 Then Begin Close(F); Exit; End;
  BInit(B);
  BEnsure(B, Cnt + 1);
  Seek(F, Off);
  If Cnt > 0 Then BlockRead(F, B.D[0], Cnt, Got) Else Got := 0;
  B.N := Got;
  Close(F);
  If IOResult <> 0 Then Exit;
  ReadFileRange := Got = Cnt;
End;

Function RdU1(Var B : TBuf; P : LongInt) : LongInt;
Begin
  If (P < 0) Or (P >= B.N) Then RdU1 := 0 Else RdU1 := B.D[P];
End;

Function RdU2(Var B : TBuf; P : LongInt) : LongInt;
Begin RdU2 := (RdU1(B, P) Shl 8) Or RdU1(B, P + 1); End;

Function RdU4(Var B : TBuf; P : LongInt) : LongInt;
Begin RdU4 := LongInt(((RdU1(B, P) Shl 24) Or (RdU1(B, P + 1) Shl 16) Or (RdU1(B, P + 2) Shl 8) Or RdU1(B, P + 3)) And $FFFFFFFF); End;

{ little-endian (archives zip, image jimage) }
Function RdL2(Var B : TBuf; P : LongInt) : LongInt;
Begin RdL2 := RdU1(B, P) Or (RdU1(B, P + 1) Shl 8); End;

Function RdL4(Var B : TBuf; P : LongInt) : LongInt;
Begin RdL4 := LongInt((Int64(RdU1(B, P)) Or (Int64(RdU1(B, P + 1)) Shl 8) Or (Int64(RdU1(B, P + 2)) Shl 16) Or
                       (Int64(RdU1(B, P + 3)) Shl 24)) And $FFFFFFFF); End;

Function BytesToStr(Var B : TBuf; P, N : LongInt) : String;
Var I : LongInt; S : String;
Begin
  SetLength(S, N);
  For I := 1 To N Do S[I] := Chr(RdU1(B, P + I - 1));
  BytesToStr := S;
End;

{ ----- decompression (inflate, RFC 1951) --------------------------------------------- }

Type
  TInfl = Record
    Src    : ^TBuf;
    Pos    : LongInt;
    BitBuf : LongInt;
    BitCnt : LongInt;
    Err    : Boolean;
  End;
  THuff = Record
    Count : Array[0..15] Of LongInt;
    Sym   : Array[0..287] Of LongInt;
  End;

Const
  LBase : Array[0..28] Of LongInt = (3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258);
  LExt  : Array[0..28] Of LongInt = (0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0);
  DBase : Array[0..29] Of LongInt = (1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577);
  DExt  : Array[0..29] Of LongInt = (0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13);
  CLOrder : Array[0..18] Of LongInt = (16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15);

Function InflBits(Var S : TInfl; Need : LongInt) : LongInt;
Var V : LongInt;
Begin
  V := S.BitBuf;
  While S.BitCnt < Need Do Begin
    If S.Pos >= S.Src^.N Then Begin S.Err := True; InflBits := 0; Exit; End;
    V := V Or (S.Src^.D[S.Pos] Shl S.BitCnt);
    Inc(S.Pos);
    Inc(S.BitCnt, 8);
  End;
  S.BitBuf := V Shr Need;
  Dec(S.BitCnt, Need);
  InflBits := V And ((1 Shl Need) - 1);
End;

Procedure HuffBuild(Var H : THuff; Const Len : Array Of LongInt; N : LongInt);
Var I, Sy : LongInt; Offs : Array[0..15] Of LongInt;
Begin
  For I := 0 To 15 Do H.Count[I] := 0;
  For Sy := 0 To N - 1 Do Inc(H.Count[Len[Sy]]);
  Offs[1] := 0;
  For I := 1 To 14 Do Offs[I + 1] := Offs[I] + H.Count[I];
  For Sy := 0 To N - 1 Do
    If Len[Sy] <> 0 Then Begin
      H.Sym[Offs[Len[Sy]]] := Sy;
      Inc(Offs[Len[Sy]]);
    End;
End;

Function InflDecode(Var S : TInfl; Var H : THuff) : LongInt;
Var Code, First, Index, Len, Cnt : LongInt;
Begin
  Code := 0; First := 0; Index := 0;
  For Len := 1 To 15 Do Begin
    Code := Code Or InflBits(S, 1);
    Cnt := H.Count[Len];
    If Code - Cnt < First Then Begin InflDecode := H.Sym[Index + (Code - First)]; Exit; End;
    Inc(Index, Cnt);
    First := (First + Cnt) Shl 1;
    Code := Code Shl 1;
    If S.Err Then Break;
  End;
  S.Err := True;
  InflDecode := -1;
End;

Function Inflate(Var Src : TBuf; Var Dst : TBuf) : Boolean;
Var
  S : TInfl; Last, Typ, Len, NLen, I, Sy, Sz, Dist, NL, ND, NC, Idx : LongInt;
  Lit, Dis : THuff; Lens : Array[0..319] Of LongInt; Lc : Array[0..18] Of LongInt; Clh : THuff;
  LL : Array[0..287] Of LongInt; DL : Array[0..29] Of LongInt;
Begin
  S.Src := @Src; S.Pos := 0; S.BitBuf := 0; S.BitCnt := 0; S.Err := False;
  BInit(Dst);
  Repeat
    Last := InflBits(S, 1);
    Typ := InflBits(S, 2);
    If Typ = 0 Then Begin
      S.BitBuf := 0; S.BitCnt := 0;
      If S.Pos + 4 > Src.N Then Begin Inflate := False; Exit; End;
      Len := Src.D[S.Pos] Or (Src.D[S.Pos + 1] Shl 8);
      Inc(S.Pos, 4);
      If S.Pos + Len > Src.N Then Begin Inflate := False; Exit; End;
      BEnsure(Dst, Len);
      For I := 0 To Len - 1 Do Begin Dst.D[Dst.N] := Src.D[S.Pos + I]; Inc(Dst.N); End;
      Inc(S.Pos, Len);
    End
    Else If Typ = 3 Then Begin Inflate := False; Exit; End
    Else Begin
      If Typ = 1 Then Begin
        For I := 0 To 143 Do LL[I] := 8;
        For I := 144 To 255 Do LL[I] := 9;
        For I := 256 To 279 Do LL[I] := 7;
        For I := 280 To 287 Do LL[I] := 8;
        HuffBuild(Lit, LL, 288);
        For I := 0 To 29 Do DL[I] := 5;
        HuffBuild(Dis, DL, 30);
      End
      Else Begin
        NL := InflBits(S, 5) + 257;
        ND := InflBits(S, 5) + 1;
        NC := InflBits(S, 4) + 4;
        For I := 0 To 18 Do Lc[I] := 0;
        For I := 0 To NC - 1 Do Lc[CLOrder[I]] := InflBits(S, 3);
        HuffBuild(Clh, Lc, 19);
        Idx := 0;
        While Idx < NL + ND Do Begin
          Sy := InflDecode(S, Clh);
          If S.Err Then Begin Inflate := False; Exit; End;
          If Sy < 16 Then Begin Lens[Idx] := Sy; Inc(Idx); End
          Else Begin
            Len := 0;
            If Sy = 16 Then Begin
              If Idx = 0 Then Begin Inflate := False; Exit; End;
              Len := Lens[Idx - 1];
              Sz := 3 + InflBits(S, 2);
            End
            Else If Sy = 17 Then Sz := 3 + InflBits(S, 3)
            Else Sz := 11 + InflBits(S, 7);
            If Idx + Sz > NL + ND Then Begin Inflate := False; Exit; End;
            While Sz > 0 Do Begin Lens[Idx] := Len; Inc(Idx); Dec(Sz); End;
          End;
        End;
        For I := 0 To NL - 1 Do LL[I] := Lens[I];
        HuffBuild(Lit, LL, NL);
        For I := 0 To ND - 1 Do DL[I] := Lens[NL + I];
        HuffBuild(Dis, DL, ND);
      End;
      While True Do Begin
        Sy := InflDecode(S, Lit);
        If S.Err Then Begin Inflate := False; Exit; End;
        If Sy < 256 Then Begin B1(Dst, Sy); End
        Else If Sy = 256 Then Break
        Else Begin
          Dec(Sy, 257);
          If Sy > 28 Then Begin Inflate := False; Exit; End;
          Len := LBase[Sy] + InflBits(S, LExt[Sy]);
          Sy := InflDecode(S, Dis);
          If S.Err Or (Sy < 0) Or (Sy > 29) Then Begin Inflate := False; Exit; End;
          Dist := DBase[Sy] + InflBits(S, DExt[Sy]);
          If Dist > Dst.N Then Begin Inflate := False; Exit; End;
          BEnsure(Dst, Len);
          For I := 1 To Len Do Begin Dst.D[Dst.N] := Dst.D[Dst.N - Dist]; Inc(Dst.N); End;
        End;
      End;
    End;
    If S.Err Then Begin Inflate := False; Exit; End;
  Until Last = 1;
  Inflate := True;
  NLen := 0;
End;

{ ----- archives zip / jar -------------------------------------------------------------- }

Procedure OpenZip(Var E : TCPEnt);
Var F : File; Sz, Pos, Cnt, I, P, NL, XL, CL : LongInt; Tail, Cd : TBuf; Base : LongInt;
Begin
  E.NEnts := 0;
  MapInit(E.Map, 2039);
  Assign(F, E.Path);
  Reset(F, 1);
  If IOResult <> 0 Then Exit;
  Sz := FileSize(F);
  Close(F);
  Base := Sz - 70000;
  If Base < 0 Then Base := 0;
  If Not ReadFileRange(E.Path, Base, Sz - Base, Tail) Then Exit;
  Pos := -1;
  For I := Tail.N - 22 Downto 0 Do
    If RdL4(Tail, I) = $06054B50 Then Begin Pos := I; Break; End;
  If Pos < 0 Then Exit;
  Cnt := RdL2(Tail, Pos + 10);
  P := RdL4(Tail, Pos + 16);
  Sz := RdL4(Tail, Pos + 12);
  If Not ReadFileRange(E.Path, P, Sz, Cd) Then Exit;
  SetLength(E.Ents, Cnt);
  P := 0;
  For I := 0 To Cnt - 1 Do Begin
    If RdL4(Cd, P) <> $02014B50 Then Break;
    E.Ents[E.NEnts].Method := RdL2(Cd, P + 10);
    E.Ents[E.NEnts].CSize := RdL4(Cd, P + 20);
    E.Ents[E.NEnts].USize := RdL4(Cd, P + 24);
    NL := RdL2(Cd, P + 28); XL := RdL2(Cd, P + 30); CL := RdL2(Cd, P + 32);
    E.Ents[E.NEnts].Off := RdL4(Cd, P + 42);
    E.Ents[E.NEnts].Name := BytesToStr(Cd, P + 46, NL);
    MapPut(E.Map, E.Ents[E.NEnts].Name, E.NEnts);
    Inc(E.NEnts);
    Inc(P, 46 + NL + XL + CL);
  End;
End;

Function ZipExtract(Var E : TCPEnt; K : LongInt; Var Out : TBuf) : Boolean;
Var Hd, Raw : TBuf; Start : LongInt;
Begin
  ZipExtract := False;
  If Not ReadFileRange(E.Path, E.Ents[K].Off, 30, Hd) Then Exit;
  Start := E.Ents[K].Off + 30 + RdL2(Hd, 26) + RdL2(Hd, 28);
  If Not ReadFileRange(E.Path, Start, E.Ents[K].CSize, Raw) Then Exit;
  If E.Ents[K].Method = 0 Then Begin
    Out := Raw;
    ZipExtract := True;
  End
  Else If E.Ents[K].Method = 8 Then ZipExtract := Inflate(Raw, Out);
End;

{ ----- image des modules du JDK (jimage) ---------------------------------------------------- }

Function JHash(Const S : String; Seed : Int64) : Int64;
Var I : LongInt; H : Int64;
Begin
  H := Seed And $FFFFFFFF;
  For I := 1 To Length(S) Do
    H := ((H * $01000193) And $FFFFFFFF) Xor Ord(S[I]);
  JHash := H And $7FFFFFFF;
End;

Procedure JdkOpen;
Var Hd : TBuf; Tmp : TBuf; Dta : TBuf;
  Procedure TryPath(Const P : String);
  Begin
    If JdkReady Then Exit;
    If ReadFileRange(P, 0, 28, Hd) Then
      If RdL4(Hd, 0) = LongInt($CAFEDADA) Then Begin
        JdkImage := P;
        JdkReady := True;
      End;
  End;
  Procedure TryHome(Const H : String);
  Begin
    If H <> '' Then TryPath(H + '/lib/modules');
  End;
  Procedure TryDir(Const Parent : String);
  Var Sr : SearchRec;
  Begin
    FindFirst(Parent + '*', Directory, Sr);
    While (DosError = 0) And Not JdkReady Do Begin
      If (Sr.Name <> '.') And (Sr.Name <> '..') And ((Sr.Attr And Directory) <> 0) Then TryHome(Parent + Sr.Name);
      FindNext(Sr);
    End;
  End;
Begin
  If JdkTried Then Exit;
  JdkTried := True;
  TryHome(GetEnv('JAVA_HOME'));
  TryDir('/usr/lib/jvm/');
  TryDir('/usr/java/');
  TryDir('/Library/Java/JavaVirtualMachines/');
  TryDir('C:\Program Files\Java\');
  TryDir('C:\Program Files\Eclipse Adoptium\');
  If Not JdkReady Then Exit;
  JdkTabLen := RdL4(Hd, 16);
  JdkLocSize := RdL4(Hd, 20);
  JdkStrSize := RdL4(Hd, 24);
  JdkIndexSize := 28 + JdkTabLen * 8 + JdkLocSize + JdkStrSize;
  JdkReady := ReadFileRange(JdkImage, 28, JdkTabLen * 4, JdkRedirect) And
              ReadFileRange(JdkImage, 28 + JdkTabLen * 4, JdkTabLen * 4, JdkOffsets) And
              ReadFileRange(JdkImage, 28 + JdkTabLen * 8, JdkLocSize, JdkLocs) And
              ReadFileRange(JdkImage, 28 + JdkTabLen * 8 + JdkLocSize, JdkStrSize, JdkStrs);
  MapInit(JdkModuleOf, 521);
  Tmp.N := 0; Dta.N := 0;
End;

Function JdkStr(Off : LongInt) : String;
Var S : String; P : LongInt;
Begin
  S := '';
  P := Off;
  While (P < JdkStrs.N) And (JdkStrs.D[P] <> 0) Do Begin S := S + Chr(JdkStrs.D[P]); Inc(P); End;
  JdkStr := S;
End;

{ Retrouve (offset, taille) d'une ressource /module/chemin ; faux si absente }
Function JdkLocate(Const Path : String; Var ROff, RSize, RComp : LongInt) : Boolean;
Var Idx, V, Loc, P, Kind, Len, I, Vv : LongInt; Attr : Array[0..8] Of LongInt; Full, Nm : String; B : LongInt;
Begin
  JdkLocate := False;
  If (Not JdkReady) Or (JdkTabLen = 0) Then Exit;
  Idx := JHash(Path, $01000193) Mod JdkTabLen;
  V := RdL4(JdkRedirect, Idx * 4);
  If V < 0 Then Loc := -1 - V
  Else If V > 0 Then Loc := JHash(Path, V) Mod JdkTabLen
  Else Exit;
  P := RdL4(JdkOffsets, Loc * 4);
  For I := 0 To 8 Do Attr[I] := 0;
  While P < JdkLocs.N Do Begin
    B := JdkLocs.D[P];
    Kind := B Shr 3;
    If Kind = 0 Then Break;
    Len := (B And 7) + 1;
    Vv := 0;
    For I := 1 To Len Do Vv := (Vv Shl 8) Or JdkLocs.D[P + I];
    If Kind <= 7 Then Attr[Kind] := Vv;
    Inc(P, Len + 1);
  End;
  { verification du nom complet }
  Full := '';
  Nm := JdkStr(Attr[1]);
  If Nm <> '' Then Full := '/' + Nm + '/';
  Nm := JdkStr(Attr[2]);
  If Nm <> '' Then Full := Full + Nm + '/';
  Full := Full + JdkStr(Attr[3]);
  Nm := JdkStr(Attr[4]);
  If Nm <> '' Then Full := Full + '.' + Nm;
  If Full <> Path Then Exit;
  ROff := JdkIndexSize + Attr[5];
  RComp := Attr[6];
  If RComp <> 0 Then RSize := Attr[6] Else RSize := Attr[7];
  JdkLocate := True;
End;

Function JdkModuleFor(Const Name : String; Var ROff, RSize, RComp : LongInt) : Boolean;
Var I, Slash : LongInt; Pkg : String; M : LongInt;
Begin
  JdkModuleFor := False;
  JdkOpen;
  If Not JdkReady Then Exit;
  Slash := LastPos('/', Name);
  Pkg := Copy(Name, 1, Slash);
  M := MapFind(JdkModuleOf, Pkg);
  If M >= 0 Then Begin
    JdkModuleFor := JdkLocate('/' + JdkMods[M] + '/' + Name + '.class', ROff, RSize, RComp);
    Exit;
  End;
  For I := 1 To NJMODS Do
    If JdkLocate('/' + JdkMods[I] + '/' + Name + '.class', ROff, RSize, RComp) Then Begin
      MapPut(JdkModuleOf, Pkg, I);
      JdkModuleFor := True;
      Exit;
    End;
End;

{ ----- recherche d'une classe externe ----------------------------------------------------- }

Function ExtFind(Const Name : String; UseJdk : Boolean) : Boolean;
Var I, K, A, B, C : LongInt; Key : String; Fn : String;
Begin
  ExtFind := False;
  If Pos('.', Name) > 0 Then Exit;
  If Length(Name) = 0 Then Exit;
  Key := Name;
  If UseJdk Then Key := '#' + Key;
  K := MapFind(ExtMemo, Key);
  If K >= 0 Then Begin ExtFind := K = 1; Exit; End;
  If Not UseJdk Then Begin
    For I := 0 To NCPath - 1 Do Begin
      If CPath[I].Kind = 1 Then Begin
        If FileExists(CPath[I].Path + Name + '.class') Then Begin MapPut(ExtMemo, Key, 1); ExtFind := True; Exit; End;
      End
      Else If MapFind(CPath[I].Map, Name + '.class') >= 0 Then Begin MapPut(ExtMemo, Key, 1); ExtFind := True; Exit; End;
    End;
  End
  Else If JdkModuleFor(Name, A, B, C) Then Begin
    If C = 0 Then Begin MapPut(ExtMemo, Key, 1); ExtFind := True; Exit; End;
  End;
  MapPut(ExtMemo, Key, 0);
End;

Function ExtGetBytes(Const Name : String; Var Out : TBuf) : Boolean;
Var I, K, A, B, C : LongInt;
Begin
  ExtGetBytes := False;
  For I := 0 To NCPath - 1 Do Begin
    If CPath[I].Kind = 1 Then Begin
      If ReadFileRange(CPath[I].Path + Name + '.class', 0, 100000000, Out) Then Begin ExtGetBytes := True; Exit; End;
    End
    Else Begin
      K := MapFind(CPath[I].Map, Name + '.class');
      If (K >= 0) And ZipExtract(CPath[I], K, Out) Then Begin ExtGetBytes := True; Exit; End;
    End;
  End;
  If JdkModuleFor(Name, A, B, C) And (C = 0) Then
    ExtGetBytes := ReadFileRange(JdkImage, A, B, Out);
End;

{ ----- analyse d'un fichier .class ------------------------------------------------------------- }

Function CountDescParams(Const D : String) : LongInt;
Var I, N : LongInt;
Begin
  N := 0; I := 2;
  While (I <= Length(D)) And (D[I] <> ')') Do Begin
    Inc(N);
    While D[I] = '[' Do Inc(I);
    If D[I] = 'L' Then While D[I] <> ';' Do Inc(I);
    Inc(I);
  End;
  CountDescParams := N;
End;

Procedure LoadExtClass(C : LongInt);
Var
  B : TBuf; Cnt, I, P, Tag, Acc, This_, Sup, NIf, NA, K, AL, AP, Fl, M, F : LongInt;
  CpTag : Array Of Byte; CpA : Array Of LongInt; CpPos : Array Of LongInt; CpStr : Array Of String;
  Sig, Desc, Nm, ClsSig, AName : String; BaseTop, BaseM, N, T, MemStart, ExcPos, ExcN, Cvi, Q, J, Np : LongInt;
  Tp : Array[0..15] Of LongInt; Ifs : Array Of LongInt; NI : LongInt; ClassFl : LongInt;
  Bits : TDblBits;
  Function CName(Idx : LongInt) : String;
  Begin
    If (Idx <= 0) Or (Idx >= Cnt) Then CName := '' Else CName := CpStr[CpA[Idx]];
  End;
  Function UName(Idx : LongInt) : String;
  Begin
    If (Idx <= 0) Or (Idx >= Cnt) Then UName := '' Else UName := CpStr[Idx];
  End;
Begin
  Classes[C].Loaded := 2;
  Classes[C].LibLine := -1;
  If Not ExtGetBytes(Classes[C].Name, B) Then Begin
    Classes[C].Super := T_OBJECT;
    Exit;
  End;
  Cnt := RdU2(B, 8);
  SetLength(CpTag, Cnt); SetLength(CpA, Cnt); SetLength(CpPos, Cnt); SetLength(CpStr, Cnt);
  P := 10;
  I := 1;
  While I < Cnt Do Begin
    Tag := RdU1(B, P);
    CpTag[I] := Tag;
    CpPos[I] := P + 1;
    Case Tag Of
      1 : Begin K := RdU2(B, P + 1); CpStr[I] := BytesToStr(B, P + 3, K); Inc(P, 3 + K); End;
      3, 4 : Inc(P, 5);
      5, 6 : Begin Inc(P, 9); Inc(I); End;
      7, 8, 16, 19, 20 : Begin CpA[I] := RdU2(B, P + 1); Inc(P, 3); End;
      15 : Inc(P, 4);
    Else
      Inc(P, 5);
    End;
    Inc(I);
  End;
  Acc := RdU2(B, P); This_ := RdU2(B, P + 2); Sup := RdU2(B, P + 4); NIf := RdU2(B, P + 6);
  Inc(P, 8);
  BaseTop := NSig;
  ClassFl := Acc And (ACC_PUBLIC Or ACC_FINAL Or ACC_INTERFACE Or ACC_ABSTRACT Or ACC_ANNOTATION Or ACC_ENUM Or ACC_SYNTHETIC);
  If Sup > 0 Then ClsSig := 'L' + CName(Sup) + ';' Else ClsSig := 'Ljava/lang/Object;';
  For I := 0 To NIf - 1 Do Begin
    ClsSig := ClsSig + 'L' + CName(RdU2(B, P)) + ';';
    Inc(P, 2);
  End;
  { saute champs et methodes pour atteindre les attributs de classe }
  MemStart := P;
  Q := P;
  For I := 1 To 2 Do Begin
    K := RdU2(B, Q);
    Inc(Q, 2);
    For J := 1 To K Do Begin
      NA := RdU2(B, Q + 6);
      Inc(Q, 8);
      While NA > 0 Do Begin Inc(Q, 6 + RdU4(B, Q + 2)); Dec(NA); End;
    End;
  End;
  NA := RdU2(B, Q);
  Inc(Q, 2);
  While NA > 0 Do Begin
    AName := UName(RdU2(B, Q));
    AL := RdU4(B, Q + 2);
    AP := Q + 6;
    If AName = 'Signature' Then ClsSig := UName(RdU2(B, AP))
    Else If AName = 'PermittedSubclasses' Then Begin
      K := RdU2(B, AP);
      SetLength(Classes[C].Permits, K);
      For J := 0 To K - 1 Do Classes[C].Permits[J] := GetClass(CName(RdU2(B, AP + 2 + J * 2)));
      Classes[C].PermitsState := 2;
      ClassFl := ClassFl Or MOD_SEALED;
    End
    Else If AName = 'InnerClasses' Then Begin
      K := RdU2(B, AP);
      For J := 0 To K - 1 Do
        If CName(RdU2(B, AP + 2 + J * 8)) = Classes[C].Name Then Begin
          Fl := RdU2(B, AP + 2 + J * 8 + 6);
          ClassFl := ClassFl Or (Fl And (ACC_PRIVATE Or ACC_PROTECTED Or ACC_STATIC Or ACC_PUBLIC));
        End;
    End;
    Inc(Q, 6 + AL);
    Dec(NA);
  End;
  { en-tete : parametres de type, super-classe, interfaces }
  Classes[C].Flags := ClassFl;
  I := 1;
  ParseTParams(ClsSig, I, Tp, N);
  SetLength(Classes[C].TPars, N);
  For K := 0 To N - 1 Do Classes[C].TPars[K] := Tp[K];
  T := ParseSigType(ClsSig, I);
  If (Acc And ACC_INTERFACE) <> 0 Then Classes[C].Super := T_OBJECT
  Else If Sup = 0 Then Classes[C].Super := 0
  Else Classes[C].Super := T;
  NI := 0;
  SetLength(Ifs, 0);
  While I <= Length(ClsSig) Do Begin
    T := ParseSigType(ClsSig, I);
    If T <> TY_NONE Then Begin
      SetLength(Ifs, NI + 1); Ifs[NI] := T; Inc(NI);
    End;
  End;
  Classes[C].Ifaces := Ifs;
  { classe imbriquee }
  K := LastPos('$', Classes[C].Name);
  If K > 0 Then Begin
    Classes[C].Outer := LookupClass(Copy(Classes[C].Name, 1, K - 1));
    Classes[C].Simple := Copy(Classes[C].Name, K + 1, Length(Classes[C].Name));
    If Classes[C].Outer >= 0 Then Begin
      N := Length(Classes[Classes[C].Outer].Nested);
      SetLength(Classes[Classes[C].Outer].Nested, N + 1);
      Classes[Classes[C].Outer].Nested[N] := C;
    End;
  End;
  { champs (I = 1) puis methodes (I = 2) ; les variables de type de la classe sont dans l'echelle }
  Q := MemStart;
  For I := 1 To 2 Do Begin
    K := RdU2(B, Q);
    Inc(Q, 2);
    For J := 1 To K Do Begin
      Fl := RdU2(B, Q);
      Nm := UName(RdU2(B, Q + 2));
      Desc := UName(RdU2(B, Q + 4));
      NA := RdU2(B, Q + 6);
      Inc(Q, 8);
      Sig := Desc;
      Cvi := 0; ExcN := 0; ExcPos := 0;
      While NA > 0 Do Begin
        AName := UName(RdU2(B, Q));
        AL := RdU4(B, Q + 2);
        If AName = 'Signature' Then Sig := UName(RdU2(B, Q + 6))
        Else If AName = 'ConstantValue' Then Cvi := RdU2(B, Q + 6)
        Else If AName = 'Exceptions' Then Begin ExcN := RdU2(B, Q + 6); ExcPos := Q + 8; End;
        Inc(Q, 6 + AL);
        Dec(NA);
      End;
      If ((Fl And ACC_PRIVATE) <> 0) Or ((Fl And ACC_SYNTHETIC) <> 0) Then Continue;
      If I = 1 Then Begin
        T := 1;
        F := NewField(C, Nm, Fl And $FFFF, ParseSigType(Sig, T));
        If (Cvi > 0) And ((Fl And (ACC_STATIC Or ACC_FINAL)) = (ACC_STATIC Or ACC_FINAL)) Then
          Case CpTag[Cvi] Of
            3 : Begin Fields[F].CK := CK_INT; Fields[F].CI := LongInt(RdU4(B, CpPos[Cvi])); End;
            4 : Begin Bits.I := 0; Bits.L := RdU4(B, CpPos[Cvi]); Fields[F].CK := CK_FLOAT; Fields[F].CD := Bits.S; End;
            5 : Begin Fields[F].CK := CK_LONG; Fields[F].CI := (Int64(RdU4(B, CpPos[Cvi])) Shl 32) Or (Int64(RdU4(B, CpPos[Cvi] + 4)) And $FFFFFFFF); End;
            6 : Begin
              Bits.I := (Int64(RdU4(B, CpPos[Cvi])) Shl 32) Or (Int64(RdU4(B, CpPos[Cvi] + 4)) And $FFFFFFFF);
              Fields[F].CK := CK_DOUBLE; Fields[F].CD := Bits.D;
            End;
            8 : Begin Fields[F].CK := CK_STR; Fields[F].CS := UName(CpA[Cvi]); End;
          End;
      End
      Else Begin
        If Nm = '<clinit>' Then Continue;
        M := NewMeth(C, Nm, (Fl And $FFFF) And Not ACC_BRIDGE);
        If ((Acc And ACC_INTERFACE) <> 0) And ((Fl And (ACC_ABSTRACT Or ACC_STATIC Or ACC_PRIVATE)) = 0) Then
          Meths[M].Flags := Meths[M].Flags Or MOD_DEFAULT;
        Meths[M].Desc := Desc;
        Meths[M].Varargs := (Fl And ACC_VARARGS) <> 0;
        T := 1;
        BaseM := NSig;
        ParseTParams(Sig, T, Tp, N);
        SetLength(Meths[M].TPar, N);
        For Np := 0 To N - 1 Do Meths[M].TPar[Np] := Tp[Np];
        Inc(T);
        Np := 0;
        While (T <= Length(Sig)) And (Sig[T] <> ')') Do Begin
          SetLength(Meths[M].Par, Np + 1);
          Meths[M].Par[Np] := ParseSigType(Sig, T);
          Inc(Np);
        End;
        Inc(T);
        Meths[M].NPar := Np;
        Meths[M].Ret := ParseSigType(Sig, T);
        NSig := BaseM;
        { signature generique incomplete (constructeurs internes, enums) : retombe sur le descripteur }
        If Np <> CountDescParams(Desc) Then Begin
          T := 2; Np := 0; SetLength(Meths[M].Par, 0);
          While (T <= Length(Desc)) And (Desc[T] <> ')') Do Begin
            SetLength(Meths[M].Par, Np + 1);
            Meths[M].Par[Np] := ParseSigType(Desc, T);
            Inc(Np);
          End;
          Meths[M].NPar := Np;
        End;
        For Np := 0 To ExcN - 1 Do Begin
          SetLength(Meths[M].Thr, Length(Meths[M].Thr) + 1);
          Meths[M].Thr[Length(Meths[M].Thr) - 1] := GetClass(CName(RdU2(B, ExcPos + Np * 2)));
        End;
      End;
    End;
  End;
  NSig := BaseTop;
  This_ := This_;
End;

{ Ajoute un element du classpath : repertoire ou archive }
Procedure AddClassPath(Const Path : String);
Var P : String;
Begin
  P := Path;
  If P = '' Then Exit;
  If NCPath >= Length(CPath) Then SetLength(CPath, NCPath + 8);
  If (Length(P) > 4) And ((UpCase(Copy(P, Length(P) - 3, 4)) = '.JAR') Or (UpCase(Copy(P, Length(P) - 3, 4)) = '.ZIP')) Then Begin
    CPath[NCPath].Kind := 2;
    CPath[NCPath].Path := P;
    OpenZip(CPath[NCPath]);
  End
  Else Begin
    If (P[Length(P)] <> '/') And (P[Length(P)] <> '\') Then P := P + '/';
    CPath[NCPath].Kind := 1;
    CPath[NCPath].Path := P;
  End;
  Inc(NCPath);
End;

Procedure SetClassPath(Const S : String);
Var I : LongInt; Cur : String; Sep : Char;
Begin
  Sep := ':';
  If (Pos(';', S) > 0) Or ((Length(S) > 1) And (S[2] = ':') And (Pos('\', S) > 0)) Then Sep := ';';
  Cur := '';
  For I := 1 To Length(S) Do
    If S[I] = Sep Then Begin AddClassPath(Cur); Cur := ''; End
    Else Cur := Cur + S[I];
  AddClassPath(Cur);
End;

{ ============================================================================
  4. ANALYSE SEMANTIQUE (1/4) : portees, resolution des noms de types,
     entree des classes, en-tetes et membres
  ============================================================================ }

Const
  SC_LOCAL      = 1;
  SC_CLASSMARK  = 2;
  SC_LOCALCLASS = 3;
  SC_TPARAM     = 4;

  CTX_METHOD = 0;
  CTX_LAMBDA = 1;
  CTX_CLASS  = 2;

Type
  TScopeEnt = Record
    Kind : Byte;
    Name : String;
    Ref  : LongInt;
  End;

  TLocalRec = Record
    Name      : String;
    Typ       : LongInt;
    Flags     : LongInt;
    Ctx       : LongInt;
    Decl      : LongInt;
    Slot      : LongInt;
    SlotOwner : LongInt;
    CK        : Byte;
    CI        : Int64;
    CD        : Double;
    CS        : String;
    Assigns   : LongInt;
    HasInit   : Boolean;
    Line      : LongInt;
    Rethrow   : Array Of LongInt;
  End;

  TCtxRec = Record
    Kind     : Byte;
    Parent   : LongInt;
    Caps     : Array Of LongInt;
    UsesThis : Boolean;
    Cls      : LongInt;
    Node     : LongInt;
    NewSites : Array Of LongInt;   { classes locales instanciees }
  End;

  TLambdaRec = Record
    Node     : LongInt;
    Ctx      : LongInt;
    SAM      : LongInt;        { methode de l'interface fonctionnelle }
    IfaceT   : LongInt;        { type de l'interface instanciee }
    Meth     : LongInt;        { methode synthetique }
    OwnerCls : LongInt;
    InStatic : Boolean;
    ParT     : Array Of LongInt;
    RetT     : LongInt;
    RetNodes : Array Of LongInt;
    Name     : String;
    Caps     : Array Of LongInt;
    UsesThis : Boolean;
  End;

Var
  AmbigType  : Boolean;
  Scope      : Array Of TScopeEnt;
  NScope     : LongInt;
  ScopeBase  : LongInt;
  Locals     : Array Of TLocalRec;
  NLocals    : LongInt;
  Ctxs       : Array Of TCtxRec;
  NCtxs      : LongInt;
  Lambdas    : Array Of TLambdaRec;
  NLambdas   : LongInt;

  CurClass   : LongInt;
  CurMeth    : LongInt;
  CurStatic  : Boolean;
  CurRet     : LongInt;
  CurCtx     : LongInt;
  CurCU      : LongInt;
  LambdaRets : LongInt;       { type courant de retour des lambdas (inference) }
  ClassQueue : Array Of LongInt;   { classes sources a analyser }
  NQueue     : LongInt;
  SrcDirs    : String;

{ ----- portees ---------------------------------------------------------- }

Procedure PushScope(Kind : Byte; Const Name : String; Ref : LongInt);
Begin
  If NScope >= Length(Scope) Then SetLength(Scope, NScope * 2 + 128);
  Scope[NScope].Kind := Kind;
  Scope[NScope].Name := Name;
  Scope[NScope].Ref := Ref;
  Inc(NScope);
End;

Function NewCtx(Kind : Byte; Parent : LongInt) : LongInt;
Begin
  If NCtxs >= Length(Ctxs) Then SetLength(Ctxs, NCtxs * 2 + 64);
  Ctxs[NCtxs].Kind := Kind;
  Ctxs[NCtxs].Parent := Parent;
  SetLength(Ctxs[NCtxs].Caps, 0);
  SetLength(Ctxs[NCtxs].NewSites, 0);
  Ctxs[NCtxs].UsesThis := False;
  Ctxs[NCtxs].Cls := -1;
  Ctxs[NCtxs].Node := 0;
  NewCtx := NCtxs;
  Inc(NCtxs);
End;

Function NewLocal(Const Name : String; Typ, Flags, Decl : LongInt) : LongInt;
Begin
  If NLocals >= Length(Locals) Then SetLength(Locals, NLocals * 2 + 256);
  Locals[NLocals].Name := Name;
  Locals[NLocals].Typ := Typ;
  Locals[NLocals].Flags := Flags;
  Locals[NLocals].Ctx := CurCtx;
  Locals[NLocals].Decl := Decl;
  Locals[NLocals].Slot := -1;
  Locals[NLocals].SlotOwner := -1;
  Locals[NLocals].CK := 0;
  Locals[NLocals].Assigns := 0;
  Locals[NLocals].HasInit := False;
  Locals[NLocals].Line := 0;
  SetLength(Locals[NLocals].Rethrow, 0);
  If Decl > 0 Then Locals[NLocals].Line := Nodes[Decl].Line;
  NewLocal := NLocals;
  Inc(NLocals);
End;

{ ----- recherche de classes --------------------------------------------- }

Function PkgPath(Const Pkg : String) : String;
Begin
  If Pkg = '' Then PkgPath := '' Else PkgPath := ReplaceAll(Pkg, '.', '/') + '/';
End;

{ Nom qualifie "a.b.C.D" -> classe, en essayant les decoupages paquetage / classes imbriquees }
Function LookupClassQualified(Const Dotted : String) : LongInt;
Var Segs : Array[0..31] Of String; N, K, J, I : LongInt; S, Nm : String; R : LongInt;
Begin
  LookupClassQualified := -1;
  N := 0;
  S := '';
  For I := 1 To Length(Dotted) Do Begin
    If Dotted[I] = '.' Then Begin
      If N < 31 Then Begin Segs[N] := S; Inc(N); End;
      S := '';
    End
    Else S := S + Dotted[I];
  End;
  Segs[N] := S; Inc(N);
  For K := N Downto 1 Do Begin
    Nm := '';
    For J := 0 To K - 1 Do Begin
      If J > 0 Then Nm := Nm + '/';
      Nm := Nm + Segs[J];
    End;
    For J := K To N - 1 Do Nm := Nm + '$' + Segs[J];
    R := LookupClass(Nm);
    If R >= 0 Then Begin LookupClassQualified := R; Exit; End;
  End;
End;

Function FindMemberClass(K : LongInt; Const Name : String) : LongInt;
Var I, R, S : LongInt;
Begin
  FindMemberClass := -1;
  EnsureHeader(K);
  For I := 0 To Length(Classes[K].Nested) - 1 Do
    If Classes[Classes[K].Nested[I]].Simple = Name Then Begin
      FindMemberClass := Classes[K].Nested[I]; Exit;
    End;
  { classes imbriquees de la bibliotheque non encore chargees }
  If Not Classes[K].IsSrc Then Begin
    R := LookupClass(Classes[K].Name + '$' + Name);
    If R >= 0 Then Begin
      EnsureHeader(R);
      FindMemberClass := R; Exit;
    End;
  End;
  S := SuperClsOf(K);
  If S >= 0 Then Begin
    R := FindMemberClass(S, Name);
    If R >= 0 Then Begin FindMemberClass := R; Exit; End;
  End;
  For I := 0 To Length(Classes[K].Ifaces) - 1 Do Begin
    R := FindMemberClass(ClsOf(Classes[K].Ifaces[I]), Name);
    If R >= 0 Then Begin FindMemberClass := R; Exit; End;
  End;
End;

Procedure LoadSourceFile(Const Fn : String); Forward;

{ Cherche une classe d'apres un nom simple, en dehors des portees locales }
Function LookupTypeInCU(Const Name : String) : LongInt;
Var Imp, R, K, Found1 : LongInt; S, Last : String; Dir : String; Pk : String;
Begin
  LookupTypeInCU := -1;
  If CurCU < 0 Then Exit;
  { imports de type simple }
  Imp := CUs[CurCU].Imports;
  While Imp <> 0 Do Begin
    If (Nodes[Imp].Aux = 0) And ((Nodes[Imp].Mods And ACC_STATIC) = 0) Then Begin
      S := Nodes[Imp].S;
      K := LastPos('.', S);
      Last := Copy(S, K + 1, Length(S));
      If Last = Name Then Begin
        R := LookupClassQualified(S);
        If R >= 0 Then Begin LookupTypeInCU := R; Exit; End;
      End;
    End;
    Imp := Nodes[Imp].Next;
  End;
  { meme paquetage (classes sources ou bibliotheque) }
  R := LookupClass(PkgPath(CUs[CurCU].Pkg) + Name);
  If R >= 0 Then Begin LookupTypeInCU := R; Exit; End;
  { imports a la demande (une ambiguite est signalee) }
  Imp := CUs[CurCU].Imports;
  Found1 := -1;
  While Imp <> 0 Do Begin
    If (Nodes[Imp].Aux = 1) And ((Nodes[Imp].Mods And ACC_STATIC) = 0) Then Begin
      R := LookupClass(PkgPath(Nodes[Imp].S) + Name);
      If R < 0 Then Begin
        K := LookupClassQualified(Nodes[Imp].S);
        If K >= 0 Then R := FindMemberClass(K, Name);
      End;
      If R >= 0 Then Begin
        If (Found1 >= 0) And (Found1 <> R) Then AmbigType := True;
        If Found1 < 0 Then Found1 := R;
      End;
    End
    Else If (Nodes[Imp].Aux = 1) Then Begin
      K := LookupClassQualified(Nodes[Imp].S);
      If K >= 0 Then Begin
        R := FindMemberClass(K, Name);
        If R >= 0 Then Begin LookupTypeInCU := R; Exit; End;
      End;
    End;
    Imp := Nodes[Imp].Next;
  End;
  If Found1 >= 0 Then Begin LookupTypeInCU := Found1; Exit; End;
  R := LookupClass('java/lang/' + Name);
  If R >= 0 Then Begin LookupTypeInCU := R; Exit; End;
  { fichier source voisin }
  Dir := '';
  S := CUs[CurCU].FileName;
  K := LastPos('/', S);
  If K = 0 Then K := LastPos('\', S);
  If K > 0 Then Dir := Copy(S, 1, K);
  Pk := Dir + Name + '.java';
  If FileExists(Pk) And (MapFind(ClassMap, '@src:' + Pk) < 0) Then Begin
    LoadSourceFile(Pk);
    R := LookupClass(PkgPath(CUs[CurCU].Pkg) + Name);
    If R >= 0 Then LookupTypeInCU := R;
  End;
End;

{ Recherche d'un nom de type simple dans toutes les portees }
Function LookupTypeSimple(Const Name : String) : LongInt;
Var I, K, R, J : LongInt;
Begin
  LookupTypeSimple := -1;
  For I := NScope - 1 Downto ScopeBase Do Begin
    Case Scope[I].Kind Of
      SC_TPARAM : If Scope[I].Name = Name Then Begin LookupTypeSimple := Scope[I].Ref; Exit; End;
      SC_LOCALCLASS : If Scope[I].Name = Name Then Begin
        LookupTypeSimple := ClassT(Scope[I].Ref); Exit;
      End;
      SC_CLASSMARK : Begin
        K := Scope[I].Ref;
        For J := 0 To Length(Classes[K].TPars) - 1 Do
          If TVars[Types[Classes[K].TPars[J]].TV].Name = Name Then Begin
            LookupTypeSimple := Classes[K].TPars[J]; Exit;
          End;
        If (Classes[K].Simple = Name) And (Classes[K].Flags And MOD_ANON = 0) Then Begin
          LookupTypeSimple := ClassT(K); Exit;
        End;
        R := FindMemberClass(K, Name);
        If R >= 0 Then Begin LookupTypeSimple := ClassT(R); Exit; End;
      End;
    End;
  End;
  R := LookupTypeInCU(Name);
  If R >= 0 Then LookupTypeSimple := ClassT(R);
End;

{ Nom de type eventuellement qualifie : retourne le type de la classe (sans arguments) }
Function LookupTypeName(Const Name : String) : LongInt;
Var P1 : LongInt; First, Rest : String; T, K, R : LongInt;
Begin
  P1 := Pos('.', Name);
  If P1 = 0 Then Begin LookupTypeName := LookupTypeSimple(Name); Exit; End;
  First := Copy(Name, 1, P1 - 1);
  Rest := Copy(Name, P1 + 1, Length(Name));
  T := LookupTypeSimple(First);
  If T > 0 Then Begin
    { nom qualifie par une classe : A.B.C }
    While (Rest <> '') And (T > 0) Do Begin
      P1 := Pos('.', Rest);
      If P1 = 0 Then Begin First := Rest; Rest := ''; End
      Else Begin First := Copy(Rest, 1, P1 - 1); Rest := Copy(Rest, P1 + 1, Length(Rest)); End;
      K := ClsOf(T);
      If K < 0 Then Begin T := -1; Break; End;
      R := FindMemberClass(K, First);
      If R < 0 Then T := -1 Else T := ClassT(R);
    End;
    LookupTypeName := T;
    Exit;
  End;
  R := LookupClassQualified(Name);
  If R >= 0 Then LookupTypeName := ClassT(R) Else LookupTypeName := -1;
End;

{ ----- resolution des noeuds de type ------------------------------------- }

Function PrimByName(Const S : String) : LongInt;
Begin
  If S = 'int' Then PrimByName := TY_INT
  Else If S = 'long' Then PrimByName := TY_LONG
  Else If S = 'boolean' Then PrimByName := TY_BOOLEAN
  Else If S = 'char' Then PrimByName := TY_CHAR
  Else If S = 'byte' Then PrimByName := TY_BYTE
  Else If S = 'short' Then PrimByName := TY_SHORT
  Else If S = 'float' Then PrimByName := TY_FLOAT
  Else If S = 'double' Then PrimByName := TY_DOUBLE
  Else If S = 'void' Then PrimByName := TY_VOID
  Else PrimByName := TY_NONE;
End;

Function ClassAccessible(C : LongInt) : Boolean; Forward;

Function ResolveType(N : LongInt) : LongInt;
Var T, A, I, Cnt : LongInt; Args : Array[0..MAXTARGS - 1] Of LongInt; Nm : String; W : LongInt;
Begin
  ResolveType := TY_NONE;
  If N = 0 Then Exit;
  If (Nodes[N].Kind = N_TYPE) And (Nodes[N].Aux = 2) Then Begin ResolveType := Nodes[N].Typ; Exit; End;
  If Nodes[N].Kind = N_WILD Then Begin
    If (Nodes[N].Aux <> 0) And (Nodes[N].A <> 0) Then ResolveType := ResolveType(Nodes[N].A)
    Else ResolveType := T_OBJECT;
    Exit;
  End;
  If Nodes[N].Aux = 1 Then T := PrimByName(Nodes[N].S)
  Else Begin
    Nm := Nodes[N].S;
    AmbigType := False;
    T := LookupTypeName(Nm);
    If AmbigType Then Err(Nodes[N].Line, 'la reference a ' + Nm + ' est ambigue');
    If T <= 0 Then Begin
      Err(Nodes[N].Line, 'symbole introuvable : classe ' + Nm);
      T := TY_NONE;
    End
    Else If IsClassT(T) And Not ClassAccessible(Types[T].Cls) Then Begin
      Err(Nodes[N].Line, Classes[Types[T].Cls].Simple + ' n''est pas public dans ' + ReplaceAll(Copy(Classes[Types[T].Cls].Name, 1,
          LastPos('/', Classes[Types[T].Cls].Name) - 1), '/', '.') + ' ; inaccessible depuis l''exterieur du paquetage');
      T := TY_NONE;
    End
    Else If IsClassT(T) And (Nodes[N].A <> 0) Then Begin
      Cnt := 0;
      A := Nodes[N].A;
      While A <> 0 Do Begin
        W := ResolveType(A);
        If Cnt < MAXTARGS Then Begin Args[Cnt] := W; Inc(Cnt); End;
        A := Nodes[A].Next;
      End;
      T := ClassTA(Types[T].Cls, Cnt, Args);
    End;
  End;
  For I := 1 To Nodes[N].N Do
    If T <> TY_NONE Then T := ArrayT(T);
  If Nodes[N].Kind = N_TYPE Then Nodes[N].Typ := T;      { memorise pour l'attribut Signature }
  ResolveType := T;
End;

{ ----- entree des classes ------------------------------------------------ }

Function MemberFlags(C : LongInt) : LongInt;
Begin
  MemberFlags := Classes[C].Flags;
End;

Procedure AddQueue(C : LongInt);
Begin
  If NQueue >= Length(ClassQueue) Then SetLength(ClassQueue, NQueue * 2 + 32);
  ClassQueue[NQueue] := C;
  Inc(NQueue);
End;

Function EnterClass(Decl, Outer, CU : LongInt; IsLocal : Boolean; Const Name : String;
                    InStatic : Boolean) : LongInt;
Var
  C, M, Kind, Fl, Lines : LongInt;
  Nm, Simple : String;
Begin
  Kind := Nodes[Decl].Aux;
  Simple := Nodes[Decl].S;
  If Outer < 0 Then Nm := PkgPath(CUs[CU].Pkg) + Simple
  Else If (Nodes[Decl].Mods And MOD_ANON) <> 0 Then Begin
    Inc(Classes[Classes[Outer].TopClass].AnonCount);
    Nm := Classes[Outer].Name + '$' + IStr(Classes[Classes[Outer].TopClass].AnonCount);
    Simple := '';
  End
  Else If IsLocal Then Begin
    Inc(Classes[Classes[Outer].TopClass].LocalCount);
    Nm := Classes[Outer].Name + '$' + IStr(Classes[Classes[Outer].TopClass].LocalCount) + Simple;
  End
  Else Nm := Classes[Outer].Name + '$' + Simple;
  If MapFind(ClassMap, Nm) >= 0 Then Begin
    C := MapFind(ClassMap, Nm);
    If Classes[C].IsSrc Then Begin
      CurFile := CUs[CU].FileName;
      Err(Nodes[Decl].Line, 'classe deja definie : ' + Simple);
    End;
  End;
  C := NewClass(Nm);
  Classes[C].Simple := Simple;
  Classes[C].IsSrc := True;
  Classes[C].Decl := Decl;
  Classes[C].CU := CU;
  Classes[C].Outer := Outer;
  Classes[C].Loaded := 2;
  Nodes[Decl].Sym := C;
  If Outer >= 0 Then Classes[C].TopClass := Classes[Outer].TopClass;
  Fl := Nodes[Decl].Mods And (ACC_PUBLIC Or ACC_PRIVATE Or ACC_PROTECTED Or ACC_STATIC Or
                              ACC_FINAL Or ACC_ABSTRACT Or ACC_STRICT);
  Case Kind Of
    CLS_INTERFACE, CLS_ANNOTATION : Fl := Fl Or ACC_INTERFACE Or ACC_ABSTRACT;
    CLS_ENUM : Fl := Fl Or ACC_ENUM;
    CLS_RECORD : Fl := Fl Or ACC_FINAL;
  End;
  If Kind = CLS_ANNOTATION Then Fl := Fl Or ACC_ANNOTATION;
  If (Kind <> CLS_CLASS) And (Outer >= 0) Then Fl := Fl Or ACC_STATIC;     { imbriquee implicitement statique }
  If (Outer >= 0) And ((Classes[Outer].Flags And ACC_INTERFACE) <> 0) And Not IsLocal Then
    Fl := Fl Or ACC_STATIC Or ACC_PUBLIC;
  Fl := Fl Or (Nodes[Decl].Mods And (MOD_SEALED Or MOD_NONSEALED));
  If (Nodes[Decl].Mods And MOD_ANON) <> 0 Then Fl := Fl Or MOD_ANON Or MOD_LOCAL;
  If IsLocal Then Fl := Fl Or MOD_LOCAL;
  Classes[C].Flags := Fl;
  { instance englobante }
  If Outer >= 0 Then Begin
    If IsLocal Then Classes[C].IsInner := (Not InStatic) And (Kind = CLS_CLASS)
    Else Classes[C].IsInner := ((Fl And ACC_STATIC) = 0) And (Kind = CLS_CLASS);
    Classes[C].InStatic := InStatic;
  End;
  { classes membres }
  M := Nodes[Decl].D;
  While M <> 0 Do Begin
    If Nodes[M].Kind = N_CLASS Then Begin
      Lines := EnterClass(M, C, CU, False, '', False);
      SetLength(Classes[C].Nested, Length(Classes[C].Nested) + 1);
      Classes[C].Nested[Length(Classes[C].Nested) - 1] := Lines;
    End;
    M := Nodes[M].Next;
  End;
  EnterClass := C;
End;

{ Remplit la portee avec la chaine lexicale d'une classe (de la plus externe a elle) }
Procedure PushClassChain(C : LongInt);
Begin
  If Classes[C].Outer >= 0 Then PushClassChain(Classes[C].Outer);
  PushScope(SC_CLASSMARK, '', C);
End;

Type
  TSavedCtx = Record
    Cls, Meth, Ret, Ctx, CUi, NSc, SBase : LongInt;
    Static : Boolean;
  End;

Procedure IsolateEnter(C : LongInt; Var S : TSavedCtx);
Begin
  S.Cls := CurClass; S.Meth := CurMeth; S.Ret := CurRet; S.Ctx := CurCtx; S.CUi := CurCU;
  S.NSc := NScope; S.SBase := ScopeBase; S.Static := CurStatic;
  CurClass := C;
  CurMeth := -1;
  CurStatic := False;
  CurCU := Classes[C].CU;
  If CurCU >= 0 Then CurFile := CUs[CurCU].FileName;
  If Classes[C].Ctx >= 0 Then
    { classe locale : la portee lexicale courante reste visible }
    PushScope(SC_CLASSMARK, '', C)
  Else Begin
    ScopeBase := NScope;
    PushClassChain(C);
  End;
End;

Procedure IsolateLeave(Var S : TSavedCtx);
Begin
  NScope := S.NSc; ScopeBase := S.SBase;
  CurClass := S.Cls; CurMeth := S.Meth; CurRet := S.Ret; CurCtx := S.Ctx; CurCU := S.CUi;
  CurStatic := S.Static;
  If CurCU >= 0 Then CurFile := CUs[CurCU].FileName;
End;

{ ----- en-tete d'une classe source : parametres de type, super-classe, interfaces ----- }

Procedure ResolveTParams(Decl : LongInt; Var Res : Array Of LongInt; Var N : LongInt; Owner : LongInt);
Var P, B : LongInt; Ty : LongInt;
Begin
  { 1) cree les variables ; 2) resout les bornes }
  N := 0;
  P := Decl;
  While P <> 0 Do Begin
    Ty := NewTVar(Nodes[P].S, 0);
    Nodes[P].Sym := Types[Ty].TV;
    Res[N] := Ty;
    Inc(N);
    PushScope(SC_TPARAM, Nodes[P].S, Ty);
    P := Nodes[P].Next;
  End;
  P := Decl;
  While P <> 0 Do Begin
    B := Nodes[P].A;
    If B <> 0 Then TVars[Nodes[P].Sym].Bound := ResolveType(B);
    P := Nodes[P].Next;
  End;
End;

{ Detecte un cycle d'heritage passant par C ; le cycle est coupe pour eviter les boucles infinies }
Function ReachesClass(X, Target, Depth : LongInt) : Boolean;
Var I, Y : LongInt;
Begin
  ReachesClass := False;
  If (X < 0) Or (Depth > 200) Or Not Classes[X].IsSrc Then Exit;
  EnsureHeader(X);
  If IsClassT(Classes[X].Super) Then Begin
    Y := Types[Classes[X].Super].Cls;
    If (Y = Target) Or ReachesClass(Y, Target, Depth + 1) Then Begin ReachesClass := True; Exit; End;
  End;
  For I := 0 To Length(Classes[X].Ifaces) - 1 Do
    If IsClassT(Classes[X].Ifaces[I]) Then Begin
      Y := Types[Classes[X].Ifaces[I]].Cls;
      If (Y = Target) Or ReachesClass(Y, Target, Depth + 1) Then Begin ReachesClass := True; Exit; End;
    End;
End;

Procedure CheckCycle(C : LongInt);
Begin
  If ReachesClass(C, C, 0) Then Begin
    Err(Nodes[Classes[C].Decl].Line, 'heritage cyclique impliquant ' + Classes[C].Simple);
    Classes[C].Super := T_OBJECT;
    SetLength(Classes[C].Ifaces, 0);
  End;
End;

Procedure ResolveSrcHeader(C : LongInt);
Var
  S : TSavedCtx; D, N, I, T, Tp : LongInt; Tps : Array[0..15] Of LongInt; Kind : LongInt;
  Ifs : Array Of LongInt; NI : LongInt;
Begin
  If Classes[C].HdrState <> 0 Then Exit;
  Classes[C].HdrState := 1;
  D := Classes[C].Decl;
  Kind := Nodes[D].Aux;
  IsolateEnter(C, S);
  { variables de type de la classe }
  N := 0;
  If Nodes[D].A <> 0 Then Begin
    { evite de repousser le marqueur : on les lit via TPars }
    ResolveTParams(Nodes[D].A, Tps, N, C);
    SetLength(Classes[C].TPars, N);
    For I := 0 To N - 1 Do Classes[C].TPars[I] := Tps[I];
  End;
  { classe de base }
  If Kind = CLS_INTERFACE Then Classes[C].Super := T_OBJECT
  Else If Kind = CLS_ENUM Then Begin
    Classes[C].Super := ClassT1(C_ENUM, ClassT(C));
  End
  Else If Kind = CLS_RECORD Then Classes[C].Super := ClassT(C_RECORD)
  Else If Nodes[D].B <> 0 Then Begin
    Tp := ResolveType(Nodes[D].B);
    If IsClassT(Tp) Then Begin
      If (Classes[Types[Tp].Cls].Flags And ACC_INTERFACE) <> 0 Then
        Err(Nodes[D].Line, 'une classe ne peut pas heriter d''une interface (utiliser implements)');
      Classes[C].Super := Tp;
    End
    Else Classes[C].Super := T_OBJECT;
  End
  Else Classes[C].Super := T_OBJECT;
  { interfaces }
  NI := 0;
  SetLength(Ifs, 0);
  T := Nodes[D].C;
  While T <> 0 Do Begin
    Tp := ResolveType(T);
    If IsClassT(Tp) Then Begin
      SetLength(Ifs, NI + 1);
      Ifs[NI] := Tp;
      Inc(NI);
    End;
    T := Nodes[T].Next;
  End;
  If Kind = CLS_ANNOTATION Then Begin
    SetLength(Ifs, NI + 1);
    Ifs[NI] := ClassT(GetClass('java/lang/annotation/Annotation'));
  End;
  Classes[C].Ifaces := Ifs;
  IsolateLeave(S);
  Classes[C].HdrState := 2;
  CheckCycle(C);
End;

{ ----- membres d'une classe source ---------------------------------------- }


Function NewParamName(Var Meth : TMethRec; K : LongInt; Const Nm : String) : LongInt;
Begin
  SetLength(Meth.ParNames, K + 1);
  Meth.ParNames[K] := Nm;
  NewParamName := K;
End;

{ Cree le symbole de methode a partir d'un noeud N_METHOD }
Function EnterMethod(C, Decl : LongInt) : LongInt;
Var
  M, P, Np, I, N : LongInt; Fl : LongInt; Tps : Array[0..15] Of LongInt; Base : LongInt; IsCtor : Boolean;
  PT : LongInt;
Begin
  IsCtor := Nodes[Decl].Aux = 1;
  Fl := Nodes[Decl].Mods And (ACC_PUBLIC Or ACC_PRIVATE Or ACC_PROTECTED Or ACC_STATIC Or ACC_FINAL Or
                              ACC_SYNCHRONIZED Or ACC_NATIVE Or ACC_ABSTRACT Or ACC_STRICT Or MOD_DEFAULT);
  If (Classes[C].Flags And ACC_INTERFACE) <> 0 Then Begin
    If (Fl And ACC_PRIVATE) = 0 Then Fl := Fl Or ACC_PUBLIC;
    If (Nodes[Decl].C = 0) And ((Fl And (ACC_STATIC Or MOD_DEFAULT Or ACC_PRIVATE)) = 0) Then Fl := Fl Or ACC_ABSTRACT;
  End;
  M := NewMeth(C, Nodes[Decl].S, Fl);
  Meths[M].Decl := Decl;
  Nodes[Decl].Sym := M;
  Base := NScope;
  N := 0;
  If Nodes[Decl].E <> 0 Then Begin
    ResolveTParams(Nodes[Decl].E, Tps, N, C);
    SetLength(Meths[M].TPar, N);
    For I := 0 To N - 1 Do Meths[M].TPar[I] := Tps[I];
  End;
  If IsCtor Then Meths[M].Ret := TY_VOID
  Else Meths[M].Ret := ResolveType(Nodes[Decl].A);
  Np := 0;
  P := Nodes[Decl].B;
  While P <> 0 Do Begin
    PT := ResolveType(Nodes[P].A);
    SetLength(Meths[M].Par, Np + 1);
    Meths[M].Par[Np] := PT;
    SetLength(Meths[M].ParNames, Np + 1);
    Meths[M].ParNames[Np] := Nodes[P].S;
    If Nodes[P].Aux = 1 Then Meths[M].Varargs := True;
    Inc(Np);
    P := Nodes[P].Next;
  End;
  Meths[M].NPar := Np;
  If Meths[M].Varargs Then Meths[M].Flags := Meths[M].Flags Or ACC_VARARGS;
  { exceptions declarees }
  P := Nodes[Decl].D;
  While P <> 0 Do Begin
    PT := ResolveType(P);
    If IsClassT(PT) Then Begin
      SetLength(Meths[M].Thr, Length(Meths[M].Thr) + 1);
      Meths[M].Thr[Length(Meths[M].Thr) - 1] := Types[PT].Cls;
    End;
    P := Nodes[P].Next;
  End;
  NScope := Base;
  EnterMethod := M;
End;

Function MkBlockNode(Line : LongInt) : LongInt;
Begin
  MkBlockNode := NewNode(N_BLOCK, Line);
End;

Procedure EnterFieldDecl(C, Decl : LongInt);
Var V, T, F, Fl, I : LongInt; Tn : LongInt;
Begin
  Fl := Nodes[Decl].Mods And (ACC_PUBLIC Or ACC_PRIVATE Or ACC_PROTECTED Or ACC_STATIC Or ACC_FINAL Or
                              ACC_VOLATILE Or ACC_TRANSIENT);
  If (Classes[C].Flags And ACC_INTERFACE) <> 0 Then Fl := Fl Or ACC_PUBLIC Or ACC_STATIC Or ACC_FINAL;
  Tn := ResolveType(Nodes[Decl].A);
  V := Nodes[Decl].B;
  While V <> 0 Do Begin
    T := Tn;
    For I := 1 To Nodes[V].N Do If T <> TY_NONE Then T := ArrayT(T);
    F := NewField(C, Nodes[V].S, Fl, T);
    Fields[F].Decl := V;
    Fields[F].ConstInit := Nodes[V].A;
    If (Fl And ACC_FINAL) <> 0 Then Fields[F].ConstState := 0 Else Fields[F].ConstState := 2;
    If Nodes[V].A = 0 Then Fields[F].ConstState := 2;
    Nodes[V].Sym := F;
    V := Nodes[V].Next;
  End;
End;

Function FindMethodDecl(C : LongInt; Const Name : String; Np : LongInt) : LongInt;
Var M : LongInt;
Begin
  FindMethodDecl := -1;
  M := Classes[C].FirstMeth;
  While M >= 0 Do Begin
    If (Meths[M].Name = Name) And (Meths[M].NPar = Np) Then Begin FindMethodDecl := M; Exit; End;
    M := Meths[M].Next;
  End;
End;

Function FindFieldIn(C : LongInt; Const Name : String) : LongInt;
Var F : LongInt;
Begin
  FindFieldIn := -1;
  F := Classes[C].FirstField;
  While F >= 0 Do Begin
    If Fields[F].Name = Name Then Begin FindFieldIn := F; Exit; End;
    F := Fields[F].Next;
  End;
End;

Procedure EnterMembers(C : LongInt);
Var
  S : TSavedCtx; D, M, Mt, I, N, F, Kind, Np, P, Fl, Dflt : LongInt;
  Ne : LongInt; HasCtor : Boolean; Blk : LongInt; Prm : LongInt;
  OwnT : LongInt; Tl : LongInt;
Begin
  If Classes[C].MemState <> 0 Then Exit;
  Classes[C].MemState := 1;
  EnsureHeader(C);
  D := Classes[C].Decl;
  Kind := Nodes[D].Aux;
  OwnT := ClassT(C);
  IsolateEnter(C, S);
  CurClass := C;
  HasCtor := False;
  Ne := 0;
  { composants d'un record : champs prives finals }
  If Kind = CLS_RECORD Then Begin
    P := Nodes[D].E;
    While P <> 0 Do Begin
      F := NewField(C, Nodes[P].S, ACC_PRIVATE Or ACC_FINAL, ResolveType(Nodes[P].A));
      Fields[F].ConstState := 2;
      Fields[F].Decl := P;
      P := Nodes[P].Next;
    End;
  End;
  M := Nodes[D].D;
  While M <> 0 Do Begin
    Case Nodes[M].Kind Of
      N_FIELD : EnterFieldDecl(C, M);
      N_ENUMCONST : Begin
        F := NewField(C, Nodes[M].S, ACC_PUBLIC Or ACC_STATIC Or ACC_FINAL Or ACC_ENUM, OwnT);
        Fields[F].ConstState := 2;
        Fields[F].Decl := M;
        Nodes[M].Sym := F;
        Inc(Ne);
      End;
      N_METHOD : Begin
        If Nodes[M].Aux = 3 Then Begin
          { constructeur compact : copie les parametres du record }
          Nodes[M].Aux := 1;
          Nodes[M].B := 0;
          Tl := 0;
          P := Nodes[D].E;
          While P <> 0 Do Begin
            Prm := NewNode(N_PARAM, Nodes[P].Line);
            Nodes[Prm].S := Nodes[P].S;
            Nodes[Prm].A := Nodes[P].A;
            Nodes[Prm].Aux := Nodes[P].Aux;
            Nodes[Prm].Ann := Nodes[P].Ann;
            AppendNode(Nodes[M].B, Tl, Prm);
            P := Nodes[P].Next;
          End;
          Nodes[M].Mods := Nodes[M].Mods Or MOD_RECORD;   { compact }
        End;
        Mt := EnterMethod(C, M);
        If Nodes[M].Aux = 1 Then HasCtor := True;
        If (Kind = CLS_ENUM) And ((Meths[Mt].Flags And ACC_ABSTRACT) <> 0) Then
          Classes[C].Flags := Classes[C].Flags Or ACC_ABSTRACT;
      End;
    End;
    M := Nodes[M].Next;
  End;
  Classes[C].EnumCount := Ne;
  { membres synthetiques d'un record : accesseurs, toString, equals, hashCode }
  If Kind = CLS_RECORD Then Begin
    P := Nodes[D].E;
    While P <> 0 Do Begin
      F := FindFieldIn(C, Nodes[P].S);
      If (F >= 0) And (FindMethodDecl(C, Nodes[P].S, 0) < 0) Then Begin
        Mt := NewSynMethod(C, Nodes[P].S, ACC_PUBLIC, 4, '()' + TypeDesc(Erasure(Fields[F].Typ)), Fields[F].Typ);
        Meths[Mt].Bridge := F;
      End;
      P := Nodes[P].Next;
    End;
    If FindMethodDecl(C, 'toString', 0) < 0 Then
      NewSynMethod(C, 'toString', ACC_PUBLIC Or ACC_FINAL, 5, '()Ljava/lang/String;', T_STRING);
    If FindMethodDecl(C, 'hashCode', 0) < 0 Then
      NewSynMethod(C, 'hashCode', ACC_PUBLIC Or ACC_FINAL, 7, '()I', TY_INT);
    If FindMethodDecl(C, 'equals', 1) < 0 Then Begin
      Mt := NewSynMethod(C, 'equals', ACC_PUBLIC Or ACC_FINAL, 6, '(Ljava/lang/Object;)Z', TY_BOOLEAN);
      SetLength(Meths[Mt].Par, 1); Meths[Mt].Par[0] := T_OBJECT; Meths[Mt].NPar := 1;
    End;
  End;
  If (Kind = CLS_ENUM) Then Begin
    M := NewSynMethod(C, 'values', ACC_PUBLIC Or ACC_STATIC, 2, '()[L' + Classes[C].Name + ';', ArrayT(OwnT));
    M := NewSynMethod(C, 'valueOf', ACC_PUBLIC Or ACC_STATIC, 3, '(Ljava/lang/String;)L' + Classes[C].Name + ';', OwnT);
    SetLength(Meths[M].Par, 1); Meths[M].Par[0] := T_STRING; Meths[M].NPar := 1;
    SetLength(Meths[M].ParNames, 1); Meths[M].ParNames[0] := 'name';
  End;
  { constructeur par defaut }
  If (Not HasCtor) And ((Classes[C].Flags And (ACC_INTERFACE Or MOD_ANON)) = 0) Then Begin
    M := NewNode(N_METHOD, Nodes[D].Line);
    Nodes[M].S := '<init>';
    Nodes[M].Aux := 1;
    Nodes[M].C := MkBlockNode(Nodes[D].Line);
    Fl := Classes[C].Flags And (ACC_PUBLIC Or ACC_PROTECTED Or ACC_PRIVATE);
    If Kind = CLS_ENUM Then Fl := ACC_PRIVATE;
    If (Classes[C].Flags And MOD_ANON) <> 0 Then Fl := 0;
    Nodes[M].Mods := Fl Or MOD_DEFAULT;      { MOD_DEFAULT : synthetique }
    { constructeur canonique d'un record }
    If Kind = CLS_RECORD Then Begin
      P := Nodes[D].E;
      Blk := 0;
      While P <> 0 Do Begin
        Prm := NewNode(N_PARAM, Nodes[P].Line);
        Nodes[Prm].S := Nodes[P].S;
        Nodes[Prm].A := Nodes[P].A;
        Nodes[Prm].Aux := Nodes[P].Aux;
        Nodes[Prm].Ann := Nodes[P].Ann;
        AppendNode(Nodes[M].B, Blk, Prm);
        P := Nodes[P].Next;
      End;
      Nodes[M].Mods := Nodes[M].Mods Or MOD_RECORD;
    End;
    { ajoute en fin de liste des membres }
    I := Nodes[D].D;
    If I = 0 Then Nodes[D].D := M
    Else Begin
      While Nodes[I].Next <> 0 Do I := Nodes[I].Next;
      Nodes[I].Next := M;
    End;
    EnterMethod(C, M);
  End;
  IsolateLeave(S);
  Classes[C].MemState := 2;
End;

{ ============================================================================
  4. ANALYSE SEMANTIQUE (2/4) : operations sur les types, constantes,
     conversions, recherche de membres
  ============================================================================ }

{ ----- substitution et parametrisation ---------------------------------- }

Function SubstType(T : LongInt; Const Fr, Tt : Array Of LongInt; N : LongInt) : LongInt;
Var I, J : LongInt; Args : Array[0..MAXTARGS - 1] Of LongInt; Ch : Boolean; R : LongInt;
Begin
  SubstType := T;
  If (T < TY_FIRSTDYN) Or (N = 0) Then Exit;
  Case Types[T].Kind Of
    TYK_TVAR : Begin
      For I := 0 To N - 1 Do
        If Fr[I] = T Then Begin SubstType := Tt[I]; Exit; End;
    End;
    TYK_ARRAY : Begin
      R := SubstType(Types[T].Elem, Fr, Tt, N);
      If R <> Types[T].Elem Then SubstType := ArrayT(R);
    End;
    TYK_CLASS : Begin
      If Types[T].NArgs = 0 Then Exit;
      Ch := False;
      For J := 0 To Types[T].NArgs - 1 Do Begin
        Args[J] := SubstType(Types[T].Args[J], Fr, Tt, N);
        If Args[J] <> Types[T].Args[J] Then Ch := True;
      End;
      If Ch Then SubstType := ClassTA(Types[T].Cls, Types[T].NArgs, Args);
    End;
  End;
End;

{ Le type contient-il une variable de type ? }
Function HasTVar(T : LongInt) : Boolean;
Var I : LongInt;
Begin
  HasTVar := False;
  If T < TY_FIRSTDYN Then Exit;
  Case Types[T].Kind Of
    TYK_TVAR : HasTVar := True;
    TYK_ARRAY : HasTVar := HasTVar(Types[T].Elem);
    TYK_CLASS : For I := 0 To Types[T].NArgs - 1 Do
      If HasTVar(Types[T].Args[I]) Then Begin HasTVar := True; Exit; End;
  End;
End;

Function ThisTypeOf(C : LongInt) : LongInt;
Var A : Array[0..MAXTARGS - 1] Of LongInt; I, N : LongInt;
Begin
  EnsureHeader(C);
  N := Length(Classes[C].TPars);
  If N = 0 Then Begin ThisTypeOf := ClassT(C); Exit; End;
  If N > MAXTARGS Then N := MAXTARGS;
  For I := 0 To N - 1 Do A[I] := Classes[C].TPars[I];
  ThisTypeOf := ClassTA(C, N, A);
End;

{ Parametrisation de la classe D vue comme super-type de T ; 0 si absent }
Function AsSuper(T : LongInt; D : LongInt) : LongInt;
Var
  C, I, S, R, N : LongInt; Fr, Tt : Array[0..MAXTARGS - 1] Of LongInt;
  Sup : LongInt;
Begin
  AsSuper := 0;
  If T < TY_FIRSTDYN Then Exit;
  Case Types[T].Kind Of
    TYK_TVAR : Begin
      If TVars[Types[T].TV].Bound = 0 Then S := T_OBJECT Else S := TVars[Types[T].TV].Bound;
      AsSuper := AsSuper(S, D); Exit;
    End;
    TYK_ARRAY : Begin
      If (D = C_OBJECT) Or (D = C_CLONEABLE) Or (D = C_SERIAL) Then AsSuper := ClassT(D);
      Exit;
    End;
    TYK_ANY : Begin If D = C_OBJECT Then AsSuper := T_OBJECT; Exit; End;
    TYK_CLASS : ;
  Else
    Exit;
  End;
  C := Types[T].Cls;
  If C = D Then Begin AsSuper := T; Exit; End;
  If Not IsSubClass(C, D) Then Exit;
  EnsureHeader(C);
  N := Length(Classes[C].TPars);
  If N > MAXTARGS Then N := MAXTARGS;
  For I := 0 To N - 1 Do Begin
    Fr[I] := Classes[C].TPars[I];
    If I < Types[T].NArgs Then Tt[I] := Types[T].Args[I]
    Else Begin
      If TVars[Types[Fr[I]].TV].Bound = 0 Then Tt[I] := T_OBJECT
      Else Tt[I] := Erasure(TVars[Types[Fr[I]].TV].Bound);
    End;
  End;
  If Classes[C].Super <> 0 Then Begin
    Sup := SubstType(Classes[C].Super, Fr, Tt, N);
    R := AsSuper(Sup, D);
    If R <> 0 Then Begin AsSuper := R; Exit; End;
  End;
  For I := 0 To Length(Classes[C].Ifaces) - 1 Do Begin
    Sup := SubstType(Classes[C].Ifaces[I], Fr, Tt, N);
    R := AsSuper(Sup, D);
    If R <> 0 Then Begin AsSuper := R; Exit; End;
  End;
End;

{ Type d'un membre declare dans la classe Owner, vu depuis le type Site }
Function MemberType(Site, Owner, T : LongInt) : LongInt;
Var A, C, N, I : LongInt; Fr, Tt : Array[0..MAXTARGS - 1] Of LongInt;
Begin
  MemberType := T;
  If Not HasTVar(T) Then Exit;
  EnsureHeader(Owner);
  N := Length(Classes[Owner].TPars);
  If N = 0 Then Exit;
  If N > MAXTARGS Then N := MAXTARGS;
  A := 0;
  If Site > 0 Then A := AsSuper(Site, Owner);
  For I := 0 To N - 1 Do Begin
    Fr[I] := Classes[Owner].TPars[I];
    If (A <> 0) And (I < Types[A].NArgs) Then Tt[I] := Types[A].Args[I]
    Else If (A <> 0) And (Types[A].NArgs = 0) Then Tt[I] := Erasure(Fr[I])
    Else If A = 0 Then Tt[I] := Fr[I]
    Else Tt[I] := T_OBJECT;
  End;
  C := SubstType(T, Fr, Tt, N);
  MemberType := C;
End;

{ ----- sous-typage et conversions ---------------------------------------- }

Function IsSubtypeRef(A, B : LongInt) : Boolean;
Var Ba : LongInt;
Begin
  IsSubtypeRef := False;
  If A = B Then Begin IsSubtypeRef := True; Exit; End;
  If (A = TY_NONE) Or (B = TY_NONE) Then Begin IsSubtypeRef := True; Exit; End;
  If A = TY_NULL Then Begin IsSubtypeRef := IsRef(B); Exit; End;
  If (A = T_ANY) Or (B = T_ANY) Then Begin IsSubtypeRef := True; Exit; End;
  If Not (IsRef(A) And IsRef(B)) Then Exit;
  If B = T_OBJECT Then Begin IsSubtypeRef := True; Exit; End;
  If IsTVarT(A) Then Begin
    Ba := TVars[Types[A].TV].Bound;
    If Ba = 0 Then Ba := T_OBJECT;
    IsSubtypeRef := IsSubtypeRef(Ba, B);
    Exit;
  End;
  If IsTVarT(B) Then Begin
    { une variable de type n'est super-type que d'elle-meme ; on est tolerant }
    IsSubtypeRef := IsSubtypeRef(A, Erasure(B)) And (HasTVar(A) Or True);
    Exit;
  End;
  If IsArrayT(A) Then Begin
    If IsArrayT(B) Then Begin
      If IsPrim(Types[A].Elem) Or IsPrim(Types[B].Elem) Then IsSubtypeRef := Types[A].Elem = Types[B].Elem
      Else IsSubtypeRef := IsSubtypeRef(Types[A].Elem, Types[B].Elem);
    End
    Else If IsClassT(B) Then
      IsSubtypeRef := (Types[B].Cls = C_OBJECT) Or (Types[B].Cls = C_CLONEABLE) Or (Types[B].Cls = C_SERIAL);
    Exit;
  End;
  If IsClassT(A) And IsClassT(B) Then IsSubtypeRef := IsSubClass(Types[A].Cls, Types[B].Cls)
  Else If IsClassT(A) And IsArrayT(B) Then IsSubtypeRef := False;
End;

Function PrimWidens(A, B : LongInt) : Boolean;
Begin
  PrimWidens := False;
  If A = B Then Begin PrimWidens := True; Exit; End;
  Case A Of
    TY_BYTE : PrimWidens := B In [TY_SHORT, TY_INT, TY_LONG, TY_FLOAT, TY_DOUBLE];
    TY_SHORT : PrimWidens := B In [TY_INT, TY_LONG, TY_FLOAT, TY_DOUBLE];
    TY_CHAR : PrimWidens := B In [TY_INT, TY_LONG, TY_FLOAT, TY_DOUBLE];
    TY_INT : PrimWidens := B In [TY_LONG, TY_FLOAT, TY_DOUBLE];
    TY_LONG : PrimWidens := B In [TY_FLOAT, TY_DOUBLE];
    TY_FLOAT : PrimWidens := B = TY_DOUBLE;
  End;
End;

{ Conversion stricte (sans boxing) : invocation de methode phase 1 }
Function IsStrictConv(From, To_ : LongInt) : Boolean;
Begin
  If (From = TY_NONE) Or (To_ = TY_NONE) Then Begin IsStrictConv := True; Exit; End;
  If IsPrim(From) And IsPrim(To_) Then IsStrictConv := PrimWidens(From, To_)
  Else If IsPrim(From) Or IsPrim(To_) Then IsStrictConv := False
  Else If (From = TY_VOID) Or (To_ = TY_VOID) Then IsStrictConv := False
  Else IsStrictConv := IsSubtypeRef(From, To_);
End;

{ Conversion lache : affectation (boxing / unboxing inclus) }
Function IsLooseConv(From, To_ : LongInt) : Boolean;
Var U : LongInt;
Begin
  IsLooseConv := False;
  If (From = TY_NONE) Or (To_ = TY_NONE) Then Begin IsLooseConv := True; Exit; End;
  If (From = TY_VOID) Or (To_ = TY_VOID) Then Exit;
  If IsStrictConv(From, To_) Then Begin IsLooseConv := True; Exit; End;
  If IsPrim(From) And IsRef(To_) Then Begin
    IsLooseConv := IsSubtypeRef(BoxedType(From), To_);
    Exit;
  End;
  If IsRef(From) And IsPrim(To_) Then Begin
    U := UnboxedType(From);
    If (U = TY_NONE) And IsTVarT(From) Then U := UnboxedType(Erasure(From));
    IsLooseConv := (U <> TY_NONE) And PrimWidens(U, To_);
    Exit;
  End;
End;

Function ConstFits(V : Int64; Target : LongInt) : Boolean;
Begin
  Case Target Of
    TY_BYTE : ConstFits := (V >= -128) And (V <= 127);
    TY_SHORT : ConstFits := (V >= -32768) And (V <= 32767);
    TY_CHAR : ConstFits := (V >= 0) And (V <= 65535);
  Else
    ConstFits := False;
  End;
End;

Function IsFinalClass(C : LongInt) : Boolean;
Begin
  EnsureHeader(C);
  IsFinalClass := (Classes[C].Flags And ACC_FINAL) <> 0;
End;

Function IsCastable(From, To_ : LongInt) : Boolean;
Var U : LongInt;
Begin
  IsCastable := False;
  If (From = TY_NONE) Or (To_ = TY_NONE) Then Begin IsCastable := True; Exit; End;
  If (From = TY_VOID) Or (To_ = TY_VOID) Then Exit;
  If IsPrim(From) And IsPrim(To_) Then Begin
    If (From = TY_BOOLEAN) Or (To_ = TY_BOOLEAN) Then IsCastable := From = To_
    Else IsCastable := True;
    Exit;
  End;
  If IsPrim(From) Then Begin
    IsCastable := IsSubtypeRef(BoxedType(From), To_);
    Exit;
  End;
  If IsPrim(To_) Then Begin
    U := UnboxedType(From);
    If U <> TY_NONE Then IsCastable := PrimWidens(U, To_)
    Else IsCastable := IsSubtypeRef(BoxedType(To_), From);
    Exit;
  End;
  { reference -> reference }
  If (From = TY_NULL) Or (From = T_ANY) Or (To_ = T_ANY) Then Begin IsCastable := True; Exit; End;
  If IsSubtypeRef(From, To_) Or IsSubtypeRef(To_, From) Then Begin IsCastable := True; Exit; End;
  If IsTVarT(From) Or IsTVarT(To_) Then Begin
    IsCastable := IsCastable(Erasure(From), Erasure(To_)) Or True; Exit;
  End;
  If IsArrayT(From) Or IsArrayT(To_) Then Begin
    If IsArrayT(From) And IsArrayT(To_) Then Begin
      If IsPrim(Types[From].Elem) Or IsPrim(Types[To_].Elem) Then IsCastable := Types[From].Elem = Types[To_].Elem
      Else IsCastable := IsCastable(Types[From].Elem, Types[To_].Elem);
    End;
    Exit;
  End;
  If IsClassT(From) And IsClassT(To_) Then Begin
    { une interface est convertible vers toute classe non finale, et inversement }
    If IsInterfaceC(Types[From].Cls) Then IsCastable := Not IsFinalClass(Types[To_].Cls) Or IsSubClass(Types[To_].Cls, Types[From].Cls)
    Else If IsInterfaceC(Types[To_].Cls) Then IsCastable := Not IsFinalClass(Types[From].Cls) Or IsSubClass(Types[From].Cls, Types[To_].Cls)
    Else IsCastable := False;
  End;
End;

{ Type "le plus petit commun super-type" (approximation) }
Function LubType(A, B : LongInt) : LongInt;
Var C : LongInt;
Begin
  If A = B Then Begin LubType := A; Exit; End;
  If A = TY_NULL Then Begin LubType := B; Exit; End;
  If B = TY_NULL Then Begin LubType := A; Exit; End;
  If (A = TY_NONE) Or (B = TY_NONE) Then Begin LubType := TY_NONE; Exit; End;
  If IsSubtypeRef(A, B) Then Begin LubType := B; Exit; End;
  If IsSubtypeRef(B, A) Then Begin LubType := A; Exit; End;
  If IsClassT(A) And IsClassT(B) Then Begin
    C := Types[A].Cls;
    While C >= 0 Do Begin
      If IsSubClass(Types[B].Cls, C) And (C <> C_OBJECT) Then Begin LubType := AsSuper(A, C); Exit; End;
      C := SuperClsOf(C);
    End;
    { une interface commune ? }
    C := Types[A].Cls;
    EnsureHeader(C);
    LubType := T_OBJECT;
    Exit;
  End;
  LubType := T_OBJECT;
End;

{ ----- constantes --------------------------------------------------------- }

Function Wrap32(V : Int64) : Int64;
Begin
  Wrap32 := LongInt(V And $FFFFFFFF);
End;

Function ToSingle(D : Double) : Double;
Var S : Single;
Begin
  S := D;
  ToSingle := S;
End;

{ Conversion double -> entier avec la semantique Java }
Function D2L(D : Double) : Int64;
Begin
  If D <> D Then D2L := 0
  Else If D >= 9.2233720368547758E18 Then D2L := High(Int64)
  Else If D <= -9.2233720368547758E18 Then D2L := Low(Int64)
  Else D2L := Trunc(D);
End;

Function D2I(D : Double) : Int64;
Begin
  If D <> D Then D2I := 0
  Else If D >= 2147483647.0 Then D2I := 2147483647
  Else If D <= -2147483648.0 Then D2I := -2147483648
  Else D2I := Trunc(D);
End;

{ Convertit une constante (genre K, entier I, reel D) vers le type primitif Target }
Procedure ConstConv(Var K : Byte; Var I : Int64; Var D : Double; Target : LongInt);
Begin
  If (K = CK_NONE) Or (K = CK_STR) Then Exit;
  Case Target Of
    TY_BOOLEAN : K := CK_INT;
    TY_BYTE, TY_SHORT, TY_CHAR, TY_INT : Begin
      If (K = CK_FLOAT) Or (K = CK_DOUBLE) Then I := D2I(D);
      Case Target Of
        TY_BYTE : I := ShortInt(I And $FF);
        TY_SHORT : I := SmallInt(I And $FFFF);
        TY_CHAR : I := I And $FFFF;
        TY_INT : I := Wrap32(I);
      End;
      K := CK_INT;
    End;
    TY_LONG : Begin
      If (K = CK_FLOAT) Or (K = CK_DOUBLE) Then I := D2L(D);
      K := CK_LONG;
    End;
    TY_FLOAT : Begin
      If (K = CK_INT) Or (K = CK_LONG) Then D := I;
      K := CK_FLOAT; D := ToSingle(D);
    End;
    TY_DOUBLE : Begin
      If (K = CK_INT) Or (K = CK_LONG) Then D := I;
      K := CK_DOUBLE;
    End;
  End;
End;

Procedure FoldConstTo(N : LongInt; Target : LongInt);
Var K : Byte; I : Int64; D : Double;
Begin
  K := Nodes[N].CK; I := Nodes[N].CI; D := Nodes[N].CD;
  ConstConv(K, I, D, Target);
  Nodes[N].CK := K; Nodes[N].CI := I; Nodes[N].CD := D;
End;

{ Texte d'une constante entiere/chaine pour la concatenation constante.
  Retourne faux si la valeur n'est pas representable (float/double). }
Function ConstToStr(N : LongInt; Var S : String) : Boolean;
Var T : LongInt;
Begin
  ConstToStr := True;
  T := Nodes[N].Typ;
  Case Nodes[N].CK Of
    CK_STR : S := Nodes[N].CS;
    CK_INT : Begin
      If T = TY_BOOLEAN Then Begin
        If Nodes[N].CI <> 0 Then S := 'true' Else S := 'false';
      End
      Else If T = TY_CHAR Then Begin
        S := '';
        AppendMUtf8(S, Nodes[N].CI);
      End
      Else S := IStr(Nodes[N].CI);
    End;
    CK_LONG : S := IStr(Nodes[N].CI);
  Else
    ConstToStr := False;
  End;
End;

{ ----- noeuds utilitaires ------------------------------------------------- }

{ Remplace le noeud N par un noeud de conversion de type Target dont l'enfant
  est l'ancien contenu de N (l'indice N reste valide pour le parent) }
Procedure WrapConv(N : LongInt; Target : LongInt);
Var C : LongInt;
Begin
  C := NewNode(N_NONE, Nodes[N].Line);
  Nodes[C] := Nodes[N];
  Nodes[C].Next := 0;
  Nodes[N].Kind := N_CONV;
  Nodes[N].A := C;
  Nodes[N].B := 0; Nodes[N].C := 0; Nodes[N].D := 0; Nodes[N].E := 0;
  Nodes[N].Typ := Target;
  Nodes[N].Aux := 0;
  Nodes[N].Mods := 0;
  Nodes[N].Sym := 0;
  Nodes[N].S := '';
  Nodes[N].N := 0;
  Nodes[N].CK := CK_NONE;
  Nodes[N].CS := '';
  { constante : repli immediat }
  If IsPrim(Target) And (Nodes[C].CK <> CK_NONE) And (Nodes[C].CK <> CK_STR) And IsPrim(Nodes[C].Typ) Then Begin
    Nodes[N].CK := Nodes[C].CK; Nodes[N].CI := Nodes[C].CI; Nodes[N].CD := Nodes[C].CD;
    FoldConstTo(N, Target);
  End;
End;

Function MkThisNode(C, Line : LongInt) : LongInt;
Var N : LongInt;
Begin
  N := NewNode(N_THIS, Line);
  Nodes[N].Typ := ThisTypeOf(C);
  Nodes[N].Sym := C;
  MkThisNode := N;
End;

Function MkOuterThis(C, Line : LongInt) : LongInt;
Var N : LongInt;
Begin
  N := NewNode(N_OUTERTHIS, Line);
  Nodes[N].Typ := ThisTypeOf(C);
  Nodes[N].Sym := C;
  MkOuterThis := N;
End;

{ ----- recherche de champs et de methodes -------------------------------- }

Function FieldInHierarchy(C : LongInt; Const Name : String; Var Owner : LongInt) : LongInt;
Var F, I, S : LongInt;
Begin
  FieldInHierarchy := -1;
  If C < 0 Then Exit;
  EnsureMembers(C);
  F := FindFieldIn(C, Name);
  If F >= 0 Then Begin Owner := C; FieldInHierarchy := F; Exit; End;
  For I := 0 To Length(Classes[C].Ifaces) - 1 Do Begin
    F := FieldInHierarchy(ClsOf(Classes[C].Ifaces[I]), Name, Owner);
    If F >= 0 Then Begin FieldInHierarchy := F; Exit; End;
  End;
  S := SuperClsOf(C);
  If S >= 0 Then FieldInHierarchy := FieldInHierarchy(S, Name, Owner);
End;

Const
  MAXCAND = 400;

Var
  CandM    : Array[0..MAXCAND - 1] Of LongInt;
  CandSite : Array[0..MAXCAND - 1] Of LongInt;
  NCand    : LongInt;
  VisitedC : Array[0..255] Of LongInt;
  NVisited : LongInt;

Function ParamDescOf(M : LongInt) : String;
Var S : String; I : LongInt;
Begin
  S := '';
  For I := 0 To Meths[M].NPar - 1 Do S := S + TypeDesc(Erasure(Meths[M].Par[I]));
  ParamDescOf := S;
End;

Function SameErasedParams(A, B : LongInt) : Boolean;
Var I : LongInt;
Begin
  SameErasedParams := False;
  If Meths[A].NPar <> Meths[B].NPar Then Exit;
  For I := 0 To Meths[A].NPar - 1 Do
    If Erasure(Meths[A].Par[I]) <> Erasure(Meths[B].Par[I]) Then Exit;
  SameErasedParams := True;
End;

Procedure VisitMethods(C : LongInt; Const Name : String; Site : LongInt; Ctor : Boolean);
Var M, I, K, S : LongInt; Dup : Boolean;
Begin
  If C < 0 Then Exit;
  For I := 0 To NVisited - 1 Do If VisitedC[I] = C Then Exit;
  If NVisited < 256 Then Begin VisitedC[NVisited] := C; Inc(NVisited); End;
  EnsureMembers(C);
  M := Classes[C].FirstMeth;
  While M >= 0 Do Begin
    If Meths[M].Name = Name Then Begin
      Dup := False;
      For K := 0 To NCand - 1 Do
        If SameErasedParams(CandM[K], M) And ((Meths[CandM[K]].Flags And ACC_STATIC) = (Meths[M].Flags And ACC_STATIC)) Then Begin
          Dup := True; Break;
        End;
      If (Not Dup) And (NCand < MAXCAND) Then Begin
        CandM[NCand] := M;
        If Site > 0 Then CandSite[NCand] := AsSuper(Site, C) Else CandSite[NCand] := 0;
        Inc(NCand);
      End;
    End;
    M := Meths[M].Next;
  End;
  If Ctor Then Exit;
  S := SuperClsOf(C);
  If S >= 0 Then VisitMethods(S, Name, Site, Ctor);
  For I := 0 To Length(Classes[C].Ifaces) - 1 Do
    VisitMethods(ClsOf(Classes[C].Ifaces[I]), Name, Site, Ctor);
  { une interface herite aussi des methodes d'Object }
  If (Classes[C].Flags And ACC_INTERFACE) <> 0 Then VisitMethods(C_OBJECT, Name, Site, Ctor);
End;

Procedure CollectMethods(SiteT : LongInt; Const Name : String; Ctor : Boolean);
Var C : LongInt;
Begin
  NCand := 0;
  NVisited := 0;
  If IsArrayT(SiteT) Then C := C_OBJECT
  Else If IsTVarT(SiteT) Then Begin
    If TVars[Types[SiteT].TV].Bound = 0 Then C := C_OBJECT
    Else C := ClsOf(Erasure(SiteT));
  End
  Else C := ClsOf(SiteT);
  If C < 0 Then C := C_OBJECT;
  VisitMethods(C, Name, SiteT, Ctor);
  { variable de type a bornes multiples non geree ; Object en dernier recours }
  If IsTVarT(SiteT) And (NCand = 0) Then VisitMethods(C_OBJECT, Name, SiteT, Ctor);
End;

{ Accessibilite (simplifiee) : prive -> meme classe de tete ; sinon accessible }
{ Paquetage (avec '/' final) de la classe courante }
Function CurPackage : String;
Var K : LongInt;
Begin
  If CurClass >= 0 Then Begin
    K := LastPos('/', Classes[CurClass].Name);
    CurPackage := Copy(Classes[CurClass].Name, 1, K);
  End
  Else If CurCU >= 0 Then CurPackage := PkgPath(CUs[CurCU].Pkg)
  Else CurPackage := '';
End;

Function ClassPackage(C : LongInt) : String;
Var K : LongInt;
Begin
  K := LastPos('/', Classes[C].Name);
  ClassPackage := Copy(Classes[C].Name, 1, K);
End;

{ Une classe englobante de la classe courante est-elle sous-classe de Owner ? }
Function EnclosingIsSubclassOf(Owner : LongInt) : Boolean;
Var K : LongInt;
Begin
  EnclosingIsSubclassOf := False;
  K := CurClass;
  While K >= 0 Do Begin
    If IsSubClass(K, Owner) Then Begin EnclosingIsSubclassOf := True; Exit; End;
    K := Classes[K].Outer;
  End;
End;

{ Acces a un membre de drapeaux Flags declare dans la classe Owner (JLS 6.6) }
Function IsAccessible(Flags, Owner : LongInt) : Boolean;
Begin
  IsAccessible := True;
  If CurClass < 0 Then Exit;
  If (Flags And ACC_PUBLIC) <> 0 Then Exit;
  If (Flags And ACC_PRIVATE) <> 0 Then Begin
    IsAccessible := Classes[Owner].TopClass = Classes[CurClass].TopClass;
    Exit;
  End;
  { membres d'interface : publics }
  If (Classes[Owner].Flags And ACC_INTERFACE) <> 0 Then Exit;
  If ClassPackage(Owner) = CurPackage Then Exit;
  If (Flags And ACC_PROTECTED) <> 0 Then IsAccessible := EnclosingIsSubclassOf(Owner)
  Else IsAccessible := False;
End;

{ Une classe (non locale) est-elle accessible depuis la classe courante ? }
Function ClassAccessible(C : LongInt) : Boolean;
Var Fl : LongInt;
Begin
  ClassAccessible := True;
  If (CurClass < 0) And (CurCU < 0) Then Exit;
  EnsureHeader(C);
  Fl := Classes[C].Flags;
  If (Fl And MOD_LOCAL) <> 0 Then Exit;
  If Classes[C].Outer >= 0 Then Begin
    If CurClass < 0 Then Begin
      ClassAccessible := (Fl And (ACC_PUBLIC Or ACC_PROTECTED)) <> 0;
      Exit;
    End;
    ClassAccessible := IsAccessible(Fl, Classes[C].Outer) And ClassAccessible(Classes[C].Outer);
  End
  Else ClassAccessible := ((Fl And ACC_PUBLIC) <> 0) Or (ClassPackage(C) = CurPackage);
End;

{ ----- methode fonctionnelle (SAM) d'une interface ------------------------ }

Var
  SamM    : LongInt;
  SamSite : LongInt;

Procedure CollectAbstract(C : LongInt; Site : LongInt; Var Cnt : LongInt);
Var M, I, K : LongInt; Dup : Boolean; Nm : String;
Begin
  EnsureMembers(C);
  M := Classes[C].FirstMeth;
  While M >= 0 Do Begin
    If ((Meths[M].Flags And ACC_ABSTRACT) <> 0) And ((Meths[M].Flags And ACC_STATIC) = 0) Then Begin
      Nm := Meths[M].Name;
      { methodes publiques d'Object redeclarees : ne comptent pas }
      If ((Nm = 'equals') And (Meths[M].NPar = 1)) Or ((Nm = 'hashCode') And (Meths[M].NPar = 0)) Or
         ((Nm = 'toString') And (Meths[M].NPar = 0)) Then
      Else Begin
        Dup := False;
        If Cnt > 0 Then
          If (Meths[SamM].Name = Nm) And (Meths[SamM].NPar = Meths[M].NPar) Then Dup := True;
        If Not Dup Then Begin
          If Cnt = 0 Then Begin SamM := M; SamSite := AsSuper(Site, C); End;
          Inc(Cnt);
        End;
      End;
    End;
    M := Meths[M].Next;
  End;
  For I := 0 To Length(Classes[C].Ifaces) - 1 Do
    CollectAbstract(ClsOf(Classes[C].Ifaces[I]), Site, Cnt);
  K := 0;
End;

{ Retourne la methode abstraite unique de l'interface T, ou -1 }
Function FindSAM(T : LongInt) : LongInt;
Var C, Cnt : LongInt;
Begin
  FindSAM := -1;
  If Not IsClassT(T) Then Exit;
  C := Types[T].Cls;
  EnsureHeader(C);
  If (Classes[C].Flags And ACC_INTERFACE) = 0 Then Exit;
  Cnt := 0;
  SamM := -1;
  CollectAbstract(C, T, Cnt);
  If Cnt = 1 Then FindSAM := SamM;
End;

{ ============================================================================
  4. ANALYSE SEMANTIQUE (3/4) : conversions, inference de types generiques,
     resolution de la surcharge
  ============================================================================ }

Const
  MAXIV = 12;
  CALL_STATIC  = 1;
  CALL_SUPER   = 2;     { invokespecial }
  CALL_VARARGS = 4;
  CALL_CTOR    = 8;
  CALL_ARRCLONE = 16;
  CALL_IFACEOBJ = 32;   { methode d'Object appelee sur une interface }

  CV_ASSIGN = 0;
  CV_ARG    = 1;

Var
  IFr, ITo   : Array[0..MAXIV - 1] Of LongInt;
  NIV        : LongInt;

Function AttribExpr(N, Expected : LongInt) : LongInt; Forward;
Procedure AttribStmt(N : LongInt); Forward;
Function AttribLambda(N, Target : LongInt; Infer : Boolean) : LongInt; Forward;
Function AttribMethodRef(N, Target : LongInt) : LongInt; Forward;
Function EnterLocalClass(Decl : LongInt; AnonSuper : LongInt) : LongInt; Forward;
Procedure AttribClassBody(C : LongInt); Forward;

Function TypeErr(Line : LongInt; From, To_ : LongInt) : Boolean;
Begin
  If IsPrim(From) And IsPrim(To_) And IsNumeric(From) And IsNumeric(To_) Then
    Err(Line, 'types incompatibles : conversion avec perte possible de ' + TypeStr(From) + ' en ' + TypeStr(To_))
  Else
    Err(Line, 'types incompatibles : ' + TypeStr(From) + ' ne peut pas etre converti en ' + TypeStr(To_));
  TypeErr := False;
End;

{ Type "de travail" d'un parametre pendant l'inference : les variables non resolues
  sont remplacees par leur borne }
Function ResolveIVars(T : LongInt) : LongInt;
Var Fr, Tt : Array[0..MAXIV - 1] Of LongInt; I, N : LongInt;
Begin
  N := 0;
  For I := 0 To NIV - 1 Do Begin
    Fr[N] := IFr[I];
    If ITo[I] <> 0 Then Tt[N] := ITo[I]
    Else If TVars[Types[IFr[I]].TV].Bound <> 0 Then Tt[N] := Erasure(IFr[I])
    Else Tt[N] := T_OBJECT;
    Inc(N);
  End;
  ResolveIVars := SubstType(T, Fr, Tt, N);
End;

{ Comme ResolveIVars mais les variables non resolues deviennent "inconnu" (T_ANY) :
  utilise pour le type de retour afin de ne pas fausser l'inference des appels imbriques }
Function ResolveIVarsAny(T : LongInt) : LongInt;
Var Fr, Tt : Array[0..MAXIV - 1] Of LongInt; I, N : LongInt;
Begin
  N := 0;
  For I := 0 To NIV - 1 Do Begin
    Fr[N] := IFr[I];
    If ITo[I] <> 0 Then Tt[N] := ITo[I] Else Tt[N] := T_ANY;
    Inc(N);
  End;
  ResolveIVarsAny := SubstType(T, Fr, Tt, N);
End;

{ Substitue seulement les variables deja liees, laisse les autres }
Function SubstBound(T : LongInt) : LongInt;
Var Fr, Tt : Array[0..MAXIV - 1] Of LongInt; I, N : LongInt;
Begin
  N := 0;
  For I := 0 To NIV - 1 Do
    If ITo[I] <> 0 Then Begin Fr[N] := IFr[I]; Tt[N] := ITo[I]; Inc(N); End;
  SubstBound := SubstType(T, Fr, Tt, N);
End;

Function IVIndex(T : LongInt) : LongInt;
Var I : LongInt;
Begin
  IVIndex := -1;
  If Not IsTVarT(T) Then Exit;
  For I := 0 To NIV - 1 Do If IFr[I] = T Then Begin IVIndex := I; Exit; End;
End;

Procedure IVAdd(T : LongInt);
Begin
  If IVIndex(T) >= 0 Then Exit;
  If NIV < MAXIV Then Begin IFr[NIV] := T; ITo[NIV] := 0; Inc(NIV); End;
End;

Function HasIVar(T : LongInt) : Boolean;
Var I : LongInt;
Begin
  HasIVar := False;
  If T < TY_FIRSTDYN Then Exit;
  Case Types[T].Kind Of
    TYK_TVAR : HasIVar := IVIndex(T) >= 0;
    TYK_ARRAY : HasIVar := HasIVar(Types[T].Elem);
    TYK_CLASS : For I := 0 To Types[T].NArgs - 1 Do
      If HasIVar(Types[T].Args[I]) Then Begin HasIVar := True; Exit; End;
  End;
End;

Procedure Unify(P, A : LongInt);
Var I, K, Aa : LongInt;
Begin
  If (A = TY_NONE) Or (A = TY_NULL) Or (A = TY_VOID) Or (P = TY_NONE) Then Exit;
  K := IVIndex(P);
  If K >= 0 Then Begin
    If IsPrim(A) Then A := BoxedType(A);
    If A = T_ANY Then Exit;
    If ITo[K] = 0 Then ITo[K] := A
    Else If ITo[K] <> A Then ITo[K] := LubType(ITo[K], A);
    Exit;
  End;
  If P < TY_FIRSTDYN Then Exit;
  Case Types[P].Kind Of
    TYK_ARRAY : If IsArrayT(A) Then Unify(Types[P].Elem, Types[A].Elem);
    TYK_CLASS : Begin
      If Types[P].NArgs = 0 Then Exit;
      Aa := AsSuper(A, Types[P].Cls);
      If (Aa <> 0) And (Types[Aa].NArgs = Types[P].NArgs) Then
        For I := 0 To Types[P].NArgs - 1 Do Unify(Types[P].Args[I], Types[Aa].Args[I]);
    End;
  End;
End;

{ Inference a partir du type attendu (position de retour) }
Procedure UnifyExpected(Ret, Exp : LongInt);
Var I, K, Aa : LongInt;
Begin
  If (Exp = 0) Or (Exp = TY_NONE) Or (Ret = TY_NONE) Then Exit;
  K := IVIndex(Ret);
  If K >= 0 Then Begin
    If (ITo[K] = 0) And (Not IsTVarT(Exp)) And (Exp <> T_OBJECT) And (Exp <> T_ANY) And (Exp <> TY_VOID) Then
      ITo[K] := BoxedType(Exp);
    Exit;
  End;
  If (Ret < TY_FIRSTDYN) Or (Exp < TY_FIRSTDYN) Then Exit;
  If (Types[Ret].Kind = TYK_CLASS) And (Types[Exp].Kind = TYK_CLASS) And (Types[Exp].NArgs > 0) Then Begin
    Aa := AsSuper(Ret, Types[Exp].Cls);
    If (Aa <> 0) And (Types[Aa].NArgs = Types[Exp].NArgs) Then
      For I := 0 To Types[Exp].NArgs - 1 Do UnifyExpected(Types[Aa].Args[I], Types[Exp].Args[I]);
  End
  Else If (Types[Ret].Kind = TYK_ARRAY) And (Types[Exp].Kind = TYK_ARRAY) Then
    UnifyExpected(Types[Ret].Elem, Types[Exp].Elem);
End;


{ ----- exceptions verifiees (checked) ----------------------------------------- }

Const
  TC_TRY = 1;
  TC_BOUND = 2;

Type
  TThrowCtx = Record
    Kind    : Byte;
    Types   : Array Of LongInt;      { types interceptes (try) ou declares (limite) }
    NTypes  : LongInt;
    Thrown  : Array Of LongInt;      { types verifies lances dans le corps (try) }
    NThrown : LongInt;
    Rec     : Array Of LongInt;      { pour chaque type intercepte : liste lancee (indices dans RecLst) }
    RecLst  : Array Of LongInt;
    RecOwn  : Array Of LongInt;      { index du type intercepte pour chaque entree de RecLst }
    NRec    : LongInt;
  End;

Var
  ThrowCtx  : Array Of TThrowCtx;
  NThrowCtx : LongInt;

Function IsCheckedExc(C : LongInt) : Boolean;
Begin
  IsCheckedExc := IsSubClass(C, ClsOf(T_THROWABLE)) And Not IsSubClass(C, C_RUNTIMEEX) And Not IsSubClass(C, C_ERROR);
End;

Procedure PushThrowCtx(Kind : Byte);
Begin
  If NThrowCtx >= Length(ThrowCtx) Then SetLength(ThrowCtx, NThrowCtx * 2 + 8);
  ThrowCtx[NThrowCtx].Kind := Kind;
  ThrowCtx[NThrowCtx].NTypes := 0;
  ThrowCtx[NThrowCtx].NThrown := 0;
  ThrowCtx[NThrowCtx].NRec := 0;
  Inc(NThrowCtx);
End;

Procedure AddThrowCtxType(I, C : LongInt);
Begin
  If ThrowCtx[I].NTypes >= Length(ThrowCtx[I].Types) Then SetLength(ThrowCtx[I].Types, ThrowCtx[I].NTypes * 2 + 4);
  ThrowCtx[I].Types[ThrowCtx[I].NTypes] := C;
  Inc(ThrowCtx[I].NTypes);
End;

{ Un type verifie C est lance a la ligne Line : doit etre intercepte ou declare }
Procedure NoteThrown(C, Line : LongInt);
Var I, K : LongInt; Done : Boolean;
Begin
  If (C < 0) Or Not IsCheckedExc(C) Then Exit;
  I := NThrowCtx - 1;
  While I >= 0 Do Begin
    If ThrowCtx[I].Kind = TC_TRY Then Begin
      { memorise pour le controle "jamais lance" et la relance precise }
      If ThrowCtx[I].NThrown >= Length(ThrowCtx[I].Thrown) Then SetLength(ThrowCtx[I].Thrown, ThrowCtx[I].NThrown * 2 + 4);
      ThrowCtx[I].Thrown[ThrowCtx[I].NThrown] := C;
      Inc(ThrowCtx[I].NThrown);
      Done := False;
      For K := 0 To ThrowCtx[I].NTypes - 1 Do Begin
        If IsSubClass(C, ThrowCtx[I].Types[K]) Then Begin
          If ThrowCtx[I].NRec >= Length(ThrowCtx[I].RecLst) Then Begin
            SetLength(ThrowCtx[I].RecLst, ThrowCtx[I].NRec * 2 + 4);
            SetLength(ThrowCtx[I].RecOwn, ThrowCtx[I].NRec * 2 + 4);
          End;
          ThrowCtx[I].RecLst[ThrowCtx[I].NRec] := C;
          ThrowCtx[I].RecOwn[ThrowCtx[I].NRec] := K;
          Inc(ThrowCtx[I].NRec);
          Done := True;
          Break;
        End;
      End;
      If Done Then Exit;
    End
    Else Begin
      For K := 0 To ThrowCtx[I].NTypes - 1 Do
        If IsSubClass(C, ThrowCtx[I].Types[K]) Then Exit;
      Err(Line, 'exception non signalee ' + Classes[C].Simple + ' ; elle doit etre interceptee ou declaree (throws)');
      Exit;
    End;
    Dec(I);
  End;
End;

Procedure NoteMethodThrows(M, Line : LongInt);
Var K : LongInt;
Begin
  For K := 0 To Length(Meths[M].Thr) - 1 Do NoteThrown(Meths[M].Thr[K], Line);
End;

{ ----- conversions d'affectation --------------------------------------- }

Procedure Coerce(N, Target : LongInt; Ctx : Byte);
Var T, U, Bx : LongInt;
Begin
  T := Nodes[N].Typ;
  If (Target = TY_NONE) Or (T = TY_NONE) Or (T = Target) Then Exit;
  If T = TY_VOID Then Begin
    Err(Nodes[N].Line, 'types incompatibles : void ne peut pas etre converti en ' + TypeStr(Target));
    Nodes[N].Typ := TY_NONE;
    Exit;
  End;
  If Target = TY_VOID Then Exit;
  If IsPrim(T) And IsPrim(Target) Then Begin
    If PrimWidens(T, Target) Then WrapConv(N, Target)
    Else If (Ctx = CV_ASSIGN) And (Nodes[N].CK = CK_INT) And (T <> TY_BOOLEAN) And
            (Target In [TY_BYTE, TY_SHORT, TY_CHAR]) And ConstFits(Nodes[N].CI, Target) Then
      Nodes[N].Typ := Target
    Else TypeErr(Nodes[N].Line, T, Target);
    Exit;
  End;
  If IsPrim(T) Then Begin
    { boxing }
    U := UnboxedType(Target);
    If (U <> TY_NONE) And (U <> T) Then Begin
      If (Ctx = CV_ASSIGN) And (Nodes[N].CK = CK_INT) And (U In [TY_BYTE, TY_SHORT, TY_CHAR]) And
         ConstFits(Nodes[N].CI, U) Then Begin
        Nodes[N].Typ := U;
        WrapConv(N, Target);
        Exit;
      End;
      TypeErr(Nodes[N].Line, T, Target);
      Exit;
    End;
    Bx := BoxedType(T);
    If IsSubtypeRef(Bx, Target) Then WrapConv(N, Bx)
    Else TypeErr(Nodes[N].Line, T, Target);
    Exit;
  End;
  If IsPrim(Target) Then Begin
    U := UnboxedType(T);
    If (U = TY_NONE) And IsTVarT(T) Then U := UnboxedType(Erasure(T));
    If (U <> TY_NONE) And PrimWidens(U, Target) Then WrapConv(N, Target)
    Else If T = T_ANY Then WrapConv(N, Target)
    Else TypeErr(Nodes[N].Line, T, Target);
    Exit;
  End;
  { reference -> reference }
  If IsSubtypeRef(T, Target) Then Begin
    If (T = T_ANY) And (Target <> T_OBJECT) Then WrapConv(N, Target);
  End
  Else TypeErr(Nodes[N].Line, T, Target);
End;

{ Promotion numerique unaire / binaire : convertit le noeud en type primitif P }
Procedure PromoteTo(N, P : LongInt);
Var T : LongInt;
Begin
  T := Nodes[N].Typ;
  If T = P Then Exit;
  If (T = TY_NONE) Then Exit;
  If IsPrim(T) Then WrapConv(N, P)
  Else WrapConv(N, P);       { unboxing + elargissement }
End;

{ Type primitif d'un operande (apres deballage) ou TY_NONE }
Function NumTypeOf(T : LongInt) : LongInt;
Var U : LongInt;
Begin
  If IsPrim(T) Then Begin NumTypeOf := T; Exit; End;
  U := UnboxedType(T);
  If (U = TY_NONE) And IsTVarT(T) Then U := UnboxedType(Erasure(T));
  NumTypeOf := U;
End;

Function BinaryPromote(A, B : LongInt) : LongInt;
Begin
  If (A = TY_DOUBLE) Or (B = TY_DOUBLE) Then BinaryPromote := TY_DOUBLE
  Else If (A = TY_FLOAT) Or (B = TY_FLOAT) Then BinaryPromote := TY_FLOAT
  Else If (A = TY_LONG) Or (B = TY_LONG) Then BinaryPromote := TY_LONG
  Else BinaryPromote := TY_INT;
End;

{ ----- captures et usages de this ---------------------------------------- }

Function AddCapTo(X, L : LongInt) : Boolean;
Var I, C : LongInt;
Begin
  AddCapTo := False;
  If Ctxs[X].Kind = CTX_CLASS Then Begin
    C := Ctxs[X].Cls;
    For I := 0 To Length(Classes[C].Caps) - 1 Do If Classes[C].Caps[I] = L Then Exit;
    SetLength(Classes[C].Caps, Length(Classes[C].Caps) + 1);
    Classes[C].Caps[Length(Classes[C].Caps) - 1] := L;
  End
  Else Begin
    For I := 0 To Length(Ctxs[X].Caps) - 1 Do If Ctxs[X].Caps[I] = L Then Exit;
    SetLength(Ctxs[X].Caps, Length(Ctxs[X].Caps) + 1);
    Ctxs[X].Caps[Length(Ctxs[X].Caps) - 1] := L;
  End;
  AddCapTo := True;
End;

Var
  CapUses    : Array Of LongInt;      { variables capturees : pour le controle "effectivement final" }
  CapLines   : Array Of LongInt;
  CapFiles   : Array Of String;
  NCapUses   : LongInt;

Procedure NoteLocalUse(L : LongInt; Line : LongInt);
Var X : LongInt; Cap : Boolean;
Begin
  X := CurCtx;
  Cap := False;
  While (X >= 0) And (X <> Locals[L].Ctx) Do Begin
    If Ctxs[X].Kind In [CTX_LAMBDA, CTX_CLASS] Then Begin AddCapTo(X, L); Cap := True; End;
    X := Ctxs[X].Parent;
  End;
  If Cap Then Begin
    If NCapUses >= Length(CapUses) Then Begin
      SetLength(CapUses, NCapUses * 2 + 32);
      SetLength(CapLines, NCapUses * 2 + 32);
      SetLength(CapFiles, NCapUses * 2 + 32);
    End;
    CapUses[NCapUses] := L; CapLines[NCapUses] := Line; CapFiles[NCapUses] := CurFile;
    Inc(NCapUses);
  End;
End;

Procedure NoteThisUse;
Var X : LongInt;
Begin
  X := CurCtx;
  While (X >= 0) And (Ctxs[X].Kind = CTX_LAMBDA) Do Begin
    Ctxs[X].UsesThis := True;
    X := Ctxs[X].Parent;
  End;
End;

{ aretes "classe locale instanciee depuis un contexte" pour la fermeture des captures }
Var
  EdgeCtx : Array Of LongInt;
  EdgeCls : Array Of LongInt;
  NEdges  : LongInt;

Procedure NoteNewLocal(Cls : LongInt);
Var X : LongInt;
Begin
  X := CurCtx;
  While (X >= 0) And (X <> Classes[Cls].Ctx) Do Begin
    If Ctxs[X].Kind In [CTX_LAMBDA, CTX_CLASS] Then Begin
      If NEdges >= Length(EdgeCtx) Then Begin
        SetLength(EdgeCtx, NEdges * 2 + 32);
        SetLength(EdgeCls, NEdges * 2 + 32);
      End;
      EdgeCtx[NEdges] := X; EdgeCls[NEdges] := Cls;
      Inc(NEdges);
    End;
    X := Ctxs[X].Parent;
  End;
  If Not CurStatic Then NoteThisUse;
End;

Function CtxIsInside(X, Anc : LongInt) : Boolean;
Begin
  CtxIsInside := False;
  While X >= 0 Do Begin
    If X = Anc Then Begin CtxIsInside := True; Exit; End;
    X := Ctxs[X].Parent;
  End;
End;

Procedure CloseCaptures;
Var Changed : Boolean; E, I, L, C, D : LongInt;
Begin
  Repeat
    Changed := False;
    For E := 0 To NEdges - 1 Do Begin
      C := EdgeCls[E];
      I := 0;
      While I < Length(Classes[C].Caps) Do Begin
        L := Classes[C].Caps[I];
        D := Locals[L].Ctx;
        If (EdgeCtx[E] <> D) And CtxIsInside(EdgeCtx[E], D) Then
          If AddCapTo(EdgeCtx[E], L) Then Changed := True;
        Inc(I);
      End;
    End;
  Until Not Changed;
End;

{ ============================================================================
  4. ANALYSE SEMANTIQUE (3b/4) : resolution des appels (surcharge, inference)
  ============================================================================ }

Const
  MAXARGS = 24;
  MAXLC   = 90;
  RET_INFER = -2;

Type
  TResolved = Record
    M       : LongInt;
    Site    : LongInt;
    Varargs : Boolean;
    NPar    : LongInt;            { nombre de parametres declares }
    ParT    : Array[0..MAXARGS - 1] Of LongInt;   { type final de chaque argument }
    Ret     : LongInt;
  End;

Var
  CurLambda : LongInt;

Function IsFnNode(N : LongInt) : Boolean;
Begin
  IsFnNode := (Nodes[N].Kind = N_LAMBDA) Or (Nodes[N].Kind = N_METHODREF);
End;

Function SamParamAt(Target, Sam, I : LongInt) : LongInt;
Begin
  SamParamAt := MemberType(Target, Meths[Sam].Owner, Meths[Sam].Par[I]);
End;

Function SamRetOf(Target, Sam : LongInt) : LongInt;
Begin
  SamRetOf := MemberType(Target, Meths[Sam].Owner, Meths[Sam].Ret);
End;

{ Un corps de lambda peut-il etre compatible void (1) / valeur (2) ? }
Function ReturnShape(N : LongInt; Var HasVal, HasVoid : Boolean) : Boolean;
Begin
  ReturnShape := True;
  While N <> 0 Do Begin
    Case Nodes[N].Kind Of
      N_RETURN : If Nodes[N].A <> 0 Then HasVal := True Else HasVoid := True;
      N_BLOCK : ReturnShape := ReturnShape(Nodes[N].A, HasVal, HasVoid);
      N_IF : Begin ReturnShape(Nodes[N].B, HasVal, HasVoid); ReturnShape(Nodes[N].C, HasVal, HasVoid); End;
      N_WHILE, N_LABELED : ReturnShape(Nodes[N].B, HasVal, HasVoid);
      N_DO : ReturnShape(Nodes[N].A, HasVal, HasVoid);
      N_FOR : ReturnShape(Nodes[N].D, HasVal, HasVoid);
      N_FOREACH : ReturnShape(Nodes[N].C, HasVal, HasVoid);
      N_SYNC : ReturnShape(Nodes[N].B, HasVal, HasVoid);
      N_TRY : Begin
        ReturnShape(Nodes[N].B, HasVal, HasVoid);
        ReturnShape(Nodes[Nodes[N].C].B, HasVal, HasVoid);
        ReturnShape(Nodes[N].D, HasVal, HasVoid);
      End;
      N_SWITCH : Begin
        ReturnShape(Nodes[Nodes[N].B].B, HasVal, HasVoid);
      End;
    End;
    N := Nodes[N].Next;
  End;
End;

{ La lambda N peut-elle fournir une methode dont le retour est RetVoid ? }
Function LambdaShapeOk(N : LongInt; RetIsVoid : Boolean) : Boolean;
Var HV, HVd : Boolean; B : LongInt;
Begin
  LambdaShapeOk := True;
  B := Nodes[N].B;
  If Nodes[N].Aux = 1 Then Begin
    { corps-expression : void compatible seulement pour une instruction-expression }
    If RetIsVoid Then
      LambdaShapeOk := Nodes[B].Kind In [N_CALL, N_ASSIGN, N_ASSIGNOP, N_NEW, N_UNARY];
    Exit;
  End;
  HV := False; HVd := False;
  ReturnShape(Nodes[B].A, HV, HVd);
  If RetIsVoid Then LambdaShapeOk := Not HV
  Else Begin
    { valeur attendue : il faut un return valeur, ou un corps qui ne se termine pas }
    LambdaShapeOk := Not HVd;
    If (Not HV) And (Not HVd) Then Begin
      { aucun return : valide seulement si le dernier enonce est un throw }
      LambdaShapeOk := False;
      If Nodes[B].A <> 0 Then Begin
        B := Nodes[B].A;
        While Nodes[B].Next <> 0 Do B := Nodes[B].Next;
        If Nodes[B].Kind = N_THROW Then LambdaShapeOk := True;
        If (Nodes[B].Kind = N_WHILE) And (Nodes[Nodes[B].A].CK = CK_INT) Then LambdaShapeOk := True;
      End;
    End;
  End;
End;

Function FnArgFits(N, P : LongInt) : Boolean;
Var Sam, Np : LongInt;
Begin
  FnArgFits := False;
  If Not IsClassT(P) Then Exit;
  Sam := FindSAM(P);
  If Sam < 0 Then Exit;
  If Nodes[N].Kind = N_LAMBDA Then Begin
    Np := ChainLen(Nodes[N].A);
    If Np <> Meths[Sam].NPar Then Exit;
    FnArgFits := LambdaShapeOk(N, Meths[Sam].Ret = TY_VOID);
  End
  Else FnArgFits := True;
End;

Procedure ArgTypeList(Args : LongInt; Var S : String);
Var A : LongInt;
Begin
  S := '';
  A := Args;
  While A <> 0 Do Begin
    If S <> '' Then S := S + ',';
    If IsFnNode(A) And (Nodes[A].Typ = 0) Then S := S + '<lambda>'
    Else S := S + TypeStr(Nodes[A].Typ);
    A := Nodes[A].Next;
  End;
End;

{ Methode finale de lambda : met a jour les types une fois l'inference terminee }
Procedure FinishLambda(N, FinalTarget : LongInt);
Var I, Sam, R, K : LongInt;
Begin
  If Nodes[N].Kind = N_LET Then Begin
    FinishLambda(Nodes[N].B, FinalTarget);
    Nodes[N].Typ := FinalTarget;
    Exit;
  End;
  If Nodes[N].Kind <> N_LAMBDA Then Begin Nodes[N].Typ := FinalTarget; Exit; End;
  I := Nodes[N].Sym;
  Nodes[N].Typ := FinalTarget;
  If I < 0 Then Exit;
  Lambdas[I].IfaceT := FinalTarget;
  Sam := Lambdas[I].SAM;
  If Sam < 0 Then Exit;
  R := SamRetOf(FinalTarget, Sam);
  If R <> TY_VOID Then Begin
    { remplacement du reste de variables libres par leur borne }
    If HasTVar(R) And (R <> TY_NONE) Then ;
  End;
  Lambdas[I].RetT := R;
  Lambdas[I].SAM := Sam;
  If R <> TY_VOID Then Begin
    If Nodes[N].Aux = 1 Then Coerce(Nodes[N].B, R, CV_ASSIGN)
    Else For K := 0 To Length(Lambdas[I].RetNodes) - 1 Do
      If Nodes[Lambdas[I].RetNodes[K]].A <> 0 Then Coerce(Nodes[Lambdas[I].RetNodes[K]].A, R, CV_ASSIGN);
  End;
End;

{ Resolution d'un appel : constructeur ou methode. Les arguments sont attribues ici. }
Function ResolveCall(Const Name : String; SiteT : LongInt; Ctor : Boolean; ArgHead : LongInt;
                     Expected : LongInt; Line : LongInt; DiamondCls : LongInt;
                     Var R : TResolved) : Boolean;
Var
  LM, LSite : Array[0..MAXLC - 1] Of LongInt;
  NL : LongInt;
  Args, ArgT : Array[0..MAXARGS - 1] Of LongInt;
  IsFn : Array[0..MAXARGS - 1] Of Boolean;
  NA, I, K, Ci, Phase, Chosen, M, Cnt, Best : LongInt;
  A : LongInt;
  SvFr, SvTo : Array[0..MAXIV - 1] Of LongInt;
  SvN : LongInt;
  Ok : Boolean;
  App : Array[0..MAXLC - 1] Of Boolean;
  Found : Boolean;
  ArgsTxt : String;
  OwnerT, Ret, PT, Q, Tgt, Sam, BodyT, RP : LongInt;
  UseVar : Boolean;
  AllExact : Boolean;

  Function ParamAt(C, Idx, Ph : LongInt) : LongInt;
  Var Mm, Np : LongInt;
  Begin
    Mm := LM[C];
    Np := Meths[Mm].NPar;
    If (Ph = 3) And (Idx >= Np - 1) Then
      ParamAt := MemberType(SiteT, Meths[Mm].Owner, ElemOf(Meths[Mm].Par[Np - 1]))
    Else
      ParamAt := MemberType(SiteT, Meths[Mm].Owner, Meths[Mm].Par[Idx]);
  End;

  Function Applicable(C, Ph : LongInt) : Boolean;
  Var Ii, Np, Mm : LongInt; P : LongInt;
  Begin
    Applicable := False;
    Mm := LM[C];
    Np := Meths[Mm].NPar;
    If Ph < 3 Then Begin
      If Np <> NA Then Exit;
    End
    Else Begin
      If Not Meths[Mm].Varargs Then Exit;
      If NA < Np - 1 Then Exit;
    End;
    For Ii := 0 To NA - 1 Do Begin
      P := ParamAt(C, Ii, Ph);
      If IsFn[Ii] Then Begin
        If Not FnArgFits(Args[Ii], Erasure(P)) Then Exit;
        { l'interface fonctionnelle visee doit avoir ses variables libres resolues par l'erasure }
        If IsTVarT(P) Then Exit;
      End
      Else Begin
        P := Erasure(P);
        If Ph = 1 Then Begin
          If Not IsStrictConv(ArgT[Ii], P) Then Exit;
        End
        Else If Not IsLooseConv(ArgT[Ii], P) Then Exit;
      End;
    End;
    Applicable := True;
  End;

  Function MoreSpecific(C1, C2, Ph : LongInt) : Boolean;
  Var Ii, N : LongInt; P1, P2 : LongInt;
  Begin
    MoreSpecific := True;
    N := NA;
    If (Ph = 3) And (Meths[LM[C1]].NPar > N) Then N := Meths[LM[C1]].NPar;
    If (Ph = 3) And (Meths[LM[C2]].NPar > N) Then N := Meths[LM[C2]].NPar;
    For Ii := 0 To N - 1 Do Begin
      If (Ph < 3) And (Ii >= NA) Then Break;
      P1 := Erasure(ParamAt(C1, Ii, Ph));
      P2 := Erasure(ParamAt(C2, Ii, Ph));
      If (Ii < NA) And IsFn[Ii] Then Begin
        { prefere l'interface dont le retour n'est pas void si la lambda produit une valeur }
        Continue;
      End;
      If Not IsStrictConv(P1, P2) Then Begin MoreSpecific := False; Exit; End;
    End;
  End;

Begin
  ResolveCall := False;
  R.M := -1;
  R.Site := SiteT;
  R.Varargs := False;
  { sauvegarde du contexte d'inference de l'appelant }
  SvN := NIV;
  For I := 0 To NIV - 1 Do Begin SvFr[I] := IFr[I]; SvTo[I] := ITo[I]; End;
  NIV := 0;
  { arguments }
  NA := 0;
  A := ArgHead;
  While A <> 0 Do Begin
    If NA >= MAXARGS Then Begin Err(Line, 'trop d''arguments'); A := 0; Break; End;
    Args[NA] := A;
    IsFn[NA] := IsFnNode(A);
    Inc(NA);
    A := Nodes[A].Next;
  End;
  { candidats }
  CollectMethods(SiteT, Name, Ctor);
  NL := 0;
  For I := 0 To NCand - 1 Do
    If (NL < MAXLC) And IsAccessible(Meths[CandM[I]].Flags, Meths[CandM[I]].Owner) Then Begin
      M := CandM[I];
      If (Meths[M].NPar = NA) Or (Meths[M].Varargs And (NA >= Meths[M].NPar - 1)) Then Begin
        LM[NL] := M; LSite[NL] := CandSite[I]; Inc(NL);
      End;
    End;
  Cnt := NCand;
  If NL = 0 Then Begin
    { attribue quand meme les arguments pour signaler leurs erreurs }
    For I := 0 To NA - 1 Do If Not IsFn[I] Then AttribExpr(Args[I], 0);
    ArgTypeList(ArgHead, ArgsTxt);
    If Cnt = 0 Then Begin
      If Ctor Then Err(Line, 'symbole introuvable : constructeur ' + TypeStr(SiteT) + '(' + ArgsTxt + ')')
      Else Err(Line, 'symbole introuvable : methode ' + Name + '(' + ArgsTxt + ')');
    End
    Else Err(Line, 'la methode ' + Name + ' ne peut pas etre appliquee aux arguments (' + ArgsTxt + ')');
    NIV := SvN;
    For I := 0 To NIV - 1 Do Begin IFr[I] := SvFr[I]; ITo[I] := SvTo[I]; End;
    Exit;
  End;
  { attribution des arguments (le type attendu est connu s'il n'y a qu'un candidat) }
  For I := 0 To NA - 1 Do Begin
    If IsFn[I] Then ArgT[I] := TY_NONE
    Else Begin
      PT := 0;
      If (NL = 1) Then Begin
        M := LM[0];
        If Meths[M].NPar > 0 Then Begin
          If I < Meths[M].NPar - 1 Then PT := MemberType(SiteT, Meths[M].Owner, Meths[M].Par[I])
          Else If Meths[M].Varargs Then Begin
            If (NA = Meths[M].NPar) Then PT := 0
            Else PT := MemberType(SiteT, Meths[M].Owner, ElemOf(Meths[M].Par[Meths[M].NPar - 1]));
          End
          Else PT := MemberType(SiteT, Meths[M].Owner, Meths[M].Par[I]);
        End;
        If (PT <> 0) And IsTVarT(PT) Then PT := 0;
      End;
      ArgT[I] := AttribExpr(Args[I], PT);
      If ArgT[I] = TY_VOID Then Begin
        Err(Nodes[Args[I]].Line, '''void'' n''est pas autorise ici');
        ArgT[I] := TY_NONE;
      End;
    End;
  End;
  { choix : trois phases }
  Chosen := -1;
  For Phase := 1 To 3 Do Begin
    Found := False;
    For Ci := 0 To NL - 1 Do Begin
      App[Ci] := Applicable(Ci, Phase);
      If App[Ci] Then Found := True;
    End;
    If Found Then Begin
      { le plus specifique }
      Best := -1;
      For Ci := 0 To NL - 1 Do If App[Ci] Then Begin
        Ok := True;
        For K := 0 To NL - 1 Do
          If App[K] And (K <> Ci) Then
            If Not MoreSpecific(Ci, K, Phase) Then Begin Ok := False; Break; End;
        If Ok Then Begin
          If Best < 0 Then Best := Ci
          Else Begin
            { deux candidats equivalents : prefere le non abstrait / le plus derive }
            If ((Meths[LM[Best]].Flags And ACC_ABSTRACT) <> 0) And ((Meths[LM[Ci]].Flags And ACC_ABSTRACT) = 0) Then Best := Ci;
          End;
        End;
      End;
      If Best < 0 Then Begin
        { ambigu : on prend le premier applicable, en signalant l'erreur si les signatures different }
        For Ci := 0 To NL - 1 Do If App[Ci] Then Begin Best := Ci; Break; End;
        Cnt := 0;
        For Ci := 0 To NL - 1 Do If App[Ci] Then Inc(Cnt);
        If Cnt > 1 Then Begin
          ArgTypeList(ArgHead, ArgsTxt);
          Err(Line, 'reference a ' + Name + ' ambigue (' + ArgsTxt + ')');
        End;
      End;
      Chosen := Best;
      R.Varargs := Phase = 3;
      Break;
    End;
  End;
  If Chosen < 0 Then Begin
    ArgTypeList(ArgHead, ArgsTxt);
    If Ctor Then Err(Line, 'aucun constructeur ' + TypeStr(SiteT) + ' applicable a (' + ArgsTxt + ')')
    Else Err(Line, 'aucune methode ' + Name + ' applicable a (' + ArgsTxt + ')');
    For I := 0 To NA - 1 Do If IsFn[I] Then Begin
      If Nodes[Args[I]].Kind = N_LAMBDA Then Begin
        { evite les erreurs en cascade : attribue avec le type Object ignore }
      End;
    End;
    NIV := SvN;
    For I := 0 To NIV - 1 Do Begin IFr[I] := SvFr[I]; ITo[I] := SvTo[I]; End;
    Exit;
  End;
  M := LM[Chosen];
  R.M := M;
  R.NPar := Meths[M].NPar;
  { inference }
  NIV := 0;
  For I := 0 To Length(Meths[M].TPar) - 1 Do IVAdd(Meths[M].TPar[I]);
  If DiamondCls >= 0 Then
    For I := 0 To Length(Classes[DiamondCls].TPars) - 1 Do IVAdd(Classes[DiamondCls].TPars[I]);
  If Ctor And (DiamondCls >= 0) Then Ret := SiteT
  Else Ret := MemberType(SiteT, Meths[M].Owner, Meths[M].Ret);
  For I := 0 To NA - 1 Do
    If Not IsFn[I] Then Unify(ParamAt(Chosen, I, Ord(R.Varargs) * 3 + Ord(Not R.Varargs)), ArgT[I]);
  If (NIV > 0) And (Expected > 0) Then UnifyExpected(Ret, Expected);
  { lambdas et references de methode }
  For I := 0 To NA - 1 Do
    If IsFn[I] Then Begin
      PT := ParamAt(Chosen, I, Ord(R.Varargs) * 3 + Ord(Not R.Varargs));
      Tgt := SubstBound(PT);
      If Nodes[Args[I]].Kind = N_LAMBDA Then BodyT := AttribLambda(Args[I], Tgt, HasIVar(Tgt))
      Else BodyT := AttribMethodRef(Args[I], Tgt);
      Sam := FindSAM(Tgt);
      If (Sam >= 0) And (BodyT <> TY_NONE) And (BodyT <> TY_VOID) Then Begin
        RP := SamRetOf(Tgt, Sam);
        Unify(RP, BodyT);
      End;
      If (Sam >= 0) And (Nodes[Args[I]].Kind = N_METHODREF) Then Begin
        { liaison du type du premier parametre depuis la reference Type::methode }
      End;
    End;
  { types finaux des parametres }
  Cnt := 0;
  For I := 0 To NA - 1 Do Begin
    PT := ResolveIVars(ParamAt(Chosen, I, Ord(R.Varargs) * 3 + Ord(Not R.Varargs)));
    R.ParT[I] := PT;
    If IsFn[I] Then FinishLambda(Args[I], PT)
    Else Coerce(Args[I], PT, CV_ARG);
  End;
  R.Ret := ResolveIVarsAny(Ret);
  If R.Ret = TY_NONE Then R.Ret := Ret;
  ResolveCall := True;
  NIV := SvN;
  For I := 0 To NIV - 1 Do Begin IFr[I] := SvFr[I]; ITo[I] := SvTo[I]; End;
End;

{ ============================================================================
  4. ANALYSE SEMANTIQUE (4/4) : expressions
  ============================================================================ }

Const
  EK_VALUE = 0;
  EK_TYPE  = 1;
  EK_PKG   = 2;

  LF_PATTERN = $1000000;     { variable liee par instanceof }
  LF_PARAM   = $2000000;     { parametre }
  LF_CATCH   = $4000000;     { parametre d'une clause catch }

Var
  LastEK      : LongInt;
  YieldNodes  : Array Of LongInt;
  NYields     : LongInt;
  LoopDepth   : LongInt;
  SwitchDepth : LongInt;
  LabelNames  : Array Of String;
  LabelLoop   : Array Of Boolean;
  NLabelStk   : LongInt;
  AnonSuperCtor : LongInt;

Function AttribQual(N : LongInt) : LongInt; Forward;
Function AttribCall(N, Expected : LongInt) : LongInt; Forward;
Function AttribNew(N, Expected : LongInt) : LongInt; Forward;
Function AttribSwitchExpr(N, Expected : LongInt) : LongInt; Forward;
Procedure EnsureFieldConst(F : LongInt); Forward;

Procedure ReadConstFromField(N, F : LongInt);
Begin
  EnsureFieldConst(F);
  If Fields[F].CK <> CK_NONE Then Begin
    Nodes[N].CK := Fields[F].CK;
    Nodes[N].CI := Fields[F].CI;
    Nodes[N].CD := Fields[F].CD;
    Nodes[N].CS := Fields[F].CS;
  End;
End;

Procedure EnsureFieldConst(F : LongInt);
Var S : TSavedCtx; T : LongInt; K : Byte; I : Int64; D : Double; Sv : LongInt; C : LongInt;
Begin
  If Fields[F].ConstState <> 0 Then Exit;
  Fields[F].ConstState := 1;
  T := Fields[F].Typ;
  If (Fields[F].ConstInit = 0) Or Not (IsPrim(T) Or (T = T_STRING)) Then Begin
    Fields[F].ConstState := 2; Exit;
  End;
  C := Fields[F].Owner;
  IsolateEnter(C, S);
  CurStatic := (Fields[F].Flags And ACC_STATIC) <> 0;
  Sv := AttribExpr(Fields[F].ConstInit, T);
  IsolateLeave(S);
  If (Nodes[Fields[F].ConstInit].CK <> CK_NONE) And (Sv <> TY_NONE) Then Begin
    K := Nodes[Fields[F].ConstInit].CK;
    I := Nodes[Fields[F].ConstInit].CI;
    D := Nodes[Fields[F].ConstInit].CD;
    If (T = T_STRING) And (K = CK_STR) Then Begin
      Fields[F].CK := CK_STR; Fields[F].CS := Nodes[Fields[F].ConstInit].CS;
    End
    Else If IsPrim(T) And (K <> CK_STR) And IsPrim(Sv) Then Begin
      If PrimWidens(Sv, T) Or ((Sv In [TY_BYTE, TY_SHORT, TY_CHAR, TY_INT]) And (T In [TY_BYTE, TY_SHORT, TY_CHAR]) And ConstFits(I, T)) Then Begin
        ConstConv(K, I, D, T);
        Fields[F].CK := K; Fields[F].CI := I; Fields[F].CD := D;
      End;
    End;
  End;
  Fields[F].ConstState := 2;
End;

{ ----- sites de champs ---------------------------------------------------- }

Function ClassOuterPath(From_, K : LongInt) : Boolean;
Var C : LongInt;
Begin
  { depuis From_ jusqu'a K en suivant les instances englobantes }
  C := From_;
  ClassOuterPath := False;
  While (C >= 0) And (C <> K) Do Begin
    If Not Classes[C].IsInner Then Exit;
    C := Classes[C].Outer;
  End;
  ClassOuterPath := C = K;
End;

{ Noeud donnant l'instance de la classe englobante K (this ou Outer.this) }
Function EnclosingInstance(K, Line : LongInt; Const What : String) : LongInt;
Begin
  EnclosingInstance := 0;
  If K = CurClass Then Begin
    If CurStatic Then Begin
      Err(Line, 'la ' + What + ' non statique ne peut pas etre referencee depuis un contexte statique');
      Exit;
    End;
    NoteThisUse;
    EnclosingInstance := MkThisNode(K, Line);
    Exit;
  End;
  If CurStatic Or Not ClassOuterPath(CurClass, K) Then Begin
    Err(Line, 'la ' + What + ' non statique ne peut pas etre referencee depuis un contexte statique');
    Exit;
  End;
  NoteThisUse;
  EnclosingInstance := MkOuterThis(K, Line);
End;

{ Un champ trouve par son nom simple dans la classe de portee K }
Function FieldRefByName(N, F, Owner, K : LongInt) : LongInt;
Var Recv : LongInt;
Begin
  If Not IsAccessible(Fields[F].Flags, Owner) Then
    Err(Nodes[N].Line, Fields[F].Name + ' n''est pas accessible dans ' + Classes[Owner].Simple);
  Nodes[N].Kind := N_SELECT;
  Nodes[N].Sym := F;
  Nodes[N].S := Fields[F].Name;
  If (Fields[F].Flags And ACC_STATIC) <> 0 Then Begin
    Nodes[N].Aux := 2;
    Nodes[N].A := 0;
    Nodes[N].Typ := Fields[F].Typ;
  End
  Else Begin
    Recv := EnclosingInstance(K, Nodes[N].Line, 'variable ' + Fields[F].Name);
    Nodes[N].Aux := 1;
    Nodes[N].A := Recv;
    If Recv = 0 Then Nodes[N].Typ := TY_NONE
    Else Nodes[N].Typ := MemberType(ThisTypeOf(K), Owner, Fields[F].Typ);
  End;
  If (Fields[F].Flags And ACC_FINAL) <> 0 Then ReadConstFromField(N, F);
  FieldRefByName := Nodes[N].Typ;
End;

Function StaticImportField(Const Name : String; Var Owner : LongInt) : LongInt;
Var Imp, K, F : LongInt; S : String;
Begin
  StaticImportField := -1;
  If CurCU < 0 Then Exit;
  Imp := CUs[CurCU].Imports;
  While Imp <> 0 Do Begin
    If (Nodes[Imp].Mods And ACC_STATIC) <> 0 Then Begin
      If Nodes[Imp].Aux = 1 Then K := LookupClassQualified(Nodes[Imp].S)
      Else Begin
        S := Nodes[Imp].S;
        If Copy(S, LastPos('.', S) + 1, Length(S)) = Name Then K := LookupClassQualified(Copy(S, 1, LastPos('.', S) - 1))
        Else K := -1;
      End;
      If K >= 0 Then Begin
        F := FieldInHierarchy(K, Name, Owner);
        If (F >= 0) And ((Fields[F].Flags And ACC_STATIC) <> 0) Then Begin StaticImportField := F; Exit; End;
      End;
    End;
    Imp := Nodes[Imp].Next;
  End;
End;

Function ResolveSimpleName(N : LongInt) : LongInt;
Var
  I, L, K, F, Owner, T : LongInt; Name : String;
Begin
  Name := Nodes[N].S;
  LastEK := EK_VALUE;
  ResolveSimpleName := TY_NONE;
  For I := NScope - 1 Downto ScopeBase Do Begin
    Case Scope[I].Kind Of
      SC_LOCAL : If Scope[I].Name = Name Then Begin
        L := Scope[I].Ref;
        NoteLocalUse(L, Nodes[N].Line);
        Nodes[N].Aux := 1;
        Nodes[N].Sym := L;
        Nodes[N].Typ := Locals[L].Typ;
        If Locals[L].CK <> CK_NONE Then Begin
          Nodes[N].CK := Locals[L].CK; Nodes[N].CI := Locals[L].CI;
          Nodes[N].CD := Locals[L].CD; Nodes[N].CS := Locals[L].CS;
        End;
        ResolveSimpleName := Locals[L].Typ;
        Exit;
      End;
      SC_CLASSMARK : Begin
        K := Scope[I].Ref;
        F := FieldInHierarchy(K, Name, Owner);
        If F >= 0 Then Begin
          ResolveSimpleName := FieldRefByName(N, F, Owner, K);
          Exit;
        End;
      End;
    End;
  End;
  F := StaticImportField(Name, Owner);
  If F >= 0 Then Begin
    ResolveSimpleName := FieldRefByName(N, F, Owner, Owner);
    Exit;
  End;
  { type ? }
  T := LookupTypeSimple(Name);
  If (T > 0) And IsClassT(T) Then Begin
    Nodes[N].Kind := N_TYPEEXPR;
    Nodes[N].Typ := T;
    Nodes[N].Sym := Types[T].Cls;
    LastEK := EK_TYPE;
    ResolveSimpleName := T;
    Exit;
  End;
  { paquetage }
  Nodes[N].Kind := N_PKGREF;
  LastEK := EK_PKG;
  ResolveSimpleName := TY_NONE;
End;

Function SelectOnType(N, QT : LongInt; Const Name : String) : LongInt;
Var C, F, Owner, R : LongInt;
Begin
  SelectOnType := TY_NONE;
  C := ClsOf(QT);
  If C < 0 Then Begin
    Err(Nodes[N].Line, 'symbole introuvable : ' + Name);
    Exit;
  End;
  F := FieldInHierarchy(C, Name, Owner);
  If F >= 0 Then Begin
    If (Fields[F].Flags And ACC_STATIC) = 0 Then Begin
      Err(Nodes[N].Line, 'la variable non statique ' + Name + ' ne peut pas etre referencee depuis un contexte statique');
      Exit;
    End;
    If Not IsAccessible(Fields[F].Flags, Owner) Then
      Err(Nodes[N].Line, Name + ' a un acces prive dans ' + Classes[Owner].Simple);
    Nodes[N].Aux := 2;
    Nodes[N].A := 0;
    Nodes[N].Sym := F;
    Nodes[N].Typ := Fields[F].Typ;
    If (Fields[F].Flags And ACC_FINAL) <> 0 Then ReadConstFromField(N, F);
    LastEK := EK_VALUE;
    SelectOnType := Nodes[N].Typ;
    Exit;
  End;
  R := FindMemberClass(C, Name);
  If R >= 0 Then Begin
    Nodes[N].Kind := N_TYPEEXPR;
    Nodes[N].Typ := ClassT(R);
    Nodes[N].Sym := R;
    Nodes[N].A := 0;
    LastEK := EK_TYPE;
    SelectOnType := Nodes[N].Typ;
    Exit;
  End;
  Err(Nodes[N].Line, 'symbole introuvable : variable ' + Name + ' dans ' + TypeStr(QT));
End;

Function SelectOnValue(N, VT : LongInt; Const Name : String) : LongInt;
Var C, F, Owner : LongInt; E : LongInt;
Begin
  SelectOnValue := TY_NONE;
  LastEK := EK_VALUE;
  If VT = TY_NONE Then Exit;
  If IsPrim(VT) Or (VT = TY_VOID) Then Begin
    Err(Nodes[N].Line, TypeStr(VT) + ' ne peut pas etre dereference');
    Exit;
  End;
  If IsArrayT(VT) Then Begin
    If Name = 'length' Then Begin
      Nodes[N].Aux := 3;
      Nodes[N].Typ := TY_INT;
      SelectOnValue := TY_INT;
      Exit;
    End;
    Err(Nodes[N].Line, 'symbole introuvable : variable ' + Name);
    Exit;
  End;
  E := Erasure(VT);
  C := ClsOf(E);
  If C < 0 Then C := C_OBJECT;
  F := FieldInHierarchy(C, Name, Owner);
  If F < 0 Then Begin
    Err(Nodes[N].Line, 'symbole introuvable : variable ' + Name + ' dans ' + TypeStr(VT));
    Exit;
  End;
  If Not IsAccessible(Fields[F].Flags, Owner) Then
    Err(Nodes[N].Line, Name + ' a un acces prive dans ' + Classes[Owner].Simple);
  Nodes[N].Sym := F;
  If (Fields[F].Flags And ACC_STATIC) <> 0 Then Begin
    Nodes[N].Aux := 2;
    Nodes[N].A := 0;
    Nodes[N].Typ := Fields[F].Typ;
  End
  Else Begin
    Nodes[N].Aux := 1;
    Nodes[N].Typ := MemberType(VT, Owner, Fields[F].Typ);
  End;
  If (Fields[F].Flags And ACC_FINAL) <> 0 Then ReadConstFromField(N, F);
  SelectOnValue := Nodes[N].Typ;
End;

Function ExprDotted(N : LongInt) : String;
Begin
  ExprDotted := '';
  Case Nodes[N].Kind Of
    N_NAME, N_PKGREF : ExprDotted := Nodes[N].S;
    N_SELECT : ExprDotted := ExprDotted(Nodes[N].A) + '.' + Nodes[N].S;
  End;
End;

Function AttribSelect(N : LongInt) : LongInt;
Var A, QT, R : LongInt; Nm, Full : String; K : LongInt;
Begin
  A := Nodes[N].A;
  Nm := Nodes[N].S;
  QT := AttribQual(A);
  Case LastEK Of
    EK_PKG : Begin
      Full := ExprDotted(A) + '.' + Nm;
      K := LookupClassQualified(Full);
      If (K >= 0) And (Classes[K].Name = ReplaceAll(Full, '.', '/')) Then Begin
        Nodes[N].Kind := N_TYPEEXPR;
        Nodes[N].Typ := ClassT(K);
        Nodes[N].Sym := K;
        LastEK := EK_TYPE;
        AttribSelect := Nodes[N].Typ;
      End
      Else Begin
        Nodes[N].Kind := N_PKGREF;
        Nodes[N].S := Full;
        Nodes[N].A := 0;
        LastEK := EK_PKG;
        AttribSelect := TY_NONE;
      End;
    End;
    EK_TYPE : AttribSelect := SelectOnType(N, QT, Nm);
  Else
    AttribSelect := SelectOnValue(N, QT, Nm);
  End;
End;

{ Attribue un nom ou une selection qui peut designer un type ou un paquetage }
Function AttribQual(N : LongInt) : LongInt;
Var T : LongInt;
Begin
  Case Nodes[N].Kind Of
    N_NAME : Begin
      If Nodes[N].Att = 1 Then Begin
        If Nodes[N].Kind = N_TYPEEXPR Then LastEK := EK_TYPE Else LastEK := EK_VALUE;
        AttribQual := Nodes[N].Typ; Exit;
      End;
      T := ResolveSimpleName(N);
      Nodes[N].Att := 1;
      AttribQual := T;
    End;
    N_SELECT : Begin
      If Nodes[N].Att = 1 Then Begin
        LastEK := EK_VALUE;
        AttribQual := Nodes[N].Typ; Exit;
      End;
      T := AttribSelect(N);
      Nodes[N].Att := 1;
      AttribQual := T;
    End;
    N_TYPEEXPR : Begin LastEK := EK_TYPE; AttribQual := Nodes[N].Typ; End;
    N_PKGREF : Begin LastEK := EK_PKG; AttribQual := TY_NONE; End;
  Else
    T := AttribExpr(N, 0);
    LastEK := EK_VALUE;
    AttribQual := T;
  End;
End;

{ ----- litteraux et operateurs ------------------------------------------- }

Function AttribLit(N : LongInt) : LongInt;
Begin
  If Nodes[N].Mods = 1 Then Err(Nodes[N].Line, 'numero entier trop grand');
  Case Nodes[N].Aux Of
    LIT_INT : Nodes[N].Typ := TY_INT;
    LIT_LONG : Nodes[N].Typ := TY_LONG;
    LIT_FLOAT : Nodes[N].Typ := TY_FLOAT;
    LIT_DOUBLE : Nodes[N].Typ := TY_DOUBLE;
    LIT_CHAR : Nodes[N].Typ := TY_CHAR;
    LIT_STRING : Nodes[N].Typ := T_STRING;
    LIT_BOOL : Nodes[N].Typ := TY_BOOLEAN;
    LIT_NULL : Nodes[N].Typ := TY_NULL;
  End;
  AttribLit := Nodes[N].Typ;
End;

{ Repli de constante d'un operateur binaire ; PT = type de l'operation }
Procedure FoldBinary(N, Op, PT : LongInt);
Var
  A, B : LongInt; X, Y, R : Int64; DX, DY, DR : Double; Cmp, Done : Boolean; Sn : LongInt;
Begin
  A := Nodes[N].A; B := Nodes[N].B;
  If (Nodes[A].CK = CK_NONE) Or (Nodes[B].CK = CK_NONE) Or (Nodes[A].CK = CK_STR) Or (Nodes[B].CK = CK_STR) Then Exit;
  Cmp := Op In [OP_LT, OP_GT, OP_LE, OP_GE, OP_EQ, OP_NE];
  Done := False;
  Case PT Of
    TY_BOOLEAN, TY_INT, TY_LONG : Begin
      X := Nodes[A].CI; Y := Nodes[B].CI;
      If PT = TY_INT Then Begin X := Wrap32(X); Y := Wrap32(Y); End;
      Done := True;
      Case Op Of
        OP_ADD : R := X + Y;
        OP_SUB : R := X - Y;
        OP_MUL : R := X * Y;
        OP_DIV : If Y = 0 Then Done := False
                 Else If Y = -1 Then R := -X
                 Else R := X Div Y;
        OP_REM : If Y = 0 Then Done := False
                 Else If Y = -1 Then R := 0
                 Else R := X Mod Y;
        OP_AND, OP_LAND : R := X And Y;
        OP_OR, OP_LOR : R := X Or Y;
        OP_XOR : R := X Xor Y;
        OP_SHL : If PT = TY_INT Then R := X Shl (Y And 31) Else R := X Shl (Y And 63);
        OP_SHR : If PT = TY_INT Then R := SarLongint(LongInt(X), Y And 31)
                 Else R := SarInt64(X, Y And 63);
        OP_USHR : If PT = TY_INT Then R := LongInt(LongWord(X And $FFFFFFFF) Shr (Y And 31))
                  Else R := Int64(QWord(X) Shr (Y And 63));
        OP_LT : R := Ord(X < Y);
        OP_GT : R := Ord(X > Y);
        OP_LE : R := Ord(X <= Y);
        OP_GE : R := Ord(X >= Y);
        OP_EQ : R := Ord(X = Y);
        OP_NE : R := Ord(X <> Y);
      Else
        Done := False;
      End;
      If Done Then Begin
        If Cmp Then Begin Nodes[N].CK := CK_INT; End
        Else If PT = TY_LONG Then Nodes[N].CK := CK_LONG
        Else Begin Nodes[N].CK := CK_INT; R := Wrap32(R); End;
        Nodes[N].CI := R;
      End;
    End;
    TY_FLOAT, TY_DOUBLE : Begin
      DX := Nodes[A].CD; DY := Nodes[B].CD;
      Done := True;
      Case Op Of
        OP_ADD : DR := DX + DY;
        OP_SUB : DR := DX - DY;
        OP_MUL : DR := DX * DY;
        OP_DIV : If DY = 0 Then Done := False Else DR := DX / DY;
        OP_LT : R := Ord(DX < DY);
        OP_GT : R := Ord(DX > DY);
        OP_LE : R := Ord(DX <= DY);
        OP_GE : R := Ord(DX >= DY);
        OP_EQ : R := Ord(DX = DY);
        OP_NE : R := Ord(DX <> DY);
      Else
        Done := False;
      End;
      If Done Then Begin
        If Cmp Then Begin Nodes[N].CK := CK_INT; Nodes[N].CI := R; End
        Else If PT = TY_FLOAT Then Begin
          Nodes[N].CK := CK_FLOAT; Nodes[N].CD := ToSingle(DR);
        End
        Else Begin Nodes[N].CK := CK_DOUBLE; Nodes[N].CD := DR; End;
      End;
    End;
  End;
  Sn := 0;
End;

Function IsStringT(T : LongInt) : Boolean;
Begin IsStringT := T = T_STRING; End;

Function AttribBinary(N : LongInt) : LongInt;
Var
  Op, A, B, TA, TB, PA, PB, PT, RT : LongInt; S1, S2 : String;
Begin
  Op := Nodes[N].Aux;
  A := Nodes[N].A; B := Nodes[N].B;
  TA := AttribExpr(A, 0);
  TB := AttribExpr(B, 0);
  Nodes[N].Typ := TY_NONE;
  AttribBinary := TY_NONE;
  If (TA = TY_NONE) Or (TB = TY_NONE) Then Exit;
  If (TA = TY_VOID) Or (TB = TY_VOID) Then Begin
    Err(Nodes[N].Line, '''void'' n''est pas autorise ici');
    Exit;
  End;
  { concatenation de chaines }
  If (Op = OP_ADD) And (IsStringT(TA) Or IsStringT(TB)) Then Begin
    RT := T_STRING;
    Nodes[N].Typ := RT;
    If (Nodes[A].CK <> CK_NONE) And (Nodes[B].CK <> CK_NONE) Then
      If ConstToStr(A, S1) And ConstToStr(B, S2) Then Begin
        Nodes[N].CK := CK_STR;
        Nodes[N].CS := S1 + S2;
      End;
    AttribBinary := RT;
    Exit;
  End;
  PA := NumTypeOf(TA);
  PB := NumTypeOf(TB);
  Case Op Of
    OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_REM : Begin
      If (PA = TY_NONE) Or (PB = TY_NONE) Or (PA = TY_BOOLEAN) Or (PB = TY_BOOLEAN) Then Begin
        Err(Nodes[N].Line, 'type d''operande incorrect pour l''operateur : ' + TypeStr(TA) + ', ' + TypeStr(TB));
        Exit;
      End;
      PT := BinaryPromote(PA, PB);
      PromoteTo(A, PT); PromoteTo(B, PT);
      Nodes[N].Typ := PT;
      FoldBinary(N, Op, PT);
      AttribBinary := PT;
    End;
    OP_SHL, OP_SHR, OP_USHR : Begin
      If Not (IsIntegral(PA) And IsIntegral(PB)) Then Begin
        Err(Nodes[N].Line, 'type d''operande incorrect pour un decalage : ' + TypeStr(TA) + ', ' + TypeStr(TB));
        Exit;
      End;
      If PA = TY_LONG Then PT := TY_LONG Else PT := TY_INT;
      PromoteTo(A, PT);
      If PB = TY_LONG Then PromoteTo(B, TY_LONG) Else PromoteTo(B, TY_INT);
      Nodes[N].Typ := PT;
      FoldBinary(N, Op, PT);
      AttribBinary := PT;
    End;
    OP_LT, OP_GT, OP_LE, OP_GE : Begin
      If (PA = TY_NONE) Or (PB = TY_NONE) Or (PA = TY_BOOLEAN) Or (PB = TY_BOOLEAN) Then Begin
        Err(Nodes[N].Line, 'type d''operande incorrect pour l''operateur : ' + TypeStr(TA) + ', ' + TypeStr(TB));
        Exit;
      End;
      PT := BinaryPromote(PA, PB);
      PromoteTo(A, PT); PromoteTo(B, PT);
      Nodes[N].Typ := TY_BOOLEAN;
      Nodes[N].E := PT;
      FoldBinary(N, Op, PT);
      AttribBinary := TY_BOOLEAN;
    End;
    OP_EQ, OP_NE : Begin
      If IsPrim(TA) Or IsPrim(TB) Then Begin
        { comparaison numerique ou booleenne (avec unboxing) }
        If (PA = TY_BOOLEAN) And (PB = TY_BOOLEAN) Then PT := TY_BOOLEAN
        Else If (PA <> TY_NONE) And (PB <> TY_NONE) And (PA <> TY_BOOLEAN) And (PB <> TY_BOOLEAN) Then
          PT := BinaryPromote(PA, PB)
        Else Begin
          Err(Nodes[N].Line, 'types incomparables : ' + TypeStr(TA) + ' et ' + TypeStr(TB));
          Exit;
        End;
        If PT <> TY_BOOLEAN Then Begin PromoteTo(A, PT); PromoteTo(B, PT); End
        Else Begin PromoteTo(A, TY_BOOLEAN); PromoteTo(B, TY_BOOLEAN); End;
        Nodes[N].E := PT;
        FoldBinary(N, Op, PT);
      End
      Else Begin
        { references }
        If Not (IsCastable(TA, TB) Or IsCastable(TB, TA)) Then Begin
          Err(Nodes[N].Line, 'types incomparables : ' + TypeStr(TA) + ' et ' + TypeStr(TB));
          Exit;
        End;
        Nodes[N].E := T_OBJECT;
      End;
      Nodes[N].Typ := TY_BOOLEAN;
      AttribBinary := TY_BOOLEAN;
    End;
    OP_AND, OP_OR, OP_XOR : Begin
      If (PA = TY_BOOLEAN) And (PB = TY_BOOLEAN) Then PT := TY_BOOLEAN
      Else If IsIntegral(PA) And IsIntegral(PB) Then PT := BinaryPromote(PA, PB)
      Else Begin
        Err(Nodes[N].Line, 'type d''operande incorrect pour l''operateur : ' + TypeStr(TA) + ', ' + TypeStr(TB));
        Exit;
      End;
      PromoteTo(A, PT); PromoteTo(B, PT);
      Nodes[N].Typ := PT;
      FoldBinary(N, Op, PT);
      AttribBinary := PT;
    End;
    OP_LAND, OP_LOR : Begin
      If (PA <> TY_BOOLEAN) Or (PB <> TY_BOOLEAN) Then Begin
        Err(Nodes[N].Line, 'type d''operande incorrect pour l''operateur : ' + TypeStr(TA) + ', ' + TypeStr(TB));
        Exit;
      End;
      PromoteTo(A, TY_BOOLEAN); PromoteTo(B, TY_BOOLEAN);
      Nodes[N].Typ := TY_BOOLEAN;
      FoldBinary(N, Op, TY_BOOLEAN);
      AttribBinary := TY_BOOLEAN;
    End;
  End;
End;

{ Un noeud est-il une cible d'affectation valide ? }
Function IsLValue(N : LongInt) : Boolean;
Begin
  Case Nodes[N].Kind Of
    N_NAME : IsLValue := Nodes[N].Aux = 1;
    N_SELECT : IsLValue := Nodes[N].Aux In [1, 2];
    N_INDEX : IsLValue := True;
  Else
    IsLValue := False;
  End;
End;

Procedure NoteAssignTarget(N : LongInt);
Var L, F : LongInt;
Begin
  If Nodes[N].Kind = N_NAME Then Begin
    L := Nodes[N].Sym;
    Inc(Locals[L].Assigns);
    If ((Locals[L].Flags And ACC_FINAL) <> 0) And (Locals[L].HasInit Or ((Locals[L].Flags And LF_PARAM) <> 0)) Then
      Err(Nodes[N].Line, 'impossible d''affecter une valeur a la variable finale ' + Locals[L].Name);
  End
  Else If (Nodes[N].Kind = N_SELECT) Then Begin
    F := Nodes[N].Sym;
    If ((Fields[F].Flags And ACC_FINAL) <> 0) Then Begin
      { permis dans un constructeur / initialiseur de la classe proprietaire }
      If Not ((Fields[F].Owner = CurClass) And ((CurMeth < 0) Or (Meths[CurMeth].Name = '<init>') Or (Meths[CurMeth].Name = '<clinit>'))) Then
        Err(Nodes[N].Line, 'impossible d''affecter une valeur a la variable finale ' + Fields[F].Name);
    End;
  End;
End;

Function AttribAssign(N : LongInt) : LongInt;
Var A, B, TA, TB : LongInt;
Begin
  A := Nodes[N].A; B := Nodes[N].B;
  TA := AttribExpr(A, 0);
  If Not IsLValue(A) Then Begin
    If TA <> TY_NONE Then Err(Nodes[N].Line, 'variable attendue dans la partie gauche de l''affectation');
    AttribExpr(B, 0);
    Nodes[N].Typ := TY_NONE;
    AttribAssign := TY_NONE;
    Exit;
  End;
  NoteAssignTarget(A);
  If Nodes[B].Kind = N_ARRAYINIT Then Nodes[B].Typ := TA;
  TB := AttribExpr(B, TA);
  Coerce(B, TA, CV_ASSIGN);
  Nodes[N].Typ := TA;
  AttribAssign := TA;
End;

Function AttribAssignOp(N : LongInt) : LongInt;
Var A, B, TA, TB, PA, PB, PT, Op : LongInt;
Begin
  A := Nodes[N].A; B := Nodes[N].B; Op := Nodes[N].Aux;
  TA := AttribExpr(A, 0);
  TB := AttribExpr(B, 0);
  Nodes[N].Typ := TY_NONE;
  AttribAssignOp := TY_NONE;
  If (TA = TY_NONE) Or (TB = TY_NONE) Then Exit;
  If Not IsLValue(A) Then Begin
    Err(Nodes[N].Line, 'variable attendue dans la partie gauche de l''affectation');
    Exit;
  End;
  NoteAssignTarget(A);
  If (Op = OP_ADD) And (TA = T_STRING) Then Begin
    If TB = TY_VOID Then Begin Err(Nodes[N].Line, '''void'' n''est pas autorise ici'); Exit; End;
    Nodes[N].E := T_STRING;
    Nodes[N].Typ := T_STRING;
    AttribAssignOp := T_STRING;
    Exit;
  End;
  PA := NumTypeOf(TA);
  PB := NumTypeOf(TB);
  If (PA = TY_NONE) Or (PB = TY_NONE) Then Begin
    Err(Nodes[N].Line, 'type d''operande incorrect pour l''operateur : ' + TypeStr(TA) + ', ' + TypeStr(TB));
    Exit;
  End;
  Case Op Of
    OP_SHL, OP_SHR, OP_USHR : Begin
      If Not (IsIntegral(PA) And IsIntegral(PB)) Then Begin
        Err(Nodes[N].Line, 'type d''operande incorrect pour un decalage'); Exit;
      End;
      If PA = TY_LONG Then PT := TY_LONG Else PT := TY_INT;
      If PB = TY_LONG Then PromoteTo(B, TY_LONG) Else PromoteTo(B, TY_INT);
    End;
    OP_AND, OP_OR, OP_XOR : Begin
      If (PA = TY_BOOLEAN) And (PB = TY_BOOLEAN) Then PT := TY_BOOLEAN
      Else If IsIntegral(PA) And IsIntegral(PB) Then PT := BinaryPromote(PA, PB)
      Else Begin Err(Nodes[N].Line, 'type d''operande incorrect pour l''operateur'); Exit; End;
      PromoteTo(B, PT);
    End;
  Else
    If (PA = TY_BOOLEAN) Or (PB = TY_BOOLEAN) Then Begin
      Err(Nodes[N].Line, 'type d''operande incorrect pour l''operateur'); Exit;
    End;
    PT := BinaryPromote(PA, PB);
    PromoteTo(B, PT);
  End;
  Nodes[N].E := PT;
  Nodes[N].Typ := TA;
  AttribAssignOp := TA;
End;

Function AttribUnary(N : LongInt) : LongInt;
Var Op, A, TA, P, K : LongInt; D : Double; R : Int64;
Begin
  Op := Nodes[N].Aux;
  A := Nodes[N].A;
  TA := AttribExpr(A, 0);
  Nodes[N].Typ := TY_NONE;
  AttribUnary := TY_NONE;
  If TA = TY_NONE Then Exit;
  If TA = TY_VOID Then Begin Err(Nodes[N].Line, '''void'' n''est pas autorise ici'); Exit; End;
  P := NumTypeOf(TA);
  Case Op Of
    OP_PLUS, OP_NEG : Begin
      If (P = TY_NONE) Or (P = TY_BOOLEAN) Then Begin
        Err(Nodes[N].Line, 'type d''operande incorrect pour l''operateur unaire : ' + TypeStr(TA)); Exit;
      End;
      If P In [TY_BYTE, TY_SHORT, TY_CHAR] Then P := TY_INT;
      PromoteTo(A, P);
      Nodes[N].Typ := P;
      If Nodes[A].CK <> CK_NONE Then Begin
        Nodes[N].CK := Nodes[A].CK; Nodes[N].CI := Nodes[A].CI; Nodes[N].CD := Nodes[A].CD;
        If Op = OP_NEG Then Begin
          Case P Of
            TY_INT : Nodes[N].CI := Wrap32(-Nodes[A].CI);
            TY_LONG : Nodes[N].CI := -Nodes[A].CI;
            TY_FLOAT, TY_DOUBLE : Nodes[N].CD := -Nodes[A].CD;
          End;
        End;
      End;
      AttribUnary := P;
    End;
    OP_COMPL : Begin
      If Not IsIntegral(P) Then Begin
        Err(Nodes[N].Line, 'type d''operande incorrect pour l''operateur ~ : ' + TypeStr(TA)); Exit;
      End;
      If P In [TY_BYTE, TY_SHORT, TY_CHAR] Then P := TY_INT;
      PromoteTo(A, P);
      Nodes[N].Typ := P;
      If Nodes[A].CK <> CK_NONE Then Begin
        Nodes[N].CK := Nodes[A].CK;
        If P = TY_INT Then Nodes[N].CI := Wrap32(Not Nodes[A].CI) Else Nodes[N].CI := Not Nodes[A].CI;
      End;
      AttribUnary := P;
    End;
    OP_NOT : Begin
      If P <> TY_BOOLEAN Then Begin
        Err(Nodes[N].Line, 'type d''operande incorrect pour l''operateur ! : ' + TypeStr(TA)); Exit;
      End;
      PromoteTo(A, TY_BOOLEAN);
      Nodes[N].Typ := TY_BOOLEAN;
      If Nodes[A].CK <> CK_NONE Then Begin
        Nodes[N].CK := CK_INT;
        Nodes[N].CI := 1 - Nodes[A].CI;
      End;
      AttribUnary := TY_BOOLEAN;
    End;
    OP_PREINC, OP_PREDEC, OP_POSTINC, OP_POSTDEC : Begin
      If Not IsLValue(A) Then Begin
        Err(Nodes[N].Line, 'variable attendue pour ++ / --'); Exit;
      End;
      If (P = TY_NONE) Or (P = TY_BOOLEAN) Then Begin
        Err(Nodes[N].Line, 'type d''operande incorrect pour ++ / -- : ' + TypeStr(TA)); Exit;
      End;
      NoteAssignTarget(A);
      Nodes[N].Typ := TA;
      Nodes[N].E := P;
      AttribUnary := TA;
    End;
  End;
  K := 0; D := 0; R := 0;
End;

Function AttribCond(N, Expected : LongInt) : LongInt;
Var C, B, E, TB, TE, PB, PE, RT, PT : LongInt;
Begin
  C := Nodes[N].A; B := Nodes[N].B; E := Nodes[N].C;
  AttribExpr(C, 0);
  PromoteTo(C, TY_BOOLEAN);
  If (Nodes[C].Typ <> TY_NONE) And (NumTypeOf(Nodes[C].Typ) <> TY_BOOLEAN) And (Nodes[C].Kind <> N_CONV) Then
    Err(Nodes[N].Line, 'types incompatibles : ' + TypeStr(Nodes[C].Typ) + ' ne peut pas etre converti en boolean');
  If IsFnNode(B) Or IsFnNode(E) Then Begin
    TB := AttribExpr(B, Expected);
    TE := AttribExpr(E, Expected);
  End
  Else Begin
    TB := AttribExpr(B, Expected);
    TE := AttribExpr(E, Expected);
  End;
  Nodes[N].Typ := TY_NONE;
  AttribCond := TY_NONE;
  If (TB = TY_NONE) Or (TE = TY_NONE) Then Exit;
  If (TB = TY_VOID) Or (TE = TY_VOID) Then Begin
    Err(Nodes[N].Line, '''void'' n''est pas autorise ici'); Exit;
  End;
  PB := NumTypeOf(TB);
  PE := NumTypeOf(TE);
  If TB = TE Then RT := TB
  Else If (PB = TY_BOOLEAN) And (PE = TY_BOOLEAN) Then RT := TY_BOOLEAN
  Else If (PB <> TY_NONE) And (PE <> TY_NONE) And (PB <> TY_BOOLEAN) And (PE <> TY_BOOLEAN) And
          (IsPrim(TB) Or IsPrim(TE) Or (TB <> TE)) And Not ((TB = TY_NULL) Or (TE = TY_NULL)) Then Begin
    { promotion numerique ; constante int qui tient dans le type plus etroit }
    If (PB = PE) Then RT := PB
    Else If (PB In [TY_BYTE, TY_SHORT, TY_CHAR]) And (Nodes[E].CK = CK_INT) And (PE = TY_INT) And ConstFits(Nodes[E].CI, PB) Then RT := PB
    Else If (PE In [TY_BYTE, TY_SHORT, TY_CHAR]) And (Nodes[B].CK = CK_INT) And (PB = TY_INT) And ConstFits(Nodes[B].CI, PE) Then RT := PE
    Else If ((PB = TY_BYTE) And (PE = TY_SHORT)) Or ((PB = TY_SHORT) And (PE = TY_BYTE)) Then RT := TY_SHORT
    Else RT := BinaryPromote(PB, PE);
  End
  Else If (TB = TY_NULL) And IsPrim(TE) Then RT := BoxedType(TE)
  Else If (TE = TY_NULL) And IsPrim(TB) Then RT := BoxedType(TB)
  Else If IsPrim(TB) Then RT := LubType(BoxedType(TB), TE)
  Else If IsPrim(TE) Then RT := LubType(TB, BoxedType(TE))
  Else Begin
    If (Expected > 0) And IsRef(Expected) And Not IsTVarT(Expected) And IsSubtypeRef(TB, Expected) And IsSubtypeRef(TE, Expected) Then RT := Expected
    Else RT := LubType(TB, TE);
  End;
  Coerce(B, RT, CV_ASSIGN);
  Coerce(E, RT, CV_ASSIGN);
  Nodes[N].Typ := RT;
  { repli de constante }
  If (Nodes[C].CK <> CK_NONE) And (Nodes[B].CK <> CK_NONE) And (Nodes[E].CK <> CK_NONE) Then Begin
    If Nodes[C].CI <> 0 Then Begin
      Nodes[N].CK := Nodes[B].CK; Nodes[N].CI := Nodes[B].CI; Nodes[N].CD := Nodes[B].CD; Nodes[N].CS := Nodes[B].CS;
    End
    Else Begin
      Nodes[N].CK := Nodes[E].CK; Nodes[N].CI := Nodes[E].CI; Nodes[N].CD := Nodes[E].CD; Nodes[N].CS := Nodes[E].CS;
    End;
  End;
  PT := 0;
  AttribCond := RT;
End;

Function AttribCast(N : LongInt) : LongInt;
Var T, B, TB, Ch : LongInt;
Begin
  T := ResolveType(Nodes[N].A);
  B := Nodes[N].B;
  TB := AttribExpr(B, T);
  AttribCast := T;
  If (T = TY_NONE) Or (TB = TY_NONE) Then Begin Nodes[N].Typ := T; Nodes[N].Kind := N_CONV; Nodes[N].A := B; Nodes[N].B := 0; Exit; End;
  If Not IsCastable(TB, T) Then Begin
    Err(Nodes[N].Line, 'types incompatibles : ' + TypeStr(TB) + ' ne peut pas etre converti en ' + TypeStr(T));
  End;
  If IsFnNode(B) Then Begin
    { cast sur lambda : le type de la lambda est celui du cast }
    Nodes[N].Kind := N_CONV; Nodes[N].A := B; Nodes[N].B := 0; Nodes[N].Typ := T; Nodes[N].Aux := 1;
    Exit;
  End;
  Nodes[N].Kind := N_CONV;
  Nodes[N].A := B;
  Nodes[N].B := 0;
  Nodes[N].Typ := T;
  Nodes[N].Aux := 1;      { conversion explicite }
  Ch := Nodes[B].CK;
  If (Ch <> CK_NONE) And (Ch <> CK_STR) And IsPrim(T) And IsPrim(TB) Then Begin
    Nodes[N].CK := Nodes[B].CK; Nodes[N].CI := Nodes[B].CI; Nodes[N].CD := Nodes[B].CD;
    FoldConstTo(N, T);
  End
  Else If (Ch = CK_STR) And (T = T_STRING) Then Begin
    Nodes[N].CK := CK_STR; Nodes[N].CS := Nodes[B].CS;
  End;
End;

{ Attribue un motif (type, ou record avec sous-motifs) applique a une valeur de type ValueT }
Procedure AttribPattern(Pat, ValueT : LongInt);
Var
  Tn, T, C, Sub, K, F, Ct, Cnt, L : LongInt; IsVar : Boolean; Pm : LongInt; Nm : String;
Begin
  Tn := Nodes[Pat].A;
  IsVar := (Nodes[Tn].Aux = 0) And (Nodes[Tn].S = 'var') And (Nodes[Tn].N = 0) And (Nodes[Pat].Aux = 0);
  If IsVar Then T := ValueT Else T := ResolveType(Tn);
  Nodes[Pat].Typ := T;
  Nodes[Pat].Sym := -1;
  If (T <> TY_NONE) And (ValueT <> TY_NONE) And Not IsVar Then Begin
    If IsPrim(T) Or IsPrim(ValueT) Then Begin
      If T <> ValueT Then Err(Nodes[Pat].Line, 'types incompatibles : ' + TypeStr(ValueT) + ' ne peut pas etre converti en ' + TypeStr(T));
    End
    Else If Not IsCastable(ValueT, T) Then
      Err(Nodes[Pat].Line, 'types incompatibles : ' + TypeStr(ValueT) + ' ne peut pas etre converti en ' + TypeStr(T));
  End;
  If Nodes[Pat].Aux = 1 Then Begin
    C := ClsOf(T);
    If (C < 0) Or Not Classes[C].IsSrc Or (Nodes[Classes[C].Decl].Aux <> CLS_RECORD) Then Begin
      If T <> TY_NONE Then Err(Nodes[Pat].Line, 'motif de record attendu : ' + TypeStr(T) + ' n''est pas un record');
      Sub := Nodes[Pat].B;
      While Sub <> 0 Do Begin AttribPattern(Sub, TY_NONE); Sub := Nodes[Sub].Next; End;
      Exit;
    End;
    EnsureMembers(C);
    Nodes[Pat].E := C;
    Pm := Nodes[Classes[C].Decl].E;
    Cnt := ChainLen(Pm);
    If Cnt <> ChainLen(Nodes[Pat].B) Then
      Err(Nodes[Pat].Line, 'nombre de sous-motifs incorrect pour le record ' + Classes[C].Simple);
    Sub := Nodes[Pat].B;
    While (Sub <> 0) And (Pm <> 0) Do Begin
      F := FindFieldIn(C, Nodes[Pm].S);
      If F >= 0 Then Ct := MemberType(T, C, Fields[F].Typ) Else Ct := TY_NONE;
      AttribPattern(Sub, Ct);
      Sub := Nodes[Sub].Next;
      Pm := Nodes[Pm].Next;
    End;
  End;
  Nm := Nodes[Pat].S;
  If Nm <> '' Then Begin
    L := NewLocal(Nm, T, LF_PATTERN, Pat);
    Locals[L].HasInit := True;
    Nodes[Pat].Sym := L;
    PushScope(SC_LOCAL, Nm, L);
  End;
  K := 0;
End;

Function AttribInstanceOf(N : LongInt) : LongInt;
Var A, T, TA, V, L : LongInt;
Begin
  A := Nodes[N].A;
  TA := AttribExpr(A, 0);
  If Nodes[N].Aux = 1 Then T := TY_NONE Else T := ResolveType(Nodes[N].B);
  Nodes[N].Typ := TY_BOOLEAN;
  AttribInstanceOf := TY_BOOLEAN;
  If Nodes[N].Aux = 1 Then Begin
    { motif record }
    If IsPrim(TA) Then Err(Nodes[N].Line, 'types incompatibles : ' + TypeStr(TA) + ' ne peut pas etre converti en un record');
    AttribPattern(Nodes[N].C, TA);
    Nodes[N].E := Nodes[Nodes[N].C].Typ;
    Exit;
  End;
  If IsPrim(TA) Then Begin
    Err(Nodes[N].Line, 'types incompatibles : ' + TypeStr(TA) + ' ne peut pas etre converti en ' + TypeStr(T));
    Exit;
  End;
  If (TA <> TY_NONE) And (T <> TY_NONE) And Not IsCastable(TA, T) Then
    Err(Nodes[N].Line, 'types incompatibles : ' + TypeStr(TA) + ' ne peut pas etre converti en ' + TypeStr(T));
  Nodes[N].E := T;
  V := Nodes[N].C;
  If V <> 0 Then Begin
    L := NewLocal(Nodes[V].S, T, LF_PATTERN, V);
    Locals[L].HasInit := True;
    Nodes[V].Sym := L;
    Nodes[V].Typ := T;
    PushScope(SC_LOCAL, Nodes[V].S, L);
  End;
End;

Function AttribThis(N : LongInt) : LongInt;
Var Q, K : LongInt;
Begin
  If Nodes[N].A <> 0 Then Begin
    Q := AttribQual(Nodes[N].A);
    If LastEK <> EK_TYPE Then Begin
      Err(Nodes[N].Line, 'classe attendue avant .this'); AttribThis := TY_NONE; Exit;
    End;
    K := ClsOf(Q);
    If K = CurClass Then Begin
      If CurStatic Then Err(Nodes[N].Line, 'this ne peut pas etre reference depuis un contexte statique');
      NoteThisUse;
      Nodes[N].A := 0;
      Nodes[N].Typ := ThisTypeOf(K);
      Nodes[N].Sym := K;
    End
    Else Begin
      Q := EnclosingInstance(K, Nodes[N].Line, 'variable this');
      If Q = 0 Then Begin AttribThis := TY_NONE; Exit; End;
      Nodes[N].Kind := N_OUTERTHIS;
      Nodes[N].A := 0;
      Nodes[N].Typ := ThisTypeOf(K);
      Nodes[N].Sym := K;
    End;
    AttribThis := Nodes[N].Typ;
    Exit;
  End;
  If CurStatic Then Err(Nodes[N].Line, 'this ne peut pas etre reference depuis un contexte statique');
  NoteThisUse;
  Nodes[N].Typ := ThisTypeOf(CurClass);
  Nodes[N].Sym := CurClass;
  AttribThis := Nodes[N].Typ;
End;

Function AttribIndex(N : LongInt) : LongInt;
Var A, I, TA, TI : LongInt;
Begin
  A := Nodes[N].A; I := Nodes[N].B;
  TA := AttribExpr(A, 0);
  TI := AttribExpr(I, 0);
  Nodes[N].Typ := TY_NONE;
  AttribIndex := TY_NONE;
  If (TA = TY_NONE) Then Exit;
  If Not IsArrayT(TA) Then Begin
    Err(Nodes[N].Line, 'type tableau attendu : ' + TypeStr(TA) + ' trouve');
    Exit;
  End;
  If TI <> TY_NONE Then Begin
    If Not (NumTypeOf(TI) In [TY_BYTE, TY_SHORT, TY_CHAR, TY_INT]) Then
      Err(Nodes[N].Line, 'types incompatibles : ' + TypeStr(TI) + ' ne peut pas etre converti en int')
    Else PromoteTo(I, TY_INT);
  End;
  Nodes[N].Typ := Types[TA].Elem;
  AttribIndex := Nodes[N].Typ;
End;

Function AttribArrayInit(N, ArrT : LongInt) : LongInt;
Var E, ET, T : LongInt;
Begin
  AttribArrayInit := ArrT;
  Nodes[N].Typ := ArrT;
  If ArrT = TY_NONE Then Begin
    E := Nodes[N].A;
    While E <> 0 Do Begin
      If Nodes[E].Kind = N_ARRAYINIT Then AttribArrayInit(E, TY_NONE) Else AttribExpr(E, 0);
      E := Nodes[E].Next;
    End;
    Exit;
  End;
  If Not IsArrayT(ArrT) Then Begin
    Err(Nodes[N].Line, 'initialiseur de tableau non autorise pour le type ' + TypeStr(ArrT));
    Nodes[N].Typ := TY_NONE;
    Exit;
  End;
  ET := Types[ArrT].Elem;
  Nodes[N].E := ChainLen(Nodes[N].A);
  E := Nodes[N].A;
  While E <> 0 Do Begin
    If Nodes[E].Kind = N_ARRAYINIT Then AttribArrayInit(E, ET)
    Else Begin
      T := AttribExpr(E, ET);
      Coerce(E, ET, CV_ASSIGN);
    End;
    E := Nodes[E].Next;
  End;
End;

Function AttribNewArray(N : LongInt) : LongInt;
Var B, T, I, D, Dims : LongInt;
Begin
  T := ResolveType(Nodes[N].A);
  Dims := Nodes[N].Aux;
  For I := 1 To Dims Do If T <> TY_NONE Then T := ArrayT(T);
  D := Nodes[N].B;
  While D <> 0 Do Begin
    AttribExpr(D, 0);
    If Nodes[D].Typ <> TY_NONE Then Begin
      If Not (NumTypeOf(Nodes[D].Typ) In [TY_BYTE, TY_SHORT, TY_CHAR, TY_INT]) Then
        Err(Nodes[D].Line, 'types incompatibles : ' + TypeStr(Nodes[D].Typ) + ' ne peut pas etre converti en int')
      Else PromoteTo(D, TY_INT);
    End;
    D := Nodes[D].Next;
  End;
  If Nodes[N].C <> 0 Then AttribArrayInit(Nodes[N].C, T);
  Nodes[N].Typ := T;
  AttribNewArray := T;
End;

Function AttribClassLit(N : LongInt) : LongInt;
Var T, Q : LongInt;
Begin
  If Nodes[N].Aux = 1 Then Begin
    Q := AttribQual(Nodes[N].A);
    If LastEK <> EK_TYPE Then Begin
      Err(Nodes[N].Line, 'classe attendue avant .class'); AttribClassLit := TY_NONE; Exit;
    End;
    T := Q;
  End
  Else T := ResolveType(Nodes[N].A);
  Nodes[N].E := T;
  Nodes[N].Typ := ClassT1(C_CLASS, BoxedType(T));
  If T = TY_VOID Then Nodes[N].Typ := ClassT1(C_CLASS, ClassT(GetClass('java/lang/Void')));
  AttribClassLit := Nodes[N].Typ;
End;

{ ============================================================================
  4. ANALYSE SEMANTIQUE : appels, creation d'objets, lambdas
  ============================================================================ }

Function MkResolvedType(T, Line : LongInt) : LongInt;
Var N : LongInt;
Begin
  N := NewNode(N_TYPE, Line);
  Nodes[N].Aux := 2;
  Nodes[N].Typ := T;
  MkResolvedType := N;
End;

Function MkNameNode2(Const S : String; Line : LongInt) : LongInt;
Var N : LongInt;
Begin
  N := NewNode(N_NAME, Line);
  Nodes[N].S := S;
  MkNameNode2 := N;
End;

Function MkTypeExprNode(T, Line : LongInt) : LongInt;
Var N : LongInt;
Begin
  N := NewNode(N_TYPEEXPR, Line);
  Nodes[N].Typ := T;
  Nodes[N].Sym := ClsOf(T);
  Nodes[N].Att := 1;
  MkTypeExprNode := N;
End;

{ Classe de portee contenant une methode de ce nom (recherche lexicale) }
Function FindMethodScope(Const Name : String; Var K : LongInt) : Boolean;
Var I, C : LongInt;
Begin
  FindMethodScope := False;
  For I := NScope - 1 Downto ScopeBase Do
    If Scope[I].Kind = SC_CLASSMARK Then Begin
      C := Scope[I].Ref;
      CollectMethods(ThisTypeOf(C), Name, False);
      If NCand > 0 Then Begin K := C; FindMethodScope := True; Exit; End;
    End;
End;

Function FindStaticImportMethod(Const Name : String; Var K : LongInt) : Boolean;
Var Imp, C, I : LongInt; S : String;
Begin
  FindStaticImportMethod := False;
  If CurCU < 0 Then Exit;
  Imp := CUs[CurCU].Imports;
  While Imp <> 0 Do Begin
    If (Nodes[Imp].Mods And ACC_STATIC) <> 0 Then Begin
      C := -1;
      If Nodes[Imp].Aux = 1 Then C := LookupClassQualified(Nodes[Imp].S)
      Else Begin
        S := Nodes[Imp].S;
        If Copy(S, LastPos('.', S) + 1, Length(S)) = Name Then C := LookupClassQualified(Copy(S, 1, LastPos('.', S) - 1));
      End;
      If C >= 0 Then Begin
        CollectMethods(ClassT(C), Name, False);
        For I := 0 To NCand - 1 Do
          If (Meths[CandM[I]].Flags And ACC_STATIC) <> 0 Then Begin K := C; FindStaticImportMethod := True; Exit; End;
      End;
    End;
    Imp := Nodes[Imp].Next;
  End;
End;

Function AttribCtorCall(N : LongInt) : LongInt;
Var SiteT, QT : LongInt; R : TResolved; Name : String; Ok : Boolean;
Begin
  Name := Nodes[N].S;
  Nodes[N].Typ := TY_VOID;
  AttribCtorCall := TY_VOID;
  If (CurMeth < 0) Or (Meths[CurMeth].Name <> '<init>') Then Begin
    Err(Nodes[N].Line, 'l''appel a ' + Name + ' doit etre dans un constructeur');
    Exit;
  End;
  If Name = 'this' Then SiteT := ThisTypeOf(CurClass)
  Else SiteT := Classes[CurClass].Super;
  If SiteT = 0 Then SiteT := T_OBJECT;
  Nodes[N].Mods := Nodes[N].Mods Or CALL_CTOR;
  Nodes[N].E := SiteT;
  { super qualifie : expr.super(...) fournit l'instance englobante de la super-classe interne }
  If Nodes[N].D <> 0 Then Begin
    QT := AttribExpr(Nodes[N].D, 0);
    If Name = 'this' Then Err(Nodes[N].Line, 'un appel this(...) ne peut pas etre qualifie')
    Else If Not IsClassT(SiteT) Or Not Classes[ClsOf(SiteT)].IsInner Then
      Err(Nodes[N].Line, 'la super-classe n''est pas une classe interne : l''appel qualifie super est invalide')
    Else If (QT <> TY_NONE) And Not IsSubtypeRef(Erasure(QT), ClassT(Classes[ClsOf(SiteT)].Outer)) Then
      Err(Nodes[N].Line, 'types incompatibles : ' + TypeStr(QT) + ' ne peut pas etre converti en ' +
          TypeStr(ClassT(Classes[ClsOf(SiteT)].Outer)));
  End;
  Ok := ResolveCall('<init>', SiteT, True, Nodes[N].B, 0, Nodes[N].Line, -1, R);
  If Ok Then Begin
    Nodes[N].Sym := R.M;
    NoteMethodThrows(R.M, Nodes[N].Line);
    If R.Varargs Then Begin Nodes[N].Mods := Nodes[N].Mods Or CALL_VARARGS; Nodes[N].N := R.NPar; End;
  End;
End;

Function AttribCall(N, Expected : LongInt) : LongInt;
Var
  Name : String; Tgt, QT, SiteT, K, M, Ret : LongInt; R : TResolved; Ok : Boolean;
  StaticOnly, IsSuper, ImplicitThis : Boolean; ArgS : String; Recv : LongInt; Imported : Boolean;
Begin
  Name := Nodes[N].S;
  Tgt := Nodes[N].A;
  Nodes[N].Typ := TY_NONE;
  AttribCall := TY_NONE;
  If Nodes[N].Aux = 1 Then Begin AttribCall := AttribCtorCall(N); Exit; End;
  StaticOnly := False; IsSuper := False; ImplicitThis := False; Imported := False;
  K := -1;
  If Tgt = 0 Then Begin
    If FindMethodScope(Name, K) Then Begin
      SiteT := ThisTypeOf(K);
      ImplicitThis := True;
    End
    Else If FindStaticImportMethod(Name, K) Then Begin
      SiteT := ClassT(K);
      Imported := True;
      StaticOnly := True;
    End
    Else Begin
      ArgS := '';
      Tgt := Nodes[N].B;
      While Tgt <> 0 Do Begin AttribExpr(Tgt, 0); Tgt := Nodes[Tgt].Next; End;
      ArgTypeList(Nodes[N].B, ArgS);
      Err(Nodes[N].Line, 'symbole introuvable : methode ' + Name + '(' + ArgS + ')');
      Exit;
    End;
  End
  Else If Nodes[Tgt].Kind = N_SUPER Then Begin
    If Nodes[Tgt].A <> 0 Then Begin
      QT := AttribQual(Nodes[Tgt].A);
      SiteT := QT;
    End
    Else SiteT := Classes[CurClass].Super;
    If SiteT = 0 Then SiteT := T_OBJECT;
    IsSuper := True;
    If CurStatic Then Err(Nodes[N].Line, 'super ne peut pas etre reference depuis un contexte statique');
    NoteThisUse;
    Nodes[Tgt].Typ := SiteT;
    Nodes[Tgt].Att := 1;
  End
  Else Begin
    QT := AttribQual(Tgt);
    Case LastEK Of
      EK_TYPE : Begin SiteT := QT; StaticOnly := True; End;
      EK_PKG : Begin
        Err(Nodes[N].Line, 'symbole introuvable : ' + ExprDotted(Tgt));
        Exit;
      End;
    Else
      If QT = TY_NONE Then Begin
        K := Nodes[N].B;
        While K <> 0 Do Begin AttribExpr(K, 0); K := Nodes[K].Next; End;
        Exit;
      End;
      If IsPrim(QT) Or (QT = TY_VOID) Then Begin
        Err(Nodes[N].Line, TypeStr(QT) + ' ne peut pas etre dereference');
        K := Nodes[N].B;
        While K <> 0 Do Begin AttribExpr(K, 0); K := Nodes[K].Next; End;
        Exit;
      End;
      SiteT := QT;
    End;
  End;
  Ok := ResolveCall(Name, SiteT, False, Nodes[N].B, Expected, Nodes[N].Line, -1, R);
  If Not Ok Then Exit;
  M := R.M;
  Nodes[N].Sym := M;
  NoteMethodThrows(M, Nodes[N].Line);
  { methode statique / d'instance }
  If (Meths[M].Flags And ACC_STATIC) <> 0 Then Begin
    Nodes[N].Mods := Nodes[N].Mods Or CALL_STATIC;
    If Not (ImplicitThis Or Imported) Then Begin
      { le qualifiant n'est evalue que pour ses effets : ignore si c'est un nom ou un type }
      If (Tgt <> 0) And (Nodes[Tgt].Kind In [N_TYPEEXPR, N_NAME, N_SELECT, N_THIS, N_SUPER]) Then Nodes[N].A := 0;
    End
    Else Nodes[N].A := 0;
    Nodes[N].E := SiteT;
    If IsSuper Then Nodes[N].A := 0;
  End
  Else Begin
    If StaticOnly Then Begin
      Err(Nodes[N].Line, 'la methode non statique ' + Name + ' ne peut pas etre referencee depuis un contexte statique');
      Exit;
    End;
    If ImplicitThis Then Begin
      Recv := EnclosingInstance(K, Nodes[N].Line, 'methode ' + Name);
      If Recv = 0 Then Exit;
      Nodes[N].A := Recv;
    End
    Else If IsSuper Then Begin
      Nodes[N].Mods := Nodes[N].Mods Or CALL_SUPER;
      If (Meths[M].Flags And ACC_ABSTRACT) <> 0 Then
        Err(Nodes[N].Line, 'impossible d''appeler la methode abstraite ' + Name + ' avec super');
      Nodes[N].A := MkThisNode(CurClass, Nodes[N].Line);
    End;
    Nodes[N].E := SiteT;
    { Object.methode() sur une interface ou un tableau }
    If (Meths[M].Owner = C_OBJECT) And (IsArrayT(SiteT) Or (IsClassT(Erasure(SiteT)) And IsInterfaceC(ClsOf(Erasure(SiteT))))) Then
      Nodes[N].Mods := Nodes[N].Mods Or CALL_IFACEOBJ;
  End;
  If R.Varargs Then Begin Nodes[N].Mods := Nodes[N].Mods Or CALL_VARARGS; Nodes[N].N := R.NPar; End;
  Ret := R.Ret;
  { cas particuliers }
  If (Name = 'getClass') And (Meths[M].NPar = 0) And (Meths[M].Owner = C_OBJECT) Then Begin
    If Tgt <> 0 Then Ret := ClassT1(C_CLASS, Erasure(SiteT)) Else Ret := ClassT1(C_CLASS, Erasure(ThisTypeOf(CurClass)));
  End;
  If (Name = 'clone') And (Meths[M].NPar = 0) And IsArrayT(SiteT) Then Begin
    Ret := SiteT;
    Nodes[N].Mods := Nodes[N].Mods Or CALL_ARRCLONE;
  End;
  Nodes[N].Typ := Ret;
  AttribCall := Ret;
End;

Function AttribNew(N, Expected : LongInt) : LongInt;
Var
  TNode, Body, OuterE, T, C, OT, SiteT, DiamondCls, Anon, K, Recv, ObjCtor : LongInt;
  R : TResolved; Ok, Diamond : Boolean; Args : LongInt;
Begin
  TNode := Nodes[N].A; Args := Nodes[N].B; Body := Nodes[N].C; OuterE := Nodes[N].D;
  Nodes[N].Typ := TY_NONE;
  AttribNew := TY_NONE;
  Diamond := Nodes[TNode].Mods = 1;
  If OuterE <> 0 Then Begin
    OT := AttribExpr(OuterE, 0);
    K := ClsOf(Erasure(OT));
    If K < 0 Then T := TY_NONE
    Else Begin
      C := FindMemberClass(K, Nodes[TNode].S);
      If C < 0 Then Begin
        Err(Nodes[N].Line, 'symbole introuvable : classe ' + Nodes[TNode].S); T := TY_NONE;
      End
      Else Begin
        T := ClassT(C);
        If Nodes[TNode].A <> 0 Then Begin
          Nodes[TNode].Aux := 0;
          T := ResolveType(TNode);
        End;
      End;
    End;
  End
  Else T := ResolveType(TNode);
  If Not IsClassT(T) Then Begin
    K := Args;
    While K <> 0 Do Begin AttribExpr(K, 0); K := Nodes[K].Next; End;
    If T <> TY_NONE Then Err(Nodes[N].Line, 'creation d''instance impossible pour ' + TypeStr(T));
    Exit;
  End;
  C := Types[T].Cls;
  EnsureMembers(C);
  If (Body = 0) And ((Classes[C].Flags And (ACC_ABSTRACT Or ACC_INTERFACE)) <> 0) Then Begin
    Err(Nodes[N].Line, Classes[C].Simple + ' est abstrait ; ne peut pas etre instancie');
    K := Args;
    While K <> 0 Do Begin AttribExpr(K, 0); K := Nodes[K].Next; End;
    Exit;
  End;
  If (Classes[C].Flags And ACC_ENUM) <> 0 Then Begin
    Err(Nodes[N].Line, 'les types enum ne peuvent pas etre instancies');
    Exit;
  End;
  DiamondCls := -1;
  SiteT := T;
  If Diamond And (Length(Classes[C].TPars) > 0) Then Begin
    DiamondCls := C;
    SiteT := ThisTypeOf(C);
  End;
  If (Body <> 0) And ((Classes[C].Flags And ACC_INTERFACE) <> 0) Then Begin
    { classe anonyme implementant une interface : pas d'argument }
    If Args <> 0 Then Err(Nodes[N].Line, 'une classe anonyme implementant une interface ne prend pas d''argument');
    ObjCtor := FindMethodDecl(C_OBJECT, '<init>', 0);
    Nodes[N].Sym := ObjCtor;
    If Diamond And (DiamondCls >= 0) Then Begin
      NIV := 0;
      T := SiteT;
      If Expected > 0 Then Begin
        For K := 0 To Length(Classes[C].TPars) - 1 Do IVAdd(Classes[C].TPars[K]);
        UnifyExpected(SiteT, Expected);
        T := ResolveIVars(SiteT);
        NIV := 0;
      End
      Else T := Erasure(SiteT);
    End;
  End
  Else Begin
    Ok := ResolveCall('<init>', SiteT, True, Args, Expected, Nodes[N].Line, DiamondCls, R);
    If Ok Then Begin
      { constructeur protege : accessible seulement dans le paquetage (ou par super / classe anonyme) }
      If (Body = 0) And ((Meths[R.M].Flags And (ACC_PUBLIC Or ACC_PRIVATE)) = 0) And ((Meths[R.M].Flags And ACC_PROTECTED) <> 0) And
         (ClassPackage(C) <> CurPackage) Then
        Err(Nodes[N].Line, 'le constructeur de ' + Classes[C].Simple + ' est protege et inaccessible ici');
      Nodes[N].Sym := R.M;
      NoteMethodThrows(R.M, Nodes[N].Line);
      If R.Varargs Then Begin Nodes[N].Mods := Nodes[N].Mods Or CALL_VARARGS; Nodes[N].N := R.NPar; End;
      If DiamondCls >= 0 Then T := R.Ret;
    End;
  End;
  Nodes[N].E := 0;
  If Body <> 0 Then Begin
    AnonSuperCtor := Nodes[N].Sym;
    Anon := EnterLocalClass(Body, T);
    Nodes[N].E := Anon + 1;      { classe anonyme + 1 }
    Nodes[N].Typ := ClassT(Anon);
    C := Anon;
  End
  Else Nodes[N].Typ := T;
  { instance englobante }
  If Classes[C].IsInner Then Begin
    If OuterE <> 0 Then Nodes[N].D := OuterE
    Else Begin
      K := CurClass;
      While (K >= 0) And Not IsSubClass(K, Classes[C].Outer) Do K := Classes[K].Outer;
      If K < 0 Then Begin
        Err(Nodes[N].Line, 'une instance englobante de type ' + Classes[Classes[C].Outer].Simple + ' est requise');
      End
      Else Begin
        Recv := EnclosingInstance(K, Nodes[N].Line, 'classe ' + Classes[C].Simple);
        Nodes[N].D := Recv;
      End;
    End;
  End;
  If Classes[C].Ctx >= 0 Then NoteNewLocal(C);
  AttribNew := Nodes[N].Typ;
End;

{ ----- lambdas ------------------------------------------------------------ }

Function AttribLambda(N, Target : LongInt; Infer : Boolean) : LongInt;
Var
  Sam, Np, I, P, Ctx, SvCtx, SvRet, SvLR, SvLam, Mark, Li, Idx, PT, RetP, B, L, Body : LongInt;
  Owner : LongInt; Names : Array[0..MAXARGS - 1] Of LongInt;
  Dup, SvLoop, SvSw, SvLab, K : LongInt;
Begin
  AttribLambda := TY_NONE;
  Nodes[N].Typ := TY_NONE;
  Sam := FindSAM(Target);
  If Sam < 0 Then Begin
    Err(Nodes[N].Line, 'types incompatibles : ' + TypeStr(Target) + ' n''est pas une interface fonctionnelle');
    Exit;
  End;
  Np := ChainLen(Nodes[N].A);
  If Np <> Meths[Sam].NPar Then Begin
    Err(Nodes[N].Line, 'types incompatibles : nombre de parametres incorrect dans l''expression lambda');
    Exit;
  End;
  If Np > MAXARGS Then Exit;
  Owner := Meths[Sam].Owner;
  If NLambdas >= Length(Lambdas) Then SetLength(Lambdas, NLambdas * 2 + 32);
  Idx := NLambdas;
  Inc(NLambdas);
  FillChar(Lambdas[Idx], SizeOf(TLambdaRec), 0);
  Lambdas[Idx].Node := N;
  Lambdas[Idx].SAM := Sam;
  Lambdas[Idx].IfaceT := Target;
  Lambdas[Idx].OwnerCls := CurClass;
  Lambdas[Idx].InStatic := CurStatic;
  Lambdas[Idx].Meth := -1;
  Lambdas[Idx].RetT := TY_VOID;
  Nodes[N].Sym := Idx;
  Ctx := NewCtx(CTX_LAMBDA, CurCtx);
  Ctxs[Ctx].Node := N;
  Lambdas[Idx].Ctx := Ctx;
  SvCtx := CurCtx; SvRet := CurRet; SvLR := LambdaRets; SvLam := CurLambda;
  SvLoop := LoopDepth; SvSw := SwitchDepth; SvLab := NLabelStk;
  LoopDepth := 0; SwitchDepth := 0;
  CurCtx := Ctx;
  CurLambda := Idx;
  PushThrowCtx(TC_BOUND);
  For K := 0 To Length(Meths[Sam].Thr) - 1 Do AddThrowCtxType(NThrowCtx - 1, Meths[Sam].Thr[K]);
  Mark := NScope;
  SetLength(Lambdas[Idx].ParT, Np);
  P := Nodes[N].A;
  I := 0;
  While P <> 0 Do Begin
    If (Nodes[P].A <> 0) And Not ((Nodes[Nodes[P].A].Aux = 0) And (Nodes[Nodes[P].A].S = 'var') And (Nodes[Nodes[P].A].N = 0)) Then PT := ResolveType(Nodes[P].A)
    Else PT := ResolveIVars(MemberType(Target, Owner, Meths[Sam].Par[I]));
    If PT = T_ANY Then PT := T_OBJECT;
    Li := NewLocal(Nodes[P].S, PT, Nodes[P].Mods Or LF_PARAM, P);
    Locals[Li].HasInit := True;
    Nodes[P].Sym := Li;
    Nodes[P].Typ := PT;
    Lambdas[Idx].ParT[I] := PT;
    PushScope(SC_LOCAL, Nodes[P].S, Li);
    Inc(I);
    P := Nodes[P].Next;
  End;
  RetP := MemberType(Target, Owner, Meths[Sam].Ret);
  Body := Nodes[N].B;
  If Nodes[N].Aux = 1 Then Begin
    { corps-expression }
    If RetP = TY_VOID Then Begin
      AttribExpr(Body, 0);
      If (Nodes[Body].Typ <> TY_NONE) And Not (Nodes[Body].Kind In [N_CALL, N_ASSIGN, N_ASSIGNOP, N_NEW, N_CONV, N_LET]) And
         Not ((Nodes[Body].Kind = N_UNARY) And (Nodes[Body].Aux In [OP_PREINC, OP_PREDEC, OP_POSTINC, OP_POSTDEC])) Then
        Err(Nodes[Body].Line, 'types incompatibles : type de retour incorrect dans l''expression lambda (void attendu)');
      AttribLambda := TY_VOID;
    End
    Else If Infer Or HasIVar(RetP) Then Begin
      B := AttribExpr(Body, 0);
      If B = TY_VOID Then Begin
        Err(Nodes[Body].Line, 'types incompatibles : le corps de la lambda est void'); B := TY_NONE;
      End;
      AttribLambda := B;
    End
    Else Begin
      B := AttribExpr(Body, RetP);
      If B = TY_VOID Then Err(Nodes[Body].Line, 'types incompatibles : le corps de la lambda est void')
      Else Coerce(Body, RetP, CV_ASSIGN);
      AttribLambda := RetP;
    End;
  End
  Else Begin
    If RetP = TY_VOID Then CurRet := TY_VOID
    Else If Infer Or HasIVar(RetP) Then Begin CurRet := RET_INFER; LambdaRets := TY_NONE; End
    Else CurRet := RetP;
    AttribStmt(Body);
    If CurRet = RET_INFER Then Begin
      If LambdaRets = TY_NONE Then AttribLambda := TY_VOID Else AttribLambda := LambdaRets;
    End
    Else AttribLambda := RetP;
  End;
  CurRet := SvRet; LambdaRets := SvLR; CurCtx := SvCtx; CurLambda := SvLam;
  LoopDepth := SvLoop; SwitchDepth := SvSw; NLabelStk := SvLab;
  Dec(NThrowCtx);
  NScope := Mark;
  Nodes[N].Typ := Target;
  Nodes[N].Att := 1;
  Dup := 0;
End;

{ Remplace le noeud N (reference de methode) par une lambda equivalente puis l'attribue }
Function AttribMethodRef(N, Target : LongInt) : LongInt;
Var
  Sam, Np, I, QT, Line, Lam, Prm, Body, Args, ArgT, Recv, Cn, M, Cls, Elem, Let, Vd, Li : LongInt;
  Tl : LongInt; IsType : Boolean; Name : String; HasStatic, HasInst : Boolean;
  Qual : LongInt; Tmp : String; Mark : LongInt; P0 : LongInt; Cast : LongInt;
  Q : LongInt;
Begin
  Line := Nodes[N].Line;
  AttribMethodRef := TY_NONE;
  Sam := FindSAM(Target);
  If Sam < 0 Then Begin
    Err(Line, 'types incompatibles : ' + TypeStr(Target) + ' n''est pas une interface fonctionnelle');
    Nodes[N].Typ := TY_NONE; Nodes[N].Att := 1;
    Exit;
  End;
  Np := Meths[Sam].NPar;
  Name := Nodes[N].S;
  Qual := Nodes[N].A;
  Let := 0;
  If Nodes[N].Aux = 1 Then Begin
    QT := ResolveType(Qual);
    IsType := True;
  End
  Else Begin
    QT := AttribQual(Qual);
    IsType := LastEK = EK_TYPE;
    If LastEK = EK_PKG Then Begin
      Err(Line, 'symbole introuvable : ' + ExprDotted(Qual));
      Nodes[N].Typ := TY_NONE; Nodes[N].Att := 1;
      Exit;
    End;
  End;
  If QT = TY_NONE Then Begin Nodes[N].Typ := TY_NONE; Nodes[N].Att := 1; Exit; End;
  { parametres de la lambda synthetique }
  Lam := NewNode(N_LAMBDA, Line);
  Nodes[Lam].Aux := 1;
  Tl := 0;
  Args := 0;
  For I := 0 To Np - 1 Do Begin
    Prm := NewNode(N_PARAM, Line);
    Nodes[Prm].S := '$m' + IStr(I);
    AppendNode(Nodes[Lam].A, Tl, Prm);
  End;
  { corps }
  Body := 0;
  If Name = 'new' Then Begin
    Tl := 0;
    For I := 0 To Np - 1 Do AppendNode(Args, Tl, MkNameNode2('$m' + IStr(I), Line));
    If IsArrayT(QT) Then Begin
      Body := NewNode(N_NEWARRAY, Line);
      Nodes[Body].A := MkResolvedType(Types[QT].Elem, Line);
      Nodes[Body].Aux := 1;
      Nodes[Body].N := 1;
      Nodes[Body].B := Args;
    End
    Else Begin
      Body := NewNode(N_NEW, Line);
      Nodes[Body].A := MkResolvedType(Erasure(QT), Line);
      If IsClassT(QT) And (Length(Classes[Types[QT].Cls].TPars) > 0) And (Types[QT].NArgs = 0) Then
        Nodes[Nodes[Body].A].Mods := 1;
      Nodes[Body].B := Args;
    End;
  End
  Else If IsType Then Begin
    CollectMethods(QT, Name, False);
    HasStatic := False; HasInst := False;
    For I := 0 To NCand - 1 Do Begin
      M := CandM[I];
      If (Meths[M].Flags And ACC_STATIC) <> 0 Then Begin
        If (Meths[M].NPar = Np) Or (Meths[M].Varargs And (Np >= Meths[M].NPar - 1)) Then HasStatic := True;
      End
      Else If (Np >= 1) And ((Meths[M].NPar = Np - 1) Or (Meths[M].Varargs And (Np - 1 >= Meths[M].NPar - 1))) Then HasInst := True;
    End;
    If HasStatic And (Not HasInst Or (Np = 0)) Or (HasStatic And HasInst) Then Begin
      Tl := 0;
      For I := 0 To Np - 1 Do AppendNode(Args, Tl, MkNameNode2('$m' + IStr(I), Line));
      Body := NewNode(N_CALL, Line);
      Nodes[Body].A := MkTypeExprNode(QT, Line);
      Nodes[Body].S := Name;
      Nodes[Body].B := Args;
    End
    Else If HasInst Then Begin
      Tl := 0;
      For I := 1 To Np - 1 Do AppendNode(Args, Tl, MkNameNode2('$m' + IStr(I), Line));
      Recv := MkNameNode2('$m0', Line);
      { le type du qualifiant lie le premier parametre libre : Type::methode }
      P0 := MemberType(Target, Meths[Sam].Owner, Meths[Sam].Par[0]);
      If (IVIndex(P0) >= 0) And (ITo[IVIndex(P0)] = 0) And IsRef(QT) Then ITo[IVIndex(P0)] := QT;
      P0 := ResolveIVars(P0);
      If (P0 = T_ANY) Or Not IsSubtypeRef(P0, Erasure(QT)) Then Begin
        Cast := NewNode(N_CAST, Line);
        Nodes[Cast].A := MkResolvedType(QT, Line);
        Nodes[Cast].B := Recv;
        Recv := Cast;
      End;
      Body := NewNode(N_CALL, Line);
      Nodes[Body].A := Recv;
      Nodes[Body].S := Name;
      Nodes[Body].B := Args;
    End
    Else Begin
      Err(Line, 'reference de methode invalide : symbole introuvable ' + Name + ' dans ' + TypeStr(QT));
      Nodes[N].Typ := TY_NONE; Nodes[N].Att := 1;
      Exit;
    End;
  End
  Else Begin
    { expr::methode ou this::methode ou super::methode }
    Tl := 0;
    For I := 0 To Np - 1 Do AppendNode(Args, Tl, MkNameNode2('$m' + IStr(I), Line));
    Body := NewNode(N_CALL, Line);
    Nodes[Body].S := Name;
    Nodes[Body].B := Args;
    If Nodes[Qual].Kind = N_THIS Then Begin
      Nodes[Body].A := NewNode(N_THIS, Line);
    End
    Else If Nodes[Qual].Kind = N_SUPER Then Begin
      Nodes[Body].A := NewNode(N_SUPER, Line);
    End
    Else Begin
      { evalue le qualifiant une seule fois, a la creation }
      Tmp := '$mr' + IStr(NLocals);
      Li := NewLocal(Tmp, QT, ACC_FINAL, Qual);
      Locals[Li].HasInit := True;
      Locals[Li].Assigns := 0;
      Vd := NewNode(N_VARDECL, Line);
      Nodes[Vd].S := Tmp;
      Nodes[Vd].A := Qual;
      Nodes[Vd].Sym := Li;
      Nodes[Vd].Typ := QT;
      Let := Vd;
      Nodes[Body].A := MkNameNode2(Tmp, Line);
    End;
  End;
  Nodes[Lam].B := Body;
  { remplace le noeud : lambda directe ou N_LET }
  If Let = 0 Then Begin
    Nodes[N].Kind := N_LAMBDA;
    Nodes[N].A := Nodes[Lam].A;
    Nodes[N].B := Body;
    Nodes[N].Aux := 1;
    Nodes[N].Att := 0;
    AttribMethodRef := AttribLambda(N, Target, HasIVar(Target));
  End
  Else Begin
    Nodes[N].Kind := N_LET;
    Nodes[N].A := Let;
    Nodes[N].B := Lam;
    Nodes[N].Att := 0;
    Mark := NScope;
    PushScope(SC_LOCAL, Nodes[Let].S, Nodes[Let].Sym);
    AttribMethodRef := AttribLambda(Lam, Target, HasIVar(Target));
    NScope := Mark;
    Nodes[N].Typ := Target;
  End;
  Nodes[N].Att := 1;
  Q := 0; Cls := 0; Elem := 0; Cn := 0; ArgT := 0;
End;

{ ============================================================================
  Classes scellees : permits, verifications de la hierarchie
  ============================================================================ }

Function IsSealedC(C : LongInt) : Boolean;
Begin
  EnsureHeader(C);
  IsSealedC := (C >= 0) And ((Classes[C].Flags And MOD_SEALED) <> 0);
End;

Function DirectlyExtends(X, C : LongInt) : Boolean;
Var I : LongInt;
Begin
  DirectlyExtends := False;
  EnsureHeader(X);
  If IsClassT(Classes[X].Super) And (Types[Classes[X].Super].Cls = C) Then DirectlyExtends := True;
  For I := 0 To Length(Classes[X].Ifaces) - 1 Do
    If IsClassT(Classes[X].Ifaces[I]) And (Types[Classes[X].Ifaces[I]].Cls = C) Then DirectlyExtends := True;
End;

{ Classes permises d'une classe scellee : clause permits, sinon sous-classes directes du meme fichier }
Procedure ComputePermits(C : LongInt);
Var D, T, X, N : LongInt; S : TSavedCtx; Ty : LongInt;
Begin
  If Classes[C].PermitsState = 2 Then Exit;
  Classes[C].PermitsState := 2;
  SetLength(Classes[C].Permits, 0);
  If Not Classes[C].IsSrc Then Exit;
  D := Classes[C].Decl;
  N := 0;
  If Nodes[D].Dflt <> 0 Then Begin
    IsolateEnter(C, S);
    T := Nodes[D].Dflt;
    While T <> 0 Do Begin
      Ty := ResolveType(T);
      If IsClassT(Ty) Then Begin
        SetLength(Classes[C].Permits, N + 1);
        Classes[C].Permits[N] := Types[Ty].Cls;
        Inc(N);
      End;
      T := Nodes[T].Next;
    End;
    IsolateLeave(S);
    Exit;
  End;
  { clause absente : sous-classes directes declarees dans le meme fichier source }
  For X := 0 To NClasses - 1 Do
    If Classes[X].IsSrc And (Classes[X].CU = Classes[C].CU) And (X <> C) And ((Classes[X].Flags And MOD_LOCAL) = 0) Then
      If DirectlyExtends(X, C) Then Begin
        SetLength(Classes[C].Permits, N + 1);
        Classes[C].Permits[N] := X;
        Inc(N);
      End;
End;

Function PkgOfClass(C : LongInt) : String;
Var K : LongInt;
Begin
  K := LastPos('/', Classes[C].Name);
  PkgOfClass := Copy(Classes[C].Name, 1, K);
End;

Procedure CheckSealed(C : LongInt);
Var
  D, Line, I, K, SupCount : LongInt; Fl : LongInt; Sups : Array Of LongInt; HasSealedSup, InList : Boolean;
Begin
  If Not Classes[C].IsSrc Then Exit;
  D := Classes[C].Decl;
  Line := Nodes[D].Line;
  Fl := Classes[C].Flags;
  If ((Fl And MOD_SEALED) <> 0) And ((Fl And MOD_NONSEALED) <> 0) Then
    Err(Line, 'les modificateurs sealed et non-sealed sont incompatibles');
  If ((Fl And MOD_SEALED) <> 0) And ((Fl And ACC_FINAL) <> 0) Then
    Err(Line, 'les modificateurs sealed et final sont incompatibles');
  If ((Fl And MOD_SEALED) <> 0) And ((Fl And MOD_ANON) <> 0) Then
    Err(Line, 'une classe anonyme ne peut pas etre scellee');
  { classe scellee : sous-classes permises }
  If (Fl And MOD_SEALED) <> 0 Then Begin
    ComputePermits(C);
    If Length(Classes[C].Permits) = 0 Then
      Err(Line, 'la classe scellee ' + Classes[C].Simple + ' doit avoir des sous-classes')
    Else
      For I := 0 To Length(Classes[C].Permits) - 1 Do Begin
        K := Classes[C].Permits[I];
        If K < 0 Then Continue;
        If Not DirectlyExtends(K, C) Then
          Err(Line, 'clause permits invalide : ' + Classes[K].Simple + ' doit heriter directement de la classe scellee ' + Classes[C].Simple)
        Else If PkgOfClass(K) <> PkgOfClass(C) Then
          Err(Line, 'clause permits invalide : la sous-classe ' + Classes[K].Simple + ' doit etre dans le meme paquetage que ' + Classes[C].Simple);
      End;
  End;
  { super-types directs }
  SupCount := 0;
  SetLength(Sups, 0);
  If IsClassT(Classes[C].Super) Then Begin SetLength(Sups, 1); Sups[0] := Types[Classes[C].Super].Cls; SupCount := 1; End;
  For I := 0 To Length(Classes[C].Ifaces) - 1 Do
    If IsClassT(Classes[C].Ifaces[I]) Then Begin
      SetLength(Sups, SupCount + 1); Sups[SupCount] := Types[Classes[C].Ifaces[I]].Cls; Inc(SupCount);
    End;
  HasSealedSup := False;
  For I := 0 To SupCount - 1 Do Begin
    If Not IsSealedC(Sups[I]) Then Continue;
    HasSealedSup := True;
    If (Fl And MOD_LOCAL) <> 0 Then Begin
      Err(Line, 'une classe locale ou anonyme ne peut pas heriter de la classe scellee ' + Classes[Sups[I]].Simple);
      Continue;
    End;
    ComputePermits(Sups[I]);
    InList := False;
    For K := 0 To Length(Classes[Sups[I]].Permits) - 1 Do If Classes[Sups[I]].Permits[K] = C Then InList := True;
    If Not InList Then
      Err(Line, 'la classe ' + Classes[C].Simple + ' ne peut pas heriter de la classe scellee ' + Classes[Sups[I]].Simple +
          ' (elle n''est pas listee dans sa clause permits)');
    If ((Fl And (ACC_FINAL Or MOD_SEALED Or MOD_NONSEALED Or ACC_ENUM)) = 0) Then
      Err(Line, 'les modificateurs sealed, non-sealed ou final sont attendus pour ' + Classes[C].Simple);
  End;
  If ((Fl And MOD_NONSEALED) <> 0) And Not HasSealedSup Then
    Err(Line, 'le modificateur non-sealed n''est pas autorise ici : ' + Classes[C].Simple + ' n''a pas de super-type scelle');
End;
{ ============================================================================
  4. ANALYSE SEMANTIQUE : repartition des expressions et instructions
  ============================================================================ }

Function AttribExpr(N, Expected : LongInt) : LongInt;
Var T : LongInt;
Begin
  If N = 0 Then Begin AttribExpr := TY_NONE; Exit; End;
  If Nodes[N].Att = 1 Then Begin AttribExpr := Nodes[N].Typ; Exit; End;
  T := TY_NONE;
  Case Nodes[N].Kind Of
    N_LIT : T := AttribLit(N);
    N_NAME, N_SELECT : Begin
      T := AttribQual(N);
      If LastEK = EK_TYPE Then Begin
        Err(Nodes[N].Line, 'symbole introuvable : variable ' + ExprDotted(N));
        T := TY_NONE;
        Nodes[N].Typ := TY_NONE;
      End
      Else If LastEK = EK_PKG Then Begin
        Err(Nodes[N].Line, 'symbole introuvable : variable ' + ExprDotted(N));
        T := TY_NONE;
      End;
    End;
    N_TYPEEXPR, N_PKGREF : Begin
      Err(Nodes[N].Line, 'expression attendue');
      T := TY_NONE;
    End;
    N_THIS : T := AttribThis(N);
    N_SUPER : Begin
      Err(Nodes[N].Line, '''super'' ne peut pas etre utilise ici');
      T := TY_NONE;
    End;
    N_CALL : T := AttribCall(N, Expected);
    N_NEW : T := AttribNew(N, Expected);
    N_NEWARRAY : T := AttribNewArray(N);
    N_ARRAYINIT : T := AttribArrayInit(N, Expected);
    N_INDEX : T := AttribIndex(N);
    N_UNARY : T := AttribUnary(N);
    N_BINARY : T := AttribBinary(N);
    N_ASSIGN : T := AttribAssign(N);
    N_ASSIGNOP : T := AttribAssignOp(N);
    N_COND : T := AttribCond(N, Expected);
    N_CAST : T := AttribCast(N);
    N_INSTANCEOF : T := AttribInstanceOf(N);
    N_CLASSLIT : T := AttribClassLit(N);
    N_SWITCHEXPR : T := AttribSwitchExpr(N, Expected);
    N_LAMBDA : Begin
      If (Expected = 0) Or (Expected = TY_NONE) Or Not IsClassT(Expected) Then Begin
        Err(Nodes[N].Line, 'expression lambda non autorisee ici');
        T := TY_NONE;
      End
      Else Begin
        AttribLambda(N, Expected, HasIVar(Expected));
        FinishLambda(N, ResolveIVars(Expected));
        T := Nodes[N].Typ;
      End;
    End;
    N_METHODREF : Begin
      If (Expected = 0) Or (Expected = TY_NONE) Or Not IsClassT(Expected) Then Begin
        Err(Nodes[N].Line, 'reference de methode non autorisee ici');
        T := TY_NONE;
      End
      Else Begin
        AttribMethodRef(N, Expected);
        FinishLambda(N, ResolveIVars(Expected));
        T := Nodes[N].Typ;
      End;
    End;
  Else
    Internal('noeud d''expression inattendu : ' + IStr(Nodes[N].Kind));
  End;
  Nodes[N].Typ := T;
  Nodes[N].Att := 1;
  AttribExpr := T;
End;

{ ----- instructions ------------------------------------------------------- }

Function LocalDeclared(Const Name : String) : Boolean;
Var I : LongInt;
Begin
  LocalDeclared := False;
  For I := NScope - 1 Downto ScopeBase Do Begin
    If Scope[I].Kind = SC_CLASSMARK Then Exit;
    If (Scope[I].Kind = SC_LOCAL) And (Scope[I].Name = Name) And
       ((Locals[Scope[I].Ref].Flags And LF_PATTERN) = 0) Then Begin
      LocalDeclared := True; Exit;
    End;
  End;
End;

Procedure AttribCondition(N : LongInt);
Var T : LongInt;
Begin
  T := AttribExpr(N, 0);
  If T = TY_NONE Then Exit;
  If NumTypeOf(T) <> TY_BOOLEAN Then Begin
    Err(Nodes[N].Line, 'types incompatibles : ' + TypeStr(T) + ' ne peut pas etre converti en boolean');
    Exit;
  End;
  PromoteTo(N, TY_BOOLEAN);
End;

Function ElementTypeOfIterable(T : LongInt) : LongInt;
Var A : LongInt;
Begin
  A := AsSuper(T, C_ITERABLE);
  If (A <> 0) And (Types[A].NArgs = 1) Then ElementTypeOfIterable := Types[A].Args[0]
  Else If A <> 0 Then ElementTypeOfIterable := T_OBJECT
  Else ElementTypeOfIterable := TY_NONE;
End;

Procedure DeclareLocal(V, T, Flags : LongInt; HasInit : Boolean);
Var L : LongInt;
Begin
  If LocalDeclared(Nodes[V].S) Then
    Err(Nodes[V].Line, 'la variable ' + Nodes[V].S + ' est deja definie dans la methode');
  L := NewLocal(Nodes[V].S, T, Flags, V);
  Locals[L].HasInit := HasInit;
  Nodes[V].Sym := L;
  Nodes[V].Typ := T;
  PushScope(SC_LOCAL, Nodes[V].S, L);
End;

Procedure AttribLocalVar(N : LongInt);
Var
  V, T, TN, Init, IT, Fl, L, I : LongInt; K : Byte; CI : Int64; CD : Double; IsVar : Boolean;
Begin
  TN := Nodes[N].A;
  Fl := Nodes[N].Mods And ACC_FINAL;
  IsVar := (Nodes[TN].Aux = 0) And (Nodes[TN].S = 'var') And (Nodes[TN].N = 0);
  If IsVar And (LookupTypeSimple('var') > 0) Then IsVar := False;
  If Not IsVar Then T := ResolveType(TN) Else T := TY_NONE;
  V := Nodes[N].B;
  While V <> 0 Do Begin
    Init := Nodes[V].A;
    If IsVar Then Begin
      If Init = 0 Then Begin
        Err(Nodes[V].Line, 'impossible de deduire le type de la variable ' + Nodes[V].S + ' (initialiseur absent)');
        IT := TY_NONE;
      End
      Else Begin
        IT := AttribExpr(Init, 0);
        If IT = TY_NULL Then Begin Err(Nodes[V].Line, 'impossible de deduire le type pour ''null'''); IT := TY_NONE; End;
        If IT = TY_VOID Then Begin Err(Nodes[V].Line, 'impossible de deduire le type : void'); IT := TY_NONE; End;
        If Nodes[Init].Kind = N_ARRAYINIT Then Begin Err(Nodes[V].Line, 'impossible de deduire le type d''un initialiseur de tableau'); IT := TY_NONE; End;
      End;
      DeclareLocal(V, IT, Fl, True);
    End
    Else Begin
      IT := T;
      For I := 1 To Nodes[V].N Do If IT <> TY_NONE Then IT := ArrayT(IT);
      If Init <> 0 Then Begin
        If Nodes[Init].Kind = N_ARRAYINIT Then AttribArrayInit(Init, IT)
        Else Begin
          AttribExpr(Init, IT);
          If Nodes[Init].Typ <> TY_NONE Then Coerce(Init, IT, CV_ASSIGN);
        End;
      End;
      DeclareLocal(V, IT, Fl, Init <> 0);
    End;
    L := Nodes[V].Sym;
    { variable finale constante }
    If (Fl <> 0) And (Init <> 0) And (Nodes[Init].CK <> CK_NONE) And (IsPrim(Locals[L].Typ) Or (Locals[L].Typ = T_STRING)) Then Begin
      K := Nodes[Init].CK; CI := Nodes[Init].CI; CD := Nodes[Init].CD;
      If IsPrim(Locals[L].Typ) And (K <> CK_STR) Then Begin
        ConstConv(K, CI, CD, Locals[L].Typ);
        Locals[L].CK := K; Locals[L].CI := CI; Locals[L].CD := CD;
      End
      Else If (K = CK_STR) And (Locals[L].Typ = T_STRING) Then Begin
        Locals[L].CK := CK_STR; Locals[L].CS := Nodes[Init].CS;
      End;
    End;
    V := Nodes[V].Next;
  End;
End;

Function IsStatementExpr(N : LongInt) : Boolean;
Begin
  Case Nodes[N].Kind Of
    N_ASSIGN, N_ASSIGNOP, N_CALL, N_NEW : IsStatementExpr := True;
    N_UNARY : IsStatementExpr := Nodes[N].Aux In [OP_PREINC, OP_PREDEC, OP_POSTINC, OP_POSTDEC];
    N_CONV, N_LET : IsStatementExpr := True;
  Else
    IsStatementExpr := False;
  End;
End;

Procedure AttribSwitchStmt(N : LongInt); Forward;

Procedure PushLabel(Const Name : String; IsLoop : Boolean);
Begin
  If NLabelStk >= Length(LabelNames) Then Begin
    SetLength(LabelNames, NLabelStk * 2 + 8);
    SetLength(LabelLoop, NLabelStk * 2 + 8);
  End;
  LabelNames[NLabelStk] := Name;
  LabelLoop[NLabelStk] := IsLoop;
  Inc(NLabelStk);
End;

Procedure AttribStmt(N : LongInt);
Var
  S, Mark, T, C, Ct, I, V, L, Tn, Lub, R, Li, Ex, SvRet : LongInt; Found : Boolean;
  Hv, Tl : LongInt; ET : LongInt; IsVar : Boolean; Idx, TcI, K, J, First : LongInt; Seen : Boolean;
Begin
  If N = 0 Then Exit;
  Case Nodes[N].Kind Of
    N_BLOCK : Begin
      Mark := NScope;
      S := Nodes[N].A;
      While S <> 0 Do Begin AttribStmt(S); S := Nodes[S].Next; End;
      NScope := Mark;
    End;
    N_EMPTY : ;
    N_LOCALVAR : AttribLocalVar(N);
    N_EXPRSTMT : Begin
      T := AttribExpr(Nodes[N].A, 0);
      If (Nodes[Nodes[N].A].Kind <> N_NAME) And Not IsStatementExpr(Nodes[N].A) And (T <> TY_NONE) Then
        Err(Nodes[N].Line, 'n''est pas une instruction')
      Else If (Nodes[Nodes[N].A].Kind = N_NAME) And (T <> TY_NONE) Then
        Err(Nodes[N].Line, 'n''est pas une instruction');
    End;
    N_IF : Begin
      AttribCondition(Nodes[N].A);
      Mark := NScope;
      AttribStmt(Nodes[N].B);
      If Nodes[N].C <> 0 Then AttribStmt(Nodes[N].C);
    End;
    N_WHILE : Begin
      AttribCondition(Nodes[N].A);
      Inc(LoopDepth);
      AttribStmt(Nodes[N].B);
      Dec(LoopDepth);
    End;
    N_DO : Begin
      Inc(LoopDepth);
      AttribStmt(Nodes[N].A);
      Dec(LoopDepth);
      AttribCondition(Nodes[N].B);
    End;
    N_FOR : Begin
      Mark := NScope;
      S := Nodes[N].A;
      While S <> 0 Do Begin AttribStmt(S); S := Nodes[S].Next; End;
      If Nodes[N].B <> 0 Then AttribCondition(Nodes[N].B);
      S := Nodes[N].C;
      While S <> 0 Do Begin AttribStmt(S); S := Nodes[S].Next; End;
      Inc(LoopDepth);
      AttribStmt(Nodes[N].D);
      Dec(LoopDepth);
      NScope := Mark;
    End;
    N_FOREACH : Begin
      Mark := NScope;
      T := AttribExpr(Nodes[N].B, 0);
      ET := TY_NONE;
      If IsArrayT(T) Then Begin ET := Types[T].Elem; Nodes[N].Aux := 1; End
      Else If T <> TY_NONE Then Begin
        ET := ElementTypeOfIterable(T);
        If ET = TY_NONE Then Err(Nodes[N].Line, 'for-each non applicable au type d''expression : ' + TypeStr(T));
        Nodes[N].Aux := 0;
      End;
      Nodes[N].E := ET;
      Tn := Nodes[N].A;
      IsVar := (Nodes[Tn].Aux = 0) And (Nodes[Tn].S = 'var') And (Nodes[Tn].N = 0);
      If IsVar Then T := ET Else T := ResolveType(Tn);
      If (T <> TY_NONE) And (ET <> TY_NONE) And Not IsLooseConv(ET, T) Then
        Err(Nodes[N].Line, 'types incompatibles : ' + TypeStr(ET) + ' ne peut pas etre converti en ' + TypeStr(T));
      { variable de boucle }
      V := NewNode(N_VARDECL, Nodes[N].Line);
      Nodes[V].S := Nodes[N].S;
      DeclareLocal(V, T, Nodes[N].Mods And ACC_FINAL, True);
      Nodes[N].Sym := Nodes[V].Sym;
      Nodes[N].D := V;
      Inc(LoopDepth);
      AttribStmt(Nodes[N].C);
      Dec(LoopDepth);
      NScope := Mark;
    End;
    N_RETURN : Begin
      If CurRet = RET_INFER Then Begin
        If Nodes[N].A = 0 Then Begin
          { return; dans une lambda a inferer }
        End
        Else Begin
          T := AttribExpr(Nodes[N].A, 0);
          If T <> TY_NONE Then Begin
            If T = TY_VOID Then Err(Nodes[N].Line, 'types incompatibles : valeur de retour void')
            Else Begin
              If LambdaRets = TY_NONE Then LambdaRets := BoxedType(T)
              Else LambdaRets := LubType(LambdaRets, BoxedType(T));
            End;
          End;
          If CurLambda >= 0 Then Begin
            SetLength(Lambdas[CurLambda].RetNodes, Length(Lambdas[CurLambda].RetNodes) + 1);
            Lambdas[CurLambda].RetNodes[Length(Lambdas[CurLambda].RetNodes) - 1] := N;
          End;
        End;
      End
      Else If Nodes[N].A = 0 Then Begin
        If (CurRet <> TY_VOID) And (CurRet <> TY_NONE) Then Err(Nodes[N].Line, 'types incompatibles : valeur de retour manquante');
      End
      Else Begin
        If CurRet = TY_VOID Then Begin
          AttribExpr(Nodes[N].A, 0);
          Err(Nodes[N].Line, 'types incompatibles : valeur de retour inattendue');
        End
        Else Begin
          If Nodes[Nodes[N].A].Kind = N_ARRAYINIT Then AttribArrayInit(Nodes[N].A, CurRet)
          Else AttribExpr(Nodes[N].A, CurRet);
          Coerce(Nodes[N].A, CurRet, CV_ASSIGN);
          { enregistre le return pour les lambdas dont le type est connu }
          If (CurLambda >= 0) And (Ctxs[CurCtx].Kind = CTX_LAMBDA) Then Begin
            SetLength(Lambdas[CurLambda].RetNodes, Length(Lambdas[CurLambda].RetNodes) + 1);
            Lambdas[CurLambda].RetNodes[Length(Lambdas[CurLambda].RetNodes) - 1] := N;
          End;
        End;
      End;
    End;
    N_BREAK : Begin
      If Nodes[N].S <> '' Then Begin
        Found := False;
        For I := 0 To NLabelStk - 1 Do If LabelNames[I] = Nodes[N].S Then Found := True;
        If Not Found Then Err(Nodes[N].Line, 'etiquette non definie : ' + Nodes[N].S);
      End
      Else If (LoopDepth = 0) And (SwitchDepth = 0) Then Err(Nodes[N].Line, 'break en dehors d''un switch ou d''une boucle');
    End;
    N_CONTINUE : Begin
      If Nodes[N].S <> '' Then Begin
        Found := False;
        For I := 0 To NLabelStk - 1 Do If (LabelNames[I] = Nodes[N].S) And LabelLoop[I] Then Found := True;
        If Not Found Then Err(Nodes[N].Line, 'etiquette de boucle non definie : ' + Nodes[N].S);
      End
      Else If LoopDepth = 0 Then Err(Nodes[N].Line, 'continue en dehors d''une boucle');
    End;
    N_LABELED : Begin
      T := Nodes[N].A;
      PushLabel(Nodes[N].S, Nodes[T].Kind In [N_WHILE, N_DO, N_FOR, N_FOREACH]);
      AttribStmt(T);
      Dec(NLabelStk);
    End;
    N_THROW : Begin
      T := AttribExpr(Nodes[N].A, 0);
      If (T <> TY_NONE) And (T <> TY_NULL) And Not IsSubtypeRef(T, T_THROWABLE) Then
        Err(Nodes[N].Line, 'types incompatibles : ' + TypeStr(T) + ' ne peut pas etre converti en Throwable')
      Else If IsClassT(T) Then Begin
        Ex := Nodes[N].A;
        If (Nodes[Ex].Kind = N_NAME) And (Nodes[Ex].Aux = 1) And ((Locals[Nodes[Ex].Sym].Flags And LF_CATCH) <> 0) And
           (Locals[Nodes[Ex].Sym].Assigns = 0) Then Begin
          { relance precise d'un parametre de catch }
          For K := 0 To Length(Locals[Nodes[Ex].Sym].Rethrow) - 1 Do NoteThrown(Locals[Nodes[Ex].Sym].Rethrow[K], Nodes[N].Line);
        End
        Else NoteThrown(Types[T].Cls, Nodes[N].Line);
      End;
    End;
    N_SYNC : Begin
      T := AttribExpr(Nodes[N].A, 0);
      If IsPrim(T) Then Err(Nodes[N].Line, 'type de reference attendu');
      AttribStmt(Nodes[N].B);
    End;
    N_ASSERT : Begin
      AttribCondition(Nodes[N].A);
      If Nodes[N].B <> 0 Then AttribExpr(Nodes[N].B, 0);
      Classes[CurClass].HasAssert := True;
    End;
    N_YIELD : Begin
      T := AttribExpr(Nodes[N].A, 0);
      If NYields >= Length(YieldNodes) Then SetLength(YieldNodes, NYields * 2 + 16);
      YieldNodes[NYields] := N;
      Inc(NYields);
    End;
    N_LOCALCLASS : Begin
      C := EnterLocalClass(Nodes[N].A, 0);
    End;
    N_SWITCH : AttribSwitchStmt(N);
    N_TRY : Begin
      { types interceptes resolus avant le corps (analyse des exceptions verifiees) }
      C := Nodes[N].C;
      Idx := 0;
      PushThrowCtx(TC_TRY);
      TcI := NThrowCtx - 1;
      While C <> 0 Do Begin
        Ct := Nodes[C].A;
        While Ct <> 0 Do Begin
          T := ResolveType(Ct);
          Nodes[Ct].Typ := T;
          If (T <> TY_NONE) And Not IsSubtypeRef(T, T_THROWABLE) Then
            Err(Nodes[Ct].Line, 'types incompatibles : ' + TypeStr(T) + ' ne peut pas etre converti en Throwable');
          If IsClassT(T) Then AddThrowCtxType(TcI, Types[T].Cls) Else AddThrowCtxType(TcI, ClsOf(T_THROWABLE));
          Ct := Nodes[Ct].Next;
        End;
        C := Nodes[C].Next;
      End;
      Mark := NScope;
      { ressources }
      S := Nodes[N].A;
      While S <> 0 Do Begin
        If Nodes[S].Kind = N_LOCALVAR Then Begin
          AttribLocalVar(S);
          V := Nodes[S].B;
          T := Locals[Nodes[V].Sym].Typ;
        End
        Else Begin
          T := AttribExpr(Nodes[S].A, 0);
        End;
        If (T <> TY_NONE) And Not IsSubtypeRef(T, ClassT(GetClass('java/lang/AutoCloseable'))) Then
          Err(Nodes[S].Line, 'types incompatibles : la ressource doit etre de type AutoCloseable')
        Else If T <> TY_NONE Then Begin
          CollectMethods(T, 'close', False);
          For K := 0 To NCand - 1 Do
            If Meths[CandM[K]].NPar = 0 Then Begin NoteMethodThrows(CandM[K], Nodes[S].Line); Break; End;
        End;
        S := Nodes[S].Next;
      End;
      AttribStmt(Nodes[N].B);
      NScope := Mark;
      { exceptions verifiees qui peuvent sortir du corps }
      Dec(NThrowCtx);
      { clauses catch }
      C := Nodes[N].C;
      Idx := 0;
      While C <> 0 Do Begin
        Mark := NScope;
        Lub := TY_NONE;
        Ct := Nodes[C].A;
        First := Idx;
        While Ct <> 0 Do Begin
          T := Nodes[Ct].Typ;
          If Lub = TY_NONE Then Lub := T Else Lub := LubType(Lub, T);
          { catch d'une exception verifiee jamais lancee }
          If IsClassT(T) Then Begin
            K := Types[T].Cls;
            If IsCheckedExc(K) And (Classes[K].Name <> 'java/lang/Exception') And (Classes[K].Name <> 'java/lang/Throwable') Then Begin
              Seen := False;
              For J := 0 To ThrowCtx[TcI].NThrown - 1 Do
                If IsSubClass(ThrowCtx[TcI].Thrown[J], K) Or IsSubClass(K, ThrowCtx[TcI].Thrown[J]) Then Seen := True;
              If Not Seen Then
                Err(Nodes[Ct].Line, 'l''exception ' + Classes[K].Simple + ' n''est jamais lancee dans le corps du try correspondant');
            End;
          End;
          Inc(Idx);
          Ct := Nodes[Ct].Next;
        End;
        V := NewNode(N_VARDECL, Nodes[C].Line);
        Nodes[V].S := Nodes[C].S;
        DeclareLocal(V, Lub, 0, True);
        Nodes[C].Sym := Nodes[V].Sym;
        Nodes[C].D := V;
        { liste pour la relance precise }
        L := Nodes[V].Sym;
        Locals[L].Flags := Locals[L].Flags Or LF_CATCH;
        SetLength(Locals[L].Rethrow, 0);
        For J := 0 To ThrowCtx[TcI].NRec - 1 Do
          If (ThrowCtx[TcI].RecOwn[J] >= First) And (ThrowCtx[TcI].RecOwn[J] < Idx) Then Begin
            SetLength(Locals[L].Rethrow, Length(Locals[L].Rethrow) + 1);
            Locals[L].Rethrow[Length(Locals[L].Rethrow) - 1] := ThrowCtx[TcI].RecLst[J];
          End;
        AttribStmt(Nodes[C].B);
        NScope := Mark;
        C := Nodes[C].Next;
      End;
      If Nodes[N].D <> 0 Then AttribStmt(Nodes[N].D);
    End;
  Else
    Internal('instruction inattendue : ' + IStr(Nodes[N].Kind));
  End;
  Nodes[N].Att := 1;
  Hv := 0; Tl := 0; Li := 0; Ex := 0; R := 0; SvRet := 0; L := 0;
End;

{ ----- switch ------------------------------------------------------------- }

Const
  SW_INT = 0;
  SW_STR = 1;
  SW_ENUM = 2;
  SW_PATTERN = 3;

Function SwitchHasPattern(N : LongInt) : Boolean;
Var Cs, Lb : LongInt;
Begin
  SwitchHasPattern := False;
  Cs := Nodes[N].B;
  While Cs <> 0 Do Begin
    Lb := Nodes[Cs].A;
    While Lb <> 0 Do Begin
      If (Nodes[Lb].Kind = N_PATTERN) Or ((Nodes[Lb].Kind = N_LIT) And (Nodes[Lb].Aux = LIT_NULL)) Then Begin
        SwitchHasPattern := True; Exit;
      End;
      Lb := Nodes[Lb].Next;
    End;
    Cs := Nodes[Cs].Next;
  End;
End;

Function AttribSwitchSel(N : LongInt; Var Mode : LongInt) : LongInt;
Var Sel, ST, U : LongInt;
Begin
  Sel := Nodes[N].A;
  ST := AttribExpr(Sel, 0);
  Mode := SW_INT;
  AttribSwitchSel := ST;
  If ST = TY_NONE Then Exit;
  If SwitchHasPattern(N) Then Begin
    If IsPrim(ST) Then Begin
      Err(Nodes[N].Line, 'selecteur de switch invalide pour un motif : ' + TypeStr(ST));
      AttribSwitchSel := TY_NONE;
    End;
    Mode := SW_PATTERN;
    Nodes[N].E := Mode;
    Exit;
  End;
  If ST = T_STRING Then Mode := SW_STR
  Else If IsClassT(ST) And ((Classes[Types[ST].Cls].Flags And ACC_ENUM) <> 0) Then Mode := SW_ENUM
  Else Begin
    U := NumTypeOf(ST);
    If U In [TY_BYTE, TY_SHORT, TY_CHAR, TY_INT] Then Begin
      If Not IsPrim(ST) Then Begin PromoteTo(Sel, U); ST := U; AttribSwitchSel := U; End;
    End
    Else Begin
      Err(Nodes[N].Line, 'selecteur de switch invalide : ' + TypeStr(ST));
      AttribSwitchSel := TY_NONE;
    End;
  End;
  Nodes[N].E := Mode;
End;

Procedure AttribCaseLabels(Cs : LongInt; ST, Mode : LongInt);
Var Lb, F, Owner, T, Pv : LongInt; Dupe : Boolean;
Begin
  Lb := Nodes[Cs].A;
  While Lb <> 0 Do Begin
    Case Mode Of
      SW_PATTERN : Begin
        If Nodes[Lb].Kind = N_PATTERN Then AttribPattern(Lb, ST)
        Else If (Nodes[Lb].Kind = N_NAME) And IsClassT(ST) And ((Classes[Types[ST].Cls].Flags And ACC_ENUM) <> 0) Then Begin
          F := FieldInHierarchy(Types[ST].Cls, Nodes[Lb].S, Owner);
          If F < 0 Then Err(Nodes[Lb].Line, 'constante enum introuvable : ' + Nodes[Lb].S)
          Else Begin Nodes[Lb].Sym := F; Nodes[Lb].Aux := 99; Nodes[Lb].Typ := ST; Nodes[Lb].Att := 1; End;
        End
        Else Begin
          T := AttribExpr(Lb, ST);
          If (Nodes[Lb].Kind = N_SELECT) And (Nodes[Lb].Aux = 2) And ((Fields[Nodes[Lb].Sym].Flags And ACC_ENUM) <> 0) Then Nodes[Lb].Aux := 98
          Else If (Nodes[Lb].Kind = N_LIT) And (Nodes[Lb].Aux = LIT_NULL) Then
          Else If Nodes[Lb].CK <> CK_STR Then Err(Nodes[Lb].Line, 'libelle de case non supporte dans un switch a motifs');
        End;
      End;
      SW_ENUM : Begin
        F := -1;
        If Nodes[Lb].Kind = N_NAME Then Begin
          F := FieldInHierarchy(Types[ST].Cls, Nodes[Lb].S, Owner);
          If F < 0 Then Err(Nodes[Lb].Line, 'constante enum introuvable : ' + Nodes[Lb].S)
          Else Begin Nodes[Lb].Sym := F; Nodes[Lb].Aux := 99; Nodes[Lb].Typ := ST; Nodes[Lb].Att := 1; End;
        End
        Else Begin
          T := AttribExpr(Lb, ST);
          If (Nodes[Lb].Kind = N_SELECT) And (Nodes[Lb].Aux = 2) Then Begin
            Nodes[Lb].Aux := 98; F := Nodes[Lb].Sym;
          End
          Else Err(Nodes[Lb].Line, 'constante enum attendue');
        End;
      End;
      SW_STR : Begin
        AttribExpr(Lb, T_STRING);
        If (Nodes[Lb].Typ <> TY_NONE) And (Nodes[Lb].CK <> CK_STR) Then
          Err(Nodes[Lb].Line, 'expression constante de type String requise');
      End;
    Else
      T := AttribExpr(Lb, ST);
      If T <> TY_NONE Then Begin
        If (Nodes[Lb].CK <> CK_INT) Then Err(Nodes[Lb].Line, 'expression constante requise')
        Else If Not (PrimWidens(T, TY_INT)) Then Err(Nodes[Lb].Line, 'types incompatibles dans le libelle de case')
        Else If (ST In [TY_BYTE, TY_SHORT, TY_CHAR]) And Not ConstFits(Nodes[Lb].CI, ST) And (ST <> TY_BYTE) Then
          Err(Nodes[Lb].Line, 'types incompatibles : conversion avec perte possible de int en ' + TypeStr(ST))
        Else If (ST = TY_BYTE) And ((Nodes[Lb].CI < -128) Or (Nodes[Lb].CI > 127)) Then
          Err(Nodes[Lb].Line, 'types incompatibles : conversion avec perte possible de int en byte');
      End;
    End;
    { doublons }
    Pv := Nodes[Cs].A;
    If Mode = SW_PATTERN Then Pv := Lb;
    While Pv <> Lb Do Begin
      Dupe := False;
      Case Mode Of
        SW_ENUM : Dupe := (Nodes[Pv].Sym = Nodes[Lb].Sym) And (Nodes[Lb].Sym > 0);
        SW_STR : Dupe := (Nodes[Pv].CK = CK_STR) And (Nodes[Pv].CS = Nodes[Lb].CS) And (Nodes[Lb].CK = CK_STR);
      Else
        Dupe := (Nodes[Pv].CK = CK_INT) And (Nodes[Lb].CK = CK_INT) And (Nodes[Pv].CI = Nodes[Lb].CI);
      End;
      If Dupe Then Err(Nodes[Lb].Line, 'libelle de case en double');
      Pv := Nodes[Pv].Next;
    End;
    Lb := Nodes[Lb].Next;
  End;
End;

Procedure CheckDuplicateLabels(N : LongInt; Mode : LongInt);
Var C1, C2, L1, L2 : LongInt; Dupe : Boolean;
Begin
  If Mode = SW_PATTERN Then Exit;
  C1 := Nodes[N].B;
  While C1 <> 0 Do Begin
    C2 := Nodes[C1].Next;
    While C2 <> 0 Do Begin
      L1 := Nodes[C1].A;
      While L1 <> 0 Do Begin
        L2 := Nodes[C2].A;
        While L2 <> 0 Do Begin
          Dupe := False;
          Case Mode Of
            SW_ENUM : Dupe := (Nodes[L1].Sym = Nodes[L2].Sym) And (Nodes[L1].Sym > 0);
            SW_STR : Dupe := (Nodes[L1].CK = CK_STR) And (Nodes[L2].CK = CK_STR) And (Nodes[L1].CS = Nodes[L2].CS);
          Else
            Dupe := (Nodes[L1].CK = CK_INT) And (Nodes[L2].CK = CK_INT) And (Nodes[L1].CI = Nodes[L2].CI);
          End;
          If Dupe Then Err(Nodes[L2].Line, 'libelle de case en double');
          L2 := Nodes[L2].Next;
        End;
        L1 := Nodes[L1].Next;
      End;
      If ((Nodes[C1].Aux And 1) <> 0) And ((Nodes[C2].Aux And 1) <> 0) Then Err(Nodes[C2].Line, 'libelle default en double');
      C2 := Nodes[C2].Next;
    End;
    C1 := Nodes[C1].Next;
  End;
End;

{ ----- exhaustivite des switch (JLS 14.11.1.1) ---------------------------------------------- }

Type
  TRow  = Array Of LongInt;
  TRows = Array Of TRow;
  TTyArr = Array Of LongInt;

Const
  PAT_ANY = 0;

{ Decompose un type en "feuilles" : sous-types permis d'une classe scellee abstraite, constantes d'enum }
Procedure DecomposeLeaves(T : LongInt; Var LT, LE : TTyArr; Depth : LongInt);
Var C, F, I, N : LongInt;
  Procedure Add(Ty, Ef : LongInt);
  Begin
    N := Length(LT);
    SetLength(LT, N + 1); SetLength(LE, N + 1);
    LT[N] := Ty; LE[N] := Ef;
  End;
Begin
  If IsTVarT(T) Then T := Erasure(T);
  If (Not IsClassT(T)) Or (Depth > 24) Then Begin Add(T, -1); Exit; End;
  C := Types[T].Cls;
  EnsureHeader(C);
  If (Classes[C].Flags And ACC_ENUM) <> 0 Then Begin
    EnsureMembers(C);
    F := Classes[C].FirstField;
    N := 0;
    While F >= 0 Do Begin
      If (Fields[F].Flags And ACC_ENUM) <> 0 Then Begin Add(T, F); Inc(N); End;
      F := Fields[F].Next;
    End;
    If N = 0 Then Add(T, -1);
    Exit;
  End;
  If IsSealedC(C) Then Begin
    ComputePermits(C);
    If (Classes[C].Flags And (ACC_ABSTRACT Or ACC_INTERFACE)) = 0 Then Add(T, -1);
    For I := 0 To Length(Classes[C].Permits) - 1 Do
      If Classes[C].Permits[I] >= 0 Then
        If IsCastable(T, ClassT(Classes[C].Permits[I])) Then
          DecomposeLeaves(ClassT(Classes[C].Permits[I]), LT, LE, Depth + 1);
    Exit;
  End;
  Add(T, -1);
End;

Function LeafSubtype(X, PT : LongInt) : Boolean;
Begin
  If IsPrim(X) Or IsPrim(PT) Then LeafSubtype := X = PT
  Else If (X = TY_NONE) Or (PT = TY_NONE) Then LeafSubtype := True
  Else LeafSubtype := IsSubtypeRef(Erasure(X), Erasure(PT));
End;

Function PatMatches(P, X, EF : LongInt) : Boolean;
Begin
  PatMatches := False;
  If P = PAT_ANY Then Begin PatMatches := True; Exit; End;
  If Nodes[P].Kind = N_PATTERN Then Begin
    If Nodes[P].Aux = 1 Then Begin
      PatMatches := IsClassT(X) And (Nodes[P].E = Types[X].Cls);
    End
    Else PatMatches := LeafSubtype(X, Nodes[P].Typ);
    Exit;
  End;
  { constante d'enum }
  If (EF >= 0) And ((Nodes[P].Aux = 98) Or (Nodes[P].Aux = 99)) Then PatMatches := Nodes[P].Sym = EF;
End;

Function ExhaustRows(Const Tys : TTyArr; Const Rows : TRows; Depth : LongInt) : Boolean;
Var
  LT, LE : TTyArr; NewRows : TRows; NewTys : TTyArr; I, J, K, M, Cl, F, Sub, Pm, NR : LongInt;
  IsRec : Boolean; R, NRw : TRow; Ct : LongInt;
Begin
  ExhaustRows := True;
  If Length(Tys) = 0 Then Begin ExhaustRows := Length(Rows) > 0; Exit; End;
  If Depth > 12 Then Exit;
  SetLength(LT, 0); SetLength(LE, 0);
  DecomposeLeaves(Tys[0], LT, LE, 0);
  For I := 0 To Length(LT) - 1 Do Begin
    IsRec := False; Cl := -1;
    If IsClassT(LT[I]) Then Begin
      Cl := Types[LT[I]].Cls;
      IsRec := Classes[Cl].IsSrc And (Nodes[Classes[Cl].Decl].Aux = CLS_RECORD);
    End;
    M := 0;
    If IsRec Then Begin EnsureMembers(Cl); M := ChainLen(Nodes[Classes[Cl].Decl].E); End;
    SetLength(NewRows, 0);
    NR := 0;
    For J := 0 To Length(Rows) - 1 Do Begin
      R := Rows[J];
      If Not PatMatches(R[0], LT[I], LE[I]) Then Continue;
      SetLength(NRw, 0);
      If IsRec Then Begin
        SetLength(NRw, M + Length(R) - 1);
        Sub := 0;
        If (R[0] <> PAT_ANY) And (Nodes[R[0]].Kind = N_PATTERN) And (Nodes[R[0]].Aux = 1) Then Sub := Nodes[R[0]].B;
        For K := 0 To M - 1 Do Begin
          If Sub <> 0 Then Begin NRw[K] := Sub; Sub := Nodes[Sub].Next; End
          Else NRw[K] := PAT_ANY;
        End;
        For K := 1 To Length(R) - 1 Do NRw[M + K - 1] := R[K];
      End
      Else Begin
        SetLength(NRw, Length(R) - 1);
        For K := 1 To Length(R) - 1 Do NRw[K - 1] := R[K];
      End;
      SetLength(NewRows, NR + 1);
      NewRows[NR] := NRw;
      Inc(NR);
    End;
    SetLength(NewTys, 0);
    If IsRec Then Begin
      SetLength(NewTys, M + Length(Tys) - 1);
      Pm := Nodes[Classes[Cl].Decl].E;
      For K := 0 To M - 1 Do Begin
        F := FindFieldIn(Cl, Nodes[Pm].S);
        If F >= 0 Then Ct := MemberType(LT[I], Cl, Fields[F].Typ) Else Ct := TY_NONE;
        NewTys[K] := Ct;
        Pm := Nodes[Pm].Next;
      End;
      For K := 1 To Length(Tys) - 1 Do NewTys[M + K - 1] := Tys[K];
    End
    Else Begin
      SetLength(NewTys, Length(Tys) - 1);
      For K := 1 To Length(Tys) - 1 Do NewTys[K - 1] := Tys[K];
    End;
    If Not ExhaustRows(NewTys, NewRows, Depth + 1) Then Begin ExhaustRows := False; Exit; End;
  End;
End;

{ Le switch N (selecteur de type ST) couvre-t-il toutes les valeurs ? Verifie aussi la dominance des motifs. }
Procedure CheckSwitchCoverage(N, ST, Mode : LongInt);
Var
  Cs, Lb, Q, Pr, NR : LongInt; Rows : TRows; Tys : TTyArr; HasDefault, IsExpr, Need, Guarded : Boolean;
  Seen : Array Of LongInt; NSeen, I : LongInt;
Begin
  If (ST = TY_NONE) Or (ST = T_ANY) Then Exit;
  IsExpr := Nodes[N].Kind = N_SWITCHEXPR;
  HasDefault := False;
  NR := 0; NSeen := 0;
  SetLength(Rows, 0);
  Cs := Nodes[N].B;
  While Cs <> 0 Do Begin
    Guarded := False;
    If Nodes[Cs].E <> 0 Then
      Guarded := Not ((Nodes[Nodes[Cs].E].CK = CK_INT) And (Nodes[Nodes[Cs].E].CI = 1));
    If (Nodes[Cs].Aux And 1) <> 0 Then HasDefault := True;
    Lb := Nodes[Cs].A;
    While Lb <> 0 Do Begin
      If Nodes[Lb].Kind = N_PATTERN Then Begin
        { dominance par un motif de type inconditionnel precedent }
        If Mode = SW_PATTERN Then
          For I := 0 To NSeen - 1 Do
            If LeafSubtype(Nodes[Lb].Typ, Nodes[Seen[I]].Typ) Then Begin
              Err(Nodes[Lb].Line, 'ce libelle case est domine par un libelle precedent');
              Break;
            End;
        If Not Guarded Then Begin
          SetLength(Rows, NR + 1);
          SetLength(Rows[NR], 1);
          Rows[NR][0] := Lb;
          Inc(NR);
          If Nodes[Lb].Aux = 0 Then Begin
            SetLength(Seen, NSeen + 1); Seen[NSeen] := Lb; Inc(NSeen);
            { motif inconditionnel : couvre tout }
            If LeafSubtype(ST, Nodes[Lb].Typ) Then Begin
              If HasDefault Then Err(Nodes[Lb].Line, 'le switch a a la fois un motif inconditionnel et un libelle default');
              HasDefault := True;
            End;
          End;
        End;
      End
      Else If (Nodes[Lb].Aux = 98) Or (Nodes[Lb].Aux = 99) Then Begin
        If Not Guarded Then Begin
          SetLength(Rows, NR + 1);
          SetLength(Rows[NR], 1);
          Rows[NR][0] := Lb;
          Inc(NR);
        End;
      End;
      Lb := Nodes[Lb].Next;
    End;
    Cs := Nodes[Cs].Next;
  End;
  Need := IsExpr Or (Mode = SW_PATTERN);
  If (Not Need) Or HasDefault Then Exit;
  If (Mode = SW_INT) Or (Mode = SW_STR) Then Begin
    Err(Nodes[N].Line, 'le switch ne couvre pas toutes les valeurs d''entree possibles');
    Exit;
  End;
  SetLength(Tys, 1);
  Tys[0] := ST;
  If Not ExhaustRows(Tys, Rows, 0) Then Begin
    If IsExpr Then Err(Nodes[N].Line, 'l''expression switch ne couvre pas toutes les valeurs d''entree possibles')
    Else Err(Nodes[N].Line, 'l''instruction switch ne couvre pas toutes les valeurs d''entree possibles');
  End;
  Pr := 0; Q := 0;
End;

Procedure AttribSwitchBody(N : LongInt; ST, Mode : LongInt);
Var Cs, S, Mark, CaseMark : LongInt;
Begin
  Mark := NScope;
  Inc(SwitchDepth);
  Cs := Nodes[N].B;
  While Cs <> 0 Do Begin
    CaseMark := NScope;
    AttribCaseLabels(Cs, ST, Mode);
    If Nodes[Cs].E <> 0 Then AttribCondition(Nodes[Cs].E);
    If (Nodes[Cs].Aux And 2) <> 0 Then Begin
      Mark := NScope;
      AttribStmt(Nodes[Cs].B);
      NScope := Mark;
    End
    Else Begin
      S := Nodes[Cs].B;
      While S <> 0 Do Begin AttribStmt(S); S := Nodes[S].Next; End;
    End;
    If Mode = SW_PATTERN Then NScope := CaseMark;
    Cs := Nodes[Cs].Next;
  End;
  CheckDuplicateLabels(N, Mode);
  CheckSwitchCoverage(N, ST, Mode);
  Dec(SwitchDepth);
  NScope := Mark;
End;

Procedure AttribSwitchStmt(N : LongInt);
Var ST, Mode, Mark : LongInt;
Begin
  Mark := NScope;
  ST := AttribSwitchSel(N, Mode);
  If ST <> TY_NONE Then AttribSwitchBody(N, ST, Mode)
  Else Begin
    { attribue quand meme }
    Inc(SwitchDepth);
    AttribStmt(Nodes[Nodes[N].B].B);
    Dec(SwitchDepth);
  End;
  NScope := Mark;
End;

Function AttribSwitchExpr(N, Expected : LongInt) : LongInt;
Var
  ST, Mode, Base, I, RT, T, PT, Y, K : LongInt; AllNum, AllBool, Same : Boolean; P : LongInt;
Begin
  ST := AttribSwitchSel(N, Mode);
  Base := NYields;
  AttribSwitchExpr := TY_NONE;
  Nodes[N].Typ := TY_NONE;
  If ST = TY_NONE Then Begin NYields := Base; Exit; End;
  AttribSwitchBody(N, ST, Mode);
  If NYields = Base Then Begin
    Err(Nodes[N].Line, 'l''expression switch ne contient aucune valeur de resultat');
    Exit;
  End;
  { type du resultat }
  RT := TY_NONE;
  If (Expected > 0) And (Expected <> TY_NONE) And Not IsTVarT(Expected) And (Expected <> T_OBJECT) Then RT := Expected
  Else Begin
    AllNum := True; AllBool := True; Same := True;
    T := Nodes[Nodes[YieldNodes[Base]].A].Typ;
    For I := Base To NYields - 1 Do Begin
      PT := Nodes[Nodes[YieldNodes[I]].A].Typ;
      If PT <> T Then Same := False;
      If Not (NumTypeOf(PT) In [TY_BYTE, TY_SHORT, TY_CHAR, TY_INT, TY_LONG, TY_FLOAT, TY_DOUBLE]) Then AllNum := False;
      If NumTypeOf(PT) <> TY_BOOLEAN Then AllBool := False;
    End;
    If Same Then RT := T
    Else If AllBool Then RT := TY_BOOLEAN
    Else If AllNum Then Begin
      RT := NumTypeOf(T);
      For I := Base To NYields - 1 Do RT := BinaryPromote(RT, NumTypeOf(Nodes[Nodes[YieldNodes[I]].A].Typ));
    End
    Else Begin
      RT := BoxedType(T);
      For I := Base To NYields - 1 Do RT := LubType(RT, BoxedType(Nodes[Nodes[YieldNodes[I]].A].Typ));
    End;
  End;
  For I := Base To NYields - 1 Do Begin
    Y := Nodes[YieldNodes[I]].A;
    Coerce(Y, RT, CV_ASSIGN);
  End;
  NYields := Base;
  Nodes[N].Typ := RT;
  AttribSwitchExpr := RT;
  P := 0; K := 0;
End;

{ ============================================================================
  4b. ANNOTATIONS : meta-annotations (retention, cibles, conteneur) et analyse
  ============================================================================ }

Const
  RET_SOURCE  = 0;
  RET_CLASS   = 1;
  RET_RUNTIME = 2;

  TGT_TYPE        = 1;
  TGT_FIELD       = 2;
  TGT_METHOD      = 4;
  TGT_PARAMETER   = 8;
  TGT_CONSTRUCTOR = 16;
  TGT_LOCAL       = 32;
  TGT_ANNOT       = 64;
  TGT_PACKAGE     = 128;
  TGT_TPARAM      = 256;
  TGT_TYPEUSE     = 512;
  TGT_MODULE      = 1024;
  TGT_RECCOMP     = 2048;
  TGT_DECL        = $FFF - 512;     { tous les contextes de declaration }

Type
  TAnnMetaRec = Record
    Done : Boolean;
    Ret  : Byte;
    Tgt  : LongInt;
    Cont : LongInt;       { classe conteneur d'une annotation repetable, ou -1 }
  End;

Var
  ModDecl : LongInt;      { noeud N_MODULE de module-info.java, ou 0 }
  ModCU   : LongInt;
  ClsParentCtx : LongInt;
  AnnMetas : Array Of TAnnMetaRec;
  ExtAB    : TBuf;
  ExtACp   : Array Of String;

Function TargetBit(Const S : String) : LongInt;
Begin
  If S = 'TYPE' Then TargetBit := TGT_TYPE
  Else If S = 'FIELD' Then TargetBit := TGT_FIELD
  Else If S = 'METHOD' Then TargetBit := TGT_METHOD
  Else If S = 'PARAMETER' Then TargetBit := TGT_PARAMETER
  Else If S = 'CONSTRUCTOR' Then TargetBit := TGT_CONSTRUCTOR
  Else If S = 'LOCAL_VARIABLE' Then TargetBit := TGT_LOCAL
  Else If S = 'ANNOTATION_TYPE' Then TargetBit := TGT_ANNOT
  Else If S = 'PACKAGE' Then TargetBit := TGT_PACKAGE
  Else If S = 'TYPE_PARAMETER' Then TargetBit := TGT_TPARAM
  Else If S = 'TYPE_USE' Then TargetBit := TGT_TYPEUSE
  Else If S = 'MODULE' Then TargetBit := TGT_MODULE
  Else If S = 'RECORD_COMPONENT' Then TargetBit := TGT_RECCOMP
  Else TargetBit := 0;
End;

Function RetentionOf(Const S : String) : Byte;
Begin
  If S = 'SOURCE' Then RetentionOf := RET_SOURCE
  Else If S = 'RUNTIME' Then RetentionOf := RET_RUNTIME
  Else RetentionOf := RET_CLASS;
End;

Function LastComp(Const S : String) : String;
Var K : LongInt;
Begin
  K := LastPos('.', S);
  LastComp := Copy(S, K + 1, Length(S));
End;

{ ----- lecture des meta-annotations d'une classe externe (.class) ------------------------ }

Function ExtUtf(Idx : LongInt) : String;
Begin
  If (Idx <= 0) Or (Idx >= Length(ExtACp)) Then ExtUtf := '' Else ExtUtf := ExtACp[Idx];
End;

Procedure ExtReadAnn(Var Q : LongInt; Var Names : String); Forward;

{ saute une valeur d'element en accumulant les noms d'enumeration / descripteurs de classe }
Procedure ExtReadEV(Var Q : LongInt; Var Names : String);
Var Tag, N, I : LongInt;
Begin
  Tag := RdU1(ExtAB, Q);
  Inc(Q);
  Case Chr(Tag) Of
    'e' : Begin
      Names := Names + ExtUtf(RdU2(ExtAB, Q + 2)) + ',';
      Inc(Q, 4);
    End;
    'c' : Begin
      Names := Names + ExtUtf(RdU2(ExtAB, Q)) + ',';
      Inc(Q, 2);
    End;
    '@' : ExtReadAnn(Q, Names);
    '[' : Begin
      N := RdU2(ExtAB, Q);
      Inc(Q, 2);
      For I := 1 To N Do ExtReadEV(Q, Names);
    End;
  Else
    Inc(Q, 2);
  End;
End;

Procedure ExtReadAnn(Var Q : LongInt; Var Names : String);
Var NP, I : LongInt;
Begin
  Inc(Q, 2);
  NP := RdU2(ExtAB, Q);
  Inc(Q, 2);
  For I := 1 To NP Do Begin
    Inc(Q, 2);
    ExtReadEV(Q, Names);
  End;
End;

Procedure ReadExtAnnMeta(C : LongInt; Var R : TAnnMetaRec);
Var
  Cnt, I, P, Tag, K, Q, NA, J, NF, AL, AP, NAnn : LongInt; AName, TypeD, Names, Part : String;
  Sp : LongInt;
Begin
  If Not ExtGetBytes(Classes[C].Name, ExtAB) Then Exit;
  Cnt := RdU2(ExtAB, 8);
  SetLength(ExtACp, 0);
  SetLength(ExtACp, Cnt);
  P := 10;
  I := 1;
  While I < Cnt Do Begin
    Tag := RdU1(ExtAB, P);
    Case Tag Of
      1 : Begin K := RdU2(ExtAB, P + 1); ExtACp[I] := BytesToStr(ExtAB, P + 3, K); Inc(P, 3 + K); End;
      3, 4 : Inc(P, 5);
      5, 6 : Begin Inc(P, 9); Inc(I); End;
      7, 8, 16, 19, 20 : Inc(P, 3);
      15 : Inc(P, 4);
    Else
      Inc(P, 5);
    End;
    Inc(I);
  End;
  Inc(P, 6);
  K := RdU2(ExtAB, P);
  Inc(P, 2 + 2 * K);
  Q := P;
  For I := 1 To 2 Do Begin
    NF := RdU2(ExtAB, Q);
    Inc(Q, 2);
    For J := 1 To NF Do Begin
      NA := RdU2(ExtAB, Q + 6);
      Inc(Q, 8);
      While NA > 0 Do Begin Inc(Q, 6 + RdU4(ExtAB, Q + 2)); Dec(NA); End;
    End;
  End;
  NA := RdU2(ExtAB, Q);
  Inc(Q, 2);
  While NA > 0 Do Begin
    AName := ExtUtf(RdU2(ExtAB, Q));
    AL := RdU4(ExtAB, Q + 2);
    AP := Q + 6;
    If AName = 'RuntimeVisibleAnnotations' Then Begin
      NAnn := RdU2(ExtAB, AP);
      Inc(AP, 2);
      For I := 1 To NAnn Do Begin
        TypeD := ExtUtf(RdU2(ExtAB, AP));
        Names := '';
        ExtReadAnn(AP, Names);
        If TypeD = 'Ljava/lang/annotation/Retention;' Then Begin
          Sp := Pos(',', Names);
          If Sp > 0 Then R.Ret := RetentionOf(Copy(Names, 1, Sp - 1));
        End
        Else If TypeD = 'Ljava/lang/annotation/Target;' Then Begin
          R.Tgt := 0;
          While Names <> '' Do Begin
            Sp := Pos(',', Names);
            Part := Copy(Names, 1, Sp - 1);
            Delete(Names, 1, Sp);
            R.Tgt := R.Tgt Or TargetBit(Part);
          End;
        End
        Else If TypeD = 'Ljava/lang/annotation/Repeatable;' Then Begin
          Sp := Pos(',', Names);
          If Sp > 2 Then R.Cont := GetClass(Copy(Names, 2, Sp - 3));
        End;
      End;
    End;
    Inc(Q, 6 + AL);
    Dec(NA);
  End;
End;

{ Version d'un module du JDK (attribut Module de son module-info.class), ou '' }
Function JdkModuleVersion(Const Nm : String) : String;
Var
  A, Bz, C, Cnt, I, P, Tag, K, Q, NA, AL : LongInt; AName : String;
Begin
  JdkModuleVersion := '';
  JdkOpen;
  If Not JdkReady Then Exit;
  If Not JdkLocate('/' + Nm + '/module-info.class', A, Bz, C) Then Exit;
  If C <> 0 Then Exit;
  If Not ReadFileRange(JdkImage, A, Bz, ExtAB) Then Exit;
  Cnt := RdU2(ExtAB, 8);
  SetLength(ExtACp, 0);
  SetLength(ExtACp, Cnt);
  P := 10;
  I := 1;
  While I < Cnt Do Begin
    Tag := RdU1(ExtAB, P);
    Case Tag Of
      1 : Begin K := RdU2(ExtAB, P + 1); ExtACp[I] := BytesToStr(ExtAB, P + 3, K); Inc(P, 3 + K); End;
      3, 4 : Inc(P, 5);
      5, 6 : Begin Inc(P, 9); Inc(I); End;
      7, 8, 16, 19, 20 : Inc(P, 3);
      15 : Inc(P, 4);
    Else
      Inc(P, 5);
    End;
    Inc(I);
  End;
  Inc(P, 6);
  K := RdU2(ExtAB, P);
  Inc(P, 2 + 2 * K);
  Q := P;
  For I := 1 To 2 Do Begin
    K := RdU2(ExtAB, Q);
    Inc(Q, 2);
    While K > 0 Do Begin
      NA := RdU2(ExtAB, Q + 6);
      Inc(Q, 8);
      While NA > 0 Do Begin Inc(Q, 6 + RdU4(ExtAB, Q + 2)); Dec(NA); End;
      Dec(K);
    End;
  End;
  NA := RdU2(ExtAB, Q);
  Inc(Q, 2);
  While NA > 0 Do Begin
    AName := ExtUtf(RdU2(ExtAB, Q));
    AL := RdU4(ExtAB, Q + 2);
    If AName = 'Module' Then Begin
      K := RdU2(ExtAB, Q + 6 + 4);
      If K > 0 Then JdkModuleVersion := ExtUtf(K);
      Exit;
    End;
    Inc(Q, 6 + AL);
    Dec(NA);
  End;
End;

{ ----- lecture des meta-annotations d'une classe source ------------------------------------ }

Procedure ReadSrcAnnMeta(C : LongInt; Var R : TAnnMetaRec);
Var A, V, Ch : LongInt; Nm : String; S : TSavedCtx;
Begin
  A := Nodes[Classes[C].Decl].Ann;
  While A <> 0 Do Begin
    Nm := LastComp(Nodes[A].S);
    If Nodes[A].A <> 0 Then V := Nodes[Nodes[A].A].A Else V := 0;
    If V <> 0 Then Begin
      If Nm = 'Retention' Then R.Ret := RetentionOf(Nodes[V].S)
      Else If Nm = 'Target' Then Begin
        R.Tgt := 0;
        If Nodes[V].Kind = N_ARRAYINIT Then Begin
          Ch := Nodes[V].A;
          While Ch <> 0 Do Begin R.Tgt := R.Tgt Or TargetBit(Nodes[Ch].S); Ch := Nodes[Ch].Next; End;
        End
        Else R.Tgt := TargetBit(Nodes[V].S);
      End
      Else If (Nm = 'Repeatable') And (Nodes[V].Kind = N_CLASSLIT) Then Begin
        IsolateEnter(C, S);
        AttribClassLit(V);
        IsolateLeave(S);
        If IsClassT(Nodes[V].E) Then R.Cont := ClsOf(Nodes[V].E);
      End;
    End;
    A := Nodes[A].Next;
  End;
End;

Function AnnMeta(C : LongInt) : TAnnMetaRec;
Var R : TAnnMetaRec; Nm : String;
Begin
  If C >= Length(AnnMetas) Then SetLength(AnnMetas, NClasses + 64);
  If AnnMetas[C].Done Then Begin AnnMeta := AnnMetas[C]; Exit; End;
  R.Done := True; R.Ret := RET_CLASS; R.Tgt := TGT_DECL; R.Cont := -1;
  Nm := Classes[C].Name;
  If Classes[C].IsSrc Then ReadSrcAnnMeta(C, R)
  Else If Nm = 'java/lang/Override' Then Begin R.Ret := RET_SOURCE; R.Tgt := TGT_METHOD; End
  Else If Nm = 'java/lang/SuppressWarnings' Then Begin
    R.Ret := RET_SOURCE; R.Tgt := TGT_TYPE Or TGT_FIELD Or TGT_METHOD Or TGT_PARAMETER Or TGT_CONSTRUCTOR Or TGT_LOCAL Or TGT_MODULE;
  End
  Else If Nm = 'java/lang/FunctionalInterface' Then Begin R.Ret := RET_RUNTIME; R.Tgt := TGT_TYPE; End
  Else If Nm = 'java/lang/SafeVarargs' Then Begin R.Ret := RET_RUNTIME; R.Tgt := TGT_CONSTRUCTOR Or TGT_METHOD; End
  Else If Nm = 'java/lang/Deprecated' Then Begin
    R.Ret := RET_RUNTIME;
    R.Tgt := TGT_CONSTRUCTOR Or TGT_FIELD Or TGT_LOCAL Or TGT_METHOD Or TGT_PACKAGE Or TGT_MODULE Or TGT_PARAMETER Or TGT_TYPE;
  End
  Else If Copy(Nm, 1, 21) = 'java/lang/annotation/' Then Begin
    R.Ret := RET_RUNTIME; R.Tgt := TGT_ANNOT;
    If Nm = 'java/lang/annotation/Native' Then Begin R.Ret := RET_SOURCE; R.Tgt := TGT_FIELD; End;
  End
  Else ReadExtAnnMeta(C, R);
  AnnMetas[C] := R;
  AnnMeta := R;
End;

{ ----- analyse semantique ---------------------------------------------------------------- }

Procedure AttribAnnot(A, Target : LongInt); Forward;

Procedure AttribElemValue(N, T : LongInt);
Var E, Ch, F, Cl : LongInt; Ok : Boolean;
Begin
  If (N = 0) Or (T = TY_NONE) Then Exit;
  If IsArrayT(T) Then Begin
    E := ElemOf(T);
    If Nodes[N].Kind = N_ARRAYINIT Then Begin
      Ch := Nodes[N].A;
      While Ch <> 0 Do Begin AttribElemValue(Ch, E); Ch := Nodes[Ch].Next; End;
    End
    Else AttribElemValue(N, E);
    Exit;
  End;
  If Nodes[N].Kind = N_ARRAYINIT Then Begin
    Err(Nodes[N].Line, 'initialiseur de tableau inattendu pour un element d''annotation de type ' + TypeStr(T));
    Exit;
  End;
  If IsClassT(T) Then Cl := ClsOf(T) Else Cl := -1;
  If Cl >= 0 Then EnsureHeader(Cl);
  { annotation imbriquee }
  If (Cl >= 0) And ((Classes[Cl].Flags And ACC_ANNOTATION) <> 0) Then Begin
    If Nodes[N].Kind <> N_ANNOT Then Err(Nodes[N].Line, 'une annotation est attendue ici')
    Else Begin
      AttribAnnot(N, 0);
      If (Nodes[N].Sym >= 0) And (Nodes[N].Sym <> Cl) Then
        Err(Nodes[N].Line, 'types incompatibles : @' + Classes[Nodes[N].Sym].Simple + ' ne peut pas etre converti en ' + TypeStr(T));
    End;
    Exit;
  End;
  If Nodes[N].Kind = N_ANNOT Then Begin
    Err(Nodes[N].Line, 'annotation inattendue pour un element de type ' + TypeStr(T));
    Exit;
  End;
  { constante d'enumeration }
  If (Cl >= 0) And ((Classes[Cl].Flags And ACC_ENUM) <> 0) Then Begin
    EnsureMembers(Cl);
    F := -1;
    If Nodes[N].Kind = N_NAME Then Begin
      F := FindFieldIn(Cl, Nodes[N].S);
      If (F >= 0) And ((Fields[F].Flags And ACC_ENUM) = 0) Then F := -1;
    End;
    If F < 0 Then Begin
      AttribExpr(N, T);
      Ok := (Nodes[N].Kind In [N_NAME, N_SELECT]) And (Nodes[N].Aux <> 1) And (Nodes[N].Sym >= 0) And (Nodes[N].Sym < NFields);
      If Ok Then Begin
        F := Nodes[N].Sym;
        If ((Fields[F].Flags And ACC_ENUM) = 0) Or (Fields[F].Owner <> Cl) Then F := -1;
      End;
      If F < 0 Then Begin
        If Nodes[N].Typ <> TY_NONE Then Err(Nodes[N].Line, 'une constante d''enumeration est attendue ici');
        Exit;
      End;
    End;
    Nodes[N].Dflt := F + 1;
    Exit;
  End;
  { litteral de classe }
  If (Cl = C_CLASS) Then Begin
    If Nodes[N].Kind <> N_CLASSLIT Then Err(Nodes[N].Line, 'un litteral de classe est attendu ici')
    Else AttribExpr(N, TY_NONE);
    Exit;
  End;
  { constante primitive ou chaine }
  AttribExpr(N, T);
  If Nodes[N].Typ = TY_NONE Then Exit;
  If Not (IsPrim(T) Or (T = T_STRING)) Then Begin
    Err(Nodes[N].Line, 'type d''element d''annotation invalide : ' + TypeStr(T));
    Exit;
  End;
  Coerce(N, T, CV_ASSIGN);
  If Nodes[N].Typ = TY_NONE Then Exit;
  If Nodes[N].CK = CK_NONE Then
    Err(Nodes[N].Line, 'la valeur d''un element d''annotation doit etre une expression constante');
End;

Procedure AttribAnnot(A, Target : LongInt);
Var Tn, T, C, G, G2, M : LongInt; Meta : TAnnMetaRec; Found : Boolean;
Begin
  If Nodes[A].Aux = 1 Then Exit;       { deja analysee (partagee entre composant, champ, ...) }
  Nodes[A].Aux := 1;
  Nodes[A].Sym := -1;
  Tn := NewNode(N_TYPE, Nodes[A].Line);
  Nodes[Tn].S := Nodes[A].S;
  T := ResolveType(Tn);
  If (T <= 0) Or Not IsClassT(T) Then Exit;
  C := ClsOf(T);
  EnsureHeader(C);
  If (Classes[C].Flags And ACC_ANNOTATION) = 0 Then Begin
    Err(Nodes[A].Line, Classes[C].Simple + ' n''est pas un type d''annotation');
    Exit;
  End;
  Nodes[A].Sym := C;
  EnsureMembers(C);
  Meta := AnnMeta(C);
  If (Target <> 0) And ((Meta.Tgt And Target) = 0) And ((Meta.Tgt And TGT_TYPEUSE) = 0) Then
    Err(Nodes[A].Line, 'le type d''annotation @' + Classes[C].Simple + ' n''est pas applicable a ce type de declaration');
  G := Nodes[A].A;
  While G <> 0 Do Begin
    Nodes[G].Sym := -1;
    M := Classes[C].FirstMeth;
    While M >= 0 Do Begin
      If (Meths[M].Name = Nodes[G].S) And (Meths[M].NPar = 0) And ((Meths[M].Flags And ACC_STATIC) = 0) Then Break;
      M := Meths[M].Next;
    End;
    If M < 0 Then
      Err(Nodes[G].Line, 'symbole introuvable : methode ' + Nodes[G].S + '() dans @' + Classes[C].Simple)
    Else Begin
      Nodes[G].Sym := M;
      G2 := Nodes[A].A;
      While G2 <> G Do Begin
        If Nodes[G2].S = Nodes[G].S Then Err(Nodes[G].Line, 'l''element ' + Nodes[G].S + ' est deja specifie dans l''annotation');
        G2 := Nodes[G2].Next;
      End;
      AttribElemValue(Nodes[G].A, Meths[M].Ret);
    End;
    G := Nodes[G].Next;
  End;
  { elements sans valeur par defaut (annotations declarees dans les sources) }
  If Classes[C].IsSrc Then Begin
    M := Classes[C].FirstMeth;
    While M >= 0 Do Begin
      If (Meths[M].Decl <> 0) And (Meths[M].Name <> '<init>') And (Nodes[Meths[M].Decl].Dflt = 0) Then Begin
        Found := False;
        G := Nodes[A].A;
        While G <> 0 Do Begin
          If Nodes[G].S = Meths[M].Name Then Found := True;
          G := Nodes[G].Next;
        End;
        If Not Found Then
          Err(Nodes[A].Line, 'il manque la valeur de l''element ' + Meths[M].Name + ' dans l''annotation @' + Classes[C].Simple);
      End;
      M := Meths[M].Next;
    End;
  End;
End;

Procedure AttribAnnotChain(Head, Target : LongInt);
Var A, B : LongInt; Fresh : Boolean; Meta : TAnnMetaRec;
Begin
  If Head = 0 Then Exit;
  Fresh := Nodes[Head].Aux = 0;
  A := Head;
  While A <> 0 Do Begin AttribAnnot(A, Target); A := Nodes[A].Next; End;
  If Not Fresh Then Exit;
  A := Head;
  While A <> 0 Do Begin
    If Nodes[A].Sym >= 0 Then Begin
      B := Nodes[A].Next;
      While B <> 0 Do Begin
        If Nodes[B].Sym = Nodes[A].Sym Then Begin
          Meta := AnnMeta(Nodes[A].Sym);
          If Meta.Cont < 0 Then
            Err(Nodes[B].Line, 'l''annotation @' + Classes[Nodes[A].Sym].Simple + ' n''est pas repetable');
        End;
        B := Nodes[B].Next;
      End;
    End;
    A := Nodes[A].Next;
  End;
End;

Function SuperHasMeth(K : LongInt; Const Name : String; Np, Depth : LongInt) : Boolean;
Var M, I : LongInt;
Begin
  SuperHasMeth := False;
  If (K < 0) Or (Depth > 40) Then Exit;
  EnsureMembers(K);
  M := Classes[K].FirstMeth;
  While M >= 0 Do Begin
    If (Meths[M].Name = Name) And (Meths[M].NPar = Np) And ((Meths[M].Flags And (ACC_STATIC Or ACC_PRIVATE)) = 0) Then Begin
      SuperHasMeth := True; Exit;
    End;
    M := Meths[M].Next;
  End;
  If SuperHasMeth(SuperClsOf(K), Name, Np, Depth + 1) Then Begin SuperHasMeth := True; Exit; End;
  For I := 0 To Length(Classes[K].Ifaces) - 1 Do
    If SuperHasMeth(ClsOf(Classes[K].Ifaces[I]), Name, Np, Depth + 1) Then Begin SuperHasMeth := True; Exit; End;
  If (Classes[K].Flags And ACC_INTERFACE) <> 0 Then
    If SuperHasMeth(C_OBJECT, Name, Np, Depth + 1) Then SuperHasMeth := True;
End;

Procedure CheckOverrideAnnot(C, M, Head : LongInt);
Var A, P : LongInt; Ok : Boolean;
Begin
  A := Head;
  While A <> 0 Do Begin
    If (Nodes[A].Sym >= 0) And (Classes[Nodes[A].Sym].Name = 'java/lang/Override') Then Begin
      Ok := (Meths[M].Flags And ACC_STATIC) = 0;
      If Ok Then Begin
        Ok := SuperHasMeth(SuperClsOf(C), Meths[M].Name, Meths[M].NPar, 0);
        If Not Ok Then Begin
          P := 0;
          Ok := SuperHasMeth(C_OBJECT, Meths[M].Name, Meths[M].NPar, 0) And ((Classes[C].Flags And ACC_INTERFACE) <> 0);
        End;
        If Not Ok Then
          For P := 0 To Length(Classes[C].Ifaces) - 1 Do
            If SuperHasMeth(ClsOf(Classes[C].Ifaces[P]), Meths[M].Name, Meths[M].NPar, 0) Then Ok := True;
        { accesseur d'un composant de record }
        If (Not Ok) And (Nodes[Classes[C].Decl].Aux = CLS_RECORD) And (Meths[M].NPar = 0) Then Begin
          P := Nodes[Classes[C].Decl].E;
          While P <> 0 Do Begin
            If Nodes[P].S = Meths[M].Name Then Ok := True;
            P := Nodes[P].Next;
          End;
        End;
      End;
      If Not Ok Then
        Err(Nodes[A].Line, 'la methode ne redefinit et n''implemente aucune methode d''un super-type');
    End;
    A := Nodes[A].Next;
  End;
End;

{ Analyse toutes les annotations declarees dans la classe C (classe, composants, champs, methodes, parametres) }
Procedure AttribClassAnnots(C : LongInt);
Var
  D, M, P, Mt : LongInt; Tg : LongInt;
  SvCtx, SvMeth, SvRet : LongInt; SvStatic : Boolean;
Begin
  D := Classes[C].Decl;
  SvCtx := CurCtx; SvMeth := CurMeth; SvRet := CurRet; SvStatic := CurStatic;
  CurCtx := NewCtx(CTX_METHOD, ClsParentCtx);
  CurStatic := True;
  CurMeth := -1;
  CurRet := TY_NONE;
  PushThrowCtx(TC_BOUND);
  If Nodes[D].Aux = CLS_ANNOTATION Then Tg := TGT_TYPE Or TGT_ANNOT Else Tg := TGT_TYPE;
  AttribAnnotChain(Nodes[D].Ann, Tg);
  { @FunctionalInterface : interface avec exactement une methode abstraite }
  P := Nodes[D].Ann;
  While P <> 0 Do Begin
    If (Nodes[P].Sym >= 0) And (Classes[Nodes[P].Sym].Name = 'java/lang/FunctionalInterface') Then Begin
      If ((Classes[C].Flags And ACC_INTERFACE) = 0) Or ((Classes[C].Flags And ACC_ANNOTATION) <> 0) Then
        Err(Nodes[P].Line, 'annotation @FunctionalInterface inattendue : ' + Classes[C].Simple + ' n''est pas une interface fonctionnelle')
      Else If FindSAM(ThisTypeOf(C)) < 0 Then
        Err(Nodes[P].Line, 'annotation @FunctionalInterface inattendue : ' + Classes[C].Simple +
            ' n''est pas une interface fonctionnelle (aucune ou plusieurs methodes abstraites)');
    End;
    P := Nodes[P].Next;
  End;
  If Nodes[D].Aux = CLS_RECORD Then Begin
    P := Nodes[D].E;
    While P <> 0 Do Begin
      AttribAnnotChain(Nodes[P].Ann, TGT_RECCOMP Or TGT_FIELD Or TGT_METHOD Or TGT_PARAMETER);
      P := Nodes[P].Next;
    End;
  End;
  M := Nodes[D].D;
  While M <> 0 Do Begin
    Case Nodes[M].Kind Of
      N_FIELD, N_ENUMCONST : AttribAnnotChain(Nodes[M].Ann, TGT_FIELD);
      N_METHOD : Begin
        Mt := Nodes[M].Sym;
        If Nodes[M].Aux = 1 Then AttribAnnotChain(Nodes[M].Ann, TGT_CONSTRUCTOR)
        Else AttribAnnotChain(Nodes[M].Ann, TGT_METHOD);
        If (Mt >= 0) And (Nodes[M].Aux <> 1) Then CheckOverrideAnnot(C, Mt, Nodes[M].Ann);
        P := Nodes[M].B;
        While P <> 0 Do Begin
          AttribAnnotChain(Nodes[P].Ann, TGT_PARAMETER);
          P := Nodes[P].Next;
        End;
        If (Nodes[M].Dflt <> 0) And (Mt >= 0) Then AttribElemValue(Nodes[M].Dflt, Meths[Mt].Ret);
      End;
    End;
    M := Nodes[M].Next;
  End;
  Dec(NThrowCtx);
  CurCtx := SvCtx; CurMeth := SvMeth; CurRet := SvRet; CurStatic := SvStatic;
End;
{ ============================================================================
  4. ANALYSE SEMANTIQUE : classes, methodes, classes locales, pilote
  ============================================================================ }

Function SuperCtorParamCount(M : LongInt) : LongInt;
Begin
  SuperCtorParamCount := Meths[M].NPar;
End;

{ Cree le constructeur d'une classe anonyme : memes parametres que le constructeur
  de la super-classe choisi }
Procedure MakeAnonCtor(C, SuperM, SuperT : LongInt);
Var
  D, M, Prm, Tl, Hd, Blk, St, Call, ArgH, ArgT, I, P, Id : LongInt; Line : LongInt;
Begin
  D := Classes[C].Decl;
  Line := Nodes[D].Line;
  M := NewNode(N_METHOD, Line);
  Nodes[M].S := '<init>';
  Nodes[M].Aux := 1;
  Nodes[M].Mods := 0;
  Blk := NewNode(N_BLOCK, Line);
  Call := NewNode(N_CALL, Line);
  Nodes[Call].S := 'super';
  Nodes[Call].Aux := 1;
  Tl := 0; Hd := 0; ArgH := 0; ArgT := 0;
  If SuperM >= 0 Then
    For I := 0 To Meths[SuperM].NPar - 1 Do Begin
      Prm := NewNode(N_PARAM, Line);
      Nodes[Prm].S := '$a' + IStr(I);
      Nodes[Prm].A := MkResolvedType(MemberType(SuperT, Meths[SuperM].Owner, Meths[SuperM].Par[I]), Line);
      If Meths[SuperM].Varargs And (I = Meths[SuperM].NPar - 1) Then Nodes[Prm].Aux := 1;
      AppendNode(Hd, Tl, Prm);
      AppendNode(ArgH, ArgT, MkNameNode2('$a' + IStr(I), Line));
    End;
  Nodes[M].B := Hd;
  Nodes[Call].B := ArgH;
  St := NewNode(N_EXPRSTMT, Line);
  Nodes[St].A := Call;
  Nodes[Blk].A := St;
  Nodes[M].C := Blk;
  { ajoute en fin de la liste des membres }
  P := Nodes[D].D;
  If P = 0 Then Nodes[D].D := M
  Else Begin
    While Nodes[P].Next <> 0 Do P := Nodes[P].Next;
    Nodes[P].Next := M;
  End;
  Id := EnterMethod(C, M);
  Classes[C].AnonCtor := Id;
End;

Function EnterLocalClass(Decl : LongInt; AnonSuper : LongInt) : LongInt;
Var
  C, Ctx, Sc : LongInt; IsAnon : Boolean; S : TSavedCtx; Ifs : Array Of LongInt; SvStatic : Boolean;
  SuperM : LongInt;
Begin
  IsAnon := (Nodes[Decl].Mods And MOD_ANON) <> 0;
  C := EnterClass(Decl, CurClass, CurCU, True, '', CurStatic);
  Classes[C].Ctx := CurCtx;
  Ctx := NewCtx(CTX_CLASS, CurCtx);
  Ctxs[Ctx].Cls := C;
  Classes[C].ClsCtx := Ctx;
  Classes[C].AnonCtor := -1;
  If Not IsAnon Then PushScope(SC_LOCALCLASS, Classes[C].Simple, C);
  If IsAnon Then Begin
    Classes[C].HdrState := 2;
    If (Classes[ClsOf(AnonSuper)].Flags And ACC_INTERFACE) <> 0 Then Begin
      Classes[C].Super := T_OBJECT;
      SetLength(Classes[C].Ifaces, 1);
      Classes[C].Ifaces[0] := AnonSuper;
    End
    Else Classes[C].Super := AnonSuper;
    { enum a corps : sous-classe de l'enum }
    If (Classes[ClsOf(AnonSuper)].Flags And ACC_ENUM) <> 0 Then
      Classes[C].Flags := Classes[C].Flags Or ACC_ENUM Or ACC_FINAL;
    Classes[C].Flags := Classes[C].Flags And Not ACC_STATIC;
  End
  Else ResolveSrcHeader(C);
  EnterMembers(C);
  If IsAnon Then Begin
    SuperM := AnonSuperCtor;
    AnonSuperCtor := -1;
    MakeAnonCtor(C, SuperM, AnonSuper);
  End;
  AttribClassBody(C);
  EnterLocalClass := C;
  Sc := 0;
End;

{ Verifie qu'une classe concrete implemente toutes les methodes abstraites (controle
  tolerant : nom et nombre de parametres) }
Procedure CheckAbstractImpl(C : LongInt);
Var Visited : Array[0..255] Of LongInt; NV : LongInt;

  Function HasImpl(K : LongInt; Const Name : String; Np : LongInt) : Boolean;
  Var M, S, I : LongInt;
  Begin
    HasImpl := False;
    If K < 0 Then Exit;
    EnsureMembers(K);
    M := Classes[K].FirstMeth;
    While M >= 0 Do Begin
      If (Meths[M].Name = Name) And (Meths[M].NPar = Np) And ((Meths[M].Flags And ACC_ABSTRACT) = 0) And
         ((Meths[M].Flags And ACC_STATIC) = 0) Then Begin HasImpl := True; Exit; End;
      M := Meths[M].Next;
    End;
    S := SuperClsOf(K);
    If HasImpl(S, Name, Np) Then Begin HasImpl := True; Exit; End;
    { methodes par defaut des interfaces }
    For I := 0 To Length(Classes[K].Ifaces) - 1 Do
      If HasImpl(ClsOf(Classes[K].Ifaces[I]), Name, Np) Then Begin HasImpl := True; Exit; End;
  End;

  Procedure Walk(K : LongInt);
  Var M, S, I : LongInt; Seen : Boolean; Nm : String;
  Begin
    If K < 0 Then Exit;
    For I := 0 To NV - 1 Do If Visited[I] = K Then Exit;
    If NV < 256 Then Begin Visited[NV] := K; Inc(NV); End;
    EnsureMembers(K);
    M := Classes[K].FirstMeth;
    While M >= 0 Do Begin
      If ((Meths[M].Flags And ACC_ABSTRACT) <> 0) And ((Meths[M].Flags And ACC_STATIC) = 0) Then Begin
        Nm := Meths[M].Name;
        If Not (((Nm = 'equals') And (Meths[M].NPar = 1)) Or ((Nm = 'hashCode') And (Meths[M].NPar = 0)) Or
                ((Nm = 'toString') And (Meths[M].NPar = 0))) Then
          If Not HasImpl(C, Nm, Meths[M].NPar) Then Begin
            Err(Nodes[Classes[C].Decl].Line, Classes[C].Simple + ' n''est pas abstrait et ne redefinit pas la methode abstraite ' +
                Nm + ' de ' + Classes[K].Simple);
            Exit;
          End;
      End;
      M := Meths[M].Next;
    End;
    S := SuperClsOf(K);
    Walk(S);
    For I := 0 To Length(Classes[K].Ifaces) - 1 Do Walk(ClsOf(Classes[K].Ifaces[I]));
  End;

Begin
  If (Classes[C].Flags And (ACC_ABSTRACT Or ACC_INTERFACE)) <> 0 Then Exit;
  If (Classes[C].Flags And ACC_ENUM) <> 0 Then Begin
    { une enum avec des constantes a corps peut laisser des methodes abstraites }
    If Classes[C].EnumCount = 0 Then Exit;
  End;
  NV := 0;
  Walk(C);
End;

Procedure AttribMethod(M : LongInt);
Var
  D, P, L, I, Body, First, Call, St, SvMeth, SvRet, SvCtx, SvLoop, SvSw, SvLab, Mark : LongInt; SvStatic : Boolean;
  Pt : LongInt; NeedSuper : Boolean; C : LongInt;
Begin
  D := Meths[M].Decl;
  If D = 0 Then Exit;
  C := Meths[M].Owner;
  Body := Nodes[D].C;
  If Body = 0 Then Begin
    If (Meths[M].Flags And (ACC_ABSTRACT Or ACC_NATIVE)) = 0 Then
      Err(Nodes[D].Line, 'corps de methode manquant, ou declarer abstract');
    Exit;
  End;
  If (Meths[M].Flags And ACC_ABSTRACT) <> 0 Then Begin
    Err(Nodes[D].Line, 'une methode abstraite ne peut pas avoir de corps');
  End;
  SvMeth := CurMeth; SvRet := CurRet; SvCtx := CurCtx; SvStatic := CurStatic;
  SvLoop := LoopDepth; SvSw := SwitchDepth; SvLab := NLabelStk;
  LoopDepth := 0; SwitchDepth := 0;
  Mark := NScope;
  CurMeth := M;
  CurStatic := (Meths[M].Flags And ACC_STATIC) <> 0;
  CurRet := Meths[M].Ret;
  CurCtx := NewCtx(CTX_METHOD, ClsParentCtx);
  PushThrowCtx(TC_BOUND);
  For I := 0 To Length(Meths[M].Thr) - 1 Do AddThrowCtxType(NThrowCtx - 1, Meths[M].Thr[I]);
  { variables de type de la methode }
  For I := 0 To Length(Meths[M].TPar) - 1 Do
    PushScope(SC_TPARAM, TVars[Types[Meths[M].TPar[I]].TV].Name, Meths[M].TPar[I]);
  { parametres }
  P := Nodes[D].B;
  I := 0;
  While P <> 0 Do Begin
    If LocalDeclared(Nodes[P].S) Then Err(Nodes[P].Line, 'la variable ' + Nodes[P].S + ' est deja definie');
    L := NewLocal(Nodes[P].S, Meths[M].Par[I], Nodes[P].Mods Or LF_PARAM, P);
    Locals[L].HasInit := True;
    Nodes[P].Sym := L;
    Nodes[P].Typ := Meths[M].Par[I];
    PushScope(SC_LOCAL, Nodes[P].S, L);
    Inc(I);
    P := Nodes[P].Next;
  End;
  { constructeur : appel implicite a super() }
  If Nodes[D].Aux = 1 Then Begin
    NeedSuper := True;
    First := Nodes[Body].A;
    If First <> 0 Then
      If (Nodes[First].Kind = N_EXPRSTMT) And (Nodes[Nodes[First].A].Kind = N_CALL) And (Nodes[Nodes[First].A].Aux = 1) Then
        NeedSuper := False;
    If (Classes[C].Flags And ACC_ENUM) <> 0 Then NeedSuper := NeedSuper And ((Classes[C].Flags And MOD_ANON) <> 0);
    If (Classes[C].Flags And ACC_INTERFACE) <> 0 Then NeedSuper := False;
    If C = C_OBJECT Then NeedSuper := False;
    If NeedSuper Then Begin
      Call := NewNode(N_CALL, Nodes[D].Line);
      Nodes[Call].S := 'super';
      Nodes[Call].Aux := 1;
      St := NewNode(N_EXPRSTMT, Nodes[D].Line);
      Nodes[St].A := Call;
      Nodes[St].Next := Nodes[Body].A;
      Nodes[Body].A := St;
    End;
  End;
  AttribStmt(Body);
  Dec(NThrowCtx);
  NScope := Mark;
  CurMeth := SvMeth; CurRet := SvRet; CurCtx := SvCtx; CurStatic := SvStatic;
  LoopDepth := SvLoop; SwitchDepth := SvSw; NLabelStk := SvLab;
  Pt := 0;
End;

{ Conflit de noms avec une methode heritee : meme effacement sans redefinition (JLS 8.4.8.3) }
Procedure CheckInheritedClash(C, M : LongInt);
Var Depth : LongInt;
  Procedure Walk(K : LongInt; D : LongInt);
  Var M2, I : LongInt; Same : Boolean; Line : LongInt;
  Begin
    If (K < 0) Or (D > 30) Then Exit;
    EnsureMembers(K);
    M2 := Classes[K].FirstMeth;
    While M2 >= 0 Do Begin
      If (Meths[M2].Name = Meths[M].Name) And (Meths[M2].NPar = Meths[M].NPar) And (Meths[M2].Synth = 0) And
         ((Meths[M2].Flags And (ACC_STATIC Or ACC_PRIVATE)) = 0) And SameErasedParams(M, M2) Then Begin
        Same := True;
        For I := 0 To Meths[M].NPar - 1 Do
          If Erasure(MemberType(ThisTypeOf(C), K, Meths[M2].Par[I])) <> Erasure(Meths[M].Par[I]) Then Same := False;
        If Not Same Then Begin
          Line := Nodes[Meths[M].Decl].Line;
          Err(Line, 'conflit de noms : ' + Meths[M].Name + ' dans ' + Classes[C].Simple + ' et ' + Meths[M2].Name + ' dans ' +
              Classes[K].Simple + ' ont la meme signature apres effacement, mais aucune ne redefinit l''autre');
          Exit;
        End;
      End;
      M2 := Meths[M2].Next;
    End;
    Walk(SuperClsOf(K), D + 1);
    For I := 0 To Length(Classes[K].Ifaces) - 1 Do Walk(ClsOf(Classes[K].Ifaces[I]), D + 1);
  End;
Begin
  Depth := 0;
  Walk(SuperClsOf(C), 1);
  For Depth := 0 To Length(Classes[C].Ifaces) - 1 Do Walk(ClsOf(Classes[C].Ifaces[Depth]), 1);
End;

{ Controles de declaration : doublons, heritage de classe finale, redefinition de methode finale }
Procedure CheckClassDecl(C : LongInt);
Var F, F2, M, M2, S, Sup : LongInt; Line : LongInt; D : LongInt;
Begin
  D := Classes[C].Decl;
  Line := Nodes[D].Line;
  F := Classes[C].FirstField;
  While F >= 0 Do Begin
    F2 := Fields[F].Next;
    While F2 >= 0 Do Begin
      If Fields[F2].Name = Fields[F].Name Then
        Err(Line, 'la variable ' + Fields[F].Name + ' est deja definie dans la classe ' + Classes[C].Simple);
      F2 := Fields[F2].Next;
    End;
    F := Fields[F].Next;
  End;
  M := Classes[C].FirstMeth;
  While M >= 0 Do Begin
    If Meths[M].Synth = 0 Then Begin
      M2 := Meths[M].Next;
      While M2 >= 0 Do Begin
        If (Meths[M2].Synth = 0) And (Meths[M2].Name = Meths[M].Name) And SameErasedParams(M, M2) Then Begin
          If Meths[M].Decl <> 0 Then Line := Nodes[Meths[M2].Decl].Line;
          If Meths[M].Name = '<init>' Then Err(Line, 'le constructeur ' + Classes[C].Simple + ' est deja defini')
          Else Err(Line, 'la methode ' + Meths[M].Name + ' est deja definie dans la classe ' + Classes[C].Simple);
        End;
        M2 := Meths[M2].Next;
      End;
    End;
    M := Meths[M].Next;
  End;
  { conflits avec les methodes heritees }
  M := Classes[C].FirstMeth;
  While M >= 0 Do Begin
    If (Meths[M].Synth = 0) And (Meths[M].Decl <> 0) And (Meths[M].Name <> '<init>') And (Meths[M].Lambda < 0) And
       ((Meths[M].Flags And (ACC_STATIC Or ACC_PRIVATE)) = 0) Then CheckInheritedClash(C, M);
    M := Meths[M].Next;
  End;
  { super-classe finale }
  Sup := SuperClsOf(C);
  If (Sup >= 0) And ((Classes[Sup].Flags And ACC_FINAL) <> 0) And ((Classes[C].Flags And MOD_ANON) = 0) And ((Classes[Sup].Flags And ACC_ENUM) = 0) Then
    Err(Nodes[D].Line, 'impossible d''heriter de la classe finale ' + Classes[Sup].Simple);
  { redefinition d'une methode finale }
  M := Classes[C].FirstMeth;
  While M >= 0 Do Begin
    If (Meths[M].Synth = 0) And (Meths[M].Name <> '<init>') And ((Meths[M].Flags And (ACC_STATIC Or ACC_PRIVATE)) = 0) And (Meths[M].Decl <> 0) Then Begin
      S := Sup;
      While S >= 0 Do Begin
        EnsureMembers(S);
        M2 := Classes[S].FirstMeth;
        While M2 >= 0 Do Begin
          If (Meths[M2].Name = Meths[M].Name) And (Meths[M2].NPar = Meths[M].NPar) And ((Meths[M2].Flags And ACC_FINAL) <> 0) And
             ((Meths[M2].Flags And (ACC_STATIC Or ACC_PRIVATE)) = 0) And SameErasedParams(M, M2) Then
            Err(Nodes[Meths[M].Decl].Line, 'la methode ' + Meths[M].Name + ' ne peut pas redefinir la methode finale de ' + Classes[S].Simple);
          M2 := Meths[M2].Next;
        End;
        S := SuperClsOf(S);
      End;
    End;
    M := Meths[M].Next;
  End;
End;

Procedure AttribClassBody(C : LongInt);
Var
  SvCls, SvMeth, SvRet, SvCtx, SvCU, SvPCtx, Mark : LongInt; SvStatic : Boolean;
  D, M, V, F, Ft, Ctx, A, B, Anon : LongInt; R : TResolved; Ok : Boolean; Sc : LongInt;
Begin
  If Classes[C].Lowered Then Exit;
  Classes[C].Lowered := True;      { drapeau "analyse faite" avant le desucrage }
  EnsureMembers(C);
  SvCls := CurClass; SvMeth := CurMeth; SvRet := CurRet; SvCtx := CurCtx; SvCU := CurCU;
  SvStatic := CurStatic; SvPCtx := ClsParentCtx;
  Mark := NScope;
  CurClass := C;
  CurCU := Classes[C].CU;
  If CurCU >= 0 Then CurFile := CUs[CurCU].FileName;
  If Classes[C].Ctx >= 0 Then ClsParentCtx := Classes[C].ClsCtx
  Else ClsParentCtx := -1;
  PushScope(SC_CLASSMARK, '', C);
  D := Classes[C].Decl;
  CheckClassDecl(C);
  CheckSealed(C);
  AttribClassAnnots(C);
  M := Nodes[D].D;
  While M <> 0 Do Begin
    Case Nodes[M].Kind Of
      N_FIELD : Begin
        V := Nodes[M].B;
        While V <> 0 Do Begin
          F := Nodes[V].Sym;
          If (F >= 0) And (Nodes[V].A <> 0) Then Begin
            Ft := Fields[F].Typ;
            CurCtx := NewCtx(CTX_METHOD, ClsParentCtx);
            CurStatic := (Fields[F].Flags And ACC_STATIC) <> 0;
            CurMeth := -1;
            CurRet := TY_NONE;
            LoopDepth := 0; SwitchDepth := 0;
            PushThrowCtx(TC_BOUND);
            If Nodes[Nodes[V].A].Kind = N_ARRAYINIT Then AttribArrayInit(Nodes[V].A, Ft)
            Else Begin
              AttribExpr(Nodes[V].A, Ft);
              Coerce(Nodes[V].A, Ft, CV_ASSIGN);
            End;
            Dec(NThrowCtx);
            { constante : memorise la valeur }
            EnsureFieldConst(F);
          End;
          V := Nodes[V].Next;
        End;
      End;
      N_INIT : Begin
        CurCtx := NewCtx(CTX_METHOD, ClsParentCtx);
        CurStatic := (Nodes[M].Mods And ACC_STATIC) <> 0;
        CurMeth := -1;
        CurRet := TY_VOID;
        LoopDepth := 0; SwitchDepth := 0;
        PushThrowCtx(TC_BOUND);
        AttribStmt(Nodes[M].A);
        Dec(NThrowCtx);
      End;
      N_METHOD : Begin
        AttribMethod(Nodes[M].Sym);
      End;
      N_ENUMCONST : Begin
        CurCtx := NewCtx(CTX_METHOD, ClsParentCtx);
        CurStatic := True;
        CurMeth := -1;
        CurRet := TY_NONE;
        PushThrowCtx(TC_BOUND);
        Ok := ResolveCall('<init>', ClassT(C), True, Nodes[M].A, 0, Nodes[M].Line, -1, R);
        Dec(NThrowCtx);
        If Ok Then Begin
          Nodes[M].N := R.M;
          If R.Varargs Then Begin Nodes[M].Mods := Nodes[M].Mods Or CALL_VARARGS; Nodes[M].Aux := R.NPar; End;
          If Nodes[M].B <> 0 Then Begin
            AnonSuperCtor := R.M;
            Anon := EnterLocalClass(Nodes[M].B, ClassT(C));
            Nodes[M].E := Anon + 1;
          End;
        End;
      End;
      N_CLASS : AttribClassBody(Nodes[M].Sym);
    End;
    M := Nodes[M].Next;
  End;
  CheckAbstractImpl(C);
  NScope := Mark;
  CurClass := SvCls; CurMeth := SvMeth; CurRet := SvRet; CurCtx := SvCtx; CurCU := SvCU;
  CurStatic := SvStatic; ClsParentCtx := SvPCtx;
  If CurCU >= 0 Then CurFile := CUs[CurCU].FileName;
  Sc := 0; A := 0; B := 0; Ctx := 0;
End;

Procedure CheckCaptures;
Var I, L : LongInt;
Begin
  For I := 0 To NCapUses - 1 Do Begin
    L := CapUses[I];
    If (Locals[L].Assigns > 0) And (Locals[L].HasInit Or ((Locals[L].Flags And LF_PARAM) <> 0)) Then Begin
      CurFile := CapFiles[I];
      Err(CapLines[I], 'les variables locales referencees depuis une lambda ou une classe interne doivent etre finales ou effectivement finales');
      Locals[L].Assigns := 0;
    End;
  End;
End;

{ Lecture, analyse lexicale et syntaxique d'un fichier ; entree de ses classes }
Procedure LoadSourceFile(Const Fn : String);
Var
  F : File; Sz, Cu, Root, Decl, C : LongInt; SvFile : String; Imp : LongInt;
Begin
  MapPut(ClassMap, '@src:' + Fn, 0);
  Assign(F, Fn);
  Reset(F, 1);
  If IOResult <> 0 Then Begin
    WriteLn('javac: fichier introuvable : ', Fn);
    Inc(ErrCount);
    Exit;
  End;
  Sz := FileSize(F);
  SetLength(Src, Sz);
  If Sz > 0 Then BlockRead(F, Src[1], Sz);
  Close(F);
  SrcLen := Sz;
  SvFile := CurFile;
  CurFile := Fn;
  { retire un eventuel BOM UTF-8 }
  If (SrcLen >= 3) And (Ord(Src[1]) = $EF) And (Ord(Src[2]) = $BB) And (Ord(Src[3]) = $BF) Then Begin
    Delete(Src, 1, 3);
    SrcLen := Length(Src);
  End;
  Lex;
  P := 0;
  If ErrCount > 0 Then Begin CurFile := SvFile; Exit; End;
  Root := ParseCompilationUnit;
  If NCUs >= Length(CUs) Then SetLength(CUs, NCUs * 2 + 8);
  Cu := NCUs;
  Inc(NCUs);
  CUs[Cu].Pkg := Nodes[Root].S;
  CUs[Cu].FileName := Fn;
  CUs[Cu].Imports := Nodes[Root].A;
  CUs[Cu].Root := Root;
  If Nodes[Root].C <> 0 Then Begin
    If ModDecl <> 0 Then Err(Nodes[Nodes[Root].C].Line, 'plusieurs declarations de module');
    ModDecl := Nodes[Root].C;
    ModCU := Cu;
  End;
  Decl := Nodes[Root].B;
  Imp := 0;
  While Decl <> 0 Do Begin
    C := EnterClass(Decl, -1, Cu, False, '', False);
    Decl := Nodes[Decl].Next;
  End;
  CurFile := SvFile;
  If Imp = 0 Then ;
End;

{ ----- module-info.java ------------------------------------------------------------------ }

Function JdkHasModule(Const Nm : String) : Boolean;
Var A, B, C : LongInt;
Begin
  JdkOpen;
  JdkHasModule := JdkReady And JdkLocate('/' + Nm + '/module-info.class', A, B, C);
End;

Function SourcePkgExists(Const Pkg : String) : Boolean;
Var I : LongInt;
Begin
  SourcePkgExists := False;
  For I := 0 To NCUs - 1 Do
    If (CUs[I].Pkg = Pkg) And (Nodes[CUs[I].Root].B <> 0) Then SourcePkgExists := True;
End;

Procedure AttribModule;
Var
  D, X, K, Cl, Svc, I : LongInt; Q : LongInt;
  SvCU, SvCtx, SvMeth, SvCls : LongInt; SvStatic : Boolean; Dup : LongInt; HasProv : Boolean;
Begin
  If ModDecl = 0 Then Exit;
  If OptTarget < 53 Then Err(Nodes[ModDecl].Line, 'les modules necessitent une version cible 9 ou superieure');
  SvCU := CurCU; SvCtx := CurCtx; SvMeth := CurMeth; SvCls := CurClass; SvStatic := CurStatic;
  CurCU := ModCU; CurClass := -1; CurMeth := -1; CurStatic := True; CurRet := TY_NONE;
  CurFile := CUs[ModCU].FileName;
  CurCtx := NewCtx(CTX_METHOD, -1);
  PushThrowCtx(TC_BOUND);
  AttribAnnotChain(Nodes[ModDecl].Ann, TGT_MODULE);
  Dec(NThrowCtx);
  D := Nodes[ModDecl].A;
  While D <> 0 Do Begin
    { directive en double }
    Q := Nodes[D].Next;
    While Q <> 0 Do Begin
      If (Nodes[Q].S = Nodes[D].S) And (Nodes[Q].CS = Nodes[D].CS) And (Nodes[D].S <> 'provides') Then Begin
        If Nodes[D].S = 'requires' Then Err(Nodes[Q].Line, 'dependance de module en double : ' + Nodes[Q].CS)
        Else If Nodes[D].S = 'uses' Then Err(Nodes[Q].Line, 'directive uses en double : ' + Nodes[Q].CS)
        Else Err(Nodes[Q].Line, 'directive ' + Nodes[Q].S + ' en double pour le paquetage ' + Nodes[Q].CS);
      End;
      Q := Nodes[Q].Next;
    End;
    If Nodes[D].S = 'requires' Then Begin
      If Nodes[D].CS = Nodes[ModDecl].S Then Err(Nodes[D].Line, 'dependance cyclique du module ' + Nodes[D].CS)
      Else If (Not JdkHasModule(Nodes[D].CS)) And (Not OptModulePath) Then
        Err(Nodes[D].Line, 'module introuvable : ' + Nodes[D].CS);
    End
    Else If Nodes[D].S = 'exports' Then Begin
      If Not SourcePkgExists(Nodes[D].CS) Then
        Err(Nodes[D].Line, 'le paquetage est vide ou n''existe pas : ' + Nodes[D].CS);
    End
    Else If Nodes[D].S = 'uses' Then Begin
      X := LookupTypeName(Nodes[D].CS);
      If X <= 0 Then Err(Nodes[D].Line, 'symbole introuvable : classe ' + Nodes[D].CS)
      Else Nodes[D].Sym := ClsOf(X);
    End
    Else If Nodes[D].S = 'provides' Then Begin
      Svc := -1;
      X := LookupTypeName(Nodes[D].CS);
      If X <= 0 Then Err(Nodes[D].Line, 'symbole introuvable : classe ' + Nodes[D].CS)
      Else Begin Svc := ClsOf(X); Nodes[D].Sym := Svc; End;
      K := Nodes[D].B;
      While K <> 0 Do Begin
        X := LookupTypeName(Nodes[K].S);
        If X <= 0 Then Err(Nodes[K].Line, 'symbole introuvable : classe ' + Nodes[K].S)
        Else Begin
          Cl := ClsOf(X);
          Nodes[K].Sym := Cl;
          If Svc >= 0 Then Begin
            EnsureMembers(Cl);
            HasProv := False;
            I := Classes[Cl].FirstMeth;
            While I >= 0 Do Begin
              If (Meths[I].Name = 'provider') And (Meths[I].NPar = 0) And ((Meths[I].Flags And ACC_STATIC) <> 0) Then HasProv := True;
              I := Meths[I].Next;
            End;
            If Not HasProv Then Begin
              If Not IsSubClass(Cl, Svc) Then
                Err(Nodes[K].Line, 'le type d''implementation du service doit etre un sous-type de ' + Classes[Svc].Simple);
              If (Classes[Cl].Flags And ACC_ABSTRACT) <> 0 Then
                Err(Nodes[K].Line, 'l''implementation du service ne peut pas etre abstraite : ' + Classes[Cl].Simple);
            End;
          End;
        End;
        K := Nodes[K].Next;
      End;
    End;
    D := Nodes[D].Next;
  End;
  CurCU := SvCU; CurCtx := SvCtx; CurMeth := SvMeth; CurClass := SvCls; CurStatic := SvStatic;
  If CurCU >= 0 Then CurFile := CUs[CurCU].FileName;
End;

Procedure AttribAll;
Var I : LongInt;
Begin
  I := 0;
  While I < NClasses Do Begin
    If Classes[I].IsSrc And (Classes[I].Ctx < 0) Then Begin
      EnsureHeader(I);
      EnsureMembers(I);
    End;
    Inc(I);
  End;
  I := 0;
  While I < NClasses Do Begin
    If Classes[I].IsSrc And (Classes[I].Outer < 0) And Not Classes[I].Lowered Then
      AttribClassBody(I);
    Inc(I);
  End;
  CloseCaptures;
  CheckCaptures;
  AttribModule;
End;

{ ============================================================================
  6. FICHIERS .CLASS : tampons d'octets, pool de constantes, ecriture
  ============================================================================ }

{ ----- pool de constantes ------------------------------------------------- }

Var
  Pool    : TBuf;
  PoolN   : LongInt;
  PoolMap : TStrMap;

Procedure PoolInit;
Begin
  BInit(Pool);
  PoolN := 1;
  MapInit(PoolMap, 2039);
End;

Function PoolFind(Const K : String) : LongInt;
Begin
  PoolFind := MapFind(PoolMap, K);
End;

Function CPUtf8(Const S : String) : LongInt;
Var K : String; I : LongInt;
Begin
  K := 'U' + S;
  I := PoolFind(K);
  If I >= 0 Then Begin CPUtf8 := I; Exit; End;
  If Length(S) > 65535 Then Err(0, 'constante de chaine trop longue');
  B1(Pool, 1);
  B2(Pool, Length(S));
  BStr(Pool, S);
  MapPut(PoolMap, K, PoolN);
  CPUtf8 := PoolN;
  Inc(PoolN);
End;

Function CPClass(Const Name : String) : LongInt;
Var K : String; I, U : LongInt;
Begin
  K := 'C' + Name;
  I := PoolFind(K);
  If I >= 0 Then Begin CPClass := I; Exit; End;
  U := CPUtf8(Name);
  B1(Pool, 7);
  B2(Pool, U);
  MapPut(PoolMap, K, PoolN);
  CPClass := PoolN;
  Inc(PoolN);
End;

Function CPModule(Const Name : String) : LongInt;
Var K : String; I, U : LongInt;
Begin
  K := 'M' + Name;
  I := PoolFind(K);
  If I >= 0 Then Begin CPModule := I; Exit; End;
  U := CPUtf8(Name);
  B1(Pool, 19);
  B2(Pool, U);
  MapPut(PoolMap, K, PoolN);
  CPModule := PoolN;
  Inc(PoolN);
End;

Function CPPackage(Const Name : String) : LongInt;
Var K : String; I, U : LongInt;
Begin
  K := 'P' + Name;
  I := PoolFind(K);
  If I >= 0 Then Begin CPPackage := I; Exit; End;
  U := CPUtf8(Name);
  B1(Pool, 20);
  B2(Pool, U);
  MapPut(PoolMap, K, PoolN);
  CPPackage := PoolN;
  Inc(PoolN);
End;

Function CPString(Const S : String) : LongInt;
Var K : String; I, U : LongInt;
Begin
  K := 'S' + S;
  I := PoolFind(K);
  If I >= 0 Then Begin CPString := I; Exit; End;
  U := CPUtf8(S);
  B1(Pool, 8);
  B2(Pool, U);
  MapPut(PoolMap, K, PoolN);
  CPString := PoolN;
  Inc(PoolN);
End;

Function CPInt(V : LongInt) : LongInt;
Var K : String; I : LongInt;
Begin
  K := 'I' + IStr(V);
  I := PoolFind(K);
  If I >= 0 Then Begin CPInt := I; Exit; End;
  B1(Pool, 3);
  B4(Pool, V And $FFFFFFFF);
  MapPut(PoolMap, K, PoolN);
  CPInt := PoolN;
  Inc(PoolN);
End;

Function CPFloat(Bits : LongInt) : LongInt;
Var K : String; I : LongInt;
Begin
  K := 'F' + IStr(Bits);
  I := PoolFind(K);
  If I >= 0 Then Begin CPFloat := I; Exit; End;
  B1(Pool, 4);
  B4(Pool, Int64(Bits) And $FFFFFFFF);
  MapPut(PoolMap, K, PoolN);
  CPFloat := PoolN;
  Inc(PoolN);
End;

Function CPLong(V : Int64) : LongInt;
Var K : String; I : LongInt;
Begin
  K := 'J' + IStr(V);
  I := PoolFind(K);
  If I >= 0 Then Begin CPLong := I; Exit; End;
  B1(Pool, 5);
  B8(Pool, V);
  MapPut(PoolMap, K, PoolN);
  CPLong := PoolN;
  Inc(PoolN, 2);
End;

Function CPDouble(Bits : Int64) : LongInt;
Var K : String; I : LongInt;
Begin
  K := 'D' + IStr(Bits);
  I := PoolFind(K);
  If I >= 0 Then Begin CPDouble := I; Exit; End;
  B1(Pool, 6);
  B8(Pool, Bits);
  MapPut(PoolMap, K, PoolN);
  CPDouble := PoolN;
  Inc(PoolN, 2);
End;

Function CPNameType(Const Name, Desc : String) : LongInt;
Var K : String; I, A, B : LongInt;
Begin
  K := 'N' + Name + ':' + Desc;
  I := PoolFind(K);
  If I >= 0 Then Begin CPNameType := I; Exit; End;
  A := CPUtf8(Name);
  B := CPUtf8(Desc);
  B1(Pool, 12);
  B2(Pool, A);
  B2(Pool, B);
  MapPut(PoolMap, K, PoolN);
  CPNameType := PoolN;
  Inc(PoolN);
End;

Function CPRef(Tag : LongInt; Const Owner, Name, Desc : String) : LongInt;
Var K : String; I, C, Nt : LongInt;
Begin
  K := 'R' + IStr(Tag) + Owner + '.' + Name + ':' + Desc;
  I := PoolFind(K);
  If I >= 0 Then Begin CPRef := I; Exit; End;
  C := CPClass(Owner);
  Nt := CPNameType(Name, Desc);
  B1(Pool, Tag);
  B2(Pool, C);
  B2(Pool, Nt);
  MapPut(PoolMap, K, PoolN);
  CPRef := PoolN;
  Inc(PoolN);
End;

Function CPField(Const Owner, Name, Desc : String) : LongInt;
Begin CPField := CPRef(9, Owner, Name, Desc); End;

Function CPMethod(Const Owner, Name, Desc : String; Iface : Boolean) : LongInt;
Begin
  If Iface Then CPMethod := CPRef(11, Owner, Name, Desc)
  Else CPMethod := CPRef(10, Owner, Name, Desc);
End;

Function CPMethodHandle(Kind, Ref : LongInt) : LongInt;
Var K : String; I : LongInt;
Begin
  K := 'H' + IStr(Kind) + ':' + IStr(Ref);
  I := PoolFind(K);
  If I >= 0 Then Begin CPMethodHandle := I; Exit; End;
  B1(Pool, 15);
  B1(Pool, Kind);
  B2(Pool, Ref);
  MapPut(PoolMap, K, PoolN);
  CPMethodHandle := PoolN;
  Inc(PoolN);
End;

Function CPMethodType(Const Desc : String) : LongInt;
Var K : String; I, U : LongInt;
Begin
  K := 'T' + Desc;
  I := PoolFind(K);
  If I >= 0 Then Begin CPMethodType := I; Exit; End;
  U := CPUtf8(Desc);
  B1(Pool, 16);
  B2(Pool, U);
  MapPut(PoolMap, K, PoolN);
  CPMethodType := PoolN;
  Inc(PoolN);
End;

Function CPInvokeDynamic(Bsm : LongInt; Const Name, Desc : String) : LongInt;
Var K : String; I, Nt : LongInt;
Begin
  K := 'Y' + IStr(Bsm) + ':' + Name + ':' + Desc;
  I := PoolFind(K);
  If I >= 0 Then Begin CPInvokeDynamic := I; Exit; End;
  Nt := CPNameType(Name, Desc);
  B1(Pool, 18);
  B2(Pool, Bsm);
  B2(Pool, Nt);
  MapPut(PoolMap, K, PoolN);
  CPInvokeDynamic := PoolN;
  Inc(PoolN);
End;

{ ----- ecriture des fichiers ---------------------------------------------- }

Procedure MakeDirs(Const Path : String);
Var I : LongInt; Cur : String;
Begin
  Cur := '';
  For I := 1 To Length(Path) Do Begin
    If (Path[I] = '/') Or (Path[I] = '\') Then Begin
      If (Cur <> '') And (Cur <> '.') Then Begin
        MkDir(Cur);
        If IOResult <> 0 Then ;
      End;
    End;
    Cur := Cur + Path[I];
  End;
End;

Function WriteBuf(Const Fn : String; Var B : TBuf) : Boolean;
Var F : File;
Begin
  WriteBuf := False;
  Assign(F, Fn);
  Rewrite(F, 1);
  If IOResult <> 0 Then Exit;
  If B.N > 0 Then BlockWrite(F, B.D[0], B.N);
  Close(F);
  WriteBuf := IOResult = 0;
End;

{ ============================================================================
  5. GENERATION DU BYTECODE (1/3) : emetteur d'instructions JVM avec suivi
     de la pile, des variables locales et de la StackMapTable
  ============================================================================ }

Const
  VT_TOP = 0;  VT_INT = 1;  VT_FLOAT = 2;  VT_DOUBLE = 3;  VT_LONG = 4;
  VT_NULL = 5; VT_UNINITTHIS = 6; VT_OBJECT = 7; VT_UNINIT = 8; VT_SECOND = 9;

  OP_NOP = 0; OP_ACONST_NULL = 1; OP_ICONST_M1 = 2; OP_ICONST_0 = 3; OP_LCONST_0 = 9;
  OP_FCONST_0 = 11; OP_DCONST_0 = 14; OP_BIPUSH = 16; OP_SIPUSH = 17;
  OP_LDC = 18; OP_LDC_W = 19; OP_LDC2_W = 20;
  OP_ILOAD = 21; OP_LLOAD = 22; OP_FLOAD = 23; OP_DLOAD = 24; OP_ALOAD = 25;
  OP_ILOAD_0 = 26; OP_LLOAD_0 = 30; OP_FLOAD_0 = 34; OP_DLOAD_0 = 38; OP_ALOAD_0 = 42;
  OP_IALOAD = 46;
  OP_ISTORE = 54; OP_LSTORE = 55; OP_FSTORE = 56; OP_DSTORE = 57; OP_ASTORE = 58;
  OP_ISTORE_0 = 59; OP_LSTORE_0 = 63; OP_FSTORE_0 = 67; OP_DSTORE_0 = 71; OP_ASTORE_0 = 75;
  OP_IASTORE = 79;
  OP_POP = 87; OP_POP2 = 88; OP_DUP = 89; OP_DUP_X1 = 90; OP_DUP_X2 = 91;
  OP_DUP2 = 92; OP_DUP2_X1 = 93; OP_DUP2_X2 = 94; OP_SWAP = 95;
  OP_IADD = 96; OP_ISUB = 100; OP_IMUL = 104; OP_IDIV = 108; OP_IREM = 112; OP_INEG = 116;
  OP_ISHL = 120; OP_ISHR = 122; OP_IUSHR = 124; OP_IAND = 126; OP_IOR = 128; OP_IXOR = 130;
  OP_IINC = 132;
  OP_I2L = 133; OP_I2F = 134; OP_I2D = 135; OP_L2I = 136; OP_L2F = 137; OP_L2D = 138;
  OP_F2I = 139; OP_F2L = 140; OP_F2D = 141; OP_D2I = 142; OP_D2L = 143; OP_D2F = 144;
  OP_I2B = 145; OP_I2C = 146; OP_I2S = 147;
  OP_LCMP = 148; OP_FCMPL = 149; OP_FCMPG = 150; OP_DCMPL = 151; OP_DCMPG = 152;
  OP_IFEQ = 153; OP_IFNE = 154; OP_IFLT = 155; OP_IFGE = 156; OP_IFGT = 157; OP_IFLE = 158;
  OP_IF_ICMPEQ = 159; OP_IF_ICMPNE = 160; OP_IF_ICMPLT = 161; OP_IF_ICMPGE = 162;
  OP_IF_ICMPGT = 163; OP_IF_ICMPLE = 164; OP_IF_ACMPEQ = 165; OP_IF_ACMPNE = 166;
  OP_GOTO = 167; OP_GOTO_W = 200; OP_TABLESWITCH = 170; OP_LOOKUPSWITCH = 171;
  OP_IRETURN = 172; OP_RETURN = 177;
  OP_GETSTATIC = 178; OP_PUTSTATIC = 179; OP_GETFIELD = 180; OP_PUTFIELD = 181;
  OP_INVOKEVIRTUAL = 182; OP_INVOKESPECIAL = 183; OP_INVOKESTATIC = 184;
  OP_INVOKEINTERFACE = 185; OP_INVOKEDYNAMIC = 186;
  OP_NEW = 187; OP_NEWARRAY = 188; OP_ANEWARRAY = 189; OP_ARRAYLENGTH = 190; OP_ATHROW = 191;
  OP_CHECKCAST = 192; OP_INSTANCEOF = 193; OP_MONITORENTER = 194; OP_MONITOREXIT = 195;
  OP_WIDE = 196; OP_MULTIANEWARRAY = 197; OP_IFNULL = 198; OP_IFNONNULL = 199;

Type
  TVT = Record
    Tag : Byte;
    Cls : LongInt;
    Off : LongInt;
  End;

  TLabel = Record
    Pos      : LongInt;
    HasState : Boolean;
    NeedFrame: Boolean;
    LL       : Array Of TVT;
    NLL      : LongInt;
    LS       : Array Of TVT;
    NLS      : LongInt;
    FinMask  : Int64;       { champs final definitivement affectes }
  End;

  TFrame = Record
    PC : LongInt;
    L  : Array Of TVT;
    NL : LongInt;
    S  : Array Of TVT;
    NS : LongInt;
  End;

Var
  VTNames   : Array Of String;
  NVTNames  : LongInt;
  VTMap     : TStrMap;

  Code      : TBuf;
  CurL      : Array Of TVT;
  CurFin    : Int64;         { champs final (blancs) definitivement affectes }
  CurS      : Array Of TVT;
  NSt       : LongInt;
  StDepth   : LongInt;
  MaxSt     : LongInt;
  MaxLoc    : LongInt;
  NextLoc   : LongInt;
  Alive     : Boolean;
  FatCode   : Boolean;       { sauts longs : goto_w et conditions inversees }
  JumpOverflow : Boolean;    { un saut court n'atteint pas sa cible }
  Labels    : Array Of TLabel;
  NLabels   : LongInt;
  FixPos, FixBase, FixLab : Array Of LongInt;
  FixWide   : Array Of Boolean;
  NFix      : LongInt;
  Frames    : Array Of TFrame;
  NFrames   : LongInt;
  LnPC, LnLine : Array Of LongInt;
  NLn       : LongInt;
  ExStart, ExEnd, ExHandler, ExType : Array Of LongInt;
  NEx       : LongInt;
  GenId     : LongInt;
  ThisClsName : String;
  LastLine  : LongInt;

{ ----- types de verification --------------------------------------------- }

Function VTObj(Const Name : String) : TVT;
Var I : LongInt; R : TVT;
Begin
  I := MapFind(VTMap, Name);
  If I < 0 Then Begin
    If NVTNames >= Length(VTNames) Then SetLength(VTNames, NVTNames * 2 + 64);
    VTNames[NVTNames] := Name;
    MapPut(VTMap, Name, NVTNames);
    I := NVTNames;
    Inc(NVTNames);
  End;
  R.Tag := VT_OBJECT; R.Cls := I; R.Off := 0;
  VTObj := R;
End;

Function VTName(Const V : TVT) : String;
Begin
  VTName := VTNames[V.Cls];
End;

Function VTSimple(Tag : Byte) : TVT;
Var R : TVT;
Begin
  R.Tag := Tag; R.Cls := 0; R.Off := 0;
  VTSimple := R;
End;

Function VTOfType(T : LongInt) : TVT;
Var E : LongInt;
Begin
  If T < TY_FIRSTDYN Then Begin
    Case T Of
      TY_BOOLEAN, TY_BYTE, TY_CHAR, TY_SHORT, TY_INT : VTOfType := VTSimple(VT_INT);
      TY_LONG : VTOfType := VTSimple(VT_LONG);
      TY_FLOAT : VTOfType := VTSimple(VT_FLOAT);
      TY_DOUBLE : VTOfType := VTSimple(VT_DOUBLE);
      TY_NULL : VTOfType := VTSimple(VT_NULL);
    Else
      VTOfType := VTSimple(VT_TOP);
    End;
    Exit;
  End;
  E := Erasure(T);
  VTOfType := VTObj(TypeClassName(E));
End;

Function VTEq(Const A, B : TVT) : Boolean;
Begin
  VTEq := (A.Tag = B.Tag) And (A.Cls = B.Cls) And (A.Off = B.Off);
End;

Function VTCat2(Const V : TVT) : Boolean;
Begin
  VTCat2 := (V.Tag = VT_LONG) Or (V.Tag = VT_DOUBLE);
End;

Function VTIsRef(Const V : TVT) : Boolean;
Begin
  VTIsRef := V.Tag In [VT_NULL, VT_OBJECT, VT_UNINIT, VT_UNINITTHIS];
End;

{ Un type de verification est-il assignable a un type statique (erasure) ? }
Function VTAssignable(Const V : TVT; T : LongInt) : Boolean;
Var Target, Src : LongInt; N : String; C : LongInt;
Begin
  VTAssignable := True;
  If V.Tag = VT_NULL Then Exit;
  If V.Tag <> VT_OBJECT Then Exit;
  Target := Erasure(T);
  If Target = T_OBJECT Then Exit;
  N := VTName(V);
  If N = TypeClassName(Target) Then Exit;
  If N[1] = '[' Then Begin
    { tableau : assignable a un tableau compatible ou a Object/Cloneable/Serializable }
    If IsArrayT(Target) Then Begin
      If Copy(N, 1, 2) = '[[' Then Begin
        VTAssignable := True;       { tableaux imbriques : toleres }
        Exit;
      End;
      VTAssignable := (TypeDesc(Target) = N) Or ((Copy(N, 1, 2) = '[L') And (Copy(TypeDesc(Target), 1, 2) = '[L') And
        IsSubtypeRef(ClassT(GetClass(Copy(N, 3, Length(N) - 3))), Types[Target].Elem));
      Exit;
    End;
    VTAssignable := (Target = T_OBJECT) Or (ClsOf(Target) = C_CLONEABLE) Or (ClsOf(Target) = C_SERIAL);
    Exit;
  End;
  C := LookupClass(N);
  If (C < 0) Or Not IsClassT(Target) Then Begin VTAssignable := False; Exit; End;
  Src := ClassT(C);
  VTAssignable := IsSubtypeRef(Src, Target);
End;

{ ----- pile et locales ----------------------------------------------------- }

Procedure EnsureLocal(N : LongInt);
Var I, Old : LongInt;
Begin
  If N > MaxLoc Then MaxLoc := N;
  If N > Length(CurL) Then Begin
    Old := Length(CurL);
    SetLength(CurL, N + 64);
    For I := Old To Length(CurL) - 1 Do CurL[I] := VTSimple(VT_TOP);
  End;
End;

Procedure PushVT(Const V : TVT);
Begin
  If NSt >= Length(CurS) Then SetLength(CurS, NSt * 2 + 32);
  CurS[NSt] := V;
  Inc(NSt);
  If VTCat2(V) Then Inc(StDepth, 2) Else Inc(StDepth);
  If StDepth > MaxSt Then MaxSt := StDepth;
End;

Function PopVT : TVT;
Begin
  If NSt = 0 Then Begin
    Internal('pile vide lors de la generation de code');
  End;
  Dec(NSt);
  PopVT := CurS[NSt];
  If VTCat2(CurS[NSt]) Then Dec(StDepth, 2) Else Dec(StDepth);
End;

Function TopVT : TVT;
Begin
  If NSt = 0 Then Internal('pile vide');
  TopVT := CurS[NSt - 1];
End;

{ ----- etiquettes et sauts --------------------------------------------------- }

Function NewLabel : LongInt;
Begin
  If NLabels >= Length(Labels) Then SetLength(Labels, NLabels * 2 + 32);
  Labels[NLabels].Pos := -1;
  Labels[NLabels].HasState := False;
  Labels[NLabels].NeedFrame := False;
  Labels[NLabels].NLL := 0;
  Labels[NLabels].NLS := 0;
  NewLabel := NLabels;
  Inc(NLabels);
End;

Function LastNonTop(Const A : Array Of TVT; N : LongInt) : LongInt;
Var I : LongInt;
Begin
  I := N;
  While (I > 0) And (A[I - 1].Tag = VT_TOP) Do Dec(I);
  LastNonTop := I;
End;

{ Fusionne l'etat courant dans l'etat attendu a l'etiquette L }
Procedure RecordJumpEx(L : LongInt; Mark : Boolean);
Var I, N : LongInt;
Begin
  N := LastNonTop(CurL, Length(CurL));
  If N > MaxLoc Then N := MaxLoc;
  If Not Labels[L].HasState Then Begin
    If Length(Labels[L].LL) < N Then SetLength(Labels[L].LL, N + 8);
    For I := 0 To N - 1 Do Labels[L].LL[I] := CurL[I];
    Labels[L].NLL := N;
    If Length(Labels[L].LS) < NSt Then SetLength(Labels[L].LS, NSt + 8);
    For I := 0 To NSt - 1 Do Labels[L].LS[I] := CurS[I];
    Labels[L].NLS := NSt;
    Labels[L].FinMask := CurFin;
    Labels[L].HasState := True;
  End
  Else Begin
    If Labels[L].NLS <> NSt Then Internal('hauteurs de pile differentes a une jonction (ligne ' + IStr(LastLine) + ')');
    Labels[L].FinMask := Labels[L].FinMask And CurFin;
    { locales : intersection }
    For I := 0 To Labels[L].NLL - 1 Do Begin
      If I >= N Then Labels[L].LL[I] := VTSimple(VT_TOP)
      Else If Not VTEq(Labels[L].LL[I], CurL[I]) Then Labels[L].LL[I] := VTSimple(VT_TOP);
    End;
    Labels[L].NLL := LastNonTop(Labels[L].LL, Labels[L].NLL);
    For I := 0 To NSt - 1 Do
      If Not VTEq(Labels[L].LS[I], CurS[I]) Then Begin
        { references de types differents : on garde la premiere }
        If Not (VTIsRef(Labels[L].LS[I]) And VTIsRef(CurS[I])) Then
          Internal('types de pile differents a une jonction (ligne ' + IStr(LastLine) + ')');
        If Labels[L].LS[I].Tag = VT_NULL Then Labels[L].LS[I] := CurS[I];
      End;
  End;
  If Mark Then Labels[L].NeedFrame := True;
End;

Procedure RecordJump(L : LongInt);
Begin
  RecordJumpEx(L, True);
End;

Procedure AddFrame(PC : LongInt);
Var I, N, K : LongInt;
Begin
  { remplace un cadre existant au meme PC }
  K := -1;
  For I := 0 To NFrames - 1 Do If Frames[I].PC = PC Then K := I;
  If K < 0 Then Begin
    If NFrames >= Length(Frames) Then SetLength(Frames, NFrames * 2 + 16);
    K := NFrames;
    Inc(NFrames);
  End;
  Frames[K].PC := PC;
  N := LastNonTop(CurL, Length(CurL));
  If N > MaxLoc Then N := MaxLoc;
  SetLength(Frames[K].L, N + 1);
  For I := 0 To N - 1 Do Frames[K].L[I] := CurL[I];
  Frames[K].NL := N;
  SetLength(Frames[K].S, NSt + 1);
  For I := 0 To NSt - 1 Do Frames[K].S[I] := CurS[I];
  Frames[K].NS := NSt;
End;

{ Place l'etiquette ici : fusionne l'etat qui arrive en tombant dedans (Alive) }
Procedure PlaceLabel(L : LongInt);
Var I : LongInt;
Begin
  If Alive Then RecordJumpEx(L, False);
  Labels[L].Pos := Code.N;
  If Not Labels[L].HasState Then Exit;      { code mort }
  { l'etat courant devient celui de l'etiquette }
  CurFin := Labels[L].FinMask;
  EnsureLocal(Labels[L].NLL);
  For I := 0 To Length(CurL) - 1 Do CurL[I] := VTSimple(VT_TOP);
  For I := 0 To Labels[L].NLL - 1 Do CurL[I] := Labels[L].LL[I];
  NSt := 0; StDepth := 0;
  For I := 0 To Labels[L].NLS - 1 Do PushVT(Labels[L].LS[I]);
  Alive := True;
  If Labels[L].NeedFrame Then AddFrame(Code.N);
End;

{ Etiquette d'une boucle (cible de sauts arriere) : cadre force }
Procedure PlaceLoopLabel(L : LongInt);
Begin
  Labels[L].NeedFrame := True;
  PlaceLabel(L);
  If Alive Then AddFrame(Code.N);
  If Not Labels[L].HasState Then Begin
    { ne devrait pas arriver : une boucle est toujours atteinte }
  End;
End;

Procedure AddFixup(Pos, Base, Lab : LongInt; Wide : Boolean);
Begin
  If NFix >= Length(FixPos) Then Begin
    SetLength(FixPos, NFix * 2 + 32); SetLength(FixBase, NFix * 2 + 32);
    SetLength(FixLab, NFix * 2 + 32); SetLength(FixWide, NFix * 2 + 32);
  End;
  FixPos[NFix] := Pos; FixBase[NFix] := Base; FixLab[NFix] := Lab; FixWide[NFix] := Wide;
  Inc(NFix);
End;

{ Ecrit un deplacement de saut vers Lab (instruction commencant en Base) }
Procedure EmitOffset(Base, Lab : LongInt; Wide : Boolean);
Begin
  If Labels[Lab].Pos >= 0 Then Begin
    If Wide Then B4(Code, Labels[Lab].Pos - Base)
    Else Begin
      If (Labels[Lab].Pos - Base < -32768) Or (Labels[Lab].Pos - Base > 32767) Then JumpOverflow := True;
      B2(Code, Labels[Lab].Pos - Base);
    End;
  End
  Else Begin
    AddFixup(Code.N, Base, Lab, Wide);
    If Wide Then B4(Code, 0) Else B2(Code, 0);
  End;
End;

Procedure ResolveFixups;
Var I, Off : LongInt;
Begin
  For I := 0 To NFix - 1 Do Begin
    If Labels[FixLab[I]].Pos < 0 Then Internal('etiquette non placee');
    Off := Labels[FixLab[I]].Pos - FixBase[I];
    If FixWide[I] Then BPatch4(Code, FixPos[I], Off)
    Else Begin
      If (Off < -32768) Or (Off > 32767) Then JumpOverflow := True;
      BPatch2(Code, FixPos[I], Off);
    End;
  End;
End;

{ ----- emission d'instructions ----------------------------------------------- }

Procedure LineMark(Line : LongInt);
Begin
  If Line <= 0 Then Exit;
  LastLine := Line;
  If NLn > 0 Then
    If (LnPC[NLn - 1] = Code.N) Then Begin LnLine[NLn - 1] := Line; Exit; End
    Else If LnLine[NLn - 1] = Line Then Exit;
  If NLn >= Length(LnPC) Then Begin SetLength(LnPC, NLn * 2 + 32); SetLength(LnLine, NLn * 2 + 32); End;
  LnPC[NLn] := Code.N; LnLine[NLn] := Line;
  Inc(NLn);
End;

Procedure EmitConstInt(V : LongInt);
Begin
  If (V >= -1) And (V <= 5) Then B1(Code, OP_ICONST_0 + V)
  Else If (V >= -128) And (V <= 127) Then Begin B1(Code, OP_BIPUSH); B1(Code, V And $FF); End
  Else If (V >= -32768) And (V <= 32767) Then Begin B1(Code, OP_SIPUSH); B2(Code, V And $FFFF); End
  Else Begin
    V := CPInt(V);
    If V < 256 Then Begin B1(Code, OP_LDC); B1(Code, V); End
    Else Begin B1(Code, OP_LDC_W); B2(Code, V); End;
  End;
  PushVT(VTSimple(VT_INT));
End;

Procedure EmitLdcIdx(Idx : LongInt; Const V : TVT);
Begin
  If Idx < 256 Then Begin B1(Code, OP_LDC); B1(Code, Idx); End
  Else Begin B1(Code, OP_LDC_W); B2(Code, Idx); End;
  PushVT(V);
End;

Procedure EmitConstLong(V : Int64);
Begin
  If (V = 0) Or (V = 1) Then B1(Code, OP_LCONST_0 + V)
  Else Begin B1(Code, OP_LDC2_W); B2(Code, CPLong(V)); End;
  PushVT(VTSimple(VT_LONG));
End;

Procedure EmitConstFloat(D : Double);
Var Bits : TDblBits;
Begin
  Bits.I := 0;
  Bits.S := D;
  If (Bits.L = 0) Then Begin B1(Code, OP_FCONST_0); PushVT(VTSimple(VT_FLOAT)); End
  Else If Bits.L = $3F800000 Then Begin B1(Code, OP_FCONST_0 + 1); PushVT(VTSimple(VT_FLOAT)); End
  Else If Bits.L = $40000000 Then Begin B1(Code, OP_FCONST_0 + 2); PushVT(VTSimple(VT_FLOAT)); End
  Else EmitLdcIdx(CPFloat(Bits.L), VTSimple(VT_FLOAT));
End;

Procedure EmitConstDouble(D : Double);
Var Bits : TDblBits;
Begin
  Bits.D := D;
  If Bits.I = 0 Then B1(Code, OP_DCONST_0)
  Else If Bits.I = $3FF0000000000000 Then B1(Code, OP_DCONST_0 + 1)
  Else Begin B1(Code, OP_LDC2_W); B2(Code, CPDouble(Bits.I)); End;
  PushVT(VTSimple(VT_DOUBLE));
End;

Procedure EmitConstString(Const S : String);
Begin
  EmitLdcIdx(CPString(S), VTObj('java/lang/String'));
End;

Procedure EmitConstClass(Const Name : String);
Begin
  EmitLdcIdx(CPClass(Name), VTObj('java/lang/Class'));
End;

Procedure EmitNull;
Begin
  B1(Code, OP_ACONST_NULL);
  PushVT(VTSimple(VT_NULL));
End;

Function KindOf(T : LongInt) : Char;
Begin
  Case T Of
    TY_LONG : KindOf := 'J';
    TY_FLOAT : KindOf := 'F';
    TY_DOUBLE : KindOf := 'D';
    TY_BOOLEAN, TY_BYTE, TY_CHAR, TY_SHORT, TY_INT : KindOf := 'I';
  Else
    KindOf := 'A';
  End;
End;

Function KindIdx(K : Char) : LongInt;
Begin
  Case K Of
    'I' : KindIdx := 0;
    'J' : KindIdx := 1;
    'F' : KindIdx := 2;
    'D' : KindIdx := 3;
  Else
    KindIdx := 4;
  End;
End;

Procedure EmitLoad(K : Char; Slot : LongInt);
Var Ki : LongInt; V : TVT;
Begin
  Ki := KindIdx(K);
  If Slot < 4 Then B1(Code, OP_ILOAD_0 + Ki * 4 + Slot)
  Else If Slot < 256 Then Begin B1(Code, OP_ILOAD + Ki); B1(Code, Slot); End
  Else Begin B1(Code, OP_WIDE); B1(Code, OP_ILOAD + Ki); B2(Code, Slot); End;
  EnsureLocal(Slot + 1);
  V := CurL[Slot];
  Case K Of
    'I' : V := VTSimple(VT_INT);
    'J' : V := VTSimple(VT_LONG);
    'F' : V := VTSimple(VT_FLOAT);
    'D' : V := VTSimple(VT_DOUBLE);
  End;
  PushVT(V);
End;

Procedure EmitStore(K : Char; Slot : LongInt; Const V : TVT);
Var Ki : LongInt; Top : TVT;
Begin
  Ki := KindIdx(K);
  If Slot < 4 Then B1(Code, OP_ISTORE_0 + Ki * 4 + Slot)
  Else If Slot < 256 Then Begin B1(Code, OP_ISTORE + Ki); B1(Code, Slot); End
  Else Begin B1(Code, OP_WIDE); B1(Code, OP_ISTORE + Ki); B2(Code, Slot); End;
  Top := PopVT;
  EnsureLocal(Slot + 2);
  CurL[Slot] := V;
  If VTCat2(V) Then CurL[Slot + 1] := VTSimple(VT_SECOND);
  { un ancien deuxieme mot de long/double devient invalide }
  If (Slot > 0) And VTCat2(CurL[Slot - 1]) Then CurL[Slot - 1] := VTSimple(VT_TOP);
End;

Procedure EmitIinc(Slot, Delta : LongInt);
Begin
  If (Slot < 256) And (Delta >= -128) And (Delta <= 127) Then Begin
    B1(Code, OP_IINC); B1(Code, Slot); B1(Code, Delta And $FF);
  End
  Else Begin
    B1(Code, OP_WIDE); B1(Code, OP_IINC); B2(Code, Slot); B2(Code, Delta And $FFFF);
  End;
End;

{ Operation sans operande : arithmetique, comparaison, conversion, tableaux... }
Procedure EmitSimple(Op : LongInt; Const PopPat, PushPat : String);
Var I : LongInt;
Begin
  B1(Code, Op);
  For I := 1 To Length(PopPat) Do PopVT;
  For I := 1 To Length(PushPat) Do Begin
    Case PushPat[I] Of
      'I' : PushVT(VTSimple(VT_INT));
      'J' : PushVT(VTSimple(VT_LONG));
      'F' : PushVT(VTSimple(VT_FLOAT));
      'D' : PushVT(VTSimple(VT_DOUBLE));
    End;
  End;
End;

{ Arithmetique binaire de type K : base = opcode de la version int }
Procedure EmitArith(BaseOp : LongInt; K : Char);
Var Ki : LongInt;
Begin
  Ki := KindIdx(K);
  EmitSimple(BaseOp + Ki, K + K, K);
End;

Procedure EmitNeg(K : Char);
Begin
  EmitSimple(OP_INEG + KindIdx(K), K, K);
End;

Procedure EmitShift(BaseOp : LongInt; K : Char);
{ BaseOp : ishl / ishr / iushr ; K : I ou J ; le compte de decalage est un int }
Var Op : LongInt;
Begin
  If K = 'J' Then Op := BaseOp + 1 Else Op := BaseOp;
  EmitSimple(Op, K + 'I', K);
End;

Procedure EmitLogic(BaseOp : LongInt; K : Char);
Var Op : LongInt;
Begin
  If K = 'J' Then Op := BaseOp + 1 Else Op := BaseOp;
  EmitSimple(Op, K + K, K);
End;

Procedure EmitPrimConv(From, To_ : LongInt);
{ conversion primitive entre types de la JVM (int-like, long, float, double) et
  retrecissement vers byte / short / char }
Var Kf, Kt : Char;
Begin
  Kf := KindOf(From); Kt := KindOf(To_);
  If Kf <> Kt Then Begin
    Case Kf Of
      'I' : Case Kt Of
        'J' : EmitSimple(OP_I2L, 'I', 'J');
        'F' : EmitSimple(OP_I2F, 'I', 'F');
        'D' : EmitSimple(OP_I2D, 'I', 'D');
      End;
      'J' : Case Kt Of
        'I' : EmitSimple(OP_L2I, 'J', 'I');
        'F' : EmitSimple(OP_L2F, 'J', 'F');
        'D' : EmitSimple(OP_L2D, 'J', 'D');
      End;
      'F' : Case Kt Of
        'I' : EmitSimple(OP_F2I, 'F', 'I');
        'J' : EmitSimple(OP_F2L, 'F', 'J');
        'D' : EmitSimple(OP_F2D, 'F', 'D');
      End;
      'D' : Case Kt Of
        'I' : EmitSimple(OP_D2I, 'D', 'I');
        'J' : EmitSimple(OP_D2L, 'D', 'J');
        'F' : EmitSimple(OP_D2F, 'D', 'F');
      End;
    End;
  End;
  { retrecissement vers byte / short / char depuis int, long, float, double }
  If To_ In [TY_BYTE, TY_SHORT, TY_CHAR] Then Begin
    If (From <> To_) And Not ((From = TY_BYTE) And (To_ = TY_SHORT)) Then
      Case To_ Of
        TY_BYTE : EmitSimple(OP_I2B, 'I', 'I');
        TY_CHAR : EmitSimple(OP_I2C, 'I', 'I');
        TY_SHORT : EmitSimple(OP_I2S, 'I', 'I');
      End;
  End;
End;

Procedure EmitPop(T : LongInt);
Begin
  Case TypeSize(T) Of
    1 : Begin B1(Code, OP_POP); PopVT; End;
    2 : Begin B1(Code, OP_POP2); PopVT; End;
  End;
End;

Procedure EmitDupValue;
Var V : TVT;
Begin
  V := TopVT;
  If VTCat2(V) Then B1(Code, OP_DUP2) Else B1(Code, OP_DUP);
  PushVT(V);
End;

{ Duplique la valeur du sommet en dessous de Depth entrees de categorie 1 }
Procedure EmitDupX(Depth : LongInt);
Var V : TVT; Saved : Array[0..3] Of TVT; I : LongInt; C2 : Boolean;
Begin
  V := PopVT;
  C2 := VTCat2(V);
  For I := 0 To Depth - 1 Do Saved[I] := PopVT;
  If C2 Then Begin
    Case Depth Of
      0 : B1(Code, OP_DUP2);
      1 : B1(Code, OP_DUP2_X1);
    Else
      B1(Code, OP_DUP2_X2);
    End;
  End
  Else Begin
    Case Depth Of
      0 : B1(Code, OP_DUP);
      1 : B1(Code, OP_DUP_X1);
    Else
      B1(Code, OP_DUP_X2);
    End;
  End;
  PushVT(V);
  For I := Depth - 1 Downto 0 Do PushVT(Saved[I]);
  PushVT(V);
End;

{ dup2 de deux entrees de categorie 1 (tableau + indice) }
Procedure EmitDup2Cat1;
Var A, B : TVT;
Begin
  A := PopVT; B := PopVT;
  B1(Code, OP_DUP2);
  PushVT(B); PushVT(A); PushVT(B); PushVT(A);
End;

Procedure EmitSwap;
Var A, B : TVT;
Begin
  A := PopVT; B := PopVT;
  B1(Code, OP_SWAP);
  PushVT(A); PushVT(B);
End;

Procedure EmitJump(Op : LongInt; Lab : LongInt);
Var Pc0, N, Inv : LongInt;
Begin
  Pc0 := Code.N;
  Case Op Of
    OP_GOTO : N := 0;
    OP_IFEQ..OP_IFLE, OP_IFNULL, OP_IFNONNULL : N := 1;
    OP_IF_ICMPEQ..OP_IF_ACMPNE : N := 2;
  Else
    N := 0;
  End;
  If FatCode Then Begin
    { sauts longs : goto_w, ou condition inversee qui saute par-dessus un goto_w }
    If Op = OP_GOTO Then Begin
      B1(Code, OP_GOTO_W);
      EmitOffset(Pc0, Lab, True);
      RecordJump(Lab);
      Alive := False;
    End
    Else Begin
      If (Op = OP_IFNULL) Or (Op = OP_IFNONNULL) Then Inv := (OP_IFNULL + OP_IFNONNULL) - Op
      Else Inv := ((Op - OP_IFEQ) Xor 1) + OP_IFEQ;
      B1(Code, Inv);
      B2(Code, 8);
      While N > 0 Do Begin PopVT; Dec(N); End;
      B1(Code, OP_GOTO_W);
      EmitOffset(Pc0 + 3, Lab, True);
      RecordJump(Lab);
      AddFrame(Code.N);
    End;
    Exit;
  End;
  B1(Code, Op);
  While N > 0 Do Begin PopVT; Dec(N); End;
  EmitOffset(Pc0, Lab, False);
  RecordJump(Lab);
  If Op = OP_GOTO Then Alive := False;
End;

{ Fin d'une methode / instruction terminale }
Procedure FinCheckReturn; Forward;

Procedure EmitReturnOp(K : Char);
Begin
  If K = 'V' Then FinCheckReturn;
  Case K Of
    'V' : B1(Code, OP_RETURN);
    'I' : Begin B1(Code, OP_IRETURN); PopVT; End;
    'J' : Begin B1(Code, OP_IRETURN + 1); PopVT; End;
    'F' : Begin B1(Code, OP_IRETURN + 2); PopVT; End;
    'D' : Begin B1(Code, OP_IRETURN + 3); PopVT; End;
  Else
    B1(Code, OP_IRETURN + 4); PopVT;
  End;
  Alive := False;
End;

Procedure EmitThrow;
Begin
  B1(Code, OP_ATHROW);
  PopVT;
  Alive := False;
End;

{ ----- tableaux ------------------------------------------------------------ }

Function ArrayElemVT(Const Arr : TVT) : TVT;
Var N : String;
Begin
  If Arr.Tag <> VT_OBJECT Then Begin ArrayElemVT := VTSimple(VT_NULL); Exit; End;
  N := VTName(Arr);
  If (Length(N) < 2) Or (N[1] <> '[') Then Begin ArrayElemVT := VTObj('java/lang/Object'); Exit; End;
  Case N[2] Of
    'L' : ArrayElemVT := VTObj(Copy(N, 3, Length(N) - 3));
    '[' : ArrayElemVT := VTObj(Copy(N, 2, Length(N)));
  Else
    ArrayElemVT := VTSimple(VT_INT);
  End;
End;

Procedure EmitArrayLoad(ElemT : LongInt);
Var Arr, V : TVT; Op : LongInt;
Begin
  PopVT;                       { indice }
  Arr := PopVT;
  Case ElemT Of
    TY_INT : Op := OP_IALOAD;
    TY_LONG : Op := OP_IALOAD + 1;
    TY_FLOAT : Op := OP_IALOAD + 2;
    TY_DOUBLE : Op := OP_IALOAD + 3;
    TY_BYTE, TY_BOOLEAN : Op := OP_IALOAD + 5;
    TY_CHAR : Op := OP_IALOAD + 6;
    TY_SHORT : Op := OP_IALOAD + 7;
  Else
    Op := OP_IALOAD + 4;
  End;
  B1(Code, Op);
  Case ElemT Of
    TY_LONG : V := VTSimple(VT_LONG);
    TY_FLOAT : V := VTSimple(VT_FLOAT);
    TY_DOUBLE : V := VTSimple(VT_DOUBLE);
    TY_INT, TY_BYTE, TY_BOOLEAN, TY_CHAR, TY_SHORT : V := VTSimple(VT_INT);
  Else
    V := ArrayElemVT(Arr);
  End;
  PushVT(V);
End;

Procedure EmitArrayStore(ElemT : LongInt);
Var Op : LongInt;
Begin
  PopVT; PopVT; PopVT;
  Case ElemT Of
    TY_INT : Op := OP_IASTORE;
    TY_LONG : Op := OP_IASTORE + 1;
    TY_FLOAT : Op := OP_IASTORE + 2;
    TY_DOUBLE : Op := OP_IASTORE + 3;
    TY_BYTE, TY_BOOLEAN : Op := OP_IASTORE + 5;
    TY_CHAR : Op := OP_IASTORE + 6;
    TY_SHORT : Op := OP_IASTORE + 7;
  Else
    Op := OP_IASTORE + 4;
  End;
  B1(Code, Op);
End;

Procedure EmitNewArray(ElemT : LongInt);
Var AType : LongInt;
Begin
  PopVT;
  If IsPrim(ElemT) Then Begin
    Case ElemT Of
      TY_BOOLEAN : AType := 4;
      TY_CHAR : AType := 5;
      TY_FLOAT : AType := 6;
      TY_DOUBLE : AType := 7;
      TY_BYTE : AType := 8;
      TY_SHORT : AType := 9;
      TY_INT : AType := 10;
    Else
      AType := 11;
    End;
    B1(Code, OP_NEWARRAY);
    B1(Code, AType);
    PushVT(VTObj('[' + TypeDesc(ElemT)));
  End
  Else Begin
    B1(Code, OP_ANEWARRAY);
    B2(Code, CPClass(TypeClassName(ElemT)));
    PushVT(VTObj('[' + TypeDesc(Erasure(ElemT))));
  End;
End;

Procedure EmitArrayLength;
Begin
  PopVT;
  B1(Code, OP_ARRAYLENGTH);
  PushVT(VTSimple(VT_INT));
End;

{ ----- objets, champs, appels --------------------------------------------- }

Procedure EmitNew(Const ClsName : String);
Var V : TVT;
Begin
  V.Tag := VT_UNINIT; V.Cls := 0; V.Off := Code.N;
  B1(Code, OP_NEW);
  B2(Code, CPClass(ClsName));
  PushVT(V);
End;

Procedure EmitCheckcast(Const ClsName : String);
Begin
  PopVT;
  B1(Code, OP_CHECKCAST);
  B2(Code, CPClass(ClsName));
  PushVT(VTObj(ClsName));
End;

Procedure EmitInstanceof(Const ClsName : String);
Begin
  PopVT;
  B1(Code, OP_INSTANCEOF);
  B2(Code, CPClass(ClsName));
  PushVT(VTSimple(VT_INT));
End;

Procedure EmitGetField(Static : Boolean; Const Owner, Name, Desc : String; FT : LongInt);
Begin
  If Static Then B1(Code, OP_GETSTATIC)
  Else Begin B1(Code, OP_GETFIELD); PopVT; End;
  B2(Code, CPField(Owner, Name, Desc));
  PushVT(VTOfType(FT));
End;

Procedure EmitPutField(Static : Boolean; Const Owner, Name, Desc : String);
Begin
  If Static Then B1(Code, OP_PUTSTATIC)
  Else B1(Code, OP_PUTFIELD);
  PopVT;
  If Not Static Then PopVT;
  B2(Code, CPField(Owner, Name, Desc));
End;

Function DescParamCount(Const D : String) : LongInt;
Var I, N : LongInt;
Begin
  N := 0;
  I := 2;
  While (I <= Length(D)) And (D[I] <> ')') Do Begin
    Inc(N);
    While D[I] = '[' Do Inc(I);
    If D[I] = 'L' Then Begin
      While D[I] <> ';' Do Inc(I);
    End;
    Inc(I);
  End;
  DescParamCount := N;
End;

Function DescParamSlots(Const D : String) : LongInt;
Var I, N : LongInt; Arr : Boolean;
Begin
  N := 0;
  I := 2;
  While (I <= Length(D)) And (D[I] <> ')') Do Begin
    Arr := False;
    While D[I] = '[' Do Begin Inc(I); Arr := True; End;
    If D[I] = 'L' Then Begin
      While D[I] <> ';' Do Inc(I);
      Inc(N);
    End
    Else If (Not Arr) And ((D[I] = 'J') Or (D[I] = 'D')) Then Inc(N, 2)
    Else Inc(N);
    Inc(I);
  End;
  DescParamSlots := N;
End;

Function DescRetType(Const D : String) : String;
Var I : LongInt;
Begin
  I := Pos(')', D);
  DescRetType := Copy(D, I + 1, Length(D));
End;

Function VTOfDesc(Const D : String) : TVT;
Begin
  Case D[1] Of
    'Z', 'B', 'C', 'S', 'I' : VTOfDesc := VTSimple(VT_INT);
    'J' : VTOfDesc := VTSimple(VT_LONG);
    'F' : VTOfDesc := VTSimple(VT_FLOAT);
    'D' : VTOfDesc := VTSimple(VT_DOUBLE);
    'L' : VTOfDesc := VTObj(Copy(D, 2, Length(D) - 2));
    '[' : VTOfDesc := VTObj(D);
  Else
    VTOfDesc := VTSimple(VT_TOP);
  End;
End;

{ Remplace les occurrences d'un objet non initialise par l'objet initialise }
Procedure InitializeObject(Const U : TVT; Const Init : TVT);
Var I : LongInt;
Begin
  For I := 0 To NSt - 1 Do If VTEq(CurS[I], U) Then CurS[I] := Init;
  For I := 0 To Length(CurL) - 1 Do If VTEq(CurL[I], U) Then CurL[I] := Init;
End;

Procedure EmitInvoke(Op : LongInt; Const Owner, Name, Desc : String; Iface : Boolean);
Var N, I : LongInt; Recv, R : TVT; Ret : String; Slots : LongInt;
Begin
  N := DescParamCount(Desc);
  Slots := DescParamSlots(Desc);
  B1(Code, Op);
  If Op = OP_INVOKEINTERFACE Then Begin
    B2(Code, CPMethod(Owner, Name, Desc, True));
    B1(Code, Slots + 1);
    B1(Code, 0);
  End
  Else B2(Code, CPMethod(Owner, Name, Desc, Iface));
  For I := 1 To N Do PopVT;
  If Op <> OP_INVOKESTATIC Then Begin
    Recv := PopVT;
    If Name = '<init>' Then Begin
      If Recv.Tag = VT_UNINITTHIS Then InitializeObject(Recv, VTObj(ThisClsName))
      Else InitializeObject(Recv, VTObj(Owner));
    End;
  End;
  Ret := DescRetType(Desc);
  If Ret <> 'V' Then PushVT(VTOfDesc(Ret));
End;

Procedure EmitInvokeDynamic(Bsm : LongInt; Const Name, Desc : String);
Var N, I : LongInt; Ret : String;
Begin
  N := DescParamCount(Desc);
  B1(Code, OP_INVOKEDYNAMIC);
  B2(Code, CPInvokeDynamic(Bsm, Name, Desc));
  B2(Code, 0);
  For I := 1 To N Do PopVT;
  Ret := DescRetType(Desc);
  If Ret <> 'V' Then PushVT(VTOfDesc(Ret));
End;

Procedure EmitMonitor(Enter : Boolean);
Begin
  PopVT;
  If Enter Then B1(Code, OP_MONITORENTER) Else B1(Code, OP_MONITOREXIT);
End;

{ ----- switch --------------------------------------------------------------- }

Procedure EmitTableSwitch(Lo, Hi : LongInt; Const Targets : Array Of LongInt; Dflt : LongInt);
Var Pc0, I : LongInt;
Begin
  Pc0 := Code.N;
  PopVT;
  B1(Code, OP_TABLESWITCH);
  While Code.N Mod 4 <> 0 Do B1(Code, 0);
  EmitOffset(Pc0, Dflt, True);
  B4(Code, Lo And $FFFFFFFF);
  B4(Code, Hi And $FFFFFFFF);
  RecordJump(Dflt);
  For I := 0 To Hi - Lo Do Begin
    EmitOffset(Pc0, Targets[I], True);
    RecordJump(Targets[I]);
  End;
  Alive := False;
End;

Procedure EmitLookupSwitch(N : LongInt; Const Keys : Array Of LongInt; Const Targets : Array Of LongInt; Dflt : LongInt);
Var Pc0, I : LongInt;
Begin
  Pc0 := Code.N;
  PopVT;
  B1(Code, OP_LOOKUPSWITCH);
  While Code.N Mod 4 <> 0 Do B1(Code, 0);
  EmitOffset(Pc0, Dflt, True);
  B4(Code, N);
  RecordJump(Dflt);
  For I := 0 To N - 1 Do Begin
    B4(Code, Keys[I] And $FFFFFFFF);
    EmitOffset(Pc0, Targets[I], True);
    RecordJump(Targets[I]);
  End;
  Alive := False;
End;

{ ----- gestionnaires d'exceptions ----------------------------------------- }

Procedure AddHandlerEntry(S, E, H, T : LongInt);
Begin
  If S >= E Then Exit;
  If NEx >= Length(ExStart) Then Begin
    SetLength(ExStart, NEx * 2 + 8); SetLength(ExEnd, NEx * 2 + 8);
    SetLength(ExHandler, NEx * 2 + 8); SetLength(ExType, NEx * 2 + 8);
  End;
  ExStart[NEx] := S; ExEnd[NEx] := E; ExHandler[NEx] := H; ExType[NEx] := T;
  Inc(NEx);
End;

{ ----- debut / fin de methode -------------------------------------------- }

Procedure BeginMethod;
Var I : LongInt;
Begin
  BInit(Code);
  Code.N := 0;
  If Length(CurL) < 64 Then SetLength(CurL, 64);
  For I := 0 To Length(CurL) - 1 Do CurL[I] := VTSimple(VT_TOP);
  NSt := 0; StDepth := 0; MaxSt := 0; MaxLoc := 0; NextLoc := 0;
  Alive := True;
  NLabels := 0; NFix := 0; NFrames := 0; NLn := 0; NEx := 0;
  LastLine := 0;
  CurFin := 0;
  Inc(GenId);
End;

{ Ecrit la StackMapTable des cadres enregistres (cadres complets) }
Procedure WriteStackMap(Var B : TBuf);
Var I, J, K, Prev : LongInt; Body : TBuf; Order : Array Of LongInt; Tmp, Cnt : LongInt;
  Procedure WVT(Const V : TVT);
  Begin
    B1(Body, V.Tag);
    If V.Tag = VT_OBJECT Then B2(Body, CPClass(VTName(V)))
    Else If V.Tag = VT_UNINIT Then B2(Body, V.Off);
  End;
Begin
  If NFrames = 0 Then Exit;
  SetLength(Order, NFrames);
  For I := 0 To NFrames - 1 Do Order[I] := I;
  { tri par PC }
  For I := 1 To NFrames - 1 Do Begin
    Tmp := Order[I];
    J := I - 1;
    While (J >= 0) And (Frames[Order[J]].PC > Frames[Tmp].PC) Do Begin Order[J + 1] := Order[J]; Dec(J); End;
    Order[J + 1] := Tmp;
  End;
  BInit(Body);
  Prev := -1;
  Cnt := 0;
  For I := 0 To NFrames - 1 Do Begin
    K := Order[I];
    If Frames[K].PC >= Code.N Then Continue;      { cadre au-dela de la fin du code }
    B1(Body, 255);
    If Prev < 0 Then B2(Body, Frames[K].PC) Else B2(Body, Frames[K].PC - Prev - 1);
    Prev := Frames[K].PC;
    { locales (le second mot des long / double est omis) }
    Tmp := 0;
    For J := 0 To Frames[K].NL - 1 Do If Frames[K].L[J].Tag <> VT_SECOND Then Inc(Tmp);
    B2(Body, Tmp);
    For J := 0 To Frames[K].NL - 1 Do If Frames[K].L[J].Tag <> VT_SECOND Then WVT(Frames[K].L[J]);
    B2(Body, Frames[K].NS);
    For J := 0 To Frames[K].NS - 1 Do WVT(Frames[K].S[J]);
    Inc(Cnt);
  End;
  If Cnt = 0 Then Exit;
  B2(B, CPUtf8('StackMapTable'));
  B4(B, Body.N + 2);
  B2(B, Cnt);
  BAppend(B, Body);
End;

{ ============================================================================
  5. GENERATION DU BYTECODE (2/3) : expressions
  ============================================================================ }

Const
  GC_LOOP = 1; GC_SWITCH = 2; GC_LABEL = 3; GC_TRY = 4; GC_SWEXPR = 5;
  FIN_NONE = 0; FIN_BLOCK = 1; FIN_MONITOR = 2; FIN_TWR = 3;

Type
  TGenCtx = Record
    Kind    : Byte;
    Name    : String;
    BreakL  : LongInt;
    ContL   : LongInt;
    FinKind : Byte;
    FinNode : LongInt;
    FinSlot : LongInt;
    FinSlot2: LongInt;
    RStart  : LongInt;
    Mode    : Byte;
    R1      : Array Of LongInt;
    N1      : LongInt;
    R2      : Array Of LongInt;
    N2      : LongInt;
    ResType : LongInt;
    LocMark : LongInt;
  End;

Var
  GCtx      : Array Of TGenCtx;
  NGCtx     : LongInt;
  GenCls    : LongInt;
  GenMeth   : LongInt;
  GenStatic : Boolean;
  GenRet    : LongInt;
  PendingLabelCtx : LongInt;
  { table des methodes d'amorcage (BootstrapMethods) de la classe en cours }
  BsmBuf    : TBuf;
  BsmCount  : LongInt;
  LambdaCount : LongInt;

Procedure GenExpr(N : LongInt); Forward;
Procedure GenExprDiscard(N : LongInt); Forward;
Procedure GenBranch(N, Target : LongInt; JumpIf : Boolean); Forward;
Procedure GenStmt(N : LongInt); Forward;
Procedure GenBoolValue(N : LongInt); Forward;
Procedure GenArrayInit(N, ArrT : LongInt); Forward;
Procedure GenPatternMatch(Pat, Slot, ValT, Fail : LongInt); Forward;

{ ----- variables locales ---------------------------------------------------- }

Function AllocSlot(T : LongInt) : LongInt;
Var Sz : LongInt;
Begin
  Sz := TypeSize(T);
  If Sz = 0 Then Sz := 1;
  AllocSlot := NextLoc;
  EnsureLocal(NextLoc + Sz + 1);
  CurL[NextLoc] := VTSimple(VT_TOP);
  If Sz = 2 Then CurL[NextLoc + 1] := VTSimple(VT_TOP);
  Inc(NextLoc, Sz);
End;

Function DeclSlot(L : LongInt) : LongInt;
Var S : LongInt;
Begin
  S := AllocSlot(Locals[L].Typ);
  Locals[L].Slot := S;
  Locals[L].SlotOwner := GenId;
  DeclSlot := S;
End;

Procedure FreeLocals(Mark : LongInt);
Var I : LongInt;
Begin
  For I := Mark To Length(CurL) - 1 Do CurL[I] := VTSimple(VT_TOP);
  NextLoc := Mark;
End;

Function SlotOf(L : LongInt) : LongInt;
Begin
  If Locals[L].SlotOwner = GenId Then SlotOf := Locals[L].Slot Else SlotOf := -1;
End;

Procedure StoreLocal(L : LongInt);
Var S : LongInt;
Begin
  S := SlotOf(L);
  If S < 0 Then Internal('variable locale sans emplacement : ' + Locals[L].Name);
  EmitStore(KindOf(Locals[L].Typ), S, VTOfType(Locals[L].Typ));
End;

Function CapIndex(C, L : LongInt) : LongInt;
Var I : LongInt;
Begin
  CapIndex := -1;
  For I := 0 To Length(Classes[C].Caps) - 1 Do
    If Classes[C].Caps[I] = L Then Begin CapIndex := I; Exit; End;
End;

Procedure EmitThis;
Begin
  EmitLoad('A', 0);
End;

Procedure LoadLocalCheck(L, Line : LongInt);
Var S : LongInt;
Begin
  S := SlotOf(L);
  If S < 0 Then Exit;
  EnsureLocal(S + 2);
  If (CurL[S].Tag = VT_TOP) Or (CurL[S].Tag = VT_SECOND) Then
    Err(Line, 'la variable ' + Locals[L].Name + ' n''a peut-etre pas ete initialisee');
End;

Function BoxClassNameOrVoid(T : LongInt) : String;
Begin
  If T = TY_VOID Then BoxClassNameOrVoid := 'java/lang/Void' Else BoxClassNameOrVoid := BoxClassName(T);
End;

Procedure LoadLocal(L, Line : LongInt);
Var S, K, F : LongInt;
Begin
  S := SlotOf(L);
  If S >= 0 Then Begin
    EnsureLocal(S + 2);
    If (CurL[S].Tag = VT_TOP) Or (CurL[S].Tag = VT_SECOND) Then
      Err(Line, 'la variable ' + Locals[L].Name + ' n''a peut-etre pas ete initialisee');
    EmitLoad(KindOf(Locals[L].Typ), S);
    Exit;
  End;
  { variable capturee par une classe locale : champ val$x }
  K := CapIndex(GenCls, L);
  If K < 0 Then Begin
    Err(Line, 'variable locale non accessible : ' + Locals[L].Name);
    PushVT(VTOfType(Locals[L].Typ));
    Exit;
  End;
  F := Classes[GenCls].CapFields[K];
  EmitThis;
  EmitGetField(False, Classes[GenCls].Name, Fields[F].Name, TypeDesc(Erasure(Fields[F].Typ)), Fields[F].Typ);
End;

{ ----- types de pile -------------------------------------------------------- }

Procedure EnsureStackType(T : LongInt);
Var V : TVT; E : LongInt;
Begin
  If Not IsRef(T) Then Exit;
  If (T = TY_NULL) Or (T = T_ANY) Then Exit;
  V := TopVT;
  If V.Tag <> VT_OBJECT Then Exit;
  E := Erasure(T);
  If E = T_OBJECT Then Exit;
  If VTAssignable(V, E) Then Exit;
  EmitCheckcast(TypeClassName(E));
End;

{ Remplace le type du sommet de pile (apres fusion de branches) }
Procedure ForceTopType(T : LongInt);
Var V : TVT;
Begin
  If Not IsRef(T) Then Exit;
  V := VTOfType(T);
  CurS[NSt - 1] := V;
End;

{ ----- constantes ------------------------------------------------------------ }

Procedure GenConst(N : LongInt);
Var Bits : TDblBits;
Begin
  Case Nodes[N].CK Of
    CK_INT : EmitConstInt(Nodes[N].CI);
    CK_LONG : EmitConstLong(Nodes[N].CI);
    CK_FLOAT : EmitConstFloat(Nodes[N].CD);
    CK_DOUBLE : EmitConstDouble(Nodes[N].CD);
    CK_STR : EmitConstString(Nodes[N].CS);
  End;
  Bits.I := 0;
End;

{ ----- conversions ------------------------------------------------------------- }

Function BoxDescOf(P : LongInt) : String;
Begin
  BoxDescOf := '(' + TypeDesc(P) + ')L' + BoxClassName(P) + ';';
End;

Procedure EmitBox(P : LongInt);
Begin
  EmitInvoke(OP_INVOKESTATIC, BoxClassName(P), 'valueOf', BoxDescOf(P), False);
End;

Function UnboxMethodName(P : LongInt) : String;
Begin
  Case P Of
    TY_BOOLEAN : UnboxMethodName := 'booleanValue';
    TY_BYTE : UnboxMethodName := 'byteValue';
    TY_CHAR : UnboxMethodName := 'charValue';
    TY_SHORT : UnboxMethodName := 'shortValue';
    TY_INT : UnboxMethodName := 'intValue';
    TY_LONG : UnboxMethodName := 'longValue';
    TY_FLOAT : UnboxMethodName := 'floatValue';
  Else
    UnboxMethodName := 'doubleValue';
  End;
End;

Procedure EmitUnbox(P : LongInt);
Begin
  EmitInvoke(OP_INVOKEVIRTUAL, BoxClassName(P), UnboxMethodName(P), '()' + TypeDesc(P), False);
End;

{ Conversion de la valeur du sommet de pile du type From vers le type To }
Procedure EmitConvTypes(From, To_ : LongInt; Explicit : Boolean);
Var U : LongInt;
Begin
  If From = To_ Then Exit;
  If IsPrim(From) And IsPrim(To_) Then Begin
    EmitPrimConv(From, To_);
    Exit;
  End;
  If IsPrim(From) Then Begin
    { boxing }
    EmitBox(From);
    If (To_ <> TY_NONE) And IsRef(To_) Then EnsureStackType(To_);
    Exit;
  End;
  If IsPrim(To_) Then Begin
    { unboxing eventuellement precede d'un cast }
    U := UnboxedType(Erasure(From));
    If U = TY_NONE Then Begin
      { Object / Number / Comparable... vers un primitif : cast vers la classe enveloppe }
      U := To_;
      EmitCheckcast(BoxClassName(U));
    End
    Else If VTIsRef(TopVT) And (TopVT.Tag = VT_OBJECT) And (VTName(TopVT) <> BoxClassName(U)) Then
      EmitCheckcast(BoxClassName(U));
    EmitUnbox(U);
    EmitPrimConv(U, To_);
    Exit;
  End;
  { reference -> reference }
  If Explicit Then Begin
    If (To_ <> TY_NULL) And (To_ <> T_ANY) Then Begin
      If Not VTAssignable(TopVT, Erasure(To_)) Then EmitCheckcast(TypeClassName(Erasure(To_)));
    End;
  End
  Else EnsureStackType(To_);
End;

{ ----- this englobant -------------------------------------------------------- }

Procedure GenOuterThis(K : LongInt);
Var C, F : LongInt;
Begin
  If (GenMeth >= 0) And (Meths[GenMeth].Name = '<init>') And Classes[GenCls].IsInner And
     (Length(Meths[GenMeth].PreLoc) > 0) And ((Classes[GenCls].Flags And ACC_ENUM) = 0) Then Begin
    { dans un constructeur : le parametre d'instance englobante (this peut ne pas etre initialise) }
    LoadLocal(Meths[GenMeth].PreLoc[0], LastLine);
    C := Classes[GenCls].Outer;
  End
  Else Begin
    EmitThis;
    C := GenCls;
  End;
  While (C >= 0) And Not IsSubClass(C, K) Do Begin
    F := Classes[C].ThisField;
    If F < 0 Then Begin
      Err(LastLine, 'instance englobante non disponible dans ' + Classes[C].Simple);
      Exit;
    End;
    EmitGetField(False, Classes[C].Name, Fields[F].Name, TypeDesc(Erasure(Fields[F].Typ)), Fields[F].Typ);
    C := Classes[C].Outer;
  End;
End;

{ ----- appels ---------------------------------------------------------------- }

Function ClassNameOfType(T : LongInt) : String;
Var E : LongInt;
Begin
  E := Erasure(T);
  If IsClassT(E) Then ClassNameOfType := Classes[Types[E].Cls].Name
  Else If IsArrayT(E) Then ClassNameOfType := TypeDesc(E)
  Else ClassNameOfType := 'java/lang/Object';
End;

Function CallOwnerName(N : LongInt) : String;
Var M, Site : LongInt;
Begin
  M := Nodes[N].Sym;
  Site := Nodes[N].E;
  If (Nodes[N].Mods And CALL_IFACEOBJ) <> 0 Then CallOwnerName := 'java/lang/Object'
  Else If (Site > 0) And (IsClassT(Erasure(Site))) Then CallOwnerName := ClassNameOfType(Site)
  Else CallOwnerName := Classes[Meths[M].Owner].Name;
End;

Procedure GenArgs(Args : LongInt; M : LongInt; Varargs : Boolean; Fixed : LongInt);
Var A, I, Cnt, ElemT : LongInt;
Begin
  If Not Varargs Then Begin
    A := Args;
    While A <> 0 Do Begin GenExpr(A); A := Nodes[A].Next; End;
    Exit;
  End;
  A := Args;
  For I := 1 To Fixed - 1 Do Begin GenExpr(A); A := Nodes[A].Next; End;
  Cnt := 0;
  ElemT := Erasure(ElemOf(Meths[M].Par[Meths[M].NPar - 1]));
  { compte les arguments restants }
  I := A;
  While I <> 0 Do Begin Inc(Cnt); I := Nodes[I].Next; End;
  EmitConstInt(Cnt);
  EmitNewArray(ElemT);
  I := 0;
  While A <> 0 Do Begin
    EmitDupValue;
    EmitConstInt(I);
    GenExpr(A);
    EmitArrayStore(ElemT);
    Inc(I);
    A := Nodes[A].Next;
  End;
End;

Function CtorDesc(M : LongInt) : String;
Begin
  CtorDesc := Meths[M].Desc;
End;

Procedure GenCtorCall(N : LongInt);
Var M, C, K, F : LongInt; Owner : String; I : LongInt;
Begin
  M := Nodes[N].Sym;
  If M < 0 Then Exit;
  Owner := Classes[Meths[M].Owner].Name;
  EmitThis;
  { arguments synthetiques de tete : prefixe enum, instance englobante }
  If Nodes[N].S = 'this' Then Begin
    For I := 0 To Length(Meths[GenMeth].PreLoc) - 1 Do LoadLocal(Meths[GenMeth].PreLoc[I], Nodes[N].Line);
  End
  Else Begin
    C := Meths[M].Owner;
    If (Classes[C].Flags And ACC_ENUM) <> 0 Then
      For I := 0 To Length(Meths[GenMeth].PreLoc) - 1 Do LoadLocal(Meths[GenMeth].PreLoc[I], Nodes[N].Line)
    Else If Classes[C].IsInner Then Begin
      { la super-classe est interne : instance englobante }
      K := Classes[C].Outer;
      If Nodes[N].D <> 0 Then Begin
        { super qualifie : expr.super(...) ; l'expression est testee contre null }
        GenExpr(Nodes[N].D);
        EmitDupValue;
        EmitInvoke(OP_INVOKESTATIC, 'java/util/Objects', 'requireNonNull', '(Ljava/lang/Object;)Ljava/lang/Object;', False);
        EmitPop(T_OBJECT);
      End
      Else If (GenCls >= 0) And Classes[GenCls].IsInner And (Length(Meths[GenMeth].PreLoc) > 0) Then Begin
        LoadLocal(Meths[GenMeth].PreLoc[0], Nodes[N].Line);
        F := Classes[GenCls].Outer;
        While (F >= 0) And Not IsSubClass(F, K) And (Classes[F].ThisField >= 0) Do Begin
          EmitGetField(False, Classes[F].Name, Fields[Classes[F].ThisField].Name,
                       TypeDesc(Erasure(Fields[Classes[F].ThisField].Typ)), Fields[Classes[F].ThisField].Typ);
          F := Classes[F].Outer;
        End;
        If Not IsSubClass(F, K) Then Err(Nodes[N].Line, 'instance englobante requise pour la super-classe');
      End
      Else Begin
        Err(Nodes[N].Line, 'instance englobante requise pour la super-classe');
        EmitNull;
      End;
    End;
  End;
  GenArgs(Nodes[N].B, M, (Nodes[N].Mods And CALL_VARARGS) <> 0, Nodes[N].N);
  { captures de la classe appelee }
  If Nodes[N].S = 'this' Then
    For I := 0 To Length(Meths[GenMeth].PostLoc) - 1 Do LoadLocal(Meths[GenMeth].PostLoc[I], Nodes[N].Line)
  Else Begin
    C := Meths[M].Owner;
    For I := 0 To Length(Classes[C].Caps) - 1 Do LoadLocal(Classes[C].Caps[I], Nodes[N].Line);
  End;
  EmitInvoke(OP_INVOKESPECIAL, Owner, '<init>', Meths[M].Desc, False);
  F := 0;
End;

Procedure GenCall(N : LongInt);
Var
  M, Op : LongInt; Name, Desc, Owner : String; IsStatic, Iface : Boolean; Oc : LongInt; Ret : String;
Begin
  LineMark(Nodes[N].Line);
  If (Nodes[N].Mods And CALL_CTOR) <> 0 Then Begin GenCtorCall(N); Exit; End;
  M := Nodes[N].Sym;
  If M < 0 Then Exit;
  Name := Meths[M].Name;
  Desc := Meths[M].Desc;
  IsStatic := (Meths[M].Flags And ACC_STATIC) <> 0;
  Owner := CallOwnerName(N);
  If (Nodes[N].Mods And CALL_ARRCLONE) <> 0 Then Owner := TypeDesc(Erasure(Nodes[Nodes[N].A].Typ));
  Oc := LookupClass(Owner);
  Iface := (Oc >= 0) And IsInterfaceC(Oc);
  If IsStatic Then Begin
    GenArgs(Nodes[N].B, M, (Nodes[N].Mods And CALL_VARARGS) <> 0, Nodes[N].N);
    EmitInvoke(OP_INVOKESTATIC, Owner, Name, Desc, Iface);
  End
  Else Begin
    GenExpr(Nodes[N].A);
    If (Nodes[N].Mods And CALL_SUPER) <> 0 Then Op := OP_INVOKESPECIAL
    Else If Iface Then Op := OP_INVOKEINTERFACE
    Else Op := OP_INVOKEVIRTUAL;
    GenArgs(Nodes[N].B, M, (Nodes[N].Mods And CALL_VARARGS) <> 0, Nodes[N].N);
    If Op = OP_INVOKESPECIAL Then
      EmitInvoke(OP_INVOKESPECIAL, Owner, Name, Desc, Iface)
    Else EmitInvoke(Op, Owner, Name, Desc, Iface);
  End;
  Ret := DescRetType(Desc);
  If Ret <> 'V' Then EnsureStackType(Nodes[N].Typ);
End;

Procedure GenNew(N : LongInt);
Var
  M, C, I, K : LongInt; Args : LongInt;
Begin
  LineMark(Nodes[N].Line);
  M := Nodes[N].Sym;
  C := Types[Erasure(Nodes[N].Typ)].Cls;
  If Nodes[N].E > 0 Then M := Classes[Nodes[N].E - 1].AnonCtor;
  EmitNew(Classes[C].Name);
  EmitDupValue;
  { instance englobante }
  If Classes[C].IsInner Then Begin
    If Nodes[N].D <> 0 Then GenExpr(Nodes[N].D)
    Else Begin
      Err(Nodes[N].Line, 'instance englobante manquante pour ' + Classes[C].Simple);
      EmitNull;
    End;
  End;
  GenArgs(Nodes[N].B, M, (Nodes[N].Mods And CALL_VARARGS) <> 0, Nodes[N].N);
  { valeurs capturees }
  For I := 0 To Length(Classes[C].Caps) - 1 Do LoadLocal(Classes[C].Caps[I], Nodes[N].Line);
  EmitInvoke(OP_INVOKESPECIAL, Classes[C].Name, '<init>', Meths[M].Desc, False);
  K := 0; Args := 0;
End;

{ ----- tableaux ---------------------------------------------------------------- }

Procedure GenArrayInit(N, ArrT : LongInt);
Var E, I, ET : LongInt;
Begin
  ET := Types[ArrT].Elem;
  EmitConstInt(ChainLen(Nodes[N].A));
  EmitNewArray(ET);
  I := 0;
  E := Nodes[N].A;
  While E <> 0 Do Begin
    EmitDupValue;
    EmitConstInt(I);
    If Nodes[E].Kind = N_ARRAYINIT Then GenArrayInit(E, ET)
    Else GenExpr(E);
    EmitArrayStore(Erasure(ET));
    Inc(I);
    E := Nodes[E].Next;
  End;
End;

Procedure GenNewArray(N : LongInt);
Var T, ET, D, NDims, I : LongInt;
Begin
  LineMark(Nodes[N].Line);
  T := Nodes[N].Typ;
  If Nodes[N].C <> 0 Then Begin GenArrayInit(Nodes[N].C, T); Exit; End;
  NDims := ChainLen(Nodes[N].B);
  If NDims = 1 Then Begin
    GenExpr(Nodes[N].B);
    EmitNewArray(Erasure(Types[T].Elem));
  End
  Else Begin
    D := Nodes[N].B;
    While D <> 0 Do Begin GenExpr(D); D := Nodes[D].Next; End;
    B1(Code, OP_MULTIANEWARRAY);
    B2(Code, CPClass(TypeDesc(Erasure(T))));
    B1(Code, NDims);
    For I := 1 To NDims Do PopVT;
    PushVT(VTObj(TypeDesc(Erasure(T))));
  End;
  ET := 0;
End;

{ ----- concatenation de chaines -------------------------------------------- }

Procedure CollectConcat(N : LongInt; Var Items : Array Of LongInt; Var Cnt : LongInt);
Begin
  If (Nodes[N].Kind = N_BINARY) And (Nodes[N].Aux = OP_ADD) And (Nodes[N].Typ = T_STRING) And
     (Nodes[N].CK = CK_NONE) Then Begin
    CollectConcat(Nodes[N].A, Items, Cnt);
    CollectConcat(Nodes[N].B, Items, Cnt);
  End
  Else If Cnt <= High(Items) Then Begin Items[Cnt] := N; Inc(Cnt); End;
End;

Function AppendDesc(T : LongInt) : String;
Begin
  Case T Of
    TY_BOOLEAN : AppendDesc := '(Z)Ljava/lang/StringBuilder;';
    TY_CHAR : AppendDesc := '(C)Ljava/lang/StringBuilder;';
    TY_BYTE, TY_SHORT, TY_INT : AppendDesc := '(I)Ljava/lang/StringBuilder;';
    TY_LONG : AppendDesc := '(J)Ljava/lang/StringBuilder;';
    TY_FLOAT : AppendDesc := '(F)Ljava/lang/StringBuilder;';
    TY_DOUBLE : AppendDesc := '(D)Ljava/lang/StringBuilder;';
  Else
    If T = T_STRING Then AppendDesc := '(Ljava/lang/String;)Ljava/lang/StringBuilder;'
    Else AppendDesc := '(Ljava/lang/Object;)Ljava/lang/StringBuilder;';
  End;
End;

Procedure EmitAppend(T : LongInt);
Begin
  EmitInvoke(OP_INVOKEVIRTUAL, 'java/lang/StringBuilder', 'append', AppendDesc(T), False);
End;

Procedure EmitNewStringBuilder;
Begin
  EmitNew('java/lang/StringBuilder');
  EmitDupValue;
  EmitInvoke(OP_INVOKESPECIAL, 'java/lang/StringBuilder', '<init>', '()V', False);
End;

Procedure GenConcat(N : LongInt);
Var Items : Array[0..255] Of LongInt; Cnt, I : LongInt; S, Acc : String; Ok : Boolean;
Begin
  Cnt := 0;
  CollectConcat(N, Items, Cnt);
  EmitNewStringBuilder;
  I := 0;
  While I < Cnt Do Begin
    { fusionne les constantes consecutives }
    If (Nodes[Items[I]].CK <> CK_NONE) And ConstToStr(Items[I], S) Then Begin
      Acc := S;
      While (I + 1 < Cnt) And (Nodes[Items[I + 1]].CK <> CK_NONE) And ConstToStr(Items[I + 1], S) Do Begin
        Acc := Acc + S;
        Inc(I);
      End;
      EmitConstString(Acc);
      EmitAppend(T_STRING);
    End
    Else Begin
      GenExpr(Items[I]);
      EmitAppend(Nodes[Items[I]].Typ);
    End;
    Inc(I);
  End;
  EmitInvoke(OP_INVOKEVIRTUAL, 'java/lang/StringBuilder', 'toString', '()Ljava/lang/String;', False);
  Ok := True;
End;

{ ----- operateurs lvalue : lecture / modification / ecriture ------------------ }

Function LvalDepth(N : LongInt) : LongInt;
Begin
  Case Nodes[N].Kind Of
    N_NAME : LvalDepth := 0;
    N_SELECT : If Nodes[N].Aux = 2 Then LvalDepth := 0 Else LvalDepth := 1;
    N_INDEX : LvalDepth := 2;
  Else
    LvalDepth := 0;
  End;
End;

Function LvalType(N : LongInt) : LongInt;
Begin
  LvalType := Nodes[N].Typ;
End;

{ Prefixe : evalue la reference de l'objet / du tableau / de l'indice }
Procedure GenLvalPrefix(N : LongInt);
Begin
  Case Nodes[N].Kind Of
    N_SELECT : If Nodes[N].Aux = 1 Then GenExpr(Nodes[N].A);
    N_INDEX : Begin GenExpr(Nodes[N].A); GenExpr(Nodes[N].B); End;
  End;
End;

Function FieldOwnerName(F : LongInt) : String;
Begin
  FieldOwnerName := Classes[Fields[F].Owner].Name;
End;

Function FieldDescOf(F : LongInt) : String;
Begin
  FieldDescOf := TypeDesc(Erasure(Fields[F].Typ));
End;

{ Duplique le prefixe pour lire puis ecrire la meme cible }
Procedure GenLvalDup(N : LongInt);
Begin
  Case Nodes[N].Kind Of
    N_SELECT : If Nodes[N].Aux = 1 Then EmitDupValue;
    N_INDEX : EmitDup2Cat1;
  End;
End;

Procedure GenLvalLoad(N : LongInt);
Var F, T : LongInt;
Begin
  Case Nodes[N].Kind Of
    N_NAME : LoadLocal(Nodes[N].Sym, Nodes[N].Line);
    N_SELECT : Begin
      F := Nodes[N].Sym;
      EmitGetField(Nodes[N].Aux = 2, FieldOwnerName(F), Fields[F].Name, FieldDescOf(F), Fields[F].Typ);
      EnsureStackType(Nodes[N].Typ);
    End;
    N_INDEX : Begin
      T := Types[Nodes[Nodes[N].A].Typ].Elem;
      EmitArrayLoad(Erasure(T));
      EnsureStackType(Nodes[N].Typ);
    End;
  End;
End;

{ ----- champs final blancs : affectation definitive (constructeurs, initialiseurs statiques) ----- }

Var
  FinFields : Array Of LongInt;
  NFin      : LongInt;
  FinActive : Boolean;

Procedure FinSetup(C : LongInt; Static : Boolean);
Var F : LongInt;
Begin
  NFin := 0;
  FinActive := False;
  CurFin := 0;
  If (Classes[C].Decl <= 0) Or (Nodes[Classes[C].Decl].Aux = CLS_RECORD) Then Exit;
  F := Classes[C].FirstField;
  While F >= 0 Do Begin
    If ((Fields[F].Flags And ACC_FINAL) <> 0) And (((Fields[F].Flags And ACC_STATIC) <> 0) = Static) And
       (Fields[F].Decl > 0) Then
      If (Nodes[Fields[F].Decl].Kind = N_VARDECL) And (Nodes[Fields[F].Decl].A = 0) And (NFin < 62) Then Begin
        SetLength(FinFields, NFin + 1);
        FinFields[NFin] := F;
        Inc(NFin);
      End;
    F := Fields[F].Next;
  End;
  FinActive := NFin > 0;
End;

Procedure FinNoteStore(F, Line : LongInt);
Var K : LongInt;
Begin
  If Not FinActive Then Exit;
  For K := 0 To NFin - 1 Do
    If FinFields[K] = F Then Begin
      If (CurFin And (Int64(1) Shl K)) <> 0 Then
        Err(Line, 'la variable finale ' + Fields[F].Name + ' peut deja avoir ete affectee');
      CurFin := CurFin Or (Int64(1) Shl K);
    End;
End;

Procedure FinCheckReturn;
Var K : LongInt; Ln : LongInt;
Begin
  If Not FinActive Then Exit;
  Ln := LastLine;
  For K := 0 To NFin - 1 Do
    If (CurFin And (Int64(1) Shl K)) = 0 Then
      If (Fields[FinFields[K]].Flags And ACC_STATIC) <> 0 Then
        Err(Nodes[Fields[FinFields[K]].Decl].Line, 'la variable finale ' + Fields[FinFields[K]].Name + ' n''a peut-etre pas ete initialisee')
      Else
      Err(Ln, 'la variable finale ' + Fields[FinFields[K]].Name + ' n''a peut-etre pas ete initialisee');
End;

Procedure GenLvalStore(N : LongInt);
Var F : LongInt;
Begin
  Case Nodes[N].Kind Of
    N_NAME : StoreLocal(Nodes[N].Sym);
    N_SELECT : Begin
      F := Nodes[N].Sym;
      EmitPutField(Nodes[N].Aux = 2, FieldOwnerName(F), Fields[F].Name, FieldDescOf(F));
      FinNoteStore(F, Nodes[N].Line);
    End;
    N_INDEX : EmitArrayStore(Erasure(Types[Nodes[Nodes[N].A].Typ].Elem));
  End;
End;

{ Partie centrale d'une modification en place :
  Mode 1 = affectation composee ; 2 = ++/-- (Delta = +1 / -1) ; 3 = += de chaines }
Procedure GenRMWMiddle(N, Mode, Delta : LongInt);
Var Lv, Rhs, P, Tv, Op : LongInt; K : Char;
Begin
  Lv := Nodes[N].A;
  Tv := Nodes[Lv].Typ;
  Case Mode Of
    1 : Begin
      P := Nodes[N].E;
      Rhs := Nodes[N].B;
      EmitConvTypes(Tv, P, False);
      GenExpr(Rhs);
      K := KindOf(P);
      Op := Nodes[N].Aux;
      Case Op Of
        OP_ADD : EmitArith(OP_IADD, K);
        OP_SUB : EmitArith(OP_ISUB, K);
        OP_MUL : EmitArith(OP_IMUL, K);
        OP_DIV : EmitArith(OP_IDIV, K);
        OP_REM : EmitArith(OP_IREM, K);
        OP_AND : EmitLogic(OP_IAND, K);
        OP_OR : EmitLogic(OP_IOR, K);
        OP_XOR : EmitLogic(OP_IXOR, K);
        OP_SHL, OP_SHR, OP_USHR : Begin
          If Nodes[Rhs].Typ = TY_LONG Then EmitSimple(OP_L2I, 'J', 'I');
          Case Op Of
            OP_SHL : EmitShift(OP_ISHL, K);
            OP_SHR : EmitShift(OP_ISHR, K);
          Else
            EmitShift(OP_IUSHR, K);
          End;
        End;
      End;
      EmitConvTypes(P, Tv, False);
    End;
    2 : Begin
      P := Nodes[N].E;
      EmitConvTypes(Tv, P, False);
      K := KindOf(P);
      Case P Of
        TY_LONG : EmitConstLong(1);
        TY_FLOAT : EmitConstFloat(1.0);
        TY_DOUBLE : EmitConstDouble(1.0);
      Else
        EmitConstInt(1);
      End;
      If Delta > 0 Then EmitArith(OP_IADD, K) Else EmitArith(OP_ISUB, K);
      If P In [TY_BYTE, TY_SHORT, TY_CHAR] Then EmitPrimConv(TY_INT, P);
      EmitConvTypes(P, Tv, False);
    End;
    3 : Begin
      EmitInvoke(OP_INVOKESTATIC, 'java/lang/String', 'valueOf', '(Ljava/lang/Object;)Ljava/lang/String;', False);
      EmitNew('java/lang/StringBuilder');
      EmitDupX(1);
      EmitSwap;
      EmitInvoke(OP_INVOKESPECIAL, 'java/lang/StringBuilder', '<init>', '(Ljava/lang/String;)V', False);
      Rhs := Nodes[N].B;
      GenExpr(Rhs);
      EmitAppend(Nodes[Rhs].Typ);
      EmitInvoke(OP_INVOKEVIRTUAL, 'java/lang/StringBuilder', 'toString', '()Ljava/lang/String;', False);
    End;
  End;
End;

{ ============================================================================
  5. GENERATION DU BYTECODE (2b/3) : expressions (suite)
  ============================================================================ }

Procedure GenAssign(N : LongInt; NeedValue : Boolean);
Var Lv, Rhs, D : LongInt;
Begin
  Lv := Nodes[N].A; Rhs := Nodes[N].B;
  D := LvalDepth(Lv);
  GenLvalPrefix(Lv);
  If (Nodes[Rhs].Kind = N_ARRAYINIT) Then GenArrayInit(Rhs, Nodes[Lv].Typ)
  Else GenExpr(Rhs);
  If NeedValue Then EmitDupX(D);
  GenLvalStore(Lv);
End;

Procedure GenAssignOp(N : LongInt; NeedValue : Boolean);
Var Lv, D, Mode : LongInt;
Begin
  Lv := Nodes[N].A;
  D := LvalDepth(Lv);
  If Nodes[N].E = T_STRING Then Mode := 3 Else Mode := 1;
  { cas rapide : variable locale int += constante }
  If (Nodes[Lv].Kind = N_NAME) And (Nodes[Lv].Typ = TY_INT) And (Mode = 1) And (SlotOf(Nodes[Lv].Sym) >= 0) And
     (Nodes[N].E = TY_INT) And (Nodes[Nodes[N].B].CK = CK_INT) And (Nodes[N].Aux In [OP_ADD, OP_SUB]) And
     (Abs(Nodes[Nodes[N].B].CI) <= 32767) Then Begin
    LoadLocalCheck(Nodes[Lv].Sym, Nodes[Lv].Line);
    If Nodes[N].Aux = OP_ADD Then EmitIinc(SlotOf(Nodes[Lv].Sym), Nodes[Nodes[N].B].CI)
    Else EmitIinc(SlotOf(Nodes[Lv].Sym), -Nodes[Nodes[N].B].CI);
    If NeedValue Then LoadLocal(Nodes[Lv].Sym, Nodes[Lv].Line);
    Exit;
  End;
  GenLvalPrefix(Lv);
  GenLvalDup(Lv);
  GenLvalLoad(Lv);
  GenRMWMiddle(N, Mode, 0);
  If NeedValue Then EmitDupX(D);
  GenLvalStore(Lv);
End;

Procedure GenIncDec(N : LongInt; NeedValue : Boolean);
Var Lv, D, Delta, Op : LongInt; Post : Boolean;
Begin
  Lv := Nodes[N].A;
  Op := Nodes[N].Aux;
  Post := (Op = OP_POSTINC) Or (Op = OP_POSTDEC);
  If (Op = OP_PREINC) Or (Op = OP_POSTINC) Then Delta := 1 Else Delta := -1;
  D := LvalDepth(Lv);
  { cas rapide : variable locale int }
  If (Nodes[Lv].Kind = N_NAME) And (Nodes[Lv].Typ = TY_INT) And (SlotOf(Nodes[Lv].Sym) >= 0) Then Begin
    LoadLocalCheck(Nodes[Lv].Sym, Nodes[Lv].Line);
    If NeedValue And Post Then LoadLocal(Nodes[Lv].Sym, Nodes[Lv].Line);
    EmitIinc(SlotOf(Nodes[Lv].Sym), Delta);
    If NeedValue And Not Post Then LoadLocal(Nodes[Lv].Sym, Nodes[Lv].Line);
    Exit;
  End;
  GenLvalPrefix(Lv);
  GenLvalDup(Lv);
  GenLvalLoad(Lv);
  If NeedValue And Post Then EmitDupX(D);
  GenRMWMiddle(N, 2, Delta);
  If NeedValue And Not Post Then EmitDupX(D);
  GenLvalStore(Lv);
End;

{ ----- conversions (noeud N_CONV) ------------------------------------------ }

Procedure GenConvNode(N : LongInt);
Var A, From, To_ : LongInt;
Begin
  A := Nodes[N].A;
  From := Nodes[A].Typ;
  To_ := Nodes[N].Typ;
  GenExpr(A);
  If (Nodes[A].Kind = N_INDY) Or (Nodes[A].Kind = N_LET) Then Exit;
  EmitConvTypes(From, To_, Nodes[N].Aux = 1);
End;

{ ----- expressions booleennes ----------------------------------------------- }

Function CondIdx(Op : LongInt) : LongInt;
Begin
  Case Op Of
    OP_EQ : CondIdx := 0;
    OP_NE : CondIdx := 1;
    OP_LT : CondIdx := 2;
    OP_GE : CondIdx := 3;
    OP_GT : CondIdx := 4;
    OP_LE : CondIdx := 5;
  Else
    CondIdx := 0;
  End;
End;

Function IsNullLit(N : LongInt) : Boolean;
Begin
  IsNullLit := (Nodes[N].Kind = N_LIT) And (Nodes[N].Aux = LIT_NULL);
End;

Procedure GenCompare(N, Target : LongInt; JumpIf : Boolean);
Var A, B, Op, P, Ci : LongInt;
Begin
  A := Nodes[N].A; B := Nodes[N].B;
  Op := Nodes[N].Aux;
  P := Nodes[N].E;
  Ci := CondIdx(Op);
  If Not JumpIf Then Ci := Ci Xor 1;
  If (P = T_OBJECT) Or Not IsPrim(P) Then Begin
    If IsNullLit(B) Then Begin
      GenExpr(A);
      If (Ci = 0) Then EmitJump(OP_IFNULL, Target) Else EmitJump(OP_IFNONNULL, Target);
    End
    Else If IsNullLit(A) Then Begin
      GenExpr(B);
      If (Ci = 0) Then EmitJump(OP_IFNULL, Target) Else EmitJump(OP_IFNONNULL, Target);
    End
    Else Begin
      GenExpr(A); GenExpr(B);
      If Ci = 0 Then EmitJump(OP_IF_ACMPEQ, Target) Else EmitJump(OP_IF_ACMPNE, Target);
    End;
    Exit;
  End;
  Case P Of
    TY_BOOLEAN, TY_BYTE, TY_CHAR, TY_SHORT, TY_INT : Begin
      If (Nodes[B].CK = CK_INT) And (Nodes[B].CI = 0) Then Begin
        GenExpr(A);
        EmitJump(OP_IFEQ + Ci, Target);
      End
      Else Begin
        GenExpr(A); GenExpr(B);
        EmitJump(OP_IF_ICMPEQ + Ci, Target);
      End;
    End;
    TY_LONG : Begin
      GenExpr(A); GenExpr(B);
      EmitSimple(OP_LCMP, 'JJ', 'I');
      EmitJump(OP_IFEQ + Ci, Target);
    End;
    TY_FLOAT, TY_DOUBLE : Begin
      GenExpr(A); GenExpr(B);
      If P = TY_FLOAT Then Begin
        If Op In [OP_LT, OP_LE] Then EmitSimple(OP_FCMPG, 'FF', 'I') Else EmitSimple(OP_FCMPL, 'FF', 'I');
      End
      Else Begin
        If Op In [OP_LT, OP_LE] Then EmitSimple(OP_DCMPG, 'DD', 'I') Else EmitSimple(OP_DCMPL, 'DD', 'I');
      End;
      EmitJump(OP_IFEQ + Ci, Target);
    End;
  End;
End;

Procedure GenBranch(N, Target : LongInt; JumpIf : Boolean);
Var Skip, V, Slot, TT : LongInt; Op : LongInt;
Begin
  If Not Alive Then Exit;
  If Nodes[N].CK = CK_INT Then Begin
    If (Nodes[N].CI <> 0) = JumpIf Then EmitJump(OP_GOTO, Target);
    Exit;
  End;
  Case Nodes[N].Kind Of
    N_UNARY : If Nodes[N].Aux = OP_NOT Then Begin GenBranch(Nodes[N].A, Target, Not JumpIf); Exit; End;
    N_BINARY : Begin
      Op := Nodes[N].Aux;
      If Op = OP_LAND Then Begin
        If Not JumpIf Then Begin
          GenBranch(Nodes[N].A, Target, False);
          GenBranch(Nodes[N].B, Target, False);
        End
        Else Begin
          Skip := NewLabel;
          GenBranch(Nodes[N].A, Skip, False);
          GenBranch(Nodes[N].B, Target, True);
          PlaceLabel(Skip);
        End;
        Exit;
      End;
      If Op = OP_LOR Then Begin
        If JumpIf Then Begin
          GenBranch(Nodes[N].A, Target, True);
          GenBranch(Nodes[N].B, Target, True);
        End
        Else Begin
          Skip := NewLabel;
          GenBranch(Nodes[N].A, Skip, True);
          GenBranch(Nodes[N].B, Target, False);
          PlaceLabel(Skip);
        End;
        Exit;
      End;
      If Op In [OP_LT, OP_GT, OP_LE, OP_GE, OP_EQ, OP_NE] Then Begin
        GenCompare(N, Target, JumpIf);
        Exit;
      End;
    End;
    N_INSTANCEOF : Begin
      TT := Nodes[N].E;
      GenExpr(Nodes[N].A);
      If Nodes[N].Aux = 1 Then Begin
        { motif record }
        Slot := AllocSlot(Nodes[Nodes[N].A].Typ);
        EmitStore('A', Slot, VTOfType(Nodes[Nodes[N].A].Typ));
        If JumpIf Then Begin
          Skip := NewLabel;
          GenPatternMatch(Nodes[N].C, Slot, Nodes[Nodes[N].A].Typ, Skip);
          EmitJump(OP_GOTO, Target);
          PlaceLabel(Skip);
        End
        Else GenPatternMatch(Nodes[N].C, Slot, Nodes[Nodes[N].A].Typ, Target);
      End
      Else If Nodes[N].C = 0 Then Begin
        EmitInstanceof(TypeClassName(Erasure(TT)));
        If JumpIf Then EmitJump(OP_IFNE, Target) Else EmitJump(OP_IFEQ, Target);
      End
      Else Begin
        V := Nodes[Nodes[N].C].Sym;
        Slot := SlotOf(V);
        If Slot < 0 Then Slot := DeclSlot(V);
        { tmp = expr ; if (tmp instanceof T) v = (T) tmp }
        EmitDupValue;
        EmitInstanceof(TypeClassName(Erasure(TT)));
        If JumpIf Then Begin
          Skip := NewLabel;
          EmitJump(OP_IFEQ, Skip);          { echec : retire la valeur copiee plus bas }
          EmitCheckcast(TypeClassName(Erasure(TT)));
          StoreLocal(V);
          EmitJump(OP_GOTO, Target);
          { chemin d'echec : il reste une copie sur la pile }
          PlaceLabel(Skip);
          EmitPop(T_OBJECT);
        End
        Else Begin
          Skip := NewLabel;
          EmitJump(OP_IFEQ, Skip);
          EmitCheckcast(TypeClassName(Erasure(TT)));
          StoreLocal(V);
          Op := NewLabel;
          EmitJump(OP_GOTO, Op);
          PlaceLabel(Skip);
          EmitPop(T_OBJECT);
          EmitJump(OP_GOTO, Target);
          PlaceLabel(Op);
        End;
      End;
      Exit;
    End;
  End;
  GenExpr(N);
  If JumpIf Then EmitJump(OP_IFNE, Target) Else EmitJump(OP_IFEQ, Target);
End;

Procedure GenBoolValue(N : LongInt);
Var Lf, Le : LongInt;
Begin
  Lf := NewLabel; Le := NewLabel;
  GenBranch(N, Lf, False);
  If Alive Then Begin
    EmitConstInt(1);
    EmitJump(OP_GOTO, Le);
  End;
  PlaceLabel(Lf);
  If Alive Then Begin
    EmitConstInt(0);
  End;
  PlaceLabel(Le);
End;

{ ----- lambdas ------------------------------------------------------------------ }

Function LambdaMethodDesc(I : LongInt) : String;
Var S : String; K, L : LongInt;
Begin
  S := '(';
  For K := 0 To Length(Lambdas[I].Caps) - 1 Do
    S := S + TypeDesc(Erasure(Locals[Lambdas[I].Caps[K]].Typ));
  For K := 0 To Length(Lambdas[I].ParT) - 1 Do S := S + TypeDesc(Erasure(Lambdas[I].ParT[K]));
  S := S + ')' + TypeDesc(Erasure(Lambdas[I].RetT));
  LambdaMethodDesc := S;
  L := 0;
End;

{ Cree (une seule fois) la methode synthetique portant le corps de la lambda }
Procedure EnsureLambdaMethod(I : LongInt);
Var
  N, C, M, D, Blk, St, Body, K : LongInt; Fl : LongInt; Nm : String; Ctx : LongInt; UsesThis : Boolean;
Begin
  If Lambdas[I].Meth >= 0 Then Exit;
  N := Lambdas[I].Node;
  C := Lambdas[I].OwnerCls;
  Ctx := Lambdas[I].Ctx;
  SetLength(Lambdas[I].Caps, Length(Ctxs[Ctx].Caps));
  For K := 0 To Length(Ctxs[Ctx].Caps) - 1 Do Lambdas[I].Caps[K] := Ctxs[Ctx].Caps[K];
  UsesThis := Ctxs[Ctx].UsesThis And Not Lambdas[I].InStatic;
  Fl := ACC_PRIVATE Or ACC_SYNTHETIC;
  If Not UsesThis Then Fl := Fl Or ACC_STATIC;
  If (GenMeth >= 0) And (Meths[GenMeth].Name <> '<init>') And (Meths[GenMeth].Name <> '<clinit>') Then Nm := Meths[GenMeth].Name
  Else If GenMeth >= 0 Then Begin
    If Meths[GenMeth].Name = '<init>' Then Nm := 'new' Else Nm := 'static';
  End
  Else Nm := 'static';
  Nm := 'lambda$' + Nm + '$' + IStr(LambdaCount);
  Inc(LambdaCount);
  M := NewMeth(C, Nm, Fl);
  Meths[M].Lambda := I;
  Lambdas[I].Meth := M;
  Meths[M].NPar := Length(Lambdas[I].ParT);
  SetLength(Meths[M].Par, Meths[M].NPar);
  For K := 0 To Meths[M].NPar - 1 Do Meths[M].Par[K] := Lambdas[I].ParT[K];
  Meths[M].Ret := Lambdas[I].RetT;
  SetLength(Meths[M].PreLoc, Length(Lambdas[I].Caps));
  For K := 0 To Length(Lambdas[I].Caps) - 1 Do Meths[M].PreLoc[K] := Lambdas[I].Caps[K];
  { declaration synthetique }
  D := NewNode(N_METHOD, Nodes[N].Line);
  Nodes[D].S := Nm;
  Nodes[D].B := Nodes[N].A;
  Meths[M].Decl := D;
  Nodes[D].Sym := M;
  If Nodes[N].Aux = 1 Then Begin
    Blk := NewNode(N_BLOCK, Nodes[N].Line);
    Body := Nodes[N].B;
    If Lambdas[I].RetT = TY_VOID Then St := NewNode(N_EXPRSTMT, Nodes[N].Line)
    Else St := NewNode(N_RETURN, Nodes[N].Line);
    Nodes[St].A := Body;
    Nodes[Blk].A := St;
    Nodes[D].C := Blk;
  End
  Else Nodes[D].C := Nodes[N].B;
  Meths[M].Desc := LambdaMethodDesc(I);
End;

Procedure GenIndy(N : LongInt);
Var
  I, Sam, K, M, Bsm, Mh, Ref : LongInt; IfaceName, Name, SamDesc, InstDesc, ImplDesc, CallDesc : String;
  Imp : String; InstT : LongInt; Static, OwnerIface : Boolean; Caps : Array Of LongInt; Ownr : String;
  Meta : LongInt; Args : TBuf;
Begin
  I := Nodes[N].Sym;
  EnsureLambdaMethod(I);
  M := Lambdas[I].Meth;
  Sam := Lambdas[I].SAM;
  Static := (Meths[M].Flags And ACC_STATIC) <> 0;
  Ownr := Classes[Meths[M].Owner].Name;
  OwnerIface := (Classes[Meths[M].Owner].Flags And ACC_INTERFACE) <> 0;
  { arguments capturees : this puis les variables }
  CallDesc := '(';
  If Not Static Then Begin
    EmitThis;
    CallDesc := CallDesc + 'L' + ThisClsName + ';';
  End;
  For K := 0 To Length(Lambdas[I].Caps) - 1 Do Begin
    LoadLocal(Lambdas[I].Caps[K], Nodes[N].Line);
    CallDesc := CallDesc + TypeDesc(Erasure(Locals[Lambdas[I].Caps[K]].Typ));
  End;
  IfaceName := ClassNameOfType(Lambdas[I].IfaceT);
  CallDesc := CallDesc + ')L' + IfaceName + ';';
  SamDesc := Meths[Sam].Desc;
  { type de methode instancie }
  InstDesc := '(';
  For K := 0 To Meths[Sam].NPar - 1 Do
    InstDesc := InstDesc + TypeDesc(Erasure(Lambdas[I].ParT[K]));
  InstDesc := InstDesc + ')' + TypeDesc(Erasure(Lambdas[I].RetT));
  ImplDesc := Meths[M].Desc;
  { methode d'amorcage }
  Ref := CPMethod('java/lang/invoke/LambdaMetafactory', 'metafactory',
    '(Ljava/lang/invoke/MethodHandles$Lookup;Ljava/lang/String;Ljava/lang/invoke/MethodType;Ljava/lang/invoke/MethodType;Ljava/lang/invoke/MethodHandle;Ljava/lang/invoke/MethodType;)Ljava/lang/invoke/CallSite;', False);
  Bsm := CPMethodHandle(6, Ref);
  If Static Then Mh := CPMethodHandle(6, CPMethod(Ownr, Meths[M].Name, ImplDesc, OwnerIface))
  Else Mh := CPMethodHandle(7, CPMethod(Ownr, Meths[M].Name, ImplDesc, OwnerIface));
  B2(BsmBuf, Bsm);
  B2(BsmBuf, 3);
  B2(BsmBuf, CPMethodType(SamDesc));
  B2(BsmBuf, Mh);
  B2(BsmBuf, CPMethodType(InstDesc));
  Meta := BsmCount;
  Inc(BsmCount);
  EmitInvokeDynamic(Meta, Meths[Sam].Name, CallDesc);
  Imp := '';
  InstT := 0;
End;

{ ----- expression principale ------------------------------------------------------ }

Procedure GenSwitch(N : LongInt; IsExpr : Boolean); Forward;

Procedure GenExpr(N : LongInt);
Var F, T, I, V : LongInt;
Begin
  If N = 0 Then Exit;
  If (Nodes[N].CK <> CK_NONE) And (Nodes[N].Kind <> N_ASSIGN) And (Nodes[N].Kind <> N_ASSIGNOP) And
     ((Nodes[N].Kind <> N_UNARY) Or Not (Nodes[N].Aux In [OP_PREINC, OP_PREDEC, OP_POSTINC, OP_POSTDEC])) Then Begin
    GenConst(N);
    Exit;
  End;
  Case Nodes[N].Kind Of
    N_LIT : EmitNull;
    N_NAME : LoadLocal(Nodes[N].Sym, Nodes[N].Line);
    N_THIS : EmitThis;
    N_OUTERTHIS : GenOuterThis(Nodes[N].Sym);
    N_SELECT : Begin
      F := Nodes[N].Sym;
      Case Nodes[N].Aux Of
        1 : Begin
          GenExpr(Nodes[N].A);
          EmitGetField(False, FieldOwnerName(F), Fields[F].Name, FieldDescOf(F), Fields[F].Typ);
          EnsureStackType(Nodes[N].Typ);
        End;
        2 : Begin
          EmitGetField(True, FieldOwnerName(F), Fields[F].Name, FieldDescOf(F), Fields[F].Typ);
          EnsureStackType(Nodes[N].Typ);
        End;
        3 : Begin
          GenExpr(Nodes[N].A);
          EmitArrayLength;
        End;
      End;
    End;
    N_CALL : GenCall(N);
    N_NEW : GenNew(N);
    N_NEWARRAY : GenNewArray(N);
    N_INDEX : Begin
      GenExpr(Nodes[N].A);
      GenExpr(Nodes[N].B);
      EmitArrayLoad(Erasure(Types[Nodes[Nodes[N].A].Typ].Elem));
      EnsureStackType(Nodes[N].Typ);
    End;
    N_UNARY : Begin
      Case Nodes[N].Aux Of
        OP_PLUS : GenExpr(Nodes[N].A);
        OP_NEG : Begin GenExpr(Nodes[N].A); EmitNeg(KindOf(Nodes[N].Typ)); End;
        OP_COMPL : Begin
          GenExpr(Nodes[N].A);
          If Nodes[N].Typ = TY_LONG Then Begin EmitConstLong(-1); EmitLogic(OP_IXOR, 'J'); End
          Else Begin EmitConstInt(-1); EmitLogic(OP_IXOR, 'I'); End;
        End;
        OP_NOT : GenBoolValue(N);
        OP_PREINC, OP_PREDEC, OP_POSTINC, OP_POSTDEC : GenIncDec(N, True);
      End;
    End;
    N_BINARY : Begin
      Case Nodes[N].Aux Of
        OP_ADD : If Nodes[N].Typ = T_STRING Then GenConcat(N)
                 Else Begin GenExpr(Nodes[N].A); GenExpr(Nodes[N].B); EmitArith(OP_IADD, KindOf(Nodes[N].Typ)); End;
        OP_SUB : Begin GenExpr(Nodes[N].A); GenExpr(Nodes[N].B); EmitArith(OP_ISUB, KindOf(Nodes[N].Typ)); End;
        OP_MUL : Begin GenExpr(Nodes[N].A); GenExpr(Nodes[N].B); EmitArith(OP_IMUL, KindOf(Nodes[N].Typ)); End;
        OP_DIV : Begin GenExpr(Nodes[N].A); GenExpr(Nodes[N].B); EmitArith(OP_IDIV, KindOf(Nodes[N].Typ)); End;
        OP_REM : Begin GenExpr(Nodes[N].A); GenExpr(Nodes[N].B); EmitArith(OP_IREM, KindOf(Nodes[N].Typ)); End;
        OP_AND : If Nodes[N].Typ = TY_BOOLEAN Then Begin GenExpr(Nodes[N].A); GenExpr(Nodes[N].B); EmitLogic(OP_IAND, 'I'); End
                 Else Begin GenExpr(Nodes[N].A); GenExpr(Nodes[N].B); EmitLogic(OP_IAND, KindOf(Nodes[N].Typ)); End;
        OP_OR : Begin GenExpr(Nodes[N].A); GenExpr(Nodes[N].B); EmitLogic(OP_IOR, KindOf(Nodes[N].Typ)); End;
        OP_XOR : Begin GenExpr(Nodes[N].A); GenExpr(Nodes[N].B); EmitLogic(OP_IXOR, KindOf(Nodes[N].Typ)); End;
        OP_SHL, OP_SHR, OP_USHR : Begin
          GenExpr(Nodes[N].A);
          GenExpr(Nodes[N].B);
          If Nodes[Nodes[N].B].Typ = TY_LONG Then EmitSimple(OP_L2I, 'J', 'I');
          Case Nodes[N].Aux Of
            OP_SHL : EmitShift(OP_ISHL, KindOf(Nodes[N].Typ));
            OP_SHR : EmitShift(OP_ISHR, KindOf(Nodes[N].Typ));
          Else
            EmitShift(OP_IUSHR, KindOf(Nodes[N].Typ));
          End;
        End;
        OP_LT, OP_GT, OP_LE, OP_GE, OP_EQ, OP_NE, OP_LAND, OP_LOR : GenBoolValue(N);
      End;
    End;
    N_ASSIGN : GenAssign(N, True);
    N_ASSIGNOP : GenAssignOp(N, True);
    N_COND : Begin
      V := NewLabel; T := NewLabel;
      GenBranch(Nodes[N].A, V, False);
      If Alive Then Begin
        GenExpr(Nodes[N].B);
        If Nodes[N].Typ <> TY_VOID Then ForceTopType(Nodes[N].Typ);
        EmitJump(OP_GOTO, T);
      End;
      PlaceLabel(V);
      If Alive Then Begin
        GenExpr(Nodes[N].C);
        If Nodes[N].Typ <> TY_VOID Then ForceTopType(Nodes[N].Typ);
      End;
      PlaceLabel(T);
    End;
    N_CONV : GenConvNode(N);
    N_INSTANCEOF : GenBoolValue(N);
    N_CLASSLIT : Begin
      T := Nodes[N].E;
      If IsPrim(T) Or (T = TY_VOID) Then
        EmitGetField(True, BoxClassNameOrVoid(T), 'TYPE', 'Ljava/lang/Class;', T_CLASS)
      Else EmitConstClass(TypeClassName(Erasure(T)));
    End;
    N_SWITCHEXPR : GenSwitch(N, True);
    N_LAMBDA, N_INDY : GenIndy(N);
    N_LET : Begin
      V := Nodes[Nodes[N].A].Sym;
      DeclSlot(V);
      GenExpr(Nodes[Nodes[N].A].A);
      StoreLocal(V);
      GenExpr(Nodes[N].B);
    End;
  Else
    Internal('GenExpr : noeud inattendu ' + IStr(Nodes[N].Kind));
  End;
  I := 0;
End;

{ Expression evaluee pour ses effets : la valeur est ecartee }
Procedure GenExprDiscard(N : LongInt);
Var T : LongInt;
Begin
  Case Nodes[N].Kind Of
    N_ASSIGN : GenAssign(N, False);
    N_ASSIGNOP : GenAssignOp(N, False);
    N_UNARY : If Nodes[N].Aux In [OP_PREINC, OP_PREDEC, OP_POSTINC, OP_POSTDEC] Then GenIncDec(N, False)
              Else Begin GenExpr(N); EmitPop(Nodes[N].Typ); End;
    N_CALL, N_NEW : Begin
      GenExpr(N);
      T := Nodes[N].Typ;
      If (Nodes[N].Kind = N_NEW) Or (T <> TY_VOID) Then EmitPop(T);
    End;
    N_CONV : Begin
      GenExpr(N);
      If Nodes[N].Typ <> TY_VOID Then EmitPop(Nodes[N].Typ);
    End;
  Else
    GenExpr(N);
    If Nodes[N].Typ <> TY_VOID Then EmitPop(Nodes[N].Typ);
  End;
End;

{ ============================================================================
  5. GENERATION DU BYTECODE (3/3) : instructions
  ============================================================================ }

Procedure PushGCtx(Kind : Byte);
Begin
  If NGCtx >= Length(GCtx) Then SetLength(GCtx, NGCtx * 2 + 8);
  GCtx[NGCtx].Kind := Kind;
  GCtx[NGCtx].Name := '';
  GCtx[NGCtx].BreakL := -1;
  GCtx[NGCtx].ContL := -1;
  GCtx[NGCtx].FinKind := FIN_NONE;
  GCtx[NGCtx].FinNode := 0;
  GCtx[NGCtx].FinSlot := -1;
  GCtx[NGCtx].FinSlot2 := -1;
  GCtx[NGCtx].RStart := -1;
  GCtx[NGCtx].Mode := 0;
  GCtx[NGCtx].N1 := 0;
  GCtx[NGCtx].N2 := 0;
  GCtx[NGCtx].ResType := TY_NONE;
  GCtx[NGCtx].LocMark := NextLoc;
  Inc(NGCtx);
End;

Procedure AddRange1(I, S, E : LongInt);
Begin
  If GCtx[I].N1 + 2 > Length(GCtx[I].R1) Then SetLength(GCtx[I].R1, GCtx[I].N1 * 2 + 8);
  GCtx[I].R1[GCtx[I].N1] := S; GCtx[I].R1[GCtx[I].N1 + 1] := E;
  Inc(GCtx[I].N1, 2);
End;

Procedure AddRange2(I, S, E : LongInt);
Begin
  If GCtx[I].N2 + 2 > Length(GCtx[I].R2) Then SetLength(GCtx[I].R2, GCtx[I].N2 * 2 + 8);
  GCtx[I].R2[GCtx[I].N2] := S; GCtx[I].R2[GCtx[I].N2 + 1] := E;
  Inc(GCtx[I].N2, 2);
End;

Procedure CloseRange(I : LongInt);
Begin
  If GCtx[I].RStart < 0 Then Exit;
  If Code.N > GCtx[I].RStart Then Begin
    If GCtx[I].Mode = 0 Then AddRange1(I, GCtx[I].RStart, Code.N);
    AddRange2(I, GCtx[I].RStart, Code.N);
  End;
  GCtx[I].RStart := -1;
End;

Procedure OpenRange(I : LongInt);
Begin
  GCtx[I].RStart := Code.N;
End;

{ Masque temporairement les contextes a partir de I pendant l'emission inline d'un
  finalisateur (les pushes du finalisateur ne doivent pas ecraser ces contextes) }
Procedure HideCtxs(I : LongInt; Var Svd : Array Of TGenCtx; Var Sv : LongInt);
Var K : LongInt;
Begin
  Sv := NGCtx;
  For K := I To Sv - 1 Do Begin
    Svd[K - I] := GCtx[K];
    SetLength(GCtx[K].R1, 0);     { evite le partage des tableaux avec la copie sauvegardee }
    SetLength(GCtx[K].R2, 0);
  End;
  NGCtx := I;
End;

Procedure ShowCtxs(I : LongInt; Var Svd : Array Of TGenCtx; Sv : LongInt);
Var K : LongInt;
Begin
  For K := I To Sv - 1 Do GCtx[K] := Svd[K - I];
  NGCtx := Sv;
End;

Procedure EmitFinalizer(I : LongInt);
Var Skip, Plain, TryS, TryE, Handler, Done, Sup : LongInt; Slot : LongInt; SvL : Array Of TVT; K : LongInt;
Begin
  Case GCtx[I].FinKind Of
    FIN_BLOCK : GenStmt(GCtx[I].FinNode);
    FIN_MONITOR : Begin
      EmitLoad('A', GCtx[I].FinSlot);
      EmitMonitor(False);
    End;
    FIN_TWR : Begin
      Skip := NewLabel; Plain := NewLabel; Done := NewLabel;
      EmitLoad('A', GCtx[I].FinSlot);
      EmitJump(OP_IFNULL, Skip);
      EmitLoad('A', GCtx[I].FinSlot2);
      EmitJump(OP_IFNULL, Plain);
      { try : r.close() ; catch Throwable s : primary.addSuppressed(s) }
      Handler := NewLabel;
      SetLength(SvL, Length(CurL));
      For K := 0 To Length(CurL) - 1 Do SvL[K] := CurL[K];
      TryS := Code.N;
      EmitLoad('A', GCtx[I].FinSlot);
      EmitInvoke(OP_INVOKEINTERFACE, 'java/lang/AutoCloseable', 'close', '()V', True);
      TryE := Code.N;
      EmitJump(OP_GOTO, Done);
      { gestionnaire }
      For K := 0 To Length(CurL) - 1 Do CurL[K] := SvL[K];
      NSt := 0; StDepth := 0;
      PushVT(VTObj('java/lang/Throwable'));
      Alive := True;
      AddFrame(Code.N);
      AddHandlerEntry(TryS, TryE, Code.N, CPClass('java/lang/Throwable'));
      Sup := AllocSlot(T_THROWABLE);
      EmitStore('A', Sup, VTObj('java/lang/Throwable'));
      EmitLoad('A', GCtx[I].FinSlot2);
      EmitLoad('A', Sup);
      EmitInvoke(OP_INVOKEVIRTUAL, 'java/lang/Throwable', 'addSuppressed', '(Ljava/lang/Throwable;)V', False);
      CurL[Sup] := VTSimple(VT_TOP);
      EmitJump(OP_GOTO, Done);
      PlaceLabel(Plain);
      EmitLoad('A', GCtx[I].FinSlot);
      EmitInvoke(OP_INVOKEINTERFACE, 'java/lang/AutoCloseable', 'close', '()V', True);
      PlaceLabel(Done);
      PlaceLabel(Skip);
      Slot := 0;
    End;
  End;
End;

{ Quitte les contextes au-dessus de Target (executant les finalisations) avant un saut }
Procedure LeaveCtxs(Target : LongInt);
Var I, Sv : LongInt; Svd : Array[0..63] Of TGenCtx;
Begin
  For I := NGCtx - 1 Downto Target + 1 Do Begin
    If GCtx[I].Kind = GC_TRY Then CloseRange(I);
    If (GCtx[I].Kind = GC_TRY) And (GCtx[I].FinKind <> FIN_NONE) And Alive Then Begin
      HideCtxs(I, Svd, Sv);
      EmitFinalizer(I);
      ShowCtxs(I, Svd, Sv);
    End;
  End;
End;

Procedure ReopenCtxs(Target : LongInt);
Var I : LongInt;
Begin
  For I := Target + 1 To NGCtx - 1 Do
    If GCtx[I].Kind = GC_TRY Then OpenRange(I);
End;

Function HasTryCtx(Target : LongInt) : Boolean;
Var I : LongInt;
Begin
  HasTryCtx := False;
  For I := Target + 1 To NGCtx - 1 Do If GCtx[I].Kind = GC_TRY Then HasTryCtx := True;
End;

{ ----- declarations de variables -------------------------------------------- }

{ ----- accessibilite des instructions (JLS 14.22) ------------------------------- }

{ Y a-t-il dans S un 'break' (sans etiquette hors boucle/switch interne, ou avec l'etiquette Lab) ? }
Function HasBreak(S : LongInt; Const Lab : String; Nested : Boolean) : Boolean;
Var C : LongInt;
Begin
  HasBreak := False;
  While S <> 0 Do Begin
    Case Nodes[S].Kind Of
      N_BREAK : If ((Nodes[S].S = '') And Not Nested) Or ((Nodes[S].S <> '') And (Nodes[S].S = Lab)) Then Begin HasBreak := True; Exit; End;
      N_BLOCK : If HasBreak(Nodes[S].A, Lab, Nested) Then Begin HasBreak := True; Exit; End;
      N_IF : If HasBreak(Nodes[S].B, Lab, Nested) Or HasBreak(Nodes[S].C, Lab, Nested) Then Begin HasBreak := True; Exit; End;
      N_LABELED, N_SYNC : If HasBreak(Nodes[S].A, Lab, Nested) Or HasBreak(Nodes[S].B, Lab, Nested) Then Begin HasBreak := True; Exit; End;
      N_WHILE : If HasBreak(Nodes[S].B, Lab, True) Then Begin HasBreak := True; Exit; End;
      N_DO : If HasBreak(Nodes[S].A, Lab, True) Then Begin HasBreak := True; Exit; End;
      N_FOR : If HasBreak(Nodes[S].D, Lab, True) Then Begin HasBreak := True; Exit; End;
      N_FOREACH : If HasBreak(Nodes[S].C, Lab, True) Then Begin HasBreak := True; Exit; End;
      N_SWITCH : Begin
        C := Nodes[S].B;
        While C <> 0 Do Begin
          If HasBreak(Nodes[C].B, Lab, True) Then Begin HasBreak := True; Exit; End;
          C := Nodes[C].Next;
        End;
      End;
      N_TRY : Begin
        If HasBreak(Nodes[S].B, Lab, Nested) Or HasBreak(Nodes[S].D, Lab, Nested) Then Begin HasBreak := True; Exit; End;
        C := Nodes[S].C;
        While C <> 0 Do Begin
          If HasBreak(Nodes[C].B, Lab, Nested) Then Begin HasBreak := True; Exit; End;
          C := Nodes[C].Next;
        End;
      End;
    End;
    S := Nodes[S].Next;
  End;
End;

Function CanComplete(S : LongInt) : Boolean;
Var C, L : LongInt; R : Boolean; HasDef : Boolean;
Begin
  CanComplete := True;
  If S = 0 Then Exit;
  Case Nodes[S].Kind Of
    N_RETURN, N_THROW, N_BREAK, N_CONTINUE, N_YIELD : CanComplete := False;
    N_BLOCK : Begin
      L := Nodes[S].A;
      R := True;
      While L <> 0 Do Begin R := CanComplete(L); If Not R Then Break; L := Nodes[L].Next; End;
      CanComplete := R;
    End;
    N_IF : If Nodes[S].C = 0 Then CanComplete := True
           Else CanComplete := CanComplete(Nodes[S].B) Or CanComplete(Nodes[S].C);
    N_WHILE : CanComplete := Not ((Nodes[Nodes[S].A].CK = CK_INT) And (Nodes[Nodes[S].A].CI <> 0)) Or HasBreak(Nodes[S].B, '', False);
    N_DO : CanComplete := (CanComplete(Nodes[S].A) And Not ((Nodes[Nodes[S].B].CK = CK_INT) And (Nodes[Nodes[S].B].CI <> 0))) Or HasBreak(Nodes[S].A, '', False);
    N_FOR : CanComplete := ((Nodes[S].B <> 0) And Not ((Nodes[Nodes[S].B].CK = CK_INT) And (Nodes[Nodes[S].B].CI <> 0))) Or HasBreak(Nodes[S].D, '', False);
    N_LABELED : CanComplete := CanComplete(Nodes[S].A) Or HasBreak(Nodes[S].A, Nodes[S].S, False);
    N_SYNC : CanComplete := CanComplete(Nodes[S].B);
    N_TRY : Begin
      R := CanComplete(Nodes[S].B);
      C := Nodes[S].C;
      While C <> 0 Do Begin If CanComplete(Nodes[C].B) Then R := True; C := Nodes[C].Next; End;
      If (Nodes[S].D <> 0) And Not CanComplete(Nodes[S].D) Then R := False;
      CanComplete := R;
    End;
    N_SWITCH : Begin
      HasDef := False;
      R := False;
      C := Nodes[S].B;
      While C <> 0 Do Begin
        If (Nodes[C].Aux And 1) <> 0 Then HasDef := True;
        If HasBreak(Nodes[C].B, '', False) Then R := True;
        If (Nodes[C].Aux And 2) <> 0 Then Begin
          If CanComplete(Nodes[C].B) Then R := True;
        End
        Else If Nodes[C].Next = 0 Then Begin
          { dernier groupe : doit pouvoir se terminer normalement }
          L := Nodes[C].B;
          If L = 0 Then R := True
          Else Begin
            If CanComplete(Nodes[C].B) Then R := True;
            While L <> 0 Do Begin If Not CanComplete(L) Then Begin R := R And False; Break; End; L := Nodes[L].Next; End;
          End;
        End;
        C := Nodes[C].Next;
      End;
      If (Nodes[S].E <> SW_PATTERN) And Not HasDef Then R := True;
      If (Nodes[S].E = SW_PATTERN) And Not HasDef Then R := True;
      CanComplete := R;
    End;
  End;
End;

Procedure GenLocalVar(N : LongInt);
Var V, L, Init : LongInt;
Begin
  V := Nodes[N].B;
  While V <> 0 Do Begin
    L := Nodes[V].Sym;
    DeclSlot(L);
    Init := Nodes[V].A;
    If Init <> 0 Then Begin
      LineMark(Nodes[V].Line);
      If Nodes[Init].Kind = N_ARRAYINIT Then GenArrayInit(Init, Locals[L].Typ)
      Else GenExpr(Init);
      StoreLocal(L);
    End;
    V := Nodes[V].Next;
  End;
End;

{ ----- switch ------------------------------------------------------------------ }

Function JavaStringHash(Const S : String) : LongInt;
Var I, N, Cp : LongInt; H : Int64;
  Procedure Add(Cu : LongInt);
  Begin
    H := (H * 31 + Cu) And $FFFFFFFF;
  End;
Begin
  H := 0;
  I := 1;
  N := Length(S);
  While I <= N Do Begin
    Cp := Ord(S[I]);
    If Cp < $80 Then Begin Add(Cp); Inc(I); End
    Else If (Cp And $E0) = $C0 Then Begin
      Add(((Cp And $1F) Shl 6) Or (Ord(S[I + 1]) And $3F)); Inc(I, 2);
    End
    Else Begin
      Add(((Cp And $0F) Shl 12) Or ((Ord(S[I + 1]) And $3F) Shl 6) Or (Ord(S[I + 2]) And $3F)); Inc(I, 3);
    End;
  End;
  JavaStringHash := LongInt(H);
End;

Function EnumOrdinal(F : LongInt) : LongInt;
Var X, K : LongInt;
Begin
  K := 0;
  X := Classes[Fields[F].Owner].FirstField;
  While X >= 0 Do Begin
    If X = F Then Begin EnumOrdinal := K; Exit; End;
    If (Fields[X].Flags And ACC_ENUM) <> 0 Then Inc(K);
    X := Fields[X].Next;
  End;
  EnumOrdinal := K;
End;

Procedure SortPairs(Var Keys, Tg : Array Of LongInt; N : LongInt);
Var I, J, K, T : LongInt;
Begin
  For I := 1 To N - 1 Do Begin
    K := Keys[I]; T := Tg[I];
    J := I - 1;
    While (J >= 0) And (Keys[J] > K) Do Begin Keys[J + 1] := Keys[J]; Tg[J + 1] := Tg[J]; Dec(J); End;
    Keys[J + 1] := K; Tg[J + 1] := T;
  End;
End;

Procedure EmitIntSwitch(Var Keys, Tg : Array Of LongInt; N, Dflt : LongInt);
Var Lo, Hi, I, J : LongInt; Tab : Array Of LongInt; TableCost, LookupCost : Int64; TT : Array Of LongInt;
Begin
  SortPairs(Keys, Tg, N);
  If N = 0 Then Begin
    PopVT; B1(Code, OP_POP);
    EmitJump(OP_GOTO, Dflt);
    Exit;
  End;
  Lo := Keys[0]; Hi := Keys[N - 1];
  TableCost := 4 + (Int64(Hi) - Lo + 1) + 3 * 3;
  LookupCost := 3 + 2 * N + 3 * N;
  If TableCost <= LookupCost Then Begin
    SetLength(Tab, Hi - Lo + 1);
    For I := 0 To Hi - Lo Do Tab[I] := Dflt;
    For I := 0 To N - 1 Do Tab[Keys[I] - Lo] := Tg[I];
    EmitTableSwitch(Lo, Hi, Tab, Dflt);
  End
  Else Begin
    SetLength(TT, N);
    For J := 0 To N - 1 Do TT[J] := Tg[J];
    EmitLookupSwitch(N, Keys, TT, Dflt);
  End;
End;

{ ----- motifs (instanceof et switch) ------------------------------------------- }

{ La valeur est dans la variable locale Slot (type statique ValT). En cas d'echec on
  saute a Fail ; sinon les variables liees sont affectees. }
Procedure GenPatternMatch(Pat, Slot, ValT, Fail : LongInt);
Var
  T, C, K, Sub, Pm, Cs, Cm, F, Ct, M2, Cslot : LongInt; NeedTest : Boolean; Et : LongInt;
Begin
  T := Nodes[Pat].Typ;
  If IsPrim(T) Then Begin
    If Nodes[Pat].Sym >= 0 Then Begin
      DeclSlot(Nodes[Pat].Sym);
      EmitLoad(KindOf(T), Slot);
      StoreLocal(Nodes[Pat].Sym);
    End;
    Exit;
  End;
  Et := Erasure(T);
  NeedTest := (Nodes[Pat].Aux = 1) Or Not IsSubtypeRef(Erasure(ValT), Et);
  If NeedTest Then Begin
    EmitLoad('A', Slot);
    EmitInstanceof(TypeClassName(Et));
    EmitJump(OP_IFEQ, Fail);
  End;
  If Nodes[Pat].Aux = 1 Then Begin
    C := Nodes[Pat].E;
    Cslot := AllocSlot(T_OBJECT);
    EmitLoad('A', Slot);
    EmitCheckcast(TypeClassName(Et));
    EmitStore('A', Cslot, VTOfType(Et));
    Pm := Nodes[Classes[C].Decl].E;
    Sub := Nodes[Pat].B;
    While (Sub <> 0) And (Pm <> 0) Do Begin
      F := FindFieldIn(C, Nodes[Pm].S);
      M2 := FindMethodDecl(C, Nodes[Pm].S, 0);
      If (F >= 0) And (M2 >= 0) Then Begin
        Ct := MemberType(T, C, Fields[F].Typ);
        EmitLoad('A', Cslot);
        EmitInvoke(OP_INVOKEVIRTUAL, Classes[C].Name, Meths[M2].Name, Meths[M2].Desc, False);
        EnsureStackType(Ct);
        K := AllocSlot(Ct);
        EmitStore(KindOf(Ct), K, VTOfType(Ct));
        GenPatternMatch(Sub, K, Ct, Fail);
      End;
      Sub := Nodes[Sub].Next;
      Pm := Nodes[Pm].Next;
    End;
  End;
  If Nodes[Pat].Sym >= 0 Then Begin
    DeclSlot(Nodes[Pat].Sym);
    EmitLoad('A', Slot);
    If Not VTAssignable(TopVT, Et) Then EmitCheckcast(TypeClassName(Et));
    StoreLocal(Nodes[Pat].Sym);
  End;
  Cs := 0; Cm := 0;
End;

Procedure GenPatternSwitch(N : LongInt; IsExpr : Boolean);
Var
  Sel, ST, S, EndL, Cs, Lb, Lnext, Lbody, Ljn, Mark, Mark2, Body, DefCs, K, NullBody, Ctx : LongInt;
  HasNull, IsDefault : Boolean; Tj : LongInt; Cm : LongInt; Lnull : LongInt;
  NullLabelCase : LongInt;
Begin
  Sel := Nodes[N].A;
  ST := Nodes[Sel].Typ;
  Mark := NextLoc;
  EndL := NewLabel;
  PushGCtx(GC_SWITCH);
  If IsExpr Then GCtx[NGCtx - 1].Kind := GC_SWEXPR;
  GCtx[NGCtx - 1].BreakL := EndL;
  GCtx[NGCtx - 1].ResType := Nodes[N].Typ;
  Ctx := NGCtx - 1;
  LineMark(Nodes[N].Line);
  GenExpr(Sel);
  S := AllocSlot(ST);
  EmitStore('A', S, VTOfType(ST));
  { cas null ? }
  HasNull := False;
  DefCs := 0;
  NullLabelCase := 0;
  Cs := Nodes[N].B;
  While Cs <> 0 Do Begin
    Lb := Nodes[Cs].A;
    While Lb <> 0 Do Begin
      If (Nodes[Lb].Kind = N_LIT) And (Nodes[Lb].Aux = LIT_NULL) Then Begin HasNull := True; NullLabelCase := Cs; End;
      Lb := Nodes[Lb].Next;
    End;
    If (Nodes[Cs].Aux And 1) <> 0 Then DefCs := Cs;
    Cs := Nodes[Cs].Next;
  End;
  Lnull := -1;
  If HasNull Then Begin
    Lnull := NewLabel;
    EmitLoad('A', S);
    EmitJump(OP_IFNULL, Lnull);
  End
  Else Begin
    EmitLoad('A', S);
    EmitInvoke(OP_INVOKESTATIC, 'java/util/Objects', 'requireNonNull', '(Ljava/lang/Object;)Ljava/lang/Object;', False);
    EmitPop(T_OBJECT);
  End;
  { les cas dans l'ordre, sauf default }
  Cs := Nodes[N].B;
  While Cs <> 0 Do Begin
    If ((Nodes[Cs].Aux And 1) = 0) Or (Nodes[Cs].A <> 0) Then Begin
      Lnext := NewLabel;
      Lbody := NewLabel;
      Mark2 := NextLoc;
      Lb := Nodes[Cs].A;
      While Lb <> 0 Do Begin
        If Not ((Nodes[Lb].Kind = N_LIT) And (Nodes[Lb].Aux = LIT_NULL)) Then Begin
          Ljn := NewLabel;
          If Nodes[Lb].Kind = N_PATTERN Then GenPatternMatch(Lb, S, ST, Ljn)
          Else If Nodes[Lb].Aux In [98, 99] Then Begin
            EmitLoad('A', S);
            EmitGetField(True, Classes[Fields[Nodes[Lb].Sym].Owner].Name, Fields[Nodes[Lb].Sym].Name,
                         'L' + Classes[Fields[Nodes[Lb].Sym].Owner].Name + ';', ST);
            EmitJump(OP_IF_ACMPNE, Ljn);
          End
          Else Begin
            EmitConstString(Nodes[Lb].CS);
            EmitLoad('A', S);
            EmitInvoke(OP_INVOKEVIRTUAL, 'java/lang/String', 'equals', '(Ljava/lang/Object;)Z', False);
            EmitJump(OP_IFEQ, Ljn);
          End;
          If Alive Then EmitJump(OP_GOTO, Lbody);
          PlaceLabel(Ljn);
        End;
        Lb := Nodes[Lb].Next;
      End;
      If Alive Then EmitJump(OP_GOTO, Lnext);
      PlaceLabel(Lbody);
      If (Cs = NullLabelCase) And (Lnull >= 0) Then PlaceLabel(Lnull);
      { garde }
      If Alive And (Nodes[Cs].E <> 0) Then GenBranch(Nodes[Cs].E, Lnext, False);
      If Alive Then Begin
        If (Nodes[Cs].Aux And 2) <> 0 Then GenStmt(Nodes[Cs].B)
        Else Begin
          Body := Nodes[Cs].B;
          While Body <> 0 Do Begin GenStmt(Body); Body := Nodes[Body].Next; End;
        End;
        If Alive And Not IsExpr Then EmitJump(OP_GOTO, EndL);
      End;
      FreeLocals(Mark2);
      PlaceLabel(Lnext);
    End;
    Cs := Nodes[Cs].Next;
  End;
  { cas default }
  If DefCs <> 0 Then Begin
    If Lnull >= 0 Then Begin
      { null atteint le default seulement s'il le contient }
    End;
    Lb := Nodes[DefCs].A;
    If Alive Or (Lnull >= 0) Then Begin
      If (Lnull >= 0) And (NullLabelCase = 0) Then PlaceLabel(Lnull);
      If Alive Then Begin
        If (Nodes[DefCs].Aux And 2) <> 0 Then GenStmt(Nodes[DefCs].B)
        Else Begin
          Body := Nodes[DefCs].B;
          While Body <> 0 Do Begin GenStmt(Body); Body := Nodes[Body].Next; End;
        End;
      End;
    End;
  End
  Else Begin
    { switch a motifs exhaustif sans default : MatchException si aucun cas ne correspond }
    If Lnull >= 0 Then PlaceLabel(Lnull);
    If Alive Then Begin
      EmitNew('java/lang/MatchException');
      EmitDupValue;
      EmitNull;
      EmitNull;
      EmitInvoke(OP_INVOKESPECIAL, 'java/lang/MatchException', '<init>', '(Ljava/lang/String;Ljava/lang/Throwable;)V', False);
      EmitThrow;
    End;
  End;
  Dec(NGCtx);
  PlaceLabel(EndL);
  FreeLocals(Mark);
  Tj := Ctx; K := 0; Cm := 0; NullBody := 0;
  IsDefault := False;
End;

Procedure GenSwitch(N : LongInt; IsExpr : Boolean);
Var
  Mode, Sel, Cs, Lb, K, NCases, NKeys, I, J, Mark, Dflt, EndL, DefCase, S1, S2, Cnt, Body : LongInt;
  CaseL : Array Of LongInt; Keys, Tg : Array Of LongInt; Strs : Array Of String; StrCase : Array Of LongInt;
  Hashes, HTg, HK : Array Of LongInt; NH, B, F : LongInt; Bucket : Array Of LongInt; Hl : Array Of LongInt;
  Nxt, After1, Ci, Ord_ : LongInt; Have : Boolean; ET : LongInt; ThrowL : LongInt; Ctx : LongInt;
  TabKeys, TabTg : Array Of LongInt; PrevB : LongInt;
Begin
  Mode := Nodes[N].E;
  If Mode = SW_PATTERN Then Begin GenPatternSwitch(N, IsExpr); Exit; End;
  Sel := Nodes[N].A;
  Mark := NextLoc;
  EndL := NewLabel;
  NCases := ChainLen(Nodes[N].B);
  SetLength(CaseL, NCases);
  For I := 0 To NCases - 1 Do CaseL[I] := NewLabel;
  DefCase := -1;
  Cs := Nodes[N].B;
  K := 0;
  While Cs <> 0 Do Begin
    If (Nodes[Cs].Aux And 1) <> 0 Then DefCase := K;
    Inc(K);
    Cs := Nodes[Cs].Next;
  End;
  If DefCase >= 0 Then Dflt := CaseL[DefCase]
  Else If IsExpr Then Dflt := NewLabel
  Else Dflt := EndL;
  ThrowL := Dflt;
  { contexte }
  PushGCtx(GC_SWITCH);
  If IsExpr Then GCtx[NGCtx - 1].Kind := GC_SWEXPR;
  GCtx[NGCtx - 1].BreakL := EndL;
  GCtx[NGCtx - 1].ResType := Nodes[N].Typ;
  Ctx := NGCtx - 1;
  LineMark(Nodes[N].Line);
  { collecte des etiquettes }
  SetLength(Keys, 0); SetLength(Tg, 0);
  NKeys := 0;
  Case Mode Of
    SW_STR : Begin
      SetLength(Strs, 0); SetLength(StrCase, 0);
      Cs := Nodes[N].B; K := 0;
      While Cs <> 0 Do Begin
        Lb := Nodes[Cs].A;
        While Lb <> 0 Do Begin
          SetLength(Strs, NKeys + 1); SetLength(StrCase, NKeys + 1);
          Strs[NKeys] := Nodes[Lb].CS; StrCase[NKeys] := K;
          Inc(NKeys);
          Lb := Nodes[Lb].Next;
        End;
        Inc(K);
        Cs := Nodes[Cs].Next;
      End;
    End;
  Else
    Cs := Nodes[N].B; K := 0;
    While Cs <> 0 Do Begin
      Lb := Nodes[Cs].A;
      While Lb <> 0 Do Begin
        SetLength(Keys, NKeys + 1); SetLength(Tg, NKeys + 1);
        If Mode = SW_ENUM Then Keys[NKeys] := EnumOrdinal(Nodes[Lb].Sym)
        Else Keys[NKeys] := Nodes[Lb].CI;
        Tg[NKeys] := CaseL[K];
        Inc(NKeys);
        Lb := Nodes[Lb].Next;
      End;
      Inc(K);
      Cs := Nodes[Cs].Next;
    End;
  End;
  { selecteur et saut }
  Case Mode Of
    SW_INT : Begin
      GenExpr(Sel);
      EmitIntSwitch(Keys, Tg, NKeys, Dflt);
    End;
    SW_ENUM : Begin
      GenExpr(Sel);
      EmitInvoke(OP_INVOKEVIRTUAL, ClassNameOfType(Nodes[Sel].Typ), 'ordinal', '()I', False);
      EmitIntSwitch(Keys, Tg, NKeys, Dflt);
    End;
    SW_STR : Begin
      S1 := AllocSlot(T_STRING);
      S2 := AllocSlot(TY_INT);
      GenExpr(Sel);
      EmitStore('A', S1, VTObj('java/lang/String'));
      EmitConstInt(-1);
      EmitStore('I', S2, VTSimple(VT_INT));
      After1 := NewLabel;
      { classement par code de hachage }
      SetLength(Hashes, NKeys);
      For I := 0 To NKeys - 1 Do Hashes[I] := JavaStringHash(Strs[I]);
      { distincts }
      SetLength(HK, NKeys); SetLength(HTg, NKeys);
      NH := 0;
      For I := 0 To NKeys - 1 Do Begin
        Have := False;
        For J := 0 To NH - 1 Do If HK[J] = Hashes[I] Then Have := True;
        If Not Have Then Begin HK[NH] := Hashes[I]; HTg[NH] := NewLabel; Inc(NH); End;
      End;
      EmitLoad('A', S1);
      EmitInvoke(OP_INVOKEVIRTUAL, 'java/lang/String', 'hashCode', '()I', False);
      SetLength(TabKeys, NH); SetLength(TabTg, NH);
      For I := 0 To NH - 1 Do Begin TabKeys[I] := HK[I]; TabTg[I] := HTg[I]; End;
      SortPairs(TabKeys, TabTg, NH);
      EmitLookupSwitch(NH, TabKeys, TabTg, After1);
      For I := 0 To NH - 1 Do Begin
        PlaceLabel(TabTg[I]);
        For J := 0 To NKeys - 1 Do
          If Hashes[J] = TabKeys[I] Then Begin
            Nxt := NewLabel;
            EmitLoad('A', S1);
            EmitConstString(Strs[J]);
            EmitInvoke(OP_INVOKEVIRTUAL, 'java/lang/String', 'equals', '(Ljava/lang/Object;)Z', False);
            EmitJump(OP_IFEQ, Nxt);
            EmitConstInt(J);
            EmitStore('I', S2, VTSimple(VT_INT));
            EmitJump(OP_GOTO, After1);
            PlaceLabel(Nxt);
          End;
        EmitJump(OP_GOTO, After1);
      End;
      PlaceLabel(After1);
      EmitLoad('I', S2);
      { second commutateur : indice -> cas }
      SetLength(Keys, NKeys); SetLength(Tg, NKeys);
      For I := 0 To NKeys - 1 Do Begin Keys[I] := I; Tg[I] := CaseL[StrCase[I]]; End;
      EmitIntSwitch(Keys, Tg, NKeys, Dflt);
    End;
  End;
  { corps des cas }
  Cs := Nodes[N].B; K := 0;
  While Cs <> 0 Do Begin
    PlaceLabel(CaseL[K]);
    If Alive Then Begin
      If (Nodes[Cs].Aux And 2) <> 0 Then Begin
        GenStmt(Nodes[Cs].B);
        If Alive And Not IsExpr Then EmitJump(OP_GOTO, EndL);
      End
      Else Begin
        Body := Nodes[Cs].B;
        PrevB := 0;
        While Body <> 0 Do Begin
          If Not Alive Then Begin If (PrevB <> 0) And Not CanComplete(PrevB) Then Err(Nodes[Body].Line, 'instruction inatteignable'); Break; End;
          GenStmt(Body);
          PrevB := Body;
          Body := Nodes[Body].Next;
        End;
      End;
    End;
    Inc(K);
    Cs := Nodes[Cs].Next;
  End;
  { sortie par defaut d'une expression sans default }
  If IsExpr And (DefCase < 0) Then Begin
    If Alive And (Nodes[N].B <> 0) Then Begin
      { chute apres le dernier cas : impossible pour une expression valide }
    End;
    PlaceLabel(ThrowL);
    If Alive Then Begin
      EmitNew('java/lang/IncompatibleClassChangeError');
      EmitDupValue;
      EmitInvoke(OP_INVOKESPECIAL, 'java/lang/IncompatibleClassChangeError', '<init>', '()V', False);
      EmitThrow;
    End;
  End;
  Dec(NGCtx);
  If IsExpr Then Begin
    { la valeur est sur la pile a la jonction }
    PlaceLabel(EndL);
  End
  Else PlaceLabel(EndL);
  FreeLocals(Mark);
  ET := 0; Cnt := 0; B := 0; F := 0; Ci := 0; Ord_ := 0; I := Ctx;
End;

{ ----- try / catch / finally ----------------------------------------------------- }

Type
  TSnap = Record
    L : Array Of TVT;
    N : LongInt;
    Fin : Int64;
  End;

Procedure TakeSnap(Var S : TSnap);
Var I : LongInt;
Begin
  SetLength(S.L, Length(CurL));
  For I := 0 To Length(CurL) - 1 Do S.L[I] := CurL[I];
  S.N := Length(CurL);
  S.Fin := CurFin;
End;

Procedure RestoreSnap(Var S : TSnap; Const Exc : TVT);
Var I : LongInt;
Begin
  For I := 0 To Length(CurL) - 1 Do
    If I < S.N Then CurL[I] := S.L[I] Else CurL[I] := VTSimple(VT_TOP);
  NSt := 0; StDepth := 0;
  CurFin := S.Fin;
  PushVT(Exc);
  Alive := True;
  AddFrame(Code.N);
End;

Procedure GenResources(N, R : LongInt); Forward;

Procedure GenTryBody(N : LongInt);
Begin
  If Nodes[N].A <> 0 Then GenResources(N, Nodes[N].A)
  Else GenStmt(Nodes[N].B);
End;

Procedure GenTry(N : LongInt);
Var
  Svd : Array[0..63] Of TGenCtx;
  Ctx, EndL, Cc, Ct, I, K, Mark, HPc, AnyPc, Tmp, EntryLoc, V : LongInt; Snap : TSnap; HasFin : Boolean;
  Hand : Array Of LongInt; NHand : LongInt; ExcT : LongInt; Sv : LongInt; Pcs : Array Of LongInt;
Begin
  LineMark(Nodes[N].Line);
  HasFin := Nodes[N].D <> 0;
  EndL := NewLabel;
  EntryLoc := NextLoc;
  TakeSnap(Snap);
  PushGCtx(GC_TRY);
  Ctx := NGCtx - 1;
  If HasFin Then Begin GCtx[Ctx].FinKind := FIN_BLOCK; GCtx[Ctx].FinNode := Nodes[N].D; End;
  OpenRange(Ctx);
  GenTryBody(N);
  CloseRange(Ctx);
  FreeLocals(EntryLoc);
  If Alive Then Begin
    If HasFin Then Begin
      HideCtxs(Ctx, Svd, Sv);
      GenStmt(Nodes[N].D);
      ShowCtxs(Ctx, Svd, Sv);
    End;
    If Alive Then EmitJump(OP_GOTO, EndL);
  End;
  { clauses catch }
  NHand := 0;
  SetLength(Pcs, 0);
  Cc := Nodes[N].C;
  While Cc <> 0 Do Begin
    ExcT := Locals[Nodes[Cc].Sym].Typ;
    RestoreSnap(Snap, VTOfType(ExcT));
    HPc := Code.N;
    SetLength(Pcs, NHand + 1); Pcs[NHand] := HPc; Inc(NHand);
    GCtx[Ctx].Mode := 1;
    OpenRange(Ctx);
    Mark := NextLoc;
    V := Nodes[Cc].Sym;
    DeclSlot(V);
    StoreLocal(V);
    GenStmt(Nodes[Cc].B);
    CloseRange(Ctx);
    FreeLocals(Mark);
    If Alive Then Begin
      If HasFin Then Begin
        HideCtxs(Ctx, Svd, Sv);
        GenStmt(Nodes[N].D);
        ShowCtxs(Ctx, Svd, Sv);
      End;
      If Alive Then EmitJump(OP_GOTO, EndL);
    End;
    Cc := Nodes[Cc].Next;
  End;
  { gestionnaire universel (finally) }
  AnyPc := -1;
  If HasFin Then Begin
    RestoreSnap(Snap, VTObj('java/lang/Throwable'));
    AnyPc := Code.N;
    Mark := NextLoc;
    Tmp := AllocSlot(T_THROWABLE);
    EmitStore('A', Tmp, VTObj('java/lang/Throwable'));
    HideCtxs(Ctx, Svd, Sv);
    GenStmt(Nodes[N].D);
    ShowCtxs(Ctx, Svd, Sv);
    If Alive Then Begin
      EmitLoad('A', Tmp);
      EmitThrow;
    End;
    FreeLocals(Mark);
  End;
  { table des exceptions : les clauses catch d'abord, puis le gestionnaire universel }
  K := 0;
  Cc := Nodes[N].C;
  While Cc <> 0 Do Begin
    Ct := Nodes[Cc].A;
    While Ct <> 0 Do Begin
      I := 0;
      While I < GCtx[Ctx].N1 Do Begin
        AddHandlerEntry(GCtx[Ctx].R1[I], GCtx[Ctx].R1[I + 1], Pcs[K], CPClass(TypeClassName(Nodes[Ct].Typ)));
        Inc(I, 2);
      End;
      Ct := Nodes[Ct].Next;
    End;
    Inc(K);
    Cc := Nodes[Cc].Next;
  End;
  If HasFin Then Begin
    I := 0;
    While I < GCtx[Ctx].N2 Do Begin
      AddHandlerEntry(GCtx[Ctx].R2[I], GCtx[Ctx].R2[I + 1], AnyPc, 0);
      Inc(I, 2);
    End;
  End;
  NGCtx := Ctx;
  PlaceLabel(EndL);
  FreeLocals(EntryLoc);
End;

{ try-with-resources : chaque ressource est fermee par un contexte de finalisation }
Procedure GenResources(N, R : LongInt);
Var
  Svd : Array[0..63] Of TGenCtx;
  Ctx, EndL, V, L, Slot, PSlot, Tmp, I, Mark, EntryLoc, AnyPc, Sv : LongInt; Snap : TSnap; T : LongInt;
Begin
  If R = 0 Then Begin GenStmt(Nodes[N].B); Exit; End;
  EntryLoc := NextLoc;
  { la ressource }
  If Nodes[R].Kind = N_LOCALVAR Then Begin
    GenLocalVar(R);
    L := Nodes[Nodes[R].B].Sym;
    Slot := SlotOf(L);
  End
  Else Begin
    T := Nodes[Nodes[R].A].Typ;
    GenExpr(Nodes[R].A);
    Slot := AllocSlot(T);
    EmitStore('A', Slot, VTOfType(T));
  End;
  PSlot := AllocSlot(T_THROWABLE);
  EmitNull;
  EmitStore('A', PSlot, VTObj('java/lang/Throwable'));
  EndL := NewLabel;
  TakeSnap(Snap);
  PushGCtx(GC_TRY);
  Ctx := NGCtx - 1;
  GCtx[Ctx].FinKind := FIN_TWR;
  GCtx[Ctx].FinSlot := Slot;
  GCtx[Ctx].FinSlot2 := PSlot;
  OpenRange(Ctx);
  GenResources(N, Nodes[R].Next);
  CloseRange(Ctx);
  If Alive Then Begin
    HideCtxs(Ctx, Svd, Sv);
    EmitFinalizer(Ctx);
    ShowCtxs(Ctx, Svd, Sv);
    EmitJump(OP_GOTO, EndL);
  End;
  { gestionnaire : primary = e ; fermeture ; relance }
  RestoreSnap(Snap, VTObj('java/lang/Throwable'));
  AnyPc := Code.N;
  Tmp := AllocSlot(T_THROWABLE);
  EmitStore('A', Tmp, VTObj('java/lang/Throwable'));
  EmitLoad('A', Tmp);
  EmitStore('A', PSlot, VTObj('java/lang/Throwable'));
  HideCtxs(Ctx, Svd, Sv);
  EmitFinalizer(Ctx);
  ShowCtxs(Ctx, Svd, Sv);
  EmitLoad('A', Tmp);
  EmitThrow;
  I := 0;
  While I < GCtx[Ctx].N2 Do Begin
    AddHandlerEntry(GCtx[Ctx].R2[I], GCtx[Ctx].R2[I + 1], AnyPc, 0);
    Inc(I, 2);
  End;
  NGCtx := Ctx;
  PlaceLabel(EndL);
  FreeLocals(EntryLoc);
  V := 0; Mark := 0;
End;

Procedure GenSync(N : LongInt);
Var Svd : Array[0..63] Of TGenCtx; Ctx, Slot, AnyPc, EndL, Tmp, Mark, I, Sv, EntryLoc : LongInt; Snap : TSnap; T : LongInt;
Begin
  LineMark(Nodes[N].Line);
  EntryLoc := NextLoc;
  T := Nodes[Nodes[N].A].Typ;
  GenExpr(Nodes[N].A);
  Slot := AllocSlot(T_OBJECT);
  EmitDupValue;
  EmitStore('A', Slot, VTOfType(T));
  EmitMonitor(True);
  EndL := NewLabel;
  TakeSnap(Snap);
  PushGCtx(GC_TRY);
  Ctx := NGCtx - 1;
  GCtx[Ctx].FinKind := FIN_MONITOR;
  GCtx[Ctx].FinSlot := Slot;
  OpenRange(Ctx);
  GenStmt(Nodes[N].B);
  CloseRange(Ctx);
  If Alive Then Begin
    HideCtxs(Ctx, Svd, Sv);
    EmitFinalizer(Ctx);
    ShowCtxs(Ctx, Svd, Sv);
    EmitJump(OP_GOTO, EndL);
  End;
  RestoreSnap(Snap, VTObj('java/lang/Throwable'));
  AnyPc := Code.N;
  Tmp := AllocSlot(T_THROWABLE);
  EmitStore('A', Tmp, VTObj('java/lang/Throwable'));
  HideCtxs(Ctx, Svd, Sv);
  EmitFinalizer(Ctx);
  ShowCtxs(Ctx, Svd, Sv);
  EmitLoad('A', Tmp);
  EmitThrow;
  I := 0;
  While I < GCtx[Ctx].N2 Do Begin
    AddHandlerEntry(GCtx[Ctx].R2[I], GCtx[Ctx].R2[I + 1], AnyPc, 0);
    Inc(I, 2);
  End;
  { le gestionnaire est protege par lui-meme comme javac : plage du monitorexit }
  NGCtx := Ctx;
  PlaceLabel(EndL);
  FreeLocals(EntryLoc);
  Mark := 0;
End;

{ ----- boucles ---------------------------------------------------------------------- }

Procedure GenForEach(N : LongInt);
Var
  Mark, Arr, Len, Idx, It, Lcond, Lend, Lcont, L, Ci : LongInt; ET, VT_, ExprT : LongInt; Owner : String; Iface : Boolean;
  C : LongInt; LoopLab : LongInt;
Begin
  LineMark(Nodes[N].Line);
  Mark := NextLoc;
  L := Nodes[N].Sym;
  ET := Nodes[N].E;
  ExprT := Nodes[Nodes[N].B].Typ;
  Lcond := NewLabel; Lend := NewLabel; Lcont := NewLabel;
  LoopLab := PendingLabelCtx;
  PendingLabelCtx := -1;
  PushGCtx(GC_LOOP);
  GCtx[NGCtx - 1].BreakL := Lend;
  If Nodes[N].Aux = 1 Then Begin
    GCtx[NGCtx - 1].ContL := Lcont;
    If LoopLab >= 0 Then GCtx[LoopLab].ContL := Lcont;
    GenExpr(Nodes[N].B);
    Arr := AllocSlot(ExprT);
    EmitStore('A', Arr, VTOfType(ExprT));
    EmitLoad('A', Arr);
    EmitArrayLength;
    Len := AllocSlot(TY_INT);
    EmitStore('I', Len, VTSimple(VT_INT));
    EmitConstInt(0);
    Idx := AllocSlot(TY_INT);
    EmitStore('I', Idx, VTSimple(VT_INT));
    DeclSlot(L);
    PlaceLoopLabel(Lcond);
    EmitLoad('I', Idx);
    EmitLoad('I', Len);
    EmitJump(OP_IF_ICMPGE, Lend);
    EmitLoad('A', Arr);
    EmitLoad('I', Idx);
    EmitArrayLoad(Erasure(ET));
    EnsureStackType(ET);
    EmitConvTypes(ET, Locals[L].Typ, False);
    StoreLocal(L);
    GenStmt(Nodes[N].C);
    PlaceLabel(Lcont);
    If Alive Then Begin
      EmitIinc(Idx, 1);
      EmitJump(OP_GOTO, Lcond);
    End;
  End
  Else Begin
    GCtx[NGCtx - 1].ContL := Lcond;
    If LoopLab >= 0 Then GCtx[LoopLab].ContL := Lcond;
    GenExpr(Nodes[N].B);
    C := ClsOf(Erasure(ExprT));
    If C < 0 Then C := C_ITERABLE;
    Owner := Classes[C].Name;
    Iface := IsInterfaceC(C);
    If Iface Then EmitInvoke(OP_INVOKEINTERFACE, Owner, 'iterator', '()Ljava/util/Iterator;', True)
    Else EmitInvoke(OP_INVOKEVIRTUAL, Owner, 'iterator', '()Ljava/util/Iterator;', False);
    It := AllocSlot(T_OBJECT);
    EmitStore('A', It, VTObj('java/util/Iterator'));
    DeclSlot(L);
    PlaceLoopLabel(Lcond);
    EmitLoad('A', It);
    EmitInvoke(OP_INVOKEINTERFACE, 'java/util/Iterator', 'hasNext', '()Z', True);
    EmitJump(OP_IFEQ, Lend);
    EmitLoad('A', It);
    EmitInvoke(OP_INVOKEINTERFACE, 'java/util/Iterator', 'next', '()Ljava/lang/Object;', True);
    If (ET <> T_OBJECT) And IsRef(ET) Then EnsureStackType(ET);
    EmitConvTypes(ET, Locals[L].Typ, False);
    StoreLocal(L);
    GenStmt(Nodes[N].C);
    If Alive Then EmitJump(OP_GOTO, Lcond);
  End;
  Dec(NGCtx);
  PlaceLabel(Lend);
  FreeLocals(Mark);
  VT_ := 0; Ci := 0;
End;

{ ----- instructions ---------------------------------------------------------------- }

Procedure GenBreakContinue(N : LongInt; IsBreak : Boolean);
Var I, T : LongInt; Lab : LongInt;
Begin
  T := -1;
  If Nodes[N].S <> '' Then Begin
    For I := NGCtx - 1 Downto 0 Do
      If (GCtx[I].Kind = GC_LABEL) And (GCtx[I].Name = Nodes[N].S) Then Begin T := I; Break; End;
  End
  Else Begin
    For I := NGCtx - 1 Downto 0 Do
      If (GCtx[I].Kind = GC_LOOP) Or ((GCtx[I].Kind = GC_SWITCH) And IsBreak) Then Begin T := I; Break; End;
  End;
  If T < 0 Then Begin Err(Nodes[N].Line, 'cible de break / continue introuvable'); Exit; End;
  If IsBreak Then Lab := GCtx[T].BreakL Else Lab := GCtx[T].ContL;
  If Lab < 0 Then Begin Err(Nodes[N].Line, 'continue hors d''une boucle'); Exit; End;
  LeaveCtxs(T);
  If Alive Then EmitJump(OP_GOTO, Lab);
  ReopenCtxs(T);
End;

Procedure GenReturn(N : LongInt);
Var T, Slot, K : LongInt; HasVal : Boolean;
Begin
  LineMark(Nodes[N].Line);
  HasVal := Nodes[N].A <> 0;
  If HasVal Then Begin
    GenExpr(Nodes[N].A);
    T := GenRet;
    If Not HasTryCtx(-1) Then Begin
      EmitReturnOp(KindOf(T));
      Exit;
    End;
    Slot := AllocSlot(T);
    EmitStore(KindOf(T), Slot, VTOfType(T));
    LeaveCtxs(-1);
    If Alive Then Begin
      EmitLoad(KindOf(T), Slot);
      EmitReturnOp(KindOf(T));
    End;
    ReopenCtxs(-1);
  End
  Else Begin
    LeaveCtxs(-1);
    If Alive Then EmitReturnOp('V');
    ReopenCtxs(-1);
  End;
  K := 0;
End;

Procedure GenYield(N : LongInt);
Var I, T, Slot, Ty : LongInt;
Begin
  T := -1;
  For I := NGCtx - 1 Downto 0 Do
    If GCtx[I].Kind = GC_SWEXPR Then Begin T := I; Break; End;
  If T < 0 Then Begin Err(Nodes[N].Line, 'yield en dehors d''une expression switch'); Exit; End;
  GenExpr(Nodes[N].A);
  Ty := GCtx[T].ResType;
  If IsRef(Ty) Then ForceTopType(Ty);
  If HasTryCtx(T) Then Begin
    Slot := AllocSlot(Ty);
    EmitStore(KindOf(Ty), Slot, VTOfType(Ty));
    LeaveCtxs(T);
    EmitLoad(KindOf(Ty), Slot);
    EmitJump(OP_GOTO, GCtx[T].BreakL);
    ReopenCtxs(T);
  End
  Else EmitJump(OP_GOTO, GCtx[T].BreakL);
End;

Procedure GenLoopHeadStmt(N : LongInt);
Var Lcond, Lend, Lcont, Mark, S, Ltop : LongInt; Lab : LongInt;
Begin
  LineMark(Nodes[N].Line);
  Lend := NewLabel; Lcont := NewLabel; Ltop := NewLabel;
  Mark := NextLoc;
  Lab := PendingLabelCtx;
  PendingLabelCtx := -1;
  Case Nodes[N].Kind Of
    N_WHILE : Begin
      PlaceLoopLabel(Ltop);
      GenBranch(Nodes[N].A, Lend, False);
      PushGCtx(GC_LOOP);
      GCtx[NGCtx - 1].BreakL := Lend; GCtx[NGCtx - 1].ContL := Ltop;
      If Lab >= 0 Then GCtx[Lab].ContL := Ltop;
      GenStmt(Nodes[N].B);
      Dec(NGCtx);
      If Alive Then EmitJump(OP_GOTO, Ltop);
      PlaceLabel(Lend);
    End;
    N_DO : Begin
      PlaceLoopLabel(Ltop);
      PushGCtx(GC_LOOP);
      GCtx[NGCtx - 1].BreakL := Lend; GCtx[NGCtx - 1].ContL := Lcont;
      If Lab >= 0 Then GCtx[Lab].ContL := Lcont;
      GenStmt(Nodes[N].A);
      Dec(NGCtx);
      PlaceLabel(Lcont);
      If Alive Then GenBranch(Nodes[N].B, Ltop, True);
      PlaceLabel(Lend);
    End;
    N_FOR : Begin
      S := Nodes[N].A;
      While S <> 0 Do Begin GenStmt(S); S := Nodes[S].Next; End;
      PlaceLoopLabel(Ltop);
      If Nodes[N].B <> 0 Then GenBranch(Nodes[N].B, Lend, False);
      PushGCtx(GC_LOOP);
      GCtx[NGCtx - 1].BreakL := Lend; GCtx[NGCtx - 1].ContL := Lcont;
      If Lab >= 0 Then GCtx[Lab].ContL := Lcont;
      GenStmt(Nodes[N].D);
      Dec(NGCtx);
      PlaceLabel(Lcont);
      S := Nodes[N].C;
      While S <> 0 Do Begin GenStmt(S); S := Nodes[S].Next; End;
      If Alive Then EmitJump(OP_GOTO, Ltop);
      PlaceLabel(Lend);
    End;
  End;
  FreeLocals(Mark);
  Lcond := 0;
End;

Procedure GenAssert(N : LongInt);
Var F, Lend, T : LongInt; Desc : String;
Begin
  LineMark(Nodes[N].Line);
  F := FindFieldIn(GenCls, '$assertionsDisabled');
  Lend := NewLabel;
  If F >= 0 Then Begin
    EmitGetField(True, Classes[GenCls].Name, '$assertionsDisabled', 'Z', TY_BOOLEAN);
    EmitJump(OP_IFNE, Lend);
  End;
  GenBranch(Nodes[N].A, Lend, True);
  If Alive Then Begin
    EmitNew('java/lang/AssertionError');
    EmitDupValue;
    If Nodes[N].B <> 0 Then Begin
      GenExpr(Nodes[N].B);
      T := Nodes[Nodes[N].B].Typ;
      Case T Of
        TY_BOOLEAN : Desc := '(Z)V';
        TY_CHAR : Desc := '(C)V';
        TY_BYTE, TY_SHORT, TY_INT : Desc := '(I)V';
        TY_LONG : Desc := '(J)V';
        TY_FLOAT : Desc := '(F)V';
        TY_DOUBLE : Desc := '(D)V';
      Else
        Desc := '(Ljava/lang/Object;)V';
      End;
    End
    Else Desc := '()V';
    EmitInvoke(OP_INVOKESPECIAL, 'java/lang/AssertionError', '<init>', Desc, False);
    EmitThrow;
  End;
  PlaceLabel(Lend);
End;

Procedure GenStmt(N : LongInt);
Var S, Mark, T, L, Lab, Prev : LongInt;
Begin
  If N = 0 Then Exit;
  If Not Alive Then Exit;
  If Not (Nodes[N].Kind In [N_LABELED, N_WHILE, N_DO, N_FOR, N_FOREACH]) Then PendingLabelCtx := -1;
  Case Nodes[N].Kind Of
    N_BLOCK : Begin
      Mark := NextLoc;
      Prev := 0;
      S := Nodes[N].A;
      While S <> 0 Do Begin
        If Not Alive Then Begin
          If (Prev <> 0) And Not CanComplete(Prev) Then Err(Nodes[S].Line, 'instruction inatteignable');
          Break;
        End;
        GenStmt(S);
        Prev := S;
        S := Nodes[S].Next;
      End;
      FreeLocals(Mark);
    End;
    N_EMPTY, N_LOCALCLASS : ;
    N_LOCALVAR : GenLocalVar(N);
    N_EXPRSTMT : Begin
      LineMark(Nodes[N].Line);
      GenExprDiscard(Nodes[N].A);
    End;
    N_IF : Begin
      LineMark(Nodes[N].Line);
      L := NewLabel;
      GenBranch(Nodes[N].A, L, False);
      If Nodes[N].C = 0 Then Begin
        GenStmt(Nodes[N].B);
        PlaceLabel(L);
      End
      Else Begin
        T := NewLabel;
        GenStmt(Nodes[N].B);
        If Alive Then EmitJump(OP_GOTO, T);
        PlaceLabel(L);
        GenStmt(Nodes[N].C);
        PlaceLabel(T);
      End;
    End;
    N_WHILE, N_DO, N_FOR : GenLoopHeadStmt(N);
    N_FOREACH : GenForEach(N);
    N_RETURN : GenReturn(N);
    N_BREAK : GenBreakContinue(N, True);
    N_CONTINUE : GenBreakContinue(N, False);
    N_THROW : Begin
      LineMark(Nodes[N].Line);
      GenExpr(Nodes[N].A);
      EmitThrow;
    End;
    N_TRY : GenTry(N);
    N_SWITCH : GenSwitch(N, False);
    N_SYNC : GenSync(N);
    N_YIELD : GenYield(N);
    N_LABELED : Begin
      L := NewLabel;
      PushGCtx(GC_LABEL);
      GCtx[NGCtx - 1].Name := Nodes[N].S;
      GCtx[NGCtx - 1].BreakL := L;
      Lab := NGCtx - 1;
      If Nodes[Nodes[N].A].Kind In [N_WHILE, N_DO, N_FOR, N_FOREACH] Then PendingLabelCtx := Lab Else PendingLabelCtx := -1;
      GenStmt(Nodes[N].A);
      PendingLabelCtx := -1;
      Dec(NGCtx);
      PlaceLabel(L);
    End;
    N_ASSERT : GenAssert(N);
  Else
    Internal('GenStmt : instruction inattendue ' + IStr(Nodes[N].Kind));
  End;
End;

{ ============================================================================
  Ecriture des annotations dans les fichiers .class
  (RuntimeVisibleAnnotations, RuntimeInvisibleAnnotations, parametres, AnnotationDefault)
  ============================================================================ }

Var NoDeprecatedAttr : Boolean;

Function ElemTagOf(T : LongInt) : LongInt;
Begin
  Case T Of
    TY_BOOLEAN : ElemTagOf := Ord('Z');
    TY_BYTE    : ElemTagOf := Ord('B');
    TY_CHAR    : ElemTagOf := Ord('C');
    TY_SHORT   : ElemTagOf := Ord('S');
    TY_INT     : ElemTagOf := Ord('I');
    TY_LONG    : ElemTagOf := Ord('J');
    TY_FLOAT   : ElemTagOf := Ord('F');
    TY_DOUBLE  : ElemTagOf := Ord('D');
  Else
    ElemTagOf := Ord('s');
  End;
End;

Procedure WriteAnnotation(Var B : TBuf; A : LongInt); Forward;

Procedure WriteElemValue(Var B : TBuf; N, T : LongInt);
Var E, Ch, Cnt : LongInt; Bits : TDblBits;
Begin
  If IsArrayT(T) Then Begin
    E := ElemOf(T);
    B1(B, Ord('['));
    If Nodes[N].Kind = N_ARRAYINIT Then Begin
      Cnt := ChainLen(Nodes[N].A);
      B2(B, Cnt);
      Ch := Nodes[N].A;
      While Ch <> 0 Do Begin WriteElemValue(B, Ch, E); Ch := Nodes[Ch].Next; End;
    End
    Else Begin
      B2(B, 1);
      WriteElemValue(B, N, E);
    End;
    Exit;
  End;
  If Nodes[N].Kind = N_ANNOT Then Begin
    B1(B, Ord('@'));
    WriteAnnotation(B, N);
    Exit;
  End;
  If IsPrim(T) Then Begin
    FoldConstTo(N, T);
    B1(B, ElemTagOf(T));
    Case T Of
      TY_LONG : B2(B, CPLong(Nodes[N].CI));
      TY_FLOAT : Begin Bits.I := 0; Bits.S := Nodes[N].CD; B2(B, CPFloat(Bits.L)); End;
      TY_DOUBLE : Begin Bits.D := Nodes[N].CD; B2(B, CPDouble(Bits.I)); End;
    Else
      B2(B, CPInt(Nodes[N].CI));
    End;
    Exit;
  End;
  If T = T_STRING Then Begin
    B1(B, Ord('s'));
    B2(B, CPUtf8(Nodes[N].CS));
    Exit;
  End;
  If Nodes[N].Dflt > 0 Then Begin
    { constante d'enumeration }
    B1(B, Ord('e'));
    B2(B, CPUtf8(TypeDesc(T)));
    B2(B, CPUtf8(Fields[Nodes[N].Dflt - 1].Name));
    Exit;
  End;
  { litteral de classe }
  B1(B, Ord('c'));
  B2(B, CPUtf8(TypeDesc(Erasure(Nodes[N].E))));
End;

Procedure WriteAnnotation(Var B : TBuf; A : LongInt);
Var G, Cnt : LongInt;
Begin
  B2(B, CPUtf8('L' + Classes[Nodes[A].Sym].Name + ';'));
  Cnt := 0;
  G := Nodes[A].A;
  While G <> 0 Do Begin If Nodes[G].Sym >= 0 Then Inc(Cnt); G := Nodes[G].Next; End;
  B2(B, Cnt);
  G := Nodes[A].A;
  While G <> 0 Do Begin
    If Nodes[G].Sym >= 0 Then Begin
      B2(B, CPUtf8(Nodes[G].S));
      WriteElemValue(B, Nodes[G].A, Meths[Nodes[G].Sym].Ret);
    End;
    G := Nodes[G].Next;
  End;
End;

{ L'annotation A (analysee) s'applique-t-elle a la cible Kind (masque TGT_*) ? }
Function AnnApplies(A, Kind : LongInt) : Boolean;
Var Meta : TAnnMetaRec;
Begin
  AnnApplies := False;
  If Nodes[A].Sym < 0 Then Exit;
  Meta := AnnMeta(Nodes[A].Sym);
  AnnApplies := ((Meta.Tgt And Kind) <> 0) Or (((Kind And TGT_TYPE) <> 0) And ((Meta.Tgt And TGT_TYPEUSE) <> 0));
End;

{ Ecrit dans Buf les annotations de la chaine Head dont la retention est Ret ; Cnt = nombre ecrit.
  Les annotations repetees sont regroupees dans leur conteneur. }
Procedure CollectAnnots(Var Buf : TBuf; Var Cnt : LongInt; Head, Kind, Ret : LongInt);
Var
  L : Array[0..127] Of LongInt; Done : Array[0..127] Of Boolean; N, I, J, K, Same : LongInt; Meta, Meta2 : TAnnMetaRec;
  A : LongInt;
Begin
  N := 0;
  A := Head;
  While (A <> 0) And (N < 128) Do Begin
    If AnnApplies(A, Kind) Then Begin L[N] := A; Done[N] := False; Inc(N); End;
    A := Nodes[A].Next;
  End;
  For I := 0 To N - 1 Do Begin
    If Done[I] Then Continue;
    Meta := AnnMeta(Nodes[L[I]].Sym);
    Same := 0;
    For J := I To N - 1 Do If Nodes[L[J]].Sym = Nodes[L[I]].Sym Then Begin Inc(Same); Done[J] := True; End;
    If (Same > 1) And (Meta.Cont >= 0) Then Begin
      Meta2 := AnnMeta(Meta.Cont);
      If Meta2.Ret = Ret Then Begin
        B2(Buf, CPUtf8('L' + Classes[Meta.Cont].Name + ';'));
        B2(Buf, 1);
        B2(Buf, CPUtf8('value'));
        B1(Buf, Ord('['));
        B2(Buf, Same);
        For K := I To N - 1 Do
          If Nodes[L[K]].Sym = Nodes[L[I]].Sym Then Begin B1(Buf, Ord('@')); WriteAnnotation(Buf, L[K]); End;
        Inc(Cnt);
      End;
    End
    Else If Meta.Ret = Ret Then Begin
      WriteAnnotation(Buf, L[I]);
      Inc(Cnt);
    End;
  End;
End;

Function HasDeprecated(Head : LongInt) : Boolean;
Var A : LongInt;
Begin
  HasDeprecated := False;
  A := Head;
  While A <> 0 Do Begin
    If (Nodes[A].Sym >= 0) And (Classes[Nodes[A].Sym].Name = 'java/lang/Deprecated') Then HasDeprecated := True;
    A := Nodes[A].Next;
  End;
End;

{ Attributs d'annotations d'une declaration : Deprecated, RuntimeVisible/InvisibleAnnotations }
Procedure EmitAnnotAttrs(Var Attr : TBuf; Var NA : LongInt; Head, Kind : LongInt);
Var Vis, Inv : TBuf; NV, NI : LongInt;
Begin
  If Head = 0 Then Exit;
  BInit(Vis); BInit(Inv);
  NV := 0; NI := 0;
  CollectAnnots(Vis, NV, Head, Kind, RET_RUNTIME);
  CollectAnnots(Inv, NI, Head, Kind, RET_CLASS);
  If HasDeprecated(Head) And Not NoDeprecatedAttr Then Begin B2(Attr, CPUtf8('Deprecated')); B4(Attr, 0); Inc(NA); End;
  If NV > 0 Then Begin
    B2(Attr, CPUtf8('RuntimeVisibleAnnotations')); B4(Attr, 2 + Vis.N); B2(Attr, NV); BAppend(Attr, Vis); Inc(NA);
  End;
  If NI > 0 Then Begin
    B2(Attr, CPUtf8('RuntimeInvisibleAnnotations')); B4(Attr, 2 + Inv.N); B2(Attr, NI); BAppend(Attr, Inv); Inc(NA);
  End;
End;

{ Annotations des parametres : Params = chaine de N_PARAM }
Procedure EmitParamAnnotAttrs(Var Attr : TBuf; Var NA : LongInt; Params : LongInt);
Var
  Ret, NP, P, Cnt, Any : LongInt; Buf, Tmp : TBuf; Nm : String;
Begin
  If Params = 0 Then Exit;
  NP := ChainLen(Params);
  For Ret := RET_CLASS To RET_RUNTIME Do Begin
    BInit(Buf);
    Any := 0;
    B1(Buf, NP);
    P := Params;
    While P <> 0 Do Begin
      BInit(Tmp);
      Cnt := 0;
      CollectAnnots(Tmp, Cnt, Nodes[P].Ann, TGT_PARAMETER, Ret);
      B2(Buf, Cnt);
      BAppend(Buf, Tmp);
      Inc(Any, Cnt);
      P := Nodes[P].Next;
    End;
    If Any > 0 Then Begin
      If Ret = RET_RUNTIME Then Nm := 'RuntimeVisibleParameterAnnotations' Else Nm := 'RuntimeInvisibleParameterAnnotations';
      B2(Attr, CPUtf8(Nm)); B4(Attr, Buf.N); BAppend(Attr, Buf); Inc(NA);
    End;
  End;
End;

Procedure EmitAnnotDefault(Var Attr : TBuf; Var NA : LongInt; Decl, RetT : LongInt);
Var Tmp : TBuf;
Begin
  If (Decl = 0) Or (Nodes[Decl].Dflt = 0) Then Exit;
  BInit(Tmp);
  WriteElemValue(Tmp, Nodes[Decl].Dflt, RetT);
  B2(Attr, CPUtf8('AnnotationDefault')); B4(Attr, Tmp.N); BAppend(Attr, Tmp); Inc(NA);
End;

{ ----- annotations de type (TYPE_USE) placees en position de declaration ----------------------- }

{ chemin de type d'une annotation placee devant le type declare T : une etape par dimension de tableau,
  puis une etape par niveau de classe interne (non statique) }
Procedure TypePathOf(T : LongInt; Var Path : TBuf; Var Len : LongInt);
Var K : LongInt;
Begin
  Len := 0;
  BInit(Path);
  While IsArrayT(T) Do Begin B1(Path, 0); B1(Path, 0); Inc(Len); T := ElemOf(T); End;
  If IsClassT(T) Then Begin
    K := ClsOf(T);
    While (Classes[K].Outer >= 0) And ((Classes[K].Flags And (ACC_STATIC Or ACC_INTERFACE Or ACC_ENUM)) = 0) And
          ((Classes[K].Flags And MOD_LOCAL) = 0) And (Nodes[Classes[K].Decl].Aux <> CLS_RECORD) Do Begin
      B1(Path, 1); B1(Path, 0); Inc(Len);
      K := Classes[K].Outer;
    End;
  End;
End;

Var
  TaBuf : Array[0..2] Of TBuf;
  TaCnt : Array[0..2] Of LongInt;

Procedure TypeAnnotsReset;
Var R : LongInt;
Begin
  For R := 0 To 2 Do Begin BInit(TaBuf[R]); TaCnt[R] := 0; End;
End;

{ Accumule les annotations TYPE_USE de Head.
  TgtType : 13h champ, 14h retour de methode / constructeur, 16h parametre (Idx) }
Procedure TypeAnnotsAdd(Head, TgtType, Idx, T : LongInt);
Var A, PLen, Ret : LongInt; Path : TBuf; Meta : TAnnMetaRec;
Begin
  If Head = 0 Then Exit;
  TypePathOf(T, Path, PLen);
  A := Head;
  While A <> 0 Do Begin
    If Nodes[A].Sym >= 0 Then Begin
      Meta := AnnMeta(Nodes[A].Sym);
      Ret := Meta.Ret;
      If ((Meta.Tgt And TGT_TYPEUSE) <> 0) And (Ret >= RET_CLASS) Then Begin
        B1(TaBuf[Ret], TgtType);
        If TgtType = $16 Then B1(TaBuf[Ret], Idx);
        B1(TaBuf[Ret], PLen);
        BAppend(TaBuf[Ret], Path);
        WriteAnnotation(TaBuf[Ret], A);
        Inc(TaCnt[Ret]);
      End;
    End;
    A := Nodes[A].Next;
  End;
End;

Procedure TypeAnnotsFlush(Var Attr : TBuf; Var NA : LongInt);
Begin
  If TaCnt[RET_CLASS] > 0 Then Begin
    B2(Attr, CPUtf8('RuntimeInvisibleTypeAnnotations')); B4(Attr, 2 + TaBuf[RET_CLASS].N);
    B2(Attr, TaCnt[RET_CLASS]); BAppend(Attr, TaBuf[RET_CLASS]); Inc(NA);
  End;
  If TaCnt[RET_RUNTIME] > 0 Then Begin
    B2(Attr, CPUtf8('RuntimeVisibleTypeAnnotations')); B4(Attr, 2 + TaBuf[RET_RUNTIME].N);
    B2(Attr, TaCnt[RET_RUNTIME]); BAppend(Attr, TaBuf[RET_RUNTIME]); Inc(NA);
  End;
End;

{ ============================================================================
  Attributs Signature (generiques) et Exceptions
  ============================================================================ }

Function SigOfType(T : LongInt) : String;
Var I : LongInt; S : String;
Begin
  If T < TY_FIRSTDYN Then Begin
    If (T = TY_NONE) Or (T = TY_NULL) Then SigOfType := 'Ljava/lang/Object;' Else SigOfType := TypeDesc(T);
    Exit;
  End;
  Case Types[T].Kind Of
    TYK_ARRAY : SigOfType := '[' + SigOfType(Types[T].Elem);
    TYK_TVAR  : SigOfType := 'T' + TVars[Types[T].TV].Name + ';';
    TYK_CLASS : Begin
      S := 'L' + Classes[Types[T].Cls].Name;
      If Types[T].NArgs > 0 Then Begin
        S := S + '<';
        For I := 0 To Types[T].NArgs - 1 Do S := S + SigOfType(Types[T].Args[I]);
        S := S + '>';
      End;
      SigOfType := S + ';';
    End;
  Else
    SigOfType := 'Ljava/lang/Object;';
  End;
End;

Function TypeGenericT(T : LongInt) : Boolean;
Var I : LongInt;
Begin
  TypeGenericT := False;
  If T <= 0 Then Exit;
  I := T;
  While IsArrayT(I) Do I := ElemOf(I);
  If I >= TY_FIRSTDYN Then
    TypeGenericT := (Types[I].Kind = TYK_TVAR) Or ((Types[I].Kind = TYK_CLASS) And (Types[I].NArgs > 0));
End;

{ Le type decrit par le noeud N est-il generique (variable de type ou type parametre) ? }
Function NodeGeneric(N : LongInt) : Boolean;
Var T, I : LongInt;
Begin
  NodeGeneric := False;
  If (N = 0) Or (Nodes[N].Kind <> N_TYPE) Then Exit;
  T := Nodes[N].Typ;
  If T <= 0 Then Exit;
  If Nodes[N].Aux = 2 Then Begin NodeGeneric := TypeGenericT(T); Exit; End;
  I := T;
  While IsArrayT(I) Do I := ElemOf(I);
  If I >= TY_FIRSTDYN Then
    If Types[I].Kind = TYK_TVAR Then NodeGeneric := True
    Else If (Types[I].Kind = TYK_CLASS) And (Nodes[N].A <> 0) Then NodeGeneric := True;
End;

Function SigOfNode(N : LongInt) : String;
Var T, I, A : LongInt; S, Args : String;
Begin
  If N = 0 Then Begin SigOfNode := ''; Exit; End;
  T := Nodes[N].Typ;
  If (Nodes[N].Aux = 2) Or (T <= 0) Then Begin SigOfNode := SigOfType(T); Exit; End;
  S := '';
  If Nodes[N].Aux = 1 Then Begin
    For I := 1 To Nodes[N].N Do S := S + '[';
    SigOfNode := S + TypeDesc(T);
    Exit;
  End;
  For I := 1 To Nodes[N].N Do Begin
    If IsArrayT(T) Then T := ElemOf(T);
    S := S + '[';
  End;
  If (T >= TY_FIRSTDYN) And (Types[T].Kind = TYK_CLASS) Then Begin
    S := S + 'L' + Classes[Types[T].Cls].Name;
    If Nodes[N].A <> 0 Then Begin
      Args := '<';
      A := Nodes[N].A;
      While A <> 0 Do Begin
        If Nodes[A].Kind = N_WILD Then Begin
          If (Nodes[A].Aux = 0) Or (Nodes[A].A = 0) Then Args := Args + '*'
          Else If Nodes[A].Aux = 1 Then Args := Args + '+' + SigOfNode(Nodes[A].A)
          Else Args := Args + '-' + SigOfNode(Nodes[A].A);
        End
        Else Args := Args + SigOfNode(A);
        A := Nodes[A].Next;
      End;
      S := S + Args + '>';
    End;
    SigOfNode := S + ';';
  End
  Else SigOfNode := S + SigOfType(T);
End;

{ <T:Ljava/lang/Object;U::Ljava/lang/Comparable<TU;>;> : Head = chaine de N_TPARAM }
Function SigOfTParams(Head : LongInt) : String;
Var Tp, B, T : LongInt; S : String; First : Boolean;
Begin
  S := '<';
  Tp := Head;
  While Tp <> 0 Do Begin
    S := S + Nodes[Tp].S;
    B := Nodes[Tp].A;
    If B = 0 Then S := S + ':Ljava/lang/Object;'
    Else Begin
      First := True;
      While B <> 0 Do Begin
        T := Nodes[B].Typ;
        If First Then Begin
          If (T >= TY_FIRSTDYN) And (Types[T].Kind = TYK_CLASS) And ((Classes[Types[T].Cls].Flags And ACC_INTERFACE) <> 0) Then
            S := S + '::'
          Else S := S + ':';
        End
        Else S := S + ':';
        S := S + SigOfNode(B);
        First := False;
        B := Nodes[B].Next;
      End;
    End;
    Tp := Nodes[Tp].Next;
  End;
  SigOfTParams := S + '>';
End;

Procedure EmitSignatureAttr(Var Attr : TBuf; Var NA : LongInt; Const Sig : String);
Begin
  If Sig = '' Then Exit;
  B2(Attr, CPUtf8('Signature')); B4(Attr, 2); B2(Attr, CPUtf8(Sig)); Inc(NA);
End;

Function FieldSignature(F : LongInt) : String;
Var D, T, I : LongInt; S : String;
Begin
  FieldSignature := '';
  D := Fields[F].Decl;
  If D <= 0 Then Exit;
  If Nodes[D].Kind = N_PARAM Then T := Nodes[D].A
  Else If Nodes[D].Kind = N_VARDECL Then T := Nodes[D].E
  Else Exit;
  If (T = 0) Or (Nodes[T].Kind <> N_TYPE) Or Not NodeGeneric(T) Then Exit;
  S := SigOfNode(T);
  If Nodes[D].Kind = N_VARDECL Then For I := 1 To Nodes[D].N Do S := '[' + S;
  FieldSignature := S;
End;

Function MethodSignature(M : LongInt) : String;
Var D, P, T : LongInt; S, Thr : String; Need : Boolean;
Begin
  MethodSignature := '';
  D := Meths[M].Decl;
  If D <= 0 Then Exit;
  Need := Nodes[D].E <> 0;
  If Nodes[D].Aux <> 1 Then If NodeGeneric(Nodes[D].A) Then Need := True;
  P := Nodes[D].B;
  While P <> 0 Do Begin If NodeGeneric(Nodes[P].A) Then Need := True; P := Nodes[P].Next; End;
  Thr := '';
  P := Nodes[D].D;
  While P <> 0 Do Begin
    T := Nodes[P].Typ;
    If NodeGeneric(P) Then Begin Need := True; End;
    P := Nodes[P].Next;
  End;
  If Not Need Then Exit;
  S := '';
  If Nodes[D].E <> 0 Then S := SigOfTParams(Nodes[D].E);
  S := S + '(';
  P := Nodes[D].B;
  While P <> 0 Do Begin S := S + SigOfNode(Nodes[P].A); P := Nodes[P].Next; End;
  S := S + ')';
  If Nodes[D].Aux = 1 Then S := S + 'V' Else S := S + SigOfNode(Nodes[D].A);
  { clause throws : seulement si une variable de type ou un type parametre y figure }
  P := Nodes[D].D;
  Need := False;
  While P <> 0 Do Begin If NodeGeneric(P) Then Need := True; P := Nodes[P].Next; End;
  If Need Then Begin
    P := Nodes[D].D;
    While P <> 0 Do Begin S := S + '^' + SigOfNode(P); P := Nodes[P].Next; End;
  End;
  MethodSignature := S;
End;

Function ClassSignature(C : LongInt) : String;
Var D, P, I : LongInt; S : String; Need : Boolean;
Begin
  ClassSignature := '';
  D := Classes[C].Decl;
  If D <= 0 Then Exit;
  S := '';
  If (Classes[C].Flags And MOD_ANON) <> 0 Then Begin
    { classe anonyme : types deja resolus }
    Need := False;
    If TypeGenericT(Classes[C].Super) Then Need := True;
    For I := 0 To Length(Classes[C].Ifaces) - 1 Do
      If TypeGenericT(Classes[C].Ifaces[I]) Then Need := True;
    If Not Need Then Exit;
    S := SigOfType(Classes[C].Super);
    For I := 0 To Length(Classes[C].Ifaces) - 1 Do S := S + SigOfType(Classes[C].Ifaces[I]);
    ClassSignature := S;
    Exit;
  End;
  Need := Nodes[D].A <> 0;
  If Nodes[D].Aux = CLS_ENUM Then Need := True;
  If (Nodes[D].Aux <> CLS_INTERFACE) And NodeGeneric(Nodes[D].B) Then Need := True;
  P := Nodes[D].C;
  While P <> 0 Do Begin If NodeGeneric(P) Then Need := True; P := Nodes[P].Next; End;
  If Not Need Then Exit;
  If Nodes[D].A <> 0 Then S := SigOfTParams(Nodes[D].A);
  Case Nodes[D].Aux Of
    CLS_ENUM : S := S + 'Ljava/lang/Enum<L' + Classes[C].Name + ';>;';
    CLS_RECORD : S := S + 'Ljava/lang/Record;';
    CLS_INTERFACE, CLS_ANNOTATION : S := S + 'Ljava/lang/Object;';
  Else
    If Nodes[D].B <> 0 Then S := S + SigOfNode(Nodes[D].B) Else S := S + 'Ljava/lang/Object;';
  End;
  If Nodes[D].Aux = CLS_ANNOTATION Then S := S + 'Ljava/lang/annotation/Annotation;';
  P := Nodes[D].C;
  While P <> 0 Do Begin S := S + SigOfNode(P); P := Nodes[P].Next; End;
  ClassSignature := S;
End;

Procedure EmitExceptionsAttr(Var Attr : TBuf; Var NA : LongInt; M : LongInt);
Var I, N, D, P, T : LongInt; Cls : Array Of LongInt;
Begin
  N := 0;
  D := Meths[M].Decl;
  If D > 0 Then Begin
    { d'apres les types declares : une variable de type est remplacee par son effacement }
    P := Nodes[D].D;
    While P <> 0 Do Begin
      T := Erasure(Nodes[P].Typ);
      If IsClassT(T) Then Begin SetLength(Cls, N + 1); Cls[N] := Types[T].Cls; Inc(N); End;
      P := Nodes[P].Next;
    End;
  End
  Else Begin
    N := Length(Meths[M].Thr);
    SetLength(Cls, N);
    For I := 0 To N - 1 Do Cls[I] := Meths[M].Thr[I];
  End;
  If N = 0 Then Exit;
  B2(Attr, CPUtf8('Exceptions')); B4(Attr, 2 + 2 * N); B2(Attr, N);
  For I := 0 To N - 1 Do B2(Attr, CPClass(Classes[Cls[I]].Name));
  Inc(NA);
End;

{ Attribut Record : un composant par parametre de l'en-tete du record }
Procedure EmitRecordAttr(Var Attr : TBuf; Var NA : LongInt; C : LongInt);
Var P, F, Cnt, NA2 : LongInt; Buf, Comp : TBuf;
Begin
  BInit(Buf);
  Cnt := 0;
  P := Nodes[Classes[C].Decl].E;
  While P <> 0 Do Begin
    F := FindFieldIn(C, Nodes[P].S);
    If F >= 0 Then Begin
      B2(Buf, CPUtf8(Nodes[P].S));
      B2(Buf, CPUtf8(FieldDescOf(F)));
      BInit(Comp);
      NA2 := 0;
      If NodeGeneric(Nodes[P].A) Then EmitSignatureAttr(Comp, NA2, SigOfNode(Nodes[P].A));
      EmitAnnotAttrs(Comp, NA2, Nodes[P].Ann, TGT_RECCOMP);
      B2(Buf, NA2);
      BAppend(Buf, Comp);
      Inc(Cnt);
    End;
    P := Nodes[P].Next;
  End;
  B2(Attr, CPUtf8('Record')); B4(Attr, 2 + Buf.N); B2(Attr, Cnt); BAppend(Attr, Buf); Inc(NA);
End;


{ Sous-classes permises ecrites dans PermittedSubclasses : classes scellees et enums a constantes a corps }
Procedure PermittedOf(C : LongInt; Var L : TTyArr);
Var X, N : LongInt;
Begin
  SetLength(L, 0);
  If Not Classes[C].IsSrc Then Exit;
  If (Classes[C].Flags And MOD_SEALED) <> 0 Then Begin
    ComputePermits(C);
    SetLength(L, Length(Classes[C].Permits));
    For N := 0 To Length(Classes[C].Permits) - 1 Do L[N] := Classes[C].Permits[N];
  End
  Else If (Classes[C].Flags And ACC_ENUM) <> 0 Then Begin
    N := 0;
    For X := 0 To NClasses - 1 Do
      If Classes[X].IsSrc And ((Classes[X].Flags And MOD_ANON) <> 0) And IsClassT(Classes[X].Super) And
         (Types[Classes[X].Super].Cls = C) Then Begin
        SetLength(L, N + 1); L[N] := X; Inc(N);
      End;
  End;
End;

Procedure EmitPermittedAttr(Var Attr : TBuf; Var NA : LongInt; C : LongInt);
Var L : TTyArr; I : LongInt;
Begin
  PermittedOf(C, L);
  If Length(L) = 0 Then Exit;
  B2(Attr, CPUtf8('PermittedSubclasses')); B4(Attr, 2 + 2 * Length(L)); B2(Attr, Length(L));
  For I := 0 To Length(L) - 1 Do B2(Attr, CPClass(Classes[L[I]].Name));
  Inc(NA);
End;
{ ============================================================================
  4b. DESUCRAGE : preparation des classes (champs synthetiques, descripteurs,
      enum, ponts) puis generation des methodes et des fichiers .class
  ============================================================================ }

Function MethodDescOf(M : LongInt) : String;
Var S : String; I : LongInt;
Begin
  S := '(';
  For I := 0 To Length(Meths[M].PreLoc) - 1 Do S := S + TypeDesc(Erasure(Locals[Meths[M].PreLoc[I]].Typ));
  For I := 0 To Meths[M].NPar - 1 Do S := S + TypeDesc(Erasure(Meths[M].Par[I]));
  For I := 0 To Length(Meths[M].PostLoc) - 1 Do S := S + TypeDesc(Erasure(Locals[Meths[M].PostLoc[I]].Typ));
  MethodDescOf := S + ')' + TypeDesc(Erasure(Meths[M].Ret));
End;

Function MkSynLocal(Const Name : String; T : LongInt) : LongInt;
Var L : LongInt;
Begin
  L := NewLocal(Name, T, ACC_FINAL, 0);
  Locals[L].HasInit := True;
  MkSynLocal := L;
End;

Function HasStaticInit(C : LongInt) : Boolean;
Var M, V, F : LongInt;
Begin
  HasStaticInit := False;
  M := Nodes[Classes[C].Decl].D;
  While M <> 0 Do Begin
    If (Nodes[M].Kind = N_INIT) And ((Nodes[M].Mods And ACC_STATIC) <> 0) Then Begin HasStaticInit := True; Exit; End;
    If Nodes[M].Kind = N_FIELD Then Begin
      V := Nodes[M].B;
      While V <> 0 Do Begin
        F := Nodes[V].Sym;
        If (F >= 0) And (Nodes[V].A <> 0) And ((Fields[F].Flags And ACC_STATIC) <> 0) Then Begin
          EnsureFieldConst(F);
          If Not (((Fields[F].Flags And ACC_FINAL) <> 0) And (Fields[F].CK <> CK_NONE)) Then Begin HasStaticInit := True; Exit; End;
        End;
        V := Nodes[V].Next;
      End;
    End;
    M := Nodes[M].Next;
  End;
End;

{ Prepare une classe source : champs synthetiques, parametres synthetiques de
  constructeurs, methodes d'enum, <clinit> }
Procedure PrepareClass(C : LongInt);
Var I, F, M, T, L : LongInt; EnumT : LongInt;
Begin
  If Classes[C].MemState < 2 Then EnsureMembers(C);
  { instance englobante et variables capturees }
  If Classes[C].IsInner Then Begin
    F := NewField(C, 'this$0', ACC_FINAL Or ACC_SYNTHETIC, ClassT(Classes[C].Outer));
    Classes[C].ThisField := F;
  End;
  SetLength(Classes[C].CapFields, Length(Classes[C].Caps));
  For I := 0 To Length(Classes[C].Caps) - 1 Do Begin
    F := NewField(C, 'val$' + Locals[Classes[C].Caps[I]].Name, ACC_FINAL Or ACC_SYNTHETIC, Locals[Classes[C].Caps[I]].Typ);
    Classes[C].CapFields[I] := F;
  End;
  If Classes[C].HasAssert Then
    NewField(C, '$assertionsDisabled', ACC_STATIC Or ACC_FINAL Or ACC_SYNTHETIC, TY_BOOLEAN);
  If (Classes[C].Flags And ACC_ENUM) <> 0 Then Begin
    { enum (ou sous-classe de constante a corps) }
    If (Classes[C].Flags And MOD_ANON) = 0 Then Begin
      EnumT := ClassT(C);
      NewField(C, '$VALUES', ACC_PRIVATE Or ACC_STATIC Or ACC_FINAL Or ACC_SYNTHETIC, ArrayT(EnumT));
    End;
  End;
  { parametres synthetiques des constructeurs }
  M := Classes[C].FirstMeth;
  While M >= 0 Do Begin
    If (Meths[M].Name = '<init>') And (Meths[M].Synth = 0) Then Begin
      If (Classes[C].Flags And ACC_ENUM) <> 0 Then Begin
        SetLength(Meths[M].PreLoc, 2);
        Meths[M].PreLoc[0] := MkSynLocal('$enum$name', T_STRING);
        Meths[M].PreLoc[1] := MkSynLocal('$enum$ordinal', TY_INT);
      End
      Else If Classes[C].IsInner Then Begin
        SetLength(Meths[M].PreLoc, 1);
        Meths[M].PreLoc[0] := MkSynLocal('this$0', ClassT(Classes[C].Outer));
      End;
      SetLength(Meths[M].PostLoc, Length(Classes[C].Caps));
      For I := 0 To Length(Classes[C].Caps) - 1 Do
        Meths[M].PostLoc[I] := MkSynLocal('val$' + Locals[Classes[C].Caps[I]].Name, Locals[Classes[C].Caps[I]].Typ);
    End;
    M := Meths[M].Next;
  End;
  L := 0; T := 0;
End;

Procedure ComputeDescs(C : LongInt);
Var M : LongInt;
Begin
  M := Classes[C].FirstMeth;
  While M >= 0 Do Begin
    If Meths[M].Desc = '' Then Meths[M].Desc := MethodDescOf(M);
    M := Meths[M].Next;
  End;
End;

{ <clinit> et methodes pont }
Var
  BrVisited : Array[0..255] Of LongInt;
  NBrVisited : LongInt;

Function HasMethodWithDesc(C : LongInt; Const Name, Desc : String) : Boolean;
Var M : LongInt;
Begin
  HasMethodWithDesc := False;
  M := Classes[C].FirstMeth;
  While M >= 0 Do Begin
    If (Meths[M].Name = Name) And (Meths[M].Desc = Desc) Then Begin HasMethodWithDesc := True; Exit; End;
    M := Meths[M].Next;
  End;
End;

Procedure BridgesFrom(C, S : LongInt);
Var I, M2, M : LongInt; Same : Boolean; K : LongInt; Thist : LongInt; Cnt : LongInt;
Begin
  If S < 0 Then Exit;
  For I := 0 To NBrVisited - 1 Do If BrVisited[I] = S Then Exit;
  If NBrVisited < 256 Then Begin BrVisited[NBrVisited] := S; Inc(NBrVisited); End;
  EnsureMembers(S);
  Thist := ThisTypeOf(C);
  M2 := Classes[S].FirstMeth;
  While M2 >= 0 Do Begin
    If (Meths[M2].Name <> '<init>') And (Meths[M2].Name <> '<clinit>') And ((Meths[M2].Flags And (ACC_STATIC Or ACC_PRIVATE)) = 0) Then Begin
      M := Classes[C].FirstMeth;
      Cnt := 0;
      While M >= 0 Do Begin
        If (Meths[M].Name = Meths[M2].Name) And (Meths[M].NPar = Meths[M2].NPar) And (Meths[M].Synth = 0) And
           ((Meths[M].Flags And (ACC_STATIC Or ACC_PRIVATE)) = 0) And (Meths[M].Desc <> Meths[M2].Desc) Then Begin
          Same := True;
          For K := 0 To Meths[M].NPar - 1 Do
            If Erasure(MemberType(Thist, S, Meths[M2].Par[K])) <> Erasure(Meths[M].Par[K]) Then Same := False;
          If Same And Not HasMethodWithDesc(C, Meths[M].Name, Meths[M2].Desc) Then Begin
            K := NewSynMethod(C, Meths[M].Name, (Meths[M].Flags And (ACC_PUBLIC Or ACC_PROTECTED)) Or ACC_BRIDGE Or ACC_SYNTHETIC,
                              1, Meths[M2].Desc, Meths[M2].Ret);
            Meths[K].Bridge := M;
            Meths[K].NPar := Meths[M2].NPar;
            Inc(Cnt);
          End;
        End;
        M := Meths[M].Next;
      End;
    End;
    M2 := Meths[M2].Next;
  End;
  K := SuperClsOf(S);
  BridgesFrom(C, K);
  For I := 0 To Length(Classes[S].Ifaces) - 1 Do BridgesFrom(C, ClsOf(Classes[S].Ifaces[I]));
End;

Procedure MakeBridges(C : LongInt);
Var I, K : LongInt; Last : LongInt;
Begin
  If (Classes[C].Flags And ACC_INTERFACE) <> 0 Then Exit;
  NBrVisited := 0;
  Last := Classes[C].LastMeth;
  BridgesFrom(C, SuperClsOf(C));
  For I := 0 To Length(Classes[C].Ifaces) - 1 Do BridgesFrom(C, ClsOf(Classes[C].Ifaces[I]));
  K := 0;
End;

Procedure PrepareAll;
Var C, I : LongInt; M : LongInt;
Begin
  { 1) champs et parametres synthetiques }
  C := 0;
  While C < NClasses Do Begin
    If Classes[C].IsSrc Then PrepareClass(C);
    Inc(C);
  End;
  { 2) descripteurs }
  C := 0;
  While C < NClasses Do Begin
    If Classes[C].IsSrc Then ComputeDescs(C);
    Inc(C);
  End;
  { 3) <clinit> et ponts }
  C := 0;
  While C < NClasses Do Begin
    If Classes[C].IsSrc Then Begin
      If (((Classes[C].Flags And ACC_ENUM) <> 0) And ((Classes[C].Flags And MOD_ANON) = 0)) Or Classes[C].HasAssert Or HasStaticInit(C) Then Begin
        M := NewSynMethod(C, '<clinit>', ACC_STATIC, 8, '()V', TY_VOID);
      End;
      MakeBridges(C);
    End;
    Inc(C);
  End;
  I := 0;
End;

{ ----- generation d'une methode --------------------------------------------- }

Procedure GenInstanceInit(C : LongInt);
Var M, V, F : LongInt;
Begin
  M := Nodes[Classes[C].Decl].D;
  While M <> 0 Do Begin
    Case Nodes[M].Kind Of
      N_FIELD : If (Nodes[M].Mods And ACC_STATIC) = 0 Then Begin
        V := Nodes[M].B;
        While V <> 0 Do Begin
          F := Nodes[V].Sym;
          If (F >= 0) And (Nodes[V].A <> 0) And ((Fields[F].Flags And ACC_STATIC) = 0) Then Begin
            LineMark(Nodes[V].Line);
            EmitThis;
            If Nodes[Nodes[V].A].Kind = N_ARRAYINIT Then GenArrayInit(Nodes[V].A, Fields[F].Typ)
            Else GenExpr(Nodes[V].A);
            EmitPutField(False, Classes[C].Name, Fields[F].Name, FieldDescOf(F));
          End;
          V := Nodes[V].Next;
        End;
      End;
      N_INIT : If (Nodes[M].Mods And ACC_STATIC) = 0 Then GenStmt(Nodes[M].A);
    End;
    M := Nodes[M].Next;
  End;
End;

Procedure GenStaticInit(C : LongInt);
Var M, V, F, K, Ne, Sub, Ctor, I : LongInt; Cls : LongInt; Cn : String; Top : LongInt;
Begin
  { assertions }
  If Classes[C].HasAssert Then Begin
    Top := Classes[C].TopClass;
    EmitConstClass(Classes[Top].Name);
    EmitInvoke(OP_INVOKEVIRTUAL, 'java/lang/Class', 'desiredAssertionStatus', '()Z', False);
    K := NewLabel; I := NewLabel;
    EmitJump(OP_IFNE, K);
    EmitConstInt(1);
    EmitJump(OP_GOTO, I);
    PlaceLabel(K);
    EmitConstInt(0);
    PlaceLabel(I);
    EmitPutField(True, Classes[C].Name, '$assertionsDisabled', 'Z');
  End;
  { constantes d'enumeration }
  If ((Classes[C].Flags And ACC_ENUM) <> 0) And ((Classes[C].Flags And MOD_ANON) = 0) Then Begin
    Ne := 0;
    M := Nodes[Classes[C].Decl].D;
    While M <> 0 Do Begin
      If Nodes[M].Kind = N_ENUMCONST Then Begin
        LineMark(Nodes[M].Line);
        If Nodes[M].E > 0 Then Begin Cls := Nodes[M].E - 1; Ctor := Classes[Cls].AnonCtor; End
        Else Begin Cls := C; Ctor := Nodes[M].N; End;
        EmitNew(Classes[Cls].Name);
        EmitDupValue;
        EmitConstString(Nodes[M].S);
        EmitConstInt(Ne);
        GenArgs(Nodes[M].A, Nodes[M].N, (Nodes[M].Mods And CALL_VARARGS) <> 0, Nodes[M].Aux);
        EmitInvoke(OP_INVOKESPECIAL, Classes[Cls].Name, '<init>', Meths[Ctor].Desc, False);
        F := Nodes[M].Sym;
        EmitPutField(True, Classes[C].Name, Fields[F].Name, 'L' + Classes[C].Name + ';');
        Inc(Ne);
      End;
      M := Nodes[M].Next;
    End;
    EmitConstInt(Ne);
    EmitNewArray(ClassT(C));
    K := 0;
    M := Nodes[Classes[C].Decl].D;
    While M <> 0 Do Begin
      If Nodes[M].Kind = N_ENUMCONST Then Begin
        EmitDupValue;
        EmitConstInt(K);
        F := Nodes[M].Sym;
        EmitGetField(True, Classes[C].Name, Fields[F].Name, 'L' + Classes[C].Name + ';', ClassT(C));
        EmitArrayStore(ClassT(C));
        Inc(K);
      End;
      M := Nodes[M].Next;
    End;
    EmitPutField(True, Classes[C].Name, '$VALUES', '[L' + Classes[C].Name + ';');
  End;
  { champs statiques et blocs statiques dans l'ordre du source }
  M := Nodes[Classes[C].Decl].D;
  While M <> 0 Do Begin
    Case Nodes[M].Kind Of
      N_FIELD : Begin
        V := Nodes[M].B;
        While V <> 0 Do Begin
          F := Nodes[V].Sym;
          If (F >= 0) And (Nodes[V].A <> 0) And ((Fields[F].Flags And ACC_STATIC) <> 0) Then Begin
            If Not (((Fields[F].Flags And ACC_FINAL) <> 0) And (Fields[F].CK <> CK_NONE)) Then Begin
              LineMark(Nodes[V].Line);
              If Nodes[Nodes[V].A].Kind = N_ARRAYINIT Then GenArrayInit(Nodes[V].A, Fields[F].Typ)
              Else GenExpr(Nodes[V].A);
              EmitPutField(True, Classes[C].Name, Fields[F].Name, FieldDescOf(F));
            End;
          End;
          V := Nodes[V].Next;
        End;
      End;
      N_INIT : If (Nodes[M].Mods And ACC_STATIC) <> 0 Then GenStmt(Nodes[M].A);
    End;
    M := Nodes[M].Next;
  End;
  Sub := 0; Cn := '';
End;

{ ----- methodes synthetiques des records ------------------------------------ }

Function RecordFieldList(C : LongInt; Var Fl : Array Of LongInt) : LongInt;
Var P, N, F : LongInt;
Begin
  N := 0;
  P := Nodes[Classes[C].Decl].E;
  While P <> 0 Do Begin
    F := FindFieldIn(C, Nodes[P].S);
    If (F >= 0) And (N <= High(Fl)) Then Begin Fl[N] := F; Inc(N); End;
    P := Nodes[P].Next;
  End;
  RecordFieldList := N;
End;

Function HashDescFor(T : LongInt; Var Cls : String) : String;
Begin
  Case T Of
    TY_BOOLEAN : Begin Cls := 'java/lang/Boolean'; HashDescFor := '(Z)I'; End;
    TY_BYTE : Begin Cls := 'java/lang/Byte'; HashDescFor := '(B)I'; End;
    TY_CHAR : Begin Cls := 'java/lang/Character'; HashDescFor := '(C)I'; End;
    TY_SHORT : Begin Cls := 'java/lang/Short'; HashDescFor := '(S)I'; End;
    TY_INT : Begin Cls := 'java/lang/Integer'; HashDescFor := '(I)I'; End;
    TY_LONG : Begin Cls := 'java/lang/Long'; HashDescFor := '(J)I'; End;
    TY_FLOAT : Begin Cls := 'java/lang/Float'; HashDescFor := '(F)I'; End;
    TY_DOUBLE : Begin Cls := 'java/lang/Double'; HashDescFor := '(D)I'; End;
  Else
    Cls := 'java/util/Objects'; HashDescFor := '(Ljava/lang/Object;)I';
  End;
End;

Procedure GenRecordMethod(C, M : LongInt);
Var
  Fl : Array[0..63] Of LongInt; N, I, F, T, Lf, Lt, Lx : LongInt; Cls, Dsc : String;
Begin
  N := RecordFieldList(C, Fl);
  Case Meths[M].Synth Of
    4 : Begin
      F := Meths[M].Bridge;
      EmitThis;
      EmitGetField(False, Classes[C].Name, Fields[F].Name, FieldDescOf(F), Fields[F].Typ);
      EmitReturnOp(KindOf(Fields[F].Typ));
    End;
    5 : Begin
      EmitNewStringBuilder;
      EmitConstString(Classes[C].Simple + '[');
      EmitAppend(T_STRING);
      For I := 0 To N - 1 Do Begin
        F := Fl[I];
        If I > 0 Then EmitConstString(', ' + Fields[F].Name + '=') Else EmitConstString(Fields[F].Name + '=');
        EmitAppend(T_STRING);
        EmitThis;
        EmitGetField(False, Classes[C].Name, Fields[F].Name, FieldDescOf(F), Fields[F].Typ);
        EmitAppend(Erasure(Fields[F].Typ));
      End;
      EmitConstString(']');
      EmitAppend(T_STRING);
      EmitInvoke(OP_INVOKEVIRTUAL, 'java/lang/StringBuilder', 'toString', '()Ljava/lang/String;', False);
      EmitReturnOp('A');
    End;
    7 : Begin
      EmitConstInt(0);
      For I := 0 To N - 1 Do Begin
        F := Fl[I];
        EmitConstInt(31);
        EmitArith(OP_IMUL, 'I');
        EmitThis;
        EmitGetField(False, Classes[C].Name, Fields[F].Name, FieldDescOf(F), Fields[F].Typ);
        Dsc := HashDescFor(Erasure(Fields[F].Typ), Cls);
        EmitInvoke(OP_INVOKESTATIC, Cls, 'hashCode', Dsc, False);
        EmitArith(OP_IADD, 'I');
      End;
      EmitReturnOp('I');
    End;
    6 : Begin
      EnsureLocal(4);
      CurL[1] := VTObj('java/lang/Object');
      NextLoc := 2;
      Lf := NewLabel; Lt := NewLabel; Lx := NewLabel;
      EmitThis;
      EmitLoad('A', 1);
      EmitJump(OP_IF_ACMPNE, Lt);
      EmitConstInt(1);
      EmitReturnOp('I');
      PlaceLabel(Lt);
      EmitLoad('A', 1);
      EmitInstanceof(Classes[C].Name);
      EmitJump(OP_IFNE, Lx);
      EmitConstInt(0);
      EmitReturnOp('I');
      PlaceLabel(Lx);
      EmitLoad('A', 1);
      EmitCheckcast(Classes[C].Name);
      EmitStore('A', 2, VTObj(Classes[C].Name));
      NextLoc := 3;
      For I := 0 To N - 1 Do Begin
        F := Fl[I];
        T := Erasure(Fields[F].Typ);
        EmitThis;
        EmitGetField(False, Classes[C].Name, Fields[F].Name, FieldDescOf(F), Fields[F].Typ);
        EmitLoad('A', 2);
        EmitGetField(False, Classes[C].Name, Fields[F].Name, FieldDescOf(F), Fields[F].Typ);
        Case T Of
          TY_BOOLEAN, TY_BYTE, TY_CHAR, TY_SHORT, TY_INT : EmitJump(OP_IF_ICMPNE, Lf);
          TY_LONG : Begin EmitSimple(OP_LCMP, 'JJ', 'I'); EmitJump(OP_IFNE, Lf); End;
          TY_FLOAT : Begin
            EmitInvoke(OP_INVOKESTATIC, 'java/lang/Float', 'compare', '(FF)I', False);
            EmitJump(OP_IFNE, Lf);
          End;
          TY_DOUBLE : Begin
            EmitInvoke(OP_INVOKESTATIC, 'java/lang/Double', 'compare', '(DD)I', False);
            EmitJump(OP_IFNE, Lf);
          End;
        Else
          EmitInvoke(OP_INVOKESTATIC, 'java/util/Objects', 'equals', '(Ljava/lang/Object;Ljava/lang/Object;)Z', False);
          EmitJump(OP_IFEQ, Lf);
        End;
      End;
      EmitConstInt(1);
      EmitReturnOp('I');
      If Labels[Lf].HasState Then Begin
        PlaceLabel(Lf);
        EmitConstInt(0);
        EmitReturnOp('I');
      End;
    End;
  End;
End;

Procedure GenCtorBody(C, M : LongInt);
Var
  D, Body, First, Rest, I, F, K, PrevR : LongInt; IsThis, HasCall : Boolean; Call : LongInt;
Begin
  D := Meths[M].Decl;
  Body := Nodes[D].C;
  First := Nodes[Body].A;
  IsThis := False; HasCall := False; PrevR := 0;
  If First <> 0 Then
    If (Nodes[First].Kind = N_EXPRSTMT) And (Nodes[Nodes[First].A].Kind = N_CALL) And (Nodes[Nodes[First].A].Aux = 1) Then Begin
      HasCall := True;
      Call := Nodes[First].A;
      IsThis := Nodes[Call].S = 'this';
    End;
  If IsThis Then FinActive := False Else FinSetup(C, False);
  { prologue : instance englobante et variables capturees }
  If Not IsThis Then Begin
    If Classes[C].ThisField >= 0 Then Begin
      F := Classes[C].ThisField;
      EmitThis;
      LoadLocal(Meths[M].PreLoc[0], Nodes[D].Line);
      EmitPutField(False, Classes[C].Name, Fields[F].Name, FieldDescOf(F));
    End;
    For I := 0 To Length(Classes[C].Caps) - 1 Do Begin
      F := Classes[C].CapFields[I];
      EmitThis;
      LoadLocal(Meths[M].PostLoc[I], Nodes[D].Line);
      EmitPutField(False, Classes[C].Name, Fields[F].Name, FieldDescOf(F));
    End;
  End;
  { appel de constructeur }
  If HasCall Then Begin
    LineMark(Nodes[First].Line);
    GenExprDiscard(Call);
    Rest := Nodes[First].Next;
  End
  Else Begin
    Rest := First;
    If (Classes[C].Flags And ACC_ENUM) <> 0 Then Begin
      EmitThis;
      LoadLocal(Meths[M].PreLoc[0], Nodes[D].Line);
      LoadLocal(Meths[M].PreLoc[1], Nodes[D].Line);
      EmitInvoke(OP_INVOKESPECIAL, 'java/lang/Enum', '<init>', '(Ljava/lang/String;I)V', False);
    End;
  End;
  If Not IsThis Then GenInstanceInit(C);
  While Rest <> 0 Do Begin
    If Not Alive Then Begin If (PrevR <> 0) And Not CanComplete(PrevR) Then Err(Nodes[Rest].Line, 'instruction inatteignable'); Break; End;
    GenStmt(Rest);
    PrevR := Rest;
    Rest := Nodes[Rest].Next;
  End;
  { record : affectation des composants a la fin du constructeur canonique }
  If Alive And ((Nodes[D].Mods And MOD_RECORD) <> 0) Then Begin
    I := 0;
    F := Nodes[Nodes[D].B].Sym;
    Rest := Nodes[D].B;
    While Rest <> 0 Do Begin
      K := FindFieldIn(C, Nodes[Rest].S);
      EmitThis;
      LoadLocal(Nodes[Rest].Sym, Nodes[D].Line);
      EmitPutField(False, Classes[C].Name, Fields[K].Name, FieldDescOf(K));
      Rest := Nodes[Rest].Next;
    End;
  End;
  K := 0;
End;

Procedure GenBridgeBody(C, M : LongInt);
Var T, I, K : LongInt; D, PD : String; P : Integer; Pos, Slot : LongInt; Ret : String;
  Tp : LongInt;
Begin
  T := Meths[M].Bridge;
  { charge this puis les parametres, avec cast vers les types de la cible }
  EmitThis;
  D := Meths[M].Desc;
  Slot := 1;
  I := 2;
  K := 0;
  While D[I] <> ')' Do Begin
    Pos := I;
    While D[I] = '[' Do Inc(I);
    If D[I] = 'L' Then While D[I] <> ';' Do Inc(I);
    PD := Copy(D, Pos, I - Pos + 1);
    Inc(I);
    EnsureLocal(Slot + 3);
    CurL[Slot] := VTOfDesc(PD);
    If VTCat2(CurL[Slot]) Then CurL[Slot + 1] := VTSimple(VT_SECOND);
    Case PD[1] Of
      'J' : Begin EmitLoad('J', Slot); Inc(Slot, 2); End;
      'D' : Begin EmitLoad('D', Slot); Inc(Slot, 2); End;
      'F' : Begin EmitLoad('F', Slot); Inc(Slot); End;
      'I', 'Z', 'B', 'C', 'S' : Begin EmitLoad('I', Slot); Inc(Slot); End;
    Else
      Begin
        EmitLoad('A', Slot); Inc(Slot);
        Tp := Erasure(Meths[T].Par[K]);
        If (Tp <> T_OBJECT) And Not VTAssignable(TopVT, Tp) Then EmitCheckcast(TypeClassName(Tp));
      End;
    End;
    Inc(K);
  End;
  Ret := DescRetType(Meths[T].Desc);
  EmitInvoke(OP_INVOKEVIRTUAL, Classes[C].Name, Meths[T].Name, Meths[T].Desc, False);
  If Ret = 'V' Then EmitReturnOp('V')
  Else Begin
    Case Ret[1] Of
      'J' : EmitReturnOp('J');
      'D' : EmitReturnOp('D');
      'F' : EmitReturnOp('F');
      'I', 'Z', 'B', 'C', 'S' : EmitReturnOp('I');
    Else
      EmitReturnOp('A');
    End;
  End;
  P := 0;
End;

Procedure GenMethodBodyOnce(C, M : LongInt);
Var
  D, Body, P, L, I, Slot : LongInt; IsCtor, Static : Boolean; Dsc : String;
Begin
  Static := (Meths[M].Flags And ACC_STATIC) <> 0;
  BeginMethod;
  FinActive := False;
  NGCtx := 0;
  PendingLabelCtx := -1;
  GenCls := C; GenMeth := M; GenStatic := Static;
  GenRet := Meths[M].Ret;
  ThisClsName := Classes[C].Name;
  IsCtor := Meths[M].Name = '<init>';
  If Not Static Then Begin
    EnsureLocal(2);
    If IsCtor Then CurL[0] := VTSimple(VT_UNINITTHIS) Else CurL[0] := VTObj(ThisClsName);
    NextLoc := 1;
    MaxLoc := 1;
  End;
  D := Meths[M].Decl;
  { parametres }
  For I := 0 To Length(Meths[M].PreLoc) - 1 Do Begin
    L := Meths[M].PreLoc[I];
    Slot := DeclSlot(L);
    CurL[Slot] := VTOfType(Locals[L].Typ);
    If VTCat2(CurL[Slot]) Then CurL[Slot + 1] := VTSimple(VT_SECOND);
  End;
  If D <> 0 Then Begin
    P := Nodes[D].B;
    While P <> 0 Do Begin
      L := Nodes[P].Sym;
      Slot := DeclSlot(L);
      CurL[Slot] := VTOfType(Locals[L].Typ);
      If VTCat2(CurL[Slot]) Then CurL[Slot + 1] := VTSimple(VT_SECOND);
      P := Nodes[P].Next;
    End;
  End
  Else If Meths[M].Synth = 3 Then Begin
    { methode synthetique sans declaration : parametres selon le descripteur }
    Slot := NextLoc;
    For I := 0 To Meths[M].NPar - 1 Do Begin
      Slot := AllocSlot(Meths[M].Par[I]);
      CurL[Slot] := VTOfType(Meths[M].Par[I]);
      If VTCat2(CurL[Slot]) Then CurL[Slot + 1] := VTSimple(VT_SECOND);
    End;
  End;
  For I := 0 To Length(Meths[M].PostLoc) - 1 Do Begin
    L := Meths[M].PostLoc[I];
    Slot := DeclSlot(L);
    CurL[Slot] := VTOfType(Locals[L].Typ);
    If VTCat2(CurL[Slot]) Then CurL[Slot + 1] := VTSimple(VT_SECOND);
  End;
  If Meths[M].Synth = 1 Then Begin
    { pont : parametres selon le descripteur du pont }
    GenBridgeBody(C, M);
  End
  Else If Meths[M].Synth = 2 Then Begin
    EmitGetField(True, Classes[C].Name, '$VALUES', '[L' + Classes[C].Name + ';', ArrayT(ClassT(C)));
    EmitInvoke(OP_INVOKEVIRTUAL, '[L' + Classes[C].Name + ';', 'clone', '()Ljava/lang/Object;', False);
    EmitCheckcast('[L' + Classes[C].Name + ';');
    EmitReturnOp('A');
  End
  Else If Meths[M].Synth = 3 Then Begin
    EmitConstClass(Classes[C].Name);
    EmitLoad('A', 0);
    EmitInvoke(OP_INVOKESTATIC, 'java/lang/Enum', 'valueOf', '(Ljava/lang/Class;Ljava/lang/String;)Ljava/lang/Enum;', False);
    EmitCheckcast(Classes[C].Name);
    EmitReturnOp('A');
  End
  Else If Meths[M].Synth In [4, 5, 6, 7] Then Begin
    GenRecordMethod(C, M);
  End
  Else If Meths[M].Synth = 8 Then Begin
    FinSetup(C, True);
    GenStaticInit(C);
    If Alive Then EmitReturnOp('V');
  End
  Else Begin
    Body := Nodes[D].C;
    If IsCtor Then GenCtorBody(C, M)
    Else GenStmt(Body);
    If Alive Then Begin
      If Meths[M].Ret = TY_VOID Then EmitReturnOp('V')
      Else Err(Nodes[D].Line, 'instruction return manquante');
    End;
  End;
  Dsc := '';
End;

{ Genere le corps ; si un saut court deborde (methode de plus de 32 Ko), regenere en mode "sauts longs" }
Procedure GenMethodBody(C, M : LongInt);
Var Errs : LongInt;
Begin
  FatCode := False;
  JumpOverflow := False;
  Errs := ErrCount;
  GenMethodBodyOnce(C, M);
  ResolveFixups;
  If JumpOverflow And (ErrCount = Errs) Then Begin
    FatCode := True;
    JumpOverflow := False;
    GenMethodBodyOnce(C, M);
    FatCode := False;
  End;
End;

{ ----- ecriture d'une classe ------------------------------------------------- }

Var
  FieldBuf, MethBuf : TBuf;
  NFieldOut, NMethOut : LongInt;

Procedure WriteCodeAttr(Var Out : TBuf);
Var Body, Attrs, Sm : TBuf; I, NA : LongInt;
Begin
  ResolveFixups;
  If Code.N > 65535 Then Err(LastLine, 'code trop long dans la methode (limite de 64 Ko)');
  If MaxLoc < NextLoc Then MaxLoc := NextLoc;
  BInit(Body); BInit(Attrs); BInit(Sm);
  B2(Body, MaxSt);
  B2(Body, MaxLoc + 1);
  B4(Body, Code.N);
  BAppend(Body, Code);
  B2(Body, NEx);
  For I := 0 To NEx - 1 Do Begin
    B2(Body, ExStart[I]);
    B2(Body, ExEnd[I]);
    B2(Body, ExHandler[I]);
    B2(Body, ExType[I]);
  End;
  NA := 0;
  If NLn > 0 Then Begin
    B2(Attrs, CPUtf8('LineNumberTable'));
    B4(Attrs, 2 + NLn * 4);
    B2(Attrs, NLn);
    For I := 0 To NLn - 1 Do Begin B2(Attrs, LnPC[I]); B2(Attrs, LnLine[I]); End;
    Inc(NA);
  End;
  WriteStackMap(Sm);
  If Sm.N > 0 Then Begin BAppend(Attrs, Sm); Inc(NA); End;
  B2(Body, NA);
  BAppend(Body, Attrs);
  B2(Out, CPUtf8('Code'));
  B4(Out, Body.N);
  BAppend(Out, Body);
End;

Function ClassFileFlags(C : LongInt) : LongInt;
Var F, R : LongInt;
Begin
  F := Classes[C].Flags;
  R := 0;
  If (F And (ACC_PUBLIC Or ACC_PROTECTED)) <> 0 Then R := R Or ACC_PUBLIC;
  If (F And ACC_FINAL) <> 0 Then R := R Or ACC_FINAL;
  If (F And ACC_INTERFACE) <> 0 Then R := R Or ACC_INTERFACE Or ACC_ABSTRACT
  Else R := R Or ACC_SUPER;
  If (F And ACC_ABSTRACT) <> 0 Then R := R Or ACC_ABSTRACT;
  If (F And ACC_ENUM) <> 0 Then R := R Or ACC_ENUM;
  If (F And ACC_ANNOTATION) <> 0 Then R := R Or ACC_ANNOTATION;
  ClassFileFlags := R;
End;

Procedure GenFieldInfo(C, F : LongInt);
Var Fl, Idx : LongInt; Attr : TBuf; NA : LongInt; Bits : TDblBits;
Begin
  Fl := Fields[F].Flags And $FFFF;
  { avant la version 11 il n'y a pas de nids : les membres prives deviennent visibles du paquetage }
  If OptTarget < 55 Then Fl := Fl And Not ACC_PRIVATE;
  B2(FieldBuf, Fl);
  B2(FieldBuf, CPUtf8(Fields[F].Name));
  B2(FieldBuf, CPUtf8(FieldDescOf(F)));
  BInit(Attr);
  NA := 0;
  { ConstantValue pour les constantes statiques finales }
  If ((Fields[F].Flags And (ACC_STATIC Or ACC_FINAL)) = (ACC_STATIC Or ACC_FINAL)) And (Fields[F].CK <> CK_NONE) Then Begin
    Case Fields[F].CK Of
      CK_INT : Idx := CPInt(Fields[F].CI);
      CK_LONG : Idx := CPLong(Fields[F].CI);
      CK_FLOAT : Begin Bits.I := 0; Bits.S := Fields[F].CD; Idx := CPFloat(Bits.L); End;
      CK_DOUBLE : Begin Bits.D := Fields[F].CD; Idx := CPDouble(Bits.I); End;
    Else
      Idx := CPString(Fields[F].CS);
    End;
    NA := 1;
    B2(Attr, CPUtf8('ConstantValue'));
    B4(Attr, 2);
    B2(Attr, Idx);
  End;
  EmitSignatureAttr(Attr, NA, FieldSignature(F));
  If Fields[F].Decl > 0 Then Begin
    EmitAnnotAttrs(Attr, NA, Nodes[Fields[F].Decl].Ann, TGT_FIELD);
    TypeAnnotsReset;
    TypeAnnotsAdd(Nodes[Fields[F].Decl].Ann, $13, 0, Fields[F].Typ);
    TypeAnnotsFlush(Attr, NA);
  End;
  B2(FieldBuf, NA);
  BAppend(FieldBuf, Attr);
  Inc(NFieldOut);
End;

Procedure GenMethodInfo(C, M : LongInt);
Var Fl : LongInt; HasCode : Boolean; Extra : TBuf; NX, D, Fd, Pr, Ix : LongInt;
Begin
  Fl := Meths[M].Flags And $FFFF;
  If (OptTarget < 55) And (Meths[M].Lambda < 0) And ((Classes[C].Flags And ACC_INTERFACE) = 0) Then Fl := Fl And Not ACC_PRIVATE;
  If Meths[M].Synth = 0 Then Fl := Fl And Not (ACC_BRIDGE);
  If (Meths[M].Flags And ACC_VARARGS) <> 0 Then Fl := Fl Or ACC_VARARGS;
  { les methodes "default" ne sont pas abstraites }
  HasCode := (Meths[M].Flags And (ACC_ABSTRACT Or ACC_NATIVE)) = 0;
  If (Meths[M].Synth = 0) And (Meths[M].Decl = 0) Then HasCode := False;
  If HasCode Then GenMethodBody(C, M);
  { attributs hors Code : annotations }
  BInit(Extra);
  NX := 0;
  D := Meths[M].Decl;
  If (Meths[M].Synth = 0) And (Meths[M].Lambda < 0) Then Begin
    EmitExceptionsAttr(Extra, NX, M);
    EmitSignatureAttr(Extra, NX, MethodSignature(M));
  End
  Else If (Meths[M].Synth = 4) And (Meths[M].Bridge >= 0) Then Begin
    Fd := Fields[Meths[M].Bridge].Decl;
    If (Fd > 0) And NodeGeneric(Nodes[Fd].A) Then EmitSignatureAttr(Extra, NX, '()' + SigOfNode(Nodes[Fd].A));
  End;
  If (D > 0) And (Meths[M].Synth = 0) And (Meths[M].Lambda < 0) Then Begin
    If Nodes[D].Aux = 1 Then EmitAnnotAttrs(Extra, NX, Nodes[D].Ann, TGT_CONSTRUCTOR)
    Else EmitAnnotAttrs(Extra, NX, Nodes[D].Ann, TGT_METHOD);
    EmitParamAnnotAttrs(Extra, NX, Nodes[D].B);
    EmitAnnotDefault(Extra, NX, D, Meths[M].Ret);
    TypeAnnotsReset;
    If (Nodes[D].Aux = 1) Or (Meths[M].Ret <> TY_VOID) Then
      TypeAnnotsAdd(Nodes[D].Ann, $14, 0, Meths[M].Ret);
    Pr := Nodes[D].B;
    Ix := 0;
    While Pr <> 0 Do Begin
      If Ix < Meths[M].NPar Then TypeAnnotsAdd(Nodes[Pr].Ann, $16, Ix, Meths[M].Par[Ix]);
      Inc(Ix);
      Pr := Nodes[Pr].Next;
    End;
    TypeAnnotsFlush(Extra, NX);
  End
  Else If (Meths[M].Synth = 4) And (Meths[M].Bridge >= 0) Then Begin
    Fd := Fields[Meths[M].Bridge].Decl;
    If Fd > 0 Then EmitAnnotAttrs(Extra, NX, Nodes[Fd].Ann, TGT_METHOD);
  End;
  B2(MethBuf, Fl);
  B2(MethBuf, CPUtf8(Meths[M].Name));
  B2(MethBuf, CPUtf8(Meths[M].Desc));
  If HasCode Then Begin
    B2(MethBuf, 1 + NX);
    WriteCodeAttr(MethBuf);
  End
  Else B2(MethBuf, NX);
  BAppend(MethBuf, Extra);
  Inc(NMethOut);
End;

Function SourceFileName(C : LongInt) : String;
Var S : String; K : LongInt;
Begin
  S := CUs[Classes[C].CU].FileName;
  K := LastPos('/', S);
  If K = 0 Then K := LastPos('\', S);
  SourceFileName := Copy(S, K + 1, Length(S));
End;

Function InnerFlags(X : LongInt) : LongInt;
Var F, R : LongInt;
Begin
  F := Classes[X].Flags;
  R := F And (ACC_PUBLIC Or ACC_PRIVATE Or ACC_PROTECTED Or ACC_STATIC Or ACC_FINAL Or ACC_INTERFACE Or
              ACC_ABSTRACT Or ACC_SYNTHETIC Or ACC_ANNOTATION Or ACC_ENUM);
  If (F And ACC_INTERFACE) <> 0 Then R := R Or ACC_ABSTRACT;
  If (F And MOD_ANON) <> 0 Then R := R And Not ACC_STATIC;
  InnerFlags := R;
End;

Procedure WriteClassFile(C : LongInt);
Var
  Out, Attr, Ifs, InnerBuf, NestBuf : TBuf; M, F, I, X, NA, NInner, NNest, SuperIdx : LongInt; Path, Dir, Nm : String;
  Version : LongInt; PermL : TTyArr;
Begin
  PoolInit;
  BInit(FieldBuf); BInit(MethBuf); BInit(BsmBuf); BsmCount := 0;
  NFieldOut := 0; NMethOut := 0; LambdaCount := 0;
  CurFile := CUs[Classes[C].CU].FileName;
  ThisClsName := Classes[C].Name;
  GenCls := C;
  { champs }
  F := Classes[C].FirstField;
  While F >= 0 Do Begin
    GenFieldInfo(C, F);
    F := Fields[F].Next;
  End;
  { methodes (la liste peut s'allonger : lambdas) }
  M := Classes[C].FirstMeth;
  While M >= 0 Do Begin
    GenMethodInfo(C, M);
    M := Meths[M].Next;
  End;
  { en-tete }
  BInit(Out);
  B4(Out, $CAFEBABE);
  B2(Out, 0);
  { Record : version 60 ; PermittedSubclasses : version 61 }
  PermittedOf(C, PermL);
  If (Length(PermL) > 0) And (OptTarget < 61) Then B2(Out, 61)
  Else If Classes[C].IsSrc And (Classes[C].Decl > 0) And (Nodes[Classes[C].Decl].Aux = CLS_RECORD) And (OptTarget < 60) Then
    B2(Out, 60)
  Else B2(Out, OptTarget);
  { attributs de classe }
  BInit(Attr);
  NA := 0;
  B2(Attr, CPUtf8('SourceFile')); B4(Attr, 2); B2(Attr, CPUtf8(SourceFileName(C))); Inc(NA);
  { signature generique, annotations de la classe et attribut Record }
  If Classes[C].IsSrc Then EmitSignatureAttr(Attr, NA, ClassSignature(C));
  If Classes[C].IsSrc And (Classes[C].Decl > 0) Then Begin
    If Nodes[Classes[C].Decl].Aux = CLS_ANNOTATION Then EmitAnnotAttrs(Attr, NA, Nodes[Classes[C].Decl].Ann, TGT_TYPE Or TGT_ANNOT)
    Else EmitAnnotAttrs(Attr, NA, Nodes[Classes[C].Decl].Ann, TGT_TYPE);
    If Nodes[Classes[C].Decl].Aux = CLS_RECORD Then EmitRecordAttr(Attr, NA, C);
    EmitPermittedAttr(Attr, NA, C);
  End;
  { classes imbriquees }
  BInit(InnerBuf);
  NInner := 0;
  For X := 0 To NClasses - 1 Do
    If Classes[X].IsSrc And ((X = C) Or (Classes[X].Outer = C)) And (Classes[X].Outer >= 0) Then Begin
      B2(InnerBuf, CPClass(Classes[X].Name));
      If (Classes[X].Flags And MOD_LOCAL) <> 0 Then B2(InnerBuf, 0) Else B2(InnerBuf, CPClass(Classes[Classes[X].Outer].Name));
      If (Classes[X].Flags And MOD_ANON) <> 0 Then B2(InnerBuf, 0) Else B2(InnerBuf, CPUtf8(Classes[X].Simple));
      B2(InnerBuf, InnerFlags(X));
      Inc(NInner);
    End;
  If NInner > 0 Then Begin
    B2(Attr, CPUtf8('InnerClasses'));
    B4(Attr, 2 + InnerBuf.N);
    B2(Attr, NInner);
    BAppend(Attr, InnerBuf);
    Inc(NA);
  End;
  { classe locale : EnclosingMethod }
  If (Classes[C].Outer >= 0) And ((Classes[C].Flags And MOD_LOCAL) <> 0) Then Begin
    B2(Attr, CPUtf8('EnclosingMethod')); B4(Attr, 4);
    B2(Attr, CPClass(Classes[Classes[C].Outer].Name)); B2(Attr, 0);
    Inc(NA);
  End;
  { nids (version 11 et suivantes) }
  If OptTarget < 55 Then Begin
  End
  Else If Classes[C].Outer >= 0 Then Begin
    B2(Attr, CPUtf8('NestHost')); B4(Attr, 2); B2(Attr, CPClass(Classes[Classes[C].TopClass].Name)); Inc(NA);
  End
  Else Begin
    BInit(NestBuf);
    NNest := 0;
    For X := 0 To NClasses - 1 Do
      If Classes[X].IsSrc And (X <> C) And (Classes[X].TopClass = C) Then Begin
        B2(NestBuf, CPClass(Classes[X].Name));
        Inc(NNest);
      End;
    If NNest > 0 Then Begin
      B2(Attr, CPUtf8('NestMembers')); B4(Attr, 2 + NestBuf.N); B2(Attr, NNest);
      BAppend(Attr, NestBuf);
      Inc(NA);
    End;
  End;
  If BsmCount > 0 Then Begin
    B2(Attr, CPUtf8('BootstrapMethods'));
    B4(Attr, 2 + BsmBuf.N);
    B2(Attr, BsmCount);
    BAppend(Attr, BsmBuf);
    Inc(NA);
  End;
  { classe, super-classe, interfaces }
  X := CPClass(Classes[C].Name);
  If Classes[C].Super = 0 Then SuperIdx := 0
  Else SuperIdx := CPClass(Classes[ClsOf(Classes[C].Super)].Name);
  BInit(Ifs);
  For I := 0 To Length(Classes[C].Ifaces) - 1 Do B2(Ifs, CPClass(Classes[ClsOf(Classes[C].Ifaces[I])].Name));
  { assemblage : la table de constantes est complete }
  B2(Out, PoolN);
  BAppend(Out, Pool);
  B2(Out, ClassFileFlags(C));
  B2(Out, X);
  B2(Out, SuperIdx);
  B2(Out, Length(Classes[C].Ifaces));
  BAppend(Out, Ifs);
  B2(Out, NFieldOut);
  BAppend(Out, FieldBuf);
  B2(Out, NMethOut);
  BAppend(Out, MethBuf);
  B2(Out, NA);
  BAppend(Out, Attr);
  { fichier de sortie }
  Nm := Classes[C].Name;
  If OptOutDir <> '' Then Begin
    Path := OptOutDir;
    If (Path[Length(Path)] <> '/') And (Path[Length(Path)] <> '\') Then Path := Path + '/';
    Path := Path + Nm + '.class';
    MakeDirs(Path);
  End
  Else Begin
    Dir := CUs[Classes[C].CU].FileName;
    I := LastPos('/', Dir);
    If I = 0 Then I := LastPos('\', Dir);
    Dir := Copy(Dir, 1, I);
    Path := Dir + Copy(Nm, LastPos('/', Nm) + 1, Length(Nm)) + '.class';
  End;
  If Not WriteBuf(Path, Out) Then Err(0, 'impossible d''ecrire le fichier ' + Path)
  Else If OptVerbose Then WriteLn('[ecrit ', Path, ']');
  Version := 0; M := 0;
End;

{ ----- module-info.class ------------------------------------------------------------------- }

Function DotsToSlashes(Const S : String) : String;
Var I : LongInt; R : String;
Begin
  R := S;
  For I := 1 To Length(R) Do If R[I] = '.' Then R[I] := '/';
  DotsToSlashes := R;
End;

Function ModVerIdx(Const Nm : String) : LongInt;
Var V : String;
Begin
  V := JdkModuleVersion(Nm);
  If V = '' Then ModVerIdx := 0 Else ModVerIdx := CPUtf8(V);
End;

Procedure WriteModuleInfo;
Var
  Out, Attr, Mod_, Tmp : TBuf; NA, D, K, N, NReq, NExp, NOpen, NUses, NProv, I : LongInt; Path, Dir, Fn : String;
  HasBase : Boolean; ReqB, ExpB, OpenB, UsesB, ProvB : TBuf; X : LongInt;
Begin
  If ModDecl = 0 Then Exit;
  PoolInit;
  CurFile := CUs[ModCU].FileName;
  BInit(Attr); BInit(Mod_); BInit(ReqB); BInit(ExpB); BInit(OpenB); BInit(UsesB); BInit(ProvB);
  NA := 0; NReq := 0; NExp := 0; NOpen := 0; NUses := 0; NProv := 0;
  HasBase := False;
  D := Nodes[ModDecl].A;
  While D <> 0 Do Begin
    If (Nodes[D].S = 'requires') And (Nodes[D].CS = 'java.base') Then HasBase := True;
    D := Nodes[D].Next;
  End;
  { java.base est toujours requis (obligatoire, implicite) }
  If (Not HasBase) And (Nodes[ModDecl].S <> 'java.base') Then Begin
    B2(ReqB, CPModule('java.base')); B2(ReqB, $8000); B2(ReqB, ModVerIdx('java.base')); Inc(NReq);
  End;
  D := Nodes[ModDecl].A;
  While D <> 0 Do Begin
    If Nodes[D].S = 'requires' Then Begin
      B2(ReqB, CPModule(Nodes[D].CS)); B2(ReqB, Nodes[D].Mods); B2(ReqB, ModVerIdx(Nodes[D].CS)); Inc(NReq);
    End
    Else If (Nodes[D].S = 'exports') Or (Nodes[D].S = 'opens') Then Begin
      If Nodes[D].S = 'exports' Then Begin
        B2(ExpB, CPPackage(DotsToSlashes(Nodes[D].CS))); B2(ExpB, 0); B2(ExpB, ChainLen(Nodes[D].B));
        K := Nodes[D].B;
        While K <> 0 Do Begin B2(ExpB, CPModule(Nodes[K].S)); K := Nodes[K].Next; End;
        Inc(NExp);
      End
      Else Begin
        B2(OpenB, CPPackage(DotsToSlashes(Nodes[D].CS))); B2(OpenB, 0); B2(OpenB, ChainLen(Nodes[D].B));
        K := Nodes[D].B;
        While K <> 0 Do Begin B2(OpenB, CPModule(Nodes[K].S)); K := Nodes[K].Next; End;
        Inc(NOpen);
      End;
    End
    Else If Nodes[D].S = 'uses' Then Begin
      If Nodes[D].Sym > 0 Then Begin B2(UsesB, CPClass(Classes[Nodes[D].Sym].Name)); Inc(NUses); End;
    End
    Else If Nodes[D].S = 'provides' Then Begin
      If Nodes[D].Sym > 0 Then Begin
        B2(ProvB, CPClass(Classes[Nodes[D].Sym].Name)); B2(ProvB, ChainLen(Nodes[D].B));
        K := Nodes[D].B;
        While K <> 0 Do Begin
          If Nodes[K].Sym > 0 Then B2(ProvB, CPClass(Classes[Nodes[K].Sym].Name)) Else B2(ProvB, 0);
          K := Nodes[K].Next;
        End;
        Inc(NProv);
      End;
    End;
    D := Nodes[D].Next;
  End;
  { attribut Module }
  B2(Mod_, CPModule(Nodes[ModDecl].S));
  If Nodes[ModDecl].Mods = 1 Then B2(Mod_, $20) Else B2(Mod_, 0);
  B2(Mod_, 0);
  B2(Mod_, NReq);  BAppend(Mod_, ReqB);
  B2(Mod_, NExp);  BAppend(Mod_, ExpB);
  B2(Mod_, NOpen); BAppend(Mod_, OpenB);
  B2(Mod_, NUses); BAppend(Mod_, UsesB);
  B2(Mod_, NProv); BAppend(Mod_, ProvB);
  B2(Attr, CPUtf8('SourceFile')); B4(Attr, 2); B2(Attr, CPUtf8('module-info.java')); Inc(NA);
  B2(Attr, CPUtf8('Module')); B4(Attr, Mod_.N); BAppend(Attr, Mod_); Inc(NA);
  NoDeprecatedAttr := True;
  EmitAnnotAttrs(Attr, NA, Nodes[ModDecl].Ann, TGT_MODULE);
  NoDeprecatedAttr := False;
  X := CPClass('module-info');
  BInit(Out);
  B4(Out, $CAFEBABE);
  B2(Out, 0);
  B2(Out, OptTarget);
  B2(Out, PoolN);
  BAppend(Out, Pool);
  B2(Out, $8000);
  B2(Out, X);
  B2(Out, 0);
  B2(Out, 0);
  B2(Out, 0);
  B2(Out, 0);
  B2(Out, NA);
  BAppend(Out, Attr);
  If OptOutDir <> '' Then Begin
    Path := OptOutDir;
    If (Path[Length(Path)] <> '/') And (Path[Length(Path)] <> '\') Then Path := Path + '/';
    Path := Path + 'module-info.class';
    MakeDirs(Path);
  End
  Else Begin
    Dir := CUs[ModCU].FileName;
    I := LastPos('/', Dir);
    If I = 0 Then I := LastPos('\', Dir);
    Path := Copy(Dir, 1, I) + 'module-info.class';
  End;
  If Not WriteBuf(Path, Out) Then Err(0, 'impossible d''ecrire le fichier ' + Path)
  Else If OptVerbose Then WriteLn('[ecrit ', Path, ']');
  N := 0; Fn := ''; Tmp.N := 0;
End;
{ ============================================================================
  PROGRAMME PRINCIPAL
  ============================================================================ }

Type
  TOutFile = Record
    Path : String;
    Data : TBuf;
  End;

Procedure Usage;
Begin
  WriteLn(VERSION);
  WriteLn('Usage : JAVAC [options] fichier.java [fichier2.java ...]');
  WriteLn;
  WriteLn('Options :');
  WriteLn('  -d repertoire      repertoire de sortie des fichiers .class');
  WriteLn('  -cp chemin         classpath (repertoires et archives .jar)');
  WriteLn('  -p, --module-path chemin   modules (ajoutes au classpath)');
  WriteLn('  -target N          version de classe visee (8 a 25, defaut 11)');
  WriteLn('  --release N        synonyme de -target');
  WriteLn('  -verbose           affiche les fichiers ecrits');
  WriteLn('  -g, -nowarn, -Xlint  (acceptes et ignores)');
  WriteLn('  -help              affiche cette aide');
End;

Var
  Files    : Array Of String;
  NFiles   : LongInt;
  I, K, V  : LongInt;
  Arg      : String;
  CpArg    : String;

Begin
  { exceptions flottantes masquees : le repli de constantes suit IEEE 754 comme Java }
  {$IFDEF CPUX86_64}SetMXCSR($1F80);{$ENDIF}
  {$IFDEF CPUI386}Set8087CW($133F);{$ENDIF}
  ErrCount := 0; WarnCount := 0;
  OptVerbose := False; OptOutDir := ''; OptTarget := 55;
  NNodes := 1;
  CurFile := 'javac';
  If ParamCount = 0 Then Begin Usage; Halt(2); End;
  NFiles := 0;
  I := 1;
  While I <= ParamCount Do Begin
    Arg := ParamStr(I);
    If (Arg = '-d') And (I < ParamCount) Then Begin
      Inc(I); OptOutDir := ParamStr(I);
    End
    Else If ((Arg = '-target') Or (Arg = '--release') Or (Arg = '-source')) And (I < ParamCount) Then Begin
      Inc(I);
      V := ToInt(ParamStr(I));
      If (Arg <> '-source') Then Begin
        If V = 1 Then V := ToInt(Copy(ParamStr(I), 3, 3));     { 1.8 -> 8 }
        If (V >= 8) And (V <= 25) Then OptTarget := 44 + V
        Else Begin
          WriteLn('javac: la version cible ', ParamStr(I), ' n''est pas prise en charge (8 a 25)');
          Halt(2);
        End;
      End;
    End
    Else If ((Arg = '-cp') Or (Arg = '-classpath') Or (Arg = '--class-path')) And (I < ParamCount) Then Begin
      Inc(I); CpArg := ParamStr(I);
    End
    Else If ((Arg = '-p') Or (Arg = '--module-path')) And (I < ParamCount) Then Begin
      Inc(I); OptModulePath := True;
      If CpArg = '' Then CpArg := ParamStr(I) Else CpArg := CpArg + ':' + ParamStr(I);
    End
    Else If Arg = '-verbose' Then OptVerbose := True
    Else If Arg = '-Xparse' Then OptParseOnly := True
    Else If (Arg = '-help') Or (Arg = '--help') Or (Arg = '-h') Or (Arg = '/?') Then Begin Usage; Halt(0); End
    Else If (Arg = '-version') Or (Arg = '--version') Then Begin WriteLn(VERSION); Halt(0); End
    Else If (Arg <> '') And (Arg[1] = '-') Then Begin
      { options ignorees }
    End
    Else Begin
      SetLength(Files, NFiles + 1);
      Files[NFiles] := Arg;
      Inc(NFiles);
    End;
    Inc(I);
  End;
  If NFiles = 0 Then Begin WriteLn('javac: aucun fichier source'); Halt(2); End;
  InitTypes;
  If CpArg = '' Then CpArg := GetEnv('CLASSPATH');
  If CpArg <> '' Then SetClassPath(CpArg);
  CurCtx := -1; CurCU := -1; CurClass := -1; CurMeth := -1; ClsParentCtx := -1; CurLambda := -1;
  AnonSuperCtor := -1; PendingLabelCtx := -1;
  MapInit(VTMap, 1021);
  For I := 0 To NFiles - 1 Do Begin
    MapPut(ClassMap, '@src:' + Files[I], 0);
  End;
  For I := 0 To NFiles - 1 Do LoadSourceFile(Files[I]);
  If (ErrCount = 0) And Not OptParseOnly Then AttribAll;
  If OptParseOnly Then Begin
    If ErrCount > 0 Then Halt(1);
    Halt(0);
  End;
  If ErrCount = 0 Then Begin
    PrepareAll;
    K := 0;
    For I := 0 To NClasses - 1 Do
      If Classes[I].IsSrc And (Classes[I].CU >= 0) Then WriteClassFile(I);
    WriteModuleInfo;
  End;
  If ErrCount > 0 Then Begin
    ErrSummary;
    Halt(1);
  End;
  If WarnCount > 0 Then WriteLn(WarnCount, ' avertissement(s)');
End.
