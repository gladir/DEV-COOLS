{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur PL/1 vers assembleur 80386, 32 bits, pour Windows 32 bits.
}

{TODO PL1CW32.PAS:
1. [IMPLEMENTE] Definir le pipeline canonique du compilateur : source .PLI/.PL1 -> tokens -> AST/intermediaire -> assembleur 80386 -> OBJ COFF -> EXE PE Win32.
2. [IMPLEMENTE] Ajouter les options de ligne de commande : fichier source, -o sortie, mode par defaut .EXE, -obj pour produire seulement un .OBJ, -asm pour generer/conserver explicitement le .ASM, -v, -h.
3. [IMPLEMENTE] Definir les conventions de fichiers : accepter SAMPLES\PL1\*.PLI, produire .EXE par defaut, produire .OBJ final avec -obj, ne produire .ASM que si -asm est demande.
4. [IMPLEMENTE] Mettre en place l'infrastructure commune : lecture source, suivi ligne/colonne, messages d'erreur clairs, codes de sortie, limites internes compatibles Turbo Pascal 7 et Free Pascal 3.2.
5. [IMPLEMENTE] Implementer le scanner lexical PL/1 : identifiants, mots-cles, entiers, chaines, commentaires /* ... */, operateurs, parentheses, virgules, deux-points, points-virgules.
6. [IMPLEMENTE] Construire la table des mots-cles necessaires aux exemples : PROCEDURE, OPTIONS, MAIN, DECLARE, FIXED, BINARY, INITIAL, STATIC, RETURNS, RETURN, DO, TO, END, PUT, LIST, SKIP, SELECT, WHEN, OTHERWISE, GOTO.
7. Parser les etiquettes PL/1 de procedure et de controle : MAIN:, ABSVAL:, FIN:, avec resolution des references avant/arriere pour GOTO.
8. Parser les declarations PROCEDURE, y compris OPTIONS(MAIN), listes de parametres, RETURNS(FIXED BINARY), corps de procedure et END nom optionnel.
9. Construire une table des symboles avec portees : procedures, parametres, variables locales, variables STATIC, tableaux, etiquettes et symboles runtime.
10. Parser les declarations DECLARE simples : FIXED BINARY, INITIAL(expr), STATIC, declarations multiples si ajoutees plus tard, et diagnostics de redeclaration.
11. Supporter les tableaux PL/1 unidimensionnels utilises par TEST2.PLI : DECLARE TAB(10) FIXED BINARY STATIC, indexation TAB(I), bornes 1..N.
12. Definir la representation 32 bits des types minimaux : FIXED BINARY comme entier signe 32 bits, tableaux d'entiers 32 bits, valeurs de retour dans EAX.
13. Implementer le parseur d'expressions avec precedence : litteraux, variables, tableaux, parentheses, appels, unaire -, *, / si prevu, +, -, comparaisons.
14. Implementer les built-ins requis : ABS, MAX, MIN, MOD, avec evaluation correcte dans les expressions et preparation a d'autres built-ins PL/1.
15. Generer le code des affectations : variable = expression, tableau(index) = expression, initialisation explicite, initialisation STATIC et locales.
16. Implementer DO I = debut TO fin ; ... END ; avec variable de controle, test de fin, increment implicite, labels 80386 uniques et imbrication.
17. Implementer SELECT(expr), WHEN(valeurs), OTHERWISE et END, en generation de comparaisons et branchements structures.
18. Implementer GOTO label et les etiquettes internes en emission ASM/OBJ, avec verification des labels inexistants ou dupliques.
19. Implementer RETURN(expr) pour les procedures avec RETURNS, prologue/epilogue propre et retour de valeur dans EAX.
20. Definir la convention d'appel interne 32 bits : parametres sur pile, frame EBP, sauvegarde minimale des registres, nettoyage de pile documente.
21. Generer les prologues/epilogues 80386 Win32 : allocation des locales, acces [EBP-offset] et [EBP+offset], alignement simple de pile.
22. Fournir le runtime console minimal : PUT LIST(expr) pour afficher les entiers, PUT SKIP pour nouvelle ligne, sortie propre via ExitProcess ou equivalent.
23. Implementer l'emission ASM optionnelle : syntaxe MASM 80386 lisible, sections .text/.data/.rdata, labels stables, commentaires utiles pour le debug.
24. Implementer l'emission OBJ COFF et le lien EXE PE Win32 par defaut, avec imports runtime necessaires et mode -obj qui s'arrete apres le fichier objet.
25. Creer une validation automatique compilant et executant tous les fichiers SAMPLES\PL1\*.PLI, en couvrant TEST.PLI et TEST2.PLI, avec verification des sorties attendues et des modes .EXE, .OBJ et .ASM optionnel.
}
Program PL1CW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  INFRASTRUCTURE DE BASE
  ============================================================ }

