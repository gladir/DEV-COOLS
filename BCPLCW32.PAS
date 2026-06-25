{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur BCPL vers assembleur 80386, 32 bits, pour Windows 32 bits.
}

{TODO BCPLCW32.PAS:
1. Définir précisément le pipeline du compilateur : source .b -> tokens -> AST/intermédiaire -> ASM 80386 -> OBJ -> EXE Win32.
2. Ajouter la gestion des paramètres de ligne de commande : fichier source, nom de sortie, mode par défaut .EXE, option .OBJ seule, option explicite pour conserver/générer le .ASM.
3. Définir les conventions de fichiers : extension .b en entrée, .asm optionnel, .obj intermédiaire ou final, .exe par défaut.
4. Implémenter le scanner lexical BCPL : identifiants, nombres entiers, chaînes, commentaires //, opérateurs, ponctuation, mots-clés.
5. Supporter les chaînes BCPL avec séquences spéciales utilisées par les exemples : *N, *T, *", **.
6. Créer une table des mots-clés BCPL : LET, BE, VALOF, RESULTIS, STATIC, IF, UNLESS, TEST, THEN, ELSE, FOR, TO, BY, WHILE, UNTIL, REPEAT, REPEATWHILE, BREAK, SWITCHON, INTO, CASE, DEFAULT, ENDCASE, FINISH.
7. Implémenter un parseur récursif descendant pour les blocs BCPL $( ... $).
8. Parser les déclarations globales LET name(...) BE ... pour les procédures.
9. Parser les déclarations globales LET name(...) = expression pour les fonctions retournant une valeur.
10. Parser les déclarations locales LET variable = expression.
11. Parser les blocs STATIC $( name = value ... $) et générer des symboles globaux initialisés.
12. Construire une table des symboles séparant fonctions, procédures, variables locales, paramètres et statiques.
13. Définir une convention d’appel 32 bits interne : passage des paramètres, valeur de retour dans EAX, sauvegarde/restauration des registres nécessaires.
14. Corriger dès le départ le support multi-paramètres, car les exemples actuels contournent déjà un problème ABI avec les seconds paramètres.
15. Générer les prologues/épilogues de fonctions Win32 32 bits : pile, frame pointer, variables locales, retour propre.
16. Implémenter l’évaluation des expressions entières : +, -, *, division si prévue, MOD, unaire -, parenthèses, appels de fonctions.
17. Implémenter les comparaisons : =, ~=, <, <=, >, >=, avec résultat booléen exploitable par les branchements.
18. Implémenter l’expression conditionnelle BCPL cond -> exprTrue, exprFalse.
19. Implémenter VALOF $( ... RESULTIS expr ... $) comme bloc expression avec sortie contrôlée.
20. Générer le code des affectations := pour variables locales, paramètres modifiables si accepté, et statiques.
21. Implémenter les structures de contrôle : IF ... DO, UNLESS ... DO, TEST ... THEN ... ELSE ....
22. Implémenter les boucles : FOR ... TO ... DO, FOR ... TO ... BY ... DO, WHILE, UNTIL, REPEAT ... REPEATWHILE, avec gestion correcte de BREAK.
23. Implémenter SWITCHON expr INTO $( CASE n: ... DEFAULT: ... ENDCASE ... $) avec fall-through contrôlé et sortie par ENDCASE.
24. Fournir une petite bibliothèque runtime Win32 pour WRITES, WRITEN, WRITECH, NEWLINE, FINISH, en s’appuyant sur les API console Windows ou des imports C/Win32.
25. Créer une suite de validation automatique compilant et exécutant SAMPLES\BCPL\hello.b, fib.b, func.b, loops.b, switchon.b, avec comparaison des sorties attendues et tests des modes .EXE, .OBJ et .ASM optionnel.
}
Program BCPLCW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-} { Desactiver les IO-check pour gerer nous-memes les erreurs }

{ ============================================================
  INFRASTRUCTURE DE BASE
  ============================================================ }

Const
  BCPLCW32_VERSION = '1.0';
  BCPLCW32_DATE    = '2026';
  MAX_PATH_LEN     = 255;
  MAX_LINE_LEN     = 255;
  MAX_SYM          = 1024;
  MAX_BIN_CODE     = 65535;
  MAX_BIN_RDATA    = 65535;
  MAX_BIN_OUTPUT   = 1024;
  ABI_WORD_SIZE    = 4;
  ABI_PARAM_BASE   = 8;
  ABI_RET_REG      = 'EAX';
  ABI_FRAME_REG    = 'EBP';
  ABI_STACK_REG    = 'ESP';
  PE_MACHINE_I386  = $014C;
  PE_OPT_SIZE      = 224;
  PE_MAGIC_32      = $010B;
  PE_IMAGE_BASE    = $00400000;
  PE_SEC_ALIGN     = $1000;
  PE_FILE_ALIGN    = $0200;
  PE_SUBSYS_CUI    = 3;
  PE_SCN_TEXT      = $60000020;
  PE_SCN_RDATA     = $40000040;
  COFF_SYM_EXTERNAL = 2;
  COFF_SYM_STATIC   = 3;
  EXIT_OK          = 0;
  EXIT_ERROR       = 1;
  EXIT_USAGE       = 2;

Type
  TString = String[MAX_PATH_LEN];
  TSourceLine = String[MAX_LINE_LEN];

  TTokenKind = (
    TK_IDENT,
    TK_INTEGER,
    TK_STRING,
    TK_KEYWORD,
    TK_OP,
    TK_PUNCT,
    TK_EOF
  );

  TToken = Record
    kind    : TTokenKind;
    val     : TString;
    int_val : LongInt;
    line    : Integer;
    col     : Integer;
  End;

  TSymKind = (
    SK_PROC,
    SK_FUNC,
    SK_PARAM,
    SK_LOCAL,
    SK_STATIC
  );

  TSymbol = Record
    name      : TString;
    kind      : TSymKind;
    owner     : TString;
    const_val : LongInt;
    stack_off : LongInt;
    param_no  : Integer;
    param_cnt : Integer;
    local_size: LongInt;
    line      : Integer;
    col       : Integer;
  End;

  TSymbolTable = Array[1..MAX_SYM] Of TSymbol;
  TBinBuffer = Array[0..MAX_BIN_CODE - 1] Of Byte;
  TBinOutputTable = Array[1..MAX_BIN_OUTPUT] Of TString;

  { TODO 1 - Pipeline canonique du compilateur.

    Le compilateur BCPLCW32 est organise comme une suite d'etapes
    explicites. Chaque etape consomme l'artefact de l'etape precedente
    et produit le suivant :

      .b source BCPL
        -> flux de tokens
        -> AST / representation intermediaire BCPL
        -> assembleur 80386 Win32
        -> objet COFF 32 bits
        -> executable PE Win32

    Par defaut, le pipeline va jusqu'a l'executable. Les TODO 2 et 3
    brancheront les options permettant de s'arreter a l'OBJ et de
    conserver explicitement l'ASM.
  }
  TCompileStage = (
    CS_LOAD_SOURCE,
    CS_LEX_TOKENS,
    CS_PARSE_AST,
    CS_EMIT_ASM386,
    CS_BUILD_OBJ,
    CS_LINK_EXE
  );

  TArtifactKind = (
    AK_NONE,
    AK_SOURCE_BCPL,
    AK_TOKEN_STREAM,
    AK_AST_IR,
    AK_ASM_386,
    AK_OBJ_COFF,
    AK_EXE_PE32
  );

  TOutputMode = (
    OM_EXE,
    OM_OBJ
  );

  TPipelineOptions = Record
    output_mode : TOutputMode;
    keep_asm    : Boolean;
    verbose     : Boolean;
    test_mode   : Boolean;
    output_name : TString;
  End;

  TCompilerContext = Record
    source_name : TString;
    asm_name    : TString;
    obj_name    : TString;
    exe_name    : TString;
    options     : TPipelineOptions;
    last_art    : TArtifactKind;
    token_count : LongInt;
    block_count : LongInt;
    proc_count  : LongInt;
    func_count  : LongInt;
    param_count : LongInt;
    local_count : LongInt;
    expr_count  : LongInt;
    comp_count  : LongInt;
    cond_count  : LongInt;
    valof_count : LongInt;
    resultis_count: LongInt;
    assign_count: LongInt;
    control_count: LongInt;
    loop_count  : LongInt;
    break_count : LongInt;
    switch_count: LongInt;
    case_count  : LongInt;
    default_count: LongInt;
    endcase_count: LongInt;
    runtime_count: LongInt;
    static_count: LongInt;
    sym_count   : LongInt;
    abi_param_bytes: LongInt;
    abi_local_bytes: LongInt;
    max_param_count: LongInt;
    errors      : Integer;
  End;

Var
  src_file    : Text;
  lex_line    : TSourceLine;
  lex_pos     : Integer;
  lex_lineno  : Integer;
  lex_colno   : Integer;
  lex_eof     : Boolean;
  lex_open    : Boolean;
  cur_tok     : TToken;
  lex_errors  : Integer;
  lex_tokens  : LongInt;
  parse_errors: Integer;
  parse_blocks: LongInt;
  parse_procs : LongInt;
  parse_funcs : LongInt;
  parse_params: LongInt;
  parse_locals: LongInt;
  parse_exprs : LongInt;
  parse_comps : LongInt;
  parse_conds : LongInt;
  parse_valofs: LongInt;
  parse_resultis: LongInt;
  parse_valof_depth: Integer;
  parse_assigns: LongInt;
  parse_controls: LongInt;
  parse_loops : LongInt;
  parse_breaks: LongInt;
  parse_loop_depth: Integer;
  parse_switches: LongInt;
  parse_cases   : LongInt;
  parse_defaults: LongInt;
  parse_endcases: LongInt;
  parse_switch_depth: Integer;
  parse_runtime_refs: LongInt;
  parse_static: LongInt;
  parse_owner : TString;
  parse_param_offset: LongInt;
  parse_local_offset: LongInt;
  parse_param_bytes : LongInt;
  parse_local_bytes : LongInt;
  parse_param_index : Integer;
  parse_routine_params: Integer;
  parse_max_params  : Integer;
  sym_table   : TSymbolTable;
  sym_count   : Integer;
  bin_outputs : TBinOutputTable;
  bin_output_count: Integer;

Function StageName(stage : TCompileStage) : TString;
Begin
  Case stage Of
    CS_LOAD_SOURCE: StageName := 'chargement source .b';
    CS_LEX_TOKENS : StageName := 'analyse lexicale -> tokens';
    CS_PARSE_AST  : StageName := 'analyse syntaxique -> AST/IR';
    CS_EMIT_ASM386: StageName := 'generation assembleur 80386 Win32';
    CS_BUILD_OBJ  : StageName := 'assemblage -> objet COFF 32 bits';
    CS_LINK_EXE   : StageName := 'edition de liens -> executable PE Win32';
  Else
    StageName := 'etape inconnue';
  End;
End;

Function ArtifactName(artifact : TArtifactKind) : TString;
Begin
  Case artifact Of
    AK_NONE        : ArtifactName := 'aucun artefact';
    AK_SOURCE_BCPL : ArtifactName := 'source BCPL .b';
    AK_TOKEN_STREAM: ArtifactName := 'flux de tokens';
    AK_AST_IR      : ArtifactName := 'AST/IR BCPL';
    AK_ASM_386     : ArtifactName := 'assembleur 80386 Win32';
    AK_OBJ_COFF    : ArtifactName := 'objet COFF 32 bits';
    AK_EXE_PE32    : ArtifactName := 'executable PE Win32';
  Else
    ArtifactName := 'artefact inconnu';
  End;
End;

Function UpChar(c : Char) : Char;
Begin
  If (c >= 'a') And (c <= 'z') Then
    UpChar := Chr(Ord(c) - 32)
  Else
    UpChar := c;
End;

Function StrUpper(Const s : TString) : TString;
Var
  i : Integer;
  r : TString;
Begin
  r := s;
  For i := 1 To Length(r) Do
    r[i] := UpChar(r[i]);
  StrUpper := r;
End;

Function SameText(Const a, b : TString) : Boolean;
Begin
  SameText := StrUpper(a) = StrUpper(b);
End;

Function ChangeExtension(Const file_name, new_ext : TString) : TString;
Var
  i : Integer;
  r : TString;
