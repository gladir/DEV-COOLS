{ ============================================================
  Modules : assemblage a la compilation de plusieurs fichiers.
  require('./x'), import / export (ESM transforme en CommonJS),
  fichiers JSON, node_modules. Les modules dependants sont
  ajoutes apres le programme principal sous forme de fonctions
  (__m1, __m2...) ; une table de correspondance (specificateur ->
  module) est ecrite en tete de la premiere ligne, ce qui
  conserve la numerotation des lignes du programme principal.
  ============================================================ }

Type
  TMTok = Record
    kind: Byte;            { 1 identifiant, 2 ponctuation, 3 chaine, 4 nombre, 5 modele, 6 regex }
    nl: Boolean;           { fin de ligne avant ce jeton }
    s, e: LongInt;
  End;
  TMTokArr = Array[0..33554431] Of TMTok;
  PMTokArr = ^TMTokArr;
  TMTextArr = Array[0..268435455] Of Char;
  PMTextArr = ^TMTextArr;

  TTextBuf = Record
    p: PMTextArr;
    n, cap: LongInt;
  End;

  TModInfo = Record
    path: TString;         { chemin absolu normalise ('/') }
    key: TString;          { cle du module dans la table }
    text: PMTextArr;
    len: LongInt;
    json: Boolean;
    out_text: TTextBuf;    { texte reecrit }
    state: Byte;           { 0 a traiter, 1 traite }
    esm: Boolean;
    head: LongInt;         { fin du prologue du texte (directives) }
  End;

  TModAlias = Record
    from_key, spec, target: TString;
  End;

Const
  MAX_MODS = 300;
  MAX_ALIASES = 3000;

Var
  mod_list: Array[1..MAX_MODS] Of TModInfo;
  mod_count: LongInt;
  mod_alias: Array[1..MAX_ALIASES] Of TModAlias;
  alias_count: LongInt;
  mod_root: TString;       { repertoire du programme principal }
  mod_main_path: TString;
  mod_tmp: LongInt;

Procedure TbInit(Var b: TTextBuf);
Begin
  b.p := Nil;
  b.n := 0;
  b.cap := 0;
End;

Procedure TbAdd(Var b: TTextBuf; c: Char);
Begin
  If b.n >= b.cap Then
    Begin
      If b.cap = 0 Then
        b.cap := 4096
      Else
        b.cap := b.cap * 2;
      ReallocMem(b.p, b.cap);
    End;
  b.p^[b.n] := c;
  Inc(b.n);
End;

Procedure TbStr(Var b: TTextBuf; Const s: String);
Var
  i: LongInt;
Begin
  For i := 1 To Length(s) Do
    TbAdd(b, s[i]);
End;

Procedure TbRange(Var b: TTextBuf; txt: PMTextArr; s, e: LongInt);
Var
  i: LongInt;
Begin
  For i := s To e - 1 Do
    TbAdd(b, txt^[i]);
End;