Const
  PL1CW32_VERSION = '1.0';
  PL1CW32_DATE    = '2026';
  MAX_PATH_LEN    = 255;
  MAX_LINE_LEN    = 255;
  MAX_SOURCE_LINES = 12000;
  MAX_SOURCE_CHARS = 60000;
  MAX_ERRORS      = 40;
  PL1_KEYWORD_COUNT = 28;
  EXT_PL1         = '.PL1';
  EXT_PLI         = '.PLI';
  EXT_ASM         = '.asm';
  EXT_OBJ         = '.obj';
  EXT_EXE         = '.exe';
  EXIT_OK         = 0;
  EXIT_ERROR      = 1;
  EXIT_USAGE      = 2;

Type
  TString = String[MAX_PATH_LEN];
  TSourceLine = String[MAX_LINE_LEN];
  TKeyword = String[16];
  TKeywordTable = Array[1..PL1_KEYWORD_COUNT] Of TKeyword;

  { TODO 1 - Pipeline canonique du compilateur.

    Le compilateur PL1CW32 est organise comme une suite d'etapes
    explicites. Chaque etape consomme l'artefact de l'etape precedente
    et produit le suivant :

      .PLI/.PL1 source PL/1
        -> flux de tokens
        -> AST / representation intermediaire PL/1
        -> assembleur 80386 Win32
        -> objet COFF 32 bits
        -> executable PE Win32

    Par defaut, le pipeline va jusqu'a l'executable PE Win32. Les TODO 2
    et 3 brancheront les options permettant de s'arreter au fichier OBJ
    et de generer ou conserver explicitement le fichier ASM.
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
    AK_SOURCE_PL1,
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
    emit_asm    : Boolean;
    verbose     : Boolean;
    show_help   : Boolean;
    output_name : TString;
  End;

  TTokenKind = (
    TK_EOF,
    TK_IDENT,
    TK_KEYWORD,
    TK_INTEGER,
    TK_STRING,
    TK_OPERATOR,
    TK_PUNCT
  );

  TToken = Record
    kind    : TTokenKind;
    text    : TString;
    int_val : LongInt;
    line    : LongInt;
    col     : Integer;
  End;

  TSourceInfo = Record
    loaded       : Boolean;
    line_count   : LongInt;
    char_count   : LongInt;
    max_line_len : Integer;
    cur_line     : LongInt;
    cur_col      : Integer;
  End;

  TLexInfo = Record
    token_count   : LongInt;
    ident_count   : LongInt;
    keyword_count : LongInt;
    integer_count : LongInt;
    string_count  : LongInt;
    operator_count: LongInt;
    punct_count   : LongInt;
    comment_count : LongInt;
    eof_token     : TToken;
  End;

  TCompilerContext = Record
    source_name : TString;
    asm_name    : TString;
    obj_name    : TString;
    exe_name    : TString;
    options     : TPipelineOptions;
    source      : TSourceInfo;
    lex         : TLexInfo;
    stage       : TCompileStage;
    last_art    : TArtifactKind;
    errors      : Integer;
    warnings    : Integer;
  End;

Const
  PL1_KEYWORDS: TKeywordTable = (
    'PROCEDURE',
    'OPTIONS',
    'MAIN',
    'DECLARE',
    'FIXED',
    'BINARY',
    'INITIAL',
    'STATIC',
    'RETURNS',
    'RETURN',
    'DO',
    'TO',
    'END',
    'PUT',
    'LIST',
    'SKIP',
    'SELECT',
    'WHEN',
    'OTHERWISE',
    'GOTO',
    'PROC',
    'DCL',
    'INIT',
    'GO',
    'BY',
    'IF',
    'THEN',
    'ELSE'
  );

Function StageName(stage: TCompileStage): TString;
Begin
  Case stage Of
    CS_LOAD_SOURCE: StageName := 'source';
    CS_LEX_TOKENS:  StageName := 'tokens';
    CS_PARSE_AST:   StageName := 'ast-ir';
    CS_EMIT_ASM386: StageName := 'asm-80386';
    CS_BUILD_OBJ:   StageName := 'obj-coff';
    CS_LINK_EXE:    StageName := 'exe-pe32';
  Else
    StageName := 'unknown';
  End;
End;

Function ArtifactName(artifact: TArtifactKind): TString;
Begin
  Case artifact Of
    AK_NONE:         ArtifactName := 'none';
    AK_SOURCE_PL1:   ArtifactName := 'source-pl1';
    AK_TOKEN_STREAM: ArtifactName := 'token-stream';
    AK_AST_IR:       ArtifactName := 'ast-ir';
    AK_ASM_386:      ArtifactName := 'asm-80386';
    AK_OBJ_COFF:     ArtifactName := 'obj-coff';
    AK_EXE_PE32:     ArtifactName := 'exe-pe32';
  Else
    ArtifactName := 'unknown';
  End;
End;

Procedure InitPipelineDefaults(Var ctx: TCompilerContext);
Begin
  ctx.source_name := '';
  ctx.asm_name := '';
  ctx.obj_name := '';
  ctx.exe_name := '';
  ctx.options.output_mode := OM_EXE;
  ctx.options.emit_asm := False;
  ctx.options.verbose := False;
  ctx.options.show_help := False;
  ctx.options.output_name := '';
  ctx.source.loaded := False;
  ctx.source.line_count := 0;
  ctx.source.char_count := 0;
  ctx.source.max_line_len := 0;
  ctx.source.cur_line := 1;
  ctx.source.cur_col := 1;
  ctx.lex.token_count := 0;
  ctx.lex.ident_count := 0;
  ctx.lex.keyword_count := 0;
  ctx.lex.integer_count := 0;
  ctx.lex.string_count := 0;
  ctx.lex.operator_count := 0;
  ctx.lex.punct_count := 0;
  ctx.lex.comment_count := 0;
  ctx.lex.eof_token.kind := TK_EOF;
  ctx.lex.eof_token.text := '';
  ctx.lex.eof_token.int_val := 0;
  ctx.lex.eof_token.line := 1;
  ctx.lex.eof_token.col := 1;
  ctx.stage := CS_LOAD_SOURCE;
  ctx.last_art := AK_NONE;
  ctx.errors := 0;
  ctx.warnings := 0;
End;

Procedure PipelineError(Var ctx: TCompilerContext; msg: TString);
Begin
  If ctx.errors < MAX_ERRORS Then
    Writeln('PL1CW32: ', StageName(ctx.stage), ': ', msg);
  Inc(ctx.errors);
  If ctx.errors = MAX_ERRORS Then
    Writeln('PL1CW32: trop d''erreurs, arret des diagnostics.');
End;

Function UpperStr(s: TString): TString;
Var
  i: Integer;
Begin
  For i := 1 To Length(s) Do
    s[i] := UpCase(s[i]);
  UpperStr := s;
End;

Function FetchSourceLine(name: TString; wanted: LongInt; Var line: TSourceLine): Boolean;
Var
  f: Text;
  cur: LongInt;
  io: Integer;
Begin
  FetchSourceLine := False;
  line := '';
  Assign(f, name);
  Reset(f);
  io := IOResult;
  If io <> 0 Then
    Exit;

  cur := 0;
  While (Not Eof(f)) And (cur < wanted) Do
    Begin
      ReadLn(f, line);
      io := IOResult;
      If io <> 0 Then
        Begin
          Close(f);
          io := IOResult;
          Exit;
        End;
      Inc(cur);
    End;

  Close(f);
  io := IOResult;
  FetchSourceLine := cur = wanted;
End;

Procedure SourceErrorAt(Var ctx: TCompilerContext; line_no: LongInt;
                        col_no: Integer; msg: TString);
Var
  line: TSourceLine;
  i: Integer;
Begin
  If ctx.errors < MAX_ERRORS Then
    Begin
      Writeln(ctx.source_name, '(', line_no, ',', col_no, '): error: ', msg);
      If FetchSourceLine(ctx.source_name, line_no, line) Then
        Begin
          Writeln(line);
          For i := 1 To col_no - 1 Do
            Write(' ');
          Writeln('^');
        End;
    End;
  Inc(ctx.errors);
  If ctx.errors = MAX_ERRORS Then
    Writeln('PL1CW32: trop d''erreurs, arret des diagnostics.');
End;

Procedure SourceWarningAt(Var ctx: TCompilerContext; line_no: LongInt;
                          col_no: Integer; msg: TString);
Begin
  Inc(ctx.warnings);
  Writeln(ctx.source_name, '(', line_no, ',', col_no, '): warning: ', msg);
End;

Procedure ResetSourceCursor(Var ctx: TCompilerContext);
Begin
  ctx.source.cur_line := 1;
  ctx.source.cur_col := 1;
End;

Procedure AdvanceSourceCursor(Var ctx: TCompilerContext; ch: Char);
Begin
  If ch = #10 Then
    Begin
      Inc(ctx.source.cur_line);
      ctx.source.cur_col := 1;
    End
  Else
    Inc(ctx.source.cur_col);
End;

Function LoadSourceFile(Var ctx: TCompilerContext): Boolean;
Var
  f: Text;
  line: TSourceLine;
  io: Integer;
  len: Integer;
Begin
  LoadSourceFile := False;
  ctx.source.loaded := False;
  ctx.source.line_count := 0;
  ctx.source.char_count := 0;
  ctx.source.max_line_len := 0;
  ResetSourceCursor(ctx);

  Assign(f, ctx.source_name);
  Reset(f);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'impossible d''ouvrir le fichier source');
      Exit;
    End;

  While Not Eof(f) Do
    Begin
      ReadLn(f, line);
      io := IOResult;
      If io <> 0 Then
        Begin
          Close(f);
          io := IOResult;
          PipelineError(ctx, 'erreur de lecture du fichier source');
          Exit;
        End;

      Inc(ctx.source.line_count);
      len := Length(line);
      Inc(ctx.source.char_count, len + 1);
      If len > ctx.source.max_line_len Then
        ctx.source.max_line_len := len;

      If ctx.source.line_count > MAX_SOURCE_LINES Then
        Begin
          SourceErrorAt(ctx, ctx.source.line_count, 1,
                        'limite de lignes source depassee');
          Close(f);
          io := IOResult;
          Exit;
        End;

      If ctx.source.char_count > MAX_SOURCE_CHARS Then
        Begin
          SourceErrorAt(ctx, ctx.source.line_count, len,
                        'limite de taille source depassee');
          Close(f);
          io := IOResult;
          Exit;
        End;
    End;

  Close(f);
  io := IOResult;

  If ctx.source.line_count = 0 Then
    SourceWarningAt(ctx, 1, 1, 'fichier source vide');

  ctx.source.loaded := True;
  LoadSourceFile := ctx.errors = 0;
