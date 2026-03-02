{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur LISP pour 8086/8088 - Sortie MASM/TASM
}

Program LISP86;

{$A-}
{$I-}

Uses DOS;

{ ============================================================================ }
{ CONSTANTES GENERALES                                                         }
{ ============================================================================ }

Const
 VERSION = 'LISP86 V1.0';

  { ---- Types de jetons LISP ---- }
 TOK_UNKNOWN  = 0;
 TOK_LPAREN   = 1;   { (                           }
 TOK_RPAREN   = 2;   { )                           }
 TOK_ATOM     = 3;   { identifiant / mot-cle       }
 TOK_NUMBER   = 4;   { litt‚rale num‚rique entiŠre }
 TOK_STRING   = 5;   { "texte"                     }
 TOK_QUOTE    = 6;   { '  (sucre syntaxique)       }
 TOK_BQUOTE   = 7;   { `  (backquote)              }
 TOK_COMMA    = 8;   { ,  (unquote)                }
 TOK_COMMA_AT = 9;   { ,@ (splice)                 }
 TOK_HASH_T   = 10;  { #t  => T                    }
 TOK_HASH_F   = 11;  { #f  => NIL                  }
 TOK_CHAR     = 12;  { #\a => code ASCII           }
 TOK_EOF      = 99;

 { ---- Balises de valeurs LISP (3 bits hauts d'un Word) ---- }
 { Valeur encodee : TTTVVVVVVVVVVVVV (3 bits tag + 13 bits payload) }
 LTAG_NIL    = 0; { NIL / faux        : Word = 0000_0 = $0000    }
 LTAG_T      = 1; { T / vrai          : Word = 001_xxxxx         }
 LTAG_FIXNUM = 2; { Entier 13 bits    : Word = 010_vvvvvvvvvvvvv }
 LTAG_SYM    = 3; { Symbole           : Word = 011_index_sym     }
 LTAG_CONS   = 4; { Cons cell         : Word = 100_index_heap    }
 LTAG_STR    = 5; { Chaine (tas)      : Word = 101_index_str     }
 LTAG_FUNC   = 6; { Fonction compil‚e : Word = 110_index_func    }
 LTAG_LAMBDA = 7; { Closure           : Word = 111_index_func    }

  { Constantes Word pr‚-calcul‚es }
 LVAL_NIL  = $0000;  { balise NIL, payload 0 }
 LVAL_T    = $2000;  { balise T  ($2000 = 001_0000000000000) }

 { D‚calage de balise }
 LTAG_SHIFT = 13;
 LPAY_MASK  = $1FFF;  { 13 bits de payload }

  { ---- Formes sp‚ciales ---- }
 SF_NONE    =  0;
 SF_DEFUN   =  1;
 SF_LAMBDA  =  2;
 SF_LET     =  3;
 SF_LETSTAR =  4;
 SF_IF      =  5;
 SF_COND    =  6;
 SF_QUOTE   =  7;
 SF_SETQ    =  8;
 SF_SETF    =  9;
 SF_PROGN   = 10;
 SF_AND     = 11;
 SF_OR      = 12;
 SF_NOT     = 13;
 SF_WHEN    = 14;
 SF_UNLESS  = 15;
 SF_DO      = 16;
 SF_LOOP    = 17;
 SF_RETURN  = 18;
 SF_DEFVAR  = 19;
 SF_DEFCONST= 20;
 SF_MAPCAR  = 21;
 SF_APPLY   = 22;
 SF_FUNCALL = 23;

  { ---- Primitives arithm‚tiques ---- }
 PRIM_NONE  = 0;
 PRIM_ADD   = 1; { +   }
 PRIM_SUB   = 2; { -   }
 PRIM_MUL   = 3; { *   }
 PRIM_DIV   = 4; { /   }
 PRIM_MOD   = 5; { MOD }
 PRIM_EQ    = 6; { =   }
 PRIM_LT    = 7; { <   }
 PRIM_GT    = 8; { >   }
 PRIM_LE    = 9; { <=  }
 PRIM_GE    = 10;{ >=  }
 PRIM_NEQ   = 11;{ /=  }
 PRIM_EQP   = 12;{ EQ   (identit‚ pointeur) }
 PRIM_EQUAL = 13;{ EQUAL (structurel) }
 PRIM_CAR   = 14;{ CAR  }
 PRIM_CDR   = 15;{ CDR  }
 PRIM_CONS  = 16;{ CONS }
 PRIM_LIST  = 17;{ LIST }
 PRIM_ATOM  = 18;{ ATOM }
 PRIM_NULL  = 19;{ NULL }
 PRIM_NOT   = 20;{ NOT  }
 PRIM_PRINT = 21;{ PRINT }
 PRIM_WRITE = 22;{ WRITE }
 PRIM_READ  = 23;{ READ  }
 PRIM_TERPRI= 24;{ TERPRI }
 PRIM_LENGTH= 25;{ LENGTH }
 PRIM_APPEND= 26;{ APPEND }
 PRIM_REVERSE=27;{ REVERSE }

  { ---- Limites ---- }
 MAX_SYM   = 256;  { Symboles maximum dans la table       }
 MAX_FUNC  = 64;   { Fonctions DEFUN maximum              }
 MAX_CONS  = 1024; { Cellules cons dans la m‚moire de tas }
 MAX_STR   = 256;  { Chaines litt‚rales maximum           }
 MAX_LOCAL = 32;   { Variables locales par scope          }
 MAX_DEPTH = 64;   { Profondeur maximum d'imbrication     }
 MAX_LABEL = 9999; { Limite de compteur d'‚tiquettes      }

{ ============================================================================ }
{ TYPES                                                                        }
{ ============================================================================ }

Type
 { ----- Valeur LISP encodee ----- }
 TLispVal = Word;   { 3 bits de balise + 13 bits payload }

 { ----- Cellule cons (m‚moire de tas) ----- }
 TConsCell = Record
  car_val : TLispVal;
  cdr_val : TLispVal;
 End;

  { ----- Entr‚e de la table des symboles ----- }
 TSymEntry = Record
  name       : String[48];    { Nom LISP (upper-case) }
  asm_name   : String[48];    { Nom ASM sanitise : _SYM_FACT,... }
  global_val : TLispVal;      { Valeur globale courante        }
  special    : Integer;       { SF_xxx si forme speciale       }
  prim       : Integer;       { PRIM_xxx si primitive          }
  func_idx   : Integer;       { 0 si non-fonction compilee     }
 End;
 PSymEntry = ^TSymEntry;

 { ----- Entr‚e de la table des fonctions DEFUN ----- }
 TFuncEntry = Record
  name        : String[48];
  asm_label   : String[48];   { exemple: _LISP_FACT }
  param_count : Integer;
  param_names : Array[1..MAX_LOCAL] of String[48];
  defined     : Boolean;
 End;
 PFuncEntry = ^TFuncEntry;

  { ----- Variable locale (‚tendue courant) ----- }
 TLocalEntry = Record
  name      : String[48];
  bp_offset : Integer;   { d‚placement depuis BP : -2, -4, -6... }
 End;

 { ----- ChaŒne litt‚rale interne ----- }
 TStrEntry = Record
  text     : String;
  asm_label: String[32];
 End;
 PStrEntry = ^TStrEntry;

{ ============================================================================ }
{ VARIABLES GLOBALES                                                           }
{ ============================================================================ }

Var
 { --- Fichiers --- }
 source_filename  : String;
 output_filename  : String;
 input_file       : Text;
 output_file      : Text;

 { --- Options en ligne de commande --- }
 opt_dump_tok  : Boolean;  { /T : afficher les tokens }
 opt_dump_ast  : Boolean;  { /A : afficher l'AST      }
 opt_verbose   : Boolean;  { /V : mode verbeux        }

  { --- Etat du tokeniseur --- }
 src_line      : String;   { Ligne courante lue              }
 src_line_num  : Integer;  { Num‚ro de ligne courante        }
 src_col       : Integer;  { Colonne courante (1-base)       }
 src_eof       : Boolean;  { Fin de fichier atteinte         }
 cur_tok_type  : Integer;  { TOK_xxx courant                 }
 cur_tok_str   : String;   { Texte du jeton courant          }
 cur_tok_num   : LongInt;  { Valeur num‚rique si TOK_NUMBER  }
 cur_tok_char  : Byte;     { Code ASCII si TOK_CHAR          }
 peek_char     : Char;     { Caractere en attente (PeekChar) }
 has_peek      : Boolean;  { True si peek_char valide        }

  { --- Table des symboles --- }
 sym_table     : Array[1..MAX_SYM] of PSymEntry;
 sym_count     : Integer;

 { --- Table des fonctions --- }
 func_table    : Array[1..MAX_FUNC] of PFuncEntry;
 func_count    : Integer;

 { --- M‚moire de tas de cons cells (pour AST en m‚moire Pascal) --- }
 heap_cons     : Array[1..MAX_CONS] of TConsCell;
 heap_free     : Integer;  { Prochaine cellule libre (1-base) }

 { --- ChaŒnes litt‚rales --- }
 str_table     : Array[1..MAX_STR] of PStrEntry;
 str_count     : Integer;

 { --- tendue courante (variables locales) --- }
 local_vars    : Array[1..MAX_LOCAL] of TLocalEntry;
 local_count   : Integer;
 local_bp_top  : Integer;   { Prochain d‚placement BP (n‚gatif : -2, -4...) }
 in_func       : Boolean;   { True si on compile l'int‚rieur d'un DEFUN     }
 cur_func_name : String;    { Nom de la fonction en cours                   }

 { --- G‚nerateur de code --- }
 label_counter : Integer;
 lit_counter   : Integer;
 gen_enabled   : Boolean;
 error_count   : Integer;

{ ============================================================================ }
{ PROTOTYPES ANTICIPES                                                         }
{ ============================================================================ }

{ D‚clarations FORWARD pour proc‚dures mutuellement d‚pendantes }
Procedure NextToken; Forward;
Function AddSymbol(Const name: String): Integer; Forward;

{ ============================================================================ }
{ Architecture + utilitaires de base                                           }
{ ============================================================================ }

Function ItoS(n: LongInt): String;
Var s: String;
Begin
 Str(n, s);
 ItoS := s;
End;

Function ItoSI(n: Integer): String;
Var s: String;
Begin
 Str(n, s);
 ItoSI := s;
End;

Function UpCaseStr(Const s: String): String;
Var
 i: Integer;
 r: String;
Begin
 r := s;
 For i := 1 to Length(r) do If (r[i] >= 'a') And (r[i] <= 'z') Then r[i] := Chr(Ord(r[i]) - 32);
 UpCaseStr := r;
End;

Function AsmStr(Const s: String): String;
Var
 i: Integer;
 r: String;
Begin
 r := '';
 For i := 1 to Length(s) do
  If s[i] = '''' Then r := r + ''''''
  Else r := r + s[i];
 AsmStr := r;
End;

 { Sanitise un nom LISP en ‚tiquette ASM valide }
Function SymToAsm(Const name: String): String;
Var
 i: Integer;
 r: String;
Begin
 r := '_SYM_';
 For i := 1 to Length(name) do
  Case name[i] Of
   'A'..'Z','0'..'9','_': r := r + name[i];
   'a'..'z': r := r + Chr(Ord(name[i]) - 32);
   '-': r := r + '_';
   '+': r := r + 'PLUS';
   '*': r := r + 'STAR';
   '/': r := r + 'SLASH';
   '<': r := r + 'LT';
   '>': r := r + 'GT';
   '=': r := r + 'EQ';
   '?': r := r + 'P';    { pr‚dicats LISP finissent souvent par ? }
   '!': r := r + 'E';
  Else r := r + 'X';
  End;
 SymToAsm := r;
End;

Function FuncToAsm(Const name: String): String;
Var
 i: Integer;
 r: String;
Begin
 r := '_LISP_';
 For i := 1 to Length(name) do
  Case name[i] Of
   'A'..'Z','0'..'9': r := r + name[i];
   'a'..'z': r := r + Chr(Ord(name[i]) - 32);
   '-': r := r + '_';
   '*': r := r + 'S';
   '/': r := r + 'D';
  Else r := r + 'X';
  End;
 FuncToAsm := r;
End;

Procedure Error(Const msg: String);Begin
 WriteLn('ERREUR (ligne ', src_line_num, ') : ', msg);
 Inc(error_count);
End;

Procedure Warning(Const msg: String);Begin
 WriteLn('ATTENTION (ligne ', src_line_num, ') : ', msg);
End;

{ ============================================================================ }
{ TOKENISEUR LISP                                                              }
{ ============================================================================ }

{ ---- Assistants de lecture caractŠres depuis fichier texte ---- }

Function SrcGetChar:Char;Begin
 If has_peek Then Begin
  SrcGetChar := peek_char;
  has_peek := False;
  Exit;
 End;
 If src_eof Then Begin
  SrcGetChar := #0;
  Exit;
 End;
 While (src_col > Length(src_line)) And Not src_eof Do Begin
  If EOF(input_file) Then Begin
   src_eof := True;
   SrcGetChar := #0;
   Exit;
  End;
  ReadLn(input_file, src_line);
  Inc(src_line_num);
  src_col := 1;
  SrcGetChar := ' ';  { Traiter saut de ligne comme espace }
  Exit;
 End;
 SrcGetChar := src_line[src_col];
 Inc(src_col);
End;

Function SrcPeekChar: Char;
Var
 ch: Char;
Begin
 If has_peek Then Begin
  SrcPeekChar := peek_char;
  Exit;
 End;
 ch := SrcGetChar;
 If ch = #0 Then Begin
  SrcPeekChar := #0;
  Exit;
 End;
 has_peek := True;
 peek_char := ch;
 SrcPeekChar := ch;
End;

Procedure InitTokenizer;Begin
 src_line_num := 0;
 src_col      := 1;
 src_eof      := False;
 has_peek     := False;
 peek_char    := #0;
 cur_tok_type := TOK_UNKNOWN;
 cur_tok_str  := '';
 cur_tok_num  := 0;
 cur_tok_char := 0;
 src_line     := '';
 If EOF(input_file) Then src_eof := True
  Else
 Begin
  ReadLn(input_file, src_line);
  src_line_num := 1;
  src_col := 1;
 End;
 NextToken;
End;

Procedure NextToken;
Var
 c, c2: Char;
 neg: Boolean;
 n: LongInt;
 s: String;
 esc: Boolean;
Begin
 cur_tok_str := ''; cur_tok_num := 0; cur_tok_char := 0;
 { 1. Sauter espaces, tabulations et commentaires LISP (;) }
 Repeat
  c := SrcPeekChar;
  If c = #0 Then Break;
  If c = ';' Then Begin
   has_peek := False;
   src_col := Length(src_line) + 1;
  End
   Else
  If (c = ' ') Or (c = #9) Or (c = #13) Or (c = #10) Then SrcGetChar
                                                     Else Break;
 Until False;
 If SrcPeekChar = #0 Then Begin
  cur_tok_type := TOK_EOF;
  cur_tok_str := 'EOF';
  Exit;
 End;
  { 2. Lire le prochain caractere significatif }
 c := SrcGetChar;
 Case c Of
  '(':  Begin
   cur_tok_type := TOK_LPAREN;
   cur_tok_str := '(';
  End;
  ')':  Begin
   cur_tok_type := TOK_RPAREN;
   cur_tok_str := ')';
  End;
  '''': Begin
   cur_tok_type := TOK_QUOTE;
   cur_tok_str := '''';
  End;
  '`': Begin
   cur_tok_type := TOK_BQUOTE;
   cur_tok_str := '`';
  End;
  ',': Begin
   If SrcPeekChar = '@' Then Begin
    SrcGetChar;
    cur_tok_type := TOK_COMMA_AT;
    cur_tok_str := ',@';
   End
    Else
   Begin
    cur_tok_type := TOK_COMMA;
    cur_tok_str := ',';
   End;
  End;
  '"': Begin
         s := '';
         esc := False;
         Repeat
          c2 := SrcGetChar;
          If c2 = #0 Then Break;
          If esc Then
          Begin
           Case c2 Of
            'n': s := s + #10;
            't': s := s + #9;
            '\': s := s + '\';
            '"': s := s + '"';
           Else  s := s + c2;
           End;
           esc := False;
          End
           Else
          If c2 = '\' Then esc := True Else
          If c2 = '"' Then Break
                      Else s := s + c2;
         Until False;
         cur_tok_type := TOK_STRING; cur_tok_str := s;
        End;
  '#':  Begin
         c2 := SrcGetChar;
         If UpCase(c2) = 'T' Then Begin
          cur_tok_type := TOK_HASH_T;
          cur_tok_str := '#T';
         End
          Else
         If UpCase(c2) = 'F' Then Begin
          cur_tok_type := TOK_HASH_F;
          cur_tok_str := '#F';
         End
          Else
         If c2 = '\' Then Begin
          c2 := SrcGetChar;
          cur_tok_type := TOK_CHAR; cur_tok_char := Ord(c2);
         cur_tok_str := '#' + c2;
         End
          Else
         Begin
          s := '#' + UpCase(c2);
          Repeat
           c2 := SrcPeekChar;
           If (c2 = #0) Or (c2 = ' ') Or (c2 = #9) Or
              (c2 = '(') Or (c2 = ')') Or (c2 = '"') Or (c2 = ';') Then Break;
           s := s + UpCase(SrcGetChar);
          Until False;
          cur_tok_type := TOK_ATOM; cur_tok_str := s;
         End;
        End;
 Else
  { Nombre ou atome }
  neg := False;
  If (c = '+') Or (c = '-') Then Begin
   If (SrcPeekChar >= '0') And (SrcPeekChar <= '9') Then Begin
    neg := (c = '-');
    c := SrcGetChar; n := Ord(c) - 48;
    While (SrcPeekChar >= '0') And (SrcPeekChar <= '9') Do
     n := n * 10 + (Ord(SrcGetChar) - 48);
    If neg Then n := -n;
    cur_tok_type := TOK_NUMBER; cur_tok_num := n;
    cur_tok_str := ItoS(n); Exit;
   End;
  End;
  If (c >= '0') And (c <= '9') Then Begin
   n := Ord(c) - 48;
   While (SrcPeekChar >= '0') And (SrcPeekChar <= '9') Do
    n := n * 10 + (Ord(SrcGetChar) - 48);
   cur_tok_type := TOK_NUMBER; cur_tok_num := n;
   cur_tok_str := ItoS(n); Exit;
  End;
   { Atome : lire jusqu'au prochain delimiteur }
  s := UpCase(c);
  Repeat
   c2 := SrcPeekChar;
   If (c2 = #0) Or (c2 = ' ') Or (c2 = #9) Or (c2 = #13) Or (c2 = #10) Or
      (c2 = '(') Or (c2 = ')') Or (c2 = '"') Or (c2 = ';') Then Break;
   s := s + UpCase(SrcGetChar);
  Until False;
  cur_tok_type := TOK_ATOM; cur_tok_str := s;
 End;
End;

Function TokenIs(Const s: String): Boolean;Begin
 TokenIs := cur_tok_str = UpCaseStr(s);
End;

Procedure Consume;Begin
 NextToken;
End;

{ ============================================================================ }
{ TABLE DES SYMBOLES                                                           }
{ ============================================================================ }

 { Enregistrer un symbole built-in avec ses attributs }
Procedure RegSym(Const name: String; sf, prim: Integer);
Var
 idx: Integer;
Begin
 idx := AddSymbol(name);
 If idx > 0 Then Begin
  sym_table[idx]^.special := sf;
  sym_table[idx]^.prim    := prim;
  If name = 'T' Then sym_table[idx]^.global_val := LVAL_T
  Else sym_table[idx]^.global_val := LVAL_NIL;
 End;
End;

Procedure InitSymbolTable;Begin
 sym_count := 0;
 { Atomes constants }
 RegSym('NIL',      SF_NONE,    PRIM_NONE   );
 RegSym('T',        SF_NONE,    PRIM_NONE   );
 { Formes speciales }
 RegSym('QUOTE',    SF_QUOTE,   PRIM_NONE   );
 RegSym('IF',       SF_IF,      PRIM_NONE   );
 RegSym('COND',     SF_COND,    PRIM_NONE   );
 RegSym('SETQ',     SF_SETQ,    PRIM_NONE   );
 RegSym('SETF',     SF_SETF,    PRIM_NONE   );
 RegSym('PROGN',    SF_PROGN,   PRIM_NONE   );
 RegSym('LET',      SF_LET,     PRIM_NONE   );
 RegSym('LET*',     SF_LETSTAR, PRIM_NONE   );
 RegSym('AND',      SF_AND,     PRIM_NONE   );
 RegSym('OR',       SF_OR,      PRIM_NONE   );
 RegSym('NOT',      SF_NOT,     PRIM_NOT    );
 RegSym('WHEN',     SF_WHEN,    PRIM_NONE   );
 RegSym('UNLESS',   SF_UNLESS,  PRIM_NONE   );
 RegSym('DEFUN',    SF_DEFUN,   PRIM_NONE   );
 RegSym('DEFVAR',   SF_DEFVAR,  PRIM_NONE   );
 RegSym('DEFCONST', SF_DEFCONST,PRIM_NONE   );
 RegSym('LAMBDA',   SF_LAMBDA,  PRIM_NONE   );
 RegSym('DO',       SF_DO,      PRIM_NONE   );
 RegSym('LOOP',     SF_LOOP,    PRIM_NONE   );
 RegSym('RETURN',   SF_RETURN,  PRIM_NONE   );
 RegSym('MAPCAR',   SF_MAPCAR,  PRIM_NONE   );
 RegSym('APPLY',    SF_APPLY,   PRIM_NONE   );
 RegSym('FUNCALL',  SF_FUNCALL, PRIM_NONE   );
 { Primitives arithmetiques }
 RegSym('+',        SF_NONE,    PRIM_ADD    );
 RegSym('-',        SF_NONE,    PRIM_SUB    );
 RegSym('*',        SF_NONE,    PRIM_MUL    );
 RegSym('/',        SF_NONE,    PRIM_DIV    );
 RegSym('=',        SF_NONE,    PRIM_EQ     );
 RegSym('<',        SF_NONE,    PRIM_LT     );
 RegSym('>',        SF_NONE,    PRIM_GT     );
 RegSym('<=',       SF_NONE,    PRIM_LE     );
 RegSym('>=',       SF_NONE,    PRIM_GE     );
 RegSym('/=',       SF_NONE,    PRIM_NEQ    );
 RegSym('EQ',       SF_NONE,    PRIM_EQP    );
 RegSym('EQUAL',    SF_NONE,    PRIM_EQUAL  );
 { Primitives sur les listes }
 RegSym('CAR',      SF_NONE,    PRIM_CAR    );
 RegSym('CDR',      SF_NONE,    PRIM_CDR    );
 RegSym('CONS',     SF_NONE,    PRIM_CONS   );
 RegSym('LIST',     SF_NONE,    PRIM_LIST   );
 RegSym('ATOM',     SF_NONE,    PRIM_ATOM   );
 RegSym('NULL',     SF_NONE,    PRIM_NULL   );
 { Entr‚es/Sorties }
 RegSym('PRINT',    SF_NONE,    PRIM_PRINT  );
 RegSym('WRITE',    SF_NONE,    PRIM_WRITE  );
 RegSym('READ',     SF_NONE,    PRIM_READ   );
 RegSym('TERPRI',   SF_NONE,    PRIM_TERPRI );
 RegSym('LENGTH',   SF_NONE,    PRIM_LENGTH );
 RegSym('APPEND',   SF_NONE,    PRIM_APPEND );
 RegSym('REVERSE',  SF_NONE,    PRIM_REVERSE);
End;

Function FindSymbol(Const name: String): Integer;
Var
 i: Integer;
 u: String;
Begin
 u := UpCaseStr(name);
 For i := 1 to sym_count do If sym_table[i]^.name = u Then Begin
  FindSymbol := i;
  Exit;
 End;
 FindSymbol := 0;
End;

Function AddSymbol(Const name: String): Integer;
Var
 p: PSymEntry;
 u: String;
 existing: Integer;
Begin
 u := UpCaseStr(name);
 existing := FindSymbol(u);
 If existing > 0 Then Begin
  AddSymbol := existing;
  Exit;
 End;
 If sym_count >= MAX_SYM Then Begin
  Error('Table des symboles pleine');
  AddSymbol := 0;
  Exit;
 End;
 New(p);
 p^.name       := u;
 p^.asm_name   := SymToAsm(u);
 p^.global_val := LVAL_NIL;
 p^.special    := SF_NONE;
 p^.prim       := PRIM_NONE;
 p^.func_idx   := 0;
 Inc(sym_count);
 sym_table[sym_count] := p;
 AddSymbol := sym_count;
End;

{ ============================================================================ }
{ REPRESENTATION INTERNE DES S-EXPRESSIONS                                     }
{ ============================================================================ }

Procedure InitHeap;Begin
  { Initialiser la m‚moire de tas de cons cells }
 heap_free := 1;
 FillChar(heap_cons, SizeOf(heap_cons), 0);
End;

Function MakeNil: TLispVal;Begin
 MakeNil := LVAL_NIL;
End;

Function MakeT: TLispVal;Begin
 MakeT := LVAL_T;
End;

Function MakeFix(n: Integer): TLispVal;Begin
 { Encoder un entier en LTAG_FIXNUM }
 { LTAG_FIXNUM = 2 = 010 en binaire => d‚calage vers la gauche 13 = $4000 }
 { payload = n AND $1FFF (13 bits, attention au signe)                    }
 MakeFix := ((LTAG_FIXNUM Shl LTAG_SHIFT) Or (n And LPAY_MASK));
End;

Function MakeSym(idx: Integer): TLispVal;Begin
 MakeSym := ((LTAG_SYM Shl LTAG_SHIFT) Or (idx And LPAY_MASK));
End;

Function MakeCons(car_v, cdr_v: TLispVal): TLispVal;
Var
 idx: Integer;
Begin
 { Allouer une cons cell dans heap_cons }
 If heap_free > MAX_CONS Then Begin
  Error('Tas LISP plein');
  MakeCons := LVAL_NIL;
  Exit;
 End;
 idx := heap_free;
 heap_cons[idx].car_val := car_v;
 heap_cons[idx].cdr_val := cdr_v;
 Inc(heap_free);
 MakeCons := ((LTAG_CONS Shl LTAG_SHIFT) Or (idx And LPAY_MASK));
End;

Function MakeStr(Const s: String): TLispVal;
Var
 p: PStrEntry;
 lbl: String;
 idx: Integer;
Begin
  { Enregistrer une chaine dans str_table }
 If str_count >= MAX_STR Then Begin
  Error('Trop de chaines');
  MakeStr := LVAL_NIL;
  Exit;
 End;
 Inc(str_count);
 Inc(lit_counter);
 lbl := '_LS' + ItoSI(lit_counter);
 New(p);
 p^.text      := s;
 p^.asm_label := lbl;
 str_table[str_count] := p;
 MakeStr := ((LTAG_STR Shl LTAG_SHIFT) Or (str_count And LPAY_MASK));
End;

Function TagOf(v: TLispVal): Byte;Begin
 TagOf := (v Shr LTAG_SHIFT) And 7;
End;

Function PayOf(v: TLispVal): Integer;
Var
 p: Integer;
Begin
 p := v And LPAY_MASK;
  { Extension de signe sur 13 bits si FIXNUM }
 If (TagOf(v) = LTAG_FIXNUM) And (p And $1000 <> 0) Then p := p Or (not LPAY_MASK);
 PayOf := p;
End;

Function IsNilVal(v: TLispVal): Boolean;Begin
 IsNilVal := (v = LVAL_NIL);
End;

Function IsTVal(v: TLispVal): Boolean;Begin
 IsTVal := (TagOf(v) = LTAG_T);
End;

Function CarOf(v: TLispVal): TLispVal;Begin
 If TagOf(v) = LTAG_CONS Then CarOf := heap_cons[PayOf(v)].car_val
  Else
 Begin
  Error('CAR d''un non-cons');
  CarOf := LVAL_NIL;
 End;
End;

Function CdrOf(v: TLispVal): TLispVal;Begin
 If TagOf(v) = LTAG_CONS Then CdrOf := heap_cons[PayOf(v)].cdr_val
  Else
 Begin
  Error('CDR d''un non-cons');
  CdrOf := LVAL_NIL;
 End;
End;

{ ============================================================================ }
{ LECTEUR DE S-EXPRESSIONS                                                     }
{ ============================================================================ }

Function ReadExpr: TLispVal; Forward;

Function ReadList: TLispVal;
Var
 head_v, tail_v, elem_v, cell_v: TLispVal;
Begin
  { Construction it‚rative de la liste, ‚vite les problŠmes de r‚cursion }
 head_v := LVAL_NIL;
 tail_v := LVAL_NIL;
 Repeat
  If cur_tok_type = TOK_RPAREN Then Begin
   Consume;
   Break;
  End;
  If cur_tok_type = TOK_EOF Then Begin
   Error('EOF inattendu dans la liste');
   Break;
  End;
  elem_v := ReadExpr;
  cell_v := MakeCons(elem_v, LVAL_NIL);
  If IsNilVal(head_v) Then Begin
   head_v := cell_v;
   tail_v := cell_v;
  End
   Else
  Begin
   heap_cons[PayOf(tail_v)].cdr_val := cell_v;
   tail_v := cell_v;
  End;
 Until False;
 ReadList := head_v;
End;

Function ReadExpr: TLispVal;
Var
 sym_idx, q_idx: Integer;
 inner: TLispVal;
Begin
 Case cur_tok_type Of
  TOK_EOF:
   ReadExpr := LVAL_NIL;
  TOK_LPAREN:
  Begin
   Consume;
   ReadExpr := ReadList;
  End;
  TOK_RPAREN:
  Begin
   Error('Parenthese fermante inattendue');
   Consume;
   ReadExpr := LVAL_NIL;
  End;
  TOK_QUOTE:
  Begin
   Consume; inner := ReadExpr;
   q_idx   := FindSymbol('QUOTE');
   ReadExpr := MakeCons(MakeSym(q_idx), MakeCons(inner, LVAL_NIL));
  End;
  TOK_BQUOTE: { Traiter backquote comme QUOTE (simplifie) }
  Begin
   Consume; inner := ReadExpr;
   q_idx   := FindSymbol('QUOTE');
   ReadExpr := MakeCons(MakeSym(q_idx), MakeCons(inner, LVAL_NIL));
  End;
  TOK_ATOM:
  Begin
   sym_idx  := AddSymbol(cur_tok_str);
   Consume;
   ReadExpr := MakeSym(sym_idx);
  End;
  TOK_NUMBER:
  Begin
   inner    := MakeFix(cur_tok_num);
   Consume;
   ReadExpr := inner;
  End;
  TOK_STRING:
  Begin
   inner    := MakeStr(cur_tok_str);
   Consume;
   ReadExpr := inner;
  End;
  TOK_HASH_T: Begin Consume; ReadExpr := MakeT;   End;
  TOK_HASH_F: Begin Consume; ReadExpr := MakeNil; End;
  TOK_CHAR:
  Begin
   inner    := MakeFix(cur_tok_char);
   Consume;
   ReadExpr := inner;
  End;
 Else
  Consume;
  ReadExpr := LVAL_NIL;
 End;
End;

{ ============================================================================ }
{ RECONNAISSANCE DES FORMES SPECIALES                                          }
{ ============================================================================ }

Function GetSpecialForm(sym_idx: Integer): Integer;Begin
 { Retourner SF_xxx du symbole si c'est une forme sp‚ciale }
 If (sym_idx < 1) Or (sym_idx > sym_count) Then Begin
  GetSpecialForm := SF_NONE;
  Exit;
 End;
 GetSpecialForm := sym_table[sym_idx]^.special;
End;

Function GetPrim(sym_idx: Integer): Integer;Begin
 { Retourner PRIM_xxx du symbole si c'est une primitive }
 If (sym_idx < 1) Or (sym_idx > sym_count) Then
  Begin GetPrim := PRIM_NONE; Exit; End;
 GetPrim := sym_table[sym_idx]^.prim;
End;

{ ============================================================================ }
{ TABLE DES FONCTIONS DEFUN                                                    }
{ ============================================================================ }

Procedure InitFuncTable;Begin
 func_count := 0;
 FillChar(func_table, SizeOf(func_table), 0);
End;

Function FindFunc(Const name: String): Integer;
Var
 i: Integer;
 u: String;
Begin
 u := UpCaseStr(name);
 For i := 1 to func_count do If func_table[i]^.name = u Then Begin
  FindFunc := i;
  Exit;
 End;
 FindFunc := 0;
End;

Function AddFunc(Const name: String; nparams: Integer): Integer;
Var
 p: PFuncEntry;
 u: String;
 existing: Integer;
Begin
 u := UpCaseStr(name);
 existing := FindFunc(u);
 If existing > 0 Then Begin
  AddFunc := existing;
  Exit;
 End;
 If func_count >= MAX_FUNC Then Begin
  Error('Table des fonctions pleine');
  AddFunc := 0;
  Exit;
 End;
 Inc(func_count);
 New(p);
 p^.name        := u;
 p^.asm_label   := FuncToAsm(u);
 p^.param_count := nparams;
 p^.defined     := False;
 func_table[func_count] := p;
 AddFunc := func_count;
End;

Function FuncAsmLabel(idx: Integer):String;Begin
 If (idx < 1) Or (idx > func_count) Then FuncAsmLabel := '_UNDEF_'
 Else FuncAsmLabel := func_table[idx]^.asm_label;
End;

{ ============================================================================ }
{ VARIABLES LOCALES (ETENDUE)                                                  }
{ ============================================================================ }

Procedure EnterScope;Begin
 { Sauvegarder le contexte local courant }
 local_count  := 0;
 local_bp_top := 0;
End;

Procedure LeaveScope;Begin
 { Restaurer le contexte local }
 local_count  := 0;
 local_bp_top := 0;
End;

Function FindLocal(Const name: String): Integer;
Var
 i: Integer;
 u: String;
Begin
 u := UpCaseStr(name);
 For i := local_count DownTo 1 do If local_vars[i].name = u Then Begin
  FindLocal := i;
  Exit;
 End;
 FindLocal := 0;
End;

Function AddLocal(Const name: String): Integer;Begin
 { Ajouter une variable locale et lui assigner un d‚placement BP }
 If local_count >= MAX_LOCAL Then Begin
  Error('Trop de variables locales');
  AddLocal := 0;
  Exit;
 End;
 Inc(local_count);
 Dec(local_bp_top, 2);  { -2, -4, -6... }
 local_vars[local_count].name      := UpCaseStr(name);
 local_vars[local_count].bp_offset := local_bp_top;
 AddLocal := local_count;
End;

{ ============================================================================ }
{ PRIMITIVES D'EMISSION ASM                                                    }
{ ============================================================================ }

Procedure Emit(Const s: String);Begin
 If gen_enabled Then WriteLn(output_file, s);
End;

Procedure EmitLabel(Const lbl: String);Begin
 If gen_enabled Then WriteLn(output_file, lbl, ':');
End;

Procedure EmitComment(Const s: String);Begin
 If gen_enabled Then WriteLn(output_file, '        ; ', s);
End;

Procedure EmitBlank;Begin
 If gen_enabled Then WriteLn(output_file);
End;

Function NewLabel: String;
Var
 s: String;
Begin
 Inc(label_counter);
 s := ItoSI(label_counter);
 While Length(s) < 4 do s := '0' + s;
 NewLabel := '_L' + s;
End;

{ ============================================================================ }
{ GENERATION : EN-TETE + SEGMENT .DATA                                         }
{ ============================================================================ }

Procedure GenDataSegment;
Var
 i: Integer;
Begin
 Emit('.DATA');
 EmitBlank;
 EmitComment('=== Buffers internes LISP86 ===');
 Emit('    _CRLF      DB  13, 10, ''$''');
 Emit('    _NUMBUF    DB  20 DUP(30h), ''$''');
 Emit('    _INPUTBUF  DB  82, 0, 80 DUP(0)');
 Emit('    _NIL_STR   DB  ''NIL'', ''$''');
 Emit('    _T_STR     DB  ''T'', ''$''');
 Emit('    _ERR_STR   DB  ''ERREUR LISP'', ''$''');
 Emit('    _HEAP_CAR  DW  ' + ItoSI(MAX_CONS) + ' DUP(0)');
 Emit('    _HEAP_CDR  DW  ' + ItoSI(MAX_CONS) + ' DUP(0)');
 Emit('    _FREE_PTR  DW  1');
 EmitBlank;
 EmitComment('=== Variables globales des symboles LISP ===');
 For i := 1 to MAX_SYM do Emit('    _GV_SYM' + ItoSI(i) + '  DW  0');
 EmitBlank;
End;

Procedure GenHeader;Begin
 Emit('; ----------------------------------------------------------------');
 Emit('; G‚n‚r‚ par LISP86 V1.0');
 Emit('; Source  : ' + source_filename);
 Emit('; ----------------------------------------------------------------');
 EmitBlank;
 Emit('        .MODEL SMALL');
 Emit('        .STACK 256');
 EmitBlank;
 GenDataSegment;
 EmitBlank;
End;

{ ============================================================================ }
{ GENERATION : POINT D'ENTREE + CONVENTION D'APPEL                             }
{ ============================================================================ }

Procedure GenCodeSegmentHeader;Begin
 Emit('.CODE');
 EmitBlank;
 Emit('START:');
 Emit('        MOV     AX, @DATA');
 Emit('        MOV     DS, AX');
 Emit('        MOV     ES, AX');
 EmitBlank;
 EmitComment('Appel de la fonction principale LISP (MAIN)');
 Emit('        CALL    _LISP_MAIN');
 Emit('        MOV     AX, 4C00h');
 Emit('        INT     21h');
 EmitBlank;
End;

Procedure GenFooter;Begin
 EmitBlank;
 Emit('END START');
End;

{ ============================================================================ }
{ GENERATION : EVALUATION D'UN ATOME                                           }
{ ============================================================================ }

Procedure GenExpr(v: TLispVal); Forward;

Procedure GenEvalAtom(v: TLispVal);
Var
 sym_idx, loc_idx: Integer;
Begin
 sym_idx := PayOf(v);
 { G‚n‚rer le code pour charger un atome dans AX / BX }
 Case TagOf(v) Of
  LTAG_NIL:
  Begin
   EmitComment('NIL');
   Emit('        XOR     AX, AX');
  End;
  LTAG_T:
  Begin
   EmitComment('T');
   Emit('        MOV     AX, ' + ItoSI(LVAL_T));
  End;
  LTAG_FIXNUM:
  Begin
   EmitComment('FIXNUM ' + ItoSI(PayOf(v)));
   Emit('        MOV     BX, ' + ItoSI(PayOf(v)));
   Emit('        MOV     AX, ' + ItoSI(v));
  End;
  LTAG_SYM:
  Begin
   { Chercher d'abord dans les variables locales (parametres + LET), sinon global }
   If (sym_idx > 0) And (sym_idx <= sym_count) Then
    loc_idx := FindLocal(sym_table[sym_idx]^.name)
   Else loc_idx := 0;
   If loc_idx > 0 Then
   Begin
    EmitComment('LOCAL ' + sym_table[sym_idx]^.name);
    If local_vars[loc_idx].bp_offset >= 0 Then
     Emit('        MOV     AX, [BP+' + ItoSI(local_vars[loc_idx].bp_offset) + ']')
    Else
     Emit('        MOV     AX, [BP' + ItoSI(local_vars[loc_idx].bp_offset) + ']');
   End Else
   Begin
    EmitComment('GLOBAL SYM ' + ItoSI(sym_idx));
    Emit('        MOV     AX, [_GV_SYM' + ItoSI(sym_idx) + ']');
   End;
  End;
  LTAG_STR:
  Begin
   EmitComment('STRING ' + ItoSI(PayOf(v)));
   Emit('        MOV     AX, ' + ItoSI(v));
  End;
 Else
  EmitComment('GenEvalAtom: tag non supporte ' + ItoSI(TagOf(v)));
  Emit('        XOR     AX, AX');
 End;
End;

{ ============================================================================ }
{ GENERATION : QUOTE                                                           }
{ ============================================================================ }

Procedure GenQuote(expr: TLispVal);Begin
 { G‚n‚rer du code pour une forme QUOTE }
 { Si expr est NIL / T / FIXNUM / SYM -> GenEvalAtom (valeur litterale)  }
 { Si expr est une cons cell :                                             }
 {   Emettre les paires CAR/CDR en DATA (chaine imbriquee), retourner     }
 {   l'index de la premiŠre cons cell balis‚ LTAG_CONS via MOV AX, $8xxx  }
 Case TagOf(expr) Of
  LTAG_NIL, LTAG_T, LTAG_FIXNUM, LTAG_STR:
   GenEvalAtom(expr);
  LTAG_SYM:
  Begin
   EmitComment('QUOTE SYM');
   Emit('        MOV     AX, ' + ItoSI(expr));
  End;
  LTAG_CONS:
  Begin
   EmitComment('QUOTE list (TODO 13 : construire en DATA)');
   Emit('        MOV     AX, ' + ItoSI(expr)); { stub }
  End;
 Else
  EmitComment('QUOTE <inconnu>');
  Emit('        XOR     AX, AX');
 End;
End;

{ ============================================================================ }
{ GENERATION : SETQ / SETF                                                     }
{ ============================================================================ }

Procedure GenSetq(sym_idx: Integer; val_expr: TLispVal);Begin
 { Compiler val_expr -> AX, puis entreposer dans variable }
 GenExpr(val_expr);
 If sym_idx > 0 Then Begin
   { Chercher local d'abord }
  If FindLocal(sym_table[sym_idx]^.name) > 0 Then Begin
   EmitComment('SETQ local ' + sym_table[sym_idx]^.name);
   Emit('        MOV     [BP' + ItoSI(local_vars[FindLocal(sym_table[sym_idx]^.name)].bp_offset) + '], AX');
  End
   Else
  Begin
   EmitComment('SETQ global ' + sym_table[sym_idx]^.name);
   Emit('        MOV     [_GV_SYM' + ItoSI(sym_idx) + '], AX');
  End;
 End
  Else
 EmitComment('SETQ : symbole inconnu');
End;

{ ============================================================================ }
{ GENERATION : IF / COND / WHEN / UNLESS                                       }
{ ============================================================================ }

Procedure GenIf(test_e, then_e, else_e: TLispVal);
Var
 lbl_else, lbl_end: String;
Begin
 { Generer IF }
 lbl_else := NewLabel + 'IE';
 lbl_end  := NewLabel + 'IF';
 EmitComment('---- IF ----');
 GenExpr(test_e);
 Emit('        TEST    AX, AX');
 Emit('        JZ      ' + lbl_else);
 GenExpr(then_e);
 Emit('        JMP     ' + lbl_end);
 EmitLabel(lbl_else);
 If Not IsNilVal(else_e) Then GenExpr(else_e)
                         Else Emit('        XOR     AX, AX  ; else=NIL');
 EmitLabel(lbl_end);
End;

Procedure GenCond(clauses: TLispVal);
Var
 lbl_end, lbl_next: String;
 clause, test_e, body_e: TLispVal;
Begin
 { Generer COND }
 lbl_end := NewLabel + 'CF';
 EmitComment('---- COND ----');
 While Not IsNilVal(clauses) Do Begin
  clause  := CarOf(clauses);
  test_e  := CarOf(clause);
  body_e  := CdrOf(clause);
  lbl_next := NewLabel + 'CN';
  If (TagOf(test_e) = LTAG_SYM) And (test_e = MakeSym(FindSymbol('T'))) Then Begin
   EmitComment('COND OTHERWISE (T)');
   If Not IsNilVal(body_e) Then GenExpr(CarOf(body_e));
   Emit('        JMP     ' + lbl_end);
  End
   Else
  Begin
   GenExpr(test_e);
   Emit('        TEST    AX, AX');
   Emit('        JZ      ' + lbl_next);
   If Not IsNilVal(body_e) Then GenExpr(CarOf(body_e))
   Else Emit('        ; clause sans corps -> retourner test');
   Emit('        JMP     ' + lbl_end);
   EmitLabel(lbl_next);
  End;
  clauses := CdrOf(clauses);
 End;
 Emit('        XOR     AX, AX  ; COND: aucune clause vraie -> NIL');
 EmitLabel(lbl_end);
End;

{ ============================================================================ }
{ GENERATION : PROGN                                                           }
{ ============================================================================ }

Procedure GenProgn(exprs: TLispVal);Begin
 { Compiler une sequence d'expressions }
 { R‚sultat de AX = dernier ‚l‚ment }
 EmitComment('---- PROGN ----');
 If IsNilVal(exprs) Then Begin Emit('        XOR     AX, AX'); Exit; End;
 While Not IsNilVal(exprs) Do
 Begin
  GenExpr(CarOf(exprs));
  exprs := CdrOf(exprs);
  { Si ce n'est pas le dernier, ignorer AX (les effets de bord restent) }
 End;
End;

{ ============================================================================ }
{ GENERATION : OPERATIONS ARITHMETIQUES                                        }
{ ============================================================================ }

Procedure GenArith(op: Integer; args: TLispVal);
Var
 first: Boolean; lbl: String;
Begin
 { G‚n‚rer +, -, *, / }
 EmitComment('---- ARITH ' + ItoSI(op) + ' ----');
 first := True;
 Case op Of
  PRIM_ADD:
  Begin
   Emit('        XOR     BX, BX  ; accumulateur +');
   While Not IsNilVal(args) Do
   Begin
    GenExpr(CarOf(args));
    EmitComment('BX = payload FIXNUM de AX');
    Emit('        AND     AX, 1FFFh');
    Emit('        ADD     BX, AX');
    args := CdrOf(args);
   End;
   Emit('        MOV     AX, BX');
   Emit('        OR      AX, ' + ItoSI(LTAG_FIXNUM Shl LTAG_SHIFT));
  End;
  PRIM_SUB:
  Begin
   If IsNilVal(args) Then Begin
    Emit('        XOR     AX, AX');
    Exit;
   End;
   GenExpr(CarOf(args));
   Emit('        AND     AX, 1FFFh');
   Emit('        MOV     BX, AX');
   args := CdrOf(args);
   If IsNilVal(args) Then { negation unaire }
   Begin
    Emit('        NEG     BX');
    Emit('        MOV     AX, BX');
    Emit('        AND     AX, 1FFFh');
    Emit('        OR      AX, ' + ItoSI(LTAG_FIXNUM Shl LTAG_SHIFT));
    Exit;
   End;
   While Not IsNilVal(args) Do
   Begin
    Emit('        PUSH    BX');
    GenExpr(CarOf(args));
    Emit('        AND     AX, 1FFFh');
    Emit('        POP     BX');
    Emit('        SUB     BX, AX');
    args := CdrOf(args);
   End;
   Emit('        MOV     AX, BX');
   Emit('        AND     AX, 1FFFh');
   Emit('        OR      AX, ' + ItoSI(LTAG_FIXNUM Shl LTAG_SHIFT));
  End;
  PRIM_MUL:
  Begin
   Emit('        MOV     BX, 1  ; accumulateur *');
   While Not IsNilVal(args) Do Begin
    GenExpr(CarOf(args));
    Emit('        AND     AX, 1FFFh');
    Emit('        IMUL    BX');
    Emit('        MOV     BX, AX');
    args := CdrOf(args);
   End;
   Emit('        MOV     AX, BX');
   Emit('        AND     AX, 1FFFh');
   Emit('        OR      AX, ' + ItoSI(LTAG_FIXNUM Shl LTAG_SHIFT));
  End;
  PRIM_DIV:
  Begin
   If IsNilVal(args) Then Begin
    Emit('        XOR     AX, AX');
    Exit;
   End;
   GenExpr(CarOf(args));
   Emit('        AND     AX, 1FFFh');
   Emit('        MOV     BX, AX');
   args := CdrOf(args);
   While Not IsNilVal(args) Do Begin
    Emit('        PUSH    BX');
    GenExpr(CarOf(args));
    Emit('        AND     AX, 1FFFh');
    Emit('        MOV     CX, AX');
    Emit('        POP     AX');
    Emit('        XOR     DX, DX');
    Emit('        IDIV    CX');
    Emit('        MOV     BX, AX');
    args := CdrOf(args);
   End;
   Emit('        MOV     AX, BX');
   Emit('        AND     AX, 1FFFh');
   Emit('        OR      AX, ' + ItoSI(LTAG_FIXNUM Shl LTAG_SHIFT));
  End;
 Else EmitComment('ARITH op=' + ItoSI(op) + ' non supporte');
 End;
End;

{ ============================================================================ }
{ GENERATION : COMPARAISONS                                                    }
{ ============================================================================ }

Procedure GenCompare(op: Integer; args: TLispVal);
Var
 lbl_false, lbl_end: String; a1, a2: TLispVal;
Begin
 { Generer =, <, >, <=, >= }
 lbl_false := NewLabel + 'CF';
 lbl_end   := NewLabel + 'CE';
 EmitComment('---- COMPARE ' + ItoSI(op) + ' ----');
 If IsNilVal(args) Or IsNilVal(CdrOf(args)) Then Begin
  Emit('        MOV     AX, ' + ItoSI(LVAL_T));
  Exit;
 End;
 a1 := CarOf(args); a2 := CarOf(CdrOf(args));
 GenExpr(a1);
 Emit('        AND     AX, 1FFFh');
 Emit('        MOV     BX, AX');
 Emit('        PUSH    BX');
 GenExpr(a2);
 Emit('        AND     AX, 1FFFh');
 Emit('        POP     BX');
 Emit('        CMP     BX, AX');
 Case op Of
  PRIM_EQ:  Emit('        JNE     ' + lbl_false);
  PRIM_LT:  Emit('        JGE     ' + lbl_false);
  PRIM_GT:  Emit('        JLE     ' + lbl_false);
  PRIM_LE:  Emit('        JG      ' + lbl_false);
  PRIM_GE:  Emit('        JL      ' + lbl_false);
  PRIM_NEQ: Emit('        JE      ' + lbl_false);
 Else Emit('        JNE     ' + lbl_false);
 End;
 Emit('        MOV     AX, ' + ItoSI(LVAL_T));
 Emit('        JMP     ' + lbl_end);
 EmitLabel(lbl_false);
 Emit('        XOR     AX, AX');
 EmitLabel(lbl_end);
End;

Procedure GenEq(a1, a2: TLispVal);
Var
 lbl_false, lbl_end: String;
Begin
 { EQ = identite de pointeur }
 lbl_false := NewLabel + 'EQF';
 lbl_end   := NewLabel + 'EQE';
 GenExpr(a1); Emit('        PUSH    AX');
 GenExpr(a2); Emit('        POP     BX');
 Emit('        CMP     AX, BX');
 Emit('        JNE     ' + lbl_false);
 Emit('        MOV     AX, ' + ItoSI(LVAL_T));
 Emit('        JMP     ' + lbl_end);
 EmitLabel(lbl_false);
 Emit('        XOR     AX, AX');
 EmitLabel(lbl_end);
End;

{ ============================================================================ }
{ GENERATION : OPERATIONS SUR LES LISTES                                       }
{ ============================================================================ }

Procedure GenCar(arg: TLispVal);Begin
 { Generer CAR }
 EmitComment('CAR');
 GenExpr(arg);
 Emit('        AND     AX, 1FFFh    ; extraire index cons');
 Emit('        SHL     AX, 1        ; *2 pour index Word');
 Emit('        MOV     SI, AX');
 Emit('        MOV     AX, [_HEAP_CAR + SI]');
End;

Procedure GenCdr(arg: TLispVal);Begin
 { Generer CDR }
 EmitComment('CDR');
 GenExpr(arg);
 Emit('        AND     AX, 1FFFh');
 Emit('        SHL     AX, 1');
 Emit('        MOV     SI, AX');
 Emit('        MOV     AX, [_HEAP_CDR + SI]');
End;

Procedure GenCons(car_e, cdr_e: TLispVal);Begin
 { Generer CONS }
 EmitComment('CONS');
 GenExpr(cdr_e); Emit('        PUSH    AX');
 GenExpr(car_e); Emit('        PUSH    AX');
 Emit('        CALL    _CONS_ALLOC');
 Emit('        ADD     SP, 4');
End;

Procedure GenNull(arg: TLispVal);
Var
 lbl_f, lbl_e: String;
Begin
 { Generer NULL -> T si NIL }
 lbl_f := NewLabel + 'NF'; lbl_e := NewLabel + 'NE';
 EmitComment('NULL');
 GenExpr(arg);
 Emit('        TEST    AX, AX');
 Emit('        JNZ     ' + lbl_f);
 Emit('        MOV     AX, ' + ItoSI(LVAL_T));
 Emit('        JMP     ' + lbl_e);
 EmitLabel(lbl_f);
 Emit('        XOR     AX, AX');
 EmitLabel(lbl_e);
End;

Procedure GenAtom(arg: TLispVal);
Var
 lbl_f, lbl_e: String;
Begin
 { ATOM -> NIL ssi CONS }
 lbl_f := NewLabel + 'ATF'; lbl_e := NewLabel + 'ATE';
 EmitComment('ATOM');
 GenExpr(arg);
 Emit('        MOV     BX, AX');
 Emit('        SHR     BX, ' + ItoSI(LTAG_SHIFT));
 Emit('        CMP     BX, ' + ItoSI(LTAG_CONS));
 Emit('        JE      ' + lbl_f);
 Emit('        MOV     AX, ' + ItoSI(LVAL_T));
 Emit('        JMP     ' + lbl_e);
 EmitLabel(lbl_f);
 Emit('        XOR     AX, AX');
 EmitLabel(lbl_e);
End;

{ ============================================================================ }
{ GENERATION : PRINT / READ / TERPRI                                           }
{ ============================================================================ }

Procedure GenPrint(arg: TLispVal);Begin
 { G‚n‚rer PRINT selon la balise de la valeur }
 EmitComment('---- PRINT ----');
 GenExpr(arg);
 Emit('        PUSH    AX');
 Emit('        CALL    _LISP_PRINT');
 Emit('        POP     AX');
 Emit('        ; resultat = valeur imprimee (convention LISP)');
End;

Procedure GenTerpri;Begin
 { G‚n‚rer TERPRI }
 EmitComment('TERPRI');
 Emit('        CALL    _LISP_CRLF');
 Emit('        XOR     AX, AX  ; TERPRI retourne NIL');
End;

Procedure GenRead(sym_idx: Integer);Begin
 { G‚n‚rer READ vers un symbole global }
 EmitComment('READ -> ' + ItoSI(sym_idx));
 Emit('        CALL    _LISP_READ_INT');
 If sym_idx > 0 Then
  Emit('        MOV     [_GV_SYM' + ItoSI(sym_idx) + '], AX')
 Else
  EmitComment('READ : destination non specifiee');
End;

{ ============================================================================ }
{ GENERATION : DEFUN + APPEL DE FONCTION                                       }
{ ============================================================================ }

Procedure GenFuncBody(func_idx: Integer; body: TLispVal);
Var
 fp: PFuncEntry;
 i, offset: Integer;
Begin
 { G‚n‚rer le corps d'une DEFUN }
 fp := func_table[func_idx];
 EmitBlank;
 EmitLabel(fp^.asm_label);
 Emit('        PUSH    BP');
 Emit('        MOV     BP, SP');
 { R‚server de l'espace pour les locaux (si LET ou LET-STAR) }
 EmitComment('Parametres: ' + ItoSI(fp^.param_count));
 { Les paramŠtres sont sur la pile : [BP+4] = 1er, [BP+6] = 2eme... }
 { (BP+0 = ancien BP, BP+2 = adresse retour) }
 EnterScope;
 offset := 4;
 For i := 1 to fp^.param_count do Begin
  Inc(local_count);
  local_vars[local_count].name      := fp^.param_names[i];
  local_vars[local_count].bp_offset := offset;
  Inc(offset, 2);
 End;
 { Compiler le corps (PROGN implicite) }
 GenProgn(body);
 LeaveScope;
 Emit('        POP     BP');
 { RET n : nettoyer la pile des arguments }
 Emit('        RET     ' + ItoSI(fp^.param_count * 2));
 EmitBlank;
 fp^.defined := True;
End;

Procedure GenFuncCall(func_idx: Integer; args: TLispVal);
Var
 fp: PFuncEntry;
 n: Integer;
 tmp: TLispVal;
Begin
 { G‚n‚rer un appel de DEFUN }
 fp := func_table[func_idx];
 EmitComment('CALL ' + fp^.name);
 { Empiler arguments de droite a gauche }
 { D'abord compter les arguments }
 tmp := args; n := 0;
 While Not IsNilVal(tmp) Do Begin Inc(n); tmp := CdrOf(tmp); End;
 { Pousser de droite a gauche : reconstruire l'ordre }
 { Simplification : pousser de gauche a droite (ordre Pascal) }
 While Not IsNilVal(args) Do Begin
  GenExpr(CarOf(args));
  Emit('        PUSH    AX');
  args := CdrOf(args);
 End;
 Emit('        CALL    ' + FuncAsmLabel(func_idx));
End;

{ ============================================================================ }
{ GENERATION : LET / LET*                                                      }
{ ============================================================================ }

Procedure GenLet(bindings, body: TLispVal);
Var
 bind, var_e, val_e: TLispVal; n: Integer; sym_idx, loc_idx: Integer;
Begin
 { Generer LET (toutes les valeurs evaluees avant les liaisons) }
 EmitComment('---- LET ----');
 n := 0;
 { Phase 1 : ‚valuer toutes les valeurs + pousser sur la pile }
 bind := bindings;
 While Not IsNilVal(bind) Do Begin
  var_e := CarOf(CarOf(bind));
  val_e := CarOf(CdrOf(CarOf(bind)));
  GenExpr(val_e);
  Emit('        PUSH    AX');
  Inc(n);
  bind := CdrOf(bind);
 End;
 { Phase 2 : cr‚er le frame (BP deja preserve par DEFUN englobant) }
 { Pour LET autonome : PUSH BP / MOV BP, SP }
 Emit('        PUSH    BP');
 Emit('        MOV     BP, SP');
 Emit('        ; Frame LET : ' + ItoSI(n) + ' liaisons');
 Emit('        SUB     SP, ' + ItoSI(n * 2));
  { Lier les variables (de droite a gauche car la pile est LIFO) }
 bind := bindings;
 While Not IsNilVal(bind) Do Begin
  var_e   := CarOf(CarOf(bind));
  sym_idx := PayOf(var_e);
  loc_idx := AddLocal(sym_table[sym_idx]^.name);
  EmitComment('LET ' + sym_table[sym_idx]^.name + ' at BP' + ItoSI(local_vars[loc_idx].bp_offset));
  bind := CdrOf(bind);
 End;
 GenProgn(body);
 Emit('        MOV     SP, BP');
 Emit('        POP     BP');
End;

Procedure GenLetStar(bindings, body: TLispVal);
Var
 bind, var_e, val_e: TLispVal;
 sym_idx, loc_idx: Integer;
Begin
 { LET* - cada binding voit les precedents }
 EmitComment('---- LET* ----');
 Emit('        PUSH    BP');
 Emit('        MOV     BP, SP');
 bind := bindings;
 While Not IsNilVal(bind) Do Begin
  var_e   := CarOf(CarOf(bind));
  val_e   := CarOf(CdrOf(CarOf(bind)));
  sym_idx := PayOf(var_e);
  GenExpr(val_e);
  loc_idx := AddLocal(sym_table[sym_idx]^.name);
  Emit('        SUB     SP, 2');
  Emit('        MOV     [BP' + ItoSI(local_vars[loc_idx].bp_offset) + '], AX');
  bind := CdrOf(bind);
 End;
 GenProgn(body);
 Emit('        MOV     SP, BP');
 Emit('        POP     BP');
End;

{ ============================================================================ }
{ GENERATION : AND / OR / NOT                                                  }
{ ============================================================================ }

Procedure GenAnd(args: TLispVal);
Var
 lbl_false, lbl_end: String;
Begin
 { AND avec court-circuit }
 lbl_false := NewLabel + 'AF';
 lbl_end   := NewLabel + 'AE';
 EmitComment('---- AND ----');
 If IsNilVal(args) Then Begin
  Emit('        MOV     AX, ' + ItoSI(LVAL_T));
  Exit;
 End;
 While Not IsNilVal(args) Do Begin
  GenExpr(CarOf(args));
  Emit('        TEST    AX, AX');
  Emit('        JZ      ' + lbl_false);
  args := CdrOf(args);
 End;
 Emit('        JMP     ' + lbl_end);  { AX = derniere valeur vraie }
 EmitLabel(lbl_false);
 Emit('        XOR     AX, AX  ; AND -> NIL');
 EmitLabel(lbl_end);
End;

Procedure GenOr(args: TLispVal);
Var
 lbl_true, lbl_end: String;
Begin
 { OR avec court-circuit }
 lbl_true := NewLabel + 'OT';
 lbl_end  := NewLabel + 'OE';
 EmitComment('---- OR ----');
 If IsNilVal(args) Then Begin
  Emit('        XOR     AX, AX  ; OR() = NIL');
  Exit;
 End;
 While Not IsNilVal(args) Do Begin
  GenExpr(CarOf(args));
  Emit('        TEST    AX, AX');
  Emit('        JNZ     ' + lbl_true);
  args := CdrOf(args);
 End;
 Emit('        XOR     AX, AX  ; OR -> NIL');
 Emit('        JMP     ' + lbl_end);
 EmitLabel(lbl_true);
 { AX = premiere valeur vraie }
 EmitLabel(lbl_end);
End;

Procedure GenNot(arg: TLispVal);
Var
 lbl_t, lbl_e: String;
Begin
  { NOT }
 lbl_t := NewLabel + 'NT';
 lbl_e := NewLabel + 'NE';
 EmitComment('NOT');
 GenExpr(arg);
 Emit('        TEST    AX, AX');
 Emit('        JNZ     ' + lbl_t);
 Emit('        MOV     AX, ' + ItoSI(LVAL_T));
 Emit('        JMP     ' + lbl_e);
 EmitLabel(lbl_t);
 Emit('        XOR     AX, AX');
 EmitLabel(lbl_e);
End;

{ ============================================================================ }
{ GENERATEUR D'EXPRESSION PRINCIPAL                                            }
{ ============================================================================ }

Procedure GenExpr(v: TLispVal);
Var
 head, args, a1, a2, else_e, tmp_e: TLispVal;
 sym_idx, sf, prim_op: Integer;
 func_idx: Integer;
Begin
 { Atome direct }
 If TagOf(v) <> LTAG_CONS Then Begin
  GenEvalAtom(v);
  Exit;
 End;
 { C'est une liste : (head args...) }
 head := CarOf(v);
 args := CdrOf(v);
  { L'operateur doit etre un symbole }
 If TagOf(head) <> LTAG_SYM Then Begin
  EmitComment('GenExpr: tete non-symbole (TODO: lambda-call)');
  GenEvalAtom(head);
  Exit;
 End;
 sym_idx := PayOf(head);
 sf      := GetSpecialForm(sym_idx);
 prim_op := GetPrim(sym_idx);
 { ---- Formes sp‚ciales ---- }
 Case sf Of
  SF_QUOTE:
  Begin
   If Not IsNilVal(args) Then GenQuote(CarOf(args))
   Else Emit('        XOR     AX, AX');
  End;
  SF_IF:
  Begin
   { (IF test then [else]) }
   If Not IsNilVal(args) Then a1 := CarOf(args) Else a1 := LVAL_NIL;
   If Not IsNilVal(CdrOf(args)) Then a2 := CarOf(CdrOf(args)) Else a2 := LVAL_NIL;
   If Not IsNilVal(CdrOf(CdrOf(args))) Then
    else_e := CarOf(CdrOf(CdrOf(args))) Else else_e := LVAL_NIL;
   GenIf(a1, a2, else_e);
  End;
  SF_COND:   GenCond(args);
  SF_SETQ:
  Begin
   { (SETQ sym val) }
   If Not IsNilVal(args) And (TagOf(CarOf(args)) = LTAG_SYM) Then
   Begin
    If Not IsNilVal(CdrOf(args)) Then tmp_e := CarOf(CdrOf(args)) Else tmp_e := LVAL_NIL;
    GenSetq(PayOf(CarOf(args)), tmp_e);
   End
   Else EmitComment('SETQ : syntaxe incorrecte');
  End;
  SF_PROGN:  GenProgn(args);
  SF_LET:    GenLet(CarOf(args), CdrOf(args));
  SF_LETSTAR:GenLetStar(CarOf(args), CdrOf(args));
  SF_AND:    GenAnd(args);
  SF_OR:     GenOr(args);
  SF_NOT:
  Begin
   If Not IsNilVal(args) Then GenNot(CarOf(args))
   Else Emit('        MOV     AX, ' + ItoSI(LVAL_T));
  End;
  SF_WHEN:
  Begin
   { (WHEN test body...) }
   If Not IsNilVal(args) Then a1 := CarOf(args) Else a1 := LVAL_NIL;
   GenIf(a1, MakeCons(MakeSym(FindSymbol('PROGN')), CdrOf(args)), LVAL_NIL);
  End;
  SF_UNLESS:
  Begin
   If Not IsNilVal(args) Then a1 := CarOf(args) Else a1 := LVAL_NIL;
   GenIf(a1, LVAL_NIL, MakeCons(MakeSym(FindSymbol('PROGN')), CdrOf(args)));
  End;
  SF_DEFUN:
  Begin
   { (DEFUN name (params) body...) }
   { Traite dans GenTopLevel, mais si imbriquee (edge case), stub }
   EmitComment('DEFUN imbriquee (non supporte, stub)');
   Emit('        XOR     AX, AX');
  End;
 Else
  { ---- Primitives ---- }
  Case prim_op Of
   PRIM_ADD, PRIM_SUB, PRIM_MUL, PRIM_DIV: GenArith(prim_op, args);
   PRIM_EQ, PRIM_LT, PRIM_GT, PRIM_LE, PRIM_GE, PRIM_NEQ:
    GenCompare(prim_op, args);
   PRIM_EQP:
   Begin
    If Not IsNilVal(args) And Not IsNilVal(CdrOf(args)) Then
     GenEq(CarOf(args), CarOf(CdrOf(args)))
    Else Emit('        MOV     AX, ' + ItoSI(LVAL_T));
   End;
   PRIM_CAR:
   Begin
    If Not IsNilVal(args) Then a1 := CarOf(args) Else a1 := LVAL_NIL;
    GenCar(a1);
   End;
   PRIM_CDR:
   Begin
    If Not IsNilVal(args) Then a1 := CarOf(args) Else a1 := LVAL_NIL;
    GenCdr(a1);
   End;
   PRIM_CONS:
   Begin
    If Not IsNilVal(args) Then a1 := CarOf(args) Else a1 := LVAL_NIL;
    If Not IsNilVal(CdrOf(args)) Then a2 := CarOf(CdrOf(args)) Else a2 := LVAL_NIL;
    GenCons(a1, a2);
   End;
   PRIM_NULL:
   Begin
    If Not IsNilVal(args) Then a1 := CarOf(args) Else a1 := LVAL_NIL;
    GenNull(a1);
   End;
   PRIM_ATOM:
   Begin
    If Not IsNilVal(args) Then a1 := CarOf(args) Else a1 := LVAL_NIL;
    GenAtom(a1);
   End;
   PRIM_NOT:
   Begin
    If Not IsNilVal(args) Then a1 := CarOf(args) Else a1 := LVAL_NIL;
    GenNot(a1);
   End;
   PRIM_PRINT:
   Begin
    If Not IsNilVal(args) Then a1 := CarOf(args) Else a1 := LVAL_NIL;
    GenPrint(a1);
   End;
   PRIM_TERPRI: GenTerpri;
   PRIM_READ:
   Begin
    EmitComment('READ (stub - lit un entier)');
    Emit('        CALL    _LISP_READ_INT');
   End;
  Else
   { Appel de fonction DEFUN }
   func_idx := FindFunc(sym_table[sym_idx]^.name);
   If func_idx > 0 Then
    GenFuncCall(func_idx, args)
   Else
   Begin
    EmitComment('Appel: ' + sym_table[sym_idx]^.name + ' (non defini)');
    Emit('        XOR     AX, AX');
   End;
  End;
 End;
End;

{ ============================================================================ }
{ TRAITEMENT DU NIVEAU SUPERIEUR                                               }
{ ============================================================================ }

Procedure GenTopLevel(expr: TLispVal);
Var
 head, args, name_e, params_e, body_e: TLispVal;
 sym_idx, func_idx: Integer;
 fname: String; nparams: Integer; tmp: TLispVal;
Begin
 If TagOf(expr) <> LTAG_CONS Then Begin
  { Expression atomique au niveau superieur : evaluer }
  GenExpr(expr);
  Exit;
 End;
 head := CarOf(expr);
 args := CdrOf(expr);
 If TagOf(head) = LTAG_SYM Then
 Begin
  sym_idx := PayOf(head);
  If sym_table[sym_idx]^.special = SF_DEFUN Then Begin
   { (DEFUN name (params) body...) }
   name_e   := CarOf(args);
   params_e := CarOf(CdrOf(args));
   body_e   := CdrOf(CdrOf(args));
   If TagOf(name_e) <> LTAG_SYM Then Begin
    Error('DEFUN : nom invalide');
    Exit;
   End;
   fname  := sym_table[PayOf(name_e)]^.name;
   { Compter les paramŠtres }
   nparams := 0; tmp := params_e;
   While Not IsNilVal(tmp) Do Begin
    Inc(nparams);
    tmp := CdrOf(tmp);
   End;
   func_idx := AddFunc(fname, nparams);
   { Enregistrer noms des paramŠtres }
   tmp := params_e; nparams := 0;
   While Not IsNilVal(tmp) Do Begin
    Inc(nparams);
    If TagOf(CarOf(tmp)) = LTAG_SYM Then
     func_table[func_idx]^.param_names[nparams] :=
      sym_table[PayOf(CarOf(tmp))]^.name;
    tmp := CdrOf(tmp);
   End;
   EmitComment('=== DEFUN ' + fname + ' ===');
   GenFuncBody(func_idx, body_e);
   Exit;
  End;
  If sym_table[sym_idx]^.special = SF_DEFVAR Then Begin
   { (DEFVAR name [init]) }
   name_e := CarOf(args);
   If TagOf(name_e) = LTAG_SYM Then Begin
    sym_idx := PayOf(name_e);
    EmitComment('DEFVAR ' + sym_table[sym_idx]^.name);
    If Not IsNilVal(CdrOf(args)) Then Begin
     GenExpr(CarOf(CdrOf(args)));
     Emit('        MOV     [_GV_SYM' + ItoSI(sym_idx) + '], AX');
    End;
   End;
   Exit;
  End;
 End;
  { Autres formes au niveau superieur : ‚valuer normalement }
 GenExpr(expr);
End;

{ ============================================================================ }
{ GENERATION : ASSISANT RUNTIME                                                }
{ ============================================================================ }

Procedure GenRuntimeHelpers;
Var
 i: Integer;
Begin
 EmitBlank;
 Emit('; ----------------------------------------------------------------');
 Emit('; RUNTIME ASSISTANT LISP86');
 Emit('; ----------------------------------------------------------------');
 EmitBlank;
 { _CONS_ALLOC : [SP+2]=CAR, [SP+4]=CDR -> AX=cons tagged }
 Emit('        ; _CONS_ALLOC: PUSH cdr, PUSH car, CALL -> AX = cons tagged');
 Emit('_CONS_ALLOC:');
 Emit('        PUSH    BP');
 Emit('        MOV     BP, SP');
 Emit('        MOV     BX, [_FREE_PTR]');
 Emit('        CMP     BX, ' + ItoSI(MAX_CONS));
 Emit('        JAE     _CONS_FULL');
 Emit('        MOV     AX, [BP+4]   ; CAR');
 Emit('        MOV     SI, BX');
 Emit('        SHL     SI, 1');
 Emit('        MOV     [_HEAP_CAR + SI], AX');
 Emit('        MOV     AX, [BP+6]   ; CDR');
 Emit('        MOV     [_HEAP_CDR + SI], AX');
 Emit('        INC     WORD PTR [_FREE_PTR]');
 Emit('        MOV     AX, BX');
 Emit('        AND     AX, 1FFFh');
 Emit('        OR      AX, 8000h   ; LTAG_CONS tag ($8000)');
 Emit('        POP     BP');
 Emit('        RET');
 Emit('_CONS_FULL:');
 Emit('        LEA     DX, _ERR_STR');
 Emit('        MOV     AH, 09h');
 Emit('        INT     21h');
 Emit('        MOV     AX, 4C01h');
 Emit('        INT     21h');
 EmitBlank;
 { _LISP_PRINT : AX = valeur LISP tagged }
 Emit('        ; _LISP_PRINT: AX = valeur LISP -> affichage sur stdout');
 Emit('_LISP_PRINT:');
 Emit('        PUSH    BP');
 Emit('        MOV     BP, SP');
 Emit('        MOV     BX, AX');
 Emit('        SHR     BX, ' + ItoSI(LTAG_SHIFT));
 Emit('        AND     BX, 7');
 Emit('        CMP     BX, ' + ItoSI(LTAG_NIL));
 Emit('        JNE     _PRT_NOT_NIL');
 Emit('        LEA     DX, _NIL_STR');
 Emit('        MOV     AH, 09h');
 Emit('        INT     21h');
 Emit('        JMP     _PRT_DONE');
 Emit('_PRT_NOT_NIL:');
 Emit('        CMP     BX, ' + ItoSI(LTAG_T));
 Emit('        JNE     _PRT_NOT_T');
 Emit('        LEA     DX, _T_STR');
 Emit('        MOV     AH, 09h');
 Emit('        INT     21h');
 Emit('        JMP     _PRT_DONE');
 Emit('_PRT_NOT_T:');
 Emit('        CMP     BX, ' + ItoSI(LTAG_FIXNUM));
 Emit('        JNE     _PRT_NOT_FIX');
 Emit('        MOV     BX, AX');
 Emit('        AND     BX, 1FFFh');
 Emit('        CALL    _LISP_PRINT_FIX');
 Emit('        JMP     _PRT_DONE');
 Emit('_PRT_NOT_FIX:');
 Emit('        CMP     BX, ' + ItoSI(LTAG_STR));
 Emit('        JNE     _PRT_DEFAULT');
 EmitComment('TODO: afficher chaine depuis heap (stub)');
 Emit('        LEA     DX, _NIL_STR');
 Emit('        MOV     AH, 09h');
 Emit('        INT     21h');
 Emit('        JMP     _PRT_DONE');
 Emit('_PRT_DEFAULT:');
 EmitComment('CONS / FUNC : affichage simplifie stub');
 Emit('        LEA     DX, _NIL_STR');
 Emit('        MOV     AH, 09h');
 Emit('        INT     21h');
 Emit('_PRT_DONE:');
 Emit('        POP     BP');
 Emit('        RET');
 EmitBlank;
 { _LISP_PRINT_FIX : BX = entier signe -> afficher en decimal }
 Emit('        ; _LISP_PRINT_FIX: BX = entier -> affichage decimal');
 Emit('_LISP_PRINT_FIX:');
 Emit('        PUSH    BX');
 Emit('        CMP     BX, 0');
 Emit('        JGE     _PFX_POS');
 Emit('        MOV     DL, ''-''');
 Emit('        MOV     AH, 02h');
 Emit('        INT     21h');
 Emit('        NEG     BX');
 Emit('_PFX_POS:');
 Emit('        LEA     DI, _NUMBUF + 19');
 Emit('        MOV     BYTE PTR [DI+1], ''$''');
 Emit('        MOV     AX, BX');
 Emit('        MOV     CX, 10');
 Emit('        MOV     SI, 0     ; nb chiffres');
 Emit('_PFX_LP:');
 Emit('        XOR     DX, DX');
 Emit('        DIV     CX');
 Emit('        ADD     DL, 30h');
 Emit('        MOV     [DI], DL');
 Emit('        DEC     DI');
 Emit('        INC     SI');
 Emit('        TEST    AX, AX');
 Emit('        JNZ     _PFX_LP');
 Emit('        INC     DI');
 Emit('        LEA     DX, [DI]');
 Emit('        MOV     AH, 09h');
 Emit('        INT     21h');
 Emit('        POP     BX');
 Emit('        RET');
 EmitBlank;
 { _LISP_CRLF }
 Emit('_LISP_CRLF:');
 Emit('        LEA     DX, _CRLF');
 Emit('        MOV     AH, 09h');
 Emit('        INT     21h');
 Emit('        RET');
 EmitBlank;
 { _LISP_READ_INT : saisir un entier -> AX = FIXNUM tagged }
 Emit('        ; _LISP_READ_INT -> AX = LTAG_FIXNUM | valeur');
 Emit('_LISP_READ_INT:');
 Emit('        MOV     _INPUTBUF, 80');
 Emit('        LEA     DX, _INPUTBUF');
 Emit('        MOV     AH, 0Ah');
 Emit('        INT     21h');
 Emit('        CALL    _LISP_CRLF');
 Emit('        XOR     BX, BX');
 Emit('        XOR     CX, CX');
 Emit('        MOV     CL, _INPUTBUF+1');
 Emit('        LEA     SI, _INPUTBUF+2');
 Emit('        CMP     BYTE PTR [SI], ''-''');
 Emit('        JNE     _RDI_LP');
 Emit('        INC     SI');
 Emit('        DEC     CX');
 Emit('        XOR     DX, DX');
 Emit('        MOV     DX, 1  ; flag negatif');
 Emit('        PUSH    DX');
 Emit('        JMP     _RDI_LP');
 Emit('_RDI_LP:');
 Emit('        JCXZ    _RDI_DONE');
 Emit('        LODSB');
 Emit('        SUB     AL, 30h');
 Emit('        IMUL    BX, BX, 10');
 Emit('        CBW');
 Emit('        ADD     BX, AX');
 Emit('        DEC     CX');
 Emit('        JMP     _RDI_LP');
 Emit('_RDI_DONE:');
 Emit('        MOV     AX, BX');
 Emit('        AND     AX, 1FFFh');
 Emit('        OR      AX, ' + ItoSI(LTAG_FIXNUM Shl LTAG_SHIFT));
 Emit('        RET');
 EmitBlank;
 { _LISP_ERROR }
 Emit('_LISP_ERROR:');
 Emit('        LEA     DX, _ERR_STR');
 Emit('        MOV     AH, 09h');
 Emit('        INT     21h');
 Emit('        MOV     AX, 4C01h');
 Emit('        INT     21h');
 EmitBlank;
 { Chaines litterales collectees lors de la compilation }
 If str_count > 0 Then
 Begin
  EmitBlank;
  Emit('.DATA');
  EmitComment('=== Chaines litterales ===');
  For i := 1 to str_count do
   Emit('    ' + str_table[i]^.asm_label +
        '  DB  ''' + AsmStr(str_table[i]^.text) + ''', ''$''');
 End;
End;

{ ============================================================================ }
{ PROGRAMME PRINCIPAL + BOUCLE DE COMPILATION                                  }
{ ============================================================================ }

{ ---- Variables locales du bloc principal ---- }
Var
 i_cmd : Integer;
 arg_s  : String;
 j_ext  : Integer;
 top_expr: TLispVal;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('LISP86 - Cette commande permet de lancer le compilateur LISP pour de l''assembleur du ',
                    'microprocesseur 8086/8088.');
  WriteLn;
  WriteLn('Syntaxe : LISP86 source.lsp [sortie.asm] [options]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  /T    Afficher tokens seulement');
  WriteLn('  /A    Afficher AST seulement');
  WriteLn('  /V    Mode verbeux');
  WriteLn;
  WriteLn('Formes speciales supportees:');
  WriteLn('  DEFUN IF COND SETQ PROGN LET LET* QUOTE AND OR NOT WHEN UNLESS');
  WriteLn;
  WriteLn('Primitives supportees:');
  WriteLn('  + - * /  = < > <= >=  /=  EQ EQUAL');
  WriteLn('  CAR CDR CONS LIST ATOM NULL NOT');
  WriteLn('  PRINT WRITE READ TERPRI LENGTH APPEND');
  Halt(0);
 End;
 { ---- Initialisation ---- }
 error_count    := 0;
 label_counter  := 0;
 lit_counter    := 0;
 gen_enabled    := False;
 sym_count      := 0;
 func_count     := 0;
 str_count      := 0;
 local_count    := 0;
 local_bp_top   := 0;
 in_func        := False;
 source_filename := '';
 output_filename := '';
 opt_dump_tok   := False;
 opt_dump_ast   := False;
 opt_verbose    := False;
  { ---- Analyser la ligne de commande ---- }
 For i_cmd := 1 to ParamCount do Begin
  arg_s := ParamStr(i_cmd);
  If (arg_s[1] = '/') Or (arg_s[1] = '-') Then
  Begin
   Case UpCase(arg_s[2]) Of
    'T': opt_dump_tok := True;
    'A': opt_dump_ast := True;
    'V': opt_verbose  := True;
   End;
  End
   Else
  If source_filename = '' Then source_filename := arg_s
                          Else output_filename := arg_s;
 End;
 If source_filename = '' Then Begin
  WriteLn('Fichier source requis !');
  Halt(1);
 End;
  { ---- Nom de sortie par defaut ---- }
 If output_filename = '' Then Begin
  output_filename := source_filename;
  j_ext := Length(output_filename);
  While (j_ext > 0) And (output_filename[j_ext] <> '.') And
        (output_filename[j_ext] <> '\') And (output_filename[j_ext] <> '/') Do Dec(j_ext);
  If (j_ext > 0) And (output_filename[j_ext] = '.') Then
   output_filename := Copy(output_filename, 1, j_ext-1) + '.ASM'
  Else
   output_filename := output_filename + '.ASM';
 End;
  { ---- Ouvrir le fichier source ---- }
 Assign(input_file, source_filename);
 Reset(input_file);
 If IOResult <> 0 Then Begin
  WriteLn('ERREUR: Impossible d''ouvrir: ', source_filename);
  Halt(1);
 End;
 WriteLn(VERSION, ' - Compilation de: ', source_filename);
  { ---- Initialiser les tables ---- }
 InitSymbolTable;
 InitFuncTable;
 InitHeap;
 InitTokenizer;
  { ---- Mode dump tokens ---- }
 If opt_dump_tok Then Begin
  { Afficher tous les tokens }
  WriteLn('=== TOKENS ===');
  While cur_tok_type <> TOK_EOF Do Begin
   WriteLn('TOK=', cur_tok_type, ' "', cur_tok_str, '"');
   NextToken;
  End;
  Close(input_file);
  Halt(0);
 End;
  { ---- Ouvrir la sortie ASM ---- }
 Assign(output_file, output_filename);
 Rewrite(output_file);
 If IOResult <> 0 Then Begin
  WriteLn('ERREUR: Impossible de creer: ', output_filename);
  Halt(1);
 End;
 gen_enabled := True;
  { ---- G‚n‚rer l'entˆte + DATA ---- }
 GenHeader;
 GenCodeSegmentHeader;
  { ---- Boucle de lecture + compilation des formes de haut niveau ---- }
  { Lire toutes les S-expressions et compiler chacune          }
 While cur_tok_type <> TOK_EOF Do Begin
  top_expr := ReadExpr;
  If opt_dump_ast Then
  Begin
   { Afficher l'AST (dump pascal) }
   WriteLn('AST tag=', TagOf(top_expr), ' pay=', PayOf(top_expr));
  End;
  GenTopLevel(top_expr);
 End;
 { ---- G‚n‚rer les helpers runtime ---- }
 GenRuntimeHelpers;
 { ---- Footer ASM ---- }
 GenFooter;
 { ---- Fermer les fichiers ---- }
 Close(output_file);
 Close(input_file);
 WriteLn('ASM g‚n‚r‚: ', output_filename);
 WriteLn('Termin‚. Erreurs: ', error_count, '  Fonctions: ', func_count,
         '  Symboles: ', sym_count);
 If error_count > 0 Then Halt(1);
END.