Function MIsIdStart(c: Char): Boolean;
Begin
  MIsIdStart := (c In ['A'..'Z', 'a'..'z', '_', '$']) Or (c >= #128);
End;

Function MIsIdChar(c: Char): Boolean;
Begin
  MIsIdChar := MIsIdStart(c) Or (c In ['0'..'9']);
End;

{ Fin d'un litteral de gabarit : i pointe sur l'apostrophe inverse ouvrante ; rend l'indice apres la fermante. }
Function MSkipTemplate(txt: PMTextArr; len, i: LongInt): LongInt;
Var
  depth: LongInt;
  q: Char;
Begin
  Inc(i);
  While i < len Do
    Begin
      If txt^[i] = '\' Then
        Inc(i, 2)
      Else If txt^[i] = '`' Then
        Begin
          MSkipTemplate := i + 1;
          Exit;
        End
      Else If (txt^[i] = '$') And (i + 1 < len) And (txt^[i + 1] = '{') Then
        Begin
          Inc(i, 2);
          depth := 1;
          While (i < len) And (depth > 0) Do
            Begin
              If txt^[i] = '{' Then
                Inc(depth)
              Else If txt^[i] = '}' Then
                Dec(depth)
              Else If txt^[i] = '`' Then
                Begin
                  i := MSkipTemplate(txt, len, i);
                  Continue;
                End
              Else If (txt^[i] = '"') Or (txt^[i] = '''') Then
                Begin
                  q := txt^[i];
                  Inc(i);
                  While (i < len) And (txt^[i] <> q) Do
                    Begin
                      If txt^[i] = '\' Then
                        Inc(i);
                      Inc(i);
                    End;
                End;
              Inc(i);
            End;
        End
      Else
        Inc(i);
    End;
  MSkipTemplate := len;
End;

Function MWordEq(txt: PMTextArr; Const t: TMTok; Const w: String): Boolean;
Var
  i: LongInt;
Begin
  MWordEq := False;
  If (t.kind <> 1) Or (t.e - t.s <> Length(w)) Then
    Exit;
  For i := 1 To Length(w) Do
    If txt^[t.s + i - 1] <> w[i] Then
      Exit;
  MWordEq := True;
End;

Function MPunctEq(txt: PMTextArr; Const t: TMTok; c: Char): Boolean;
Begin
  MPunctEq := (t.kind = 2) And (txt^[t.s] = c);
End;

Function MRegexAllowed(txt: PMTextArr; toks: PMTokArr; n: LongInt): Boolean;
Var
  t: TMTok;
Begin
  MRegexAllowed := True;
  If n = 0 Then
    Exit;
  t := toks^[n - 1];
  Case t.kind Of
    2: MRegexAllowed := Not (txt^[t.s] In [')', ']', '}']);
    1: MRegexAllowed := MWordEq(txt, t, 'return') Or MWordEq(txt, t, 'typeof') Or MWordEq(txt, t, 'instanceof') Or
                        MWordEq(txt, t, 'in') Or MWordEq(txt, t, 'of') Or MWordEq(txt, t, 'new') Or
                        MWordEq(txt, t, 'delete') Or MWordEq(txt, t, 'void') Or MWordEq(txt, t, 'throw') Or
                        MWordEq(txt, t, 'case') Or MWordEq(txt, t, 'do') Or MWordEq(txt, t, 'else') Or
                        MWordEq(txt, t, 'yield') Or MWordEq(txt, t, 'await');
  Else
    MRegexAllowed := False;
  End;
End;

Procedure MTokenize(txt: PMTextArr; len: LongInt; Var toks: PMTokArr; Var ntok: LongInt);
Var
  i, st: LongInt;
  c, q: Char;
  nl, incls: Boolean;

  Procedure Push(k: Byte; s, e: LongInt);
  Begin
    toks^[ntok].kind := k;
    toks^[ntok].s := s;
    toks^[ntok].e := e;
    toks^[ntok].nl := nl;
    Inc(ntok);
    nl := False;
  End;

Begin
  GetMem(toks, (len + 16) * SizeOf(TMTok));
  ntok := 0;
  nl := False;
  i := 0;
  If (len >= 2) And (txt^[0] = '#') And (txt^[1] = '!') Then
    While (i < len) And (txt^[i] <> #10) Do
      Inc(i);
  While i < len Do
    Begin
      c := txt^[i];
      If c = #10 Then
        Begin
          nl := True;
          Inc(i);
        End
      Else If (c = ' ') Or (c = #9) Or (c = #13) Then
        Inc(i)
      Else If (c = '/') And (i + 1 < len) And (txt^[i + 1] = '/') Then
        Begin
          While (i < len) And (txt^[i] <> #10) Do
            Inc(i);
        End
      Else If (c = '/') And (i + 1 < len) And (txt^[i + 1] = '*') Then
        Begin
          Inc(i, 2);
          While (i + 1 < len) And Not ((txt^[i] = '*') And (txt^[i + 1] = '/')) Do
            Begin
              If txt^[i] = #10 Then
                nl := True;
              Inc(i);
            End;
          Inc(i, 2);
        End
      Else If (c = '"') Or (c = '''') Then
        Begin
          st := i;
          Inc(i);
          While (i < len) And (txt^[i] <> c) And (txt^[i] <> #10) Do
            Begin
              If txt^[i] = '\' Then
                Inc(i);
              Inc(i);
            End;
          Inc(i);
          Push(3, st, i);
        End
      Else If c = '`' Then
        Begin
          st := i;
          i := MSkipTemplate(txt, len, i);
          Push(5, st, i);
        End
      Else If MIsIdStart(c) Then
        Begin
          st := i;
          While (i < len) And MIsIdChar(txt^[i]) Do
            Inc(i);
          Push(1, st, i);
        End
      Else If c In ['0'..'9'] Then
        Begin
          st := i;
          While (i < len) And (MIsIdChar(txt^[i]) Or (txt^[i] = '.')) Do
            Inc(i);
          Push(4, st, i);
        End
      Else If (c = '/') And MRegexAllowed(txt, toks, ntok) Then
        Begin
          st := i;
          Inc(i);
          incls := False;
          While (i < len) And (txt^[i] <> #10) And (incls Or (txt^[i] <> '/')) Do
            Begin
              If txt^[i] = '\' Then
                Inc(i)
              Else If txt^[i] = '[' Then
                incls := True
              Else If txt^[i] = ']' Then
                incls := False;
              Inc(i);
            End;
          Inc(i);
          While (i < len) And MIsIdChar(txt^[i]) Do
            Inc(i);
          Push(6, st, i);
        End
      Else
        Begin
          Push(2, i, i + 1);
          Inc(i);
        End;
    End;
End;

{ Valeur d'un jeton chaine sans guillemets. }
Function MStrVal(txt: PMTextArr; Const t: TMTok): TString;
Var
  i: LongInt;
  r: TString;
Begin
  r := '';
  For i := t.s + 1 To t.e - 2 Do
    If Length(r) < 250 Then
      r := r + txt^[i];
  MStrVal := r;
End;

Function MTokText(txt: PMTextArr; Const t: TMTok): TString;
Var
  i: LongInt;
  r: TString;
Begin
  r := '';
  For i := t.s To t.e - 1 Do
    If Length(r) < 250 Then
      r := r + txt^[i];
  MTokText := r;
End;

{ ---- fichiers et chemins ---- }

Function MFileExists(Const p: TString): Boolean;
Var
  f: File;
  io: Integer;
  attr: Word;
Begin
  Assign(f, NormalizePath(p));
  GetFAttr(f, attr);
  io := DosError;
  MFileExists := (io = 0) And ((attr And Directory) = 0);
End;

Function MDirExists(Const p: TString): Boolean;
Var
  f: File;
  io: Integer;
  attr: Word;
Begin
  Assign(f, NormalizePath(p));
  GetFAttr(f, attr);
  io := DosError;
  MDirExists := (io = 0) And ((attr And Directory) <> 0);
End;

Function MDirName(Const p: TString): TString;
Var
  i: Integer;
Begin
  i := Length(p);
  While (i > 0) And (p[i] <> '/') Do
    Dec(i);
  If i <= 1 Then
    MDirName := Copy(p, 1, i)
  Else
    MDirName := Copy(p, 1, i - 1);
End;

{ Normalise : '\' -> '/', supprime . et .. }
Function MNormPath(Const p0: TString): TString;
Var
  p, seg, r: TString;
  i: Integer;
  segs: Array[1..60] Of TString;
  n, k: Integer;
  absolute: Boolean;
  drive: TString;
Begin
  p := p0;
  For i := 1 To Length(p) Do
    If p[i] = '\' Then
      p[i] := '/';
  drive := '';
  absolute := False;
  If (Length(p) >= 2) And (p[2] = ':') Then
    Begin
      drive := Copy(p, 1, 2);
      p := Copy(p, 3, 250);
    End;
  If (Length(p) > 0) And (p[1] = '/') Then
    absolute := True;
  n := 0;
  seg := '';
  p := p + '/';
  For i := 1 To Length(p) Do
    Begin
      If p[i] = '/' Then
        Begin
          If (seg = '') Or (seg = '.') Then
            seg := ''
          Else If seg = '..' Then
            Begin
              If (n > 0) And (segs[n] <> '..') Then
                Dec(n)
              Else If Not absolute Then
                Begin
                  Inc(n);
                  segs[n] := '..';
                End;
            End
          Else If n < 60 Then
            Begin
              Inc(n);
              segs[n] := seg;
            End;
          seg := '';
        End
      Else
        seg := seg + p[i];
    End;
  r := drive;
  If absolute Then
    r := r + '/';
  For k := 1 To n Do
    Begin
      r := r + segs[k];
      If k < n Then
        r := r + '/';
    End;
  MNormPath := r;
End;

Function MIsBuiltin(Const spec: TString): Boolean;
Const
  NB = 40;
  Names: Array[1..NB] Of String[20] = ('fs', 'path', 'os', 'util', 'events', 'assert', 'timers', 'perf_hooks',
    'process', 'child_process', 'readline', 'buffer', 'url', 'crypto', 'stream', 'http', 'https', 'net', 'zlib',
    'worker_threads', 'string_decoder', 'vm', 'cluster', 'dns', 'tty', 'querystring', 'module', 'v8', 'constants',
    'punycode', 'repl', 'dgram', 'http2', 'inspector', 'domain', 'async_hooks', 'diagnostics_channel', 'sys',
    'trace_events', 'wasi');
Var
  i: Integer;
Begin
  MIsBuiltin := False;
  If Copy(spec, 1, 5) = 'node:' Then
    Begin
      MIsBuiltin := True;
      Exit;
    End;
  For i := 1 To NB Do
    If (spec = Names[i]) Or (Copy(spec, 1, Length(Names[i]) + 1) = Names[i] + '/') Then
      Begin
        MIsBuiltin := True;
        Exit;
      End;
End;

{ Fichier ou repertoire candidat : rend le chemin du fichier ou '' }
Function MTryFile(Const base: TString): TString;
Const
  Exts: Array[1..4] Of String[6] = ('.js', '.json', '.cjs', '.mjs');
Var
  i: Integer;
Begin
  MTryFile := '';
  If MFileExists(base) Then
    Begin
      MTryFile := base;
      Exit;
    End;
  For i := 1 To 4 Do
    If MFileExists(base + Exts[i]) Then
      Begin
        MTryFile := base + Exts[i];
        Exit;
      End;
End;

Function MPackageMain(Const dir: TString): TString;
Var
  f: File;
  buf: PMTextArr;
  sz, got, i, j: LongInt;
  r: TString;
Begin
  MPackageMain := '';
  If Not MFileExists(dir + '/package.json') Then
    Exit;
  Assign(f, NormalizePath(dir + '/package.json'));
  FileMode := 0;
  Reset(f, 1);
  If IOResult <> 0 Then
    Exit;
  sz := FileSize(f);
  If (sz <= 0) Or (sz > 1000000) Then
    Begin
      Close(f);
      Exit;
    End;
  GetMem(buf, sz + 1);
  BlockRead(f, buf^, sz, got);
  Close(f);
  i := 0;
  While i + 6 < got Do
    Begin
      If (buf^[i] = '"') And (buf^[i + 1] = 'm') And (buf^[i + 2] = 'a') And (buf^[i + 3] = 'i') And
         (buf^[i + 4] = 'n') And (buf^[i + 5] = '"') Then
        Begin
          j := i + 6;
          While (j < got) And (buf^[j] In [' ', ':', #9, #10, #13]) Do
            Inc(j);
          If (j < got) And (buf^[j] = '"') Then
            Begin
              Inc(j);
              r := '';
              While (j < got) And (buf^[j] <> '"') And (Length(r) < 200) Do
                Begin
                  r := r + buf^[j];
                  Inc(j);
                End;
              MPackageMain := r;
            End;
          Break;
        End;
      Inc(i);
    End;
  FreeMem(buf);
End;

{ Resolution d'un specificateur : chemin absolu du fichier ou '' }
Function MResolve(Const from_path, spec: TString): TString;
Var
  base, dir, t, pm: TString;
  p: TString;
Begin
  MResolve := '';
  If MIsBuiltin(spec) Then
    Exit;
  If (Copy(spec, 1, 2) = './') Or (Copy(spec, 1, 3) = '../') Or (spec = '.') Or (spec = '..') Or
     (Copy(spec, 1, 1) = '/') Or ((Length(spec) > 2) And (spec[2] = ':')) Then
    Begin
      If (Copy(spec, 1, 1) = '/') Or ((Length(spec) > 2) And (spec[2] = ':')) Then
        base := MNormPath(spec)
      Else
        base := MNormPath(MDirName(from_path) + '/' + spec);
      t := MTryFile(base);
      If t <> '' Then
        Begin
          MResolve := t;
          Exit;
        End;
      If MDirExists(base) Then
        Begin
          pm := MPackageMain(base);
          If pm <> '' Then
            Begin
              t := MTryFile(MNormPath(base + '/' + pm));
              If t <> '' Then
                Begin
                  MResolve := t;
                  Exit;
                End;
            End;
          t := MTryFile(base + '/index');
          If t <> '' Then
            MResolve := t;
        End;
      Exit;
    End;
  { paquet : node_modules en remontant }
  dir := MDirName(from_path);
  While dir <> '' Do
    Begin
      p := MNormPath(dir + '/node_modules/' + spec);
      t := MTryFile(p);
      If t <> '' Then
        Begin
          MResolve := t;
          Exit;
        End;
      If MDirExists(p) Then
        Begin
          pm := MPackageMain(p);
          If pm <> '' Then
            Begin
              t := MTryFile(MNormPath(p + '/' + pm));
              If t <> '' Then
                Begin
                  MResolve := t;
                  Exit;
                End;
            End;
          t := MTryFile(p + '/index');
          If t <> '' Then
            Begin
              MResolve := t;
              Exit;
            End;
        End;
      If (dir = '/') Or (Length(dir) <= 2) Then
        Break;
      dir := MDirName(dir);
    End;
End;

Function MKeyOf(Const path: TString): TString;
Begin
  If (mod_root <> '') And (Copy(path, 1, Length(mod_root) + 1) = mod_root + '/') Then
    MKeyOf := Copy(path, Length(mod_root) + 2, 250)
  Else
    MKeyOf := path;
End;

Function MFindMod(Const path: TString): LongInt;
Var
  i: LongInt;
Begin
  MFindMod := 0;
  For i := 1 To mod_count Do
    If mod_list[i].path = path Then
      Begin
        MFindMod := i;
        Exit;
      End;
End;

Function MLoadFile(Const path: TString; Var text: PMTextArr; Var len: LongInt): Boolean;
Var
  f: File;
  sz, got, st: LongInt;
Begin
  MLoadFile := False;
  Assign(f, NormalizePath(path));
  FileMode := 0;
  Reset(f, 1);
  If IOResult <> 0 Then
    Exit;
  sz := FileSize(f);
  GetMem(text, sz + 1);
  got := 0;
  If sz > 0 Then
    BlockRead(f, text^, sz, got);
  Close(f);
  If IOResult <> 0 Then
    ;
  st := 0;
  If (got >= 3) And (text^[0] = #$EF) And (text^[1] = #$BB) And (text^[2] = #$BF) Then
    st := 3;
  If st > 0 Then
    Begin
      Move(text^[st], text^[0], got - st);
      Dec(got, st);
    End;
  len := got;
  MLoadFile := True;
End;

Procedure MAddAlias(Const from_key, spec, target: TString);
Var
  i: LongInt;
Begin
  For i := 1 To alias_count Do
    If (mod_alias[i].from_key = from_key) And (mod_alias[i].spec = spec) Then
      Exit;
  If alias_count >= MAX_ALIASES Then
    Exit;
  Inc(alias_count);
  mod_alias[alias_count].from_key := from_key;
  mod_alias[alias_count].spec := spec;
  mod_alias[alias_count].target := target;
End;

Procedure MQueueDep(Const from_path, from_key, spec: TString);
Var
  r: TString;
  id: LongInt;
  txt: PMTextArr;
  len: LongInt;
Begin
  r := MResolve(from_path, spec);
  If r = '' Then
    Exit;
  id := MFindMod(r);
  If id = 0 Then
    Begin
      If mod_count >= MAX_MODS Then
        Exit;
      If Not MLoadFile(r, txt, len) Then
        Exit;
      Inc(mod_count);
      id := mod_count;
      mod_list[id].path := r;
      mod_list[id].key := MKeyOf(r);
      mod_list[id].text := txt;
      mod_list[id].len := len;
      mod_list[id].json := (Length(r) > 5) And (Copy(r, Length(r) - 4, 5) = '.json');
      mod_list[id].state := 0;
      TbInit(mod_list[id].out_text);
    End;
  MAddAlias(from_key, spec, mod_list[id].key);
End;

{ Echappement d'une chaine pour un litteral JavaScript entre guillemets. }
Function MJsStr(Const s: String): String;
Var
  i: Integer;
  r: String;
Begin
  r := '"';
  For i := 1 To Length(s) Do
    Case s[i] Of
      '"': r := r + '\"';
      '\': r := r + '\\';
    Else
      r := r + s[i];
    End;
  MJsStr := r + '"';
End;

{ ---- Reecriture d'un module : ESM -> CommonJS, collecte des dependances ---- }

Type
  TNameList = Array[1..200] Of TString;

Procedure MProcess(Const mpath, mkey: TString; txt: PMTextArr; len: LongInt; Var outb: TTextBuf; Var is_esm: Boolean;
                   Var head_pos: LongInt);
Var
  toks: PMTokArr;
  ntok, i, j, k, copied, depth, tmpn, nl_count, q, stmt_end: LongInt;
  getters: TTextBuf;
  getter_names: TNameList;
  ng: Integer;
  repl: String;
  spec: TString;
  has_esm: Boolean;

  Function T(idx: LongInt): TMTok;
  Var
    z: TMTok;
  Begin
    If (idx >= 0) And (idx < ntok) Then
      T := toks^[idx]
    Else
      Begin
        z.kind := 0;
        z.s := len;
        z.e := len;
        z.nl := False;
        T := z;
      End;
  End;

  Function IsW(idx: LongInt; Const w: String): Boolean;
  Begin
    IsW := MWordEq(txt, T(idx), w);
  End;

  Function IsP(idx: LongInt; c: Char): Boolean;
  Begin
    IsP := MPunctEq(txt, T(idx), c);
  End;

  Procedure Replace(s, e: LongInt; Const r: String);
  Var
    z, nls: LongInt;
  Begin
    TbRange(outb, txt, copied, s);
    TbStr(outb, r);
    nls := 0;
    For z := s To e - 1 Do
      If txt^[z] = #10 Then
        Inc(nls);
    For z := 1 To nls Do
      TbAdd(outb, #10);
    copied := e;
  End;

  Procedure AddGetter(Const exported, localexpr: TString);
  Begin
    TbStr(getters, 'Object.defineProperty(exports,' + MJsStr(exported) + ',{get:function(){return ' + localexpr +
          '},enumerable:true,configurable:true});');
  End;

  { identifiants lies par un motif de destructuration a partir de l'ouvrant idx ; rend l'indice apres la fermante }
  Function PatternNames(idx: LongInt): LongInt;
  Var
    d, kk: LongInt;
    expect_bind: Boolean;
    prev: TMTok;
  Begin
    d := 0;
    expect_bind := True;
    While idx < ntok Do
      Begin
        If toks^[idx].kind = 2 Then
          Begin
            Case txt^[toks^[idx].s] Of
              '{', '[':
                Begin
                  Inc(d);
                  expect_bind := True;
                End;
              '}', ']':
                Begin
                  Dec(d);
                  If d = 0 Then
                    Begin
                      PatternNames := idx + 1;
                      Exit;
                    End;
                End;
              ',': expect_bind := True;
              ':': expect_bind := True;
              '=':
                Begin
                  { valeur par defaut : sauter jusqu'a la virgule ou la fermante du meme niveau }
                  expect_bind := False;
                  Inc(idx);
                  kk := 0;
                  While idx < ntok Do
                    Begin
                      If toks^[idx].kind = 2 Then
                        Case txt^[toks^[idx].s] Of
                          '{', '(', '[': Inc(kk);
                          '}', ')', ']':
                            Begin
                              If kk = 0 Then
                                Break;
                              Dec(kk);
                            End;
                          ',': If kk = 0 Then Break;
                        End;
                      Inc(idx);
                    End;
                  Continue;
                End;
            End;
          End
        Else If (toks^[idx].kind = 1) And expect_bind Then
          Begin
            { propriete suivie de ':' -> ce n'est pas la liaison }
            If Not ((idx + 1 < ntok) And (toks^[idx + 1].kind = 2) And (txt^[toks^[idx + 1].s] = ':')) Then
              Begin
                If ng < 200 Then
                  Begin
                    Inc(ng);
                    getter_names[ng] := MTokText(txt, toks^[idx]);
                  End;
                expect_bind := False;
              End;
          End;
        Inc(idx);
      End;
    PatternNames := idx;
  End;

  Procedure ProcessImport(start: LongInt);
  Var
    jj, e: LongInt;
    defname, nsname: TString;
    named: Array[1..60] Of TString;
    imp: Array[1..60] Of TString;
    nn, a: Integer;
    sp: TString;
    r: String;
    tn: String;
    sstr, sp_idx: LongInt;
  Begin
    jj := start + 1;
    defname := '';
    nsname := '';
    nn := 0;
    If T(jj).kind = 3 Then
      Begin
        sp := MStrVal(txt, T(jj));
        MQueueDep(mpath, mkey, sp);
        e := jj + 1;
        If IsP(e, ';') Then
          Inc(e);
        Replace(T(start).s, T(e - 1).e, 'require(' + MJsStr(sp) + ');');
        copied := T(e - 1).e;
        i := e - 1;
        Exit;
      End;
    If IsW(jj, 'type') And (T(jj + 1).kind = 1) And Not IsW(jj + 1, 'from') Then
      Inc(jj);
    If (T(jj).kind = 1) And Not (IsW(jj, 'from') And (T(jj + 1).kind = 3)) Then
      Begin
        defname := MTokText(txt, T(jj));
        Inc(jj);
        If IsP(jj, ',') Then
          Inc(jj);
      End;
    If IsP(jj, '*') Then
      Begin
        Inc(jj, 2);
        nsname := MTokText(txt, T(jj));
        Inc(jj);
      End
    Else If IsP(jj, '{') Then
      Begin
        Inc(jj);
        While (jj < ntok) And Not IsP(jj, '}') Do
          Begin
            If nn < 60 Then
              Begin
                Inc(nn);
                If T(jj).kind = 3 Then
                  imp[nn] := MJsStr(MStrVal(txt, T(jj)))
                Else
                  imp[nn] := MTokText(txt, T(jj));
                named[nn] := imp[nn];
                Inc(jj);
                If IsW(jj, 'as') Then
                  Begin
                    named[nn] := MTokText(txt, T(jj + 1));
                    Inc(jj, 2);
                  End;
              End
            Else
              Inc(jj);
            If IsP(jj, ',') Then
              Inc(jj);
          End;
        Inc(jj);
      End;
    If Not IsW(jj, 'from') Then
      Exit;
    Inc(jj);
    If T(jj).kind <> 3 Then
      Exit;
    sp := MStrVal(txt, T(jj));
    MQueueDep(mpath, mkey, sp);
    e := jj + 1;
    If (IsW(e, 'assert') Or IsW(e, 'with')) And IsP(e + 1, '{') Then
      Begin
        e := e + 2;
        While (e < ntok) And Not IsP(e, '}') Do
          Inc(e);
        Inc(e);
      End;
    If IsP(e, ';') Then
      Inc(e);
    Inc(tmpn);
    str(tmpn, tn);
    r := 'const __t' + tn + ' = __esm(require(' + MJsStr(sp) + '))';
    If defname <> '' Then
      r := r + ', ' + defname + ' = __t' + tn + '.default';
    If nsname <> '' Then
      r := r + ', ' + nsname + ' = __t' + tn;
    If nn > 0 Then
      Begin
        r := r + ', {';
        For a := 1 To nn Do
          Begin
            If a > 1 Then
              r := r + ', ';
            If imp[a][1] = '"' Then
              r := r + imp[a] + ': ' + named[a]
            Else If imp[a] = named[a] Then
              r := r + imp[a]
            Else
              r := r + imp[a] + ': ' + named[a];
          End;
        r := r + '} = __t' + tn;
      End;
    r := r + ';';
    Replace(T(start).s, T(e - 1).e, r);
    i := e - 1;
  End;

  Procedure ProcessExport(start: LongInt);
  Var
    jj, e, a, m: LongInt;
    nm, ex, sp: TString;
    r: String;
    froms: Boolean;
    loc: Array[1..60] Of TString;
    exn: Array[1..60] Of TString;
    nn: Integer;
    starred: Boolean;
    asname: TString;
    isdecl: Boolean;
    pairs: String;
  Begin
    jj := start + 1;
    If IsW(jj, 'default') Then
      Begin
        k := jj + 1;
        If IsW(k, 'async') And IsW(k + 1, 'function') Then
          Inc(k);
        If IsW(k, 'function') Or IsW(k, 'class') Then
          Begin
            m := k + 1;
            If IsP(m, '*') Then
              Inc(m);
            nm := '';
            If (T(m).kind = 1) And Not IsW(m, 'extends') Then
              nm := MTokText(txt, T(m));
            If nm <> '' Then
              Begin
                AddGetter('default', nm);
                Replace(T(start).s, T(jj + 1).s, '');
              End
            Else
              Replace(T(start).s, T(jj).e, 'exports.default =');
          End
        Else
          Replace(T(start).s, T(jj).e, 'exports.default =');
        has_esm := True;
        Exit;
      End;
    If IsP(jj, '{') Or IsP(jj, '*') Then
      Begin
        starred := IsP(jj, '*');
        nn := 0;
        asname := '';
        If starred Then
          Begin
            Inc(jj);
            If IsW(jj, 'as') Then
              Begin
                asname := MTokText(txt, T(jj + 1));
                Inc(jj, 2);
              End;
          End
        Else
          Begin
            Inc(jj);
            While (jj < ntok) And Not IsP(jj, '}') Do
              Begin
                If nn < 60 Then
                  Begin
                    Inc(nn);
                    If T(jj).kind = 3 Then
                      loc[nn] := MStrVal(txt, T(jj))
                    Else
                      loc[nn] := MTokText(txt, T(jj));
                    exn[nn] := loc[nn];
                    Inc(jj);
                    If IsW(jj, 'as') Then
                      Begin
                        If T(jj + 1).kind = 3 Then
                          exn[nn] := MStrVal(txt, T(jj + 1))
                        Else
                          exn[nn] := MTokText(txt, T(jj + 1));
                        Inc(jj, 2);
                      End;
                  End
                Else
                  Inc(jj);
                If IsP(jj, ',') Then
                  Inc(jj);
              End;
            Inc(jj);
          End;
        froms := IsW(jj, 'from');
        e := jj;
        sp := '';
        If froms Then
          Begin
            sp := MStrVal(txt, T(jj + 1));
            MQueueDep(mpath, mkey, sp);
            e := jj + 2;
            If (IsW(e, 'assert') Or IsW(e, 'with')) And IsP(e + 1, '{') Then
              Begin
                e := e + 2;
                While (e < ntok) And Not IsP(e, '}') Do
                  Inc(e);
                Inc(e);
              End;
          End;
        If IsP(e, ';') Then
          Inc(e);
        If starred Then
          Begin
            If asname <> '' Then
              r := 'Object.defineProperty(exports,' + MJsStr(asname) + ',{value:__esm(require(' + MJsStr(sp) + ')),enumerable:true,configurable:true});'
            Else
              r := '__reexpall(exports, require(' + MJsStr(sp) + '));';
          End
        Else If froms Then
          Begin
            pairs := '[';
            For a := 1 To nn Do
              Begin
                If a > 1 Then
                  pairs := pairs + ',';
                pairs := pairs + '[' + MJsStr(loc[a]) + ',' + MJsStr(exn[a]) + ']';
              End;
            r := '__reexp(exports, require(' + MJsStr(sp) + '), ' + pairs + ']);';
          End
        Else
          Begin
            r := '';
            For a := 1 To nn Do
              AddGetter(exn[a], loc[a]);
          End;
        Replace(T(start).s, T(e - 1).e, r);
        i := e - 1;
        has_esm := True;
        Exit;
      End;
    { export const|let|var|function|async function|class }
    isdecl := False;
    If IsW(jj, 'const') Or IsW(jj, 'let') Or IsW(jj, 'var') Then
      Begin
        isdecl := True;
        ng := 0;
        k := jj + 1;
        { liste de declarateurs }
        While k < ntok Do
          Begin
            If IsP(k, '{') Or IsP(k, '[') Then
              k := PatternNames(k)
            Else If T(k).kind = 1 Then
              Begin
                If ng < 200 Then
                  Begin
                    Inc(ng);
                    getter_names[ng] := MTokText(txt, T(k));
                  End;
                Inc(k);
              End
            Else
              Break;
            { initialisation }
            If IsP(k, '=') Then
              Begin
                Inc(k);
                m := 0;
                While k < ntok Do
                  Begin
                    If (m = 0) And (toks^[k].nl) And (k > 0) And Not IsP(k - 1, ',') And Not IsP(k - 1, '=') And
                       Not ((toks^[k].kind = 2) And (txt^[toks^[k].s] In ['.', '+', '-', '*', '/', '(', '[', '?', ':', '&', '|', '>', '<', '%', '^'])) Then
                      Break;
                    If toks^[k].kind = 2 Then
                      Case txt^[toks^[k].s] Of
                        '{', '(', '[': Inc(m);
                        '}', ')', ']':
                          Begin
                            If m = 0 Then
                              Break;
                            Dec(m);
                          End;
                        ',': If m = 0 Then Break;
                        ';': If m = 0 Then Break;
                      End;
                    Inc(k);
                  End;
              End;
            If IsP(k, ',') Then
              Inc(k)
            Else
              Break;
          End;
        For a := 1 To ng Do
          AddGetter(getter_names[a], getter_names[a]);
        Replace(T(start).s, T(jj).s, '');
        has_esm := True;
        Exit;
      End;
    If IsW(jj, 'async') And IsW(jj + 1, 'function') Then
      Inc(jj);
    If IsW(jj, 'function') Or IsW(jj, 'class') Then
      Begin
        m := jj + 1;
        If IsP(m, '*') Then
          Inc(m);
        If T(m).kind = 1 Then
          AddGetter(MTokText(txt, T(m)), MTokText(txt, T(m)));
        Replace(T(start).s, T(start + 1).s, '');
        has_esm := True;
        Exit;
      End;
  End;

Begin
  TbInit(getters);
  tmpn := 0;
  ng := 0;
  has_esm := False;
  copied := 0;
  MTokenize(txt, len, toks, ntok);
  { fin du prologue du fichier : ligne #! et directives ('use strict') }
  head_pos := 0;
  If (len >= 2) And (txt^[0] = '#') And (txt^[1] = '!') Then
    Begin
      head_pos := 0;
      While (head_pos < len) And (txt^[head_pos] <> #10) Do
        Inc(head_pos);
    End;
  i := 0;
  While (i < ntok) And (toks^[i].kind = 3) Do
    Begin
      If IsP(i + 1, ';') Then
        Begin
          head_pos := toks^[i + 1].e;
          Inc(i, 2);
        End
      Else If (i + 1 >= ntok) Or toks^[i + 1].nl Then
        Begin
          head_pos := toks^[i].e;
          Inc(i);
        End
      Else
        Break;
    End;
  depth := 0;
  i := 0;
  While i < ntok Do
    Begin
      If toks^[i].kind = 2 Then
        Case txt^[toks^[i].s] Of
          '{', '(', '[': Inc(depth);
          '}', ')', ']': Dec(depth);
        End
      Else If toks^[i].kind = 1 Then
        Begin
          If MWordEq(txt, toks^[i], 'require') And IsP(i + 1, '(') And (T(i + 2).kind = 3) And IsP(i + 3, ')') And
             Not ((i > 0) And IsP(i - 1, '.')) Then
            MQueueDep(mpath, mkey, MStrVal(txt, T(i + 2)))
          Else If MWordEq(txt, toks^[i], 'import') And Not ((i > 0) And IsP(i - 1, '.')) Then
            Begin
              If IsP(i + 1, '(') Then
                Begin
                  If T(i + 2).kind = 3 Then
                    MQueueDep(mpath, mkey, MStrVal(txt, T(i + 2)));
                  Replace(toks^[i].s, toks^[i].e, '__dynimport');
                End
              Else If IsP(i + 1, '.') And IsW(i + 2, 'meta') Then
                Begin
                  Replace(toks^[i].s, T(i + 2).e,
                          '({url:"file:///"+__filename.replace(/\\/g,"/"),dirname:__dirname,filename:__filename})');
                  i := i + 2;
                End
              Else If depth = 0 Then
                Begin
                  has_esm := True;
                  ProcessImport(i);
                End;
            End
          Else If MWordEq(txt, toks^[i], 'export') And (depth = 0) And Not ((i > 0) And IsP(i - 1, '.')) Then
            ProcessExport(i);
        End;
      Inc(i);
    End;
  TbRange(outb, txt, copied, len);
  FreeMem(toks);
  is_esm := has_esm;
  { le prologue (accesseurs d'exportation) est ajoute par l'appelant }
  If has_esm Or (getters.n > 0) Then
    Begin
      TbAdd(outb, #0);
      TbRange(outb, getters.p, 0, getters.n);
    End;
End;

{ Assemble un module : tete d'origine (#!, directives), prologue, accesseurs d'exportation, puis le reste. }
Procedure MFinishModule(Var src: TTextBuf; Var dst: TTextBuf; is_esm: Boolean; head_pos: LongInt; Var extra: TTextBuf);
Var
  i, z: LongInt;
Begin
  z := -1;
  For i := 0 To src.n - 1 Do
    If src.p^[i] = #0 Then
      Begin
        z := i;
        Break;
      End;
  If z < 0 Then
    z := src.n;
  TbRange(dst, src.p, 0, head_pos);
  If is_esm And (head_pos = 0) Then
    TbStr(dst, '"use strict";');
  If is_esm Then
    TbStr(dst, 'Object.defineProperty(exports,"__esModule",{value:true});');
  If extra.n > 0 Then
    TbRange(dst, extra.p, 0, extra.n);
  If z < src.n Then
    TbRange(dst, src.p, z + 1, src.n);
  TbRange(dst, src.p, head_pos, z);
End;

Procedure ResetSourceText(Var ctx: TCompilerContext; Const b: TTextBuf);
Var
  i, line_len: LongInt;
  c: Char;
Begin
  ctx.source.char_count := 0;
  ctx.source.line_count := 1;
  LineStartP(ctx.source.line_start, 1)^ := 0;
  ctx.source.max_line_len := 0;
  For i := 0 To b.n - 1 Do
    Begin
      c := b.p^[i];
      If c = #13 Then
        Continue;
      SrcCharP(ctx.source.buf, ctx.source.char_count)^ := c;
      Inc(ctx.source.char_count);
      If c = #10 Then
        Begin
          line_len := ctx.source.char_count - 1 - LineStartP(ctx.source.line_start, ctx.source.line_count)^;
          If line_len > ctx.source.max_line_len Then
            ctx.source.max_line_len := line_len;
          Inc(ctx.source.line_count);
          LineStartP(ctx.source.line_start, ctx.source.line_count)^ := ctx.source.char_count;
        End;
    End;
End;

Procedure BundleModules(Var ctx: TCompilerContext);
Var
  txt: PMTextArr;
  len, i, mhead: LongInt;
  mainb, final, hdr, empty, depb: TTextBuf;
  mesm: Boolean;
  abs_main: TString;
  num: String;
Begin
  { texte du programme principal }
  len := ctx.source.char_count;
  GetMem(txt, len + 1);
  For i := 0 To len - 1 Do
    txt^[i] := SrcCharP(ctx.source.buf, i)^;
  mod_count := 0;
  alias_count := 0;
  abs_main := MNormPath(FExpand(NormalizePath(ctx.source_name)));
  mod_main_path := abs_main;
  mod_root := MDirName(abs_main);
  TbInit(mainb);
  MProcess(abs_main, '#main', txt, len, mainb, mesm, mhead);
  { dependances, en largeur }
  i := 1;
  While i <= mod_count Do
    Begin
      mod_list[i].esm := False;
      mod_list[i].head := 0;
      If Not mod_list[i].json Then
        MProcess(mod_list[i].path, mod_list[i].key, mod_list[i].text, mod_list[i].len, mod_list[i].out_text,
                 mod_list[i].esm, mod_list[i].head);
      Inc(i);
    End;
  { en-tete : __filename, __dirname, table des modules }
  TbInit(hdr);
  TbInit(empty);
  TbStr(hdr, '__filename=' + MJsStr(abs_main) + ';__dirname=' + MJsStr(mod_root) + ';');
  If mod_count > 0 Then
    Begin
      TbStr(hdr, '__umods={');
      For i := 1 To mod_count Do
        Begin
          If i > 1 Then
            TbAdd(hdr, ',');
          str(i, num);
          TbStr(hdr, MJsStr(mod_list[i].key) + ':__m' + num);
        End;
      TbStr(hdr, '};__ualias={');
      For i := 1 To alias_count Do
        Begin
          If i > 1 Then
            TbAdd(hdr, ',');
          TbStr(hdr, MJsStr(mod_alias[i].from_key + '|' + mod_alias[i].spec) + ':' + MJsStr(mod_alias[i].target));
        End;
      TbStr(hdr, '};');
    End;
  { assemblage : programme principal, puis chaque module dans une fonction }
  TbInit(final);
  MFinishModule(mainb, final, mesm, mhead, hdr);
  For i := 1 To mod_count Do
    Begin
      str(i, num);
      TbStr(final, #10 + 'function __m' + num + '(exports, require, module, __filename, __dirname) {');
      If mod_list[i].json Then
        Begin
          TbStr(final, 'module.exports = ');
          TbRange(final, mod_list[i].text, 0, mod_list[i].len);
          TbStr(final, ';');
        End
      Else
        MFinishModule(mod_list[i].out_text, final, mod_list[i].esm, mod_list[i].head, empty);
      TbStr(final, #10 + '}');
    End;
  TbAdd(final, #10);
  ResetSourceText(ctx, final);
End;