End;

Function IsLetter(ch: Char): Boolean;
Begin
  IsLetter := ((ch >= 'A') And (ch <= 'Z')) Or
              ((ch >= 'a') And (ch <= 'z')) Or
              (ch = '_') Or (ch = '#') Or (ch = '@') Or (ch = '$');
End;

Function IsDigit(ch: Char): Boolean;
Begin
  IsDigit := (ch >= '0') And (ch <= '9');
End;

Function IsIdentChar(ch: Char): Boolean;
Begin
  IsIdentChar := IsLetter(ch) Or IsDigit(ch);
End;

Function IsSpace(ch: Char): Boolean;
Begin
  IsSpace := (ch = ' ') Or (ch = #9);
End;

Function IsPunct(ch: Char): Boolean;
Begin
  IsPunct := (ch = '(') Or (ch = ')') Or (ch = ',') Or
             (ch = ':') Or (ch = ';');
End;

Function IsOperatorStart(ch: Char): Boolean;
Begin
  IsOperatorStart := (ch = '+') Or (ch = '-') Or (ch = '*') Or
                     (ch = '/') Or (ch = '=') Or (ch = '<') Or
                     (ch = '>') Or (ch = '^') Or (ch = '~') Or
                     (ch = '.') Or (ch = '&') Or (ch = '|');
End;

Function IsPL1Keyword(word: TString): Boolean;
Var
  u: TString;
  i: Integer;
Begin
  u := UpperStr(word);
  IsPL1Keyword := False;
  For i := 1 To PL1_KEYWORD_COUNT Do
    If u = PL1_KEYWORDS[i] Then
      Begin
        IsPL1Keyword := True;
        Exit;
      End;
End;

Procedure CountToken(Var ctx: TCompilerContext; kind: TTokenKind);
Begin
  Inc(ctx.lex.token_count);
  Case kind Of
    TK_IDENT:    Inc(ctx.lex.ident_count);
    TK_KEYWORD:  Inc(ctx.lex.keyword_count);
    TK_INTEGER:  Inc(ctx.lex.integer_count);
    TK_STRING:   Inc(ctx.lex.string_count);
    TK_OPERATOR: Inc(ctx.lex.operator_count);
    TK_PUNCT:    Inc(ctx.lex.punct_count);
  Else
  End;
End;

Procedure MakeToken(Var tok: TToken; kind: TTokenKind; text: TString;
                    line_no: LongInt; col_no: Integer);
Begin
  tok.kind := kind;
  tok.text := text;
  tok.int_val := 0;
  tok.line := line_no;
  tok.col := col_no;
End;

Function LexSourceFile(Var ctx: TCompilerContext): Boolean;
Var
  f: Text;
  line: TSourceLine;
  io, pos, len, start_col: Integer;
  line_no: LongInt;
  ch: Char;
  text: TString;
  tok: TToken;
  in_comment: Boolean;
  comment_line: LongInt;
  comment_col: Integer;
Begin
  LexSourceFile := False;
  If Not ctx.source.loaded Then
    Begin
      PipelineError(ctx, 'source non chargee');
      Exit;
    End;

  ctx.lex.token_count := 0;
  ctx.lex.ident_count := 0;
  ctx.lex.keyword_count := 0;
  ctx.lex.integer_count := 0;
  ctx.lex.string_count := 0;
  ctx.lex.operator_count := 0;
  ctx.lex.punct_count := 0;
  ctx.lex.comment_count := 0;
  ResetSourceCursor(ctx);

  Assign(f, ctx.source_name);
  Reset(f);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'impossible de relire le fichier source');
      Exit;
    End;

  in_comment := False;
  comment_line := 1;
  comment_col := 1;
  line_no := 0;

  While Not Eof(f) Do
    Begin
      ReadLn(f, line);
      io := IOResult;
      If io <> 0 Then
        Begin
          Close(f);
          io := IOResult;
          PipelineError(ctx, 'erreur de lecture pendant le scan lexical');
          Exit;
        End;

      Inc(line_no);
      pos := 1;
      len := Length(line);

      While pos <= len Do
        Begin
          ctx.source.cur_line := line_no;
          ctx.source.cur_col := pos;
          ch := line[pos];

          If in_comment Then
            Begin
              If (ch = '*') And (pos < len) And (line[pos + 1] = '/') Then
                Begin
                  in_comment := False;
                  Inc(pos, 2);
                End
              Else
                Inc(pos);
            End
          Else If IsSpace(ch) Then
            Inc(pos)
          Else If (ch = '/') And (pos < len) And (line[pos + 1] = '*') Then
            Begin
              Inc(ctx.lex.comment_count);
              in_comment := True;
              comment_line := line_no;
              comment_col := pos;
              Inc(pos, 2);
            End
          Else If IsLetter(ch) Then
            Begin
              start_col := pos;
              text := '';
              While (pos <= len) And IsIdentChar(line[pos]) Do
                Begin
                  text := text + line[pos];
                  Inc(pos);
                End;
              If IsPL1Keyword(text) Then
                MakeToken(tok, TK_KEYWORD, UpperStr(text), line_no, start_col)
              Else
                MakeToken(tok, TK_IDENT, text, line_no, start_col);
              CountToken(ctx, tok.kind);
            End
          Else If IsDigit(ch) Then
            Begin
              start_col := pos;
              text := '';
              While (pos <= len) And IsDigit(line[pos]) Do
                Begin
                  text := text + line[pos];
                  Inc(pos);
                End;
              MakeToken(tok, TK_INTEGER, text, line_no, start_col);
              CountToken(ctx, tok.kind);
            End
          Else If ch = '''' Then
            Begin
              start_col := pos;
              text := '';
              Inc(pos);
              While (pos <= len) And (line[pos] <> '''') Do
                Begin
                  text := text + line[pos];
                  Inc(pos);
                End;
              If pos > len Then
                SourceErrorAt(ctx, line_no, start_col,
                              'chaine non terminee')
              Else
                Begin
                  Inc(pos);
                  MakeToken(tok, TK_STRING, text, line_no, start_col);
                  CountToken(ctx, tok.kind);
                End;
            End
          Else If IsPunct(ch) Then
            Begin
              text := ch;
              MakeToken(tok, TK_PUNCT, text, line_no, pos);
              CountToken(ctx, tok.kind);
              Inc(pos);
            End
          Else If IsOperatorStart(ch) Then
            Begin
              start_col := pos;
              text := ch;
              If (pos < len) Then
                Begin
                  If ((ch = '<') Or (ch = '>') Or (ch = '^') Or
                      (ch = '~')) And (line[pos + 1] = '=') Then
                    Begin
                      text := text + '=';
                      Inc(pos);
                    End;
                End;
              MakeToken(tok, TK_OPERATOR, text, line_no, start_col);
              CountToken(ctx, tok.kind);
              Inc(pos);
            End
          Else
            Begin
              SourceErrorAt(ctx, line_no, pos,
                            'caractere inattendu dans le source');
              Inc(pos);
            End;
        End;
    End;

  Close(f);
  io := IOResult;

  If in_comment Then
    SourceErrorAt(ctx, comment_line, comment_col,
                  'commentaire non termine');

  MakeToken(ctx.lex.eof_token, TK_EOF, '', ctx.source.line_count + 1, 1);
  LexSourceFile := ctx.errors = 0;
