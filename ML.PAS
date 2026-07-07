{ @author:      Sylvain Maltais
  @created:     2026
  @website(https://www.gladir.com/dev-cools)
  @abstract:    Target: Turbo Pascal 7 / Free Pascal 3.2 (-Mtp)
  @description: Clone ML.EXE, Macro Assembleur 80386/Win32 (COFF+PE)
  @author:      Sylvain Maltais (support@gladir.com)
  @output:      COFF .OBJ 32 bits + PE32 .EXE (linker interne)
}

{ ================================================================
  ML.PAS - Macro Assembleur 80386 compatible Microsoft ML.EXE
  ================================================================

  Clone de Microsoft Macro Assembler 32 bits (ML.EXE / MASM 6.x+)
  cible 80386 protege / Win32. Contrairement a MASM.PAS (8086/OMF),
  ce fichier produit :
    - des fichiers .OBJ au format COFF 32 bits (IMAGE_FILE_MACHINE_I386)
    - des executables .EXE au format PE32 (via un linker interne,
      sans dependre de LINK.exe externe)

  Syntaxe ligne de commande (calquee sur ML.EXE reel) :
    ML [options] fichier.asm [[options] [fichier.asm] ...] [/link options_de_liaison]

  Options reconnues : /c /Zi /Zd /Fl[fichier] /Fo[fichier] /I[chemin]
  /coff /Cp /D /W0../W2 /nologo /? /help, plus /link <options passees
  au linker interne : /OUT: /SUBSYSTEM: /ENTRY: /LIBPATH: /DEBUG>.

  Assemblage en deux passes (comme MASM.PAS). Architecture generale
  (lexer, table de symboles, evaluateur d'expressions, macros,
  assemblage conditionnel) inspiree de MASM.PAS ; l'encodeur d'
  instructions et le writer PE sont rebatis pour le 32 bits et le
  format COFF/PE (portage du coeur ModRM/SIB de POWFXC32.PAS).

  ================================================================ }

Program ML;

{ ============================================================
  TODO 1 - INFRASTRUCTURE DE BASE
  ============================================================ }

{$Q-} { verifications de depassement arithmetique desactivees : HashName
        et d autres calculs (AlignUp, decalages de checksum...) reposent
        volontairement sur le comportement de retenue/troncature standard
        des types entiers, pas sur une detection de depassement. }

Uses Dos;

Const
  VERSION      = '1.0';
  MAX_SYM      = 8192;   { max symboles (heap) }
  MAX_SEG      = 16;     { max segments/sections definis }
  MAX_GRP      = 8;      { max groupes (compat .MODEL) }
  MAX_FIXUP    = 16384;  { max fixups internes par module }
  MAX_MACRO    = 256;    { max macros definies }
  MAX_STRUCT   = 64;     { max structures STRUC }
  MAX_IF_DEPTH = 32;     { profondeur max des blocs IF imbriques }
  HASH_SIZE    = 256;    { buckets de la table de hachage symboles }
  INC_DEPTH    = 8;      { max niveaux d inclusion INCLUDE }
  MAX_TEXTEQU  = 128;    { max macros texte (TEXTEQU) }
  MAX_PROC_ARG = 32;     { max parametres formels par PROC }
  MAX_IMPORT_DLL  = 16;  { max DLL importees par l executable }
  MAX_IMPORT_FUNC = 512; { max fonctions importees (toutes DLL confondues) }
  MAX_SRCFILES = 32;     { max fichiers .asm sur la ligne de commande }
  MAX_INCPATH  = 16;     { max chemins /I }

  { Index fixes des 4 sections COFF predefinies (modele FLAT) }
  SEC_TEXT  = 1; { .text  - code, CODE/EXECUTE/READ }
  SEC_DATA  = 2; { .data  - donnees initialisees, READ/WRITE }
  SEC_BSS   = 3; { .bss   - donnees non initialisees, READ/WRITE }
  SEC_RDATA = 4; { .rdata - donnees en lecture seule + tables d import }
  NUM_FIXED_SEC = 4;

{ ---- Types de base ---- }
Type
  TString    = String[200]; { chaine generale (lignes source, noms) }
  TSymString = String[64];  { nom de symbole/segment (uppercase) }
  TByte      = Byte;
  TWord      = Word;
  TLong      = LongInt;

  { Genres de tokens produits par le lexer }
  TTokenKind = (
    TK_IDENT,    { identificateur ou mot-cle / directive / mnemonic / registre }
    TK_NUMBER,   { literal numerique (dec/hex/oct/bin) }
    TK_STRING,   { chaine litterale delimitee par ' ou " }
    TK_PUNCT,    { operateur ou ponctuation ( ) [ ] + - * / . : , = }
    TK_NEWLINE,  { fin de ligne logique (separateur d instruction) }
    TK_EOF       { fin de fichier source }
  );

  { Genre d un symbole dans la table des symboles }
  TSymKind = (
    SK_UNDEF,    { reference avant non encore resolue }
    SK_LABEL,    { etiquette de code ou de donnee }
    SK_PUBLIC,   { symbole exporte (PUBLIC) }
    SK_EXTERN,   { symbole importe (EXTRN/EXTERN) }
    SK_EQU,      { constante EQU (non reassignable) ou = (reassignable) }
    SK_GROUP,    { nom de groupe (GROUP), compat }
    SK_SEG,      { nom de segment (SEGMENT) }
    SK_MACRO,    { macro (MACRO/ENDM) }
    SK_TEXTEQU,  { macro texte (TEXTEQU / EQU sans valeur numerique) }
    SK_STRUCT,   { structure de donnees (STRUC/ENDS) }
    SK_PROC      { procedure haut niveau (PROC/ENDP) }
  );

  { Taille d un operande memoire/donnee }
  TDataSize = (
    DS_BYTE,     { 1 octet   - DB / BYTE }
    DS_WORD,     { 2 octets  - DW / WORD }
    DS_DWORD,    { 4 octets  - DD / DWORD }
    DS_QWORD,    { 8 octets  - DQ / QWORD }
    DS_TBYTE,    { 10 octets - DT / TBYTE }
    DS_OWORD,    { 16 octets - DO / OWORD / XMMWORD }
    DS_UNKNOWN   { taille non specifiee / non applicable }
  );

  { Categories de registres 80386+ }
  TRegKind = (
    RK_NONE, { pas un registre }
    RK_8,    { AL CL DL BL AH CH DH BH }
    RK_16,   { AX CX DX BX SP BP SI DI }
    RK_32,   { EAX ECX EDX EBX ESP EBP ESI EDI }
    RK_SEG,  { ES CS SS DS FS GS }
    RK_ST,   { ST(0)..ST(7) FPU }
    RK_MM,   { MM0..MM7 MMX }
    RK_XMM,  { XMM0..XMM7 SSE }
    RK_CR,   { CR0..CR4 }
    RK_DR    { DR0..DR7 }
  );

  TReg = Record
    kind : TRegKind; { categorie du registre }
    idx  : TByte;    { index 0..7 (0..4 pour CR) }
  End;

  { Token produit par le lexer }
  TToken = Record
    kind     : TTokenKind; { type de token }
    val      : TString;    { valeur textuelle (toujours en majuscules pour idents) }
    raw      : TString;    { valeur textuelle originale (casse preservee, pour STRING) }
    num_val  : TLong;      { valeur numerique (valide si TK_NUMBER) }
    line_num : Integer;    { numero de ligne source logique }
  End;

  { ------- Genre d operande apres analyse syntaxique ------- }
  TOpKind = (
    OPK_NONE,  { operande absent }
    OPK_REG,   { registre pur }
    OPK_MEM,   { operande memoire [base+index*scale+disp] }
    OPK_IMM,   { valeur immediate / expression constante ou relogeable }
    OPK_ST     { registre FPU ST(n), garde separe de OPK_REG pour la forme texte "ST(n)" }
  );

  { ------- Resultat d une evaluation d expression ------- }
  TExpr = Record
    val        : TLong;    { valeur numerique de l expression }
    is_reloc   : Boolean;  { True = adresse relogeable (label/donnee) }
    seg_idx    : Integer;  { index 1..NUM_FIXED_SEC de la section cible si is_reloc }
    is_undef   : Boolean;  { True = symbole inconnu en passe 1 (reporter passe 2) }
    is_extern  : Boolean;  { True = symbole externe (import), fixup par nom }
    sym_name   : TSymString; { nom du symbole si is_reloc/is_extern/is_undef }
    ptr_size   : Integer;  { 0=non specifie,1=BYTE,2=WORD,4=DWORD,8=QWORD,10=TBYTE,16=OWORD }
    is_offset_form : Boolean; { True = expression construite via OFFSET (adresse
                                voulue explicitement) ; False = reference nue a
                                un label, qui doit etre DEREFERENCEE (semantique
                                MASM) plutot que traitee comme une adresse }
  End;

  { ------- Operande d instruction totalement analyse ------- }
  TOperand = Record
    kind        : TOpKind;
    reg         : TReg;      { registre (OPK_REG/OPK_ST) }
    has_base    : Boolean;   { OPK_MEM : registre de base present }
    base_reg    : TReg;
    has_index   : Boolean;   { OPK_MEM : registre d index present }
    index_reg   : TReg;
    scale       : TByte;     { 1,2,4,8 }
    disp        : TExpr;     { deplacement (constante et/ou relogeable) }
    has_disp    : Boolean;
    seg_ovr     : Integer;   { 0=aucun, 1..6 = ES,CS,SS,DS,FS,GS }
    size_hint   : TDataSize; { taille explicite (BYTE PTR, DWORD PTR, ...) }
    imm         : TExpr;     { OPK_IMM : valeur }
    is_indirect_call : Boolean; { CALL/JMP via registre ou memoire (pas relatif) }
  End;

  { ------- Table des symboles (allocation dynamique sur le heap) ------- }
  PSymbol = ^TSymbol;
  TSymbol = Record
    name     : TSymString; { nom du symbole (uppercase) }
    orig     : TSymString; { nom original (casse preservee, pour l export COFF) }
    kind     : TSymKind;   { genre du symbole }
    seg_idx  : Integer;    { index section 1..NUM_FIXED_SEC (0 = absolu/externe) }
    offset   : TLong;      { offset dans la section au moment de la definition }
    value    : TLong;      { valeur absolue (SK_EQU) }
    size     : TLong;      { taille en octets (labels de donnee, STRUC, PROC) }
    flags    : TByte;      { bit0=public bit1=extern bit2=defini bit3=proc-stdcall bit4=proc-c }
    text_val : TString;    { valeur texte (SK_TEXTEQU) }
    proc_argbytes : TLong; { PROC: total octets de parametres (pour RET n) }
    next     : PSymbol;    { maillon suivant dans la chaine de hachage }
  End;

  { ------- Sections COFF (4 fixes + extensions via SEGMENT) ------- }
  TSegInfo = Record
    name       : TSymString;  { nom textuel (.text, .data, .bss, .rdata ou nom SEGMENT) }
    class_name : TSymString;  { classe MASM (CODE/DATA/CONST/STACK/BSS) }
    is_bss     : Boolean;     { True = pas de donnees physiques (uninitialized) }
    cur_lc     : TLong;       { location counter courant (taille logique accumulee) }
    defined    : Boolean;     { True si la section a ete utilisee }
  End;

{ ---- Variables globales ---- }
Var
  { Tables de la chaine de hachage (symboles sur le heap) }
  hash_table : Array[0..HASH_SIZE-1] Of PSymbol;

  { Sections fixes (index 1..NUM_FIXED_SEC utilises, MAX_SEG reserve pour extension) }
  seg_table  : Array[1..MAX_SEG] Of TSegInfo;
  seg_count  : Integer;

  { Compteurs de tables }
  sym_count  : Integer;  { nb de PSymbol alloues sur le heap }

  { Etat de l assemblage }
  pass_num   : Integer;  { passe courante : 1 ou 2 }
  err_count  : Integer;  { nb d erreurs detectees }
  warn_count : Integer;  { nb d avertissements }
  cur_seg    : Integer;  { index section courante dans seg_table (0=hors segment) }
  use32_mode : Boolean;  { True apres .386/.486/.586/.686 (toujours True en pratique) }
  flat_model : Boolean;  { True apres .MODEL FLAT }

  { Fichiers }
  src_fname  : TString;  { nom du fichier source .ASM courant }
  obj_fname  : TString;  { nom du fichier objet  .OBJ courant }
  lst_fname  : TString;  { nom du fichier listing .LST }
  exe_fname  : TString;  { nom de l executable final .EXE }
  do_listing : Boolean;  { True = generer le fichier .LST }
  assemble_only : Boolean; { True = /c, pas d edition de liens }

  { Options ligne de commande }
  warn_level      : Integer;  { /W0-2 = niveau d avertissement }
  nologo_mode     : Boolean;  { /nologo = pas de banniere }
  debug_info      : Boolean;  { /Zi /Zd = info debug (acceptee, non emise) }
  inc_paths       : Array[1..MAX_INCPATH] Of TString;
  inc_path_count  : Integer;

  { Ligne de source courante (pour messages d erreur) }
  cur_line   : TString;  { contenu de la ligne en cours d analyse }
  cur_lineno : Integer;  { numero de ligne logique (apres continuation) }

  { Controle d emission (passe 1 = True => avancer LC sans ecrire) }
  no_emit    : Boolean;

  { Options de link (apres /link, transmises au linker interne) }
  link_subsystem : TSymString; { CONSOLE ou WINDOWS }
  link_entry     : TSymString; { nom du symbole d entree, vide = auto }
  link_out       : TString;    { nom .exe explicite via /OUT: }

  show_err_lines : Boolean;    { True = afficher la ligne source en erreur }

{ ============================================================
  MESSAGES D ERREUR / AVERTISSEMENT
  ============================================================ }

{ ============================================================
  ErrorMsg : afficher un message d erreur (style ML A2xxx)
  ============================================================ }
Procedure ErrorMsg(Const msg : TString);
Begin
  Inc(err_count);
  If src_fname <> '' Then
    Writeln(src_fname, '(', cur_lineno, ') : error A2',
            err_count:3, ': ', msg)
  Else
    Writeln('error A2', err_count:3, ': ', msg);
  If show_err_lines And (cur_line <> '') Then
    Writeln('  ', cur_line);
End;

{ ============================================================
  WarnMsg : afficher un avertissement (style ML A4xxx)
  ============================================================ }
Procedure WarnMsg(Const msg : TString);
Begin
  If warn_level = 0 Then Exit;
  Inc(warn_count);
  If src_fname <> '' Then
    Writeln(src_fname, '(', cur_lineno, ') : warning A4',
            warn_count:3, ': ', msg)
  Else
    Writeln('warning A4', warn_count:3, ': ', msg);
End;

{ ============================================================
  LECTEUR DE SOURCE ET GESTIONNAIRE D INCLUSION
  ============================================================
  Principe identique a MASM.PAS : pile de max INC_DEPTH contextes
  de fichier, lignes logiques avec continuation par \ en fin de
  ligne et suppression du commentaire ;.
  ============================================================ }

{ ---- Types de la pile d inclusion ---- }
Type
  TSrcContext = Record
    f        : Text;         { fichier Pascal ouvert }
    fname    : TString;      { nom du fichier }
    lineno   : Integer;      { dernier numero de ligne physique lu }
    is_open  : Boolean;      { True si le fichier est ouvert }
  End;

{ ---- Variables du lecteur de source ---- }
Var
  src_stack  : Array[0..INC_DEPTH-1] Of TSrcContext; { pile d inclusion }
  src_top    : Integer;  { indice du contexte courant (-1 = vide) }
  phys_lineno: Integer;  { compteur de lignes physiques global }

  { Table TEXTEQU (macros texte) et predefined strings }
  textequ_names : Array[1..MAX_TEXTEQU] Of TSymString;
  textequ_vals  : Array[1..MAX_TEXTEQU] Of TString;
  textequ_count : Integer;

  { Predefined string values (mises a jour en cours d assemblage) }
  predef_date : TString;  { date assemblage 'MM/DD/YY' }
  predef_time : TString;  { heure assemblage 'HH:MM:SS' }

{ ============================================================
  SrcInit : initialiser la pile d inclusion
  ============================================================ }
Procedure SrcInit;
Var
  i : Integer;
Begin
  src_top     := -1;
  phys_lineno := 0;
  textequ_count := 0;
  predef_date := '';
  predef_time := '';
  For i := 0 To INC_DEPTH-1 Do
  Begin
    src_stack[i].fname   := '';
    src_stack[i].lineno  := 0;
    src_stack[i].is_open := False;
  End;
End;

{ ============================================================
  SrcAtEnd : True si la pile est vide (plus rien a lire)
  ============================================================ }
Function SrcAtEnd : Boolean;
Begin
  SrcAtEnd := (src_top < 0);
End;

{ ============================================================
  SrcFindFile : chercher fname dans le repertoire courant puis
  dans inc_paths (/I) ; retourne le chemin complet trouve ou fname
  si non trouve.
  ============================================================ }
Function SrcFindFile(Const fname : TString) : TString;
Var
  i    : Integer;
  path : TString;
  tmp  : Text;
  env  : TString;
  ep   : Integer;
  es   : Integer;
  edr  : TString;
Begin
  { 1. tel quel (absolu ou relatif au CWD) }
  Assign(tmp, fname);
  {$I-}
  Reset(tmp);
  {$I+}
  If IoResult = 0 Then
  Begin
    Close(tmp);
    SrcFindFile := fname;
    Exit;
  End;
  { 2. dans les repertoires /I }
  For i := 1 To inc_path_count Do
  Begin
    path := inc_paths[i];
    If (Length(path) > 0) And (path[Length(path)] <> '\') Then
      path := path + '\';
    path := path + fname;
    Assign(tmp, path);
    {$I-}
    Reset(tmp);
    {$I+}
    If IoResult = 0 Then
    Begin
      Close(tmp);
      SrcFindFile := path;
      Exit;
    End;
  End;
  { 3. dans la variable d environnement INCLUDE (separateur ;) }
  env := GetEnv('INCLUDE');
  If env <> '' Then
  Begin
    ep := 1;
    While ep <= Length(env) Do
    Begin
      es := ep;
      While (ep <= Length(env)) And (env[ep] <> ';') Do Inc(ep);
      edr := Copy(env, es, ep - es);
      Inc(ep); { sauter le ; }
      If edr <> '' Then
      Begin
        If edr[Length(edr)] <> '\' Then edr := edr + '\';
        path := edr + fname;
        Assign(tmp, path);
        {$I-}
        Reset(tmp);
        {$I+}
        If IoResult = 0 Then
        Begin
          Close(tmp);
          SrcFindFile := path;
          Exit;
        End;
      End;
    End;
  End;
  SrcFindFile := fname; { non trouve, retourner tel quel }
End;

{ ============================================================
  SrcPush : ouvrir un fichier et l empiler
  ============================================================ }
Procedure SrcPush(Const fn : TString);
Var
  rpath : TString;
Begin
  If src_top >= INC_DEPTH-1 Then
  Begin
    ErrorMsg('INCLUDE trop profond (max ' +
             Chr(Ord('0') + INC_DEPTH) + ' niveaux)');
    Exit;
  End;
  rpath := SrcFindFile(fn);
  Inc(src_top);
  With src_stack[src_top] Do
  Begin
    fname   := rpath;
    lineno  := 0;
    is_open     := False;
    Assign(f, rpath);
    {$I-}
    Reset(f);
    {$I+}
    If IoResult <> 0 Then
    Begin
      Dec(src_top);
      ErrorMsg('Impossible d ouvrir le fichier : ' + rpath);
      Exit;
    End;
    is_open := True;
  End;
  src_fname := src_stack[src_top].fname;
End;

{ ============================================================
  SrcPop : fermer le fichier courant et depiler
  ============================================================ }
Procedure SrcPop;
Begin
  If src_top < 0 Then Exit;
  With src_stack[src_top] Do
    If is_open Then
    Begin
      Close(f);
      is_open := False;
    End;
  Dec(src_top);
  If src_top >= 0 Then
    src_fname := src_stack[src_top].fname
  Else
    src_fname := '';
End;

{ ============================================================
  SrcStripComment : supprimer le commentaire (;) d une ligne,
  en respectant les chaines entre guillemets simples ou doubles.
  ============================================================ }
Function SrcStripComment(Const line : TString) : TString;
Var
  i      : Integer;
  in_sq  : Boolean;
  in_dq  : Boolean;
  c      : Char;
  result : TString;
Begin
  in_sq  := False;
  in_dq  := False;
  result := '';
  For i := 1 To Length(line) Do
  Begin
    c := line[i];
    If (c = '''') And Not in_dq Then in_sq := Not in_sq
    Else If (c = '"') And Not in_sq Then in_dq := Not in_dq
    Else If (c = ';') And Not in_sq And Not in_dq Then
      Break;
    result := result + c;
  End;
  While (Length(result) > 0) And (result[Length(result)] = ' ') Do
    Delete(result, Length(result), 1);
  SrcStripComment := result;
End;

{ ============================================================
  SrcExpandTabs : remplacer les tabulations par des espaces
  (tabstop = 8).
  ============================================================ }
Function SrcExpandTabs(Const line : TString) : TString;
Var
  i      : Integer;
  col    : Integer;
  result : TString;
  spaces : Integer;
  j      : Integer;
Begin
  result := '';
  col    := 1;
  For i := 1 To Length(line) Do
  Begin
    If line[i] = #9 Then
    Begin
      spaces := 8 - ((col-1) Mod 8);
      For j := 1 To spaces Do
      Begin
        result := result + ' ';
        Inc(col);
      End;
    End
    Else
    Begin
      result := result + line[i];
      Inc(col);
    End;
  End;
  SrcExpandTabs := result;
End;

{ ============================================================
  SrcIsContinued : True si la ligne se termine par \ (continuation)
  ============================================================ }
Function SrcIsContinued(Var line : TString) : Boolean;
Var
  trimmed : TString;
  len     : Integer;
Begin
  trimmed := line;
  While (Length(trimmed) > 0) And (trimmed[Length(trimmed)] = ' ') Do
    Delete(trimmed, Length(trimmed), 1);
  len := Length(trimmed);
  If (len > 0) And (trimmed[len] = '\') Then
  Begin
    Delete(trimmed, len, 1);
    While (Length(trimmed) > 0) And (trimmed[Length(trimmed)] = ' ') Do
      Delete(trimmed, Length(trimmed), 1);
    line := trimmed;
    SrcIsContinued := True;
  End
  Else
  Begin
    line := trimmed;
    SrcIsContinued := False;
  End;
End;

{ ============================================================
  SrcReadLine : lire la prochaine ligne logique du fichier
  courant (avec continuation et pre-traitement).
  ============================================================ }
Function SrcReadLine : Boolean;
Var
  raw     : TString;
  logical : TString;
  cont    : Boolean;
Begin
  SrcReadLine := False;
  If SrcAtEnd Then Exit;

  logical := '';
  Repeat
    While (src_top >= 0) And Eof(src_stack[src_top].f) Do
      SrcPop;
    If SrcAtEnd Then
    Begin
      If logical <> '' Then Break;
      Exit;
    End;

    ReadLn(src_stack[src_top].f, raw);
    Inc(src_stack[src_top].lineno);
    Inc(phys_lineno);

    raw := SrcExpandTabs(raw);
    raw := SrcStripComment(raw);

    cont := SrcIsContinued(raw);
    If logical <> '' Then
      logical := logical + ' ' + raw
    Else
      logical := raw;
  Until Not cont;

  cur_lineno := src_stack[src_top].lineno;
  cur_line   := logical;
  SrcReadLine := True;
End;

{ ============================================================
  FILE D EXPANSION DE MACROS - permet a une macro invoquee
  d injecter ses lignes de corps (deja substituees) avant de
  reprendre la lecture normale du fichier source. Empile comme
  la pile d inclusion pour gerer l imbrication (une macro peut
  en invoquer une autre dans son corps).
  ============================================================ }
Const
  MAX_MACRO_BODY_LINES = 128;
  MAX_MACRO_EXP_DEPTH   = 8;
Type
  TMacroExpCtx = Record
    lines : Array[1..MAX_MACRO_BODY_LINES] Of TString;
    count : Integer;
    idx   : Integer;
  End;
Var
  macro_exp_stack : Array[0..MAX_MACRO_EXP_DEPTH-1] Of TMacroExpCtx;
  macro_exp_top   : Integer; { -1 = pile vide }

Procedure MacroExpInit;
Begin
  macro_exp_top := -1;
End;

Procedure BeginMacroExpansion;
Begin
  If macro_exp_top >= MAX_MACRO_EXP_DEPTH - 1 Then
  Begin
    ErrorMsg('Imbrication de macros trop profonde');
    Exit;
  End;
  Inc(macro_exp_top);
  macro_exp_stack[macro_exp_top].count := 0;
  macro_exp_stack[macro_exp_top].idx   := 1;
End;

Procedure AddMacroExpLine(Const s : TString);
Begin
  If macro_exp_top < 0 Then Exit;
  With macro_exp_stack[macro_exp_top] Do
    If count < MAX_MACRO_BODY_LINES Then
    Begin
      Inc(count);
      lines[count] := s;
    End;
End;

{ ============================================================
  NextLogicalLine : fournit la prochaine ligne logique au lexer,
  en priorite depuis la pile d expansion de macros, sinon depuis
  le lecteur de fichier source normal (SrcReadLine, qui remplit
  deja cur_line/cur_lineno).
  ============================================================ }
Function NextLogicalLine : Boolean;
Begin
  While macro_exp_top >= 0 Do
  Begin
    If macro_exp_stack[macro_exp_top].idx <= macro_exp_stack[macro_exp_top].count Then
    Begin
      cur_line := macro_exp_stack[macro_exp_top].lines[macro_exp_stack[macro_exp_top].idx];
      Inc(macro_exp_stack[macro_exp_top].idx);
      NextLogicalLine := True;
      Exit;
    End;
    Dec(macro_exp_top);
  End;
  NextLogicalLine := SrcReadLine;
End;

{ ============================================================
  TEXTEQU / SYMBOLES PREDEFINIS
  ============================================================ }

Function TextEquFind(Const name : TSymString) : Integer;
Var i : Integer;
Begin
  TextEquFind := 0;
  For i := 1 To textequ_count Do
    If textequ_names[i] = name Then
    Begin
      TextEquFind := i;
      Exit;
    End;
End;

Procedure TextEquSet(Const name : TSymString; Const val : TString);
Var i : Integer;
Begin
  i := TextEquFind(name);
  If i = 0 Then
  Begin
    If textequ_count >= MAX_TEXTEQU Then Exit;
    Inc(textequ_count);
    i := textequ_count;
  End;
  textequ_names[i] := name;
  textequ_vals[i]  := val;
End;

Function TextEquGet(Const name : TSymString) : TString;
Var i : Integer;
Begin
  i := TextEquFind(name);
  If i > 0 Then TextEquGet := textequ_vals[i]
  Else           TextEquGet := '';
End;

{ ============================================================
  TextEquSubstLine : substituer les macros texte dans une ligne
  source (respecte les chaines entre ' et ").
  ============================================================ }
Function TextEquSubstLine(Const s : TString) : TString;
Var
  i      : Integer;
  c      : Char;
  in_sq  : Boolean;
  in_dq  : Boolean;
  id_st  : Integer;
  id     : TSymString;
  uname  : TSymString;
  val    : TString;
  res    : TString;
Begin
  res   := '';
  in_sq := False;
  in_dq := False;
  i     := 1;
  While i <= Length(s) Do
  Begin
    c := s[i];
    If (c = '''') And Not in_dq Then Begin in_sq := Not in_sq; res := res + c; Inc(i); Continue; End;
    If (c = '"')  And Not in_sq Then Begin in_dq := Not in_dq; res := res + c; Inc(i); Continue; End;
    If in_sq Or in_dq Then Begin res := res + c; Inc(i); Continue; End;

    If (c = '@') Or (c = '_') Or ((c >= 'A') And (c <= 'Z'))
                               Or ((c >= 'a') And (c <= 'z')) Then
    Begin
      id_st := i;
      id := '';
      While (i <= Length(s)) And
            ((s[i] = '@') Or (s[i] = '_') Or
             ((s[i] >= 'A') And (s[i] <= 'Z')) Or
             ((s[i] >= 'a') And (s[i] <= 'z')) Or
             ((s[i] >= '0') And (s[i] <= '9'))) Do
      Begin
        If Length(id) < 63 Then
        Begin
          c := s[i];
          If (c >= 'a') And (c <= 'z') Then c := Chr(Ord(c) - 32);
          id := id + c;
        End;
        Inc(i);
      End;
      uname := id;
      val   := TextEquGet(uname);
      If val <> '' Then
        res := res + val
      Else
        res := res + Copy(s, id_st, i - id_st);
    End
    Else
    Begin
      res := res + c;
      Inc(i);
    End;
  End;
  TextEquSubstLine := res;
End;

Function Pad2(n : Word) : TString;
Var s : TString;
Begin
  Str(n Mod 100, s);
  If Length(s) < 2 Then s := '0' + s;
  Pad2 := s;
End;

{ ============================================================
  InitPredefDateTimeFilename : calculer @DATE, @TIME, @FILENAME
  ============================================================ }
Procedure InitPredefDateTimeFilename(Const fname : TString);
Var
  yr, mo, dy, dow : Word;
  hr, mn, sc, sc2 : Word;
  fi : Integer;
  fn : TString;
Begin
  GetDate(yr, mo, dy, dow);
  GetTime(hr, mn, sc, sc2);
  predef_date := Pad2(mo) + '/' + Pad2(dy) + '/' + Pad2(yr Mod 100);
  predef_time := Pad2(hr) + ':' + Pad2(mn) + ':' + Pad2(sc);
  TextEquSet('@DATE',     predef_date);
  TextEquSet('@TIME',     predef_time);
  fi := Length(fname);
  While (fi > 0) And (fname[fi] <> '\') And (fname[fi] <> '/') Do Dec(fi);
  fn := Copy(fname, fi+1, Length(fname)-fi);
  fi := Length(fn);
  While (fi > 0) And (fn[fi] <> '.') Do Dec(fi);
  If fi > 0 Then fn := Copy(fn, 1, fi-1);
  TextEquSet('@FILENAME', fn);
End;

{ ============================================================
  LEXER (ANALYSEUR LEXICAL)
  ============================================================
  Travaille sur la ligne logique courante (lex_line). Quand la
  ligne est epuisee, appelle SrcReadLine et retourne TK_NEWLINE.
  Tous les identificateurs sont convertis en majuscules.
  ============================================================ }

Var
  lex_line     : TString;
  lex_pos      : Integer;
  lex_tok      : TToken;
  lex_peek_tok : TToken;
  lex_has_peek : Boolean;
  lex_at_eol   : Boolean;

Function LexUpperCase(Const s : TString) : TString;
Var
  i   : Integer;
  res : TString;
  c   : Char;
Begin
  res := '';
  For i := 1 To Length(s) Do
  Begin
    c := s[i];
    If (c >= 'a') And (c <= 'z') Then
      res := res + Chr(Ord(c) - 32)
    Else
      res := res + c;
  End;
  LexUpperCase := res;
End;

Function LexIsAlpha(c : Char) : Boolean;
Begin
  LexIsAlpha := ((c >= 'A') And (c <= 'Z')) Or
                ((c >= 'a') And (c <= 'z'));
End;

Function LexIsDigit(c : Char) : Boolean;
Begin
  LexIsDigit := (c >= '0') And (c <= '9');
End;

Function LexIsHexDigit(c : Char) : Boolean;
Begin
  LexIsHexDigit := ((c >= '0') And (c <= '9')) Or
                   ((c >= 'A') And (c <= 'F')) Or
                   ((c >= 'a') And (c <= 'f'));
End;

Function LexIsAlNum(c : Char) : Boolean;
Begin
  LexIsAlNum := LexIsAlpha(c) Or LexIsDigit(c) Or
                (c = '_') Or (c = '$') Or (c = '@') Or (c = '?');
End;

Function LexHexVal(c : Char) : Integer;
Begin
  If (c >= '0') And (c <= '9') Then LexHexVal := Ord(c) - Ord('0')
  Else If (c >= 'a') And (c <= 'f') Then LexHexVal := Ord(c) - Ord('a') + 10
  Else LexHexVal := Ord(c) - Ord('A') + 10;
End;

Procedure LexInit;
Begin
  lex_line         := '';
  lex_pos          := 1;
  lex_has_peek     := False;
  lex_at_eol       := True;
  lex_tok.kind     := TK_EOF;
  lex_tok.val      := '';
  lex_tok.raw      := '';
  lex_tok.num_val  := 0;
  lex_tok.line_num := 0;
  lex_peek_tok     := lex_tok;
End;

Procedure LexSkipSpaces;
Begin
  While (lex_pos <= Length(lex_line)) And
        (lex_line[lex_pos] = ' ') Do
    Inc(lex_pos);
End;

{ Supporte : 0FFh (hex), 0x1AF (hex), 1010b (binaire), 777q/777o (octal) }
Procedure LexReadNumber(Var tok : TToken);
Var
  raw  : TString;
  suf  : Char;
  v    : TLong;
  i    : Integer;
  c    : Char;
  ok   : Boolean;
Begin
  raw := '';
  If (lex_pos + 1 <= Length(lex_line)) And
     (lex_line[lex_pos] = '0') And
     ((lex_line[lex_pos+1] = 'x') Or (lex_line[lex_pos+1] = 'X')) Then
  Begin
    Inc(lex_pos, 2);
    While (lex_pos <= Length(lex_line)) And
          LexIsHexDigit(lex_line[lex_pos]) Do
    Begin
      raw := raw + lex_line[lex_pos];
      Inc(lex_pos);
    End;
    v := 0;
    For i := 1 To Length(raw) Do
      v := v * 16 + LexHexVal(raw[i]);
    tok.kind    := TK_NUMBER;
    tok.val     := '0X' + LexUpperCase(raw);
    tok.num_val := v;
    Exit;
  End;

  While (lex_pos <= Length(lex_line)) And
        (LexIsHexDigit(lex_line[lex_pos]) Or
         (lex_line[lex_pos] = '_')) Do
  Begin
    raw := raw + lex_line[lex_pos];
    Inc(lex_pos);
  End;
  suf := ' ';
  If lex_pos <= Length(lex_line) Then
  Begin
    c := lex_line[lex_pos];
    If (c = 'h') Or (c = 'H') Then Begin suf := 'H'; Inc(lex_pos); End
    Else If (c = 'b') Or (c = 'B') Then Begin suf := 'B'; Inc(lex_pos); End
    Else If (c = 'o') Or (c = 'O') Then Begin suf := 'O'; Inc(lex_pos); End
    Else If (c = 'q') Or (c = 'Q') Then Begin suf := 'Q'; Inc(lex_pos); End
    Else If (c = 'd') Or (c = 'D') Then Begin suf := 'D'; Inc(lex_pos); End;
    If (suf <> ' ') And (lex_pos <= Length(lex_line)) And
       LexIsAlNum(lex_line[lex_pos]) Then
    Begin
      Dec(lex_pos);
      suf := ' ';
    End;
  End;

  v  := 0;
  ok := True;
  Case suf Of
    'H' : Begin
            For i := 1 To Length(raw) Do
            Begin
              If Not LexIsHexDigit(raw[i]) Then Begin ok := False; Break; End;
              v := v * 16 + LexHexVal(raw[i]);
            End;
          End;
    'B' : Begin
            For i := 1 To Length(raw) Do
            Begin
              If (raw[i] <> '0') And (raw[i] <> '1') Then
                Begin ok := False; Break; End;
              v := v * 2 + (Ord(raw[i]) - Ord('0'));
            End;
          End;
    'O','Q' : Begin
            For i := 1 To Length(raw) Do
            Begin
              If (raw[i] < '0') Or (raw[i] > '7') Then
                Begin ok := False; Break; End;
              v := v * 8 + (Ord(raw[i]) - Ord('0'));
            End;
          End;
    Else
          Begin
            For i := 1 To Length(raw) Do
            Begin
              If Not LexIsDigit(raw[i]) Then
              Begin
                ok := False;
                Break;
              End;
              v := v * 10 + (Ord(raw[i]) - Ord('0'));
            End;
          End;
  End;
  If Not ok Then
  Begin
    WarnMsg('Litteral numerique invalide : ' + raw);
    v := 0;
  End;
  tok.kind    := TK_NUMBER;
  tok.val     := raw + suf;
  tok.num_val := v;
End;

Procedure LexReadString(Var tok : TToken; q : Char);
Var
  s : TString;
Begin
  s := '';
  Inc(lex_pos);
  While lex_pos <= Length(lex_line) Do
  Begin
    If lex_line[lex_pos] = q Then
    Begin
      Inc(lex_pos);
      Break;
    End;
    s := s + lex_line[lex_pos];
    Inc(lex_pos);
  End;
  tok.kind    := TK_STRING;
  tok.val     := s;
  tok.raw     := s;
  tok.num_val := 0;
End;

Procedure LexReadIdent(Var tok : TToken);
Var
  s : TString;
Begin
  s := '';
  While (lex_pos <= Length(lex_line)) And
        LexIsAlNum(lex_line[lex_pos]) Do
  Begin
    s := s + lex_line[lex_pos];
    Inc(lex_pos);
  End;
  tok.kind    := TK_IDENT;
  tok.val     := LexUpperCase(s);
  tok.raw     := s;
  tok.num_val := 0;
End;

Procedure LexNextRaw(Var tok : TToken);
Var
  c : Char;
Begin
  tok.line_num := cur_lineno;
  tok.num_val  := 0;
  tok.raw      := '';

  LexSkipSpaces;

  If lex_pos > Length(lex_line) Then
  Begin
    tok.kind := TK_NEWLINE;
    tok.val  := '';
    Exit;
  End;

  c := lex_line[lex_pos];

  If LexIsDigit(c) Then
  Begin
    LexReadNumber(tok);
    Exit;
  End;

  If (c = '''') Or (c = '"') Then
  Begin
    LexReadString(tok, c);
    Exit;
  End;

  If LexIsAlpha(c) Or (c = '_') Or (c = '$') Or (c = '@') Or (c = '?') Then
  Begin
    LexReadIdent(tok);
    Exit;
  End;

  { Directive avec point initial (.CODE .DATA .MODEL .386 etc.) }
  If c = '.' Then
  Begin
    If (lex_pos+1 <= Length(lex_line)) And
       (LexIsAlpha(lex_line[lex_pos+1]) Or LexIsDigit(lex_line[lex_pos+1])) Then
    Begin
      Inc(lex_pos);
      LexReadIdent(tok);
      tok.val := '.' + tok.val;
      Exit;
    End;
  End;

  Inc(lex_pos);
  tok.kind := TK_PUNCT;
  tok.val  := c;
  If lex_pos <= Length(lex_line) Then
  Begin
    If (c = '<') And (lex_line[lex_pos] = '<') Then
      Begin tok.val := '<<'; Inc(lex_pos); End
    Else If (c = '>') And (lex_line[lex_pos] = '>') Then
      Begin tok.val := '>>'; Inc(lex_pos); End
    Else If (c = '<') And (lex_line[lex_pos] = '>') Then
      Begin tok.val := '<>'; Inc(lex_pos); End
    Else If (c = '=') And (lex_line[lex_pos] = '=') Then
      Begin tok.val := '=='; Inc(lex_pos); End;
  End;
End;

Procedure LexNext;
Begin
  If lex_has_peek Then
  Begin
    lex_tok      := lex_peek_tok;
    lex_has_peek := False;
    Exit;
  End;

  If lex_at_eol Then
  Begin
    lex_at_eol := False;
    If Not NextLogicalLine Then
    Begin
      lex_tok.kind     := TK_EOF;
      lex_tok.val      := '';
      lex_tok.num_val  := 0;
      lex_tok.line_num := cur_lineno;
      Exit;
    End;
    lex_line := TextEquSubstLine(cur_line);
    lex_pos  := 1;
    lex_tok.kind     := TK_NEWLINE;
    lex_tok.val      := '';
    lex_tok.num_val  := 0;
    lex_tok.line_num := cur_lineno;
    Exit;
  End;

  LexNextRaw(lex_tok);

  If lex_tok.kind = TK_NEWLINE Then
    lex_at_eol := True;
End;

Procedure LexEnsurePeek;
Var
  saved_tok : TToken;
Begin
  If lex_has_peek Then Exit;
  saved_tok    := lex_tok;
  LexNext;
  lex_peek_tok := lex_tok;
  lex_tok      := saved_tok;
  lex_has_peek := True;
End;

Function LexPeekKind : TTokenKind;
Begin
  LexEnsurePeek;
  LexPeekKind := lex_peek_tok.kind;
End;

Function LexPeekVal : TString;
Begin
  LexEnsurePeek;
  LexPeekVal := lex_peek_tok.val;
End;

{ ---- Table des directives ML (386/Win32) ---- }
Const
  LD_COUNT = 132;
  LD_NAMES : Array[1..132] Of String[12] = (
    'ASSUME',  'ALIGN',    'BYTE',    'CODE',     'COMM',
    'COMMENT', 'CONST',    'DATA',    'DB',       'DD',
    'DF',      'DQ',       'DT',      'DW',       'DWORD',
    'ELSE',    'ELSEIF',   'END',     'ENDIF',    'ENDM',
    'ENDP',    'ENDS',     'EQU',     'EVEN',     'EXITM',
    'EXTERN',  'EXTRN',    'FAR',     'FWORD',    'GLOBAL',
    'GROUP',   'IF',       'IF1',     'IF2',      'IFB',
    'IFDEF',   'IFDIF',    'IFIDNI',  'IFIDN',    'IFNB',
    'IFNDEF',  'IFE',      'INCLUDE', 'INCLUDELIB','IRP',
    'IRPC',    'LABEL',    'LENGTH',  'LOCAL',    'MACRO',
    'MOD',     'MODEL',    'NAME',    'NEAR',     'NOT',
    'OFFSET',  'OPTION',   'ORG',     'PAGE',     'PARA',
    'PROC',    'PTR',      'PUBLIC',  'PURGE',    'QWORD',
    'RECORD',  'REPT',     'SBYTE',   'SEG',      'SEGMENT',
    'SHORT',   'SIZE',     'SIZEOF',  'SIZESTR',  'STACK',
    'STRUC',   'STRUCT',   'SUBTTL',  'TBYTE',    'TEXTEQU',
    'TITLE',   'TYPE',     'TYPEDEF', 'UNION',    'USES',
    'WORD',    '.CODE',    '.DATA',   '.MODEL',   '.STACK',
    '.CONST',  '.STARTUP', '.EXIT',   '.LIST',    '.NOLIST',
    '.XLIST',  '.LISTALL', '.RADIX',  '.386',     '.386P',
    '.486',    '.486P',    '.586',    '.586P',    '.686',
    '.686P',   '.MMX',     '.XMM',    '.K3D',     '.ERR',
    '.ERRNZ',  '.ERRE',    'AND',     'OR',       'XOR',
    'SHL',     'SHR',      'HIGH',    'LOW',      'THIS',
    'WIDTH',   'MASK',     'INVOKE',  'PROTO',    'FLAT',
    'STDCALL', 'C',        'DATA?',   'OWORD',    'XMMWORD',
    'PROC',    '.DATA?'
  );

Function LexIsDirective(Const s : TString) : Boolean;
Var i : Integer;
Begin
  For i := 1 To LD_COUNT Do
    If LD_NAMES[i] = s Then Begin LexIsDirective := True; Exit; End;
  LexIsDirective := False;
End;

{ ---- Table des registres 80386+ ---- }
Const
  LR_COUNT = 46;
  LR_NAMES : Array[1..46] Of String[6] = (
    { 32 bits } 'EAX','EBX','ECX','EDX','ESI','EDI','ESP','EBP',
    { 16 bits } 'AX','BX','CX','DX','SI','DI','SP','BP',
    {  8 bits } 'AL','AH','BL','BH','CL','CH','DL','DH',
    { segment } 'CS','DS','ES','SS','FS','GS',
    { FPU     } 'ST',
    { MMX     } 'MM0','MM1','MM2','MM3','MM4','MM5','MM6','MM7',
    { control } 'CR0','CR2','CR3','CR4',
    { debug   } 'DR0','DR6','DR7'
  );

Function LexIsRegister(Const s : TString) : Boolean;
Var i : Integer;
Begin
  If (Length(s) >= 4) And (Copy(s,1,3) = 'XMM') Then
  Begin
    LexIsRegister := (s[4] >= '0') And (s[4] <= '7') And (Length(s) = 4);
    Exit;
  End;
  For i := 1 To LR_COUNT Do
    If LR_NAMES[i] = s Then Begin LexIsRegister := True; Exit; End;
  LexIsRegister := False;
End;

{ ============================================================
  ParseTextequ : name TEXTEQU <text> | expr | reste de ligne
  ============================================================ }
Procedure ParseTextequ(Const name : TSymString);
Var
  val : TString;
Begin
  val := '';
  If (LexPeekKind = TK_PUNCT) And (LexPeekVal = '<') Then
  Begin
    LexNext;
    While (lex_pos <= Length(lex_line)) And (lex_line[lex_pos] <> '>') Do
    Begin
      val := val + lex_line[lex_pos];
      Inc(lex_pos);
    End;
    If lex_pos <= Length(lex_line) Then Inc(lex_pos);
  End
  Else If LexPeekKind = TK_STRING Then
  Begin
    LexNext; val := lex_tok.val;
  End
  Else
  Begin
    While (lex_pos <= Length(lex_line)) And (lex_line[lex_pos] = ' ') Do Inc(lex_pos);
    While lex_pos <= Length(lex_line) Do
    Begin
      val := val + lex_line[lex_pos];
      Inc(lex_pos);
    End;
  End;
  TextEquSet(name, val);
End;

{ ============================================================
  TABLE DES SYMBOLES
  ============================================================
  Organisation : hash table HASH_SIZE buckets de listes chainees.
  Chaque noeud est un PSymbol alloue sur le tas (New).

  Symboles predefinis inseres par SymInit :
    TRUE (-1), FALSE (0), @WORDSIZE (4, modele FLAT 32 bits),
    @CURSEG (0), @DATA/@CODE (index de section), @FILENAME, @VERSION.

  Flags dans TSymbol.flags :
    bit 0 = is_public   (declare PUBLIC)
    bit 1 = is_extern   (declare EXTERN/EXTRN)
    bit 2 = is_defined  (valeur/position connue)
    bit 3 = is_proc     (declare via PROC, appellable par INVOKE)
    bit 4 = is_stdcall  (convention STDCALL, sinon C)
  ============================================================ }

Function HashName(Const s : TSymString) : Integer;
Var
  i : Integer;
  h : LongInt;
Begin
  h := 5381;
  For i := 1 To Length(s) Do
    h := ((h Shl 5) + h) Xor LongInt(Ord(s[i]));
  If h < 0 Then h := -h;
  HashName := Integer(h Mod HASH_SIZE);
End;

Function SymFind(Const name : TSymString) : PSymbol;
Var
  h : Integer;
  p : PSymbol;
Begin
  h := HashName(name);
  p := hash_table[h];
  While p <> Nil Do
  Begin
    If p^.name = name Then
    Begin
      SymFind := p;
      Exit;
    End;
    p := p^.next;
  End;
  SymFind := Nil;
End;

Function SymEnter(Const name : TSymString;
                  kind    : TSymKind;
                  seg_idx : Integer;
                  offset  : TLong;
                  size    : TLong) : PSymbol;
Var
  h : Integer;
  p : PSymbol;
Begin
  New(p);
  p^.name     := name;
  p^.orig     := name;
  p^.kind     := kind;
  p^.seg_idx  := seg_idx;
  p^.offset   := offset;
  p^.value    := 0;
  p^.size     := size;
  p^.flags    := 4; { bit 2 = is_defined par defaut }
  p^.text_val := '';
  p^.proc_argbytes := 0;
  h             := HashName(name);
  p^.next       := hash_table[h];
  hash_table[h] := p;
  Inc(sym_count);
  SymEnter := p;
End;

Procedure SymSetValue(p : PSymbol; val : TLong);
Begin
  If p = Nil Then Exit;
  p^.value := val;
  p^.flags := p^.flags Or 4;
End;

Procedure SymSetPublic(p : PSymbol);
Begin
  If p = Nil Then Exit;
  p^.flags := p^.flags Or 1;
  If p^.kind <> SK_EXTERN Then p^.kind := SK_PUBLIC;
End;

Procedure SymSetExtern(p : PSymbol);
Begin
  If p = Nil Then Exit;
  p^.flags := p^.flags Or 2;
  p^.kind  := SK_EXTERN;
End;

Function SymLookupOrEnter(Const name : TSymString) : PSymbol;
Var
  p : PSymbol;
Begin
  p := SymFind(name);
  If p = Nil Then
  Begin
    p := SymEnter(name, SK_UNDEF, 0, 0, 0);
    p^.flags := 0;
  End;
  SymLookupOrEnter := p;
End;

{ En passe 1 : creer/mettre a jour. En passe 2 : verifier coherence. }
Procedure SymDefineLabel(Const name : TSymString; seg_i : Integer;
                         off : TLong; sz : TLong);
Var
  p : PSymbol;
Begin
  p := SymFind(name);
  If p = Nil Then
  Begin
    p := SymEnter(name, SK_LABEL, seg_i, off, sz);
  End
  Else
  Begin
    If (p^.kind <> SK_UNDEF) And (p^.kind <> SK_LABEL) And
       (p^.kind <> SK_PUBLIC) And (p^.kind <> SK_PROC) Then
    Begin
      ErrorMsg('Redefinition de symbole : ' + name);
      Exit;
    End;
    If (pass_num = 2) And (p^.offset <> off) Then
      WarnMsg('Erreur de phase pour : ' + name);
    If p^.kind <> SK_PROC Then p^.kind := SK_LABEL;
    p^.seg_idx := seg_i;
    p^.offset  := off;
    p^.size    := sz;
    p^.flags   := p^.flags Or 4;
  End;
End;

Procedure SymCheckUndefined;
Var
  i : Integer;
  p : PSymbol;
Begin
  For i := 0 To HASH_SIZE-1 Do
  Begin
    p := hash_table[i];
    While p <> Nil Do
    Begin
      If p^.kind = SK_UNDEF Then
        ErrorMsg('Symbole non defini : ' + p^.name);
      p := p^.next;
    End;
  End;
End;

Procedure SymAddPredef(Const name : TSymString; val : TLong);
Var
  p : PSymbol;
Begin
  p := SymEnter(name, SK_EQU, 0, 0, 4);
  SymSetValue(p, val);
End;

Procedure SymInit;
Var
  p : PSymbol;
Begin
  SymAddPredef('TRUE',      -1);
  SymAddPredef('FALSE',      0);
  SymAddPredef('@MODEL',     0);
  SymAddPredef('@WORDSIZE',  4); { 32-bit flat }
  SymAddPredef('@CUR_LINE',  0);
  SymAddPredef('@DATA',   SEC_DATA);
  SymAddPredef('@CODE',   SEC_TEXT);
  SymAddPredef('@STACK',  0);
  p := SymEnter('@CURSEG', SK_EQU, 0, 0, 0);
  p^.value := SEC_TEXT;
  p := SymEnter('@FILENAME', SK_EQU, 0, 0, 0);
  p^.value := 0;
  SymAddPredef('@VERSION', 100);
End;

{ ============================================================
  EVALUATEUR D EXPRESSIONS ASSEMBLEUR (DEUX PASSES)
  ============================================================
  Hierarchie d appel (du moins prioritaire au plus prioritaire) :
    EvalExpr -> EvalRelational -> EvalBitwise -> EvalNot ->
    EvalAdd -> EvalMul -> EvalPTR -> EvalUnary -> EvalPrimary
  ============================================================ }

Procedure ExprMakeNum(Var e : TExpr; v : TLong);
Begin
  e.val      := v;
  e.is_reloc := False;
  e.seg_idx  := 0;
  e.is_undef := False;
  e.is_extern:= False;
  e.sym_name := '';
  e.ptr_size := 0;
  e.is_offset_form := False;
End;

Procedure ExprMakeReloc(Var e : TExpr; v : TLong; sidx : Integer; Const nm : TSymString);
Begin
  e.val      := v;
  e.is_reloc := True;
  e.seg_idx  := sidx;
  e.is_undef := False;
  e.is_extern:= False;
  e.sym_name := nm;
  e.ptr_size := 0;
  e.is_offset_form := False;
End;

Procedure ExprMakeExtern(Var e : TExpr; Const nm : TSymString; sz : Integer);
Begin
  e.val      := 0;
  e.is_reloc := True;
  e.seg_idx  := 0;
  e.is_undef := False;
  e.is_extern:= True;
  e.sym_name := nm;
  e.ptr_size := sz;
  e.is_offset_form := False;
End;

Procedure ExprMakeUndef(Var e : TExpr);
Begin
  e.val      := 0;
  e.is_reloc := False;
  e.seg_idx  := 0;
  e.is_undef := True;
  e.is_extern:= False;
  e.sym_name := '';
  e.ptr_size := 0;
  e.is_offset_form := False;
End;

Procedure EvalExpr(Var e : TExpr); Forward;
Procedure EvalRelational(Var e : TExpr); Forward;
Procedure EvalBitwise(Var e : TExpr); Forward;
Procedure EvalNot(Var e : TExpr); Forward;
Procedure EvalAdd(Var e : TExpr); Forward;
Procedure EvalMul(Var e : TExpr); Forward;
Procedure EvalPTR(Var e : TExpr); Forward;
Procedure EvalUnary(Var e : TExpr); Forward;
Procedure EvalPrimary(Var e : TExpr); Forward;

Procedure EvalPrimary(Var e : TExpr);
Var
  tok : TString;
  sym : PSymbol;
Begin
  If LexPeekKind = TK_NUMBER Then
  Begin
    LexNext;
    ExprMakeNum(e, lex_tok.num_val);
    Exit;
  End;

  If LexPeekKind = TK_STRING Then
  Begin
    LexNext;
    If Length(lex_tok.val) >= 1 Then
      ExprMakeNum(e, Ord(lex_tok.val[1]))
    Else
      ExprMakeNum(e, 0);
    Exit;
  End;

  If LexPeekKind = TK_PUNCT Then
  Begin
    If LexPeekVal = '$' Then
    Begin
      LexNext;
      ExprMakeReloc(e, seg_table[cur_seg].cur_lc, cur_seg, '');
      Exit;
    End;
    If LexPeekVal = '(' Then
    Begin
      LexNext;
      EvalExpr(e);
      If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ')') Then
        LexNext
      Else
        WarnMsg('Parenthese fermante ) manquante dans expression');
      Exit;
    End;
    If LexPeekVal = '[' Then
    Begin
      LexNext;
      EvalExpr(e);
      If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ']') Then
        LexNext
      Else
        WarnMsg('Crochet fermant ] manquant dans expression');
      Exit;
    End;
  End;

  If LexPeekKind = TK_IDENT Then
  Begin
    LexNext;
    tok := lex_tok.val;

    If tok = 'TRUE'  Then Begin ExprMakeNum(e, -1); Exit; End;
    If tok = 'FALSE' Then Begin ExprMakeNum(e,  0); Exit; End;

    { prefixe FLAT: devant un label (modele flat, toujours vrai ici) }
    If (tok = 'FLAT') And (LexPeekKind = TK_PUNCT) And (LexPeekVal = ':') Then
    Begin
      LexNext; { consommer ':' }
      EvalPrimary(e);
      Exit;
    End;

    sym := SymFind(tok);
    If sym = Nil Then
    Begin
      If pass_num = 1 Then
        ExprMakeUndef(e)
      Else
      Begin
        ErrorMsg('Symbole indefini : ' + tok);
        ExprMakeNum(e, 0);
      End;
      Exit;
    End;

    Case sym^.kind Of
      SK_LABEL, SK_PUBLIC, SK_PROC :
        ExprMakeReloc(e, sym^.offset, sym^.seg_idx, sym^.name);
      SK_EXTERN :
        ExprMakeExtern(e, sym^.name, Integer(sym^.size));
      SK_EQU :
        ExprMakeNum(e, sym^.value);
      SK_SEG :
        ExprMakeNum(e, sym^.seg_idx);
      SK_UNDEF :
        Begin
          If pass_num = 1 Then
            ExprMakeUndef(e)
          Else
          Begin
            ErrorMsg('Symbole indefini en passe 2 : ' + tok);
            ExprMakeNum(e, 0);
          End;
        End;
    Else
      ExprMakeNum(e, sym^.value);
    End;
    Exit;
  End;

  ErrorMsg('Expression attendue, token inattendu : ' + LexPeekVal);
  ExprMakeNum(e, 0);
End;

Const
  EU_OFFSET = 1;   EU_SEG    = 2;   EU_TYPE   = 3;
  EU_SIZE   = 4;   EU_LENGTH = 5;   EU_SHORT  = 6;
  EU_BYTE   = 7;   EU_WORD   = 8;   EU_DWORD  = 9;
  EU_QWORD  = 10;  EU_TBYTE  = 11;  EU_NEAR   = 12;
  EU_FAR    = 13;  EU_OWORD  = 14;
  EU_COUNT  = 14;
  EU_NAMES  : Array[1..14] Of String[8] = (
    'OFFSET','SEG','TYPE','SIZE','LENGTH','SHORT',
    'BYTE','WORD','DWORD','QWORD','TBYTE','NEAR','FAR','OWORD'
  );

Procedure EvalUnary(Var e : TExpr);
Var
  tok   : TString;
  sz    : Integer;
  u_idx : Integer;
  i     : Integer;
Begin
  If LexPeekKind = TK_IDENT Then
  Begin
    tok   := LexPeekVal;
    sz    := 0;
    u_idx := 0;
    For i := 1 To EU_COUNT Do
      If EU_NAMES[i] = tok Then Begin u_idx := i; Break; End;
    Case u_idx Of
      EU_OFFSET :
        Begin
          LexNext; EvalPrimary(e); e.is_offset_form := True; Exit;
        End;
      EU_SEG :
        Begin
          LexNext; EvalPrimary(e);
          If e.is_reloc Then ExprMakeNum(e, e.seg_idx)
          Else             ExprMakeNum(e, 0);
          Exit;
        End;
      EU_TYPE :
        Begin
          LexNext; EvalPrimary(e); ExprMakeNum(e, e.ptr_size); Exit;
        End;
      EU_SIZE :
        Begin
          LexNext; EvalPrimary(e);
          ExprMakeNum(e, e.ptr_size);
          Exit;
        End;
      EU_LENGTH :
        Begin
          LexNext; EvalPrimary(e);
          ExprMakeNum(e, 1);
          Exit;
        End;
      EU_SHORT :
        Begin
          LexNext; EvalPrimary(e); e.ptr_size := 1; Exit;
        End;
      EU_BYTE  : sz := 1;
      EU_WORD  : sz := 2;
      EU_DWORD : sz := 4;
      EU_QWORD : sz := 8;
      EU_TBYTE : sz := 10;
      EU_NEAR  : sz := 4;
      EU_FAR   : sz := 6;
      EU_OWORD : sz := 16;
    End;

    If sz > 0 Then
    Begin
      LexNext;
      If (LexPeekKind = TK_IDENT) And (LexPeekVal = 'PTR') Then
      Begin
        LexNext;
        EvalUnary(e);
        e.ptr_size := sz;
        Exit;
      End;
      ExprMakeNum(e, sz);
      Exit;
    End;
  End;

  If (LexPeekKind = TK_PUNCT) And (LexPeekVal = '-') Then
  Begin
    LexNext;
    EvalPrimary(e);
    e.val      := -e.val;
    e.is_reloc := False;
    Exit;
  End;

  If (LexPeekKind = TK_PUNCT) And (LexPeekVal = '+') Then
  Begin
    LexNext;
    EvalPrimary(e);
    Exit;
  End;

  EvalPrimary(e);
End;

Procedure EvalPTR(Var e : TExpr);
Begin
  EvalUnary(e);
End;

Const EM_MOD=1; EM_SHL=2; EM_SHR=3; EM_COUNT=3;
      EM_NAMES: Array[1..3] Of String[3] = ('MOD','SHL','SHR');

Procedure EvalMul(Var e : TExpr);
Var
  op     : TString;
  r      : TExpr;
  em_idx : Integer;
  i      : Integer;
Begin
  EvalPTR(e);
  Repeat
    If LexPeekKind = TK_PUNCT Then
    Begin
      op := LexPeekVal;
      If (op = '*') Or (op = '/') Then
      Begin
        LexNext;
        EvalPTR(r);
        Case op[1] Of
          '*': e.val := e.val * r.val;
          '/': If r.val = 0 Then
               Begin
                 ErrorMsg('Division par zero dans expression');
                 e.val := 0;
               End
               Else
                 e.val := e.val Div r.val;
        End;
        e.is_reloc := False;
      End
      Else
        Break;
    End
    Else If LexPeekKind = TK_IDENT Then
    Begin
      op := LexPeekVal;
      em_idx := 0;
      For i := 1 To EM_COUNT Do
        If EM_NAMES[i] = op Then Begin em_idx := i; Break; End;
      If em_idx = 0 Then Break;
      LexNext;
      EvalPTR(r);
      Case em_idx Of
        EM_MOD : If r.val = 0 Then e.val := 0
                 Else e.val := e.val Mod r.val;
        EM_SHL : e.val := e.val Shl r.val;
        EM_SHR : e.val := e.val Shr r.val;
      End;
      e.is_reloc := False;
    End
    Else
      Break;
  Until False;
End;

Procedure EvalAdd(Var e : TExpr);
Var
  op : TString;
  r  : TExpr;
Begin
  EvalMul(e);
  Repeat
    If LexPeekKind = TK_PUNCT Then
    Begin
      op := LexPeekVal;
      If (op = '+') Or (op = '-') Then
      Begin
        LexNext;
        EvalMul(r);
        If op = '+' Then
          e.val := e.val + r.val
        Else
          e.val := e.val - r.val;
        If (e.is_reloc Or e.is_extern) And (r.is_reloc Or r.is_extern) Then
        Begin
          If op = '-' Then
          Begin
            e.is_reloc  := False;
            e.is_extern := False;
          End
          Else
          Begin
            ErrorMsg('Addition de deux adresses relocalisables interdite');
            e.is_reloc  := False;
            e.is_extern := False;
          End;
        End
        Else If r.is_reloc Or r.is_extern Then
        Begin
          e.is_reloc  := r.is_reloc;
          e.is_extern := r.is_extern;
          e.seg_idx   := r.seg_idx;
          e.sym_name  := r.sym_name;
        End;
        If r.is_undef Then e.is_undef := True;
      End
      Else
        Break;
    End
    Else
      Break;
  Until False;
End;

Procedure EvalNot(Var e : TExpr);
Begin
  If (LexPeekKind = TK_IDENT) And (LexPeekVal = 'NOT') Then
  Begin
    LexNext;
    EvalNot(e);
    e.val      := Not e.val;
    e.is_reloc := False;
  End
  Else
    EvalAdd(e);
End;

Const EB_AND=1; EB_OR=2; EB_XOR=3; EB_COUNT=3;
      EB_NAMES: Array[1..3] Of String[3] = ('AND','OR','XOR');

Procedure EvalBitwise(Var e : TExpr);
Var
  op    : TString;
  r     : TExpr;
  eb_idx : Integer;
  i     : Integer;
Begin
  EvalNot(e);
  Repeat
    If LexPeekKind = TK_IDENT Then
    Begin
      op := LexPeekVal;
      eb_idx := 0;
      For i := 1 To EB_COUNT Do
        If EB_NAMES[i] = op Then Begin eb_idx := i; Break; End;
      If eb_idx = 0 Then Break;
      LexNext;
      EvalNot(r);
      Case eb_idx Of
        EB_AND : e.val := e.val And r.val;
        EB_OR  : e.val := e.val Or  r.val;
        EB_XOR : e.val := e.val Xor r.val;
      End;
      e.is_reloc := False;
      If r.is_undef Then e.is_undef := True;
    End
    Else
      Break;
  Until False;
End;

Const
  ER_EQ = 1; ER_NE = 2; ER_LT = 3; ER_LE = 4; ER_GT = 5; ER_GE = 6;
  ER_COUNT = 6;
  ER_NAMES : Array[1..6] Of String[2] = ('EQ','NE','LT','LE','GT','GE');

Procedure EvalRelational(Var e : TExpr);
Var
  op    : TString;
  r     : TExpr;
  b     : Boolean;
  er_idx : Integer;
  i     : Integer;
Begin
  EvalBitwise(e);
  Repeat
    If LexPeekKind = TK_IDENT Then
    Begin
      op     := LexPeekVal;
      er_idx := 0;
      For i := 1 To ER_COUNT Do
        If ER_NAMES[i] = op Then Begin er_idx := i; Break; End;
      If er_idx = 0 Then Break;
      LexNext;
      EvalBitwise(r);
      Case er_idx Of
        ER_EQ : b := (e.val =  r.val);
        ER_NE : b := (e.val <> r.val);
        ER_LT : b := (e.val <  r.val);
        ER_LE : b := (e.val <= r.val);
        ER_GT : b := (e.val >  r.val);
        ER_GE : b := (e.val >= r.val);
      Else b := False;
      End;
      If b Then e.val := -1 Else e.val := 0;
      e.is_reloc := False;
      e.is_undef := e.is_undef Or r.is_undef;
    End
    Else
      Break;
  Until False;
End;

Procedure EvalExpr(Var e : TExpr);
Begin
  EvalRelational(e);
End;

Function EvalConstExpr : TLong;
Var
  e : TExpr;
Begin
  EvalExpr(e);
  If e.is_undef Then
  Begin
    If pass_num = 2 Then
      ErrorMsg('Expression constante non resolue en passe 2');
    EvalConstExpr := 0;
    Exit;
  End;
  If e.is_reloc Or e.is_extern Then
  Begin
    ErrorMsg('Expression relocalisable inattendue (constante requise)');
    EvalConstExpr := e.val;
    Exit;
  End;
  EvalConstExpr := e.val;
End;

{ ============================================================
  TODO 2 - EMISSION BAS NIVEAU (BUFFERS DE SECTION) ET FIXUPS
  ============================================================
  Chaque section fixe (.text/.data/.bss/.rdata) a son propre
  buffer d octets en memoire (BinInit alloue au demarrage).
  .bss ne stocke pas d octets physiques (seul cur_lc avance).

  Les fixups (BinFixup) sont resolus en une seule fois apres la
  passe 2 :
    - reference a un label interne  : patch immediat (adresse finale
      connue des que les tailles de section sont figees)
    - reference a un symbole EXTERN : patch differe apres la
      construction de la table d import (voir TODO 10, WritePE)
  ============================================================ }

Const
  MAX_BIN_TEXT  = {$IFDEF FPC}2097152{$ELSE}16384{$ENDIF};  { 2 Mo code }
  MAX_BIN_DATA  = {$IFDEF FPC}1048576{$ELSE}16384{$ENDIF};  { 1 Mo .data }
  MAX_BIN_RDATA = {$IFDEF FPC}1048576{$ELSE}16384{$ENDIF};  { 1 Mo .rdata (+ table d import) }

Type
  TFixKind = (FX_ABS32, FX_REL32);

  TBinFixup = Record
    sec         : Integer;     { section contenant l octet a patcher }
    pos         : TLong;       { offset du champ 32 bits a patcher }
    kind        : TFixKind;
    is_extern   : Boolean;     { True = cible un symbole EXTERN (import) }
    name        : TSymString;  { nom du symbole cible (si direct_sec=0) }
    addend      : TLong;       { constante additionnelle (ex label+N, ou offset si direct_sec>0) }
    direct_sec  : Integer;     { >0 = cible resolue directement (section, pas de recherche par nom) }
  End;

  TBinTextArr  = Array[0..MAX_BIN_TEXT-1]  Of Byte;
  TBinDataArr  = Array[0..MAX_BIN_DATA-1]  Of Byte;
  TBinRDataArr = Array[0..MAX_BIN_RDATA-1] Of Byte;
  PBinTextArr  = ^TBinTextArr;
  PBinDataArr  = ^TBinDataArr;
  PBinRDataArr = ^TBinRDataArr;

Var
  bin_text   : PBinTextArr;
  bin_data   : PBinDataArr;
  bin_rdata  : PBinRDataArr;
  bin_fixups : Array[1..MAX_FIXUP] Of TBinFixup;
  bin_fixup_count : Integer;

Procedure BinInit;
Begin
  GetMem(bin_text,  MAX_BIN_TEXT);
  GetMem(bin_data,  MAX_BIN_DATA);
  GetMem(bin_rdata, MAX_BIN_RDATA);
  bin_fixup_count := 0;
End;

{ ============================================================
  BinEmitByte : ecrire un octet dans la section courante (cur_seg)
  et avancer son location counter. En passe 1 (no_emit), seul le
  LC avance (l ecriture reelle est reportee a la passe 2).
  ============================================================ }
Procedure BinEmitByte(b : Byte);
Var
  p : TLong;
Begin
  p := seg_table[cur_seg].cur_lc;
  If (pass_num = 2) And (Not seg_table[cur_seg].is_bss) Then
  Begin
    Case cur_seg Of
      SEC_TEXT  : If p < MAX_BIN_TEXT  Then bin_text^[p]  := b;
      SEC_DATA  : If p < MAX_BIN_DATA  Then bin_data^[p]  := b;
      SEC_RDATA : If p < MAX_BIN_RDATA Then bin_rdata^[p] := b;
    End;
  End;
  Inc(seg_table[cur_seg].cur_lc);
End;

Procedure BinEmitWord(w : Word);
Begin
  BinEmitByte(Byte(w And $FF));
  BinEmitByte(Byte((w Shr 8) And $FF));
End;

Procedure BinEmitDWord(d : TLong);
Begin
  BinEmitByte(Byte(d And $FF));
  BinEmitByte(Byte((d Shr 8)  And $FF));
  BinEmitByte(Byte((d Shr 16) And $FF));
  BinEmitByte(Byte((d Shr 24) And $FF));
End;

Procedure BinEmitQWord(lo, hi : TLong);
Begin
  BinEmitDWord(lo);
  BinEmitDWord(hi);
End;

{ ============================================================
  IntToStr_ / StrLPad_ : utilitaires de formatage (evite les
  dependances a une unite non standard)
  ============================================================ }
Function IntToStr_(v : LongInt) : TString;
Var s : TString;
Begin
  Str(v, s);
  IntToStr_ := s;
End;

{ ============================================================
  BinAddFixupExpr : enregistrer un patch a resoudre apres la fin
  de l assemblage. Pour un symbole local (e.is_reloc), la section
  cible est deja connue (e.seg_idx) : pas besoin de rechercher le
  symbole a nouveau, "addend" contient deja l offset complet
  (offset du symbole + toute constante ajoutee dans l expression).
  Pour un symbole EXTERN (e.is_extern), la cible sera une entree
  de la table d import, resolue par nom au moment de WritePE.
  pos = position (dans la section courante) du premier des 4
  octets a patcher ; ces octets doivent deja avoir ete ecrits
  (generalement a 0) par BinEmitDWord avant l appel.
  ============================================================ }
Procedure BinAddFixupExpr(fkind : TFixKind; Const e : TExpr);
Begin
  If pass_num <> 2 Then Exit; { les fixups ne sont utiles qu en passe 2 }
  If Not (e.is_reloc Or e.is_extern) Then Exit;
  If bin_fixup_count >= MAX_FIXUP Then
  Begin
    ErrorMsg('Table de fixups pleine (MAX_FIXUP=' + IntToStr_(MAX_FIXUP) + ')');
    Exit;
  End;
  Inc(bin_fixup_count);
  With bin_fixups[bin_fixup_count] Do
  Begin
    sec := cur_seg;
    pos := seg_table[cur_seg].cur_lc - 4;
    kind := fkind;
    If e.is_extern Then
    Begin
      is_extern  := True;
      name       := e.sym_name;
      addend     := e.val;
      direct_sec := 0;
    End
    Else
    Begin
      is_extern  := False;
      name       := e.sym_name;
      addend     := e.val;
      direct_sec := e.seg_idx;
    End;
  End;
End;

{ ============================================================
  BinEmitDisp32Expr : ecrire un deplacement/adresse 32 bits qui
  peut etre une constante pure, une reference a un label local,
  ou une reference EXTERN - et enregistrer le fixup si necessaire.
  ============================================================ }
Procedure BinEmitDisp32Expr(Const e : TExpr);
Begin
  BinEmitDWord(e.val);
  BinAddFixupExpr(FX_ABS32, e);
End;

{ ============================================================
  SEG_OVR_BYTE : prefixe de surcharge de segment (index 1..6
  ES/CS/SS/DS/FS/GS -> octet de prefixe x86)
  ============================================================ }
Const
  SEG_OVR_BYTE : Array[1..6] Of Byte = ($26,$2E,$36,$3E,$64,$65);

{ ============================================================
  EmitSegOverride : emettre le prefixe de segment si present
  ============================================================ }
Procedure EmitSegOverride(Const op : TOperand);
Begin
  If (op.seg_ovr >= 1) And (op.seg_ovr <= 6) Then
    BinEmitByte(SEG_OVR_BYTE[op.seg_ovr]);
End;

{ ============================================================
  ScaleFieldOf : convertir 1/2/4/8 en champ SS du SIB (0..3)
  ============================================================ }
Function ScaleFieldOf(scale : Integer) : Byte;
Begin
  Case scale Of
    1 : ScaleFieldOf := 0;
    2 : ScaleFieldOf := 1;
    4 : ScaleFieldOf := 2;
    8 : ScaleFieldOf := 3;
  Else
    Begin
      WarnMsg('Facteur d echelle invalide (1,2,4,8 attendu)');
      ScaleFieldOf := 0;
    End;
  End;
End;

{ ============================================================
  EmitModRM : emettre le prefixe de segment eventuel, l octet
  ModRM (et le SIB/deplacement si memoire) pour reg_field/op.
  reg_field = bits 5-3 du ModRM (numero de registre ou /digit
  d extension d opcode). C est le coeur de l encodeur 32 bits,
  portage du calcul ModRM/SIB de POWFXC32.PAS (AsmEncodeMemory),
  parametre ici par TOperand deja analyse au lieu de texte brut.
  ============================================================ }
Procedure EmitModRM(reg_field : Byte; Const op : TOperand);
Var
  disp_val   : TLong;
  disp_is_far: Boolean; { True = doit utiliser disp32 (reloc/extern ou hors [-128,127]) }
  scale_f    : Byte;
Begin
  EmitSegOverride(op);

  If (op.kind = OPK_REG) Or (op.kind = OPK_ST) Then
  Begin
    BinEmitByte(Byte($C0 Or (reg_field Shl 3) Or (op.reg.idx And 7)));
    Exit;
  End;

  { OPK_MEM au-dela de ce point }
  disp_val := 0;
  If op.has_disp Then disp_val := op.disp.val;
  disp_is_far := op.has_disp And (op.disp.is_reloc Or op.disp.is_extern Or
                                   (disp_val < -128) Or (disp_val > 127));

  { ---- cas 1 : ni base ni index -> adresse directe [disp32] ---- }
  If (Not op.has_base) And (Not op.has_index) Then
  Begin
    BinEmitByte(Byte((0 Shl 6) Or (reg_field Shl 3) Or 5));
    If op.has_disp Then BinEmitDisp32Expr(op.disp)
    Else                BinEmitDWord(0);
    Exit;
  End;

  { ---- cas 2 : index present (avec ou sans base) -> SIB obligatoire ---- }
  If op.has_index Then
  Begin
    If op.index_reg.idx = 4 Then
      WarnMsg('ESP ne peut pas etre utilise comme registre d index');
    scale_f := ScaleFieldOf(op.scale);

    If Not op.has_base Then
    Begin
      { [index*scale+disp32], pas de base : SIB.base=101 force mod=00 }
      BinEmitByte(Byte((0 Shl 6) Or (reg_field Shl 3) Or 4));
      BinEmitByte(Byte((scale_f Shl 6) Or ((op.index_reg.idx And 7) Shl 3) Or 5));
      If op.has_disp Then BinEmitDisp32Expr(op.disp)
      Else                BinEmitDWord(0);
      Exit;
    End;

    { base + index present }
    If (op.base_reg.idx = 5) And (Not op.has_disp) Then
    Begin
      { [EBP+index*scale] sans disp -> mod=01 disp8=0 obligatoire }
      BinEmitByte(Byte((1 Shl 6) Or (reg_field Shl 3) Or 4));
      BinEmitByte(Byte((scale_f Shl 6) Or ((op.index_reg.idx And 7) Shl 3) Or (op.base_reg.idx And 7)));
      BinEmitByte(0);
      Exit;
    End;

    If (Not op.has_disp) Or ((Not disp_is_far) And (disp_val = 0)) Then
    Begin
      BinEmitByte(Byte((0 Shl 6) Or (reg_field Shl 3) Or 4));
      BinEmitByte(Byte((scale_f Shl 6) Or ((op.index_reg.idx And 7) Shl 3) Or (op.base_reg.idx And 7)));
      Exit;
    End
    Else If Not disp_is_far Then
    Begin
      BinEmitByte(Byte((1 Shl 6) Or (reg_field Shl 3) Or 4));
      BinEmitByte(Byte((scale_f Shl 6) Or ((op.index_reg.idx And 7) Shl 3) Or (op.base_reg.idx And 7)));
      BinEmitByte(Byte(disp_val And $FF));
      Exit;
    End
    Else
    Begin
      BinEmitByte(Byte((2 Shl 6) Or (reg_field Shl 3) Or 4));
      BinEmitByte(Byte((scale_f Shl 6) Or ((op.index_reg.idx And 7) Shl 3) Or (op.base_reg.idx And 7)));
      BinEmitDisp32Expr(op.disp);
      Exit;
    End;
  End;

  { ---- cas 3 : base seule, pas d index ---- }
  If op.base_reg.idx = 4 Then
  Begin
    { [ESP] ou [ESP+disp] : necessite toujours un SIB (base=100,index=100,scale=0) }
    If (Not op.has_disp) Or ((Not disp_is_far) And (disp_val = 0)) Then
    Begin
      BinEmitByte(Byte((0 Shl 6) Or (reg_field Shl 3) Or 4));
      BinEmitByte($24);
      Exit;
    End
    Else If Not disp_is_far Then
    Begin
      BinEmitByte(Byte((1 Shl 6) Or (reg_field Shl 3) Or 4));
      BinEmitByte($24);
      BinEmitByte(Byte(disp_val And $FF));
      Exit;
    End
    Else
    Begin
      BinEmitByte(Byte((2 Shl 6) Or (reg_field Shl 3) Or 4));
      BinEmitByte($24);
      BinEmitDisp32Expr(op.disp);
      Exit;
    End;
  End;

  If (op.base_reg.idx = 5) And (Not op.has_disp) Then
  Begin
    { [EBP] sans disp -> mod=01 disp8=0 obligatoire }
    BinEmitByte(Byte((1 Shl 6) Or (reg_field Shl 3) Or 5));
    BinEmitByte(0);
    Exit;
  End;

  If (Not op.has_disp) Or ((Not disp_is_far) And (disp_val = 0)) Then
  Begin
    BinEmitByte(Byte((0 Shl 6) Or (reg_field Shl 3) Or (op.base_reg.idx And 7)));
    Exit;
  End
  Else If Not disp_is_far Then
  Begin
    BinEmitByte(Byte((1 Shl 6) Or (reg_field Shl 3) Or (op.base_reg.idx And 7)));
    BinEmitByte(Byte(disp_val And $FF));
    Exit;
  End
  Else
  Begin
    BinEmitByte(Byte((2 Shl 6) Or (reg_field Shl 3) Or (op.base_reg.idx And 7)));
    BinEmitDisp32Expr(op.disp);
    Exit;
  End;
End;

{ ============================================================
  TODO 3 - REGISTRES ET OPERANDES 32 BITS (ADRESSAGE SIB)
  ============================================================ }

{ ============================================================
  RegByName : resoudre un nom de registre (deja en majuscules)
  en TReg. Retourne kind=RK_NONE si s n est pas un registre.
  ============================================================ }
Function RegByName(Const s : TString) : TReg;
Var
  r : TReg;
Begin
  r.kind := RK_NONE;
  r.idx  := 0;

  { 32 bits }
  If s = 'EAX' Then Begin r.kind := RK_32; r.idx := 0; End
  Else If s = 'ECX' Then Begin r.kind := RK_32; r.idx := 1; End
  Else If s = 'EDX' Then Begin r.kind := RK_32; r.idx := 2; End
  Else If s = 'EBX' Then Begin r.kind := RK_32; r.idx := 3; End
  Else If s = 'ESP' Then Begin r.kind := RK_32; r.idx := 4; End
  Else If s = 'EBP' Then Begin r.kind := RK_32; r.idx := 5; End
  Else If s = 'ESI' Then Begin r.kind := RK_32; r.idx := 6; End
  Else If s = 'EDI' Then Begin r.kind := RK_32; r.idx := 7; End
  { 16 bits }
  Else If s = 'AX' Then Begin r.kind := RK_16; r.idx := 0; End
  Else If s = 'CX' Then Begin r.kind := RK_16; r.idx := 1; End
  Else If s = 'DX' Then Begin r.kind := RK_16; r.idx := 2; End
  Else If s = 'BX' Then Begin r.kind := RK_16; r.idx := 3; End
  Else If s = 'SP' Then Begin r.kind := RK_16; r.idx := 4; End
  Else If s = 'BP' Then Begin r.kind := RK_16; r.idx := 5; End
  Else If s = 'SI' Then Begin r.kind := RK_16; r.idx := 6; End
  Else If s = 'DI' Then Begin r.kind := RK_16; r.idx := 7; End
  { 8 bits }
  Else If s = 'AL' Then Begin r.kind := RK_8; r.idx := 0; End
  Else If s = 'CL' Then Begin r.kind := RK_8; r.idx := 1; End
  Else If s = 'DL' Then Begin r.kind := RK_8; r.idx := 2; End
  Else If s = 'BL' Then Begin r.kind := RK_8; r.idx := 3; End
  Else If s = 'AH' Then Begin r.kind := RK_8; r.idx := 4; End
  Else If s = 'CH' Then Begin r.kind := RK_8; r.idx := 5; End
  Else If s = 'DH' Then Begin r.kind := RK_8; r.idx := 6; End
  Else If s = 'BH' Then Begin r.kind := RK_8; r.idx := 7; End
  { segment }
  Else If s = 'ES' Then Begin r.kind := RK_SEG; r.idx := 0; End
  Else If s = 'CS' Then Begin r.kind := RK_SEG; r.idx := 1; End
  Else If s = 'SS' Then Begin r.kind := RK_SEG; r.idx := 2; End
  Else If s = 'DS' Then Begin r.kind := RK_SEG; r.idx := 3; End
  Else If s = 'FS' Then Begin r.kind := RK_SEG; r.idx := 4; End
  Else If s = 'GS' Then Begin r.kind := RK_SEG; r.idx := 5; End
  { control / debug }
  Else If s = 'CR0' Then Begin r.kind := RK_CR; r.idx := 0; End
  Else If s = 'CR2' Then Begin r.kind := RK_CR; r.idx := 2; End
  Else If s = 'CR3' Then Begin r.kind := RK_CR; r.idx := 3; End
  Else If s = 'CR4' Then Begin r.kind := RK_CR; r.idx := 4; End
  Else If s = 'DR0' Then Begin r.kind := RK_DR; r.idx := 0; End
  Else If s = 'DR6' Then Begin r.kind := RK_DR; r.idx := 6; End
  Else If s = 'DR7' Then Begin r.kind := RK_DR; r.idx := 7; End
  { MMX }
  Else If s = 'MM0' Then Begin r.kind := RK_MM; r.idx := 0; End
  Else If s = 'MM1' Then Begin r.kind := RK_MM; r.idx := 1; End
  Else If s = 'MM2' Then Begin r.kind := RK_MM; r.idx := 2; End
  Else If s = 'MM3' Then Begin r.kind := RK_MM; r.idx := 3; End
  Else If s = 'MM4' Then Begin r.kind := RK_MM; r.idx := 4; End
  Else If s = 'MM5' Then Begin r.kind := RK_MM; r.idx := 5; End
  Else If s = 'MM6' Then Begin r.kind := RK_MM; r.idx := 6; End
  Else If s = 'MM7' Then Begin r.kind := RK_MM; r.idx := 7; End
  { XMM }
  Else If (Length(s) = 4) And (Copy(s,1,3) = 'XMM') And (s[4] >= '0') And (s[4] <= '7') Then
    Begin r.kind := RK_XMM; r.idx := Ord(s[4]) - Ord('0'); End;

  RegByName := r;
End;

{ ============================================================
  ParseRegToken : si le prochain token est un registre, le
  consommer et le retourner dans r ; sinon r.kind=RK_NONE et
  rien n est consomme. Gere la forme speciale ST ou ST(n).
  ============================================================ }
Function ParseRegToken(Var r : TReg) : Boolean;
Var
  s : TString;
Begin
  ParseRegToken := False;
  r.kind := RK_NONE;
  r.idx  := 0;
  If LexPeekKind <> TK_IDENT Then Exit;
  s := LexPeekVal;
  If s = 'ST' Then
  Begin
    LexNext; { consommer ST }
    r.kind := RK_ST;
    r.idx  := 0;
    If (LexPeekKind = TK_PUNCT) And (LexPeekVal = '(') Then
    Begin
      LexNext; { ( }
      If LexPeekKind = TK_NUMBER Then
      Begin
        LexNext;
        r.idx := lex_tok.num_val And 7;
      End;
      If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ')') Then LexNext;
    End;
    ParseRegToken := True;
    Exit;
  End;
  r := RegByName(s);
  If r.kind <> RK_NONE Then
  Begin
    LexNext;
    ParseRegToken := True;
  End;
End;

{ ============================================================
  ClearOperand : reinitialiser un TOperand
  ============================================================ }
Procedure ClearOperand(Var op : TOperand);
Begin
  op.kind      := OPK_NONE;
  op.reg.kind  := RK_NONE; op.reg.idx := 0;
  op.has_base  := False;
  op.base_reg.kind := RK_NONE; op.base_reg.idx := 0;
  op.has_index := False;
  op.index_reg.kind := RK_NONE; op.index_reg.idx := 0;
  op.scale     := 1;
  op.has_disp  := False;
  ExprMakeNum(op.disp, 0);
  op.seg_ovr   := 0;
  op.size_hint := DS_UNKNOWN;
  ExprMakeNum(op.imm, 0);
  op.is_indirect_call := False;
End;

{ ---- Table des prefixes de taille pour ParseOperand ---- }
Const
  PO_COUNT = 8;
  PO_NAMES : Array[1..8] Of String[8] = (
    'BYTE','WORD','DWORD','QWORD','TBYTE','OWORD','XMMWORD','FWORD'
  );
  PO_SIZE  : Array[1..8] Of TDataSize = (
    DS_BYTE, DS_WORD, DS_DWORD, DS_QWORD, DS_TBYTE, DS_OWORD, DS_OWORD, DS_TBYTE
  );

{ ============================================================
  SegOverrideIdx : 1..6 (ES,CS,SS,DS,FS,GS) si s est un nom de
  registre de segment, sinon 0.
  ============================================================ }
Function SegOverrideIdx(Const s : TString) : Integer;
Begin
  If s = 'ES' Then SegOverrideIdx := 1
  Else If s = 'CS' Then SegOverrideIdx := 2
  Else If s = 'SS' Then SegOverrideIdx := 3
  Else If s = 'DS' Then SegOverrideIdx := 4
  Else If s = 'FS' Then SegOverrideIdx := 5
  Else If s = 'GS' Then SegOverrideIdx := 6
  Else SegOverrideIdx := 0;
End;

{ ============================================================
  VARIABLES DE PILE (parametres PROC haut niveau + LOCAL)
  ============================================================
  Une PROC declaree avec une liste de parametres haut niveau
  (ex: MaProc PROC arg1:DWORD, arg2:DWORD) ou utilisant LOCAL
  cree des symboles relatifs a EBP (EBP+8+4*i pour un parametre,
  EBP-N pour une variable LOCAL). Ces symboles ne sont PAS des
  labels de section : ParseOperand/ParseMemBracket les detectent
  ici, avant la resolution generale par la table des symboles,
  et construisent directement un operande memoire [EBP+/-disp].
  ============================================================ }
Const
  MAX_STACKVAR = 64;
Type
  TStackVar = Record
    name   : TSymString;
    offset : TLong; { deplacement signe par rapport a EBP }
  End;
Var
  stackvar_tab   : Array[1..MAX_STACKVAR] Of TStackVar;
  stackvar_count : Integer;

Procedure StackVarClear;
Begin
  stackvar_count := 0;
End;

Procedure StackVarAdd(Const nm : TSymString; off : TLong);
Begin
  If stackvar_count >= MAX_STACKVAR Then
  Begin
    ErrorMsg('Trop de parametres/variables locales (max ' + IntToStr_(MAX_STACKVAR) + ')');
    Exit;
  End;
  Inc(stackvar_count);
  stackvar_tab[stackvar_count].name   := nm;
  stackvar_tab[stackvar_count].offset := off;
End;

Function StackVarFind(Const nm : TSymString; Var off : TLong) : Boolean;
Var i : Integer;
Begin
  StackVarFind := False;
  For i := 1 To stackvar_count Do
    If stackvar_tab[i].name = nm Then
    Begin
      off := stackvar_tab[i].offset;
      StackVarFind := True;
      Exit;
    End;
End;

{ ============================================================
  ParseMemBracket : analyser le contenu entre [ et ] (le '['
  a deja ete consomme). Remplit has_base/base_reg/has_index/
  index_reg/scale/disp dans op. Le ']' final est consomme.
  Grammaire acceptee : (reg / reg*scale / +expr / -expr)...
  ============================================================ }
Procedure ParseMemBracket(Var op : TOperand);
Var
  sign     : Integer;
  r        : TReg;
  e        : TExpr;
  disp_set : Boolean;
  disp_e   : TExpr;
Begin
  sign     := 1;
  disp_set := False;
  ExprMakeNum(disp_e, 0);

  While True Do
  Begin
    If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ']') Then Break;
    If LexPeekKind = TK_EOF Then Break;

    If (LexPeekKind = TK_PUNCT) And (LexPeekVal = '+') Then
    Begin
      LexNext; sign := 1; Continue;
    End;
    If (LexPeekKind = TK_PUNCT) And (LexPeekVal = '-') Then
    Begin
      LexNext; sign := -1; Continue;
    End;

    { variable de pile (parametre PROC ou LOCAL) : contribue EBP + offset }
    If (LexPeekKind = TK_IDENT) And StackVarFind(LexPeekVal, e.val) Then
    Begin
      LexNext; { consommer le nom }
      op.has_base := True;
      op.base_reg.kind := RK_32; op.base_reg.idx := 5; { EBP }
      If sign < 0 Then e.val := -e.val;
      If disp_set Then
      Begin
        disp_e.val := disp_e.val + e.val;
      End
      Else
      Begin
        ExprMakeNum(disp_e, e.val);
        disp_set := True;
      End;
      sign := 1;
      Continue;
    End;

    { registre (base ou index) }
    If (LexPeekKind = TK_IDENT) And (RegByName(LexPeekVal).kind = RK_32) Then
    Begin
      ParseRegToken(r);
      { suivi de * scale ? }
      If (LexPeekKind = TK_PUNCT) And (LexPeekVal = '*') Then
      Begin
        LexNext; { * }
        op.has_index  := True;
        op.index_reg  := r;
        If LexPeekKind = TK_NUMBER Then
        Begin
          LexNext;
          op.scale := lex_tok.num_val;
        End
        Else
          op.scale := 1;
      End
      Else If Not op.has_base Then
      Begin
        op.has_base := True;
        op.base_reg := r;
      End
      Else If Not op.has_index Then
      Begin
        op.has_index := True;
        op.index_reg := r;
        op.scale     := 1;
      End;
      sign := 1;
      Continue;
    End;

    { Un seul TERME du deplacement (constante/label, avec */MOD/SHL/SHR
      autorises) - PAS EvalExpr, qui consommerait aussi un + ou - de haut
      niveau suivant (ex: le "+ ESI" de "[array10 + ESI*4]"), une boucle
      d accumulation deja geree ICI par ParseMemBracket lui-meme. }
    EvalMul(e);
    If sign < 0 Then e.val := -e.val;
    If disp_set Then
    Begin
      disp_e.val := disp_e.val + e.val;
      If e.is_reloc Or e.is_extern Then
      Begin
        disp_e.is_reloc  := e.is_reloc;
        disp_e.is_extern := e.is_extern;
        disp_e.seg_idx    := e.seg_idx;
        disp_e.sym_name    := e.sym_name;
      End;
      disp_e.is_undef := disp_e.is_undef Or e.is_undef;
    End
    Else
    Begin
      disp_e   := e;
      disp_set := True;
    End;
    sign := 1;
  End;

  If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ']') Then LexNext
  Else WarnMsg('] manquant dans un operande memoire');

  If disp_set Then
  Begin
    op.has_disp := True;
    op.disp     := disp_e;
  End;
End;

{ ============================================================
  ParseOperand : parser un operande d instruction complet.
  Gere : prefixe de taille (BYTE/WORD/DWORD/... PTR), surcharge
  de segment (DS:...), registres 8/16/32/FPU/MMX/XMM, adressage
  memoire [base+index*scale+disp], immediat/adresse directe.
  ============================================================ }
Procedure ParseOperand(Var op : TOperand);
Var
  tok    : TString;
  i      : Integer;
  po_idx : Integer;
  ovr    : Integer;
  r      : TReg;
  e      : TExpr;
Begin
  ClearOperand(op);
  If LexPeekKind = TK_EOF Then Exit;

  { prefixe de taille }
  If LexPeekKind = TK_IDENT Then
  Begin
    tok := LexPeekVal;
    po_idx := 0;
    For i := 1 To PO_COUNT Do
      If PO_NAMES[i] = tok Then Begin po_idx := i; Break; End;
    If po_idx > 0 Then
    Begin
      LexNext;
      op.size_hint := PO_SIZE[po_idx];
      If (LexPeekKind = TK_IDENT) And (LexPeekVal = 'PTR') Then LexNext;
    End;
  End;

  { surcharge de segment SEG: }
  ovr := 0;
  If LexPeekKind = TK_IDENT Then
  Begin
    tok := LexPeekVal;
    ovr := SegOverrideIdx(tok);
    If ovr > 0 Then
    Begin
      LexEnsurePeek;
      { il faut regarder le token APRES le registre de segment pour savoir
        si c est un vrai prefixe seg: ou l operande registre de segment seul }
      LexNext; { consommer le nom de segment }
      If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ':') Then
        LexNext { consommer ':' }
      Else
      Begin
        { pas de ':' : c etait un registre de segment utilise seul }
        op.kind := OPK_REG;
        op.reg.kind := RK_SEG;
        op.reg.idx  := ovr - 1;
        Exit;
      End;
    End
    Else
      ovr := 0;
  End;

  { registre pur (ou ST/ST(n)) }
  If LexPeekKind = TK_IDENT Then
  Begin
    If ParseRegToken(r) Then
    Begin
      If r.kind = RK_ST Then op.kind := OPK_ST Else op.kind := OPK_REG;
      op.reg     := r;
      op.seg_ovr := ovr;
      Exit;
    End;
  End;

  { adressage memoire [ ... ] }
  If (LexPeekKind = TK_PUNCT) And (LexPeekVal = '[') Then
  Begin
    LexNext; { consommer [ }
    op.kind    := OPK_MEM;
    op.seg_ovr := ovr;
    ParseMemBracket(op);
    Exit;
  End;

  { variable de pile (parametre PROC ou LOCAL) utilisee nue, sans [ ] }
  If (LexPeekKind = TK_IDENT) And StackVarFind(LexPeekVal, e.val) Then
  Begin
    LexNext;
    op.kind          := OPK_MEM;
    op.seg_ovr       := ovr;
    op.has_base      := True;
    op.base_reg.kind := RK_32; op.base_reg.idx := 5; { EBP }
    op.has_disp      := True;
    ExprMakeNum(op.disp, e.val);
    If op.size_hint = DS_UNKNOWN Then op.size_hint := DS_DWORD;
    Exit;
  End;

  { expression : immediat, ou reference nue a un label/EXTERN }
  EvalExpr(e);
  If (e.is_reloc Or e.is_extern) And (Not e.is_offset_form) Then
  Begin
    { "MOV EAX, label" (avec ou sans PTR explicite) : un label nu, sans
      OFFSET ni crochets, designe l EMPLACEMENT MEMOIRE (dereference),
      exactement comme le vrai MASM - PAS son adresse. "OFFSET label" (ou
      une expression EXTERN utilisee comme cible d appel) reste une valeur
      immediate (is_offset_form=True), voir EU_OFFSET et ExprMakeExtern.
      Les instructions de branchement (JMP/CALL/Jcc/LOOP) reconnaissent
      elles-memes cette forme OPK_MEM sans base/index comme une cible directe
      (voir ExtractBranchTarget) : pas besoin de cas special ici. }
    op.kind     := OPK_MEM;
    op.seg_ovr  := ovr;
    op.has_disp := True;
    op.disp     := e;
    Exit;
  End;
  op.kind := OPK_IMM;
  op.imm  := e;
End;
{ ============================================================
  TODO 4 - ENCODEUR D INSTRUCTIONS ENTIERES 80386
  ============================================================
  Convention generale des fixups de branchement : TOUJOURS
  differer via BinAddFixupExpr (meme pour un label interne deja
  connu) - simplifie le code au prix d une entree de fixup
  supplementaire ; resolu en une seule passe finale (voir TODO 10).
  ============================================================ }

{ ============================================================
  OperandSize : deviner la taille (8/16/32/0=inconnue) d un
  operande deja analyse.
  ============================================================ }
Function OperandSize(Const op : TOperand) : Integer;
Begin
  OperandSize := 0;
  Case op.kind Of
    OPK_REG :
      Case op.reg.kind Of
        RK_8  : OperandSize := 8;
        RK_16 : OperandSize := 16;
        RK_32 : OperandSize := 32;
        RK_SEG: OperandSize := 16;
      Else OperandSize := 32;
      End;
    OPK_MEM :
      Case op.size_hint Of
        DS_BYTE  : OperandSize := 8;
        DS_WORD  : OperandSize := 16;
        DS_DWORD : OperandSize := 32;
      Else OperandSize := 0;
      End;
  Else
    OperandSize := 0;
  End;
End;

{ ============================================================
  Emit16BitPrefix : emettre 66h si l instruction est en mode 16
  bits (operande WORD explicite ou registre 16 bits).
  ============================================================ }
Procedure Emit16BitPrefix(sz : Integer);
Begin
  If sz = 16 Then BinEmitByte($66);
End;

{ ============================================================
  BinEmitImmExpr : emettre une valeur immediate sur 1, 2 ou 4
  octets (avec fixup si 4 octets et relogeable/externe).
  ============================================================ }
Procedure BinEmitImmExpr(Const e : TExpr; nbytes : Integer);
Begin
  Case nbytes Of
    1 : BinEmitByte(Byte(e.val And $FF));
    2 : BinEmitWord(Word(e.val And $FFFF));
    4 : BinEmitDisp32Expr(e);
  End;
End;

{ ============================================================
  EmitRelToOperand : emettre un deplacement REL32 vers la cible
  (label ou EXTERN) - toujours differe via un fixup.
  ============================================================ }
Procedure EmitRelToOperand(Const target : TExpr);
Var
  e : TExpr;
Begin
  If target.is_reloc Or target.is_extern Then
  Begin
    BinEmitDWord(0);
    BinAddFixupExpr(FX_REL32, target);
  End
  Else
  Begin
    { forme rare : deplacement numerique explicite / $ arithmetique }
    e := target;
    BinEmitDWord(e.val - (seg_table[cur_seg].cur_lc + 4));
  End;
End;

{ ============================================================
  EncodeALU : groupe arithmetique/logique generique (ADD OR ADC
  SBB AND SUB XOR CMP), digit = 0..7 (ordre standard x86).
  Opcodes : base+0/1 = r/m,reg ; base+2/3 = reg,r/m ;
            base+4/5 = accum,imm ; 80/81/83 /digit = r/m,imm
  base = digit*8.
  ============================================================ }
Procedure EncodeALU(digit : Byte; Const op1, op2 : TOperand);
Var
  base : Byte;
  sz   : Integer;
Begin
  base := digit * 8;
  sz := OperandSize(op1);
  If sz = 0 Then sz := OperandSize(op2);
  If sz = 0 Then sz := 32;
  Emit16BitPrefix(sz);

  If (op2.kind = OPK_REG) And ((op1.kind = OPK_REG) Or (op1.kind = OPK_MEM)) Then
  Begin
    { r/m, reg }
    If sz = 8 Then BinEmitByte(base Or 0) Else BinEmitByte(base Or 1);
    EmitModRM(op2.reg.idx, op1);
    Exit;
  End;
  If (op1.kind = OPK_REG) And (op2.kind = OPK_MEM) Then
  Begin
    { reg, r/m }
    If sz = 8 Then BinEmitByte(base Or 2) Else BinEmitByte(base Or 3);
    EmitModRM(op1.reg.idx, op2);
    Exit;
  End;
  If op2.kind = OPK_IMM Then
  Begin
    { r/m, imm }
    If (op1.kind = OPK_REG) And (op1.reg.idx = 0) And (sz <> 8) And
       (Not op2.imm.is_reloc) And (Not op2.imm.is_extern) And
       (op2.imm.val >= -2147483647) Then
    Begin
      { forme courte AL/EAX, imm - toujours valide, utilisee simplement }
      BinEmitByte(base Or 5);
      BinEmitImmExpr(op2.imm, 4);
      Exit;
    End;
    If sz = 8 Then
    Begin
      BinEmitByte($80);
      EmitModRM(digit, op1);
      BinEmitImmExpr(op2.imm, 1);
    End
    Else If (Not op2.imm.is_reloc) And (Not op2.imm.is_extern) And
            (op2.imm.val >= -128) And (op2.imm.val <= 127) Then
    Begin
      BinEmitByte($83);
      EmitModRM(digit, op1);
      BinEmitImmExpr(op2.imm, 1);
    End
    Else
    Begin
      BinEmitByte($81);
      EmitModRM(digit, op1);
      BinEmitImmExpr(op2.imm, 4);
    End;
    Exit;
  End;
  ErrorMsg('Combinaison d operandes invalide pour instruction arithmetique');
End;

{ ============================================================
  EncodeMOV
  ============================================================ }
Procedure EncodeMOV(Const op1, op2 : TOperand);
Var
  sz : Integer;
Begin
  If op1.kind = OPK_REG Then
  Begin
    sz := OperandSize(op1);
    If op1.reg.kind = RK_SEG Then
    Begin
      { MOV segreg, r/m16 }
      BinEmitByte($8E);
      EmitModRM(op1.reg.idx, op2);
      Exit;
    End;
    If op2.kind = OPK_IMM Then
    Begin
      Emit16BitPrefix(sz);
      If sz = 8 Then
      Begin
        BinEmitByte(Byte($B0 Or op1.reg.idx));
        BinEmitImmExpr(op2.imm, 1);
      End
      Else
      Begin
        BinEmitByte(Byte($B8 Or op1.reg.idx));
        If sz = 16 Then BinEmitImmExpr(op2.imm, 2) Else BinEmitImmExpr(op2.imm, 4);
      End;
      Exit;
    End;
    If (op2.kind = OPK_REG) And (op2.reg.kind = RK_SEG) Then
    Begin
      BinEmitByte($8C);
      EmitModRM(op2.reg.idx, op1);
      Exit;
    End;
    { reg <- r/m }
    Emit16BitPrefix(sz);
    If sz = 8 Then BinEmitByte($8A) Else BinEmitByte($8B);
    EmitModRM(op1.reg.idx, op2);
    Exit;
  End;

  If op1.kind = OPK_MEM Then
  Begin
    sz := OperandSize(op1);
    If sz = 0 Then sz := OperandSize(op2);
    If sz = 0 Then sz := 32;
    If (op2.kind = OPK_REG) And (op2.reg.kind = RK_SEG) Then
    Begin
      BinEmitByte($8C);
      EmitModRM(op2.reg.idx, op1);
      Exit;
    End;
    If op2.kind = OPK_REG Then
    Begin
      Emit16BitPrefix(sz);
      If sz = 8 Then BinEmitByte($88) Else BinEmitByte($89);
      EmitModRM(op2.reg.idx, op1);
      Exit;
    End;
    If op2.kind = OPK_IMM Then
    Begin
      Emit16BitPrefix(sz);
      If sz = 8 Then
      Begin
        BinEmitByte($C6);
        EmitModRM(0, op1);
        BinEmitImmExpr(op2.imm, 1);
      End
      Else
      Begin
        BinEmitByte($C7);
        EmitModRM(0, op1);
        If sz = 16 Then BinEmitImmExpr(op2.imm, 2) Else BinEmitImmExpr(op2.imm, 4);
      End;
      Exit;
    End;
  End;
  ErrorMsg('Combinaison d operandes invalide pour MOV');
End;

{ ============================================================
  EncodeTEST
  ============================================================ }
Procedure EncodeTEST(Const op1, op2 : TOperand);
Var sz : Integer;
Begin
  sz := OperandSize(op1);
  If sz = 0 Then sz := OperandSize(op2);
  If sz = 0 Then sz := 32;
  Emit16BitPrefix(sz);
  If op2.kind = OPK_REG Then
  Begin
    If sz = 8 Then BinEmitByte($84) Else BinEmitByte($85);
    EmitModRM(op2.reg.idx, op1);
    Exit;
  End
  Else If op1.kind = OPK_REG Then
  Begin
    If sz = 8 Then BinEmitByte($84) Else BinEmitByte($85);
    EmitModRM(op1.reg.idx, op2);
    Exit;
  End
  Else If op2.kind = OPK_IMM Then
  Begin
    If sz = 8 Then
    Begin
      BinEmitByte($F6); EmitModRM(0, op1); BinEmitImmExpr(op2.imm, 1);
    End
    Else
    Begin
      BinEmitByte($F7); EmitModRM(0, op1);
      If sz = 16 Then BinEmitImmExpr(op2.imm, 2) Else BinEmitImmExpr(op2.imm, 4);
    End;
    Exit;
  End;
  ErrorMsg('Combinaison d operandes invalide pour TEST');
End;

{ ============================================================
  EncodeXCHG
  ============================================================ }
Procedure EncodeXCHG(Const op1, op2 : TOperand);
Var sz : Integer;
Begin
  sz := OperandSize(op1);
  If sz = 0 Then sz := OperandSize(op2);
  If sz = 0 Then sz := 32;
  Emit16BitPrefix(sz);
  If (op1.kind = OPK_REG) And (op1.reg.idx = 0) And (op2.kind = OPK_REG) And (sz <> 8) Then
  Begin
    BinEmitByte(Byte($90 Or op2.reg.idx));
    Exit;
  End;
  If (op2.kind = OPK_REG) And (op2.reg.idx = 0) And (op1.kind = OPK_REG) And (sz <> 8) Then
  Begin
    BinEmitByte(Byte($90 Or op1.reg.idx));
    Exit;
  End;
  If op2.kind = OPK_REG Then
  Begin
    If sz = 8 Then BinEmitByte($86) Else BinEmitByte($87);
    EmitModRM(op2.reg.idx, op1);
    Exit;
  End
  Else If op1.kind = OPK_REG Then
  Begin
    If sz = 8 Then BinEmitByte($86) Else BinEmitByte($87);
    EmitModRM(op1.reg.idx, op2);
    Exit;
  End;
  ErrorMsg('Combinaison d operandes invalide pour XCHG');
End;

{ ============================================================
  EncodeLEA
  ============================================================ }
Procedure EncodeLEA(Const op1, op2 : TOperand);
Begin
  If (op1.kind <> OPK_REG) Or (op2.kind <> OPK_MEM) Then
  Begin
    ErrorMsg('LEA requiert reg32, memoire');
    Exit;
  End;
  BinEmitByte($8D);
  EmitModRM(op1.reg.idx, op2);
End;

{ ============================================================
  EncodeShiftGroup : SHL/SAL/SHR/SAR/ROL/ROR/RCL/RCR.
  digit : 0=ROL 1=ROR 2=RCL 3=RCR 4=SHL/SAL 5=SHR 6=(rare) 7=SAR
  ============================================================ }
Procedure EncodeShiftGroup(digit : Byte; Const op1, op2 : TOperand);
Var sz : Integer;
Begin
  sz := OperandSize(op1);
  If sz = 0 Then sz := 32;
  Emit16BitPrefix(sz);
  If op2.kind = OPK_NONE Then
  Begin
    { forme implicite ,1 }
    If sz = 8 Then BinEmitByte($D0) Else BinEmitByte($D1);
    EmitModRM(digit, op1);
    Exit;
  End;
  If (op2.kind = OPK_REG) And (op2.reg.idx = 1) And (op2.reg.kind = RK_8) Then
  Begin
    { ,CL }
    If sz = 8 Then BinEmitByte($D2) Else BinEmitByte($D3);
    EmitModRM(digit, op1);
    Exit;
  End;
  If op2.kind = OPK_IMM Then
  Begin
    If (Not op2.imm.is_reloc) And (Not op2.imm.is_extern) And (op2.imm.val = 1) Then
    Begin
      If sz = 8 Then BinEmitByte($D0) Else BinEmitByte($D1);
      EmitModRM(digit, op1);
      Exit;
    End;
    If sz = 8 Then BinEmitByte($C0) Else BinEmitByte($C1);
    EmitModRM(digit, op1);
    BinEmitImmExpr(op2.imm, 1);
    Exit;
  End;
  ErrorMsg('Combinaison d operandes invalide pour instruction de decalage');
End;

{ ============================================================
  EncodeIncDec
  ============================================================ }
Procedure EncodeIncDec(is_dec : Boolean; Const op1 : TOperand);
Var sz : Integer; digit : Byte;
Begin
  sz := OperandSize(op1);
  If sz = 0 Then sz := 32;
  Emit16BitPrefix(sz);
  If is_dec Then digit := 1 Else digit := 0;
  If sz = 8 Then BinEmitByte($FE) Else BinEmitByte($FF);
  EmitModRM(digit, op1);
End;

{ ============================================================
  EncodeNegNot : NEG(/3) ou NOT(/2)
  ============================================================ }
Procedure EncodeNegNot(digit : Byte; Const op1 : TOperand);
Var sz : Integer;
Begin
  sz := OperandSize(op1);
  If sz = 0 Then sz := 32;
  Emit16BitPrefix(sz);
  If sz = 8 Then BinEmitByte($F6) Else BinEmitByte($F7);
  EmitModRM(digit, op1);
End;

{ ============================================================
  EncodeMulDivGroup : MUL(/4) IMUL-1op(/5) DIV(/6) IDIV(/7)
  ============================================================ }
Procedure EncodeMulDivGroup(digit : Byte; Const op1 : TOperand);
Var sz : Integer;
Begin
  sz := OperandSize(op1);
  If sz = 0 Then sz := 32;
  Emit16BitPrefix(sz);
  If sz = 8 Then BinEmitByte($F6) Else BinEmitByte($F7);
  EmitModRM(digit, op1);
End;

{ ============================================================
  EncodeIMUL : formes 1/2/3 operandes.
  ============================================================ }
Procedure EncodeIMUL(opcount : Integer; Const op1, op2, op3 : TOperand);
Var sz : Integer;
Begin
  If opcount = 1 Then
  Begin
    EncodeMulDivGroup(5, op1);
    Exit;
  End;
  If opcount = 2 Then
  Begin
    sz := OperandSize(op1);
    Emit16BitPrefix(sz);
    BinEmitByte($0F); BinEmitByte($AF);
    EmitModRM(op1.reg.idx, op2);
    Exit;
  End;
  { 3 operandes : reg, r/m, imm }
  sz := OperandSize(op1);
  Emit16BitPrefix(sz);
  If (Not op3.imm.is_reloc) And (Not op3.imm.is_extern) And
     (op3.imm.val >= -128) And (op3.imm.val <= 127) Then
  Begin
    BinEmitByte($6B);
    EmitModRM(op1.reg.idx, op2);
    BinEmitImmExpr(op3.imm, 1);
  End
  Else
  Begin
    BinEmitByte($69);
    EmitModRM(op1.reg.idx, op2);
    BinEmitImmExpr(op3.imm, 4);
  End;
End;

{ ============================================================
  EncodePUSH / EncodePOP
  ============================================================ }
Procedure EncodePUSH(Const op1 : TOperand);
Begin
  If (op1.kind = OPK_REG) And (op1.reg.kind = RK_32) Then
  Begin
    BinEmitByte(Byte($50 Or op1.reg.idx));
    Exit;
  End;
  If op1.kind = OPK_MEM Then
  Begin
    BinEmitByte($FF);
    EmitModRM(6, op1);
    Exit;
  End;
  If op1.kind = OPK_IMM Then
  Begin
    If (Not op1.imm.is_reloc) And (Not op1.imm.is_extern) And
       (op1.imm.val >= -128) And (op1.imm.val <= 127) Then
    Begin
      BinEmitByte($6A);
      BinEmitImmExpr(op1.imm, 1);
    End
    Else
    Begin
      BinEmitByte($68);
      BinEmitImmExpr(op1.imm, 4);
    End;
    Exit;
  End;
  If (op1.kind = OPK_REG) And (op1.reg.kind = RK_SEG) Then
  Begin
    Case op1.reg.idx Of
      0 : Begin BinEmitByte($06); Exit; End; { ES }
      1 : Begin BinEmitByte($0E); Exit; End; { CS }
      2 : Begin BinEmitByte($16); Exit; End; { SS }
      3 : Begin BinEmitByte($1E); Exit; End; { DS }
      4 : Begin BinEmitByte($0F); BinEmitByte($A0); Exit; End; { FS }
      5 : Begin BinEmitByte($0F); BinEmitByte($A8); Exit; End; { GS }
    End;
  End;
  ErrorMsg('Operande invalide pour PUSH');
End;

Procedure EncodePOP(Const op1 : TOperand);
Begin
  If (op1.kind = OPK_REG) And (op1.reg.kind = RK_32) Then
  Begin
    BinEmitByte(Byte($58 Or op1.reg.idx));
    Exit;
  End;
  If op1.kind = OPK_MEM Then
  Begin
    BinEmitByte($8F);
    EmitModRM(0, op1);
    Exit;
  End;
  If (op1.kind = OPK_REG) And (op1.reg.kind = RK_SEG) Then
  Begin
    Case op1.reg.idx Of
      0 : Begin BinEmitByte($07); Exit; End;
      2 : Begin BinEmitByte($17); Exit; End;
      3 : Begin BinEmitByte($1F); Exit; End;
      4 : Begin BinEmitByte($0F); BinEmitByte($A1); Exit; End;
      5 : Begin BinEmitByte($0F); BinEmitByte($A9); Exit; End;
    End;
  End;
  ErrorMsg('Operande invalide pour POP');
End;

{ ============================================================
  Table des conditions Jcc/SETcc/CMOVcc (nibble 0-15)
  ============================================================ }
Const
  CC_COUNT = 30;
  CC_NAMES : Array[1..30] Of String[3] = (
    'O','NO','B','C','NAE','NB','NC','AE','E','Z','NE','NZ',
    'BE','NA','A','NBE','S','NS','P','PE','NP','PO',
    'L','NGE','GE','NL','LE','NG','G','NLE'
  );
  CC_CODE : Array[1..30] Of Byte = (
    0,1,2,2,2,3,3,3,4,4,5,5,
    6,6,7,7,8,9,10,10,11,11,
    12,12,13,13,14,14,15,15
  );

Function CondCodeOf(Const s : TString) : Integer;
Var i : Integer;
Begin
  CondCodeOf := -1;
  For i := 1 To CC_COUNT Do
    If CC_NAMES[i] = s Then Begin CondCodeOf := CC_CODE[i]; Exit; End;
End;

{ ============================================================
  ExtractBranchTarget : reconnait une cible de branchement DIRECTE
  dans un operande deja analyse - soit OPK_IMM (ex: cible externe,
  ou constante), soit OPK_MEM sans base ni index (un label nu :
  depuis le correctif des semantiques MASM, "JMP label"/"CALL label"
  produisent desormais OPK_MEM comme tout autre label nu ; c est ICI
  qu on les reconnait comme une adresse cible plutot que comme une
  dereference memoire). Retourne False si l operande a une base ou
  un index (saut/appel reellement INDIRECT, gere par EmitModRM).
  ============================================================ }
Function ExtractBranchTarget(Const op : TOperand; Var target : TExpr) : Boolean;
Begin
  ExtractBranchTarget := False;
  If op.kind = OPK_IMM Then
  Begin
    target := op.imm;
    ExtractBranchTarget := True;
    Exit;
  End;
  If (op.kind = OPK_MEM) And (Not op.has_base) And (Not op.has_index) And op.has_disp Then
  Begin
    target := op.disp;
    ExtractBranchTarget := True;
  End;
End;

{ ============================================================
  EncodeJcc : saut conditionnel proche (forme 32 bits, 6 octets :
  0F 8x rel32). Simplification documentee : pas d optimisation
  vers la forme courte rel8 (2 octets).
  ============================================================ }
Procedure EncodeJcc(cc : Byte; Const target : TExpr);
Begin
  BinEmitByte($0F);
  BinEmitByte(Byte($80 Or cc));
  EmitRelToOperand(target);
End;

{ ============================================================
  EncodeJMP / EncodeCALL
  ============================================================ }
Procedure EncodeJMP(Const op1 : TOperand);
Var target : TExpr;
Begin
  If ExtractBranchTarget(op1, target) Then
  Begin
    BinEmitByte($E9);
    EmitRelToOperand(target);
    Exit;
  End;
  If (op1.kind = OPK_REG) Or (op1.kind = OPK_MEM) Then
  Begin
    BinEmitByte($FF);
    EmitModRM(4, op1);
    Exit;
  End;
  ErrorMsg('Operande invalide pour JMP');
End;

Procedure EncodeCALL(Const op1 : TOperand);
Var target : TExpr;
Begin
  If ExtractBranchTarget(op1, target) Then
  Begin
    BinEmitByte($E8);
    EmitRelToOperand(target);
    Exit;
  End;
  If (op1.kind = OPK_REG) Or (op1.kind = OPK_MEM) Then
  Begin
    BinEmitByte($FF);
    EmitModRM(2, op1);
    Exit;
  End;
  ErrorMsg('Operande invalide pour CALL');
End;

{ ============================================================
  EncodeShortJump : LOOP/LOOPE/LOOPNE/JECXZ - toujours rel8,
  resolu immediatement (meme section .text, donc invariant a
  l adresse de base finale de l image).
  ============================================================ }
Procedure EncodeShortJump(opc : Byte; Const target : TExpr);
Var
  rel : TLong;
Begin
  BinEmitByte(opc);
  If target.is_extern Then
  Begin
    ErrorMsg('Cible externe invalide pour un saut court (LOOP/JECXZ)');
    BinEmitByte(0);
    Exit;
  End;
  rel := target.val - (seg_table[cur_seg].cur_lc + 1);
  If (rel < -128) Or (rel > 127) Then
    ErrorMsg('Cible hors de portee pour un saut court (LOOP/JECXZ, +/-128)');
  BinEmitByte(Byte(rel And $FF));
End;

{ ============================================================
  Instructions sans operande / prefixes simples
  ============================================================ }
Procedure EncodeNoOperand(Const mnem : TString; Var handled : Boolean);
Begin
  handled := True;
  If mnem = 'NOP'    Then BinEmitByte($90)
  Else If mnem = 'INT3'   Then BinEmitByte($CC)
  Else If mnem = 'HLT'    Then BinEmitByte($F4)
  Else If mnem = 'CLC'    Then BinEmitByte($F8)
  Else If mnem = 'STC'    Then BinEmitByte($F9)
  Else If mnem = 'CMC'    Then BinEmitByte($F5)
  Else If mnem = 'CLD'    Then BinEmitByte($FC)
  Else If mnem = 'STD'    Then BinEmitByte($FD)
  Else If mnem = 'CLI'    Then BinEmitByte($FA)
  Else If mnem = 'STI'    Then BinEmitByte($FB)
  Else If mnem = 'LAHF'   Then BinEmitByte($9F)
  Else If mnem = 'SAHF'   Then BinEmitByte($9E)
  Else If mnem = 'PUSHFD' Then BinEmitByte($9C)
  Else If mnem = 'POPFD'  Then BinEmitByte($9D)
  Else If mnem = 'PUSHAD' Then BinEmitByte($60)
  Else If mnem = 'POPAD'  Then BinEmitByte($61)
  Else If mnem = 'CBW'    Then Begin BinEmitByte($66); BinEmitByte($98); End
  Else If mnem = 'CWDE'   Then BinEmitByte($98)
  Else If mnem = 'CWD'    Then Begin BinEmitByte($66); BinEmitByte($99); End
  Else If mnem = 'CDQ'    Then BinEmitByte($99)
  Else If mnem = 'LEAVE'  Then BinEmitByte($C9)
  Else If (mnem = 'WAIT') Or (mnem = 'FWAIT') Then BinEmitByte($9B)
  Else If mnem = 'RET'    Then BinEmitByte($C3)
  Else If mnem = 'RETN'   Then BinEmitByte($C3)
  Else If mnem = 'RETF'   Then BinEmitByte($CB)
  Else If mnem = 'MOVSB'  Then BinEmitByte($A4)
  Else If mnem = 'MOVSW'  Then Begin BinEmitByte($66); BinEmitByte($A5); End
  Else If mnem = 'MOVSD'  Then BinEmitByte($A5)
  Else If mnem = 'CMPSB'  Then BinEmitByte($A6)
  Else If mnem = 'CMPSW'  Then Begin BinEmitByte($66); BinEmitByte($A7); End
  Else If mnem = 'CMPSD'  Then BinEmitByte($A7)
  Else If mnem = 'SCASB'  Then BinEmitByte($AE)
  Else If mnem = 'SCASW'  Then Begin BinEmitByte($66); BinEmitByte($AF); End
  Else If mnem = 'SCASD'  Then BinEmitByte($AF)
  Else If mnem = 'LODSB'  Then BinEmitByte($AC)
  Else If mnem = 'LODSW'  Then Begin BinEmitByte($66); BinEmitByte($AD); End
  Else If mnem = 'LODSD'  Then BinEmitByte($AD)
  Else If mnem = 'STOSB'  Then BinEmitByte($AA)
  Else If mnem = 'STOSW'  Then Begin BinEmitByte($66); BinEmitByte($AB); End
  Else If mnem = 'STOSD'  Then BinEmitByte($AB)
  Else
    handled := False;
End;

{ ============================================================
  EncodeMOVSXZX : MOVSX/MOVZX reg32, r/m8|r/m16
  ============================================================ }
Procedure EncodeMOVSXZX(is_zx : Boolean; Const op1, op2 : TOperand);
Var src_sz : Integer;
Begin
  If op1.kind <> OPK_REG Then
  Begin
    ErrorMsg('MOVSX/MOVZX : premier operande doit etre un registre');
    Exit;
  End;
  src_sz := OperandSize(op2);
  If src_sz = 0 Then src_sz := 8;
  BinEmitByte($0F);
  If is_zx Then
  Begin
    If src_sz = 8 Then BinEmitByte($B6) Else BinEmitByte($B7);
  End
  Else
  Begin
    If src_sz = 8 Then BinEmitByte($BE) Else BinEmitByte($BF);
  End;
  EmitModRM(op1.reg.idx, op2);
End;

{ ============================================================
  EncodeCMOVcc : 0F 40+cc /r  (reg32, r/m32)
  ============================================================ }
Procedure EncodeCMOVcc(cc : Byte; Const op1, op2 : TOperand);
Begin
  BinEmitByte($0F);
  BinEmitByte(Byte($40 Or cc));
  EmitModRM(op1.reg.idx, op2);
End;

{ ============================================================
  EncodeSETcc : 0F 90+cc /0  (r/m8)
  ============================================================ }
Procedure EncodeSETcc(cc : Byte; Const op1 : TOperand);
Begin
  BinEmitByte($0F);
  BinEmitByte(Byte($90 Or cc));
  EmitModRM(0, op1);
End;

{ ============================================================
  EncodeBSWAP : 0F C8+reg
  ============================================================ }
Procedure EncodeBSWAP(Const op1 : TOperand);
Begin
  BinEmitByte($0F);
  BinEmitByte(Byte($C8 Or op1.reg.idx));
End;

{ ============================================================
  EncodeBSF_BSR : 0F BC (BSF) / 0F BD (BSR), reg32, r/m32
  ============================================================ }
Procedure EncodeBSF_BSR(is_bsr : Boolean; Const op1, op2 : TOperand);
Begin
  BinEmitByte($0F);
  If is_bsr Then BinEmitByte($BD) Else BinEmitByte($BC);
  EmitModRM(op1.reg.idx, op2);
End;

{ ============================================================
  EncodeBT_group : BT(/4) BTS(/5) BTR(/6) BTC(/7)
  Forme registre : 0F A3/AB/B3/BB  r/m32, r32
  Forme immediate : 0F BA /digit  r/m32, imm8
  ============================================================ }
Procedure EncodeBTGroup(digit : Byte; Const op1, op2 : TOperand);
Var opc : Byte;
Begin
  If op2.kind = OPK_REG Then
  Begin
    Case digit Of
      4 : opc := $A3;
      5 : opc := $AB;
      6 : opc := $B3;
    Else opc := $BB;
    End;
    BinEmitByte($0F);
    BinEmitByte(opc);
    EmitModRM(op2.reg.idx, op1);
    Exit;
  End;
  BinEmitByte($0F);
  BinEmitByte($BA);
  EmitModRM(digit, op1);
  BinEmitImmExpr(op2.imm, 1);
End;

{ ============================================================
  EncodeXADD / EncodeCMPXCHG : 0F C0/C1 (XADD), 0F B0/B1 (CMPXCHG)
  ============================================================ }
Procedure EncodeXADD(Const op1, op2 : TOperand);
Var sz : Integer;
Begin
  sz := OperandSize(op1);
  If sz = 8 Then BinEmitByte($0F)
  Else BinEmitByte($0F);
  If sz = 8 Then BinEmitByte($C0) Else BinEmitByte($C1);
  EmitModRM(op2.reg.idx, op1);
End;

Procedure EncodeCMPXCHG(Const op1, op2 : TOperand);
Var sz : Integer;
Begin
  sz := OperandSize(op1);
  BinEmitByte($0F);
  If sz = 8 Then BinEmitByte($B0) Else BinEmitByte($B1);
  EmitModRM(op2.reg.idx, op1);
End;

{ ============================================================
  TODO 5 - ENCODEUR FPU (x87) + MMX + SSE/SSE2
  ============================================================
  Limitation documentee (v1) : SSE3/SSSE3/SSE4/AVX, la plupart
  des instructions MMX/3DNow! rares (PAVGB, PMULHUW...) et les
  formes AVX/VEX ne sont pas couvertes - seul le sous-ensemble
  x87 courant, MMX de base et SSE/SSE2 usuel (mouvements et
  arithmetique scalaire/vectorielle simple) est implemente.
  Reste a faire (TODO 6+) : SSE3+, AVX, 3DNow!, formes rares.
  ============================================================ }

{ ============================================================
  EncodeFPUMemOnly : opcode/digit pour instruction FPU n acceptant
  qu un operande memoire (ex: FLDCW, FSTCW, FLDENV...). opc32/opc64
  selectionnent D9 ou DD selon que l on stocke des reels simples ou
  doubles ; ici on utilise un seul opcode fixe (fld/fst de controle).
  ============================================================ }
Procedure EncodeFPUMemDigit(opc : Byte; digit : Byte; Const op1 : TOperand);
Begin
  BinEmitByte(opc);
  EmitModRM(digit, op1);
End;

{ ============================================================
  EncodeFPUNoOperand : opcodes FPU a deux octets fixes (D9/DB/...)
  ============================================================ }
Function EncodeFPUNoOperand(Const mnem : TString) : Boolean;
Begin
  EncodeFPUNoOperand := True;
  If      mnem = 'FCHS'    Then Begin BinEmitByte($D9); BinEmitByte($E0); End
  Else If mnem = 'FABS'    Then Begin BinEmitByte($D9); BinEmitByte($E1); End
  Else If mnem = 'FTST'    Then Begin BinEmitByte($D9); BinEmitByte($E4); End
  Else If mnem = 'FXAM'    Then Begin BinEmitByte($D9); BinEmitByte($E5); End
  Else If mnem = 'FLD1'    Then Begin BinEmitByte($D9); BinEmitByte($E8); End
  Else If mnem = 'FLDL2T'  Then Begin BinEmitByte($D9); BinEmitByte($E9); End
  Else If mnem = 'FLDL2E'  Then Begin BinEmitByte($D9); BinEmitByte($EA); End
  Else If mnem = 'FLDPI'   Then Begin BinEmitByte($D9); BinEmitByte($EB); End
  Else If mnem = 'FLDLG2'  Then Begin BinEmitByte($D9); BinEmitByte($EC); End
  Else If mnem = 'FLDLN2'  Then Begin BinEmitByte($D9); BinEmitByte($ED); End
  Else If mnem = 'FLDZ'    Then Begin BinEmitByte($D9); BinEmitByte($EE); End
  Else If mnem = 'F2XM1'   Then Begin BinEmitByte($D9); BinEmitByte($F0); End
  Else If mnem = 'FYL2X'   Then Begin BinEmitByte($D9); BinEmitByte($F1); End
  Else If mnem = 'FPTAN'   Then Begin BinEmitByte($D9); BinEmitByte($F2); End
  Else If mnem = 'FPATAN'  Then Begin BinEmitByte($D9); BinEmitByte($F3); End
  Else If mnem = 'FXTRACT' Then Begin BinEmitByte($D9); BinEmitByte($F4); End
  Else If mnem = 'FPREM1'  Then Begin BinEmitByte($D9); BinEmitByte($F5); End
  Else If mnem = 'FDECSTP' Then Begin BinEmitByte($D9); BinEmitByte($F6); End
  Else If mnem = 'FINCSTP' Then Begin BinEmitByte($D9); BinEmitByte($F7); End
  Else If mnem = 'FPREM'   Then Begin BinEmitByte($D9); BinEmitByte($F8); End
  Else If mnem = 'FYL2XP1' Then Begin BinEmitByte($D9); BinEmitByte($F9); End
  Else If mnem = 'FSQRT'   Then Begin BinEmitByte($D9); BinEmitByte($FA); End
  Else If mnem = 'FSINCOS' Then Begin BinEmitByte($D9); BinEmitByte($FB); End
  Else If mnem = 'FRNDINT' Then Begin BinEmitByte($D9); BinEmitByte($FC); End
  Else If mnem = 'FSCALE'  Then Begin BinEmitByte($D9); BinEmitByte($FD); End
  Else If mnem = 'FSIN'    Then Begin BinEmitByte($D9); BinEmitByte($FE); End
  Else If mnem = 'FCOS'    Then Begin BinEmitByte($D9); BinEmitByte($FF); End
  Else If mnem = 'FNOP'    Then Begin BinEmitByte($D9); BinEmitByte($D0); End
  Else If mnem = 'FCOMPP'  Then Begin BinEmitByte($DE); BinEmitByte($D9); End
  Else If mnem = 'FUCOMPP' Then Begin BinEmitByte($DA); BinEmitByte($E9); End
  Else If (mnem = 'FCLEX') Or (mnem = 'FNCLEX') Then Begin BinEmitByte($DB); BinEmitByte($E2); End
  Else If (mnem = 'FINIT') Or (mnem = 'FNINIT') Then Begin BinEmitByte($DB); BinEmitByte($E3); End
  Else If mnem = 'EMMS'    Then Begin BinEmitByte($0F); BinEmitByte($77); End
  Else
    EncodeFPUNoOperand := False;
End;

{ ============================================================
  EncodeFPUArith : ADD/MUL/SUB/SUBR/DIV/DIVR/COM/COMP.
  digit standard (memoire/ST(0),ST(i)) : ADD=0 MUL=1 COM=2 COMP=3
  SUB=4 SUBR=5 DIV=6 DIVR=7.
  revdigit (formes ST(i),ST(0) et P/pop) : inverse SUB/SUBR et
  DIV/DIVR (quirk historique x87 documente).
  ============================================================ }
Procedure EncodeFPUArith(digit, revdigit : Byte; is_pop : Boolean;
                         opcount : Integer; Const op1, op2 : TOperand);
Begin
  If opcount = 0 Then
  Begin
    { forme implicite ST(1),ST(0) avec pop (ex: FADDP seul) }
    BinEmitByte($DE);
    BinEmitByte(Byte($C0 Or (revdigit Shl 3) Or 1));
    Exit;
  End;
  If opcount = 1 Then
  Begin
    If op1.kind = OPK_MEM Then
    Begin
      { memoire reel simple (D8) par defaut, DWORD PTR/QWORD PTR selon size_hint }
      If op1.size_hint = DS_QWORD Then BinEmitByte($DC) Else BinEmitByte($D8);
      EmitModRM(digit, op1);
      Exit;
    End;
    If op1.kind = OPK_ST Then
    Begin
      { ST(i) implicite avec ST(0), avec pop si is_pop }
      If is_pop Then BinEmitByte($DE) Else BinEmitByte($DC);
      BinEmitByte(Byte($C0 Or (revdigit Shl 3) Or (op1.reg.idx And 7)));
      Exit;
    End;
    ErrorMsg('Operande invalide pour instruction FPU arithmetique');
    Exit;
  End;
  { 2 operandes : ST(0),ST(i) ou ST(i),ST(0) }
  If (op1.kind = OPK_ST) And (op1.reg.idx = 0) And (op2.kind = OPK_ST) Then
  Begin
    BinEmitByte($D8);
    BinEmitByte(Byte($C0 Or (digit Shl 3) Or (op2.reg.idx And 7)));
    Exit;
  End;
  If (op1.kind = OPK_ST) And (op2.kind = OPK_ST) And (op2.reg.idx = 0) Then
  Begin
    If is_pop Then BinEmitByte($DE) Else BinEmitByte($DC);
    BinEmitByte(Byte($C0 Or (revdigit Shl 3) Or (op1.reg.idx And 7)));
    Exit;
  End;
  ErrorMsg('Combinaison d operandes ST(i) invalide pour instruction FPU');
End;

{ ============================================================
  EncodeFLD / EncodeFST / EncodeFSTP / EncodeFILD / EncodeFIST /
  EncodeFISTP
  ============================================================ }
Procedure EncodeFLD(Const op1 : TOperand);
Begin
  If op1.kind = OPK_ST Then
  Begin
    BinEmitByte($D9);
    BinEmitByte(Byte($C0 Or (op1.reg.idx And 7)));
    Exit;
  End;
  If op1.size_hint = DS_TBYTE Then
  Begin
    BinEmitByte($DB); EmitModRM(5, op1); Exit;
  End;
  If op1.size_hint = DS_QWORD Then
  Begin
    BinEmitByte($DD); EmitModRM(0, op1); Exit;
  End;
  BinEmitByte($D9); EmitModRM(0, op1);
End;

Procedure EncodeFSTGeneric(is_pop : Boolean; Const op1 : TOperand);
Var digit : Byte;
Begin
  If is_pop Then digit := 3 Else digit := 2;
  If op1.kind = OPK_ST Then
  Begin
    If is_pop Then BinEmitByte($DD) Else BinEmitByte($DD);
    If is_pop Then
      BinEmitByte(Byte($D8 Or (op1.reg.idx And 7)))
    Else
      BinEmitByte(Byte($D0 Or (op1.reg.idx And 7)));
    Exit;
  End;
  If op1.size_hint = DS_TBYTE Then
  Begin
    If Not is_pop Then
    Begin
      ErrorMsg('FST vers TBYTE PTR invalide (utiliser FSTP)');
      Exit;
    End;
    BinEmitByte($DB); EmitModRM(7, op1); Exit;
  End;
  If op1.size_hint = DS_QWORD Then
  Begin
    BinEmitByte($DD); EmitModRM(digit, op1); Exit;
  End;
  BinEmitByte($D9); EmitModRM(digit, op1);
End;

Procedure EncodeFILD(Const op1 : TOperand);
Begin
  If op1.size_hint = DS_QWORD Then Begin BinEmitByte($DF); EmitModRM(5, op1); Exit; End;
  If op1.size_hint = DS_WORD  Then Begin BinEmitByte($DF); EmitModRM(0, op1); Exit; End;
  BinEmitByte($DB); EmitModRM(0, op1);
End;

Procedure EncodeFISTGeneric(is_pop : Boolean; Const op1 : TOperand);
Begin
  If op1.size_hint = DS_QWORD Then
  Begin
    If Not is_pop Then
    Begin
      ErrorMsg('FIST vers QWORD PTR invalide (utiliser FISTP)');
      Exit;
    End;
    BinEmitByte($DF); EmitModRM(7, op1); Exit;
  End;
  If op1.size_hint = DS_WORD Then
  Begin
    If is_pop Then Begin BinEmitByte($DF); EmitModRM(3, op1); End
    Else           Begin BinEmitByte($DF); EmitModRM(2, op1); End;
    Exit;
  End;
  If is_pop Then Begin BinEmitByte($DB); EmitModRM(3, op1); End
  Else           Begin BinEmitByte($DB); EmitModRM(2, op1); End;
End;

{ ============================================================
  EncodeFXCH / EncodeFFREE / EncodeFCOMI-family / EncodeFUCOM
  ============================================================ }
Procedure EncodeFXCH(opcount : Integer; Const op1 : TOperand);
Begin
  If opcount = 0 Then
  Begin
    BinEmitByte($D9); BinEmitByte($C9);
    Exit;
  End;
  BinEmitByte($D9);
  BinEmitByte(Byte($C8 Or (op1.reg.idx And 7)));
End;

Procedure EncodeFFREE(Const op1 : TOperand);
Begin
  BinEmitByte($DD);
  BinEmitByte(Byte($C0 Or (op1.reg.idx And 7)));
End;

{ FCOMI/FCOMIP/FUCOMI/FUCOMIP : DB/DF F0+i }
Procedure EncodeFCOMI(opc0 : Byte; opc1 : Byte; opcount : Integer; Const op1 : TOperand);
Var idx : Byte;
Begin
  If opcount = 0 Then idx := 1 Else idx := op1.reg.idx And 7;
  BinEmitByte(opc0);
  BinEmitByte(Byte(opc1 Or idx));
End;

{ FUCOM/FUCOMP : DD E0+i / E8+i }
Procedure EncodeFUCOM(is_pop : Boolean; opcount : Integer; Const op1 : TOperand);
Var idx : Byte;
Begin
  If opcount = 0 Then idx := 1 Else idx := op1.reg.idx And 7;
  BinEmitByte($DD);
  If is_pop Then BinEmitByte(Byte($E8 Or idx)) Else BinEmitByte(Byte($E0 Or idx));
End;

{ FCOM/FCOMP : memoire (D8/DC, digit 2/3) ou ST(i) (D8 D0+i / D8 D8+i) }
Procedure EncodeFCOM(is_pop : Boolean; opcount : Integer; Const op1 : TOperand);
Var idx : Byte;
Begin
  If opcount = 0 Then
  Begin
    BinEmitByte($D8);
    If is_pop Then BinEmitByte($D9) Else BinEmitByte($D1);
    Exit;
  End;
  If op1.kind = OPK_ST Then
  Begin
    idx := op1.reg.idx And 7;
    BinEmitByte($D8);
    If is_pop Then BinEmitByte(Byte($D8 Or idx)) Else BinEmitByte(Byte($D0 Or idx));
    Exit;
  End;
  If op1.size_hint = DS_QWORD Then BinEmitByte($DC) Else BinEmitByte($D8);
  If is_pop Then EmitModRM(3, op1) Else EmitModRM(2, op1);
End;

{ ============================================================
  EncodeFLDCW / EncodeFSTCW / EncodeFSTSW
  ============================================================ }
Procedure EncodeFLDCW(Const op1 : TOperand);
Begin
  BinEmitByte($D9); EmitModRM(5, op1);
End;

Procedure EncodeFSTCW(Const op1 : TOperand);
Begin
  BinEmitByte($9B); BinEmitByte($D9); EmitModRM(7, op1);
End;

Procedure EncodeFNSTCW(Const op1 : TOperand);
Begin
  BinEmitByte($D9); EmitModRM(7, op1);
End;

Procedure EncodeFSTSW(opcount : Integer; Const op1 : TOperand);
Begin
  If (opcount = 1) And (op1.kind = OPK_REG) And (op1.reg.idx = 0) And (op1.reg.kind = RK_16) Then
  Begin
    BinEmitByte($9B); BinEmitByte($DF); BinEmitByte($E0);
    Exit;
  End;
  BinEmitByte($9B); BinEmitByte($DD); EmitModRM(7, op1);
End;

Procedure EncodeFNSTSW(opcount : Integer; Const op1 : TOperand);
Begin
  If (opcount = 1) And (op1.kind = OPK_REG) And (op1.reg.idx = 0) And (op1.reg.kind = RK_16) Then
  Begin
    BinEmitByte($DF); BinEmitByte($E0);
    Exit;
  End;
  BinEmitByte($DD); EmitModRM(7, op1);
End;

{ ============================================================
  MMX : registres MM0-7. Dispatch generique par mnemonique.
  Toutes les instructions MMX ici utilisent le prefixe 0F et
  travaillent sur MMX,MMX/m64 (reg_field=op1, rm=op2).
  ============================================================ }
Function EncodeMMX(Const mnem : TString; opcount : Integer;
                   Const op1, op2 : TOperand) : Boolean;
Var opc2 : Byte; ok : Boolean;
Begin
  ok := True;
  If      mnem = 'MOVQ'    Then
  Begin
    If op1.kind = OPK_MEM Then Begin BinEmitByte($0F); BinEmitByte($7F); EmitModRM(op2.reg.idx, op1); Exit(True); End
    Else Begin BinEmitByte($0F); BinEmitByte($6F); EmitModRM(op1.reg.idx, op2); Exit(True); End;
  End
  Else If mnem = 'MOVD'    Then
  Begin
    If op1.kind = OPK_MEM Then Begin BinEmitByte($0F); BinEmitByte($7E); EmitModRM(op2.reg.idx, op1); Exit(True); End
    Else Begin BinEmitByte($0F); BinEmitByte($6E); EmitModRM(op1.reg.idx, op2); Exit(True); End;
  End
  Else If mnem = 'PADDB'   Then opc2 := $FC
  Else If mnem = 'PADDW'   Then opc2 := $FD
  Else If mnem = 'PADDD'   Then opc2 := $FE
  Else If mnem = 'PSUBB'   Then opc2 := $F8
  Else If mnem = 'PSUBW'   Then opc2 := $F9
  Else If mnem = 'PSUBD'   Then opc2 := $FA
  Else If mnem = 'PAND'    Then opc2 := $DB
  Else If mnem = 'PANDN'   Then opc2 := $DF
  Else If mnem = 'POR'     Then opc2 := $EB
  Else If mnem = 'PXOR'    Then opc2 := $EF
  Else If mnem = 'PCMPEQB' Then opc2 := $74
  Else If mnem = 'PCMPEQW' Then opc2 := $75
  Else If mnem = 'PCMPEQD' Then opc2 := $76
  Else If mnem = 'PCMPGTB' Then opc2 := $64
  Else If mnem = 'PCMPGTW' Then opc2 := $65
  Else If mnem = 'PCMPGTD' Then opc2 := $66
  Else If mnem = 'PMULLW'  Then opc2 := $D5
  Else If mnem = 'PMADDWD' Then opc2 := $F5
  Else If mnem = 'PSLLW'   Then opc2 := $F1
  Else If mnem = 'PSLLD'   Then opc2 := $F2
  Else If mnem = 'PSLLQ'   Then opc2 := $F3
  Else If mnem = 'PSRLW'   Then opc2 := $D1
  Else If mnem = 'PSRLD'   Then opc2 := $D2
  Else If mnem = 'PSRLQ'   Then opc2 := $D3
  Else If mnem = 'PSRAW'   Then opc2 := $E1
  Else If mnem = 'PSRAD'   Then opc2 := $E2
  Else If mnem = 'PACKSSWB' Then opc2 := $63
  Else If mnem = 'PACKSSDW' Then opc2 := $6B
  Else If mnem = 'PUNPCKLBW' Then opc2 := $60
  Else If mnem = 'PUNPCKLWD' Then opc2 := $61
  Else If mnem = 'PUNPCKLDQ' Then opc2 := $62
  Else ok := False;

  If Not ok Then Begin EncodeMMX := False; Exit; End;
  BinEmitByte($0F);
  BinEmitByte(opc2);
  EmitModRM(op1.reg.idx, op2);
  EncodeMMX := True;
End;

{ ============================================================
  SSE/SSE2 : registres XMM0-7. Prefixes obligatoires :
  MOVSS/ADDSS.. = F3 0F ; MOVSD/ADDSD.. = F2 0F ; PS = 0F ;
  PD = 66 0F. Dispatch par mnemonique (suffixe SS/SD/PS/PD).
  ============================================================ }
Function EncodeSSE(Const mnem : TString; opcount : Integer;
                   Const op1, op2 : TOperand) : Boolean;
Var
  opc2 : Byte;
  pfx  : Byte; { 0=aucun 1=F3 2=F2 3=66 }
  ok   : Boolean;
Begin
  ok := True;
  pfx := 0;
  EncodeSSE := False;

  If mnem = 'MOVSS' Then Begin pfx := 1; opc2 := $10; End
  Else If mnem = 'MOVSD' Then Begin pfx := 2; opc2 := $10; End
  Else If mnem = 'MOVAPS' Then Begin pfx := 0; opc2 := $28; End
  Else If mnem = 'MOVUPS' Then Begin pfx := 0; opc2 := $10; End
  Else If mnem = 'MOVAPD' Then Begin pfx := 3; opc2 := $28; End
  Else If mnem = 'MOVUPD' Then Begin pfx := 3; opc2 := $10; End
  Else If mnem = 'ADDSS' Then Begin pfx := 1; opc2 := $58; End
  Else If mnem = 'ADDSD' Then Begin pfx := 2; opc2 := $58; End
  Else If mnem = 'ADDPS' Then Begin pfx := 0; opc2 := $58; End
  Else If mnem = 'ADDPD' Then Begin pfx := 3; opc2 := $58; End
  Else If mnem = 'SUBSS' Then Begin pfx := 1; opc2 := $5C; End
  Else If mnem = 'SUBSD' Then Begin pfx := 2; opc2 := $5C; End
  Else If mnem = 'SUBPS' Then Begin pfx := 0; opc2 := $5C; End
  Else If mnem = 'SUBPD' Then Begin pfx := 3; opc2 := $5C; End
  Else If mnem = 'MULSS' Then Begin pfx := 1; opc2 := $59; End
  Else If mnem = 'MULSD' Then Begin pfx := 2; opc2 := $59; End
  Else If mnem = 'MULPS' Then Begin pfx := 0; opc2 := $59; End
  Else If mnem = 'MULPD' Then Begin pfx := 3; opc2 := $59; End
  Else If mnem = 'DIVSS' Then Begin pfx := 1; opc2 := $5E; End
  Else If mnem = 'DIVSD' Then Begin pfx := 2; opc2 := $5E; End
  Else If mnem = 'DIVPS' Then Begin pfx := 0; opc2 := $5E; End
  Else If mnem = 'DIVPD' Then Begin pfx := 3; opc2 := $5E; End
  Else If mnem = 'SQRTSS' Then Begin pfx := 1; opc2 := $51; End
  Else If mnem = 'SQRTSD' Then Begin pfx := 2; opc2 := $51; End
  Else If mnem = 'MINSS' Then Begin pfx := 1; opc2 := $5D; End
  Else If mnem = 'MINSD' Then Begin pfx := 2; opc2 := $5D; End
  Else If mnem = 'MAXSS' Then Begin pfx := 1; opc2 := $5F; End
  Else If mnem = 'MAXSD' Then Begin pfx := 2; opc2 := $5F; End
  Else If mnem = 'ANDPS' Then Begin pfx := 0; opc2 := $54; End
  Else If mnem = 'ANDPD' Then Begin pfx := 3; opc2 := $54; End
  Else If mnem = 'ORPS'  Then Begin pfx := 0; opc2 := $56; End
  Else If mnem = 'ORPD'  Then Begin pfx := 3; opc2 := $56; End
  Else If mnem = 'XORPS' Then Begin pfx := 0; opc2 := $57; End
  Else If mnem = 'XORPD' Then Begin pfx := 3; opc2 := $57; End
  Else If mnem = 'COMISS' Then Begin pfx := 0; opc2 := $2F; End
  Else If mnem = 'COMISD' Then Begin pfx := 3; opc2 := $2F; End
  Else If mnem = 'UCOMISS' Then Begin pfx := 0; opc2 := $2E; End
  Else If mnem = 'UCOMISD' Then Begin pfx := 3; opc2 := $2E; End
  Else If mnem = 'CVTSI2SS' Then Begin pfx := 1; opc2 := $2A; End
  Else If mnem = 'CVTSI2SD' Then Begin pfx := 2; opc2 := $2A; End
  Else If mnem = 'CVTTSS2SI' Then Begin pfx := 1; opc2 := $2C; End
  Else If mnem = 'CVTTSD2SI' Then Begin pfx := 2; opc2 := $2C; End
  Else If mnem = 'CVTSS2SI' Then Begin pfx := 1; opc2 := $2D; End
  Else If mnem = 'CVTSD2SI' Then Begin pfx := 2; opc2 := $2D; End
  Else If mnem = 'CVTSS2SD' Then Begin pfx := 1; opc2 := $5A; End
  Else If mnem = 'CVTSD2SS' Then Begin pfx := 2; opc2 := $5A; End
  Else If mnem = 'PSHUFD' Then Begin pfx := 3; opc2 := $70; End
  Else ok := False;

  If Not ok Then Exit;

  { MOVSS/MOVSD/MOVUPS/MOVAPS/MOVUPD/MOVAPD : opcode+1 pour la forme store
    (op1=memoire, op2=xmm) - meme prefixe, ModRM inverse (reg=source) }
  If ((mnem = 'MOVSS') Or (mnem = 'MOVSD') Or (mnem = 'MOVAPS') Or
      (mnem = 'MOVUPS') Or (mnem = 'MOVAPD') Or (mnem = 'MOVUPD')) And
     (op1.kind = OPK_MEM) Then
    opc2 := opc2 + 1;

  Case pfx Of
    1 : BinEmitByte($F3);
    2 : BinEmitByte($F2);
    3 : BinEmitByte($66);
  End;
  BinEmitByte($0F);
  BinEmitByte(opc2);

  If (mnem = 'CVTSI2SS') Or (mnem = 'CVTSI2SD') Then
    EmitModRM(op1.reg.idx, op2)
  Else If (mnem = 'CVTTSS2SI') Or (mnem = 'CVTTSD2SI') Or
          (mnem = 'CVTSS2SI') Or (mnem = 'CVTSD2SI') Then
    EmitModRM(op1.reg.idx, op2)
  Else If (op1.kind = OPK_MEM) And
          ((mnem = 'MOVSS') Or (mnem = 'MOVSD') Or (mnem = 'MOVAPS') Or
           (mnem = 'MOVUPS') Or (mnem = 'MOVAPD') Or (mnem = 'MOVUPD')) Then
    EmitModRM(op2.reg.idx, op1)
  Else
    EmitModRM(op1.reg.idx, op2);

  EncodeSSE := True;
End;

{ ============================================================
  TryFPUMMXSSE : point d entree unique pour toutes les
  instructions x87/MMX/SSE, quel que soit le nombre d operandes.
  Appele en dernier recours par AssembleInstruction.
  ============================================================ }
Function TryFPUMMXSSE(Const mnem : TString; opcount : Integer;
                      Const op1, op2, op3 : TOperand) : Boolean;
Begin
  TryFPUMMXSSE := True;

  If EncodeFPUNoOperand(mnem) Then Exit;

  If      mnem = 'FLD'  Then Begin EncodeFLD(op1); Exit; End
  Else If mnem = 'FST'  Then Begin EncodeFSTGeneric(False, op1); Exit; End
  Else If mnem = 'FSTP' Then Begin EncodeFSTGeneric(True, op1); Exit; End
  Else If mnem = 'FILD' Then Begin EncodeFILD(op1); Exit; End
  Else If mnem = 'FIST' Then Begin EncodeFISTGeneric(False, op1); Exit; End
  Else If mnem = 'FISTP' Then Begin EncodeFISTGeneric(True, op1); Exit; End
  Else If mnem = 'FXCH' Then Begin EncodeFXCH(opcount, op1); Exit; End
  Else If mnem = 'FFREE' Then Begin EncodeFFREE(op1); Exit; End
  Else If mnem = 'FLDCW' Then Begin EncodeFLDCW(op1); Exit; End
  Else If mnem = 'FSTCW' Then Begin EncodeFSTCW(op1); Exit; End
  Else If mnem = 'FNSTCW' Then Begin EncodeFNSTCW(op1); Exit; End
  Else If mnem = 'FSTSW' Then Begin EncodeFSTSW(opcount, op1); Exit; End
  Else If mnem = 'FNSTSW' Then Begin EncodeFNSTSW(opcount, op1); Exit; End
  Else If mnem = 'FCOM'  Then Begin EncodeFCOM(False, opcount, op1); Exit; End
  Else If mnem = 'FCOMP' Then Begin EncodeFCOM(True, opcount, op1); Exit; End
  Else If mnem = 'FUCOM'  Then Begin EncodeFUCOM(False, opcount, op1); Exit; End
  Else If mnem = 'FUCOMP' Then Begin EncodeFUCOM(True, opcount, op1); Exit; End
  Else If mnem = 'FCOMI'   Then Begin EncodeFCOMI($DB, $F0, opcount, op1); Exit; End
  Else If mnem = 'FCOMIP'  Then Begin EncodeFCOMI($DF, $F0, opcount, op1); Exit; End
  Else If mnem = 'FUCOMI'  Then Begin EncodeFCOMI($DB, $E8, opcount, op1); Exit; End
  Else If mnem = 'FUCOMIP' Then Begin EncodeFCOMI($DF, $E8, opcount, op1); Exit; End
  Else If mnem = 'FADD'   Then Begin EncodeFPUArith(0, 0, False, opcount, op1, op2); Exit; End
  Else If mnem = 'FMUL'   Then Begin EncodeFPUArith(1, 1, False, opcount, op1, op2); Exit; End
  Else If mnem = 'FSUB'   Then Begin EncodeFPUArith(4, 5, False, opcount, op1, op2); Exit; End
  Else If mnem = 'FSUBR'  Then Begin EncodeFPUArith(5, 4, False, opcount, op1, op2); Exit; End
  Else If mnem = 'FDIV'   Then Begin EncodeFPUArith(6, 7, False, opcount, op1, op2); Exit; End
  Else If mnem = 'FDIVR'  Then Begin EncodeFPUArith(7, 6, False, opcount, op1, op2); Exit; End
  Else If mnem = 'FADDP'  Then Begin EncodeFPUArith(0, 0, True, opcount, op1, op2); Exit; End
  Else If mnem = 'FMULP'  Then Begin EncodeFPUArith(1, 1, True, opcount, op1, op2); Exit; End
  Else If mnem = 'FSUBP'  Then Begin EncodeFPUArith(4, 5, True, opcount, op1, op2); Exit; End
  Else If mnem = 'FSUBRP' Then Begin EncodeFPUArith(5, 4, True, opcount, op1, op2); Exit; End
  Else If mnem = 'FDIVP'  Then Begin EncodeFPUArith(6, 7, True, opcount, op1, op2); Exit; End
  Else If mnem = 'FDIVRP' Then Begin EncodeFPUArith(7, 6, True, opcount, op1, op2); Exit; End
  Else If (opcount = 2) And EncodeMMX(mnem, opcount, op1, op2) Then Exit
  Else If (opcount = 2) And EncodeSSE(mnem, opcount, op1, op2) Then Exit
  Else
    TryFPUMMXSSE := False;
End;

{ ============================================================
  ParseOperandList : lire 0..3 operandes separes par des
  virgules, jusqu a la fin de la ligne logique.
  ============================================================ }
Procedure ParseOperandList(Var op1, op2, op3 : TOperand; Var opcount : Integer);
Begin
  ClearOperand(op1); ClearOperand(op2); ClearOperand(op3);
  opcount := 0;
  If (LexPeekKind = TK_NEWLINE) Or (LexPeekKind = TK_EOF) Then Exit;
  ParseOperand(op1); opcount := 1;
  While (LexPeekKind = TK_PUNCT) And (LexPeekVal = ',') Do
  Begin
    LexNext; { consommer , }
    If opcount = 1 Then Begin ParseOperand(op2); opcount := 2; End
    Else If opcount = 2 Then Begin ParseOperand(op3); opcount := 3; End
    Else
    Begin
      { operandes supplementaires ignores (rare, ex INVOKE varargs geres ailleurs) }
      ParseOperand(op3);
    End;
  End;
End;

{ ============================================================
  AssembleInstruction : point d entree principal de l encodeur.
  mnem est deja en majuscules. Consomme les operandes de la
  ligne logique courante. Retourne False si mnem n est pas une
  instruction reconnue (l appelant essaiera alors les directives).
  ============================================================ }
Function AssembleInstruction(Const mnem0 : TString) : Boolean;
Var
  mnem      : TString;
  op1,op2,op3 : TOperand;
  opcount   : Integer;
  handled   : Boolean;
  cc        : Integer;
  suffix    : TString;
  rep_kind  : Byte; { 0=aucun 1=F3(REP/REPE) 2=F2(REPNE) }
  jtarget   : TExpr;
Begin
  AssembleInstruction := True;
  mnem := mnem0;

  { ---- prefixes LOCK / REP / REPE / REPNE ---- }
  rep_kind := 0;
  If mnem = 'LOCK' Then
  Begin
    BinEmitByte($F0);
    If LexPeekKind = TK_IDENT Then
    Begin
      LexNext;
      mnem := lex_tok.val;
    End;
  End;
  If (mnem = 'REP') Or (mnem = 'REPE') Or (mnem = 'REPZ') Then rep_kind := 1;
  If (mnem = 'REPNE') Or (mnem = 'REPNZ') Then rep_kind := 2;
  If rep_kind <> 0 Then
  Begin
    If LexPeekKind <> TK_IDENT Then
    Begin
      ErrorMsg('Mnemonique attendu apres REP/REPNE');
      AssembleInstruction := True;
      Exit;
    End;
    LexNext;
    mnem := lex_tok.val;
    If rep_kind = 1 Then BinEmitByte($F3) Else BinEmitByte($F2);
  End;

  ParseOperandList(op1, op2, op3, opcount);

  { ---- instructions sans operande ---- }
  If opcount = 0 Then
  Begin
    EncodeNoOperand(mnem, handled);
    If handled Then Exit;
  End;

  { ---- groupe arithmetique (2 operandes) ---- }
  If opcount = 2 Then
  Begin
    handled := True;
    If      mnem = 'ADD' Then EncodeALU(0, op1, op2)
    Else If mnem = 'OR'  Then EncodeALU(1, op1, op2)
    Else If mnem = 'ADC' Then EncodeALU(2, op1, op2)
    Else If mnem = 'SBB' Then EncodeALU(3, op1, op2)
    Else If mnem = 'AND' Then EncodeALU(4, op1, op2)
    Else If mnem = 'SUB' Then EncodeALU(5, op1, op2)
    Else If mnem = 'XOR' Then EncodeALU(6, op1, op2)
    Else If mnem = 'CMP' Then EncodeALU(7, op1, op2)
    Else If mnem = 'MOV' Then EncodeMOV(op1, op2)
    Else If mnem = 'TEST' Then EncodeTEST(op1, op2)
    Else If mnem = 'XCHG' Then EncodeXCHG(op1, op2)
    Else If mnem = 'LEA'  Then EncodeLEA(op1, op2)
    Else If mnem = 'MOVZX' Then EncodeMOVSXZX(True, op1, op2)
    Else If mnem = 'MOVSX' Then EncodeMOVSXZX(False, op1, op2)
    Else If mnem = 'BSF' Then EncodeBSF_BSR(False, op1, op2)
    Else If mnem = 'BSR' Then EncodeBSF_BSR(True, op1, op2)
    Else If mnem = 'BT'  Then EncodeBTGroup(4, op1, op2)
    Else If mnem = 'BTS' Then EncodeBTGroup(5, op1, op2)
    Else If mnem = 'BTR' Then EncodeBTGroup(6, op1, op2)
    Else If mnem = 'BTC' Then EncodeBTGroup(7, op1, op2)
    Else If mnem = 'XADD' Then EncodeXADD(op1, op2)
    Else If (mnem = 'CMPXCHG') Or (mnem = 'CMPXCHGL') Then EncodeCMPXCHG(op1, op2)
    Else If (mnem = 'SHL') Or (mnem = 'SAL') Then EncodeShiftGroup(4, op1, op2)
    Else If mnem = 'SHR' Then EncodeShiftGroup(5, op1, op2)
    Else If mnem = 'SAR' Then EncodeShiftGroup(7, op1, op2)
    Else If mnem = 'ROL' Then EncodeShiftGroup(0, op1, op2)
    Else If mnem = 'ROR' Then EncodeShiftGroup(1, op1, op2)
    Else If mnem = 'RCL' Then EncodeShiftGroup(2, op1, op2)
    Else If mnem = 'RCR' Then EncodeShiftGroup(3, op1, op2)
    Else If mnem = 'IMUL' Then EncodeIMUL(2, op1, op2, op2)
    Else
    Begin
      If (Length(mnem) >= 4) And (Copy(mnem,1,4) = 'CMOV') Then
      Begin
        suffix := Copy(mnem, 5, Length(mnem)-4);
        cc := CondCodeOf(suffix);
        If cc >= 0 Then EncodeCMOVcc(cc, op1, op2)
        Else handled := False;
      End
      Else
        handled := False;
    End;
    If handled Then Exit;
  End;

  { ---- instructions a 3 operandes ---- }
  If opcount = 3 Then
  Begin
    If mnem = 'IMUL' Then Begin EncodeIMUL(3, op1, op2, op3); Exit; End;
    If mnem = 'SHLD' Then
    Begin
      BinEmitByte($0F); BinEmitByte($A4); EmitModRM(op2.reg.idx, op1);
      BinEmitImmExpr(op3.imm, 1); Exit;
    End;
    If mnem = 'SHRD' Then
    Begin
      BinEmitByte($0F); BinEmitByte($AC); EmitModRM(op2.reg.idx, op1);
      BinEmitImmExpr(op3.imm, 1); Exit;
    End;
  End;

  { ---- instructions a 1 operande ---- }
  If opcount = 1 Then
  Begin
    handled := True;
    If      mnem = 'PUSH' Then EncodePUSH(op1)
    Else If mnem = 'POP'  Then EncodePOP(op1)
    Else If mnem = 'INC'  Then EncodeIncDec(False, op1)
    Else If mnem = 'DEC'  Then EncodeIncDec(True, op1)
    Else If mnem = 'NEG'  Then EncodeNegNot(3, op1)
    Else If mnem = 'NOT'  Then EncodeNegNot(2, op1)
    Else If mnem = 'MUL'  Then EncodeMulDivGroup(4, op1)
    Else If mnem = 'IMUL' Then EncodeMulDivGroup(5, op1)
    Else If mnem = 'DIV'  Then EncodeMulDivGroup(6, op1)
    Else If mnem = 'IDIV' Then EncodeMulDivGroup(7, op1)
    Else If mnem = 'JMP'  Then EncodeJMP(op1)
    Else If mnem = 'CALL' Then EncodeCALL(op1)
    Else If mnem = 'BSWAP' Then EncodeBSWAP(op1)
    Else If mnem = 'INT'  Then Begin BinEmitByte($CD); BinEmitImmExpr(op1.imm, 1); End
    Else If mnem = 'RET'  Then Begin BinEmitByte($C2); BinEmitImmExpr(op1.imm, 2); End
    Else If mnem = 'RETN' Then Begin BinEmitByte($C2); BinEmitImmExpr(op1.imm, 2); End
    Else If mnem = 'LOOP'   Then Begin ExtractBranchTarget(op1, jtarget); EncodeShortJump($E2, jtarget); End
    Else If mnem = 'LOOPE'  Then Begin ExtractBranchTarget(op1, jtarget); EncodeShortJump($E1, jtarget); End
    Else If mnem = 'LOOPZ'  Then Begin ExtractBranchTarget(op1, jtarget); EncodeShortJump($E1, jtarget); End
    Else If mnem = 'LOOPNE' Then Begin ExtractBranchTarget(op1, jtarget); EncodeShortJump($E0, jtarget); End
    Else If mnem = 'LOOPNZ' Then Begin ExtractBranchTarget(op1, jtarget); EncodeShortJump($E0, jtarget); End
    Else If mnem = 'JECXZ'  Then Begin ExtractBranchTarget(op1, jtarget); EncodeShortJump($E3, jtarget); End
    Else If mnem = 'JCXZ'   Then Begin ExtractBranchTarget(op1, jtarget); EncodeShortJump($E3, jtarget); End
    Else
    Begin
      If (Length(mnem) >= 2) And (mnem[1] = 'J') Then
      Begin
        suffix := Copy(mnem, 2, Length(mnem)-1);
        cc := CondCodeOf(suffix);
        If cc >= 0 Then Begin ExtractBranchTarget(op1, jtarget); EncodeJcc(cc, jtarget); End
        Else handled := False;
      End
      Else If (Length(mnem) >= 4) And (Copy(mnem,1,3) = 'SET') Then
      Begin
        suffix := Copy(mnem, 4, Length(mnem)-3);
        cc := CondCodeOf(suffix);
        If cc >= 0 Then EncodeSETcc(cc, op1)
        Else handled := False;
      End
      Else
        handled := False;
    End;
    If handled Then Exit;
  End;

  If TryFPUMMXSSE(mnem, opcount, op1, op2, op3) Then Exit;

  AssembleInstruction := False;
End;

{ ============================================================
  TODO 6 - DIRECTIVES D ASSEMBLAGE
  ============================================================
  Limitation documentee (v1) : STRUC/RECORD/UNION (structures de
  donnees) et les groupes de segments personnalises (GROUP) ne
  sont pas implementes - seul le modele .MODEL FLAT avec les 4
  sections fixes .text/.data/.bss/.rdata est supporte, ce qui
  couvre l ecrasante majorite des programmes Win32 en assembleur
  ecrits pour ML.EXE moderne. SEGMENT/ENDS explicites sont
  acceptes par compatibilite et mappes par heuristique de nom.
  ============================================================ }

{ ============================================================
  DataSizeBytes : taille en octets d une unite DS_xxx
  ============================================================ }
Function DataSizeBytes(ds : TDataSize) : Integer;
Begin
  Case ds Of
    DS_BYTE  : DataSizeBytes := 1;
    DS_WORD  : DataSizeBytes := 2;
    DS_DWORD : DataSizeBytes := 4;
    DS_QWORD : DataSizeBytes := 8;
    DS_TBYTE : DataSizeBytes := 10;
    DS_OWORD : DataSizeBytes := 16;
  Else DataSizeBytes := 4;
  End;
End;

{ ============================================================
  TryReadFloatAtCurrentPos : detecte un litteral flottant decimal
  (chiffres '.' chiffres [E[+-]chiffres]) directement dans
  lex_line a partir de lex_pos, SANS passer par le tokenizer
  normal (qui scinderait "3.14" en NOMBRE puis '.' puis NOMBRE).
  Ne doit etre appele que lorsque lex_has_peek=False.
  ============================================================ }
Function TryReadFloatAtCurrentPos(Var f : Double) : Boolean;
Var
  raw     : TString;
  intpart : TString;
  p       : Integer;
Begin
  TryReadFloatAtCurrentPos := False;

  If lex_has_peek Then
  Begin
    { Un token a deja ete tokenize en avance dans lex_peek_tok (par un
      LexPeekKind anterieur, ex: la verification "nom DIRECTIVE" faite par
      ProcessLine avant meme d appeler ParseDataDeclList) ; lex_pos est deja
      positionne juste APRES ce token. Si c etait un NOMBRE et que le
      caractere courant est un '.' suivi d un chiffre, c est en realite un
      litteral flottant dont seule la partie entiere a ete tokenizee. }
    If lex_peek_tok.kind <> TK_NUMBER Then Exit;
    If (lex_pos > Length(lex_line)) Or (lex_line[lex_pos] <> '.') Then Exit;
    If (lex_pos + 1 > Length(lex_line)) Or (Not LexIsDigit(lex_line[lex_pos + 1])) Then Exit;
    intpart := IntToStr_(lex_peek_tok.num_val);
  End
  Else
  Begin
    p := lex_pos;
    While (p <= Length(lex_line)) And LexIsDigit(lex_line[p]) Do Inc(p);
    If p = lex_pos Then Exit;
    If (p > Length(lex_line)) Or (lex_line[p] <> '.') Then Exit;
    intpart := Copy(lex_line, lex_pos, p - lex_pos);
    lex_pos := p; { positionner sur le '.' pour la suite commune ci-dessous }
  End;

  { a partir d ici, lex_pos pointe sur le '.' et au moins un chiffre suit }
  p := lex_pos;
  Inc(p); { sauter le '.' }
  While (p <= Length(lex_line)) And LexIsDigit(lex_line[p]) Do Inc(p);
  If (p <= Length(lex_line)) And ((lex_line[p] = 'E') Or (lex_line[p] = 'e')) And
     (p + 1 <= Length(lex_line)) And
     (LexIsDigit(lex_line[p+1]) Or
      (((lex_line[p+1] = '+') Or (lex_line[p+1] = '-')) And (p + 2 <= Length(lex_line)) And
       LexIsDigit(lex_line[p+2]))) Then
  Begin
    Inc(p);
    If (lex_line[p] = '+') Or (lex_line[p] = '-') Then Inc(p);
    While (p <= Length(lex_line)) And LexIsDigit(lex_line[p]) Do Inc(p);
  End;

  raw := intpart + Copy(lex_line, lex_pos, p - lex_pos);
  lex_pos := p;
  lex_has_peek := False; { le peek eventuel est maintenant consomme/invalide }
  Val(raw, f, p);
  If p <> 0 Then f := 0.0;
  TryReadFloatAtCurrentPos := True;
End;

Procedure EmitFloat32(f : Double);
Var sv : Single; barr : Array[0..3] Of Byte;
Begin
  sv := f;
  Move(sv, barr, 4);
  BinEmitByte(barr[0]); BinEmitByte(barr[1]); BinEmitByte(barr[2]); BinEmitByte(barr[3]);
End;

Procedure EmitFloat64(f : Double);
Var barr : Array[0..7] Of Byte; i : Integer;
Begin
  Move(f, barr, 8);
  For i := 0 To 7 Do BinEmitByte(barr[i]);
End;

{ ============================================================
  EmitOneDataValue : emettre une unite de taille ds pour la
  valeur e (avec fixup si 32 bits et relogeable/externe).
  ============================================================ }
Procedure EmitOneDataValue(ds : TDataSize; Const e : TExpr);
Begin
  Case ds Of
    DS_BYTE  : BinEmitByte(Byte(e.val And $FF));
    DS_WORD  : BinEmitWord(Word(e.val And $FFFF));
    DS_DWORD : If e.is_reloc Or e.is_extern Then BinEmitDisp32Expr(e) Else BinEmitDWord(e.val);
    DS_QWORD : BinEmitQWord(e.val, 0);
    DS_TBYTE : Begin BinEmitQWord(e.val, 0); BinEmitWord(0); End;
    DS_OWORD : Begin BinEmitQWord(e.val, 0); BinEmitQWord(0, 0); End;
  End;
End;

{ ============================================================
  ParseDataDeclList : analyser la liste d elements separes par
  des virgules d une directive DB/DW/DD/DQ/DT/DO, jusqu a fin de
  ligne. Gere : nombres, flottants (DD/DQ), chaines ('...' pour
  DB - un octet par caractere), '?' (non initialise), et la forme
  "compte DUP (liste)" sur un seul niveau (pas de DUP imbrique).
  ============================================================ }
Procedure ParseDataDeclList(ds : TDataSize);
Var
  e        : TExpr;
  f        : Double;
  cnt      : TLong;
  i, j     : Integer;
  s        : TString;
  dup_vals : Array[1..64] Of TExpr;
  dup_flts : Array[1..64] Of Double;
  dup_is_f : Array[1..64] Of Boolean;
  dup_n    : Integer;
Begin
  Repeat
    { chaine litterale : uniquement significative pour DB (un octet/caractere) }
    If LexPeekKind = TK_STRING Then
    Begin
      LexNext;
      s := lex_tok.val;
      If ds = DS_BYTE Then
      Begin
        For i := 1 To Length(s) Do BinEmitByte(Byte(Ord(s[i])));
      End
      Else
      Begin
        For i := 1 To Length(s) Do
        Begin
          ExprMakeNum(e, Ord(s[i]));
          EmitOneDataValue(ds, e);
        End;
      End;
    End
    { valeur non initialisee }
    Else If (LexPeekKind = TK_IDENT) And (LexPeekVal = '?') Then
    Begin
      LexNext;
      BinEmitByte(0); { BinEmitByte gere lui-meme le cas .bss (pas d ecriture physique) }
      For i := 2 To DataSizeBytes(ds) Do BinEmitByte(0);
    End
    { flottant explicite (uniquement pour DD/DQ) }
    Else If ((ds = DS_DWORD) Or (ds = DS_QWORD)) And TryReadFloatAtCurrentPos(f) Then
    Begin
      If ds = DS_QWORD Then EmitFloat64(f) Else EmitFloat32(f);
    End
    { "compte DUP (liste)" ou valeur simple }
    Else
    Begin
      EvalExpr(e);
      If (LexPeekKind = TK_IDENT) And (LexPeekVal = 'DUP') Then
      Begin
        cnt := e.val;
        LexNext; { DUP }
        If (LexPeekKind = TK_PUNCT) And (LexPeekVal = '(') Then LexNext
        Else WarnMsg('( attendue apres DUP');
        dup_n := 0;
        Repeat
          If dup_n < 64 Then Inc(dup_n);
          If LexPeekKind = TK_STRING Then
          Begin
            LexNext;
            s := lex_tok.val;
            For j := 1 To Length(s) Do
            Begin
              If dup_n <= 64 Then
              Begin
                ExprMakeNum(dup_vals[dup_n], Ord(s[j]));
                dup_is_f[dup_n] := False;
              End;
              If j < Length(s) Then
              Begin
                If dup_n < 64 Then Inc(dup_n);
              End;
            End;
          End
          Else If (LexPeekKind = TK_IDENT) And (LexPeekVal = '?') Then
          Begin
            LexNext;
            ExprMakeNum(dup_vals[dup_n], 0);
            dup_is_f[dup_n] := False;
          End
          Else If ((ds = DS_DWORD) Or (ds = DS_QWORD)) And
                  TryReadFloatAtCurrentPos(dup_flts[dup_n]) Then
            dup_is_f[dup_n] := True
          Else
          Begin
            EvalExpr(dup_vals[dup_n]);
            dup_is_f[dup_n] := False;
          End;
          If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ',') Then LexNext
          Else Break;
        Until False;
        If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ')') Then LexNext
        Else WarnMsg(') attendue apres la liste DUP');
        For i := 1 To cnt Do
          For j := 1 To dup_n Do
          Begin
            If dup_is_f[j] Then
            Begin
              If ds = DS_QWORD Then EmitFloat64(dup_flts[j]) Else EmitFloat32(dup_flts[j]);
            End
            Else
              EmitOneDataValue(ds, dup_vals[j]);
          End;
      End
      Else
        EmitOneDataValue(ds, e);
    End;

    If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ',') Then LexNext
    Else Break;
  Until (LexPeekKind = TK_NEWLINE) Or (LexPeekKind = TK_EOF);
End;

{ ============================================================
  SECTIONS / MODELE / .386 etc.
  ============================================================ }
Procedure SetActiveSection(sec : Integer);
Begin
  cur_seg := sec;
  seg_table[sec].defined := True;
End;

Procedure SkipRestOfLine;
Begin
  While (LexPeekKind <> TK_NEWLINE) And (LexPeekKind <> TK_EOF) Do LexNext;
End;

{ ============================================================
  DoAlign : completer la section courante avec des zeros jusqu a
  ce que cur_lc soit un multiple de n.
  ============================================================ }
Procedure DoAlign(n : TLong);
Begin
  If n <= 1 Then Exit;
  While (seg_table[cur_seg].cur_lc Mod n) <> 0 Do BinEmitByte(0);
End;

{ ============================================================
  EQU / = : constantes
  ============================================================ }
Procedure DefineEquDirective(Const name : TSymString);
Var
  sym : PSymbol;
  v   : TLong;
Begin
  If (LexPeekKind = TK_PUNCT) And (LexPeekVal = '<') Then
  Begin
    ParseTextequ(name);
    Exit;
  End;
  v := EvalConstExpr;
  sym := SymFind(name);
  If sym = Nil Then sym := SymEnter(name, SK_EQU, 0, 0, 4);
  SymSetValue(sym, v);
End;

Procedure DefineAssignDirective(Const name : TSymString);
Var
  sym : PSymbol;
  v   : TLong;
Begin
  v := EvalConstExpr;
  sym := SymFind(name);
  If sym = Nil Then sym := SymEnter(name, SK_EQU, 0, 0, 4);
  SymSetValue(sym, v);
End;

{ ============================================================
  PUBLIC / EXTERN / EXTRN
  ============================================================ }
Procedure DoPublic;
Var
  nm  : TSymString;
  sym : PSymbol;
Begin
  Repeat
    If LexPeekKind <> TK_IDENT Then Begin ErrorMsg('Nom de symbole attendu apres PUBLIC'); Exit; End;
    LexNext;
    nm := lex_tok.val;
    sym := SymFind(nm);
    If sym = Nil Then sym := SymEnter(nm, SK_UNDEF, 0, 0, 0);
    SymSetPublic(sym);
    If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ',') Then LexNext Else Break;
  Until False;
End;

Function TypeKeywordSize(Const s : TString) : Integer;
Begin
  If      s = 'BYTE'  Then TypeKeywordSize := 1
  Else If s = 'WORD'  Then TypeKeywordSize := 2
  Else If s = 'DWORD' Then TypeKeywordSize := 4
  Else If s = 'QWORD' Then TypeKeywordSize := 8
  Else If s = 'TBYTE' Then TypeKeywordSize := 10
  Else If s = 'OWORD' Then TypeKeywordSize := 16
  Else If s = 'PROC'  Then TypeKeywordSize := 4
  Else If s = 'NEAR'  Then TypeKeywordSize := 4
  Else If s = 'FAR'   Then TypeKeywordSize := 6
  Else If s = 'ABS'   Then TypeKeywordSize := 4
  Else TypeKeywordSize := 4;
End;

Procedure DoExtern;
Var
  nm  : TSymString;
  ty  : TString;
  sym : PSymbol;
Begin
  Repeat
    If LexPeekKind <> TK_IDENT Then Begin ErrorMsg('Nom de symbole attendu apres EXTERN/EXTRN'); Exit; End;
    LexNext;
    nm := lex_tok.val;
    ty := 'DWORD';
    If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ':') Then
    Begin
      LexNext;
      If LexPeekKind = TK_IDENT Then Begin LexNext; ty := lex_tok.val; End;
      { PROTO eventuel : sauter jusqu a la fin de la ligne / prochaine , }
      While (LexPeekKind = TK_PUNCT) And (LexPeekVal = ':') Do
      Begin
        LexNext;
        If LexPeekKind <> TK_PUNCT Then LexNext;
      End;
    End;
    sym := SymFind(nm);
    If sym = Nil Then sym := SymEnter(nm, SK_EXTERN, 0, 0, TypeKeywordSize(ty))
    Else sym^.size := TypeKeywordSize(ty);
    SymSetExtern(sym);
    If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ',') Then LexNext Else Break;
  Until False;
End;

{ ============================================================
  LABEL name TYPE : etiquette explicite (sans reservation)
  ============================================================ }
Procedure DoLabelDirective(Const name : TSymString);
Var ty : TString; sz : Integer;
Begin
  ty := 'BYTE';
  If LexPeekKind = TK_IDENT Then Begin LexNext; ty := lex_tok.val; End;
  sz := TypeKeywordSize(ty);
  SymDefineLabel(name, cur_seg, seg_table[cur_seg].cur_lc, sz);
End;

{ ============================================================
  SEGMENT / ENDS / GROUP : compatibilite (mappage heuristique
  vers l une des 4 sections fixes du modele FLAT)
  ============================================================ }
Procedure DoSegmentDirective(Const name : TSymString);
Var
  target : Integer;
  s      : TString;
  sym    : PSymbol;
Begin
  target := SEC_DATA;
  s := LexUpperCase(name);
  If (Pos('CODE', s) > 0) Or (Pos('TEXT', s) > 0) Then target := SEC_TEXT
  Else If (Pos('CONST', s) > 0) Or (Pos('RDATA', s) > 0) Then target := SEC_RDATA
  Else If (Pos('BSS', s) > 0) Then target := SEC_BSS;
  { chercher un nom de classe entre guillemets sur la ligne pour affiner }
  While (LexPeekKind <> TK_NEWLINE) And (LexPeekKind <> TK_EOF) Do
  Begin
    If LexPeekKind = TK_STRING Then
    Begin
      LexNext;
      s := LexUpperCase(lex_tok.val);
      If (Pos('CODE', s) > 0) Then target := SEC_TEXT
      Else If (Pos('CONST', s) > 0) Then target := SEC_RDATA
      Else If (Pos('BSS', s) > 0) Then target := SEC_BSS
      Else If Pos('DATA', s) > 0 Then target := SEC_DATA;
    End
    Else
      LexNext;
  End;
  sym := SymFind(name);
  If sym = Nil Then sym := SymEnter(name, SK_SEG, target, 0, 0)
  Else Begin sym^.kind := SK_SEG; sym^.seg_idx := target; End;
  SetActiveSection(target);
End;

{ ============================================================
  PROC / ENDP / LOCAL / INVOKE - procedures haut niveau
  ============================================================ }
Var
  in_proc              : Boolean;
  cur_proc_name         : TSymString;
  cur_proc_argbytes     : TLong;
  cur_proc_is_stdcall   : Boolean;
  cur_proc_local_size   : TLong;
  cur_proc_uses_count   : Integer;
  cur_proc_uses_regs    : Array[1..8] Of Byte;
  cur_proc_prologue_done: Boolean;
  cur_proc_sub_esp_pos  : TLong; { position du disp32 de "SUB ESP,imm32" a corriger }
  cur_proc_has_sub_esp  : Boolean;

Function MakeRegOperand(k : TRegKind; idx : TByte) : TOperand;
Var op : TOperand;
Begin
  ClearOperand(op);
  op.kind := OPK_REG;
  op.reg.kind := k;
  op.reg.idx  := idx;
  MakeRegOperand := op;
End;

{ ============================================================
  EnsurePrologueEmitted : emettre "SUB ESP,local_size" une seule
  fois, juste avant la premiere instruction reelle du corps
  (apres que tous les LOCAL en tete de PROC aient ete traites).
  ============================================================ }
Procedure EnsurePrologueEmitted;
Begin
  If (Not in_proc) Or cur_proc_prologue_done Then Exit;
  cur_proc_prologue_done := True;
  If cur_proc_local_size > 0 Then
  Begin
    BinEmitByte($81); BinEmitByte($EC); { SUB ESP, imm32 }
    BinEmitDWord(cur_proc_local_size);
  End;
End;

Procedure DoBeginProc(Const name : TSymString);
Var
  pname   : TSymString;
  offs    : TLong;
Begin
  in_proc               := True;
  cur_proc_name          := name;
  cur_proc_argbytes      := 0;
  cur_proc_is_stdcall    := True;
  cur_proc_local_size    := 0;
  cur_proc_uses_count    := 0;
  cur_proc_prologue_done := False;
  StackVarClear;

  SymDefineLabel(name, cur_seg, seg_table[cur_seg].cur_lc, 0);
  With SymFind(name)^ Do kind := SK_PROC;

  { prologue standard }
  BinEmitByte($55);             { PUSH EBP }
  BinEmitByte($8B); BinEmitByte($EC); { MOV EBP,ESP }

  { mot-cle optionnel NEAR/FAR }
  If (LexPeekKind = TK_IDENT) And ((LexPeekVal = 'NEAR') Or (LexPeekVal = 'FAR')) Then LexNext;

  { convention d appel optionnelle }
  If (LexPeekKind = TK_IDENT) And (LexPeekVal = 'STDCALL') Then
  Begin LexNext; cur_proc_is_stdcall := True; End
  Else If (LexPeekKind = TK_IDENT) And (LexPeekVal = 'C') Then
  Begin LexNext; cur_proc_is_stdcall := False; End;

  { USES reg1 reg2 ... }
  If (LexPeekKind = TK_IDENT) And (LexPeekVal = 'USES') Then
  Begin
    LexNext;
    While (LexPeekKind = TK_IDENT) And (RegByName(LexPeekVal).kind = RK_32) Do
    Begin
      LexNext;
      If cur_proc_uses_count < 8 Then
      Begin
        Inc(cur_proc_uses_count);
        cur_proc_uses_regs[cur_proc_uses_count] := RegByName(lex_tok.val).idx;
        BinEmitByte(Byte($50 Or cur_proc_uses_regs[cur_proc_uses_count]));
      End;
    End;
  End;

  { liste de parametres haut niveau : name:type, name:type, ... }
  offs := 8;
  If (LexPeekKind = TK_IDENT) Then
  Begin
    { heuristique : IDENT suivi de ':' = debut d une liste de parametres }
    LexEnsurePeek;
    If lex_peek_tok.kind = TK_IDENT Then ; { rien, juste pour forcer le peek }
  End;
  While (LexPeekKind = TK_IDENT) Do
  Begin
    LexNext;
    pname := lex_tok.val;
    If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ':') Then
    Begin
      LexNext; { : }
      If LexPeekKind = TK_IDENT Then LexNext; { type, ignore (PTR compose non gere en detail) }
      { PTR compose eventuel : "PTR DWORD" deja couvert par un seul token du type }
      StackVarAdd(pname, offs);
      offs := offs + 4;
      cur_proc_argbytes := cur_proc_argbytes + 4;
    End
    Else
    Begin
      { pas de ':' : jeton inattendu, on arrete la liste }
      Break;
    End;
    If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ',') Then LexNext Else Break;
  End;
End;

Procedure DoLocalDecl;
Var nm : TSymString;
Begin
  Repeat
    If LexPeekKind <> TK_IDENT Then Begin ErrorMsg('Nom de variable attendu apres LOCAL'); Exit; End;
    LexNext;
    nm := lex_tok.val;
    If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ':') Then
    Begin
      LexNext;
      If LexPeekKind = TK_IDENT Then
      Begin
        LexNext;
        cur_proc_local_size := cur_proc_local_size + TypeKeywordSize(lex_tok.val);
        { alignement 4 par defaut }
        If (cur_proc_local_size Mod 4) <> 0 Then
          cur_proc_local_size := cur_proc_local_size + (4 - (cur_proc_local_size Mod 4));
      End
      Else
        cur_proc_local_size := cur_proc_local_size + 4;
    End
    Else
      cur_proc_local_size := cur_proc_local_size + 4;
    StackVarAdd(nm, -cur_proc_local_size);
    If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ',') Then LexNext Else Break;
  Until False;
End;

Procedure DoEndProc(Const name : TSymString);
Var i : Integer;
Begin
  EnsurePrologueEmitted;
  { restaurer les registres USES en ordre inverse }
  For i := cur_proc_uses_count DownTo 1 Do
    BinEmitByte(Byte($58 Or cur_proc_uses_regs[i]));
  BinEmitByte($8B); BinEmitByte($E5); { MOV ESP,EBP }
  BinEmitByte($5D);                   { POP EBP }
  If cur_proc_is_stdcall And (cur_proc_argbytes > 0) Then
  Begin
    BinEmitByte($C2);
    BinEmitWord(Word(cur_proc_argbytes));
  End
  Else
    BinEmitByte($C3);
  in_proc := False;
  StackVarClear;
End;

{ ============================================================
  INVOKE procname, arg1, arg2, ... (ADDR name pour une adresse)
  ============================================================ }
Procedure DoInvoke;
Const MAX_INVOKE_ARGS = 16;
Var
  callee     : TSymString;
  n          : Integer;
  args       : Array[1..MAX_INVOKE_ARGS] Of TOperand;
  is_addr    : Array[1..MAX_INVOKE_ARGS] Of Boolean;
  i          : Integer;
  pushimm    : TOperand;
  calltarget : TOperand;
  csym       : PSymbol;
Begin
  If LexPeekKind <> TK_IDENT Then Begin ErrorMsg('Nom de procedure attendu apres INVOKE'); Exit; End;
  LexNext;
  callee := lex_tok.val;
  n := 0;
  While (LexPeekKind = TK_PUNCT) And (LexPeekVal = ',') Do
  Begin
    LexNext;
    If n >= MAX_INVOKE_ARGS Then Begin ErrorMsg('Trop d arguments INVOKE'); Break; End;
    Inc(n);
    If (LexPeekKind = TK_IDENT) And (LexPeekVal = 'ADDR') Then
    Begin
      LexNext;
      is_addr[n] := True;
    End
    Else
      is_addr[n] := False;
    ParseOperand(args[n]);
  End;

  For i := n DownTo 1 Do
  Begin
    If is_addr[i] Then
    Begin
      If (args[i].kind = OPK_MEM) And (Not args[i].has_base) And (Not args[i].has_index) Then
      Begin
        ClearOperand(pushimm);
        pushimm.kind := OPK_IMM;
        If args[i].has_disp Then pushimm.imm := args[i].disp Else ExprMakeNum(pushimm.imm, 0);
        EncodePUSH(pushimm);
      End
      Else
      Begin
        BinEmitByte($8D); EmitModRM(0, args[i]); { LEA EAX, [args[i]] }
        EncodePUSH(MakeRegOperand(RK_32, 0));
      End;
    End
    Else
      EncodePUSH(args[i]);
  End;

  csym := SymFind(callee);
  If csym = Nil Then csym := SymLookupOrEnter(callee);
  ClearOperand(calltarget);
  calltarget.kind := OPK_IMM;
  Case csym^.kind Of
    SK_LABEL, SK_PUBLIC, SK_PROC : ExprMakeReloc(calltarget.imm, csym^.offset, csym^.seg_idx, csym^.name);
    SK_EXTERN : ExprMakeExtern(calltarget.imm, csym^.name, Integer(csym^.size));
  Else
    Begin
      If pass_num = 1 Then ExprMakeUndef(calltarget.imm)
      Else ExprMakeReloc(calltarget.imm, csym^.offset, csym^.seg_idx, csym^.name);
    End;
  End;
  EncodeCALL(calltarget);
End;

{ ============================================================
  .MODEL / .STACK / .STARTUP / .EXIT / directives sans effet
  (acceptees et ignorees par compatibilite avec du code source
  ecrit pour un ML.EXE reel)
  ============================================================ }
Var
  pe_stack_reserve : TLong;
  entry_point_name : TSymString; { fixe par END si un label de depart est donne }

Procedure DoModelDirective;
Begin
  If (LexPeekKind = TK_IDENT) And (LexPeekVal = 'FLAT') Then
  Begin
    LexNext;
    flat_model := True;
  End;
  SkipRestOfLine;
End;

Procedure DoStackDirective;
Begin
  If (LexPeekKind <> TK_NEWLINE) And (LexPeekKind <> TK_EOF) Then
    pe_stack_reserve := EvalConstExpr
  Else
    pe_stack_reserve := $100000;
End;

Procedure DoExitDirective;
Var
  e         : TExpr;
  callarg   : TOperand;
  calltgt   : TOperand;
  csym      : PSymbol;
Begin
  { .EXIT [exitcode] : equivalent a INVOKE ExitProcess, exitcode }
  ClearOperand(callarg);
  If (LexPeekKind <> TK_NEWLINE) And (LexPeekKind <> TK_EOF) Then
  Begin
    EvalExpr(e);
    callarg.kind := OPK_IMM;
    callarg.imm  := e;
  End
  Else
  Begin
    callarg.kind := OPK_IMM;
    ExprMakeNum(callarg.imm, 0);
  End;
  EncodePUSH(callarg);
  csym := SymFind('EXITPROCESS');
  If csym = Nil Then csym := SymEnter('EXITPROCESS', SK_EXTERN, 0, 0, 4);
  SymSetExtern(csym);
  ClearOperand(calltgt);
  calltgt.kind := OPK_IMM;
  ExprMakeExtern(calltgt.imm, csym^.name, 4);
  EncodeCALL(calltgt);
End;

{ ============================================================
  COMMENT delimiteur ... delimiteur : ignorer toutes les lignes
  jusqu a ce que le delimiteur reapparaisse.
  ============================================================ }
Procedure DoCommentDirective;
Var delim : Char;
Begin
  SkipRestOfLine; { le delimiteur est le premier caractere non-espace du reste
                     de la ligne source brute ; comme notre lexer l a deja
                     tokenize, on se contente ici d ignorer les lignes
                     suivantes jusqu a une ligne qui commence par le meme
                     caractere que le premier token restant (limitation
                     documentee : forme simplifiee du vrai COMMENT MASM) }
  delim := '*';
  While SrcReadLine Do
  Begin
    If (Length(cur_line) > 0) And (cur_line[1] = delim) Then Break;
  End;
  lex_at_eol := True;
End;

{ ============================================================
  END directive : fin du fichier source, avec eventuellement un
  label de point d entree.
  ============================================================ }
Procedure DoEndDirective;
Begin
  If (LexPeekKind = TK_IDENT) Then
  Begin
    LexNext;
    entry_point_name := lex_tok.val;
  End;
End;

{ ============================================================
  TODO 7 - PROCESSEUR DE MACROS (MACRO/ENDM)
  ============================================================
  Limitation documentee (v1) : substitution textuelle simple des
  parametres formels (pas de gestion de LOCAL a l interieur d une
  macro, pas d operateur de concatenation &, pas de macros a
  argument variable via REPT/IRP/IRPC imbrique dans une macro).
  Couvre neanmoins l usage courant (macros utilitaires simples).
  ============================================================ }
Type
  TMacroDef = Record
    name        : TSymString;
    params      : Array[1..16] Of TSymString;
    param_count : Integer;
    body        : Array[1..MAX_MACRO_BODY_LINES] Of TString;
    body_count  : Integer;
  End;
Var
  macro_defs      : Array[1..MAX_MACRO] Of TMacroDef;
  macro_def_count : Integer;

Function TrimStr(Const s : TString) : TString;
Var r : TString;
Begin
  r := s;
  While (Length(r) > 0) And (r[1] = ' ') Do Delete(r, 1, 1);
  While (Length(r) > 0) And (r[Length(r)] = ' ') Do Delete(r, Length(r), 1);
  TrimStr := r;
End;

Function MacroFind(Const name : TSymString) : Integer;
Var i : Integer;
Begin
  MacroFind := 0;
  For i := 1 To macro_def_count Do
    If macro_defs[i].name = name Then Begin MacroFind := i; Exit; End;
End;

{ ============================================================
  ParseMacroDef : "name MACRO param1, param2, ..." deja lu
  jusqu au nom ; lit la liste de parametres formels puis le
  corps texte brut jusqu a ENDM.
  ============================================================ }
Procedure ParseMacroDef(Const name : TSymString);
Var
  m        : Integer;
  pname    : TSymString;
  raw      : TString;
  trimmed  : TString;
  firstword: TString;
  i        : Integer;
Begin
  If macro_def_count >= MAX_MACRO Then Begin ErrorMsg('Trop de macros definies'); Exit; End;
  Inc(macro_def_count);
  m := macro_def_count;
  macro_defs[m].name        := name;
  macro_defs[m].param_count := 0;
  macro_defs[m].body_count  := 0;

  While LexPeekKind = TK_IDENT Do
  Begin
    LexNext;
    pname := lex_tok.val;
    If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ':') Then
    Begin
      LexNext;
      If LexPeekKind = TK_IDENT Then LexNext; { REQ ou valeur par defaut, ignores }
    End;
    If macro_defs[m].param_count < 16 Then
    Begin
      Inc(macro_defs[m].param_count);
      macro_defs[m].params[macro_defs[m].param_count] := pname;
    End;
    If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ',') Then LexNext Else Break;
  End;
  lex_at_eol := True; { forcer la fin de ligne courante, tokens restants ignores }
  lex_has_peek := False;

  Repeat
    If Not SrcReadLine Then
    Begin
      ErrorMsg('ENDM manquant pour la macro ' + name);
      Exit;
    End;
    raw     := cur_line;
    trimmed := TrimStr(raw);
    i := 1; firstword := '';
    While (i <= Length(trimmed)) And LexIsAlNum(trimmed[i]) Do
    Begin
      firstword := firstword + trimmed[i];
      Inc(i);
    End;
    firstword := LexUpperCase(firstword);
    If firstword = 'ENDM' Then Break;
    If macro_defs[m].body_count < MAX_MACRO_BODY_LINES Then
    Begin
      Inc(macro_defs[m].body_count);
      macro_defs[m].body[macro_defs[m].body_count] := raw;
    End;
  Until False;
End;

{ ============================================================
  ExpandMacro : invocation d une macro deja definie. Les
  arguments reels sont le reste de la ligne courante (lex_line a
  partir de lex_pos), separes par des virgules de haut niveau.
  ============================================================ }
Procedure ExpandMacro(m : Integer);
Var
  args      : Array[1..16] Of TString;
  argc      : Integer;
  body_line : TString;
  outline   : TString;
  j, k      : Integer;
  c         : Char;
  id        : TSymString;
  found     : Integer;
  i         : Integer;
Begin
  { Capturer les arguments reels via le tokenizer normal (LexPeekKind/LexNext),
    PAS par decoupage brut de lex_line/lex_pos : au moment ou ExpandMacro est
    appele, ProcessLine a deja fait plusieurs LexPeekKind (pour detecter un
    label ou une directive "nom DIRECTIVE"), ce qui a deja fait avancer
    lex_pos via le mecanisme de lookahead (LexEnsurePeek) - une lecture brute
    de lex_line/lex_pos a cet endroit serait desynchronisee et incorrecte. }
  argc := 0;
  If (LexPeekKind <> TK_NEWLINE) And (LexPeekKind <> TK_EOF) Then
  Begin
    argc := 1;
    args[1] := '';
    Repeat
      If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ',') Then
      Begin
        LexNext; { consommer la , }
        If argc < 16 Then Inc(argc);
        args[argc] := '';
      End
      Else
      Begin
        LexNext; { consommer le prochain token de l argument courant }
        If args[argc] <> '' Then args[argc] := args[argc] + ' ';
        If lex_tok.kind = TK_STRING Then
          args[argc] := args[argc] + '''' + lex_tok.val + ''''
        Else
          args[argc] := args[argc] + lex_tok.val;
      End;
    Until (LexPeekKind = TK_NEWLINE) Or (LexPeekKind = TK_EOF);
  End;

  BeginMacroExpansion;
  For i := 1 To macro_defs[m].body_count Do
  Begin
    body_line := macro_defs[m].body[i];
    outline := '';
    j := 1;
    While j <= Length(body_line) Do
    Begin
      c := body_line[j];
      If LexIsAlpha(c) Or (c = '_') Or (c = '@') Or (c = '$') Then
      Begin
        id := '';
        While (j <= Length(body_line)) And LexIsAlNum(body_line[j]) Do
        Begin
          id := id + body_line[j];
          Inc(j);
        End;
        found := 0;
        For k := 1 To macro_defs[m].param_count Do
          If LexUpperCase(id) = macro_defs[m].params[k] Then Begin found := k; Break; End;
        If (found > 0) And (found <= argc) Then outline := outline + args[found]
        Else If found > 0 Then { parametre sans argument fourni : substitue par vide }
        Else outline := outline + id;
      End
      Else
      Begin
        outline := outline + c;
        Inc(j);
      End;
    End;
    AddMacroExpLine(outline);
  End;
End;

{ ============================================================
  TODO 8 - ASSEMBLAGE CONDITIONNEL (IF/IFDEF/ELSE/ELSEIF/ENDIF)
  ============================================================ }
Const
  IFK_IF=1; IFK_IFE=2; IFK_IFDEF=3; IFK_IFNDEF=4; IFK_IF1=5; IFK_IF2=6;
  IFK_IFB=7; IFK_IFNB=8; IFK_IFIDN=9; IFK_IFIDNI=10; IFK_IFDIF=11; IFK_IFDIFI=12;

Type
  TIfState = Record
    branch_active : Boolean; { True si ce niveau doit actuellement etre assemble }
    taken         : Boolean; { True si une branche (IF vrai ou ELSEIF vrai) a deja ete choisie }
  End;
Var
  if_stack : Array[1..MAX_IF_DEPTH] Of TIfState;
  if_top   : Integer;

Procedure CondInit;
Begin
  if_top := 0;
End;

Function CurrentlyActive : Boolean;
Begin
  CurrentlyActive := (if_top = 0) Or if_stack[if_top].branch_active;
End;

{ ============================================================
  ReadAngleText : lire <texte> (deja utilise par TEXTEQU) - copie
  locale pour l assemblage conditionnel (IFB/IFIDN etc.)
  ============================================================ }
Function ReadAngleText : TString;
Var s : TString;
Begin
  s := '';
  If (LexPeekKind = TK_PUNCT) And (LexPeekVal = '<') Then
  Begin
    LexNext;
    While (lex_pos <= Length(lex_line)) And (lex_line[lex_pos] <> '>') Do
    Begin
      s := s + lex_line[lex_pos];
      Inc(lex_pos);
    End;
    If lex_pos <= Length(lex_line) Then Inc(lex_pos);
  End
  Else If LexPeekKind = TK_STRING Then
  Begin
    LexNext;
    s := lex_tok.val;
  End
  Else If LexPeekKind = TK_IDENT Then
  Begin
    LexNext;
    s := lex_tok.val;
  End;
  ReadAngleText := s;
End;

Function StrEqCI(Const a, b : TString) : Boolean;
Begin
  StrEqCI := (LexUpperCase(a) = LexUpperCase(b));
End;

{ ============================================================
  EvaluateIfCondition : evalue la condition selon kind. Ne doit
  etre appele que lorsque le niveau parent est actif.
  ============================================================ }
Function EvaluateIfCondition(kind : Integer) : Boolean;
Var
  nm      : TSymString;
  sym     : PSymbol;
  a, b    : TString;
  v       : TLong;
Begin
  EvaluateIfCondition := False;
  Case kind Of
    IFK_IF  : Begin v := EvalConstExpr; EvaluateIfCondition := (v <> 0); End;
    IFK_IFE : Begin v := EvalConstExpr; EvaluateIfCondition := (v = 0); End;
    IFK_IF1 : EvaluateIfCondition := (pass_num = 1);
    IFK_IF2 : EvaluateIfCondition := (pass_num = 2);
    IFK_IFDEF, IFK_IFNDEF :
      Begin
        If LexPeekKind = TK_IDENT Then Begin LexNext; nm := lex_tok.val; End
        Else nm := '';
        sym := SymFind(nm);
        v := 0;
        If (sym <> Nil) And (sym^.kind <> SK_UNDEF) Then v := 1;
        If kind = IFK_IFDEF Then EvaluateIfCondition := (v <> 0)
        Else                     EvaluateIfCondition := (v = 0);
      End;
    IFK_IFB, IFK_IFNB :
      Begin
        a := ReadAngleText;
        If kind = IFK_IFB Then EvaluateIfCondition := (TrimStr(a) = '')
        Else                   EvaluateIfCondition := (TrimStr(a) <> '');
      End;
    IFK_IFIDN, IFK_IFIDNI, IFK_IFDIF, IFK_IFDIFI :
      Begin
        a := ReadAngleText;
        If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ',') Then LexNext;
        b := ReadAngleText;
        If kind = IFK_IFIDN  Then EvaluateIfCondition := (a = b)
        Else If kind = IFK_IFIDNI Then EvaluateIfCondition := StrEqCI(a, b)
        Else If kind = IFK_IFDIF  Then EvaluateIfCondition := (a <> b)
        Else EvaluateIfCondition := Not StrEqCI(a, b);
      End;
  End;
End;

Procedure DoIfDirective(kind : Integer);
Var parent_active : Boolean;
Begin
  parent_active := CurrentlyActive;
  If if_top >= MAX_IF_DEPTH Then Begin ErrorMsg('IF imbrique trop profond'); Exit; End;
  Inc(if_top);
  If Not parent_active Then
  Begin
    if_stack[if_top].branch_active := False;
    if_stack[if_top].taken         := True;
    SkipRestOfLine;
    Exit;
  End;
  if_stack[if_top].branch_active := EvaluateIfCondition(kind);
  if_stack[if_top].taken         := if_stack[if_top].branch_active;
End;

Procedure DoElseIfDirective(kind : Integer);
Var parent_active : Boolean;
Begin
  If if_top = 0 Then Begin ErrorMsg('ELSEIF sans IF'); Exit; End;
  parent_active := (if_top = 1) Or if_stack[if_top-1].branch_active;
  With if_stack[if_top] Do
  Begin
    If taken Or (Not parent_active) Then
    Begin
      branch_active := False;
      SkipRestOfLine;
    End
    Else
    Begin
      branch_active := EvaluateIfCondition(kind);
      If branch_active Then taken := True;
    End;
  End;
End;

Procedure DoElseDirective;
Begin
  If if_top = 0 Then Begin ErrorMsg('ELSE sans IF'); Exit; End;
  With if_stack[if_top] Do
  Begin
    If taken Then branch_active := False
    Else Begin branch_active := True; taken := True; End;
  End;
End;

Procedure DoEndifDirective;
Begin
  If if_top = 0 Then Begin ErrorMsg('ENDIF sans IF'); Exit; End;
  Dec(if_top);
End;

{ ============================================================
  IfKeywordIndex : mappe un nom de directive IF* vers IFK_*,
  0 si ce n est pas un mot-cle conditionnel.
  ============================================================ }
Function IfKeywordIndex(Const s : TString) : Integer;
Begin
  If      s = 'IF'     Then IfKeywordIndex := IFK_IF
  Else If s = 'IFE'    Then IfKeywordIndex := IFK_IFE
  Else If s = 'IFDEF'  Then IfKeywordIndex := IFK_IFDEF
  Else If s = 'IFNDEF' Then IfKeywordIndex := IFK_IFNDEF
  Else If s = 'IF1'    Then IfKeywordIndex := IFK_IF1
  Else If s = 'IF2'    Then IfKeywordIndex := IFK_IF2
  Else If s = 'IFB'    Then IfKeywordIndex := IFK_IFB
  Else If s = 'IFNB'   Then IfKeywordIndex := IFK_IFNB
  Else If s = 'IFIDN'  Then IfKeywordIndex := IFK_IFIDN
  Else If s = 'IFIDNI' Then IfKeywordIndex := IFK_IFIDNI
  Else If s = 'IFDIF'  Then IfKeywordIndex := IFK_IFDIF
  Else If s = 'IFDIFI' Then IfKeywordIndex := IFK_IFDIFI
  Else IfKeywordIndex := 0;
End;

{ ============================================================
  DoIncludeDirective : INCLUDE nomfichier - capture le reste brut
  de la ligne (pas de tokenisation, car un chemin contient des
  caracteres non valides pour un identificateur).
  ============================================================ }
Procedure DoIncludeDirective;
Var fn : TString;
Begin
  fn := TrimStr(Copy(lex_line, lex_pos, Length(lex_line) - lex_pos + 1));
  lex_pos := Length(lex_line) + 1;
  lex_has_peek := False;
  If (Length(fn) >= 2) And (fn[1] = '"') And (fn[Length(fn)] = '"') Then
    fn := Copy(fn, 2, Length(fn) - 2);
  If (Length(fn) >= 2) And (fn[1] = '''') And (fn[Length(fn)] = '''') Then
    fn := Copy(fn, 2, Length(fn) - 2);
  SrcPush(fn);
  lex_at_eol := True;
End;

{ ============================================================
  TODO 9 - DISPATCHEUR PRINCIPAL PAR LIGNE
  ============================================================
  ProcessLine consomme une ligne logique complete (jusqu au
  TK_NEWLINE/TK_EOF suivant, sans le consommer). Gere dans l
  ordre : lignes vides, assemblage conditionnel (toujours actif,
  meme si on saute un bloc), puis si actif : ENDM orphelin,
  label "nom:", forme "nom DIRECTIVE" (EQU/MACRO/PROC/DB../
  LABEL/SEGMENT/TEXTEQU), directives globales, appel de macro,
  et enfin instruction machine.
  ============================================================ }
Procedure ProcessLine;
Var
  nm    : TSymString;
  tok   : TString;
  ifk   : Integer;
  midx  : Integer;
Begin
  If LexPeekKind = TK_EOF Then Exit;
  If LexPeekKind = TK_NEWLINE Then Exit; { ligne vide, rien a faire }

  { --- assemblage conditionnel : actif meme si on saute un bloc --- }
  If LexPeekKind = TK_IDENT Then
  Begin
    tok := LexPeekVal;
    If tok = 'ENDIF' Then Begin LexNext; DoEndifDirective; SkipRestOfLine; Exit; End;
    If tok = 'ELSE'  Then Begin LexNext; DoElseDirective; SkipRestOfLine; Exit; End;
    If (Length(tok) >= 6) And (Copy(tok, 1, 6) = 'ELSEIF') Then
    Begin LexNext; DoElseIfDirective(IFK_IF); SkipRestOfLine; Exit; End;
    ifk := IfKeywordIndex(tok);
    If ifk > 0 Then Begin LexNext; DoIfDirective(ifk); SkipRestOfLine; Exit; End;
  End;

  If Not CurrentlyActive Then Begin SkipRestOfLine; Exit; End;

  { --- premier token doit etre un identificateur --- }
  If LexPeekKind <> TK_IDENT Then
  Begin
    ErrorMsg('Token inattendu en debut de ligne : ' + LexPeekVal);
    SkipRestOfLine;
    Exit;
  End;

  LexNext;
  nm := lex_tok.val;

  If nm = 'ENDM' Then Begin WarnMsg('ENDM sans MACRO correspondante'); SkipRestOfLine; Exit; End;

  { --- label "nom:" --- }
  If (LexPeekKind = TK_PUNCT) And (LexPeekVal = ':') Then
  Begin
    LexNext;
    EnsurePrologueEmitted;
    SymDefineLabel(nm, cur_seg, seg_table[cur_seg].cur_lc, 0);
    If (LexPeekKind = TK_NEWLINE) Or (LexPeekKind = TK_EOF) Then Exit;
    ProcessLine; { instruction/directive eventuelle sur la meme ligne }
    Exit;
  End;

  { --- forme "nom DIRECTIVE" (le nom lu est un symbole, pas une instruction) --- }
  If LexPeekKind = TK_IDENT Then
  Begin
    tok := LexPeekVal;
    If tok = 'MACRO' Then Begin LexNext; ParseMacroDef(nm); Exit; End;
    If tok = 'EQU' Then Begin LexNext; DefineEquDirective(nm); Exit; End;
    If tok = 'TEXTEQU' Then Begin LexNext; ParseTextequ(nm); Exit; End;
    If tok = 'PROC' Then Begin LexNext; DoBeginProc(nm); Exit; End;
    If tok = 'ENDP' Then Begin LexNext; DoEndProc(nm); Exit; End;
    If tok = 'SEGMENT' Then Begin LexNext; DoSegmentDirective(nm); Exit; End;
    If tok = 'ENDS' Then Begin LexNext; SkipRestOfLine; Exit; End;
    If tok = 'LABEL' Then Begin LexNext; EnsurePrologueEmitted; DoLabelDirective(nm); Exit; End;
    If tok = 'DB' Then
    Begin LexNext; EnsurePrologueEmitted; SymDefineLabel(nm, cur_seg, seg_table[cur_seg].cur_lc, 0);
          ParseDataDeclList(DS_BYTE); Exit; End;
    If tok = 'DW' Then
    Begin LexNext; EnsurePrologueEmitted; SymDefineLabel(nm, cur_seg, seg_table[cur_seg].cur_lc, 0);
          ParseDataDeclList(DS_WORD); Exit; End;
    If tok = 'DD' Then
    Begin LexNext; EnsurePrologueEmitted; SymDefineLabel(nm, cur_seg, seg_table[cur_seg].cur_lc, 0);
          ParseDataDeclList(DS_DWORD); Exit; End;
    If tok = 'DQ' Then
    Begin LexNext; EnsurePrologueEmitted; SymDefineLabel(nm, cur_seg, seg_table[cur_seg].cur_lc, 0);
          ParseDataDeclList(DS_QWORD); Exit; End;
    If tok = 'DT' Then
    Begin LexNext; EnsurePrologueEmitted; SymDefineLabel(nm, cur_seg, seg_table[cur_seg].cur_lc, 0);
          ParseDataDeclList(DS_TBYTE); Exit; End;
  End;
  If (LexPeekKind = TK_PUNCT) And (LexPeekVal = '=') Then
  Begin LexNext; DefineAssignDirective(nm); Exit; End;

  { --- directives globales (pas de symbole en tete de ligne) --- }
  If nm = 'PUBLIC' Then Begin DoPublic; Exit; End;
  If (nm = 'EXTERN') Or (nm = 'EXTRN') Then Begin DoExtern; Exit; End;
  If nm = 'ALIGN' Then Begin EnsurePrologueEmitted; DoAlign(EvalConstExpr); Exit; End;
  If nm = 'EVEN'  Then Begin EnsurePrologueEmitted; DoAlign(2); Exit; End;
  If nm = 'INVOKE' Then Begin EnsurePrologueEmitted; DoInvoke; Exit; End;
  If nm = 'LOCAL' Then Begin DoLocalDecl; Exit; End;
  If nm = '.MODEL' Then Begin DoModelDirective; Exit; End;
  If nm = '.CODE'  Then Begin SetActiveSection(SEC_TEXT); SkipRestOfLine; Exit; End;
  If nm = '.DATA'  Then Begin SetActiveSection(SEC_DATA); SkipRestOfLine; Exit; End;
  If nm = '.DATA?' Then Begin SetActiveSection(SEC_BSS); SkipRestOfLine; Exit; End;
  If nm = '.CONST' Then Begin SetActiveSection(SEC_RDATA); SkipRestOfLine; Exit; End;
  If nm = '.STACK' Then Begin DoStackDirective; Exit; End;
  If (nm = '.386') Or (nm = '.386P') Or (nm = '.486') Or (nm = '.486P') Or
     (nm = '.586') Or (nm = '.586P') Or (nm = '.686') Or (nm = '.686P') Then
  Begin use32_mode := True; SkipRestOfLine; Exit; End;
  If (nm = '.MMX') Or (nm = '.XMM') Or (nm = '.K3D') Then Begin SkipRestOfLine; Exit; End;
  If nm = '.STARTUP' Then Begin SkipRestOfLine; Exit; End;
  If nm = '.EXIT' Then Begin EnsurePrologueEmitted; DoExitDirective; Exit; End;
  If (nm = '.LIST') Or (nm = '.NOLIST') Or (nm = '.XLIST') Or (nm = '.LISTALL') Or
     (nm = '.RADIX') Or (nm = 'OPTION') Or (nm = 'ASSUME') Or (nm = 'PAGE') Or
     (nm = 'TITLE') Or (nm = 'SUBTTL') Or (nm = 'NAME') Or (nm = 'INCLUDELIB') Or
     (nm = '.ERR') Or (nm = '.ERRNZ') Or (nm = '.ERRE') Then
  Begin SkipRestOfLine; Exit; End;
  If nm = 'COMMENT' Then Begin DoCommentDirective; Exit; End;
  If nm = 'INCLUDE' Then Begin DoIncludeDirective; Exit; End;
  If nm = 'GROUP' Then Begin SkipRestOfLine; Exit; End;
  If nm = 'END' Then Begin DoEndDirective; Exit; End;

  { --- appel de macro utilisateur --- }
  midx := MacroFind(nm);
  If midx > 0 Then Begin ExpandMacro(midx); Exit; End;

  { --- instruction machine --- }
  EnsurePrologueEmitted;
  If Not AssembleInstruction(nm) Then
    ErrorMsg('Mnemonique ou directive inconnue : ' + nm);
End;

{ ============================================================
  TODO 10 - WRITER COFF .OBJ (mode /c, assemblage seul)
  ============================================================
  Produit un fichier .OBJ COFF 32 bits (IMAGE_FILE_MACHINE_I386)
  reellement exploitable par un editeur de liens externe standard
  (symboles PUBLIC en storage class EXTERNAL, EXTERN en section 0
  non definie, relocations DIR32/REL32 correctement adressees par
  symbole avec un addend purge de l offset deja integre a
  l encodage - voir commentaire de BinAddFixupExpr).
  ============================================================ }
Const
  COFF_MACHINE_I386 = $014C;
  COFF_SCN_CNT_CODE  = $00000020;
  COFF_SCN_CNT_IDATA = $00000040;
  COFF_SCN_CNT_UDATA = $00000080;
  COFF_SCN_MEM_EXEC  = $20000000;
  COFF_SCN_MEM_READ  = $40000000;
  COFF_SCN_MEM_WRITE = $80000000;
  COFF_REL_DIR32     = $0006;
  COFF_REL_REL32     = $0014;
  COFF_SYMCLASS_EXTERNAL = 2;
  COFF_SYMCLASS_STATIC   = 3;
  MAX_COFF_SYM = MAX_SYM;

Type
  TCoffSym = Record
    name       : TSymString;
    value      : TLong;
    section    : Integer; { 0 = non defini/externe ; sinon 1..NUM_FIXED_SEC }
    is_extern  : Boolean; { storage class EXTERNAL si True, sinon STATIC }
    is_section_sym : Boolean; { symbole synthetique de section (pour $ anonyme) }
  End;
Var
  coff_syms      : Array[1..MAX_COFF_SYM] Of TCoffSym;
  coff_sym_count : Integer;
  coff_secsym_idx: Array[1..NUM_FIXED_SEC] Of Integer; { index 1-based dans coff_syms }

Function CoffFindSym(Const nm : TSymString) : Integer;
Var i : Integer;
Begin
  CoffFindSym := 0;
  For i := 1 To coff_sym_count Do
    If coff_syms[i].name = nm Then Begin CoffFindSym := i; Exit; End;
End;

Procedure CoffAddSym(Const nm : TSymString; value : TLong; section : Integer; is_ext : Boolean);
Begin
  If coff_sym_count >= MAX_COFF_SYM Then Exit;
  Inc(coff_sym_count);
  coff_syms[coff_sym_count].name      := nm;
  coff_syms[coff_sym_count].value     := value;
  coff_syms[coff_sym_count].section   := section;
  coff_syms[coff_sym_count].is_extern := is_ext;
  coff_syms[coff_sym_count].is_section_sym := False;
End;

{ ============================================================
  CoffBuildSymbolTable : construire la table de symboles COFF a
  partir de la table de symboles interne (hash_table) + des
  symboles synthetiques de section (pour les fixups $ anonymes).
  ============================================================ }
Procedure CoffBuildSymbolTable;
Var
  i   : Integer;
  p   : PSymbol;
  snm : TSymString;
Begin
  coff_sym_count := 0;
  For i := 1 To NUM_FIXED_SEC Do
  Begin
    Case i Of
      SEC_TEXT  : snm := '.text';
      SEC_DATA  : snm := '.data';
      SEC_BSS   : snm := '.bss';
      SEC_RDATA : snm := '.rdata';
    End;
    CoffAddSym(snm, 0, i, False);
    coff_syms[coff_sym_count].is_section_sym := True;
    coff_secsym_idx[i] := coff_sym_count;
  End;
  For i := 0 To HASH_SIZE - 1 Do
  Begin
    p := hash_table[i];
    While p <> Nil Do
    Begin
      Case p^.kind Of
        SK_LABEL, SK_PROC :
          CoffAddSym(p^.name, p^.offset, p^.seg_idx, (p^.flags And 1) <> 0);
        SK_PUBLIC :
          CoffAddSym(p^.name, p^.offset, p^.seg_idx, True);
        SK_EXTERN :
          CoffAddSym(p^.name, 0, 0, True);
      End;
      p := p^.next;
    End;
  End;
End;

{ ---- petits helpers d ecriture bas niveau (fichier non type) ---- }
Procedure CoffWrByte(Var f : File; b : Byte);
Begin
  BlockWrite(f, b, 1);
End;

Procedure CoffWrWord(Var f : File; w : Word);
Begin
  BlockWrite(f, w, 2);
End;

Procedure CoffWrDWord(Var f : File; d : LongWord);
Begin
  BlockWrite(f, d, 4);
End;

Procedure CoffWrName8(Var f : File; Const nm : TString);
Var i : Integer; b : Byte;
Begin
  For i := 1 To 8 Do
  Begin
    If i <= Length(nm) Then b := Byte(Ord(nm[i])) Else b := 0;
    CoffWrByte(f, b);
  End;
End;

{ ============================================================
  WriteCOFF : ecrire le fichier .OBJ complet (en-tete, sections,
  donnees brutes, relocations, table de symboles, table de
  chaines pour les noms > 8 caracteres).
  ============================================================ }
Procedure WriteCOFF(Const out_name : TString);
Var
  f             : File;
  i, j          : Integer;
  num_sections  : Integer;
  sec_size      : Array[1..NUM_FIXED_SEC] Of TLong;
  sec_reloc_cnt : Array[1..NUM_FIXED_SEC] Of Integer;
  sec_class     : Array[1..NUM_FIXED_SEC] Of LongWord;
  hdr_size      : LongInt;
  reloc_offset  : Array[1..NUM_FIXED_SEC] Of LongInt;
  cur_off       : LongInt;
  sym_table_off : LongInt;
  str_tab       : TString; { concatenation brute des noms > 8 caracteres (simplifie) }
  str_tab_len   : LongInt;
  patched_addend: TLong;
  fx            : TBinFixup;
  ownsym        : PSymbol;
  reloc_symidx  : Integer;
Begin
  CoffBuildSymbolTable;

  num_sections := NUM_FIXED_SEC;
  sec_size[SEC_TEXT]  := seg_table[SEC_TEXT].cur_lc;
  sec_size[SEC_DATA]  := seg_table[SEC_DATA].cur_lc;
  sec_size[SEC_BSS]   := seg_table[SEC_BSS].cur_lc;
  sec_size[SEC_RDATA] := seg_table[SEC_RDATA].cur_lc;
  sec_class[SEC_TEXT]  := COFF_SCN_CNT_CODE  Or COFF_SCN_MEM_EXEC Or COFF_SCN_MEM_READ;
  sec_class[SEC_DATA]  := COFF_SCN_CNT_IDATA Or COFF_SCN_MEM_READ Or COFF_SCN_MEM_WRITE;
  sec_class[SEC_BSS]   := COFF_SCN_CNT_UDATA Or COFF_SCN_MEM_READ Or COFF_SCN_MEM_WRITE;
  sec_class[SEC_RDATA] := COFF_SCN_CNT_IDATA Or COFF_SCN_MEM_READ;

  For i := 1 To NUM_FIXED_SEC Do sec_reloc_cnt[i] := 0;
  For i := 1 To bin_fixup_count Do
    If (bin_fixups[i].sec >= 1) And (bin_fixups[i].sec <= NUM_FIXED_SEC) Then
      Inc(sec_reloc_cnt[bin_fixups[i].sec]);

  { calcul des offsets de fichier }
  hdr_size := 20 + num_sections * 40;
  cur_off  := hdr_size;
  For i := 1 To NUM_FIXED_SEC Do
  Begin
    If i = SEC_BSS Then Continue; { .bss n a pas de donnees physiques }
    cur_off := cur_off + sec_size[i];
  End;
  For i := 1 To NUM_FIXED_SEC Do
  Begin
    reloc_offset[i] := cur_off;
    cur_off := cur_off + sec_reloc_cnt[i] * 10;
  End;
  sym_table_off := cur_off;

  Assign(f, out_name);
  {$I-}
  Rewrite(f, 1);
  {$I+}
  If IoResult <> 0 Then
  Begin
    ErrorMsg('Impossible de creer le fichier objet : ' + out_name);
    Exit;
  End;

  { --- IMAGE_FILE_HEADER --- }
  CoffWrWord(f, COFF_MACHINE_I386);
  CoffWrWord(f, Word(num_sections));
  CoffWrDWord(f, 0); { horodatage }
  CoffWrDWord(f, sym_table_off);
  CoffWrDWord(f, coff_sym_count);
  CoffWrWord(f, 0); { pas d en-tete optionnel pour un .OBJ }
  CoffWrWord(f, 0); { characteristics }

  { --- en-tetes de section --- }
  cur_off := hdr_size;
  For i := 1 To NUM_FIXED_SEC Do
  Begin
    Case i Of
      SEC_TEXT  : CoffWrName8(f, '.text');
      SEC_DATA  : CoffWrName8(f, '.data');
      SEC_BSS   : CoffWrName8(f, '.bss');
      SEC_RDATA : CoffWrName8(f, '.rdata');
    End;
    CoffWrDWord(f, 0); { VirtualSize : non utilise pour un .OBJ }
    CoffWrDWord(f, 0); { VirtualAddress }
    CoffWrDWord(f, sec_size[i]);
    If i = SEC_BSS Then CoffWrDWord(f, 0) Else Begin CoffWrDWord(f, cur_off); cur_off := cur_off + sec_size[i]; End;
    If sec_reloc_cnt[i] > 0 Then CoffWrDWord(f, reloc_offset[i]) Else CoffWrDWord(f, 0);
    CoffWrDWord(f, 0); { PointerToLinenumbers }
    CoffWrWord(f, Word(sec_reloc_cnt[i]));
    CoffWrWord(f, 0);
    CoffWrDWord(f, sec_class[i]);
  End;

  { --- donnees brutes des sections (sauf .bss) --- }
  If sec_size[SEC_TEXT] > 0 Then BlockWrite(f, bin_text^, sec_size[SEC_TEXT]);
  If sec_size[SEC_DATA] > 0 Then BlockWrite(f, bin_data^, sec_size[SEC_DATA]);
  If sec_size[SEC_RDATA] > 0 Then BlockWrite(f, bin_rdata^, sec_size[SEC_RDATA]);

  { --- relocations, section par section --- }
  For i := 1 To NUM_FIXED_SEC Do
  Begin
    For j := 1 To bin_fixup_count Do
    Begin
      fx := bin_fixups[j];
      If fx.sec <> i Then Continue;
      If fx.is_extern Then
      Begin
        reloc_symidx := CoffFindSym(fx.name);
      End
      Else If fx.name <> '' Then
      Begin
        reloc_symidx := CoffFindSym(fx.name);
        If fx.kind = FX_ABS32 Then
        Begin
          ownsym := SymFind(fx.name);
          If ownsym <> Nil Then
          Begin
            patched_addend := fx.addend - ownsym^.offset;
            Case fx.sec Of
              SEC_TEXT  : Move(patched_addend, bin_text^[fx.pos], 4);
              SEC_DATA  : Move(patched_addend, bin_data^[fx.pos], 4);
              SEC_RDATA : Move(patched_addend, bin_rdata^[fx.pos], 4);
            End;
          End;
        End;
      End
      Else
      Begin
        reloc_symidx := coff_secsym_idx[fx.direct_sec];
      End;
      CoffWrDWord(f, fx.pos);
      CoffWrDWord(f, reloc_symidx - 1); { index 0-based dans le fichier COFF }
      If fx.kind = FX_ABS32 Then CoffWrWord(f, COFF_REL_DIR32)
      Else                       CoffWrWord(f, COFF_REL_REL32);
    End;
  End;

  { --- table de symboles --- }
  str_tab     := '';
  str_tab_len := 4; { les 4 premiers octets = taille totale de la table de chaines }
  For i := 1 To coff_sym_count Do
  Begin
    If Length(coff_syms[i].name) <= 8 Then
      CoffWrName8(f, coff_syms[i].name)
    Else
    Begin
      CoffWrDWord(f, 0); { zero_indicator }
      CoffWrDWord(f, str_tab_len);
      str_tab     := str_tab + coff_syms[i].name + #0;
      str_tab_len := str_tab_len + Length(coff_syms[i].name) + 1;
    End;
    CoffWrDWord(f, coff_syms[i].value);
    CoffWrWord(f, Word(coff_syms[i].section));
    CoffWrWord(f, 0); { type }
    If coff_syms[i].is_extern Then CoffWrByte(f, COFF_SYMCLASS_EXTERNAL)
    Else                           CoffWrByte(f, COFF_SYMCLASS_STATIC);
    CoffWrByte(f, 0); { NumberOfAuxSymbols }
  End;

  { --- table de chaines --- }
  CoffWrDWord(f, str_tab_len);
  If Length(str_tab) > 0 Then BlockWrite(f, str_tab[1], Length(str_tab));

  Close(f);
  If Not nologo_mode Then
    Writeln('   Cree : ', out_name);
End;

{ ============================================================
  TODO 11 - WRITER PE .EXE (LINKER INTERNE)
  ============================================================
  Limitation documentee (v1) : pas de support des bibliotheques
  d import (.LIB) - seule une table interne des fonctions Win32
  les plus courantes (kernel32/user32/msvcrt) est reconnue. Toute
  fonction EXTERN non repertoriee produit une erreur de lien
  ("symbole externe non resolu"). C est la meme approche que
  POWFXC32.PAS/PERLCW32.PAS, generalisee a plusieurs DLL.
  ============================================================ }
Const
  WINAPI_COUNT = 113;
  WINAPI_NAME : Array[1..WINAPI_COUNT] Of String[32] = (
    { kernel32.dll }
    'EXITPROCESS','GETSTDHANDLE','WRITEFILE','READFILE','CREATEFILEA',
    'CREATEFILEW','CLOSEHANDLE','GETLASTERROR','SETLASTERROR','HEAPALLOC',
    'HEAPFREE','GETPROCESSHEAP','HEAPREALLOC','GETMODULEHANDLEA','GETMODULEHANDLEW',
    'GETPROCADDRESS','LOADLIBRARYA','LOADLIBRARYW','GETCOMMANDLINEA','GETCOMMANDLINEW',
    'SLEEP','GETTICKCOUNT','VIRTUALALLOC','VIRTUALFREE','GETSYSTEMTIME',
    'GETLOCALTIME','SETCONSOLETEXTATTRIBUTE','SETCONSOLECURSORPOSITION',
    'GETCONSOLESCREENBUFFERINFO','FLUSHFILEBUFFERS','CREATETHREAD',
    'WAITFORSINGLEOBJECT','TERMINATEPROCESS','GETCURRENTPROCESS','GETCURRENTTHREAD',
    'MULTIBYTETOWIDECHAR','WIDECHARTOMULTIBYTE','LSTRLENA','LSTRCPYA','LSTRCATA',
    'FINDFIRSTFILEA','FINDNEXTFILEA','FINDCLOSE','DELETEFILEA','CREATEDIRECTORYA',
    'REMOVEDIRECTORYA','SETFILEPOINTER','GETFILESIZE','GETSTARTUPINFOA','GETENVIRONMENTVARIABLEA',
    'SETENVIRONMENTVARIABLEA','GETMODULEFILENAMEA','GETCURRENTDIRECTORYA','SETCURRENTDIRECTORYA',
    'CREATEPROCESSA','EXITTHREAD','LOCALALLOC','LOCALFREE','GLOBALALLOC','GLOBALFREE',
    { user32.dll }
    'MESSAGEBOXA','MESSAGEBOXW','WSPRINTFA','WSPRINTFW','GETMESSAGEA',
    'DISPATCHMESSAGEA','TRANSLATEMESSAGE','REGISTERCLASSA','REGISTERCLASSEXA',
    'CREATEWINDOWEXA','DEFWINDOWPROCA','SHOWWINDOW','UPDATEWINDOW','POSTQUITMESSAGE',
    'LOADCURSORA','LOADICONA','GETWINDOWTEXTA','SETWINDOWTEXTA','GETDC','RELEASEDC',
    'INVALIDATERECT','BEGINPAINT','ENDPAINT','DRAWTEXTA','SENDMESSAGEA','SETTIMER',
    'KILLTIMER','GETCLIENTRECT',
    { msvcrt.dll }
    'PRINTF','SPRINTF','SCANF','EXIT','MALLOC','FREE','CALLOC','REALLOC',
    'STRLEN','STRCPY','STRCAT','STRCMP','MEMCPY','MEMSET','MEMMOVE','ATOI',
    'ATOL','RAND','SRAND','PUTS','FOPEN','FCLOSE','FREAD','FWRITE','FPRINTF'
  );
  { casse exacte reelle des noms exportes (l export-by-name de Windows est
    sensible a la casse, contrairement aux identificateurs assembleur qui
    sont toujours convertis en majuscules par le lexer - voir ImportFuncIndex) }
  WINAPI_REALNAME : Array[1..WINAPI_COUNT] Of String[32] = (
    { kernel32.dll }
    'ExitProcess','GetStdHandle','WriteFile','ReadFile','CreateFileA',
    'CreateFileW','CloseHandle','GetLastError','SetLastError','HeapAlloc',
    'HeapFree','GetProcessHeap','HeapReAlloc','GetModuleHandleA','GetModuleHandleW',
    'GetProcAddress','LoadLibraryA','LoadLibraryW','GetCommandLineA','GetCommandLineW',
    'Sleep','GetTickCount','VirtualAlloc','VirtualFree','GetSystemTime',
    'GetLocalTime','SetConsoleTextAttribute','SetConsoleCursorPosition',
    'GetConsoleScreenBufferInfo','FlushFileBuffers','CreateThread',
    'WaitForSingleObject','TerminateProcess','GetCurrentProcess','GetCurrentThread',
    'MultiByteToWideChar','WideCharToMultiByte','lstrlenA','lstrcpyA','lstrcatA',
    'FindFirstFileA','FindNextFileA','FindClose','DeleteFileA','CreateDirectoryA',
    'RemoveDirectoryA','SetFilePointer','GetFileSize','GetStartupInfoA','GetEnvironmentVariableA',
    'SetEnvironmentVariableA','GetModuleFileNameA','GetCurrentDirectoryA','SetCurrentDirectoryA',
    'CreateProcessA','ExitThread','LocalAlloc','LocalFree','GlobalAlloc','GlobalFree',
    { user32.dll }
    'MessageBoxA','MessageBoxW','wsprintfA','wsprintfW','GetMessageA',
    'DispatchMessageA','TranslateMessage','RegisterClassA','RegisterClassExA',
    'CreateWindowExA','DefWindowProcA','ShowWindow','UpdateWindow','PostQuitMessage',
    'LoadCursorA','LoadIconA','GetWindowTextA','SetWindowTextA','GetDC','ReleaseDC',
    'InvalidateRect','BeginPaint','EndPaint','DrawTextA','SendMessageA','SetTimer',
    'KillTimer','GetClientRect',
    { msvcrt.dll }
    'printf','sprintf','scanf','exit','malloc','free','calloc','realloc',
    'strlen','strcpy','strcat','strcmp','memcpy','memset','memmove','atoi',
    'atol','rand','srand','puts','fopen','fclose','fread','fwrite','fprintf'
  );
  WINAPI_DLL : Array[1..WINAPI_COUNT] Of String[16] = (
    'KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL',
    'KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL',
    'KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL',
    'KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL',
    'KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL',
    'KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL',
    'KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL',
    'KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL',
    'KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL',
    'KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL',
    'KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL',
    'KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL',
    'KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL','KERNEL32.DLL',
    'USER32.DLL','USER32.DLL','USER32.DLL','USER32.DLL','USER32.DLL',
    'USER32.DLL','USER32.DLL','USER32.DLL','USER32.DLL',
    'USER32.DLL','USER32.DLL','USER32.DLL','USER32.DLL','USER32.DLL',
    'USER32.DLL','USER32.DLL','USER32.DLL','USER32.DLL','USER32.DLL','USER32.DLL',
    'USER32.DLL','USER32.DLL','USER32.DLL','USER32.DLL','USER32.DLL','USER32.DLL',
    'USER32.DLL','USER32.DLL',
    'MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL',
    'MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL',
    'MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL','MSVCRT.DLL'
  );

Function FindWinApiDll(Const fname : TString) : TString;
Var i : Integer; up : TString;
Begin
  up := LexUpperCase(fname);
  { retirer un eventuel prefixe de decoration __imp_ }
  If Copy(up, 1, 6) = '__IMP_' Then up := Copy(up, 7, Length(up) - 6);
  FindWinApiDll := '';
  For i := 1 To WINAPI_COUNT Do
    If WINAPI_NAME[i] = up Then Begin FindWinApiDll := WINAPI_DLL[i]; Exit; End;
End;

{ ============================================================
  FindWinApiRealName : retrouver la casse EXACTE du nom exporte
  (l export-by-name Windows est sensible a la casse, contrairement
  au nom de symbole assembleur qui est toujours en majuscules).
  Retourne fname inchange si non trouve (ne devrait pas arriver
  si FindWinApiDll a deja reussi juste avant).
  ============================================================ }
Function FindWinApiRealName(Const fname : TString) : TString;
Var i : Integer; up : TString;
Begin
  up := LexUpperCase(fname);
  If Copy(up, 1, 6) = '__IMP_' Then up := Copy(up, 7, Length(up) - 6);
  FindWinApiRealName := fname;
  For i := 1 To WINAPI_COUNT Do
    If WINAPI_NAME[i] = up Then Begin FindWinApiRealName := WINAPI_REALNAME[i]; Exit; End;
End;

{ ============================================================
  Structures de travail pour la construction de la table d import
  ============================================================ }
Type
  TImportFunc = Record
    sym_name     : TSymString; { nom du symbole tel qu utilise par le fixup (majuscules) }
    name         : TSymString; { casse EXACTE ecrite dans la table hint/name (export-by-name) }
    dll_index    : Integer;    { index 1-based dans import_dlls }
    iat_rva      : TLong;      { RVA finale de l entree IAT (remplie apres layout) }
    thunk_offset : TLong;      { offset dans .text du thunk FF25 (-1 = pas encore cree) }
  End;
Var
  import_dlls      : Array[1..MAX_IMPORT_DLL] Of TString;
  import_dll_count  : Integer;
  import_funcs      : Array[1..MAX_IMPORT_FUNC] Of TImportFunc;
  import_func_count : Integer;

Function ImportDllIndex(Const dll : TString) : Integer;
Var i : Integer;
Begin
  For i := 1 To import_dll_count Do
    If import_dlls[i] = dll Then Begin ImportDllIndex := i; Exit; End;
  If import_dll_count >= MAX_IMPORT_DLL Then Begin ImportDllIndex := 0; Exit; End;
  Inc(import_dll_count);
  import_dlls[import_dll_count] := dll;
  ImportDllIndex := import_dll_count;
End;

Function ImportFuncIndex(Const nm : TSymString) : Integer;
Var i, di : Integer; dll : TString;
Begin
  For i := 1 To import_func_count Do
    If import_funcs[i].sym_name = nm Then Begin ImportFuncIndex := i; Exit; End;
  dll := FindWinApiDll(nm);
  If dll = '' Then
  Begin
    ErrorMsg('Symbole externe non resolu (DLL inconnue pour) : ' + nm);
    ImportFuncIndex := 0;
    Exit;
  End;
  di := ImportDllIndex(dll);
  If import_func_count >= MAX_IMPORT_FUNC Then Begin ImportFuncIndex := 0; Exit; End;
  Inc(import_func_count);
  import_funcs[import_func_count].sym_name     := nm;
  import_funcs[import_func_count].name         := FindWinApiRealName(nm);
  import_funcs[import_func_count].dll_index    := di;
  import_funcs[import_func_count].iat_rva      := 0;
  import_funcs[import_func_count].thunk_offset := -1;
  ImportFuncIndex := import_func_count;
End;

{ ============================================================
  RDataAppend* : ecrire directement dans bin_rdata en etendant
  seg_table[SEC_RDATA].cur_lc (utilise uniquement en phase de
  construction du linker, apres la fin de l assemblage normal).
  ============================================================ }
Procedure RDataAppendByte(b : Byte);
Var p : TLong;
Begin
  p := seg_table[SEC_RDATA].cur_lc;
  If p < MAX_BIN_RDATA Then bin_rdata^[p] := b;
  Inc(seg_table[SEC_RDATA].cur_lc);
End;

Procedure RDataAppendWord(w : Word);
Begin
  RDataAppendByte(Byte(w And $FF));
  RDataAppendByte(Byte((w Shr 8) And $FF));
End;

Procedure RDataAppendDWord(d : LongWord);
Begin
  RDataAppendByte(Byte(d And $FF));
  RDataAppendByte(Byte((d Shr 8)  And $FF));
  RDataAppendByte(Byte((d Shr 16) And $FF));
  RDataAppendByte(Byte((d Shr 24) And $FF));
End;

Procedure RDataAppendStr(Const s : TString);
Var i : Integer;
Begin
  For i := 1 To Length(s) Do RDataAppendByte(Byte(Ord(s[i])));
  RDataAppendByte(0);
End;

Procedure TextAppendByte(b : Byte);
Var p : TLong;
Begin
  p := seg_table[SEC_TEXT].cur_lc;
  If p < MAX_BIN_TEXT Then bin_text^[p] := b;
  Inc(seg_table[SEC_TEXT].cur_lc);
End;

Procedure TextAppendDWord(d : LongWord);
Begin
  TextAppendByte(Byte(d And $FF));
  TextAppendByte(Byte((d Shr 8)  And $FF));
  TextAppendByte(Byte((d Shr 16) And $FF));
  TextAppendByte(Byte((d Shr 24) And $FF));
End;

Function AlignUp(v, a : TLong) : TLong;
Begin
  If a <= 1 Then Begin AlignUp := v; Exit; End;
  AlignUp := ((v + a - 1) Div a) * a;
End;

{ ============================================================
  Variables globales du layout PE (remplies par WritePE, lues
  par les fonctions de patch de fixups)
  ============================================================ }
Var
  g_text_rva, g_rdata_rva, g_data_rva, g_bss_rva : TLong;
  g_image_base : TLong;

Function SectionRvaOf(sec : Integer) : TLong;
Begin
  Case sec Of
    SEC_TEXT  : SectionRvaOf := g_text_rva;
    SEC_DATA  : SectionRvaOf := g_data_rva;
    SEC_BSS   : SectionRvaOf := g_bss_rva;
    SEC_RDATA : SectionRvaOf := g_rdata_rva;
  Else SectionRvaOf := 0;
  End;
End;

Procedure PatchSectionDWord(sec : Integer; pos : TLong; v : LongWord);
Begin
  If (pos < 0) Then Exit;
  Case sec Of
    SEC_TEXT  : If pos + 3 < MAX_BIN_TEXT  Then Move(v, bin_text^[pos],  4);
    SEC_DATA  : If pos + 3 < MAX_BIN_DATA  Then Move(v, bin_data^[pos],  4);
    SEC_RDATA : If pos + 3 < MAX_BIN_RDATA Then Move(v, bin_rdata^[pos], 4);
  End;
End;

Function HintNameSize(Const nm : TString) : Integer;
Var sz : Integer;
Begin
  sz := 2 + Length(nm) + 1;
  If Odd(sz) Then Inc(sz);
  HintNameSize := sz;
End;

{ ============================================================
  WritePE : construire la table d import, generer les thunks
  d appel, calculer le layout PE32 final, resoudre tous les
  fixups et ecrire l executable .EXE complet.
  ============================================================ }
Procedure WritePE(Const out_name : TString);
Var
  f  : File;
  i, d, cnt : Integer;
  off, off2 : TLong;
  func_hintname_rva : Array[1..MAX_IMPORT_FUNC] Of TLong;
  dll_ilt_rva, dll_iat_rva, dll_name_rva : Array[1..MAX_IMPORT_DLL] Of TLong;
  import_dir_rel, import_dir_rva : TLong;
  text_size, rdata_size, data_size, bss_size : TLong;
  hdr_raw_size, hdr_size_aligned : TLong;
  text_foff, rdata_foff, data_foff : TLong;
  size_of_image : TLong;
  num_sections : Integer;
  entry_rva : TLong;
  entry_sym : PSymbol;
  subsystem_val : Word;
  thunk_done : Array[1..MAX_IMPORT_FUNC] Of Boolean;
  fidx : Integer;
  fx   : TBinFixup;
  patch_abs : LongWord;
  patch_rel : LongInt;
  target_off, target_rva, patch_rva : TLong;
  written : Integer;
  pad_needed : Integer;
  zero_buf   : Array[0..511] Of Byte;
  section_rva_arr : Array[1..4] Of TLong;
  section_size_arr: Array[1..4] Of TLong;
  section_foff_arr: Array[1..4] Of TLong;
  section_raw_arr : Array[1..4] Of TLong;
  section_name_arr: Array[1..4] Of String[8];
  section_class_arr: Array[1..4] Of LongWord;
  n : Integer;
Begin
  g_image_base := $400000;

  { --- 1. symboles EXTERN reellement references --- }
  import_dll_count  := 0;
  import_func_count := 0;
  For i := 1 To bin_fixup_count Do
    If bin_fixups[i].is_extern Then ImportFuncIndex(bin_fixups[i].name);

  If err_count > 0 Then
  Begin
    Writeln(err_count, ' erreur(s) - edition de liens abandonnee.');
    Exit;
  End;

  { --- 2. mesurer (sans ecrire) le bloc d import ajoute a la fin de .rdata --- }
  off := seg_table[SEC_RDATA].cur_lc;
  For i := 1 To import_func_count Do
  Begin
    func_hintname_rva[i] := off;
    off := off + HintNameSize(import_funcs[i].name);
  End;
  For d := 1 To import_dll_count Do
  Begin
    dll_ilt_rva[d] := off;
    cnt := 0;
    For i := 1 To import_func_count Do If import_funcs[i].dll_index = d Then Inc(cnt);
    off := off + (cnt + 1) * 4;
  End;
  For d := 1 To import_dll_count Do
  Begin
    dll_iat_rva[d] := off;
    For i := 1 To import_func_count Do
      If import_funcs[i].dll_index = d Then
      Begin
        import_funcs[i].iat_rva := off;
        off := off + 4;
      End;
    off := off + 4;
  End;
  For d := 1 To import_dll_count Do
  Begin
    dll_name_rva[d] := off;
    off := off + Length(import_dlls[d]) + 1;
  End;
  If import_dll_count > 0 Then
  Begin
    If (off Mod 4) <> 0 Then off := off + (4 - (off Mod 4));
    import_dir_rel := off;
    off := off + import_dll_count * 20 + 20;
  End
  Else
    import_dir_rel := off;
  rdata_size := off;

  { --- 3. mesurer les thunks CALL/JMP vers l import (FF 25 [iat]) --- }
  For i := 1 To import_func_count Do Begin import_funcs[i].thunk_offset := -1; thunk_done[i] := False; End;
  off2 := seg_table[SEC_TEXT].cur_lc;
  For i := 1 To bin_fixup_count Do
  Begin
    If bin_fixups[i].is_extern And (bin_fixups[i].kind = FX_REL32) Then
    Begin
      fidx := ImportFuncIndex(bin_fixups[i].name);
      If (fidx > 0) And (import_funcs[fidx].thunk_offset < 0) Then
      Begin
        import_funcs[fidx].thunk_offset := off2;
        off2 := off2 + 6;
      End;
    End;
  End;
  text_size := off2;

  data_size := seg_table[SEC_DATA].cur_lc;
  bss_size  := seg_table[SEC_BSS].cur_lc;

  { --- 4. layout des sections (RVA memoire / offsets fichier) ---
    Un vrai linker omet completement les sections vides (VirtualSize=0) au
    lieu d en ecrire l en-tete - certains chargeurs PE rejettent l image si
    une section declaree est totalement vide (VirtualSize=0 ET
    SizeOfRawData=0). .text est toujours presente (point d entree). }
  num_sections := 1;
  If rdata_size > 0 Then Inc(num_sections);
  If data_size  > 0 Then Inc(num_sections);
  If bss_size   > 0 Then Inc(num_sections);
  hdr_raw_size := 64 + 4 + 20 + 224 + num_sections * 40;
  hdr_size_aligned := AlignUp(hdr_raw_size, $200);

  g_text_rva  := $1000;
  g_rdata_rva := g_text_rva  + AlignUp(text_size,  $1000);
  g_data_rva  := g_rdata_rva + AlignUp(rdata_size, $1000);
  g_bss_rva   := g_data_rva  + AlignUp(data_size,  $1000);
  size_of_image := AlignUp(g_bss_rva + AlignUp(bss_size, $1000), $1000);

  text_foff  := hdr_size_aligned;
  rdata_foff := text_foff  + AlignUp(text_size,  $200);
  data_foff  := rdata_foff + AlignUp(rdata_size, $200);

  { --- 5. convertir les offsets relatifs mesures en RVA absolues --- }
  For i := 1 To import_func_count Do func_hintname_rva[i] := func_hintname_rva[i] + g_rdata_rva;
  For d := 1 To import_dll_count Do
  Begin
    dll_ilt_rva[d]  := dll_ilt_rva[d]  + g_rdata_rva;
    dll_iat_rva[d]  := dll_iat_rva[d]  + g_rdata_rva;
    dll_name_rva[d] := dll_name_rva[d] + g_rdata_rva;
  End;
  For i := 1 To import_func_count Do import_funcs[i].iat_rva := import_funcs[i].iat_rva + g_rdata_rva;
  import_dir_rva := import_dir_rel + g_rdata_rva;

  { --- 6. ecrire reellement le bloc d import dans bin_rdata --- }
  For i := 1 To import_func_count Do
  Begin
    RDataAppendWord(0);
    RDataAppendStr(import_funcs[i].name);
    written := 2 + Length(import_funcs[i].name) + 1;
    If Odd(written) Then RDataAppendByte(0);
  End;
  For d := 1 To import_dll_count Do
  Begin
    For i := 1 To import_func_count Do
      If import_funcs[i].dll_index = d Then RDataAppendDWord(func_hintname_rva[i]);
    RDataAppendDWord(0);
  End;
  For d := 1 To import_dll_count Do
  Begin
    For i := 1 To import_func_count Do
      If import_funcs[i].dll_index = d Then RDataAppendDWord(func_hintname_rva[i]);
    RDataAppendDWord(0);
  End;
  For d := 1 To import_dll_count Do RDataAppendStr(import_dlls[d]);
  If import_dll_count > 0 Then
  Begin
    While (seg_table[SEC_RDATA].cur_lc Mod 4) <> 0 Do RDataAppendByte(0);
    For d := 1 To import_dll_count Do
    Begin
      RDataAppendDWord(dll_ilt_rva[d]);
      RDataAppendDWord(0);
      RDataAppendDWord(0);
      RDataAppendDWord(dll_name_rva[d]);
      RDataAppendDWord(dll_iat_rva[d]);
    End;
    For i := 1 To 5 Do RDataAppendDWord(0);
  End;

  { --- 7. ecrire reellement les thunks dans bin_text (meme ordre que la mesure) --- }
  For i := 1 To bin_fixup_count Do
  Begin
    If bin_fixups[i].is_extern And (bin_fixups[i].kind = FX_REL32) Then
    Begin
      fidx := ImportFuncIndex(bin_fixups[i].name);
      If (fidx > 0) And (Not thunk_done[fidx]) Then
      Begin
        thunk_done[fidx] := True;
        TextAppendByte($FF); TextAppendByte($25);
        TextAppendDWord(LongWord(g_image_base + import_funcs[fidx].iat_rva));
      End;
    End;
  End;

  { --- 8. resoudre tous les fixups (patch direct dans les buffers) --- }
  For i := 1 To bin_fixup_count Do
  Begin
    fx := bin_fixups[i];
    If fx.kind = FX_ABS32 Then
    Begin
      If fx.is_extern Then
      Begin
        fidx := ImportFuncIndex(fx.name);
        patch_abs := LongWord(g_image_base + import_funcs[fidx].iat_rva);
      End
      Else
        patch_abs := LongWord(g_image_base + SectionRvaOf(fx.direct_sec) + fx.addend);
      PatchSectionDWord(fx.sec, fx.pos, patch_abs);
    End
    Else
    Begin { FX_REL32 }
      If fx.is_extern Then
      Begin
        fidx := ImportFuncIndex(fx.name);
        target_off := import_funcs[fidx].thunk_offset;
        patch_rel  := target_off - (fx.pos + 4); { meme section .text : les RVA s annulent }
      End
      Else
      Begin
        target_rva := SectionRvaOf(fx.direct_sec) + fx.addend;
        patch_rva  := SectionRvaOf(fx.sec) + fx.pos + 4;
        patch_rel  := target_rva - patch_rva;
      End;
      PatchSectionDWord(fx.sec, fx.pos, LongWord(patch_rel));
    End;
  End;

  { --- 9. point d entree --- }
  entry_rva := g_text_rva;
  If entry_point_name <> '' Then
  Begin
    entry_sym := SymFind(entry_point_name);
    If entry_sym <> Nil Then entry_rva := SectionRvaOf(entry_sym^.seg_idx) + entry_sym^.offset;
  End;

  If link_subsystem = 'WINDOWS' Then subsystem_val := 2 Else subsystem_val := 3;

  { --- 10. ecrire le fichier .EXE --- }
  Assign(f, out_name);
  {$I-}
  Rewrite(f, 1);
  {$I+}
  If IoResult <> 0 Then
  Begin
    ErrorMsg('Impossible de creer l executable : ' + out_name);
    Exit;
  End;

  { en-tete DOS minimal (64 octets) : seuls e_magic et e_lfanew comptent }
  CoffWrWord(f, $5A4D); { 'MZ' }
  For i := 1 To 29 Do CoffWrWord(f, 0); { 58 octets a 0, jusqu a l offset 60 }
  CoffWrDWord(f, 64);   { e_lfanew : le PE header commence juste apres ces 64 octets }

  { signature PE }
  CoffWrByte(f, Ord('P')); CoffWrByte(f, Ord('E')); CoffWrByte(f, 0); CoffWrByte(f, 0);

  { IMAGE_FILE_HEADER }
  CoffWrWord(f, COFF_MACHINE_I386);
  CoffWrWord(f, Word(num_sections));
  CoffWrDWord(f, 0);
  CoffWrDWord(f, 0);
  CoffWrDWord(f, 0);
  CoffWrWord(f, 224); { SizeOfOptionalHeader }
  CoffWrWord(f, $010F); { RELOCS_STRIPPED | EXECUTABLE_IMAGE | LINE_NUMS_STRIPPED | LOCAL_SYMS_STRIPPED | 32BIT_MACHINE }

  { IMAGE_OPTIONAL_HEADER32 }
  CoffWrWord(f, $10B); { magic PE32 }
  CoffWrByte(f, 8); CoffWrByte(f, 0); { linker version }
  CoffWrDWord(f, AlignUp(text_size, $200));
  CoffWrDWord(f, AlignUp(rdata_size, $200) + AlignUp(data_size, $200));
  CoffWrDWord(f, AlignUp(bss_size, $1000));
  CoffWrDWord(f, entry_rva);
  CoffWrDWord(f, g_text_rva);
  If data_size > 0 Then CoffWrDWord(f, g_data_rva)
  Else If rdata_size > 0 Then CoffWrDWord(f, g_rdata_rva)
  Else CoffWrDWord(f, g_text_rva);
  CoffWrDWord(f, g_image_base);
  CoffWrDWord(f, $1000); { SectionAlignment }
  CoffWrDWord(f, $200);  { FileAlignment }
  CoffWrWord(f, 4); CoffWrWord(f, 0); { MajorOSVersion }
  CoffWrWord(f, 0); CoffWrWord(f, 0); { MajorImageVersion }
  CoffWrWord(f, 4); CoffWrWord(f, 0); { MajorSubsystemVersion }
  CoffWrDWord(f, 0); { Win32VersionValue }
  CoffWrDWord(f, size_of_image);
  CoffWrDWord(f, hdr_size_aligned);
  CoffWrDWord(f, 0); { CheckSum }
  CoffWrWord(f, subsystem_val);
  CoffWrWord(f, 0); { DllCharacteristics }
  CoffWrDWord(f, pe_stack_reserve);
  CoffWrDWord(f, $1000);
  CoffWrDWord(f, $100000);
  CoffWrDWord(f, $1000);
  CoffWrDWord(f, 0); { LoaderFlags }
  CoffWrDWord(f, 16); { NumberOfRvaAndSizes }
  { DataDirectory[0] Export }
  CoffWrDWord(f, 0); CoffWrDWord(f, 0);
  { DataDirectory[1] Import }
  If import_dll_count > 0 Then Begin CoffWrDWord(f, import_dir_rva); CoffWrDWord(f, import_dll_count * 20 + 20); End
  Else Begin CoffWrDWord(f, 0); CoffWrDWord(f, 0); End;
  { DataDirectory[2..11] non utilises }
  For i := 1 To 10 Do Begin CoffWrDWord(f, 0); CoffWrDWord(f, 0); End;
  { DataDirectory[12] IAT }
  If import_dll_count > 0 Then Begin CoffWrDWord(f, dll_iat_rva[1]); CoffWrDWord(f, LongWord(import_func_count * 4)); End
  Else Begin CoffWrDWord(f, 0); CoffWrDWord(f, 0); End;
  { DataDirectory[13..15] non utilises }
  For i := 1 To 3 Do Begin CoffWrDWord(f, 0); CoffWrDWord(f, 0); End;

  { --- en-tetes de section : seules les sections non vides sont ecrites --- }
  n := 0;
  Inc(n);
  section_name_arr[n] := '.text'; section_rva_arr[n] := g_text_rva; section_size_arr[n] := text_size;
  section_foff_arr[n] := text_foff; section_raw_arr[n] := AlignUp(text_size, $200);
  section_class_arr[n] := COFF_SCN_CNT_CODE Or COFF_SCN_MEM_EXEC Or COFF_SCN_MEM_READ;
  If rdata_size > 0 Then
  Begin
    Inc(n);
    section_name_arr[n] := '.rdata'; section_rva_arr[n] := g_rdata_rva; section_size_arr[n] := rdata_size;
    section_foff_arr[n] := rdata_foff; section_raw_arr[n] := AlignUp(rdata_size, $200);
    section_class_arr[n] := COFF_SCN_CNT_IDATA Or COFF_SCN_MEM_READ;
  End;
  If data_size > 0 Then
  Begin
    Inc(n);
    section_name_arr[n] := '.data'; section_rva_arr[n] := g_data_rva; section_size_arr[n] := data_size;
    section_foff_arr[n] := data_foff; section_raw_arr[n] := AlignUp(data_size, $200);
    section_class_arr[n] := COFF_SCN_CNT_IDATA Or COFF_SCN_MEM_READ Or COFF_SCN_MEM_WRITE;
  End;
  If bss_size > 0 Then
  Begin
    Inc(n);
    section_name_arr[n] := '.bss'; section_rva_arr[n] := g_bss_rva; section_size_arr[n] := bss_size;
    section_foff_arr[n] := 0; section_raw_arr[n] := 0;
    section_class_arr[n] := COFF_SCN_CNT_UDATA Or COFF_SCN_MEM_READ Or COFF_SCN_MEM_WRITE;
  End;

  For i := 1 To num_sections Do
  Begin
    CoffWrName8(f, section_name_arr[i]);
    CoffWrDWord(f, section_size_arr[i]);      { VirtualSize }
    CoffWrDWord(f, section_rva_arr[i]);       { VirtualAddress }
    CoffWrDWord(f, section_raw_arr[i]);       { SizeOfRawData }
    CoffWrDWord(f, section_foff_arr[i]);      { PointerToRawData }
    CoffWrDWord(f, 0); CoffWrDWord(f, 0);
    CoffWrWord(f, 0); CoffWrWord(f, 0);
    CoffWrDWord(f, section_class_arr[i]);
  End;

  { --- remplissage jusqu au premier alignement de fichier --- }
  For i := 1 To 512 Do zero_buf[i-1] := 0;
  pad_needed := hdr_size_aligned - hdr_raw_size;
  While pad_needed > 0 Do
  Begin
    If pad_needed > 512 Then Begin BlockWrite(f, zero_buf, 512); pad_needed := pad_needed - 512; End
    Else Begin BlockWrite(f, zero_buf, pad_needed); pad_needed := 0; End;
  End;

  { --- donnees brutes de section, chacune completee a FileAlignment --- }
  If text_size > 0 Then BlockWrite(f, bin_text^, text_size);
  pad_needed := AlignUp(text_size, $200) - text_size;
  While pad_needed > 0 Do
  Begin
    If pad_needed > 512 Then Begin BlockWrite(f, zero_buf, 512); pad_needed := pad_needed - 512; End
    Else Begin BlockWrite(f, zero_buf, pad_needed); pad_needed := 0; End;
  End;

  If rdata_size > 0 Then BlockWrite(f, bin_rdata^, rdata_size);
  pad_needed := AlignUp(rdata_size, $200) - rdata_size;
  While pad_needed > 0 Do
  Begin
    If pad_needed > 512 Then Begin BlockWrite(f, zero_buf, 512); pad_needed := pad_needed - 512; End
    Else Begin BlockWrite(f, zero_buf, pad_needed); pad_needed := 0; End;
  End;

  If data_size > 0 Then BlockWrite(f, bin_data^, data_size);
  pad_needed := AlignUp(data_size, $200) - data_size;
  While pad_needed > 0 Do
  Begin
    If pad_needed > 512 Then Begin BlockWrite(f, zero_buf, 512); pad_needed := pad_needed - 512; End
    Else Begin BlockWrite(f, zero_buf, pad_needed); pad_needed := 0; End;
  End;

  Close(f);
  If Not nologo_mode Then
    Writeln('   Cree : ', out_name);
End;

{ ============================================================
  TODO 12 - GENERATEUR DE LISTING .LST (basique)
  ============================================================
  Format simplifie (une ligne par ligne source) : numero de
  ligne, section:offset de depart, jusqu a 6 octets generes en
  hexadecimal, puis le texte source. Pas de pagination/table des
  symboles en fin de fichier (limitation documentee v1).
  ============================================================ }
Var
  lst_file : Text;
  lst_open : Boolean;

Procedure LstOpen(Const fname : TString);
Begin
  Assign(lst_file, fname);
  {$I-}
  Rewrite(lst_file);
  {$I+}
  lst_open := (IoResult = 0);
  If lst_open Then
    Writeln(lst_file, 'ML.PAS - Listing d assemblage (version ', VERSION, ')');
End;

Procedure LstClose;
Begin
  If lst_open Then Begin Close(lst_file); lst_open := False; End;
End;

Function HexByteStr(b : Byte) : TString;
Const hx : String[16] = '0123456789ABCDEF';
Begin
  HexByteStr := hx[(b Shr 4) + 1] + hx[(b And $F) + 1];
End;

Procedure LstEmitLine(lineno : Integer; start_seg : Integer; start_lc : TLong;
                     end_lc : TLong; Const srcline : TString);
Var
  s      : TString;
  n, i   : Integer;
  ln_str : TString;
Begin
  If Not lst_open Then Exit;
  Str(lineno:5, ln_str);
  s := ln_str + '  ';
  If (start_seg >= 1) And (start_seg <= NUM_FIXED_SEC) And (Not seg_table[start_seg].is_bss) Then
  Begin
    n := end_lc - start_lc;
    If n > 6 Then n := 6;
    For i := 0 To n - 1 Do
    Begin
      Case start_seg Of
        SEC_TEXT  : s := s + HexByteStr(bin_text^[start_lc + i]);
        SEC_DATA  : s := s + HexByteStr(bin_data^[start_lc + i]);
        SEC_RDATA : s := s + HexByteStr(bin_rdata^[start_lc + i]);
      End;
      s := s + ' ';
    End;
  End;
  While Length(s) < 30 Do s := s + ' ';
  Writeln(lst_file, s, srcline);
End;

{ ============================================================
  TODO 13 - DRIVER DEUX PASSES ET GESTION MULTI-FICHIERS
  ============================================================ }
Var
  asm_end_seen : Boolean; { True des que la directive END a ete rencontree }
  g_srcfiles      : Array[1..MAX_SRCFILES] Of TString;
  g_srcfile_count : Integer;

{ ============================================================
  ResetAssemblyState : reinitialiser tout l etat semantique
  (symboles, macros, conditions, sections) avant un assemblage.
  N alloue PAS les buffers .text/.data/.rdata (BinInit, appele
  une seule fois au demarrage du programme).
  ============================================================ }
Procedure ResetAssemblyState;
Var i : Integer;
Begin
  For i := 0 To HASH_SIZE - 1 Do hash_table[i] := Nil;
  sym_count := 0;
  For i := 1 To NUM_FIXED_SEC Do
  Begin
    seg_table[i].cur_lc   := 0;
    seg_table[i].defined  := False;
    seg_table[i].is_bss   := (i = SEC_BSS);
    seg_table[i].class_name := '';
    Case i Of
      SEC_TEXT  : seg_table[i].name := '.text';
      SEC_DATA  : seg_table[i].name := '.data';
      SEC_BSS   : seg_table[i].name := '.bss';
      SEC_RDATA : seg_table[i].name := '.rdata';
    End;
  End;
  seg_count  := NUM_FIXED_SEC;
  cur_seg    := SEC_TEXT;
  err_count  := 0;
  warn_count := 0;
  macro_def_count := 0;
  MacroExpInit;
  CondInit;
  in_proc := False;
  entry_point_name := '';
  flat_model := False;
  use32_mode := False;
  pe_stack_reserve := $100000;
  bin_fixup_count := 0;
  SymInit;
End;

{ ============================================================
  RunFilePass : executer une passe complete (1 ou 2) sur UN
  fichier source (les compteurs de section ne sont PAS remis a
  zero ici - c est la responsabilite de l appelant, pour
  permettre l assemblage combine de plusieurs fichiers avec un
  location counter continu).
  ============================================================ }
Procedure RunFilePass(pass : Integer; Const fname : TString);
Var
  lst_start_lc  : TLong;
  lst_start_seg : Integer;
Begin
  pass_num   := pass;
  cur_lineno := 0;
  SrcInit;
  SrcPush(fname);
  If SrcAtEnd Then
  Begin
    ErrorMsg('Impossible d ouvrir le fichier source : ' + fname);
    Exit;
  End;
  LexInit;
  asm_end_seen := False;
  Repeat
    LexNext;
    If lex_tok.kind = TK_EOF Then Break;
    If do_listing And (pass = 2) And lst_open Then
    Begin
      lst_start_seg := cur_seg;
      lst_start_lc  := seg_table[cur_seg].cur_lc;
    End;
    ProcessLine;
    If do_listing And (pass = 2) And lst_open Then
      LstEmitLine(cur_lineno, lst_start_seg, lst_start_lc, seg_table[lst_start_seg].cur_lc, cur_line);
    If asm_end_seen Then Break;
  Until False;
End;

{ ============================================================
  AssembleOneFile : assembler UN fichier en un .OBJ COFF
  independant (mode /c).
  ============================================================ }
Procedure AssembleOneFile(Const fname, out_obj : TString);
Var i : Integer;
Begin
  ResetAssemblyState;
  InitPredefDateTimeFilename(fname);

  If Not nologo_mode Then Writeln('Assemblage (passe 1) : ', fname);
  RunFilePass(1, fname);
  If err_count > 0 Then
  Begin
    Writeln(err_count, ' erreur(s) en passe 1 - ', fname);
    Exit;
  End;

  For i := 1 To NUM_FIXED_SEC Do seg_table[i].cur_lc := 0;
  cur_seg := SEC_TEXT;
  If Not nologo_mode Then Writeln('Assemblage (passe 2) : ', fname);
  RunFilePass(2, fname);
  If err_count > 0 Then
  Begin
    Writeln(err_count, ' erreur(s) en passe 2 - ', fname);
    Exit;
  End;

  WriteCOFF(out_obj);
End;

{ ============================================================
  AssembleCombinedAndLink : assembler TOUS les fichiers sources
  donnes sur la ligne de commande comme un seul module logique
  (location counter continu entre fichiers), puis produire l
  executable .EXE via le linker interne (WritePE).
  Limitation documentee (v1) : contrairement a un vrai ML.EXE
  (un .OBJ distinct par source, lies ensuite), tous les fichiers
  sont combines en une seule unite de compilation - suffisant
  pour l usage courant (un seul fichier .asm dans l ecrasante
  majorite des cas), evite d avoir a implementer un linker
  multi-module complet.
  ============================================================ }
Procedure AssembleCombinedAndLink(Const out_exe : TString);
Var i : Integer;
Begin
  ResetAssemblyState;
  If g_srcfile_count > 0 Then InitPredefDateTimeFilename(g_srcfiles[1]);
  If link_entry <> '' Then entry_point_name := link_entry;

  For i := 1 To NUM_FIXED_SEC Do seg_table[i].cur_lc := 0;
  cur_seg := SEC_TEXT;
  For i := 1 To g_srcfile_count Do
  Begin
    If Not nologo_mode Then Writeln('Assemblage (passe 1) : ', g_srcfiles[i]);
    RunFilePass(1, g_srcfiles[i]);
  End;
  If err_count > 0 Then
  Begin
    Writeln(err_count, ' erreur(s) en passe 1.');
    Exit;
  End;

  For i := 1 To NUM_FIXED_SEC Do seg_table[i].cur_lc := 0;
  cur_seg := SEC_TEXT;
  For i := 1 To g_srcfile_count Do
  Begin
    If Not nologo_mode Then Writeln('Assemblage (passe 2) : ', g_srcfiles[i]);
    RunFilePass(2, g_srcfiles[i]);
  End;
  If err_count > 0 Then
  Begin
    Writeln(err_count, ' erreur(s) en passe 2.');
    Exit;
  End;

  If link_entry <> '' Then entry_point_name := link_entry;
  WritePE(out_exe);
End;

{ ============================================================
  TODO 14 - PARSEUR CLI FACON ML.EXE + PROGRAMME PRINCIPAL
  ============================================================
  ML [options] fichier.asm [[options] [fichier.asm] ...] [/link options_de_liaison]
  Options : /c /Zi /Zd /Fl[fichier] /Fo[fichier] /I[chemin]
  /coff /nologo /W0../W2 /? /help ; apres /link : /OUT: /SUBSYSTEM:
  /ENTRY: /STACK: /LIBPATH: (ignore) /DEBUG (ignore).
  ============================================================ }
Procedure ShowUsage;Begin
  Writeln('ML- Cette commande permet de lancer le compilateur Macro Assembler (ML.EXE) 80386/Win32.');
  WriteLn;
  Writeln('Syntaxe : ML [options] fichier.asm [[options] [fichier.asm] ...] [/link options-de-liaison]');
  WriteLn;
  Writeln('Options :');
  Writeln('  /c            assembler seulement (produit un .OBJ COFF, pas d edition de liens)');
  Writeln('  /Zi /Zd       accepte, information de debogage non emise');
  Writeln('  /Fo<fichier>  nom du fichier .OBJ de sortie');
  Writeln('  /Fl[fichier]  generer un fichier de listing .LST');
  Writeln('  /I<chemin>    ajouter un repertoire de recherche INCLUDE');
  Writeln('  /coff         accepte (le format de sortie est toujours COFF)');
  Writeln('  /nologo       ne pas afficher la banniere');
  Writeln('  /W0 /W1 /W2   niveau d avertissement');
  Writeln('  /? /help      afficher cette aide');
  Writeln('  /link ...     options transmises au linker interne :');
  Writeln('                /OUT:fichier /SUBSYSTEM:CONSOLE|WINDOWS /ENTRY:nom /STACK:taille');
End;

Function ExtractFileExtPos(Const fn : TString) : Integer;
Var i : Integer;
Begin
  ExtractFileExtPos := 0;
  For i := Length(fn) DownTo 1 Do
  Begin
    If fn[i] = '.' Then Begin ExtractFileExtPos := i; Exit; End;
    If (fn[i] = '\') Or (fn[i] = '/') Then Exit;
  End;
End;

Function ChangeExt(Const fn : TString; Const newext : TString) : TString;
Var p : Integer;
Begin
  p := ExtractFileExtPos(fn);
  If p > 0 Then ChangeExt := Copy(fn, 1, p - 1) + newext
  Else          ChangeExt := fn + newext;
End;

Function StrToIntSafe(Const s : TString) : TLong;
Var v : LongInt; code : Integer;
Begin
  Val(s, v, code);
  If code <> 0 Then v := 0;
  StrToIntSafe := v;
End;

Procedure ParseArgs;
Var
  i, ac        : Integer;
  a, au        : TString;
  in_link_sect : Boolean;
  p            : TString;
Begin
  g_srcfile_count := 0;
  inc_path_count  := 0;
  assemble_only   := False;
  do_listing      := False;
  lst_fname       := '';
  obj_fname       := '';
  nologo_mode     := False;
  warn_level      := 1;
  debug_info      := False;
  link_subsystem  := 'CONSOLE';
  link_entry      := '';
  link_out        := '';
  show_err_lines  := False;
  in_link_sect    := False;

  ac := ParamCount;
  i := 1;
  While i <= ac Do
  Begin
    a := ParamStr(i);

    If in_link_sect Then
    Begin
      au := LexUpperCase(a);
      If Copy(au, 1, 5) = '/OUT:' Then link_out := Copy(a, 6, Length(a) - 5)
      Else If Copy(au, 1, 11) = '/SUBSYSTEM:' Then link_subsystem := LexUpperCase(Copy(a, 12, Length(a) - 11))
      Else If Copy(au, 1, 7) = '/ENTRY:' Then link_entry := Copy(a, 8, Length(a) - 7)
      Else If Copy(au, 1, 7) = '/STACK:' Then pe_stack_reserve := StrToIntSafe(Copy(a, 8, Length(a) - 7))
      Else { /LIBPATH: /DEBUG /MACHINE: /DEFAULTLIB: etc. ignores } ;
      Inc(i);
      Continue;
    End;

    If (Length(a) > 0) And ((a[1] = '/') Or (a[1] = '-')) Then
    Begin
      au := LexUpperCase(Copy(a, 2, Length(a) - 1));
      If au = 'LINK' Then Begin in_link_sect := True; Inc(i); Continue; End
      Else If (au = '?') Or (au = 'HELP') Then Begin ShowUsage; Halt(0); End
      Else If au = 'C' Then assemble_only := True
      Else If (au = 'ZI') Or (au = 'ZD') Then debug_info := True
      Else If au = 'NOLOGO' Then nologo_mode := True
      Else If au = 'W0' Then warn_level := 0
      Else If au = 'W1' Then warn_level := 1
      Else If au = 'W2' Then warn_level := 2
      Else If au = 'COFF' Then { deja le format par defaut }
      Else If au = 'Z' Then show_err_lines := True
      Else If (Length(au) >= 1) And (au[1] = 'I') Then
      Begin
        If Length(au) > 1 Then p := Copy(a, 3, Length(a) - 2)
        Else Begin Inc(i); p := ParamStr(i); End;
        If inc_path_count < MAX_INCPATH Then Begin Inc(inc_path_count); inc_paths[inc_path_count] := p; End;
      End
      Else If (Length(au) >= 2) And (au[1] = 'F') And (au[2] = 'O') Then
      Begin
        If Length(au) > 2 Then obj_fname := Copy(a, 4, Length(a) - 3)
        Else Begin Inc(i); obj_fname := ParamStr(i); End;
      End
      Else If (Length(au) >= 2) And (au[1] = 'F') And (au[2] = 'L') Then
      Begin
        do_listing := True;
        If Length(au) > 2 Then lst_fname := Copy(a, 4, Length(a) - 3);
      End
      Else { option non reconnue : ignoree silencieusement (comportement tolerant) } ;
    End
    Else
    Begin
      If g_srcfile_count < MAX_SRCFILES Then
      Begin
        Inc(g_srcfile_count);
        g_srcfiles[g_srcfile_count] := a;
      End;
    End;
    Inc(i);
  End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Var
  main_i       : Integer;
  main_outobj  : TString;
  main_outexe  : TString;
BEGIN
  BinInit;
  ParseArgs;

  If Not nologo_mode Then
    Writeln('ML.PAS - clone de Microsoft Macro Assembler (ML.EXE) 80386/Win32, version ', VERSION);

  If g_srcfile_count = 0 Then
  Begin
    ShowUsage;
    Halt(1);
  End;

  If assemble_only Then
  Begin
    For main_i := 1 To g_srcfile_count Do
    Begin
      If (g_srcfile_count = 1) And (obj_fname <> '') Then
        main_outobj := obj_fname
      Else
        main_outobj := ChangeExt(g_srcfiles[main_i], '.obj');

      If do_listing Then
      Begin
        If (lst_fname = '') Or (g_srcfile_count > 1) Then
          LstOpen(ChangeExt(g_srcfiles[main_i], '.lst'))
        Else
          LstOpen(lst_fname);
      End;

      AssembleOneFile(g_srcfiles[main_i], main_outobj);

      If do_listing Then LstClose;
    End;
  End
  Else
  Begin
    If link_out <> '' Then main_outexe := link_out
    Else main_outexe := ChangeExt(g_srcfiles[1], '.exe');

    If do_listing Then
    Begin
      If lst_fname <> '' Then LstOpen(lst_fname)
      Else LstOpen(ChangeExt(g_srcfiles[1], '.lst'));
    End;

    AssembleCombinedAndLink(main_outexe);

    If do_listing Then LstClose;
  End;

  If err_count > 0 Then Halt(1) Else Halt(0);
END.