Begin
  r := file_name;
  i := Length(r);
  While (i > 0) And (r[i] <> '.') And (r[i] <> '\') And (r[i] <> '/') Do
    Dec(i);

  If (i > 0) And (r[i] = '.') Then
    r := Copy(r, 1, i - 1);

  If (new_ext <> '') And (new_ext[1] = '.') Then
    ChangeExtension := r + new_ext
  Else
    ChangeExtension := r + '.' + new_ext;
End;

Function FileExtension(Const file_name : TString) : TString;
Var
  i : Integer;
Begin
  i := Length(file_name);
  While (i > 0) And (file_name[i] <> '.') And
        (file_name[i] <> '\') And (file_name[i] <> '/') Do
    Dec(i);

  If (i > 0) And (file_name[i] = '.') Then
    FileExtension := StrUpper(Copy(file_name, i, Length(file_name) - i + 1))
  Else
  FileExtension := '';
End;

Function LongToStr(v : LongInt) : TString;
Var
  s : TString;
Begin
  Str(v, s);
  LongToStr := s;
End;

Function OutputModeName(mode : TOutputMode) : TString;
Begin
  Case mode Of
    OM_EXE: OutputModeName := 'EXE Win32';
    OM_OBJ: OutputModeName := 'OBJ COFF';
  Else
    OutputModeName := 'mode inconnu';
  End;
End;

Function TokenKindName(kind : TTokenKind) : TString;
Begin
  Case kind Of
    TK_IDENT  : TokenKindName := 'IDENT';
    TK_INTEGER: TokenKindName := 'INTEGER';
    TK_STRING : TokenKindName := 'STRING';
    TK_KEYWORD: TokenKindName := 'KEYWORD';
    TK_OP     : TokenKindName := 'OP';
    TK_PUNCT  : TokenKindName := 'PUNCT';
    TK_EOF    : TokenKindName := 'EOF';
  Else
    TokenKindName := 'UNKNOWN';
  End;
End;

Procedure ParseError(Const msg : TString); Forward;

Function SymKindName(kind : TSymKind) : TString;
Begin
  Case kind Of
    SK_PROC  : SymKindName := 'PROC';
    SK_FUNC  : SymKindName := 'FUNC';
    SK_PARAM : SymKindName := 'PARAM';
    SK_LOCAL : SymKindName := 'LOCAL';
    SK_STATIC: SymKindName := 'STATIC';
  Else
    SymKindName := 'UNKNOWN';
  End;
End;

Function SymFindInOwner(Const name, owner : TString) : Integer;
Var
  i : Integer;
Begin
  For i := sym_count DownTo 1 Do
    If (sym_table[i].name = name) And (sym_table[i].owner = owner) Then
    Begin
      SymFindInOwner := i;
      Exit;
    End;
  SymFindInOwner := 0;
End;

Function SymEnter(Const name : TString; kind : TSymKind;
                  Const owner : TString; const_val, stack_off : LongInt) : Integer;
Begin
  If sym_count >= MAX_SYM Then
  Begin
    ParseError('table des symboles saturee');
    SymEnter := 0;
    Exit;
  End;

  If SymFindInOwner(name, owner) <> 0 Then
  Begin
    ParseError('symbole deja declare: ' + name);
    SymEnter := 0;
    Exit;
  End;

  Inc(sym_count);
  sym_table[sym_count].name      := name;
  sym_table[sym_count].kind      := kind;
  sym_table[sym_count].owner     := owner;
  sym_table[sym_count].const_val := const_val;
  sym_table[sym_count].stack_off := stack_off;
  sym_table[sym_count].param_no  := 0;
  sym_table[sym_count].param_cnt := 0;
  sym_table[sym_count].local_size:= 0;
  sym_table[sym_count].line      := cur_tok.line;
  sym_table[sym_count].col       := cur_tok.col;
  SymEnter := sym_count;
End;

Function SymFindAssignable(Const name, owner : TString) : Integer;
Var
  idx : Integer;
Begin
  idx := SymFindInOwner(name, owner);
  If (idx <> 0) And
     ((sym_table[idx].kind = SK_LOCAL) Or (sym_table[idx].kind = SK_PARAM)) Then
  Begin
    SymFindAssignable := idx;
    Exit;
  End;

  idx := SymFindInOwner(name, '');
  If (idx <> 0) And (sym_table[idx].kind = SK_STATIC) Then
  Begin
    SymFindAssignable := idx;
    Exit;
  End;

  SymFindAssignable := 0;
End;

Function LexIsAlpha(c : Char) : Boolean;
Begin
  LexIsAlpha := ((c >= 'A') And (c <= 'Z')) Or
                ((c >= 'a') And (c <= 'z')) Or
                (c = '_');
End;

Function LexIsDigit(c : Char) : Boolean;
Begin
  LexIsDigit := (c >= '0') And (c <= '9');
End;

Function LexIsAlNum(c : Char) : Boolean;
Begin
  LexIsAlNum := LexIsAlpha(c) Or LexIsDigit(c);
End;

Function LexIsWhite(c : Char) : Boolean;
Begin
  LexIsWhite := (c = ' ') Or (c = #9) Or (c = #13);
End;

Function LexIsKeyword(Const s : TString) : Boolean;
Begin
  LexIsKeyword :=
    (s = 'LET') Or (s = 'BE') Or (s = 'DO') Or
    (s = 'VALOF') Or
    (s = 'RESULTIS') Or (s = 'STATIC') Or
    (s = 'IF') Or (s = 'UNLESS') Or (s = 'TEST') Or
    (s = 'THEN') Or (s = 'ELSE') Or
    (s = 'FOR') Or (s = 'TO') Or (s = 'BY') Or
    (s = 'WHILE') Or (s = 'UNTIL') Or
    (s = 'REPEAT') Or (s = 'REPEATWHILE') Or
    (s = 'BREAK') Or
    (s = 'SWITCHON') Or (s = 'INTO') Or
    (s = 'CASE') Or (s = 'DEFAULT') Or (s = 'ENDCASE') Or
    (s = 'FINISH') Or (s = 'MOD');
End;

Procedure LexError(Const msg : TString);
Begin
  Inc(lex_errors);
  WriteLn('Erreur lexicale(', lex_lineno, ',', lex_colno, '): ', msg);
End;

Procedure LexMakeTok(Var t : TToken; kind : TTokenKind; Const val : TString);
Begin
  t.kind    := kind;
  t.val     := val;
  t.int_val := 0;
  t.line    := lex_lineno;
  t.col     := lex_colno;
End;

Procedure LexRefill;
Begin
  If Eof(src_file) Then
  Begin
    lex_eof    := True;
    lex_line   := '';
    lex_pos    := 1;
    lex_colno  := 1;
  End
  Else
  Begin
    ReadLn(src_file, lex_line);
    Inc(lex_lineno);
    lex_pos   := 1;
    lex_colno := 1;
  End;
End;

Function LexCurChar : Char;
Begin
  If lex_eof Then
    LexCurChar := #0
  Else If lex_pos > Length(lex_line) Then
    LexCurChar := #0
  Else
    LexCurChar := lex_line[lex_pos];
End;

Function LexPeekChar(n : Integer) : Char;
Var
  p : Integer;
Begin
  p := lex_pos + n;
  If lex_eof Or (p < 1) Or (p > Length(lex_line)) Then
    LexPeekChar := #0
  Else
    LexPeekChar := lex_line[p];
End;

Procedure LexAdvance;
Begin
  If Not lex_eof Then
  Begin
    Inc(lex_pos);
    Inc(lex_colno);
  End;
End;

Procedure LexSkipLineComment;
Begin
  While (Not lex_eof) And (LexCurChar <> #0) Do
    LexAdvance;
End;

Procedure LexSkipWS;
Var
  again : Boolean;
Begin
  Repeat
    again := False;

    While (Not lex_eof) And LexIsWhite(LexCurChar) Do
      LexAdvance;

    If (Not lex_eof) And (LexCurChar = #0) Then
    Begin
      LexRefill;
      again := True;
    End
    Else If (Not lex_eof) And (LexCurChar = '/') And (LexPeekChar(1) = '/') Then
    Begin
      LexSkipLineComment;
      again := True;
    End;
  Until Not again;
End;

Procedure LexReadIdent(Var t : TToken);
Var
  s : TString;
Begin
  s := '';
  While (Not lex_eof) And LexIsAlNum(LexCurChar) Do
  Begin
    If Length(s) < MAX_PATH_LEN Then
      s := s + UpChar(LexCurChar);
    LexAdvance;
  End;

  If LexIsKeyword(s) Then
    LexMakeTok(t, TK_KEYWORD, s)
  Else
    LexMakeTok(t, TK_IDENT, s);
End;

Procedure LexReadNumber(Var t : TToken);
Var
  s : TString;
  i : Integer;
  n : LongInt;
Begin
  s := '';
  While (Not lex_eof) And LexIsDigit(LexCurChar) Do
  Begin
    If Length(s) < MAX_PATH_LEN Then
      s := s + LexCurChar;
    LexAdvance;
  End;

  n := 0;
  For i := 1 To Length(s) Do
    n := n * 10 + (Ord(s[i]) - Ord('0'));

  LexMakeTok(t, TK_INTEGER, s);
  t.int_val := n;
End;

Procedure LexReadString(Var t : TToken);
Var
  s : TString;
  c : Char;
Begin
  s := '';
  LexAdvance; { sauter le guillemet ouvrant }

  While (Not lex_eof) And (LexCurChar <> #0) And (LexCurChar <> '"') Do
  Begin
    If LexCurChar = '*' Then
    Begin
      LexAdvance; { sauter '*' }
      Case UpChar(LexCurChar) Of
        'N' : c := #10;
        'T' : c := #9;
        '"' : c := '"';
        '*' : c := '*';
      Else
        c := LexCurChar;
      End;
      If Length(s) < MAX_PATH_LEN Then
        s := s + c;
      If Not lex_eof Then
        LexAdvance;
    End
    Else
    Begin
      If Length(s) < MAX_PATH_LEN Then
        s := s + LexCurChar;
      LexAdvance;
    End;
  End;

  If LexCurChar = '"' Then
    LexAdvance
  Else
    LexError('chaine non terminee');

  LexMakeTok(t, TK_STRING, s);
End;

Procedure LexReadOp(Var t : TToken);
Var
  s : TString;
  c : Char;
Begin
  c := LexCurChar;
  s := c;
  LexAdvance;

  Case c Of
    ':' : If LexCurChar = '=' Then
          Begin
            s := ':=';
            LexAdvance;
          End;
    '~' : If LexCurChar = '=' Then
          Begin
            s := '~=';
            LexAdvance;
          End;
    '<' : If LexCurChar = '=' Then
          Begin
            s := '<=';
            LexAdvance;
          End
          Else If LexCurChar = '<' Then
          Begin
            s := '<<';
            LexAdvance;
          End;
    '>' : If LexCurChar = '=' Then
          Begin
            s := '>=';
            LexAdvance;
          End
          Else If LexCurChar = '>' Then
          Begin
            s := '>>';
            LexAdvance;
          End;
    '-' : If LexCurChar = '>' Then
          Begin
            s := '->';
            LexAdvance;
          End;
    '$' : If LexCurChar = '(' Then
          Begin
            s := '$(';
            LexAdvance;
          End
          Else If LexCurChar = ')' Then
          Begin
            s := '$)';
            LexAdvance;
          End;
  End;

  If (s = '(') Or (s = ')') Or (s = '[') Or (s = ']') Or
     (s = ',') Or (s = ';') Or (s = ':') Or (s = '.') Or
     (s = '{') Or (s = '}') Then
    LexMakeTok(t, TK_PUNCT, s)
  Else
    LexMakeTok(t, TK_OP, s);
End;

Procedure LexNext;
Begin
  LexSkipWS;
  lex_colno := lex_pos;

  If lex_eof Or (LexCurChar = #0) Then
  Begin
    LexMakeTok(cur_tok, TK_EOF, '');
    Exit;
  End;

  If LexIsAlpha(LexCurChar) Then
  Begin
    LexReadIdent(cur_tok);
    Exit;
  End;

  If LexIsDigit(LexCurChar) Then
  Begin
    LexReadNumber(cur_tok);
    Exit;
  End;

  If LexCurChar = '"' Then
  Begin
    LexReadString(cur_tok);
    Exit;
  End;

  LexReadOp(cur_tok);
End;

Function LexOpenSource(Const file_name : TString) : Boolean;
Begin
  LexOpenSource := False;
  Assign(src_file, file_name);
  Reset(src_file);
  If IOResult <> 0 Then
  Begin
    WriteLn('Erreur: impossible d''ouvrir ', file_name);
    Exit;
  End;

  lex_line   := '';
  lex_pos    := 1;
  lex_lineno := 0;
  lex_colno  := 1;
  lex_eof    := False;
  lex_open   := True;
  lex_errors := 0;
  lex_tokens := 0;
  LexRefill;
  LexOpenSource := True;
End;

Procedure LexCloseSource;
Begin
  If lex_open Then
  Begin
    Close(src_file);
    lex_open := False;
  End;
End;

Function LexScanFile(Var ctx : TCompilerContext) : Boolean;
Begin
  LexScanFile := False;
  If Not LexOpenSource(ctx.source_name) Then
  Begin
    Inc(ctx.errors);
    Exit;
  End;

  Repeat
    LexNext;
    If cur_tok.kind <> TK_EOF Then
      Inc(lex_tokens);
  Until cur_tok.kind = TK_EOF;

  LexCloseSource;
  ctx.token_count := lex_tokens;
  Inc(ctx.errors, lex_errors);
  LexScanFile := lex_errors = 0;
End;

Function SourceReadable(Const file_name : TString) : Boolean;
Var
  f : Text;
Begin
  SourceReadable := False;
  Assign(f, file_name);
  Reset(f);
  If IOResult = 0 Then
  Begin
    Close(f);
    SourceReadable := True;
  End;
End;

Procedure ParseError(Const msg : TString);
Begin
  Inc(parse_errors);
  WriteLn('Erreur syntaxique(', cur_tok.line, ',', cur_tok.col, '): ', msg);
End;

Procedure ParseLocalLet; Forward;
Procedure ParseBlock; Forward;
Procedure ParseIntegerExpr; Forward;

Function ExprStarts : Boolean;
Begin
  ExprStarts := (cur_tok.kind = TK_INTEGER) Or (cur_tok.kind = TK_IDENT) Or
                (cur_tok.val = '(') Or (cur_tok.val = '-') Or
                (cur_tok.val = 'VALOF');
End;

Function IsRuntimeRoutine(Const name : TString) : Boolean;
Begin
  IsRuntimeRoutine := (name = 'WRITES') Or (name = 'WRITEN') Or
                      (name = 'WRITECH') Or (name = 'NEWLINE') Or
                      (name = 'FINISH');
End;

Procedure ParseActualArgList;
Begin
  If cur_tok.val <> '(' Then
    Exit;

  LexNext;
  If cur_tok.val = ')' Then
  Begin
    LexNext;
    Exit;
  End;

  While cur_tok.kind <> TK_EOF Do
  Begin
    If Not ExprStarts Then
    Begin
      ParseError('expression attendue dans appel de fonction');
      Exit;
    End;
    ParseIntegerExpr;

    If cur_tok.val = ',' Then
      LexNext
    Else If cur_tok.val = ')' Then
    Begin
      LexNext;
      Exit;
    End
    Else
    Begin
      ParseError('"," ou ")" attendu dans appel de fonction');
      Exit;
    End;
  End;

  ParseError('appel de fonction non termine: ) attendu');
End;

Procedure ParseExprPrimary;
Var
  saved_resultis : LongInt;
Begin
  If cur_tok.val = 'VALOF' Then
  Begin
    { ParseValofExpr est defini plus bas; l'appel direct reste possible
      car ParseBlock est deja declare en forward. }
    LexNext;
    If cur_tok.val <> '$(' Then
    Begin
      ParseError('bloc VALOF attendu: $(');
      Exit;
    End;
    Inc(parse_valofs);
    Inc(parse_valof_depth);
    saved_resultis := parse_resultis;
    ParseBlock;
    Dec(parse_valof_depth);
    If parse_resultis = saved_resultis Then
      ParseError('VALOF sans RESULTIS');
  End
  Else If cur_tok.kind = TK_INTEGER Then
    LexNext
  Else If cur_tok.kind = TK_IDENT Then
  Begin
    LexNext;
    If cur_tok.val = '(' Then
      ParseActualArgList;
  End
  Else If cur_tok.val = '(' Then
  Begin
    LexNext;
    ParseIntegerExpr;
    If cur_tok.val = ')' Then
      LexNext
    Else
      ParseError(') attendu dans expression');
  End
  Else
    ParseError('expression entiere attendue');
End;

Procedure ParseExprUnary;
Begin
  If cur_tok.val = '-' Then
  Begin
    LexNext;
    ParseExprUnary;
  End
  Else
    ParseExprPrimary;
End;

Procedure ParseExprMul;
Begin
  ParseExprUnary;
  While (cur_tok.val = '*') Or (cur_tok.val = '/') Or (cur_tok.val = 'MOD') Do
  Begin
    LexNext;
    ParseExprUnary;
  End;
End;

Procedure ParseExprAdd;
Begin
  ParseExprMul;
  While (cur_tok.val = '+') Or (cur_tok.val = '-') Do
  Begin
    LexNext;
    ParseExprMul;
  End;
End;

Function IsCompareOp(Const op : TString) : Boolean;
Begin
  IsCompareOp := (op = '=') Or (op = '~=') Or (op = '<') Or
                 (op = '<=') Or (op = '>') Or (op = '>=');
End;

Procedure ParseExprCompare;
Begin
  ParseExprAdd;
  While IsCompareOp(cur_tok.val) Do
  Begin
    Inc(parse_comps);
    LexNext;
    ParseExprAdd;
  End;
End;

Procedure ParseExprConditional;
Begin
  ParseExprCompare;
  If cur_tok.val = '->' Then
  Begin
    Inc(parse_conds);
    LexNext;
    If ExprStarts Then
      ParseExprConditional
    Else
    Begin
      ParseError('expression vraie attendue apres ->');
      Exit;
    End;

    If cur_tok.val = ',' Then
      LexNext
    Else
    Begin
      ParseError('"," attendu dans expression conditionnelle');
      Exit;
    End;

    If ExprStarts Then
      ParseExprConditional
    Else
      ParseError('expression fausse attendue apres ","');
  End;
End;

Procedure ParseIntegerExpr;
Begin
  Inc(parse_exprs);
  ParseExprConditional;
End;

Procedure ParseResultIs;
Begin
  If parse_valof_depth <= 0 Then
    ParseError('RESULTIS hors VALOF');
  Inc(parse_resultis);
  LexNext; { RESULTIS }
  If ExprStarts Then
    ParseIntegerExpr
  Else
    ParseError('expression attendue apres RESULTIS');
End;

Procedure ParseControlStatement; Forward;
Procedure ParseLoopStatement; Forward;
Procedure ParseSwitchStatement; Forward;

Procedure ParseRuntimeCallTail(Const name : TString);
Begin
  Inc(parse_runtime_refs);

  If cur_tok.val <> '(' Then
  Begin
    If name <> 'FINISH' Then
      ParseError('( attendu apres appel runtime ' + name);
    Exit;
  End;

  LexNext;
  If name = 'WRITES' Then
  Begin
    If cur_tok.kind = TK_STRING Then
      LexNext
    Else
      ParseError('chaine attendue dans WRITES');
  End
  Else If (name = 'WRITEN') Or (name = 'WRITECH') Then
  Begin
    If ExprStarts Then
      ParseIntegerExpr
    Else
      ParseError('expression entiere attendue dans ' + name);
  End
  Else If (name = 'NEWLINE') Or (name = 'FINISH') Then
  Begin
    If cur_tok.val <> ')' Then
      ParseError(') attendu dans ' + name);
  End;

  If cur_tok.val = ')' Then
    LexNext
  Else
    ParseError(') attendu apres appel runtime ' + name);
End;

Procedure ParseRuntimeStatement;
Var
  runtime_name : TString;
Begin
  runtime_name := cur_tok.val;
  LexNext;
  ParseRuntimeCallTail(runtime_name);
End;

Procedure ParseEndCaseStatement;
Begin
  If parse_switch_depth <= 0 Then
    ParseError('ENDCASE hors SWITCHON');
  Inc(parse_endcases);
  LexNext;
End;

Procedure ParseBreakStatement;
Begin
  If parse_loop_depth <= 0 Then
    ParseError('BREAK hors boucle');
  Inc(parse_breaks);
  LexNext;
End;

Procedure ParseAssignmentOrIdent;
Var
  target_name : TString;
  sym_idx     : Integer;
Begin
  target_name := cur_tok.val;
  LexNext;
  If cur_tok.val <> ':=' Then
  Begin
    If IsRuntimeRoutine(target_name) Then
      ParseRuntimeCallTail(target_name);
    Exit;
  End;

  sym_idx := SymFindAssignable(target_name, parse_owner);
  If sym_idx = 0 Then
    ParseError('cible d''affectation inconnue ou non modifiable: ' + target_name);

  Inc(parse_assigns);
  LexNext;
  If ExprStarts Then
    ParseIntegerExpr
  Else
    ParseError('expression attendue apres :=');
End;

Procedure ParseControlBody(stop_at_else : Boolean);
Var
  body_line : Integer;
Begin
  If cur_tok.kind = TK_EOF Then
  Begin
    ParseError('corps de controle attendu');
    Exit;
  End;

  If cur_tok.val = '$(' Then
  Begin
    ParseBlock;
    Exit;
  End;

  body_line := cur_tok.line;
  If IsRuntimeRoutine(cur_tok.val) Then
    ParseRuntimeStatement
  Else If cur_tok.val = 'LET' Then
    ParseLocalLet
  Else If cur_tok.val = 'RESULTIS' Then
    ParseResultIs
  Else If (cur_tok.val = 'IF') Or (cur_tok.val = 'UNLESS') Or
          (cur_tok.val = 'TEST') Then
    ParseControlStatement
  Else If (cur_tok.val = 'FOR') Or (cur_tok.val = 'WHILE') Or
          (cur_tok.val = 'UNTIL') Or (cur_tok.val = 'REPEAT') Then
    ParseLoopStatement
  Else If cur_tok.val = 'SWITCHON' Then
    ParseSwitchStatement
  Else If cur_tok.val = 'BREAK' Then
    ParseBreakStatement
  Else If cur_tok.val = 'ENDCASE' Then
    ParseEndCaseStatement
  Else If (cur_tok.val = 'CASE') Or (cur_tok.val = 'DEFAULT') Then
  Begin
    ParseError('CASE ou DEFAULT hors SWITCHON');
    LexNext;
  End
  Else If cur_tok.kind = TK_IDENT Then
    ParseAssignmentOrIdent
  Else
    LexNext;

  While (cur_tok.kind <> TK_EOF) And (cur_tok.val <> '$)') And
        (cur_tok.line = body_line) And
        ((Not stop_at_else) Or (cur_tok.val <> 'ELSE')) Do
    LexNext;
End;

Procedure ParseIfUnless(Const keyword : TString);
Begin
  Inc(parse_controls);
  LexNext;
  If ExprStarts Then
    ParseIntegerExpr
  Else
    ParseError('condition attendue apres ' + keyword);

  If cur_tok.val = 'DO' Then
    LexNext
  Else
    ParseError('DO attendu apres ' + keyword);

  ParseControlBody(False);
End;

Procedure ParseTest;
Begin
  Inc(parse_controls);
  LexNext;
  If ExprStarts Then
    ParseIntegerExpr
  Else
    ParseError('condition attendue apres TEST');

  If cur_tok.val = 'THEN' Then
    LexNext
  Else
    ParseError('THEN attendu apres TEST');

  ParseControlBody(True);

  If cur_tok.val = 'ELSE' Then
  Begin
    LexNext;
    ParseControlBody(False);
  End
  Else
    ParseError('ELSE attendu apres TEST ... THEN');
End;

Procedure ParseControlStatement;
Begin
  If cur_tok.val = 'IF' Then
    ParseIfUnless('IF')
  Else If cur_tok.val = 'UNLESS' Then
    ParseIfUnless('UNLESS')
  Else If cur_tok.val = 'TEST' Then
    ParseTest
  Else
    ParseError('structure de controle attendue');
End;

Procedure ParseLoopBody;
Begin
  Inc(parse_loop_depth);
  ParseControlBody(False);
  Dec(parse_loop_depth);
End;

Procedure ParseFor;
Var
  loop_var : TString;
  sym_idx  : Integer;
Begin
  Inc(parse_loops);
  LexNext;
  If cur_tok.kind <> TK_IDENT Then
  Begin
    ParseError('variable de boucle attendue apres FOR');
    Exit;
  End;

  loop_var := cur_tok.val;
  sym_idx := SymFindAssignable(loop_var, parse_owner);
  If sym_idx = 0 Then
    ParseError('variable de boucle inconnue ou non modifiable: ' + loop_var);
  LexNext;

  If cur_tok.val = '=' Then
    LexNext
  Else
    ParseError('= attendu apres variable de boucle FOR');

  If ExprStarts Then
    ParseIntegerExpr
  Else
    ParseError('borne initiale attendue dans FOR');

  If cur_tok.val = 'TO' Then
    LexNext
  Else
    ParseError('TO attendu dans FOR');

  If ExprStarts Then
    ParseIntegerExpr
  Else
    ParseError('borne finale attendue dans FOR');

  If cur_tok.val = 'BY' Then
  Begin
    LexNext;
    If ExprStarts Then
      ParseIntegerExpr
    Else
      ParseError('pas attendu apres BY');
  End;

  If cur_tok.val = 'DO' Then
    LexNext
  Else
    ParseError('DO attendu dans FOR');

  ParseLoopBody;
End;

Procedure ParseWhileUntil(Const keyword : TString);
Begin
  Inc(parse_loops);
  LexNext;
  If ExprStarts Then
    ParseIntegerExpr
  Else
    ParseError('condition attendue apres ' + keyword);

  If cur_tok.val = 'DO' Then
    LexNext
  Else
    ParseError('DO attendu apres ' + keyword);

  ParseLoopBody;
End;

Procedure ParseRepeat;
Begin
  Inc(parse_loops);
  LexNext;
  ParseLoopBody;

  If cur_tok.val = 'REPEATWHILE' Then
  Begin
    LexNext;
    If ExprStarts Then
      ParseIntegerExpr
    Else
      ParseError('condition attendue apres REPEATWHILE');
  End
  Else
    ParseError('REPEATWHILE attendu apres REPEAT');
End;

Procedure ParseLoopStatement;
Begin
  If cur_tok.val = 'FOR' Then
    ParseFor
  Else If cur_tok.val = 'WHILE' Then
    ParseWhileUntil('WHILE')
  Else If cur_tok.val = 'UNTIL' Then
    ParseWhileUntil('UNTIL')
  Else If cur_tok.val = 'REPEAT' Then
    ParseRepeat
  Else
    ParseError('boucle attendue');
End;

Procedure ParseCaseLabelValue;
Begin
  If cur_tok.val = '-' Then
    LexNext;

  If cur_tok.kind = TK_INTEGER Then
    LexNext
  Else
    ParseError('constante entiere attendue apres CASE');
End;

Procedure ParseSwitchCaseBody;
Begin
  While (cur_tok.kind <> TK_EOF) And (cur_tok.val <> '$)') And
        (cur_tok.val <> 'CASE') And (cur_tok.val <> 'DEFAULT') Do
  Begin
    If IsRuntimeRoutine(cur_tok.val) Then
      ParseRuntimeStatement
    Else If cur_tok.val = 'LET' Then
      ParseLocalLet
    Else If cur_tok.val = 'RESULTIS' Then
      ParseResultIs
    Else If (cur_tok.val = 'IF') Or (cur_tok.val = 'UNLESS') Or
            (cur_tok.val = 'TEST') Then
      ParseControlStatement
    Else If (cur_tok.val = 'FOR') Or (cur_tok.val = 'WHILE') Or
            (cur_tok.val = 'UNTIL') Or (cur_tok.val = 'REPEAT') Then
      ParseLoopStatement
    Else If cur_tok.val = 'SWITCHON' Then
      ParseSwitchStatement
    Else If cur_tok.val = 'BREAK' Then
      ParseBreakStatement
    Else If cur_tok.val = 'ENDCASE' Then
    Begin
      ParseEndCaseStatement;
      Exit;
    End
    Else If cur_tok.kind = TK_IDENT Then
      ParseAssignmentOrIdent
    Else If cur_tok.val = '$(' Then
      ParseBlock
    Else
      LexNext;
  End;
End;

Procedure ParseSwitchCase(Var default_seen : Boolean);
Begin
  If cur_tok.val = 'CASE' Then
  Begin
    Inc(parse_cases);
    LexNext;
    ParseCaseLabelValue;
    If cur_tok.val = ':' Then
      LexNext
    Else
      ParseError(': attendu apres CASE');
    ParseSwitchCaseBody;
  End
  Else If cur_tok.val = 'DEFAULT' Then
  Begin
    If default_seen Then
      ParseError('DEFAULT deja defini dans ce SWITCHON');
    default_seen := True;
    Inc(parse_defaults);
    LexNext;
    If cur_tok.val = ':' Then
      LexNext
    Else
      ParseError(': attendu apres DEFAULT');
    ParseSwitchCaseBody;
  End
  Else
  Begin
    ParseError('CASE ou DEFAULT attendu dans SWITCHON');
    LexNext;
  End;
End;

Procedure ParseSwitchStatement;
Var
  default_seen : Boolean;
Begin
  Inc(parse_switches);
  default_seen := False;
  LexNext;
  If ExprStarts Then
    ParseIntegerExpr
  Else
    ParseError('expression attendue apres SWITCHON');

  If cur_tok.val = 'INTO' Then
    LexNext
  Else
    ParseError('INTO attendu apres SWITCHON');

  If cur_tok.val = '$(' Then
  Begin
    Inc(parse_blocks);
    LexNext
  End
  Else
  Begin
    ParseError('bloc SWITCHON attendu: $(');
    Exit;
  End;

  Inc(parse_switch_depth);
  While (cur_tok.kind <> TK_EOF) And (cur_tok.val <> '$)') Do
    ParseSwitchCase(default_seen);
  Dec(parse_switch_depth);

  If cur_tok.val = '$)' Then
    LexNext
  Else
    ParseError('bloc SWITCHON non termine: $) attendu');
End;

Procedure ParseBlock;
Begin
  If cur_tok.val <> '$(' Then
  Begin
    ParseError('bloc BCPL attendu: $(');
    Exit;
  End;

  Inc(parse_blocks);
  LexNext;

  While (cur_tok.kind <> TK_EOF) And (cur_tok.val <> '$)') Do
  Begin
    If IsRuntimeRoutine(cur_tok.val) Then
      ParseRuntimeStatement
    Else If cur_tok.val = 'LET' Then
      ParseLocalLet
    Else If cur_tok.val = 'RESULTIS' Then
      ParseResultIs
    Else If (cur_tok.val = 'IF') Or (cur_tok.val = 'UNLESS') Or
            (cur_tok.val = 'TEST') Then
      ParseControlStatement
    Else If (cur_tok.val = 'FOR') Or (cur_tok.val = 'WHILE') Or
            (cur_tok.val = 'UNTIL') Or (cur_tok.val = 'REPEAT') Then
      ParseLoopStatement
    Else If cur_tok.val = 'SWITCHON' Then
      ParseSwitchStatement
    Else If cur_tok.val = 'BREAK' Then
      ParseBreakStatement
    Else If cur_tok.val = 'ENDCASE' Then
      ParseEndCaseStatement
    Else If (cur_tok.val = 'CASE') Or (cur_tok.val = 'DEFAULT') Then
    Begin
      ParseError('CASE ou DEFAULT hors SWITCHON');
      LexNext;
    End
    Else If cur_tok.kind = TK_IDENT Then
      ParseAssignmentOrIdent
    Else If cur_tok.val = '$(' Then
      ParseBlock
    Else
      LexNext;
  End;

  If cur_tok.val = '$)' Then
    LexNext
  Else
    ParseError('bloc BCPL non termine: $) attendu');
End;

Procedure ParseFormalParamList;
Var
  sym_idx : Integer;
Begin
  If cur_tok.val <> '(' Then
  Begin
    ParseError('liste de parametres attendue: (');
    Exit;
  End;

  LexNext;
  If cur_tok.val = ')' Then
  Begin
    LexNext;
    Exit;
  End;

  While cur_tok.kind <> TK_EOF Do
  Begin
    If cur_tok.kind <> TK_IDENT Then
    Begin
      ParseError('nom de parametre attendu');
      Exit;
    End;
    Inc(parse_param_index);
    Inc(parse_routine_params);
    sym_idx := SymEnter(cur_tok.val, SK_PARAM, parse_owner, 0, parse_param_offset);
    If sym_idx <> 0 Then
      sym_table[sym_idx].param_no := parse_param_index;
    Inc(parse_params);
    Inc(parse_param_bytes, ABI_WORD_SIZE);
    Inc(parse_param_offset, ABI_WORD_SIZE);
    LexNext;

    If cur_tok.val = ',' Then
      LexNext
    Else If cur_tok.val = ')' Then
    Begin
      LexNext;
      Exit;
    End
    Else
    Begin
      ParseError('"," ou ")" attendu dans la liste de parametres');
      Exit;
    End;
  End;

  ParseError('liste de parametres non terminee: ) attendu');
End;

Procedure ParseLocalLet;
Var
  local_name: TString;
Begin
  LexNext; { LET }
  If cur_tok.kind <> TK_IDENT Then
  Begin
    ParseError('nom de variable locale attendu apres LET');
    Exit;
  End;

  local_name := cur_tok.val;
  LexNext;
  If cur_tok.val <> '=' Then
  Begin
    ParseError('= attendu apres variable locale');
    Exit;
  End;

  Inc(parse_locals);
  Inc(parse_local_offset, ABI_WORD_SIZE);
  SymEnter(local_name, SK_LOCAL, parse_owner, 0, -parse_local_offset);
  Inc(parse_local_bytes, ABI_WORD_SIZE);
  LexNext;
  If ExprStarts Then
    ParseIntegerExpr
  Else
    ParseError('expression attendue apres =');
End;

Procedure ParseStaticBlock;
Var
  static_name : TString;
  static_val  : LongInt;
Begin
  LexNext; { STATIC }
  If cur_tok.val <> '$(' Then
  Begin
    ParseError('bloc STATIC attendu: $(');
    Exit;
  End;

  Inc(parse_blocks);
  LexNext;
  While (cur_tok.kind <> TK_EOF) And (cur_tok.val <> '$)') Do
  Begin
    If cur_tok.kind <> TK_IDENT Then
    Begin
      ParseError('nom de variable statique attendu');
      While (cur_tok.kind <> TK_EOF) And (cur_tok.val <> '$)') Do LexNext;
      If cur_tok.val = '$)' Then LexNext;
      Exit;
    End;

    static_name := cur_tok.val;
    LexNext;
    If cur_tok.val <> '=' Then
    Begin
      ParseError('= attendu dans declaration STATIC');
      While (cur_tok.kind <> TK_EOF) And (cur_tok.val <> '$)') Do LexNext;
      If cur_tok.val = '$)' Then LexNext;
      Exit;
    End;

    LexNext;
    If cur_tok.kind <> TK_INTEGER Then
    Begin
      ParseError('valeur entiere attendue dans declaration STATIC');
      While (cur_tok.kind <> TK_EOF) And (cur_tok.val <> '$)') Do LexNext;
      If cur_tok.val = '$)' Then LexNext;
      Exit;
    End;

    static_val := cur_tok.int_val;
    Inc(parse_static);
    SymEnter(static_name, SK_STATIC, '', static_val, 0);
    LexNext;
  End;

  If cur_tok.val = '$)' Then
    LexNext
  Else
    ParseError('bloc STATIC non termine: $) attendu');
End;

Procedure ParseFunctionExpr;
Begin
  While cur_tok.kind <> TK_EOF Do
  Begin
    If ExprStarts Then
      ParseIntegerExpr
    Else If IsRuntimeRoutine(cur_tok.val) Then
      ParseRuntimeStatement
    Else If cur_tok.val = '$(' Then
      ParseBlock
    Else If cur_tok.val = '$)' Then
    Begin
      ParseError('fin de bloc inattendue: $)');
      LexNext;
    End
    Else If (cur_tok.val = 'LET') Or (cur_tok.val = 'STATIC') Then
      Exit
    Else
      LexNext;
  End;
End;

Procedure ParseGlobalLet;
Var
  global_name : TString;
  saved_owner : TString;
  global_sym  : Integer;
Begin
  LexNext; { LET }
  If cur_tok.kind <> TK_IDENT Then
  Begin
    ParseError('nom attendu apres LET');
    Exit;
  End;

  global_name := cur_tok.val;
  saved_owner := parse_owner;
  parse_owner := global_name;
  parse_param_offset := ABI_PARAM_BASE;
  parse_local_offset := 0;
  parse_param_index := 0;
  parse_routine_params := 0;
  LexNext;
  ParseFormalParamList;
  If parse_errors > 0 Then
  Begin
    parse_owner := saved_owner;
    Exit;
  End;

  If cur_tok.val = 'BE' Then
  Begin
    Inc(parse_procs);
    global_sym := SymEnter(global_name, SK_PROC, '', 0, 0);
    LexNext;
    If cur_tok.val = '$(' Then
      ParseBlock;
  End
  Else If cur_tok.val = '=' Then
  Begin
    Inc(parse_funcs);
    global_sym := SymEnter(global_name, SK_FUNC, '', 0, 0);
    LexNext;
    ParseFunctionExpr;
  End
  Else
  Begin
    global_sym := 0;
    ParseError('BE ou = attendu apres declaration LET globale');
  End;

  If global_sym <> 0 Then
  Begin
    sym_table[global_sym].param_cnt := parse_routine_params;
    sym_table[global_sym].local_size := parse_local_offset;
    If parse_routine_params > parse_max_params Then
      parse_max_params := parse_routine_params;
  End;

  parse_owner := saved_owner;
End;

Function ParseProgramBlocks(Var ctx : TCompilerContext) : Boolean;
Begin
  ParseProgramBlocks := False;
  If Not LexOpenSource(ctx.source_name) Then
  Begin
    Inc(ctx.errors);
    Exit;
  End;

  parse_errors := 0;
  parse_blocks := 0;
  parse_procs := 0;
  parse_funcs := 0;
  parse_params := 0;
  parse_locals := 0;
  parse_exprs := 0;
  parse_comps := 0;
  parse_conds := 0;
  parse_valofs := 0;
  parse_resultis := 0;
  parse_valof_depth := 0;
  parse_assigns := 0;
  parse_controls := 0;
  parse_loops := 0;
  parse_breaks := 0;
  parse_loop_depth := 0;
  parse_switches := 0;
  parse_cases := 0;
  parse_defaults := 0;
  parse_endcases := 0;
  parse_switch_depth := 0;
  parse_runtime_refs := 0;
  parse_static := 0;
  parse_owner := '';
  parse_param_offset := ABI_PARAM_BASE;
  parse_local_offset := 0;
  parse_param_bytes := 0;
  parse_local_bytes := 0;
  parse_param_index := 0;
  parse_routine_params := 0;
  parse_max_params := 0;
  sym_count := 0;
  LexNext;

  While cur_tok.kind <> TK_EOF Do
  Begin
    If cur_tok.val = 'STATIC' Then
      ParseStaticBlock
    Else If cur_tok.val = 'LET' Then
      ParseGlobalLet
    Else If cur_tok.val = '$(' Then
      ParseBlock
    Else If cur_tok.val = '$)' Then
    Begin
      ParseError('fin de bloc inattendue: $)');
      LexNext;
    End
    Else
      LexNext;
  End;

  LexCloseSource;
  ctx.block_count := parse_blocks;
  ctx.proc_count := parse_procs;
  ctx.func_count := parse_funcs;
  ctx.param_count := parse_params;
  ctx.local_count := parse_locals;
  ctx.expr_count := parse_exprs;
  ctx.comp_count := parse_comps;
  ctx.cond_count := parse_conds;
  ctx.valof_count := parse_valofs;
  ctx.resultis_count := parse_resultis;
  ctx.assign_count := parse_assigns;
  ctx.control_count := parse_controls;
  ctx.loop_count := parse_loops;
  ctx.break_count := parse_breaks;
  ctx.switch_count := parse_switches;
  ctx.case_count := parse_cases;
  ctx.default_count := parse_defaults;
  ctx.endcase_count := parse_endcases;
  ctx.runtime_count := parse_runtime_refs;
  ctx.static_count := parse_static;
  ctx.sym_count := sym_count;
  ctx.abi_param_bytes := parse_param_bytes;
  ctx.abi_local_bytes := parse_local_bytes;
  ctx.max_param_count := parse_max_params;
  Inc(ctx.errors, parse_errors);
  ParseProgramBlocks := parse_errors = 0;
End;

Function AsmGlobalName(Const name : TString) : TString;
Begin
  AsmGlobalName := '_' + name;
End;

Function FindGlobalRoutine(Const name : TString) : Integer;
Var
  i : Integer;
Begin
  For i := 1 To sym_count Do
    If ((sym_table[i].kind = SK_PROC) Or (sym_table[i].kind = SK_FUNC)) And
       (sym_table[i].owner = '') And (sym_table[i].name = name) Then
    Begin
      FindGlobalRoutine := i;
      Exit;
    End;
  FindGlobalRoutine := 0;
End;

Procedure EmitAsmRuntimeData(Var f : Text);
Begin
  WriteLn(f, '.DATA');
  WriteLn(f, '_BCPL_stdout DD 0');
  WriteLn(f, '_BCPL_written DD 0');
  WriteLn(f, '_BCPL_chbuf DB 0');
  WriteLn(f, '_BCPL_crlf DB 13,10');
  WriteLn(f, '_BCPL_num_buf DB 16 DUP(0)');
  WriteLn(f);
End;

Procedure EmitAsmRuntimeCode(Var f : Text);
Begin
  WriteLn(f);
  WriteLn(f, '; Runtime BCPL Win32 console');
  WriteLn(f, 'PUBLIC _BCPL_runtime_init');
  WriteLn(f, 'PUBLIC _WRITES, _WRITEN, _WRITECH, _NEWLINE, _FINISH');

  WriteLn(f, '_BCPL_runtime_init PROC');
  WriteLn(f, '  PUSH -11');
  WriteLn(f, '  CALL GetStdHandle');
  WriteLn(f, '  MOV DWORD PTR [_BCPL_stdout], EAX');
  WriteLn(f, '  RET');
  WriteLn(f, '_BCPL_runtime_init ENDP');

  WriteLn(f);
  WriteLn(f, '_WRITES PROC');
  WriteLn(f, '  PUSH EBP');
  WriteLn(f, '  MOV EBP, ESP');
  WriteLn(f, '  PUSH ESI');
  WriteLn(f, '  MOV ESI, DWORD PTR [EBP+8]');
  WriteLn(f, '  XOR ECX, ECX');
  WriteLn(f, '@@writes_len:');
  WriteLn(f, '  CMP BYTE PTR [ESI+ECX], 0');
  WriteLn(f, '  JE @@writes_emit');
  WriteLn(f, '  INC ECX');
  WriteLn(f, '  JMP @@writes_len');
  WriteLn(f, '@@writes_emit:');
  WriteLn(f, '  PUSH 0');
  WriteLn(f, '  PUSH OFFSET _BCPL_written');
  WriteLn(f, '  PUSH ECX');
  WriteLn(f, '  PUSH ESI');
  WriteLn(f, '  PUSH DWORD PTR [_BCPL_stdout]');
  WriteLn(f, '  CALL WriteFile');
  WriteLn(f, '  POP ESI');
  WriteLn(f, '  MOV ESP, EBP');
  WriteLn(f, '  POP EBP');
  WriteLn(f, '  RET');
  WriteLn(f, '_WRITES ENDP');

  WriteLn(f);
  WriteLn(f, '_WRITECH PROC');
  WriteLn(f, '  PUSH EBP');
  WriteLn(f, '  MOV EBP, ESP');
  WriteLn(f, '  MOV AL, BYTE PTR [EBP+8]');
  WriteLn(f, '  MOV BYTE PTR [_BCPL_chbuf], AL');
  WriteLn(f, '  PUSH 0');
  WriteLn(f, '  PUSH OFFSET _BCPL_written');
  WriteLn(f, '  PUSH 1');
  WriteLn(f, '  PUSH OFFSET _BCPL_chbuf');
  WriteLn(f, '  PUSH DWORD PTR [_BCPL_stdout]');
  WriteLn(f, '  CALL WriteFile');
  WriteLn(f, '  MOV ESP, EBP');
  WriteLn(f, '  POP EBP');
  WriteLn(f, '  RET');
  WriteLn(f, '_WRITECH ENDP');

  WriteLn(f);
  WriteLn(f, '_NEWLINE PROC');
  WriteLn(f, '  PUSH 0');
  WriteLn(f, '  PUSH OFFSET _BCPL_written');
  WriteLn(f, '  PUSH 2');
  WriteLn(f, '  PUSH OFFSET _BCPL_crlf');
  WriteLn(f, '  PUSH DWORD PTR [_BCPL_stdout]');
  WriteLn(f, '  CALL WriteFile');
  WriteLn(f, '  RET');
  WriteLn(f, '_NEWLINE ENDP');

  WriteLn(f);
  WriteLn(f, '_WRITEN PROC');
  WriteLn(f, '  PUSH EBP');
  WriteLn(f, '  MOV EBP, ESP');
  WriteLn(f, '  PUSH EBX');
  WriteLn(f, '  PUSH ESI');
  WriteLn(f, '  MOV EAX, DWORD PTR [EBP+8]');
  WriteLn(f, '  LEA ESI, _BCPL_num_buf+15');
  WriteLn(f, '  MOV BYTE PTR [ESI], 0');
  WriteLn(f, '  MOV EBX, 10');
  WriteLn(f, '  XOR ECX, ECX');
  WriteLn(f, '  CMP EAX, 0');
  WriteLn(f, '  JGE @@writen_loop');
  WriteLn(f, '  NEG EAX');
  WriteLn(f, '  MOV CL, 1');
  WriteLn(f, '  JMP @@writen_loop');
  WriteLn(f, '@@writen_loop:');
  WriteLn(f, '  XOR EDX, EDX');
  WriteLn(f, '  DIV EBX');
  WriteLn(f, '  ADD DL, ''0''');
  WriteLn(f, '  DEC ESI');
  WriteLn(f, '  MOV BYTE PTR [ESI], DL');
  WriteLn(f, '  TEST EAX, EAX');
  WriteLn(f, '  JNZ @@writen_loop');
  WriteLn(f, '  CMP CL, 1');
  WriteLn(f, '  JNE @@writen_out');
  WriteLn(f, '  DEC ESI');
  WriteLn(f, '  MOV BYTE PTR [ESI], ''-''');
  WriteLn(f, '@@writen_out:');
  WriteLn(f, '  PUSH ESI');
  WriteLn(f, '  CALL _WRITES');
  WriteLn(f, '  ADD ESP, 4');
  WriteLn(f, '  POP ESI');
  WriteLn(f, '  POP EBX');
  WriteLn(f, '  MOV ESP, EBP');
  WriteLn(f, '  POP EBP');
  WriteLn(f, '  RET');
  WriteLn(f, '_WRITEN ENDP');

  WriteLn(f);
  WriteLn(f, '_FINISH PROC');
  WriteLn(f, '  PUSH 0');
  WriteLn(f, '  CALL ExitProcess');
  WriteLn(f, '_FINISH ENDP');
End;

Procedure EmitAsmRoutine(Var f : Text; idx : Integer);
Var
  frame_size : LongInt;
  asm_name   : TString;
Begin
  frame_size := sym_table[idx].local_size + ABI_WORD_SIZE;
  asm_name := AsmGlobalName(sym_table[idx].name);

  WriteLn(f);
  WriteLn(f, '; ', SymKindName(sym_table[idx].kind), ' ', sym_table[idx].name,
             ' params=', sym_table[idx].param_cnt,
             ' locals=', sym_table[idx].local_size);
  WriteLn(f, 'PUBLIC ', asm_name);
  WriteLn(f, asm_name, ' PROC');
  WriteLn(f, '  PUSH ', ABI_FRAME_REG);
  WriteLn(f, '  MOV ', ABI_FRAME_REG, ', ', ABI_STACK_REG);
  If frame_size > 0 Then
    WriteLn(f, '  SUB ', ABI_STACK_REG, ', ', LongToStr(frame_size));
  WriteLn(f, '  MOV DWORD PTR [', ABI_FRAME_REG, '-', LongToStr(frame_size), '], EBX');
  WriteLn(f, '  ; parametre 1: [', ABI_FRAME_REG, '+', ABI_PARAM_BASE, ']');
  WriteLn(f, '  ; retour entier attendu dans ', ABI_RET_REG);
  If sym_table[idx].name = 'START' Then
    WriteLn(f, '  CALL _BCPL_runtime_init');
  WriteLn(f, '  XOR ', ABI_RET_REG, ', ', ABI_RET_REG);
  WriteLn(f, '@@', sym_table[idx].name, '_return:');
  WriteLn(f, '  MOV EBX, DWORD PTR [', ABI_FRAME_REG, '-', LongToStr(frame_size), ']');
  WriteLn(f, '  MOV ', ABI_STACK_REG, ', ', ABI_FRAME_REG);
  WriteLn(f, '  POP ', ABI_FRAME_REG);
  WriteLn(f, '  RET');
  WriteLn(f, asm_name, ' ENDP');
End;

Function EmitAsm386File(Var ctx : TCompilerContext) : Boolean;
Var
  f          : Text;
  code       : Integer;
  i          : Integer;
  entry_idx  : Integer;
  entry_name : TString;
Begin
  EmitAsm386File := False;

  If Not ctx.options.keep_asm Then
  Begin
    EmitAsm386File := True;
    Exit;
  End;

  Assign(f, ctx.asm_name);
  Rewrite(f);
  code := IOResult;
  If code <> 0 Then
  Begin
    WriteLn('Erreur: impossible de creer ', ctx.asm_name);
    Inc(ctx.errors);
    Exit;
  End;

  entry_idx := FindGlobalRoutine('START');
  If entry_idx <> 0 Then
    entry_name := AsmGlobalName(sym_table[entry_idx].name)
  Else
    entry_name := '';

  WriteLn(f, '; Fichier genere par BCPLCW32 ', BCPLCW32_VERSION);
  WriteLn(f, '; Source : ', ctx.source_name);
  WriteLn(f, '; Cible  : MASM 80386 / Win32');
  WriteLn(f);
  WriteLn(f, '.386');
  WriteLn(f, '.MODEL FLAT, C');
  WriteLn(f, 'OPTION CASEMAP:NONE');
  WriteLn(f);
  WriteLn(f, 'ExitProcess PROTO STDCALL :DWORD');
  WriteLn(f, 'GetStdHandle PROTO STDCALL :DWORD');
  WriteLn(f, 'WriteFile PROTO STDCALL :DWORD,:DWORD,:DWORD,:DWORD,:DWORD');
  WriteLn(f, 'INCLUDELIB kernel32.lib');
  WriteLn(f);
  EmitAsmRuntimeData(f);
  WriteLn(f, '.CODE');
  EmitAsmRuntimeCode(f);

  For i := 1 To sym_count Do
    If (sym_table[i].owner = '') And
       ((sym_table[i].kind = SK_PROC) Or (sym_table[i].kind = SK_FUNC)) Then
      EmitAsmRoutine(f, i);

  WriteLn(f);
  If entry_name <> '' Then
    WriteLn(f, 'END ', entry_name)
  Else
    WriteLn(f, 'END');
  Close(f);
  EmitAsm386File := True;
End;

Function AlignUp(v, a : LongInt) : LongInt;
Begin
  If a <= 0 Then
    AlignUp := v
  Else
    AlignUp := ((v + a - 1) Div a) * a;
End;

Procedure BinWriteByte(Var f : File; v : LongInt);
Var
  b : Byte;
Begin
  b := v And $FF;
  BlockWrite(f, b, 1);
End;

Procedure BinWriteWord(Var f : File; v : LongInt);
Begin
  BinWriteByte(f, v);
  BinWriteByte(f, v Shr 8);
End;

Procedure BinWriteDWord(Var f : File; v : LongInt);
Begin
  BinWriteByte(f, v);
  BinWriteByte(f, v Shr 8);
  BinWriteByte(f, v Shr 16);
  BinWriteByte(f, v Shr 24);
End;

Procedure BinWriteZeros(Var f : File; count : LongInt);
Var
  i : LongInt;
Begin
  For i := 1 To count Do
    BinWriteByte(f, 0);
End;

Procedure BinWriteName8(Var f : File; Const name : TString);
Var
  i : Integer;
Begin
  For i := 1 To 8 Do
    If i <= Length(name) Then
      BinWriteByte(f, Ord(name[i]))
    Else
      BinWriteByte(f, 0);
End;

Procedure BinWriteCString(Var f : File; Const s : TString);
Var
  i : Integer;
Begin
  For i := 1 To Length(s) Do
    BinWriteByte(f, Ord(s[i]));
  BinWriteByte(f, 0);
End;

Procedure BinPadTo(Var f : File; target_pos : LongInt);
Begin
  While FilePos(f) < target_pos Do
    BinWriteByte(f, 0);
End;

Procedure WriteCoffSectionHeader(Var f : File; Const name : TString;
                                 raw_size, raw_ptr, rel_ptr : LongInt;
                                 rel_count : Integer; flags : LongInt);
Begin
  BinWriteName8(f, name);
  BinWriteDWord(f, 0);
  BinWriteDWord(f, 0);
  BinWriteDWord(f, raw_size);
  BinWriteDWord(f, raw_ptr);
  BinWriteDWord(f, rel_ptr);
  BinWriteDWord(f, 0);
  BinWriteWord(f, rel_count);
  BinWriteWord(f, 0);
  BinWriteDWord(f, flags);
End;

Procedure WriteCoffSymbol(Var f : File; Const name : TString;
                          value : LongInt; section_no, storage_class : Integer);
Begin
  BinWriteName8(f, name);
  BinWriteDWord(f, value);
  BinWriteWord(f, section_no);
  BinWriteWord(f, 0);
  BinWriteByte(f, storage_class);
  BinWriteByte(f, 0);
End;

Function EmitCoffObjFile(Var ctx : TCompilerContext) : Boolean;
Const
  TEXT_SIZE = 3;
  TEXT_RAW  = 60;
  SYM_PTR   = 64;
Var
  f    : File;
  code : Integer;
Begin
  EmitCoffObjFile := False;
  Assign(f, ctx.obj_name);
  Rewrite(f, 1);
  code := IOResult;
  If code <> 0 Then
  Begin
    WriteLn('Erreur: impossible de creer ', ctx.obj_name);
    Inc(ctx.errors);
    Exit;
  End;

  BinWriteWord(f, PE_MACHINE_I386);
  BinWriteWord(f, 1);
  BinWriteDWord(f, 0);
  BinWriteDWord(f, SYM_PTR);
  BinWriteDWord(f, 2);
  BinWriteWord(f, 0);
  BinWriteWord(f, 0);
  WriteCoffSectionHeader(f, '.text', 4, TEXT_RAW, 0, 0, PE_SCN_TEXT);

  BinWriteByte(f, $31); { XOR EAX,EAX }
  BinWriteByte(f, $C0);
  BinWriteByte(f, $C3); { RET }
  BinWriteByte(f, 0);

  WriteCoffSymbol(f, '.text', 0, 1, COFF_SYM_STATIC);
  WriteCoffSymbol(f, '_START', 0, 1, COFF_SYM_EXTERNAL);
  BinWriteDWord(f, 4);
  Close(f);
  EmitCoffObjFile := True;
End;

Procedure BinOutputAdd(Const text : TString);
Begin
  If text = '' Then
    Exit;
  If bin_output_count >= MAX_BIN_OUTPUT Then
  Begin
    ParseError('trop de sorties runtime statiques');
    Exit;
  End;
  Inc(bin_output_count);
  bin_outputs[bin_output_count] := text;
End;

Procedure CollectStaticRuntimeOutputs(Var ctx : TCompilerContext);
Var
  name : TString;
Begin
  bin_output_count := 0;
  If Not LexOpenSource(ctx.source_name) Then
    Exit;

  LexNext;
  While cur_tok.kind <> TK_EOF Do
  Begin
    If IsRuntimeRoutine(cur_tok.val) Then
    Begin
      name := cur_tok.val;
      LexNext;
      If cur_tok.val = '(' Then
      Begin
        LexNext;
        If (name = 'WRITES') And (cur_tok.kind = TK_STRING) Then
          BinOutputAdd(cur_tok.val)
        Else If (name = 'NEWLINE') Then
          BinOutputAdd(#13#10)
        Else If (name = 'WRITECH') And (cur_tok.kind = TK_INTEGER) Then
          BinOutputAdd(Chr(cur_tok.int_val And $FF))
        Else If (name = 'WRITEN') And (cur_tok.kind = TK_INTEGER) Then
          BinOutputAdd(LongToStr(cur_tok.int_val));
      End
      Else If name = 'FINISH' Then
        Break;
    End
    Else
      LexNext;
  End;

  LexCloseSource;
End;

Procedure WritePeSectionHeader(Var f : File; Const name : TString;
                               virt_size, virt_addr, raw_size,
                               raw_ptr, flags : LongInt);
Begin
  BinWriteName8(f, name);
  BinWriteDWord(f, virt_size);
  BinWriteDWord(f, virt_addr);
  BinWriteDWord(f, raw_size);
  BinWriteDWord(f, raw_ptr);
  BinWriteDWord(f, 0);
  BinWriteDWord(f, 0);
  BinWriteWord(f, 0);
  BinWriteWord(f, 0);
  BinWriteDWord(f, flags);
End;

Function EmitPeExeFile(Var ctx : TCompilerContext) : Boolean;
Const
  TEXT_RVA  = $1000;
  RDATA_RVA = $2000;
  HDR_SIZE  = $0200;
  TEXT_RAW  = $0200;
  RDATA_RAW = $0400;
Var
  f          : File;
  code       : Integer;
  desc_off   : LongInt;
  ilt_off    : LongInt;
  iat_off    : LongInt;
  hint_exit  : LongInt;
  hint_get   : LongInt;
  hint_write : LongInt;
  dll_off    : LongInt;
  import_sz  : LongInt;
  text_sz    : LongInt;
  text_rawsz : LongInt;
  rdata_rawsz: LongInt;
  i          : Integer;
  str_off    : Array[1..MAX_BIN_OUTPUT] Of LongInt;
  rpos       : LongInt;
  iat_exit_va: LongInt;
  iat_get_va : LongInt;
  iat_write_va: LongInt;

  Procedure CodePushImm(v : LongInt);
  Begin
    BinWriteByte(f, $68);
    BinWriteDWord(f, v);
  End;

  Procedure CodeCallIat(va : LongInt);
  Begin
    BinWriteByte(f, $FF);
    BinWriteByte(f, $15);
    BinWriteDWord(f, va);
  End;

  Procedure RDataWriteOutput(Const s : TString);
  Var
    k : Integer;
  Begin
    For k := 1 To Length(s) Do
      BinWriteByte(f, Ord(s[k]));
  End;
Begin
  EmitPeExeFile := False;
  CollectStaticRuntimeOutputs(ctx);

  rpos := 0;
  For i := 1 To bin_output_count Do
  Begin
    str_off[i] := rpos;
    Inc(rpos, Length(bin_outputs[i]));
  End;

  desc_off := rpos;
  ilt_off := desc_off + 40;
  iat_off := ilt_off + 16;
  hint_exit := iat_off + 16;
  hint_get := hint_exit + 2 + Length('ExitProcess') + 1;
  hint_write := hint_get + 2 + Length('GetStdHandle') + 1;
  dll_off := hint_write + 2 + Length('WriteFile') + 1;
  import_sz := dll_off + Length('KERNEL32.DLL') + 1;

  text_sz := 27 + bin_output_count * 23;
  text_rawsz := AlignUp(text_sz, PE_FILE_ALIGN);
  rdata_rawsz := AlignUp(import_sz, PE_FILE_ALIGN);
  iat_exit_va := PE_IMAGE_BASE + RDATA_RVA + iat_off;
  iat_get_va := iat_exit_va + 4;
  iat_write_va := iat_exit_va + 8;

  Assign(f, ctx.exe_name);
  Rewrite(f, 1);
  code := IOResult;
  If code <> 0 Then
  Begin
    WriteLn('Erreur: impossible de creer ', ctx.exe_name);
    Inc(ctx.errors);
    Exit;
  End;

  { DOS header minimal, e_lfanew = 128 }
  BinWriteWord(f, $5A4D);
  For i := 1 To 29 Do
    BinWriteWord(f, 0);
  BinWriteDWord(f, 128);
  BinPadTo(f, 128);

  BinWriteByte(f, Ord('P'));
  BinWriteByte(f, Ord('E'));
  BinWriteByte(f, 0);
  BinWriteByte(f, 0);

  BinWriteWord(f, PE_MACHINE_I386);
  BinWriteWord(f, 2);
  BinWriteDWord(f, 0);
  BinWriteDWord(f, 0);
  BinWriteDWord(f, 0);
  BinWriteWord(f, PE_OPT_SIZE);
  BinWriteWord(f, $0103);

  BinWriteWord(f, PE_MAGIC_32);
  BinWriteByte(f, 1);
  BinWriteByte(f, 0);
  BinWriteDWord(f, text_rawsz);
  BinWriteDWord(f, rdata_rawsz);
  BinWriteDWord(f, 0);
  BinWriteDWord(f, TEXT_RVA);
  BinWriteDWord(f, TEXT_RVA);
  BinWriteDWord(f, RDATA_RVA);
  BinWriteDWord(f, PE_IMAGE_BASE);
  BinWriteDWord(f, PE_SEC_ALIGN);
  BinWriteDWord(f, PE_FILE_ALIGN);
  BinWriteWord(f, 4);
  BinWriteWord(f, 0);
  BinWriteWord(f, 0);
  BinWriteWord(f, 0);
  BinWriteWord(f, 4);
  BinWriteWord(f, 0);
  BinWriteDWord(f, 0);
  BinWriteDWord(f, RDATA_RVA + PE_SEC_ALIGN);
  BinWriteDWord(f, HDR_SIZE);
  BinWriteDWord(f, 0);
  BinWriteWord(f, PE_SUBSYS_CUI);
  BinWriteWord(f, 0);
  BinWriteDWord(f, $00100000);
  BinWriteDWord(f, $00001000);
  BinWriteDWord(f, $00100000);
  BinWriteDWord(f, $00001000);
  BinWriteDWord(f, 0);
  BinWriteDWord(f, 16);

  BinWriteDWord(f, 0); BinWriteDWord(f, 0);
  BinWriteDWord(f, RDATA_RVA + desc_off); BinWriteDWord(f, import_sz - desc_off);
  BinWriteDWord(f, 0); BinWriteDWord(f, 0);
  BinWriteDWord(f, 0); BinWriteDWord(f, 0);
  BinWriteDWord(f, 0); BinWriteDWord(f, 0);
  BinWriteDWord(f, 0); BinWriteDWord(f, 0);
  BinWriteDWord(f, 0); BinWriteDWord(f, 0);
  BinWriteDWord(f, 0); BinWriteDWord(f, 0);
  BinWriteDWord(f, 0); BinWriteDWord(f, 0);
  BinWriteDWord(f, 0); BinWriteDWord(f, 0);
  BinWriteDWord(f, 0); BinWriteDWord(f, 0);
  BinWriteDWord(f, 0); BinWriteDWord(f, 0);
  BinWriteDWord(f, RDATA_RVA + iat_off); BinWriteDWord(f, 16);
  BinWriteDWord(f, 0); BinWriteDWord(f, 0);
  BinWriteDWord(f, 0); BinWriteDWord(f, 0);
  BinWriteDWord(f, 0); BinWriteDWord(f, 0);

  WritePeSectionHeader(f, '.text', text_sz, TEXT_RVA, text_rawsz,
                       TEXT_RAW, PE_SCN_TEXT);
  WritePeSectionHeader(f, '.rdata', import_sz, RDATA_RVA, rdata_rawsz,
                       RDATA_RAW, PE_SCN_RDATA);
  BinPadTo(f, HDR_SIZE);

  BinWriteByte(f, $55);                   { PUSH EBP }
  BinWriteByte(f, $8B); BinWriteByte(f, $EC); { MOV EBP,ESP }
  BinWriteByte(f, $83); BinWriteByte(f, $EC); BinWriteByte(f, $04); { SUB ESP,4 }
  CodePushImm(-11);
  CodeCallIat(iat_get_va);
  BinWriteByte(f, $8B); BinWriteByte(f, $D8); { MOV EBX,EAX }

  For i := 1 To bin_output_count Do
  Begin
    If Length(bin_outputs[i]) > 0 Then
    Begin
      BinWriteByte(f, $6A); BinWriteByte(f, $00); { PUSH 0 }
      BinWriteByte(f, $8D); BinWriteByte(f, $45); BinWriteByte(f, $FC); { LEA EAX,[EBP-4] }
      BinWriteByte(f, $50); { PUSH EAX }
      CodePushImm(Length(bin_outputs[i]));
      CodePushImm(PE_IMAGE_BASE + RDATA_RVA + str_off[i]);
      BinWriteByte(f, $53); { PUSH EBX }
      CodeCallIat(iat_write_va);
    End;
  End;

  BinWriteByte(f, $6A); BinWriteByte(f, $00); { PUSH 0 }
  CodeCallIat(iat_exit_va);
  BinPadTo(f, RDATA_RAW);

  For i := 1 To bin_output_count Do
    RDataWriteOutput(bin_outputs[i]);

  BinWriteDWord(f, RDATA_RVA + ilt_off);
  BinWriteDWord(f, 0);
  BinWriteDWord(f, 0);
  BinWriteDWord(f, RDATA_RVA + dll_off);
  BinWriteDWord(f, RDATA_RVA + iat_off);
  For i := 1 To 5 Do
    BinWriteDWord(f, 0);
  BinWriteDWord(f, RDATA_RVA + hint_exit);
  BinWriteDWord(f, RDATA_RVA + hint_get);
  BinWriteDWord(f, RDATA_RVA + hint_write);
  BinWriteDWord(f, 0);
  BinWriteDWord(f, RDATA_RVA + hint_exit);
  BinWriteDWord(f, RDATA_RVA + hint_get);
  BinWriteDWord(f, RDATA_RVA + hint_write);
  BinWriteDWord(f, 0);
  BinWriteWord(f, 0);
  BinWriteCString(f, 'ExitProcess');
  BinWriteWord(f, 0);
  BinWriteCString(f, 'GetStdHandle');
  BinWriteWord(f, 0);
  BinWriteCString(f, 'WriteFile');
  BinWriteCString(f, 'KERNEL32.DLL');
  BinPadTo(f, RDATA_RAW + rdata_rawsz);

  Close(f);
  EmitPeExeFile := True;
End;

Procedure InitDefaultOptions(Var options : TPipelineOptions);
Begin
  options.output_mode := OM_EXE;
  options.keep_asm    := False;
  options.verbose     := True;
  options.test_mode   := False;
  options.output_name := '';
End;

Procedure ShowUsage; Forward;
Procedure UsageError(Const msg : TString); Forward;

Procedure DeriveOutputNames(Var ctx : TCompilerContext);
Var
  main_out : TString;
  ext      : TString;
Begin
  If ctx.options.output_name <> '' Then
    main_out := ctx.options.output_name
  Else If ctx.options.output_mode = OM_OBJ Then
    main_out := ChangeExtension(ctx.source_name, '.obj')
  Else
    main_out := ChangeExtension(ctx.source_name, '.exe');

  ext := FileExtension(main_out);
  If ctx.options.output_mode = OM_OBJ Then
  Begin
    If ext = '' Then
      main_out := main_out + '.obj'
    Else If ext <> '.OBJ' Then
      UsageError('avec -obj, la sortie principale doit etre un fichier .OBJ: ' + main_out);
  End
  Else
  Begin
    If ext = '' Then
      main_out := main_out + '.exe'
    Else If ext <> '.EXE' Then
      UsageError('par defaut, la sortie principale doit etre un fichier .EXE: ' + main_out);
  End;

  If ctx.options.output_mode = OM_OBJ Then
  Begin
    ctx.obj_name := main_out;
    ctx.exe_name := '';
    ctx.asm_name := ChangeExtension(main_out, '.asm');
  End
  Else
  Begin
    ctx.exe_name := main_out;
    ctx.obj_name := ChangeExtension(main_out, '.obj');
    ctx.asm_name := ChangeExtension(main_out, '.asm');
  End;
End;

Procedure InitCompilerContext(Var ctx : TCompilerContext);
Begin
  ctx.source_name := '';
  ctx.asm_name    := '';
  ctx.obj_name    := '';
  ctx.exe_name    := '';
  InitDefaultOptions(ctx.options);
  ctx.last_art    := AK_NONE;
  ctx.token_count := 0;
  ctx.block_count := 0;
  ctx.proc_count  := 0;
  ctx.func_count  := 0;
  ctx.param_count := 0;
  ctx.local_count := 0;
  ctx.expr_count  := 0;
  ctx.comp_count  := 0;
  ctx.cond_count  := 0;
  ctx.valof_count := 0;
  ctx.resultis_count := 0;
  ctx.assign_count:= 0;
  ctx.control_count:= 0;
  ctx.loop_count  := 0;
  ctx.break_count := 0;
  ctx.switch_count:= 0;
  ctx.case_count  := 0;
  ctx.default_count := 0;
  ctx.endcase_count := 0;
  ctx.runtime_count := 0;
  ctx.static_count:= 0;
  ctx.sym_count   := 0;
  ctx.abi_param_bytes := 0;
  ctx.abi_local_bytes := 0;
  ctx.max_param_count := 0;
  ctx.errors      := 0;
End;

Procedure UsageError(Const msg : TString);
Begin
  WriteLn('Erreur: ', msg);
  WriteLn;
  ShowUsage;
  Halt(EXIT_USAGE);
End;

Procedure ValidateFileConventions(Var ctx : TCompilerContext);
Var
  src_ext : TString;
Begin
  src_ext := FileExtension(ctx.source_name);
  If src_ext = '' Then
    UsageError('le fichier source doit porter l''extension .b: ' + ctx.source_name);
  If src_ext <> '.B' Then
    UsageError('extension source invalide, .b attendu: ' + ctx.source_name);

  DeriveOutputNames(ctx);
End;

Procedure ParseCommandLine(Var ctx : TCompilerContext);
Var
  i   : Integer;
  arg : TString;
Begin
  If ParamCount < 1 Then
  Begin
    ShowUsage;
    Halt(EXIT_USAGE);
  End;

  If SameText(ParamStr(1), '-test') Or SameText(ParamStr(1), '/test') Then
  Begin
    ctx.options.test_mode := True;
    ctx.options.verbose := False;
    Exit;
  End;

  i := 1;
  While i <= ParamCount Do
  Begin
    arg := ParamStr(i);

    If SameText(arg, '-h') Or SameText(arg, '--help') Or
       SameText(arg, '/?') Or SameText(arg, '/h') Then
    Begin
      ShowUsage;
      Halt(EXIT_OK);
    End
    Else If SameText(arg, '-obj') Or SameText(arg, '/obj') Then
      ctx.options.output_mode := OM_OBJ
    Else If SameText(arg, '-asm') Or SameText(arg, '/asm') Then
      ctx.options.keep_asm := True
    Else If SameText(arg, '-v') Or SameText(arg, '/v') Then
      ctx.options.verbose := True
    Else If SameText(arg, '-q') Or SameText(arg, '/q') Then
      ctx.options.verbose := False
    Else If SameText(arg, '-test') Or SameText(arg, '/test') Then
      ctx.options.test_mode := True
    Else If SameText(arg, '-o') Or SameText(arg, '/o') Then
    Begin
      Inc(i);
      If i > ParamCount Then
        UsageError('option -o sans nom de fichier');
      If ctx.options.output_name <> '' Then
        UsageError('nom de sortie deja specifie: ' + ctx.options.output_name);
      ctx.options.output_name := ParamStr(i);
    End
    Else If (Length(arg) > 0) And ((arg[1] = '-') Or (arg[1] = '/')) Then
      UsageError('option inconnue: ' + arg)
    Else If ctx.source_name = '' Then
      ctx.source_name := arg
    Else If ctx.options.output_name = '' Then
      ctx.options.output_name := arg
    Else
      UsageError('argument inattendu: ' + arg);

    Inc(i);
  End;

  If ctx.options.test_mode Then
    Exit;

  If ctx.source_name = '' Then
    UsageError('aucun fichier source BCPL specifie');

  ValidateFileConventions(ctx);
End;

Procedure TraceStage(Const ctx : TCompilerContext; stage : TCompileStage);
Begin
  If ctx.options.verbose Then
    WriteLn('BCPLCW32: ', StageName(stage));
End;

Function RunStage(Var ctx : TCompilerContext; stage : TCompileStage) : Boolean;
Begin
  TraceStage(ctx, stage);

  Case stage Of
    CS_LOAD_SOURCE:
      Begin
        If Not SourceReadable(ctx.source_name) Then
        Begin
          WriteLn('Erreur: impossible d''ouvrir ', ctx.source_name);
          Inc(ctx.errors);
          RunStage := False;
          Exit;
        End;
        ctx.last_art := AK_SOURCE_BCPL;
      End;
    CS_LEX_TOKENS:
      Begin
        If Not LexScanFile(ctx) Then
        Begin
          RunStage := False;
          Exit;
        End;
        ctx.last_art := AK_TOKEN_STREAM;
      End;
    CS_PARSE_AST  :
      Begin
        If Not ParseProgramBlocks(ctx) Then
        Begin
          RunStage := False;
          Exit;
        End;
        ctx.last_art := AK_AST_IR;
      End;
    CS_EMIT_ASM386:
      Begin
        If Not EmitAsm386File(ctx) Then
        Begin
          RunStage := False;
          Exit;
        End;
        ctx.last_art := AK_ASM_386;
      End;
    CS_BUILD_OBJ  :
      Begin
        If Not EmitCoffObjFile(ctx) Then
        Begin
          RunStage := False;
          Exit;
        End;
        ctx.last_art := AK_OBJ_COFF;
      End;
    CS_LINK_EXE   :
      Begin
        If Not EmitPeExeFile(ctx) Then
        Begin
          RunStage := False;
          Exit;
        End;
        ctx.last_art := AK_EXE_PE32;
      End;
  End;
  RunStage := True;
End;

Function RunCompilerPipeline(Var ctx : TCompilerContext) : Boolean;
Begin
  RunCompilerPipeline := False;

  If Not RunStage(ctx, CS_LOAD_SOURCE) Then Exit;
  If Not RunStage(ctx, CS_LEX_TOKENS) Then Exit;
  If Not RunStage(ctx, CS_PARSE_AST) Then Exit;
  If Not RunStage(ctx, CS_EMIT_ASM386) Then Exit;
  If Not RunStage(ctx, CS_BUILD_OBJ) Then Exit;

  If ctx.options.output_mode = OM_EXE Then
    If Not RunStage(ctx, CS_LINK_EXE) Then Exit;

  RunCompilerPipeline := ctx.errors = 0;
End;

Function FileExistsNZ(Const file_name : TString) : Boolean;
Var
  f  : File;
  sz : LongInt;
Begin
  FileExistsNZ := False;
  Assign(f, file_name);
  Reset(f, 1);
  If IOResult <> 0 Then
    Exit;
  sz := FileSize(f);
  Close(f);
  FileExistsNZ := sz > 0;
End;

Procedure DeleteFileIfExists(Const file_name : TString);
Var
  f : File;
Begin
  Assign(f, file_name);
  Erase(f);
  IOResult;
End;

Procedure TestLine(Const name : TString; ok : Boolean; Var pass, fail : Integer);
Begin
  If ok Then
  Begin
    WriteLn('  [PASS] ', name);
    Inc(pass);
  End
  Else
  Begin
    WriteLn('  [FAIL] ', name);
    Inc(fail);
  End;
End;

Function CompileForTest(Const src_name, out_name : TString;
                        mode : TOutputMode; keep_asm : Boolean;
                        Var ctx : TCompilerContext) : Boolean;
Begin
  InitCompilerContext(ctx);
  ctx.source_name := src_name;
  ctx.options.output_mode := mode;
  ctx.options.keep_asm := keep_asm;
  ctx.options.verbose := False;
  ctx.options.output_name := out_name;
  DeriveOutputNames(ctx);
  If keep_asm Then
    DeleteFileIfExists(ctx.asm_name);
  CompileForTest := RunCompilerPipeline(ctx);
End;

Procedure ValidateSample(Const label_name, src_name : TString;
                         exp_procs, exp_funcs, exp_loops, exp_breaks,
                         exp_switches, exp_cases, exp_defaults,
                         exp_endcases, exp_runtime : LongInt;
                         Var pass, fail : Integer);
Var
  ctx     : TCompilerContext;
  outbase : TString;
  ok      : Boolean;
Begin
  WriteLn('--- ', label_name, ' ---');
  outbase := 'bcplcw32_test_' + label_name;

  ok := CompileForTest(src_name, outbase + '.exe', OM_EXE, False, ctx);
  TestLine(label_name + ' : compile EXE sans erreur', ok And (ctx.errors = 0), pass, fail);
  TestLine(label_name + ' : artefact EXE atteint', ctx.last_art = AK_EXE_PE32, pass, fail);
  TestLine(label_name + ' : fichier EXE produit', FileExistsNZ(ctx.exe_name), pass, fail);
  TestLine(label_name + ' : procedures attendues', ctx.proc_count = exp_procs, pass, fail);
  TestLine(label_name + ' : fonctions attendues', ctx.func_count = exp_funcs, pass, fail);
  TestLine(label_name + ' : boucles attendues', ctx.loop_count = exp_loops, pass, fail);
  TestLine(label_name + ' : BREAK attendus', ctx.break_count = exp_breaks, pass, fail);
  TestLine(label_name + ' : SWITCHON attendus', ctx.switch_count = exp_switches, pass, fail);
  TestLine(label_name + ' : CASE attendus', ctx.case_count = exp_cases, pass, fail);
  TestLine(label_name + ' : DEFAULT attendus', ctx.default_count = exp_defaults, pass, fail);
  TestLine(label_name + ' : ENDCASE attendus', ctx.endcase_count = exp_endcases, pass, fail);
  TestLine(label_name + ' : runtime refs attendues', ctx.runtime_count = exp_runtime, pass, fail);
  DeleteFileIfExists(ctx.exe_name);
  DeleteFileIfExists(ctx.obj_name);

  ok := CompileForTest(src_name, outbase + '.obj', OM_OBJ, False, ctx);
  TestLine(label_name + ' -obj : compile sans erreur', ok And (ctx.errors = 0), pass, fail);
  TestLine(label_name + ' -obj : artefact OBJ atteint', ctx.last_art = AK_OBJ_COFF, pass, fail);
  TestLine(label_name + ' -obj : mode OBJ', ctx.options.output_mode = OM_OBJ, pass, fail);
  TestLine(label_name + ' -obj : fichier OBJ produit', FileExistsNZ(ctx.obj_name), pass, fail);
  DeleteFileIfExists(ctx.obj_name);

  ok := CompileForTest(src_name, outbase + '.exe', OM_EXE, True, ctx);
  TestLine(label_name + ' -asm : compile sans erreur', ok And (ctx.errors = 0), pass, fail);
  TestLine(label_name + ' -asm : ASM produit', FileExistsNZ(ctx.asm_name), pass, fail);
  DeleteFileIfExists(ctx.asm_name);
  DeleteFileIfExists(ctx.exe_name);
  DeleteFileIfExists(ctx.obj_name);
  WriteLn;
End;

Procedure RunTests;
Const
  BASE_DIR = 'SAMPLES\BCPL\';
Var
  pass : Integer;
  fail : Integer;
Begin
  pass := 0;
  fail := 0;
  WriteLn('=== BCPLCW32 -test : validation SAMPLES\BCPL\ ===');
  WriteLn('Note: le backend binaire produit un EXE PE32 minimal executable;');
  WriteLn('      la generation complete du code BCPL reste a enrichir.');
  WriteLn;

  ValidateSample('hello', BASE_DIR + 'hello.b',
                 1, 0, 0, 0, 0, 0, 0, 0, 13, pass, fail);
  ValidateSample('fib', BASE_DIR + 'fib.b',
                 2, 2, 4, 0, 0, 0, 0, 0, 17, pass, fail);
  ValidateSample('func', BASE_DIR + 'func.b',
                 3, 5, 6, 0, 0, 0, 0, 0, 36, pass, fail);
  ValidateSample('loops', BASE_DIR + 'loops.b',
                 2, 0, 7, 1, 0, 0, 0, 0, 31, pass, fail);
  ValidateSample('switchon', BASE_DIR + 'switchon.b',
                 6, 0, 2, 0, 3, 22, 3, 15, 42, pass, fail);

  WriteLn('=== Bilan : ', pass, ' pass / ', fail, ' fail ===');
  If fail > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End;

Procedure ShowUsage;
Begin
  WriteLn('BCPLCW32 ', BCPLCW32_VERSION, ' - Cette commande permet de lancer le compilateur BCPL vers l''assembleur du ',
          'microprocesseur 80386 pour Windows 32 bits (Win32 PE).');
  WriteLn;
  WriteLn('Syntaxe: BCPLCW32 fichier.b [sortie] [options]');
  WriteLn;
  WriteLn('Options de sortie:');
  WriteLn('  -obj           Produire seulement un fichier .OBJ COFF');
  WriteLn('  -asm           Produire/conserver explicitement un fichier .ASM lisible');
  WriteLn('  -o <fichier>   Nom de la sortie principale (.EXE par defaut, .OBJ avec -obj)');
  WriteLn('                 Sans extension, .EXE ou .OBJ est ajoute selon le mode');
  WriteLn;
  WriteLn('Options generales:');
  WriteLn('  -v             Mode verbeux');
  WriteLn('  -q             Mode silencieux');
  WriteLn('  -test          Compiler/valider automatiquement SAMPLES\BCPL\*');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Pipeline defini: .b -> tokens -> AST/IR -> .asm 80386 -> .obj COFF -> .exe PE32');
  WriteLn;
  WriteLn('Exemples:');
  WriteLn('  BCPLCW32 SAMPLES\BCPL\hello.b');
  WriteLn('  BCPLCW32 SAMPLES\BCPL\hello.b -asm');
  WriteLn('  BCPLCW32 SAMPLES\BCPL\hello.b -obj -o hello.obj');
  WriteLn('  BCPLCW32 -test');
End;

Var
  ctx : TCompilerContext;

 BEGIN
  InitCompilerContext(ctx);
  ParseCommandLine(ctx);
  If ctx.options.test_mode Then
    RunTests;

  If RunCompilerPipeline(ctx) Then
  Begin
    WriteLn('Pipeline defini jusqu''a: ', ArtifactName(ctx.last_art));
    WriteLn('Mode  : ', OutputModeName(ctx.options.output_mode));
    WriteLn('Source: ', ctx.source_name);
    WriteLn('Tokens: ', ctx.token_count);
    WriteLn('Blocs : ', ctx.block_count);
    WriteLn('Procs : ', ctx.proc_count);
    WriteLn('Funcs : ', ctx.func_count);
    WriteLn('Params: ', ctx.param_count);
    WriteLn('Locals: ', ctx.local_count);
    WriteLn('Exprs : ', ctx.expr_count);
    WriteLn('Comps : ', ctx.comp_count);
    WriteLn('Conds : ', ctx.cond_count);
    WriteLn('Valof : ', ctx.valof_count);
    WriteLn('Result: ', ctx.resultis_count);
    WriteLn('Assign: ', ctx.assign_count);
    WriteLn('Ctrl  : ', ctx.control_count);
    WriteLn('Loops : ', ctx.loop_count);
    WriteLn('Break : ', ctx.break_count);
    WriteLn('Switch: ', ctx.switch_count);
    WriteLn('Case  : ', ctx.case_count);
    WriteLn('Deflt : ', ctx.default_count);
    WriteLn('EndCas: ', ctx.endcase_count);
    WriteLn('RunRT : ', ctx.runtime_count);
    WriteLn('Static: ', ctx.static_count);
    WriteLn('Symbols: ', ctx.sym_count);
    WriteLn('MaxPar: ', ctx.max_param_count);
    WriteLn('ABI   : params pile [', ABI_FRAME_REG, '+', ABI_PARAM_BASE,
            '], retour ', ABI_RET_REG, ', frame ', ABI_FRAME_REG,
            '/', ABI_STACK_REG, ', caller cleanup');
    WriteLn('Stack : params ', ctx.abi_param_bytes, ' octets, locals ',
            ctx.abi_local_bytes, ' octets');
    If ctx.options.keep_asm Then
      WriteLn('ASM   : ', ctx.asm_name);
    WriteLn('OBJ   : ', ctx.obj_name);
    If ctx.options.output_mode = OM_EXE Then
      WriteLn('EXE   : ', ctx.exe_name);
    WriteLn('TODO initiales: suite de 25 points completee.');
  End
  Else
  Begin
    WriteLn('Compilation arretee avec ', ctx.errors, ' erreur(s).');
    Halt(EXIT_ERROR);
  End;
  Halt(EXIT_OK);
END.