End;

Function IsOption(s: TString): Boolean;
Begin
  IsOption := (Length(s) > 0) And ((s[1] = '-') Or (s[1] = '/'));
End;

Function StripOptionPrefix(s: TString): TString;
Begin
  If IsOption(s) Then
    Delete(s, 1, 1);
  StripOptionPrefix := s;
End;

Function BaseNameNoExt(name: TString): TString;
Var
  i, dot_pos, slash_pos: Integer;
Begin
  dot_pos := 0;
  slash_pos := 0;
  For i := 1 To Length(name) Do
    Begin
      If (name[i] = '\') Or (name[i] = '/') Or (name[i] = ':') Then
        slash_pos := i;
      If name[i] = '.' Then
        dot_pos := i;
    End;

  If dot_pos <= slash_pos Then
    dot_pos := Length(name) + 1;

  BaseNameNoExt := Copy(name, 1, dot_pos - 1);
End;

Function FileExt(name: TString): TString;
Var
  i, dot_pos, slash_pos: Integer;
Begin
  dot_pos := 0;
  slash_pos := 0;
  For i := 1 To Length(name) Do
    Begin
      If (name[i] = '\') Or (name[i] = '/') Or (name[i] = ':') Then
        slash_pos := i;
      If name[i] = '.' Then
        dot_pos := i;
    End;

  If dot_pos <= slash_pos Then
    FileExt := ''
  Else
    FileExt := Copy(name, dot_pos, Length(name) - dot_pos + 1);
End;

Function HasFileExt(name: TString): Boolean;
Begin
  HasFileExt := FileExt(name) <> '';
End;

Function WithExt(name, ext: TString): TString;
Begin
  WithExt := BaseNameNoExt(name) + ext;
End;

Function EnsureExt(name, ext: TString): TString;
Begin
  If HasFileExt(name) Then
    EnsureExt := name
  Else
    EnsureExt := name + ext;
End;

Function SameExt(name, ext: TString): Boolean;
Begin
  SameExt := UpperStr(FileExt(name)) = UpperStr(ext);
End;

Function IsValidSourceName(name: TString): Boolean;
Begin
  IsValidSourceName := SameExt(name, EXT_PLI) Or SameExt(name, EXT_PL1);
End;

Function IsValidOutputName(name, ext: TString): Boolean;
Begin
  IsValidOutputName := (Not HasFileExt(name)) Or SameExt(name, ext);
End;

Procedure PrintUsage;
Begin
  Writeln('PL1CW32 - Cette commande permet de lancer le compilateur PL/1 ',
          'vers assembleur 80386, 32 bits, pour Windows 32 bits.');
  WriteLn;
  Writeln('Syntaxe: pl1cw32 source.pli [-o sortie] [-obj] [-asm] [-v] [-h]');
  Writeln;
  Writeln('Options:');
  Writeln('  -o sortie   Nom du fichier de sortie principal');
  Writeln('  -obj        Produire seulement un fichier .OBJ COFF');
  Writeln('  -asm        Generer/conserver aussi un fichier .ASM lisible');
  Writeln('  -v          Afficher les etapes du pipeline');
  Writeln('  -h          Afficher cette aide');
  Writeln;
  Writeln('Conventions: entree .PLI/.PL1, sortie .EXE par defaut, .OBJ avec -obj.');
End;

Procedure PrintOptions(Var ctx: TCompilerContext);
Begin
  Writeln('Source : ', ctx.source_name);
  If ctx.options.output_mode = OM_OBJ Then
    Writeln('Mode   : OBJ seulement')
  Else
    Writeln('Mode   : EXE Win32');
  If ctx.options.emit_asm Then
    Begin
      Writeln('ASM    : oui');
      Writeln('ASM out: ', ctx.asm_name);
    End
  Else
    Writeln('ASM    : non');
  If ctx.options.output_mode = OM_OBJ Then
    Writeln('OBJ out: ', ctx.obj_name, ' (final)')
  Else
    Begin
      Writeln('OBJ out: ', ctx.obj_name, ' (intermediaire)');
      Writeln('EXE out: ', ctx.exe_name, ' (final)');
    End;
End;

Procedure PrintSourceInfo(Var ctx: TCompilerContext);
Begin
  Writeln('Source chargee: ', ctx.source.line_count, ' lignes, ',
          ctx.source.char_count, ' caracteres, ligne max ',
          ctx.source.max_line_len);
End;

Procedure PrintLexInfo(Var ctx: TCompilerContext);
Begin
  Writeln('Table mots-cles PL/1: ', PL1_KEYWORD_COUNT, ' entrees');
  Writeln('Tokens : ', ctx.lex.token_count,
          ' (mots-cles=', ctx.lex.keyword_count,
          ', ident=', ctx.lex.ident_count,
          ', entiers=', ctx.lex.integer_count,
          ', chaines=', ctx.lex.string_count,
          ', ops=', ctx.lex.operator_count,
          ', ponct=', ctx.lex.punct_count,
          ', commentaires=', ctx.lex.comment_count, ')');
End;

Function SetDefaultOutputNames(Var ctx: TCompilerContext): Boolean;
Var
  base_name: TString;
Begin
  SetDefaultOutputNames := False;
  base_name := BaseNameNoExt(ctx.source_name);

  If ctx.options.output_name <> '' Then
    Begin
      If ctx.options.output_mode = OM_OBJ Then
        Begin
          If Not IsValidOutputName(ctx.options.output_name, EXT_OBJ) Then
            Begin
              Writeln('PL1CW32: avec -obj, la sortie doit etre .obj');
              Exit;
            End;
          ctx.obj_name := EnsureExt(ctx.options.output_name, EXT_OBJ);
        End
      Else
        Begin
          If Not IsValidOutputName(ctx.options.output_name, EXT_EXE) Then
            Begin
              Writeln('PL1CW32: en mode par defaut, la sortie doit etre .exe');
              Exit;
            End;
          ctx.exe_name := EnsureExt(ctx.options.output_name, EXT_EXE);
        End;
    End;

  If ctx.options.emit_asm And (ctx.asm_name = '') Then
    ctx.asm_name := WithExt(base_name, EXT_ASM);
  If ctx.obj_name = '' Then
    ctx.obj_name := WithExt(base_name, EXT_OBJ);
  If (ctx.options.output_mode = OM_EXE) And (ctx.exe_name = '') Then
    ctx.exe_name := WithExt(base_name, EXT_EXE);

  SetDefaultOutputNames := True;
End;

Function ParseArgs(Var ctx: TCompilerContext): Integer;
Var
  i: Integer;
  arg, opt: TString;
Begin
  ParseArgs := EXIT_OK;
  i := 1;

  While i <= ParamCount Do
    Begin
      arg := ParamStr(i);

      If IsOption(arg) Then
        Begin
          opt := UpperStr(StripOptionPrefix(arg));
          If opt = 'H' Then
            ctx.options.show_help := True
          Else If opt = '?' Then
            ctx.options.show_help := True
          Else If opt = 'V' Then
            ctx.options.verbose := True
          Else If opt = 'ASM' Then
            ctx.options.emit_asm := True
          Else If opt = 'OBJ' Then
            ctx.options.output_mode := OM_OBJ
          Else If opt = 'O' Then
            Begin
              Inc(i);
              If i > ParamCount Then
                Begin
                  Writeln('PL1CW32: option -o sans nom de sortie');
                  ParseArgs := EXIT_USAGE;
                  Exit;
                End;
              ctx.options.output_name := ParamStr(i);
            End
          Else
            Begin
              Writeln('PL1CW32: option inconnue: ', arg);
              ParseArgs := EXIT_USAGE;
              Exit;
            End;
        End
      Else
        Begin
          If ctx.source_name <> '' Then
            Begin
              Writeln('PL1CW32: plusieurs fichiers sources indiques');
              ParseArgs := EXIT_USAGE;
              Exit;
            End;
          ctx.source_name := arg;
        End;

      Inc(i);
    End;

  If ctx.options.show_help Then
    Begin
      ParseArgs := EXIT_OK;
      Exit;
    End;

  If ctx.source_name = '' Then
    Begin
      Writeln('PL1CW32: aucun fichier source indique');
      ParseArgs := EXIT_USAGE;
      Exit;
    End;

  If Not IsValidSourceName(ctx.source_name) Then
    Begin
      Writeln('PL1CW32: le fichier source doit avoir une extension .PLI ou .PL1');
      ParseArgs := EXIT_USAGE;
      Exit;
    End;

  If Not SetDefaultOutputNames(ctx) Then
    Begin
      ParseArgs := EXIT_USAGE;
      Exit;
    End;
End;

Function RunStage(Var ctx: TCompilerContext; stage: TCompileStage): Boolean;
Begin
  ctx.stage := stage;
  RunStage := False;

  Case stage Of
    CS_LOAD_SOURCE:
      Begin
        If LoadSourceFile(ctx) Then
          Begin
            ctx.last_art := AK_SOURCE_PL1;
            If ctx.options.verbose Then
              PrintSourceInfo(ctx);
            RunStage := True;
          End;
      End;
    CS_LEX_TOKENS:
      Begin
        If ctx.last_art <> AK_SOURCE_PL1 Then
          PipelineError(ctx, 'source PL/1 attendue')
        Else
          If LexSourceFile(ctx) Then
            Begin
              ctx.last_art := AK_TOKEN_STREAM;
              If ctx.options.verbose Then
                PrintLexInfo(ctx);
              RunStage := True;
            End;
      End;
    CS_PARSE_AST:
      Begin
        { TODO 8 a 18 construiront l'AST / IR PL/1. }
        If ctx.last_art <> AK_TOKEN_STREAM Then
          PipelineError(ctx, 'flux de tokens attendu')
        Else
          Begin
            ctx.last_art := AK_AST_IR;
            RunStage := True;
          End;
      End;
    CS_EMIT_ASM386:
      Begin
        { TODO 20 a 23 genereront l'assembleur 80386 Win32. }
        If ctx.last_art <> AK_AST_IR Then
          PipelineError(ctx, 'AST / IR attendu')
        Else
          Begin
            ctx.last_art := AK_ASM_386;
            RunStage := True;
          End;
      End;
    CS_BUILD_OBJ:
      Begin
        { TODO 24 produira l'objet COFF 32 bits. }
        If ctx.last_art <> AK_ASM_386 Then
          PipelineError(ctx, 'assembleur 80386 attendu')
        Else
          Begin
            ctx.last_art := AK_OBJ_COFF;
            RunStage := True;
          End;
      End;
    CS_LINK_EXE:
      Begin
        { TODO 24 liera l'objet en executable PE Win32 par defaut. }
        If ctx.last_art <> AK_OBJ_COFF Then
          PipelineError(ctx, 'objet COFF attendu')
        Else
          Begin
            ctx.last_art := AK_EXE_PE32;
            RunStage := True;
          End;
      End;
  End;
End;

Function RunPipeline(Var ctx: TCompilerContext): Boolean;
Begin
  RunPipeline := False;

  If Not RunStage(ctx, CS_LOAD_SOURCE) Then
    Exit;
  If Not RunStage(ctx, CS_LEX_TOKENS) Then
    Exit;
  If Not RunStage(ctx, CS_PARSE_AST) Then
    Exit;
  If Not RunStage(ctx, CS_EMIT_ASM386) Then
    Exit;
  If Not RunStage(ctx, CS_BUILD_OBJ) Then
    Exit;

  If ctx.options.output_mode = OM_EXE Then
    If Not RunStage(ctx, CS_LINK_EXE) Then
      Exit;

  RunPipeline := ctx.errors = 0;
End;

Procedure PrintPipeline;
Begin
  Writeln('PL1CW32 ', PL1CW32_VERSION, ' - pipeline canonique');
  Writeln('  .PLI/.PL1 -> ', ArtifactName(AK_TOKEN_STREAM),
          ' -> ', ArtifactName(AK_AST_IR),
          ' -> ', ArtifactName(AK_ASM_386),
          ' -> ', ArtifactName(AK_OBJ_COFF),
          ' -> ', ArtifactName(AK_EXE_PE32));
End;

Var
  ctx: TCompilerContext;
  parse_result: Integer;

BEGIN
  InitPipelineDefaults(ctx);
  parse_result := ParseArgs(ctx);

  If ctx.options.show_help Then
    Begin
      PrintUsage;
      Halt(EXIT_OK);
    End;

  If parse_result <> EXIT_OK Then
    Begin
      PrintUsage;
      Halt(parse_result);
    End;

  If ctx.options.verbose Then
    Begin
      PrintPipeline;
      PrintOptions(ctx);
    End;

  If Not RunPipeline(ctx) Then
    Halt(EXIT_ERROR);

  Halt(EXIT_OK);
END.
