{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur Fortran 77 vers assembleur 8086
  @output:  MASM/TASM 8086 (.ASM) - Modele memoire SMALL
  @license: MIT }

Program F77C86;

{$N+}
{$I-}   { desactiver les IO-check }

{ ============================================================
  INFRASTRUCTURE DE BASE
  ============================================================ }

{ --- Constantes de dimensionnement --- }
Const
  F77_VERSION  = '1.0';
  F77_DATE     = '2026-03-04';

  MAX_SYM      = {$IFDEF FPC}512{$ELSE}100{$ENDIF};    { entrees table des symboles                 }
  MAX_SCOPE    = 16;     { niveaux de portee (F77 a portee unique)    }
  MAX_PROC     = {$IFDEF FPC}128{$ELSE}48{$ENDIF};    { sous-programmes et fonctions               }
  MAX_PARAM    = {$IFDEF FPC}32{$ELSE}8{$ENDIF};     { parametres par sous-programme              }
  MAX_LABELS   = {$IFDEF FPC}1024{$ELSE}256{$ENDIF};   { etiquettes numeriques Fortran (1-99999)    }
  MAX_ERRORS   = 30;     { arret apres N erreurs                      }
  MAX_STR      = 127;    { longueur maximale d'une TString            }
  MAX_DIM      = 7;      { dimensions max d'un tableau (norme F77)    }
  MAX_COMMON   = 64;     { blocs COMMON distincts                     }
  MAX_FORMAT   = 64;     { enonces FORMAT memorises                   }
  MAX_UNITS    = 99;     { unites logiques de fichiers (1..99)        }
  STACK_SIZE   = 512;    { taille segment pile en octets              }
  MAX_LOGLINE  = 1320;   { longueur max d'un enregistrement logique   }

  { Prefixes des labels assembleur 8086 }
  FL_PFX  = '_FL_';    { etiquettes numeriques Fortran (GOTO/DO)    }
  FV_PFX  = '_FV_';    { variables statiques et COMMON              }
  FB_PFX  = '_FB_';    { branches internes (IF/DO/..)               }
  FRT_PFX = '_FRT_';   { routines runtime Fortran                   }
  FK_PFX  = '_FK_';    { constantes chaines et format               }
  FC_PFX  = '_FC_';    { blocs COMMON (_FC_BLANK_, _FC_nom_)        }
  FP_PFX  = '_FP_';    { procedures et fonctions utilisateur        }

{ --- Types fondamentaux --- }
Type
  TString = String[MAX_STR];

  { ---- Tokens Fortran 77 ---- }
  TTokenKind = (
    TK_IDENT,      { identificateur (max 6 chars en F77 strict)   }
    TK_INTEGER,    { litteral entier                               }
    TK_REAL,       { litteral reel  (1.5E+3)                      }
    TK_DOUBLE,     { litteral double precision (1.5D-2)           }
    TK_STRING,     { chaine 'abc' (apostrophe doublee pour '')     }
    TK_LOGICAL,    { .TRUE. ou .FALSE.                            }
    TK_HOLLERITH,  { nHabc... (hollerith)                         }
    TK_KEYWORD,    { mot-cle Fortran reserve                      }
    TK_RELOP,      { .EQ. .NE. .LT. .LE. .GT. .GE.               }
    TK_LOGOP,      { .AND. .OR. .NOT. .EQV. .NEQV.               }
    TK_OP,         { operateur  + - * / ** // =                   }
    TK_PUNCT,      { ponctuation  ( ) , : '                       }
    TK_LABEL,      { etiquette numerique (colonnes 1-5)           }
    TK_NEWLINE,    { fin d'enregistrement logique                 }
    TK_EOF         { fin de fichier                               }
  );

  TToken = Record
    kind     : TTokenKind;
    val      : TString;       { representation brute               }
    int_val  : LongInt;       { si TK_INTEGER ou TK_LABEL          }
    real_val : Real;          { si TK_REAL ou TK_DOUBLE            }
    lbl_num  : Integer;       { si TK_LABEL : numero 1-99999       }
    line     : Integer;       { ligne physique dans le source      }
    col      : Integer;       { colonne dans l'enregistrement      }
  End;

  { ---- Types de donnees Fortran 77 ---- }
  TDataType = (
    DT_NONE,       { non determine (avant typage implicite)       }
    DT_INTEGER,    { INTEGER [*2|*4] : entier signe 16/32 bits    }
    DT_REAL,       { REAL [*4]       : virgule flottante 4 octets  }
    DT_DOUBLE,     { DOUBLE PRECISION : virgule flottante 8 octets }
    DT_COMPLEX,    { COMPLEX [*8]    : partie re+im REAL*4+REAL*4  }
    DT_LOGICAL,    { LOGICAL [*2]    : booleen 0/-1               }
    DT_CHARACTER   { CHARACTER [*n]  : chaine longueur fixe        }
  );

  { ---- Categories de symboles Fortran 77 ---- }
  TSymKind = (
    SK_NONE,        { entree non utilisee                          }
    SK_VAR,         { variable scalaire (locale ou SAVE)           }
    SK_ARRAY,       { tableau (DIMENSION declaree)                 }
    SK_PARAM,       { parametre formel (passe par adresse)         }
    SK_FUNC,        { fonction utilisateur (FUNCTION)              }
    SK_SUBR,        { sous-programme (SUBROUTINE)                  }
    SK_COMMON,      { variable dans un bloc COMMON                 }
    SK_PARAM_CONST, { constante symbolique (PARAMETER)             }
    SK_INTRINSIC,   { fonction intrinseque (INTRINSIC declaree)    }
    SK_EXTERNAL,    { sous-programme externe (EXTERNAL declaree)   }
    SK_STMTFUNC     { fonction-instruction (FUNC(x) = expr)        }
  );

  { ---- Borne d'une dimension de tableau ---- }
  TDimBound = Record
    lb : Integer;   { borne inferieure (defaut 1)                  }
    ub : Integer;   { borne superieure (-1 = ajustable : ub=*)     }
  End;

  { ---- Entree de la table des symboles ---- }
  TSymRec = Record
    name       : TString;     { nom du symbole (majuscules)        }
    kind       : TSymKind;
    dtype      : TDataType;
    char_len   : Integer;     { longueur si DT_CHARACTER           }
    type_size  : Integer;     { taille en octets (2,4,8...)        }
    ndim       : Integer;     { nombre de dimensions (0=scalaire)  }
    dims       : Array[1..MAX_DIM] of TDimBound;
    asm_label  : TString;     { label ASM (FV_ ou FC_ + nom)       }
    bp_offset  : Integer;     { offset BP si variable locale       }
    is_save    : Boolean;     { SAVE : conserver entre les appels  }
    is_dummy   : Boolean;     { parametre formel                   }
    is_defined : Boolean;     { au moins une affectation faite     }
    common_blk : Integer;     { index bloc COMMON (0=aucun)        }
    common_off : Integer;     { offset dans le bloc COMMON         }
    equiv_grp  : Integer;     { groupe EQUIVALENCE (0=aucun)       }
    equiv_off  : Integer;     { offset dans le groupe              }
    const_ival : LongInt;     { valeur si SK_PARAM_CONST entier    }
    const_rval : Real;        { valeur si SK_PARAM_CONST reel      }
    const_sval : TString;     { valeur si SK_PARAM_CONST chaine    }
    proc_idx   : Integer;     { index proc_table si SK_FUNC/SUBR   }
    scope_unit : Integer;     { unite de programme (proc_idx)      }
  End;

  TSymTable = Array[1..MAX_SYM] of TSymRec;

  { ---- Entree de la table des etiquettes numeriques ---- }
  TLabelRec = Record
    num        : Integer;     { numero 1-99999                     }
    asm_label  : TString;     { FL_nnnnn                           }
    defined    : Boolean;     { l'etiquette a ete vue dans le code }
    referenced : Boolean;     { un GOTO/DO y fait reference        }
    do_end     : Boolean;     { c'est le label de fin d'un DO      }
    line       : Integer;     { ligne de definition                }
  End;

  TLabelTable = Array[1..MAX_LABELS] of TLabelRec;

  { ---- Bloc COMMON ---- }
  TCommonRec = Record
    name       : TString;     { nom du bloc ('' = BLANK COMMON)    }
    asm_label  : TString;     { _FC_nom_ ou _FC_BLANK_             }
    total_size : Integer;     { taille totale en octets            }
  End;

  TCommonTable = Array[1..MAX_COMMON] of TCommonRec;

  { Alias pratiques pour les variables locales dans le generateur de code }
  TSymRef    = TSymRec;
  TCommonRef = TCommonRec;

  { ---- Enonce FORMAT memorise ---- }
  TFormatRec = Record
    lbl_num    : Integer;     { numero de l'etiquette              }
    text       : TString;     { corps du FORMAT entre parentheses  }
    asm_label  : TString;     { FK_FMT_nnnnn                       }
  End;

  TFormatTable = Array[1..MAX_FORMAT] of TFormatRec;

  { ---- Parametre formel d'un sous-programme ---- }
  TParamRec = Record
    name       : TString;
    dtype      : TDataType;
    char_len   : Integer;     { si DT_CHARACTER                    }
    is_array   : Boolean;     { tableau dummy                      }
    bp_offset  : Integer;     { [BP + bp_offset] = adresse arg     }
    len_offset : Integer;     { [BP + len_offset] = longueur char  }
  End;

  { ---- Entree de la table des sous-programmes ---- }
  TProcRec = Record
    name         : TString;
    asm_label    : TString;   { _FP_<nom>                          }
    is_function  : Boolean;   { True=FUNCTION, False=SUBROUTINE    }
    ret_type     : TDataType; { type de retour si FUNCTION         }
    ret_char_len : Integer;   { longueur si CHARACTER FUNCTION      }
    param_count  : Integer;
    params       : Array[1..MAX_PARAM] of TParamRec;
    local_size   : Integer;   { octets du cadre local pile         }
    has_result   : Boolean;   { le nom de fonction a ete affecte   }
    result_off   : Integer;   { offset BP de la variable retour    }
  End;

  TProcTable = Array[1..MAX_PROC] of TProcRec;

  { ---- Unite logique de fichier ---- }
  TUnitRec = Record
    number     : Integer;     { 0=non ouvert, 5=stdin, 6=stdout    }
    handle     : Integer;     { handle DOS (0=non ouvert)          }
    is_open    : Boolean;
    fname      : TString;     { nom de fichier physique            }
  End;

  { Pointeur sur fichier texte }
  TTextPtr = ^Text;

  { Enregistrement logique Fortran (concatentation des lignes de continuation) }
  TLogRec = Array[1..MAX_LOGLINE] of Char;

{ --- Variables globales du compilateur --- }
Var
  { Tables allouees dynamiquement }
  sym_table    : ^TSymTable;
  proc_table   : ^TProcTable;
  lbl_table    : ^TLabelTable;
  common_table : ^TCommonTable;
  fmt_table    : ^TFormatTable;

  { Fichiers source et sortie }
  src_file     : Text;
  out_file     : Text;
  tmp_file     : Text;            { corps des sous-programmes       }
  str_file     : Text;            { chaines litterales differees    }
  cur_out      : TTextPtr;        { pointe sur out_file ou tmp_file }
  src_fname    : TString;
  out_fname    : TString;
  tmp_fname    : TString;
  str_fname    : TString;
  prog_epilogue_done : Boolean;   { True si GenProgramEpilogue deja emis }
  in_block_data    : Boolean;       { True durant le parsing d'un BLOCK DATA  }
  block_data_name  : TString;       { nom du BLOCK DATA courant ('' = sans nom) }
  called_list_cnt  : Integer;       { nombre d'appels externes enregistres     }
  called_list      : Array[1..128] of TString; { noms appeles via CALL          }
  pre_ident        : TString; { partie ident collee au mot-cle (F77 blank-strip) }
  tmp_file_open    : Boolean; { True tant que tmp_file n'est pas encore ferme    }

  { Compteurs }
  sym_count    : Integer;
  proc_count   : Integer;
  lbl_count    : Integer;
  common_count : Integer;
  fmt_count    : Integer;
  equiv_count  : Integer;     { groupes EQUIVALENCE distincts      }
  err_count    : Integer;
  warn_count   : Integer;
  instr_count  : Integer;
  str_lit_count: Integer;
  branch_lbl_count : Integer;   { compteur labels branches internes _FB_  }
  data_lbl_count   : Integer;   { compteur labels constantes DATA _FK_     }
  phys_lines   : Integer;         { lignes physiques lues          }

  { Lecteur de source format fixe }
  src_eof      : Boolean;
  log_rec      : ^TLogRec;            { enregistrement logique courant }
  log_rec_len  : Integer;             { longueur de log_rec            }
  log_pos      : Integer;             { position courante dans log_rec }
  log_label    : Integer;             { etiquette cols 1-5 (0=aucune)  }
  log_is_comm  : Boolean;             { ligne commentaire              }
  log_lineno   : Integer;             { numero de ligne physique debut }
  peek_phys_buf : String[255];          { ligne physique anticipee (SrcIsContinued) }
  has_peek_phys : Boolean;              { True si peek_phys_buf est valide          }

  { Lecteur lexical }
  cur_tok      : TToken;
  peek_tok     : TToken;
  has_peek     : Boolean;
  pending_id   : TString; { identifiant mis en attente apres split kw+id }

  { Contexte de compilation }
  prog_name    : TString;             { nom de PROGRAM/SUBROUTINE/FUNCTION }
  cur_proc_idx : Integer;             { 0=niveau module                    }
  cur_unit_kw  : TString;             { PROGRAM SUBROUTINE FUNCTION BLOCKDATA }

  { Typage implicite }
  impl_type    : Array['A'..'Z'] of TDataType;  { regle implicite par lettre }
  impl_none    : Boolean;             { IMPLICIT NONE actif                }

  { Pile de blocs IF }
  if_depth     : Integer;
  if_else_lbl  : Array[1..MAX_SCOPE] of TString;
  if_end_lbl   : Array[1..MAX_SCOPE] of TString;

  { Pile de boucles DO }
  do_depth     : Integer;
  do_top_lbl   : Array[1..MAX_SCOPE] of TString;  { label haut DO    }
  do_end_lbl   : Array[1..MAX_SCOPE] of TString;  { label fin DO     }
  do_var_si    : Array[1..MAX_SCOPE] of Integer;   { sym index var DO }
  do_lbl_num   : Array[1..MAX_SCOPE] of Integer;   { etiquette num    }

  { Label de retour sous-programme courant }
  cur_ret_lbl   : TString;
  cur_subr_name : TString;  { nom du sous-programme courant (vide=prog. principal) }

  { Fonction courante }
  cur_func_result_si : Integer;   { index sym variable-resultat (0=SUBROUTINE) }
  cur_func_ret_type  : TDataType; { type de retour FUNCTION courant }

  { Dernier label d'enonce courant (pour FORMAT) }
  last_stmt_lbl : Integer;

  { Options de compilation }
  opt_verbose  : Boolean;
  opt_debug    : Boolean;
  opt_no_rt    : Boolean;

  { Unites logiques de fichiers }
  unit_table   : Array[0..MAX_UNITS] of TUnitRec;

{ ============================================================
  Utilitaires generaux
  ============================================================ }

Function IntToStr(n : LongInt) : TString;
Var s : TString;
Begin
  Str(n, s);
  IntToStr := s;
End;

Function StrToInt(Const s : TString) : LongInt;
Var n : LongInt; code : Integer;
Begin
  Val(s, n, code);
  StrToInt := n;
End;

Function StrUpper(Const s : TString) : TString;
Var i : Integer; r : TString;
Begin
  r := s;
  For i := 1 To Length(r) Do
    If (r[i] >= 'a') And (r[i] <= 'z') Then
      r[i] := Chr(Ord(r[i]) - 32);
  StrUpper := r;
End;

Function ChangeExtension(Const fn, ext : TString) : TString;
Var i : Integer; base : TString;
Begin
  base := fn;
  i    := Length(base);
  While (i > 0) And (base[i] <> '.') And (base[i] <> '\') And (base[i] <> '/') Do
    Dec(i);
  If (i > 0) And (base[i] = '.') Then
    base := Copy(base, 1, i - 1);
  ChangeExtension := base + ext;
End;

Function PadRight(Const s : TString; n : Integer) : TString;
Var r : TString; i : Integer;
Begin
  r := s;
  While Integer(Length(r)) < n Do r := r + ' ';
  PadRight := r;
End;

{ Taille en octets d'un type de donnees Fortran 77 }
Function DataTypeSize(dt : TDataType; char_len : Integer) : Integer;
Begin
  Case dt Of
    DT_INTEGER   : DataTypeSize := 2;
    DT_REAL      : DataTypeSize := 4;
    DT_DOUBLE    : DataTypeSize := 8;
    DT_COMPLEX   : DataTypeSize := 8;
    DT_LOGICAL   : DataTypeSize := 2;
    DT_CHARACTER : DataTypeSize := char_len;
  Else
    DataTypeSize := 2;
  End;
End;

{ Nom lisible d'un type de donnees }
Function DataTypeName(dt : TDataType) : TString;
Begin
  Case dt Of
    DT_INTEGER   : DataTypeName := 'INTEGER';
    DT_REAL      : DataTypeName := 'REAL';
    DT_DOUBLE    : DataTypeName := 'DOUBLE PRECISION';
    DT_COMPLEX   : DataTypeName := 'COMPLEX';
    DT_LOGICAL   : DataTypeName := 'LOGICAL';
    DT_CHARACTER : DataTypeName := 'CHARACTER';
  Else
    DataTypeName := 'UNKNOWN';
  End;
End;

{ Directives ASM correspondant a un type (pour DATA) }
Function DataTypeDir(dt : TDataType) : TString;
Begin
  Case dt Of
    DT_INTEGER   : DataTypeDir := 'DW';   { 2 octets         }
    DT_REAL      : DataTypeDir := 'DD';   { 4 octets         }
    DT_DOUBLE    : DataTypeDir := 'DQ';   { 8 octets         }
    DT_COMPLEX   : DataTypeDir := 'DQ';   { 8 octets re+im   }
    DT_LOGICAL   : DataTypeDir := 'DW';   { 2 octets 0/-1    }
    DT_CHARACTER : DataTypeDir := 'DB';   { octets bruts      }
  Else
    DataTypeDir := 'DW';
  End;
End;

{ ============================================================
  Messages d'erreur et avertissements
  ============================================================ }

Procedure ErrorMsg(Const msg : TString);
Begin
  Writeln('** ERREUR ligne ', log_lineno, ' : ', msg);
  Inc(err_count);
  If err_count >= MAX_ERRORS Then
  Begin
    Writeln('Trop d''erreurs - compilation arretee.');
    Halt(1);
  End;
End;

Procedure WarnMsg(Const msg : TString);
Begin
  Writeln('   AVERT  ligne ', log_lineno, ' : ', msg);
  Inc(warn_count);
End;

Procedure NoteMsg(Const msg : TString);
Begin
  If opt_verbose Then
    Writeln('   Info   : ', msg);
End;

{ ============================================================
  Initialisation des tables
  ============================================================ }

Procedure InitTables;
Var i : Integer; c : Char;
Begin
  New(sym_table);
  New(proc_table);
  New(lbl_table);
  New(common_table);
  New(fmt_table);

  sym_count    := 0;
  proc_count   := 0;
  lbl_count    := 0;
  common_count := 0;
  fmt_count    := 0;
  equiv_count  := 0;
  err_count    := 0;
  warn_count   := 0;
  instr_count  := 0;
  str_lit_count:= 0;
  branch_lbl_count := 0;
  data_lbl_count   := 0;
  phys_lines   := 0;

  src_eof      := False;
  New(log_rec);
  log_rec_len  := 0;
  log_pos      := 1;
  log_label    := 0;
  log_is_comm  := False;
  log_lineno   := 0;
  has_peek_phys := False;
  peek_phys_buf := '';

  has_peek     := False;

  prog_name    := 'MAIN';
  cur_proc_idx := 0;
  cur_unit_kw  := 'PROGRAM';

  { Typage implicite F77 par defaut : I-N INTEGER, reste REAL }
  impl_none := False;
  For c := 'A' To 'Z' Do
  Begin
    If (c >= 'I') And (c <= 'N') Then
      impl_type[c] := DT_INTEGER
    Else
      impl_type[c] := DT_REAL;
  End;

  if_depth  := 0;
  do_depth  := 0;
  last_stmt_lbl := 0;
  cur_ret_lbl   := '';
  cur_subr_name := '';
  cur_func_result_si := 0;
  cur_func_ret_type  := DT_NONE;
  prog_epilogue_done := False;
  in_block_data   := False;
  block_data_name := '';
  called_list_cnt := 0;
  pre_ident       := '';
  tmp_file_open   := False;

  opt_verbose := False;
  opt_debug   := False;
  opt_no_rt   := False;

  For i := 0 To MAX_UNITS Do
  Begin
    unit_table[i].number  := i;
    unit_table[i].handle  := 0;
    unit_table[i].is_open := False;
    unit_table[i].fname   := '';
  End;
  { unites standard DOS }
  unit_table[5].is_open := True;
  unit_table[5].fname   := 'STDIN';
  unit_table[6].is_open := True;
  unit_table[6].fname   := 'STDOUT';
End;

{ ============================================================
  Affichage d'aide et traitement de la ligne de commande
  ============================================================ }

Procedure ParseArgs;
Var i : Integer; arg : TString;
Begin
  src_fname := '';
  out_fname := '';

  For i := 1 To ParamCount Do
  Begin
    arg := StrUpper(ParamStr(i));
    If arg = '-V' Then
      opt_verbose := True
    Else If arg = '-D' Then
      opt_debug := True
    Else If arg = '-NR' Then
      opt_no_rt := True
    Else If src_fname = '' Then
      src_fname := ParamStr(i)
    Else If out_fname = '' Then
      out_fname := ParamStr(i);
  End;

  If src_fname = '' Then Begin
    WriteLn('Fichier source requis !');
    Halt(1);
  End;

  If out_fname = '' Then
    out_fname := ChangeExtension(src_fname, '.ASM');

  tmp_fname := ChangeExtension(src_fname, '.TMP');
  str_fname := ChangeExtension(src_fname, '.STR');
End;

{ Ouvrir les fichiers source et sortie }
Procedure OpenFiles;
Begin
  Assign(src_file, src_fname);
  Reset(src_file);
  If IOResult <> 0 Then
  Begin
    Writeln('Impossible d''ouvrir le source : ', src_fname);
    Halt(1);
  End;

  Assign(out_file, out_fname);
  Rewrite(out_file);
  If IOResult <> 0 Then
  Begin
    Writeln('Impossible de creer : ', out_fname);
    Halt(1);
  End;

  Assign(tmp_file, tmp_fname);
  Rewrite(tmp_file);
  If IOResult <> 0 Then
  Begin
    Writeln('Impossible de creer : ', tmp_fname);
    Halt(1);
  End;
  tmp_file_open := True;

  cur_out := @out_file;

  If opt_verbose Then
  Begin
    Writeln('Source  : ', src_fname);
    Writeln('Sortie  : ', out_fname);
  End;
End;

Procedure CloseFiles;
Begin
  Close(src_file);
  {$I-} Close(out_file); {$I+}
  If tmp_file_open Then
  Begin
    {$I-} Close(tmp_file); {$I+}
    tmp_file_open := False;
  End;
End;

{ --------------------------------------------------------------------------
  AppendTmpToOut : fermer tmp_file, le relire, et appender a out_file.
  Appele apres GenRuntimeRoutines et avant GenFileEnd.
  -------------------------------------------------------------------------- }
Procedure AppendTmpToOut;
Var
  rd : Text;
  ln : TString;
Begin
  { Fermer la sortie principale et la reuvrir en mode append }
  {$I-} Close(out_file); {$I+}
  Assign(out_file, out_fname);
  {$I-} Append(out_file); {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('AppendTmpToOut : impossible de rouvrir ' + out_fname);
    Exit;
  End;

  { Fermer tmp_file et le relire depuis le debut }
  {$I-} Close(tmp_file); {$I+}
  tmp_file_open := False;
  Assign(rd, tmp_fname);
  {$I-} Reset(rd); {$I+}
  If IOResult <> 0 Then Exit;  { tmp vide ou absent, OK }

  While Not Eof(rd) Do
  Begin
    Readln(rd, ln);
    Writeln(out_file, ln);
  End;
  Close(rd);
End;

Procedure SwitchToMain;
Begin
  cur_out := @out_file;
End;

Procedure SwitchToTmp;
Begin
  cur_out := @tmp_file;
End;

{ ============================================================
  LECTEUR DE SOURCE A FORMAT FIXE
  ============================================================ }

{ --------------------------------------------------------------------------
  Format fixe Fortran 77 :
    Col 1     : 'C' ou '*' -> ligne de commentaire (ignoree)
    Col 1-5   : etiquette numerique (chiffres seulement, blancs -> 0)
    Col 6     : indicateur de continuation (non-blanc et non-'0' -> suite)
    Col 7-72  : corps de l'instruction
    Col 73-80 : identification (ignoree)
  Les lignes de continuation sont assemblees en un seul enregistrement
  logique de longueur max MAX_LOGLINE chars.
  Les espaces ne sont PAS significatifs en dehors des chaines litterales
  (la norme F77 autorise leur suppression).
  -------------------------------------------------------------------------- }

{ Lire une ligne physique depuis src_file.
  Retourne False si fin de fichier.
  Stocke la ligne dans phys_buf (sans le saut de ligne). }
Const
  PHYS_MAX = 255;

Var
  phys_buf     : String[255];        { ligne physique courante brute      }
  phys_lineno  : Integer;            { numero de ligne physique courante  }

Function SrcReadPhysLine : Boolean;
Var c : Char; i : Integer;
Begin
  phys_buf := '';
  { Utiliser la ligne pre-lue par SrcIsContinued si disponible }
  If has_peek_phys Then
  Begin
    phys_buf      := peek_phys_buf;
    has_peek_phys := False;
    SrcReadPhysLine := True;
    Exit;
  End;
  If Eof(src_file) Then
  Begin
    SrcReadPhysLine := False;
    src_eof := True;
    Exit;
  End;
  Readln(src_file, phys_buf);
  Inc(phys_lines);
  phys_lineno := phys_lines;
  { Expander a 80 colonnes avec des espaces si trop court }
  While Length(phys_buf) < 6 Do phys_buf := phys_buf + ' ';
  SrcReadPhysLine := True;
End;

{ Forward : SrcIsContinued est definie apres SrcNextLogRecord }
Function SrcIsContinued : Boolean; Forward;

{ --------------------------------------------------------------------------
  SrcNextLogRecord : assembler l'enregistrement logique suivant.
  Remplit log_rec^[1..log_rec_len], log_label, log_is_comm, log_lineno.
  Retourne False si fin de fichier (aucune instruction disponible).
  -------------------------------------------------------------------------- }
Function SrcNextLogRecord : Boolean;
Var
  first_line : Boolean;
  label_str  : String[5];
  col        : Integer;
  i          : Integer;
  body_start : Integer;
  body_end   : Integer;
  is_cont    : Boolean;
  c          : Char;
  n          : Integer;
  code       : Integer;
Begin
  log_rec_len := 0;
  log_label   := 0;
  log_is_comm := False;
  first_line  := True;

  Repeat
    { Lire la ligne physique suivante (sauter les commentaires) }
    Repeat
      If Not SrcReadPhysLine Then
      Begin
        If first_line Then
        Begin
          SrcNextLogRecord := False;
          src_eof := True;
          Exit;
        End;
        { Fin de fichier en milieu de continuation : ok, on retourne ce qu'on a }
        src_eof := True;
        SrcNextLogRecord := (log_rec_len > 0);
        Exit;
      End;

      { Colonne 1 : commentaire ? }
      c := phys_buf[1];
      If (c = 'C') Or (c = 'c') Or (c = '*') Or (phys_buf = '') Then
      Begin
        { Ligne de commentaire : ignorer et recommencer }
        Continue;
      End;
      Break;
    Until False;

    { --- Analyser la ligne physique --- }

    { Colonne 6 : indicateur de continuation }
    is_cont := False;
    If Length(phys_buf) >= 6 Then
    Begin
      c := phys_buf[6];
      is_cont := (c <> ' ') And (c <> '0') And (Not first_line);
    End;

    If first_line Then
    Begin
      log_lineno := phys_lineno;
      { Extraire l'etiquette des colonnes 1-5 (chiffres uniquement) }
      label_str := '';
      For i := 1 To 5 Do
      Begin
        If i <= Length(phys_buf) Then
        Begin
          c := phys_buf[i];
          If (c >= '0') And (c <= '9') Then
            label_str := label_str + c
          Else If c <> ' ' Then
          Begin
            ErrorMsg('Caractere invalide en colonne ' + IntToStr(i) +
                     ' (etiquette) : ' + c);
          End;
        End;
      End;
      If label_str <> '' Then
      Begin
        Val(label_str, n, code);
        If (code = 0) And (n >= 1) And (n <= 99999) Then
          log_label := n
        Else
          ErrorMsg('Etiquette invalide : ' + label_str);
      End;
      first_line := False;
    End;

    { Copier les colonnes 7-72 dans log_rec (sans les espaces insignifiants).
      NOTE : selon la norme F77, les blancs peuvent etre supprimes partout
      SAUF dans les constantes chaines ; ici on les conserve pour simplifier
      le lexer qui gerera lui-meme les blancs. }
    body_start := 7;
    body_end   := Length(phys_buf);
    If body_end > 72 Then body_end := 72;

    For i := body_start To body_end Do
    Begin
      If log_rec_len < MAX_LOGLINE Then
      Begin
        Inc(log_rec_len);
        log_rec^[log_rec_len] := phys_buf[i];
      End
      Else
        ErrorMsg('Enregistrement logique trop long (> ' +
                 IntToStr(MAX_LOGLINE) + ' chars)');
    End;

    { Verifier si la ligne suivante est une continuation }
    { On relit la prochaine ligne physique pour tester sa colonne 6 }
    { En pratique on lira en boucle grace au Repeat/Until ci-dessous }

    { Verifier si c'est une ligne totalement vide (corps vide apres concat) }
    { -> continuer a lire }

  Until Not SrcIsContinued;     { <- fonction definie ci-dessous }

  log_pos := 1;
  SrcNextLogRecord := (log_rec_len > 0);
End;

{ --------------------------------------------------------------------------
  SrcIsContinued : regarder si la PROCHAINE ligne physique est une suite.
  Utilise un mecanisme de "peek" sur src_file.
  Retourne True si la prochaine ligne physique a un caractere de continuation
  en colonne 6 (non espace, non '0').
  En sortie, phys_buf contient deja la prochaine ligne (elle est "consommee").
  -------------------------------------------------------------------------- }
Function SrcIsContinued : Boolean;
Var c : Char;
Begin
  { Si la ligne suivante est deja dans le tampon peek, la traiter }
  has_peek_phys := False;

  If Eof(src_file) Then
  Begin
    SrcIsContinued := False;
    Exit;
  End;

  Readln(src_file, peek_phys_buf);
  Inc(phys_lines);
  phys_lineno := phys_lines;

  { Commentaire -> ce n'est pas une continuation, mais on l'ignore }
  While (Length(peek_phys_buf) > 0) And
        ((peek_phys_buf[1] = 'C') Or (peek_phys_buf[1] = 'c') Or
         (peek_phys_buf[1] = '*')) Do
  Begin
    If Eof(src_file) Then
    Begin
      SrcIsContinued := False;
      Exit;
    End;
    Readln(src_file, peek_phys_buf);
    Inc(phys_lines);
    phys_lineno := phys_lines;
  End;

  While Length(peek_phys_buf) < 6 Do peek_phys_buf := peek_phys_buf + ' ';

  c := peek_phys_buf[6];
  If (c <> ' ') And (c <> '0') Then
  Begin
    { Ligne de continuation : la mettre dans phys_buf et signaler }
    phys_buf := peek_phys_buf;
    SrcIsContinued := True;
  End
  Else
  Begin
    { Pas une continuation : on a lu une ligne en trop.
      La memo dans has_peek_phys pour la reutiliser au prochain appel. }
    has_peek_phys := True;
    SrcIsContinued := False;
  End;
End;

{ --------------------------------------------------------------------------
  Accesseurs sur l'enregistrement logique courant (utilises par le lexer).
  -------------------------------------------------------------------------- }

{ Caractere courant de l'enregistrement logique }
Function LogCurChar : Char;
Begin
  If log_pos <= log_rec_len Then
    LogCurChar := log_rec^[log_pos]
  Else
    LogCurChar := #0;
End;

{ Caractere suivant (peek) sans avancer }
Function LogPeekChar : Char;
Begin
  If log_pos + 1 <= log_rec_len Then
    LogPeekChar := log_rec^[log_pos + 1]
  Else
    LogPeekChar := #0;
End;

{ Avancer d'un caractere dans l'enregistrement }
Procedure LogAdvance;
Begin
  If log_pos <= log_rec_len Then
    Inc(log_pos);
End;

{ Sauter les espaces insignifiants dans l'enregistrement logique }
Procedure LogSkipBlanks;
Begin
  While (log_pos <= log_rec_len) And (log_rec^[log_pos] = ' ') Do
    Inc(log_pos);
End;

{ Fin de l'enregistrement logique courant ? }
Function LogAtEnd : Boolean;
Begin
  LogAtEnd := (log_pos > log_rec_len);
End;

{ --------------------------------------------------------------------------
  Lire une sous-chaine de l'enregistrement logique a partir de log_pos
  tant que le predicat est vrai. Retourne la chaine et avance log_pos.
  -------------------------------------------------------------------------- }
Function LogReadWhile(Const isOk : Boolean) : TString;
Begin
  { non-utilise : le lexer lit caractere par caractere }
  LogReadWhile := '';
End;

{ --------------------------------------------------------------------------
  SrcInit : reinitialiser le lecteur de source pour une unite de programme.
  A appeler apres chaque END rencontre.
  -------------------------------------------------------------------------- }
Procedure SrcInit;
Begin
  log_rec_len  := 0;
  log_pos      := 1;
  log_label    := 0;
  log_is_comm  := False;
  has_peek_phys := False;
End;

{ ============================================================
  ANALYSEUR LEXICAL (LEXER)
  ============================================================
  Lit les tokens Fortran 77 depuis l'enregistrement logique courant
  (log_rec^ via LogCurChar / LogAdvance / LogAtEnd).
  En F77 les espaces sont non-significatifs en dehors des chaines
  litterales : LogSkipBlanks est appele systematiquement.

  Organisation :
    LexDoRead(var tok)  -- lecture effective (interne)
    LexNext             -- avance cur_tok (utilise has_peek si disponible)
    LexPeekKind/LexPeekVal  -- consulte le token suivant sans consommer
    LexExpect(val)      -- assertion sur cur_tok.val + avance
    LexExpectKind(k)    -- assertion sur cur_tok.kind + avance
    LexInit             -- initialise le lexer, lit le 1er enregistrement

  Table des mots-cles statique (typed const Turbo Pascal).
  ============================================================ }

Const
  LEX_KW_COUNT = 44;

Type
  TKeyword = String[20];

Const
  LEX_KW : Array[1..LEX_KW_COUNT] of TKeyword = (
    { Instructions }
    'PROGRAM','SUBROUTINE','FUNCTION','BLOCKDATA','END',
    'STOP','PAUSE','RETURN','CALL',
    'COMMON','EQUIVALENCE','DIMENSION','IMPLICIT',
    'EXTERNAL','INTRINSIC','SAVE','PARAMETER',
    'DATA','FORMAT','INCLUDE',
    'IF','THEN','ELSE','ELSEIF','ENDIF',
    'DO','CONTINUE','GOTO','ASSIGN',
    'READ','WRITE','PRINT',
    'OPEN','CLOSE','REWIND','BACKSPACE','ENDFILE','INQUIRE',
    { Types }
    'INTEGER','REAL','DOUBLEPRECISION','COMPLEX',
    'LOGICAL','CHARACTER'
  );

{ Verifie si s est un mot-cle F77. }
Function LexIsKeyword(Const s : TString) : Boolean;
Var i : Integer;
Begin
  LexIsKeyword := False;
  For i := 1 To LEX_KW_COUNT Do
    If s = LEX_KW[i] Then
    Begin
      LexIsKeyword := True;
      Exit;
    End;
End;

{ --------------------------------------------------------------------------
  KwSplitAt : teste si token commence par prefix, retourne le suffixe.
  Utilise pour separer mot-cle et identifiant colles (F77 blank-stripping).
  -------------------------------------------------------------------------- }
Function KwSplitAt(Const token, prefix : TString; Var suffix : TString) : Boolean;
Var plen : Integer;
Begin
  plen := Length(prefix);
  If (Length(token) >= plen) And (Copy(token, 1, plen) = prefix) Then
  Begin
    suffix := Copy(token, plen + 1, 255);
    KwSplitAt := True;
  End
  Else
  Begin
    suffix := '';
    KwSplitAt := False;
  End;
End;

{ --------------------------------------------------------------------------
  LexSplitKw : si s commence par un mot-cle reconnu suivi d'un identifiant,
  retourne True, s := le mot-cle, pending_id := le suffixe.
  Appele apres LexReadLetters pour gerer le blank-stripping F77.
  -------------------------------------------------------------------------- }
Function LexSplitKw(Var s : TString) : Boolean;
Var rest : TString;
Begin
  LexSplitKw := False;
  rest := '';
  { Tester du plus long au plus court }
  If      KwSplitAt(s, 'DOUBLEPRECISION', rest) And LexIsKeyword('DOUBLEPRECISION') Then
    Begin s := 'DOUBLEPRECISION'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'SUBROUTINE', rest) And LexIsKeyword('SUBROUTINE') Then
    Begin s := 'SUBROUTINE'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'BLOCKDATA', rest) And LexIsKeyword('BLOCKDATA') Then
    Begin s := 'BLOCKDATA'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'FUNCTION', rest) And LexIsKeyword('FUNCTION') And (rest <> '') Then
    Begin s := 'FUNCTION'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'INTEGER', rest) And LexIsKeyword('INTEGER') And (rest <> '') Then
    Begin s := 'INTEGER'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'REAL', rest) And LexIsKeyword('REAL') And (rest <> '') Then
    Begin s := 'REAL'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'LOGICAL', rest) And LexIsKeyword('LOGICAL') And (rest <> '') Then
    Begin s := 'LOGICAL'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'CHARACTER', rest) And LexIsKeyword('CHARACTER') And (rest <> '') Then
    Begin s := 'CHARACTER'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'COMPLEX', rest) And LexIsKeyword('COMPLEX') And (rest <> '') Then
    Begin s := 'COMPLEX'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'CALL', rest) And LexIsKeyword('CALL') And (rest <> '') Then
    Begin s := 'CALL'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'PROGRAM', rest) And LexIsKeyword('PROGRAM') And (rest <> '') Then
    Begin s := 'PROGRAM'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'DIMENSION', rest) And LexIsKeyword('DIMENSION') And (rest <> '') Then
    Begin s := 'DIMENSION'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'EQUIVALENCE', rest) And LexIsKeyword('EQUIVALENCE') And (rest <> '') Then
    Begin s := 'EQUIVALENCE'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'PARAMETER', rest) And LexIsKeyword('PARAMETER') And (rest <> '') Then
    Begin s := 'PARAMETER'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'EXTERNAL', rest) And LexIsKeyword('EXTERNAL') And (rest <> '') Then
    Begin s := 'EXTERNAL'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'INTRINSIC', rest) And LexIsKeyword('INTRINSIC') And (rest <> '') Then
    Begin s := 'INTRINSIC'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'IMPLICIT', rest) And LexIsKeyword('IMPLICIT') And (rest <> '') Then
    Begin s := 'IMPLICIT'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'COMMON', rest) And LexIsKeyword('COMMON') And (rest <> '') Then
    Begin s := 'COMMON'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'DATA', rest) And LexIsKeyword('DATA') And (rest <> '') Then
    Begin s := 'DATA'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'SAVE', rest) And LexIsKeyword('SAVE') And (rest <> '') Then
    Begin s := 'SAVE'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'PRINT', rest) And LexIsKeyword('PRINT') And (rest <> '') Then
    Begin s := 'PRINT'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'WRITE', rest) And LexIsKeyword('WRITE') And (rest <> '') Then
    Begin s := 'WRITE'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'READ', rest) And LexIsKeyword('READ') And (rest <> '') Then
    Begin s := 'READ'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'FORMAT', rest) And LexIsKeyword('FORMAT') And (rest <> '') Then
    Begin s := 'FORMAT'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'GOTO', rest) And LexIsKeyword('GOTO') And (rest <> '') Then
    Begin s := 'GOTO'; pending_id := rest; LexSplitKw := True; Exit; End
  Else If KwSplitAt(s, 'RETURN', rest) And LexIsKeyword('RETURN') And (rest <> '') Then
    Begin s := 'RETURN'; pending_id := rest; LexSplitKw := True; Exit; End;
End;

{ ---- Lecture de la partie alphabetique dans log_rec (skip blancs). ---- }
Function LexReadLetters : TString;
Var s : TString; c : Char;
Begin
  s := '';
  LogSkipBlanks;
  While (Not LogAtEnd) And (LogCurChar In ['A'..'Z','a'..'z']) Do
  Begin
    c := LogCurChar;
    If (c >= 'a') And (c <= 'z') Then c := Chr(Ord(c) - 32);
    If Length(s) < MAX_STR Then s := s + c;
    LogAdvance;
    LogSkipBlanks;
  End;
  LexReadLetters := s;
End;

{ ---- Lecture de lettres + chiffres (suite d'un identifiant). ---- }
Function LexReadAlphaNum : TString;
Var s : TString; c : Char;
Begin
  s := '';
  LogSkipBlanks;
  While (Not LogAtEnd) And (LogCurChar In ['A'..'Z','a'..'z','0'..'9']) Do
  Begin
    c := LogCurChar;
    If (c >= 'a') And (c <= 'z') Then c := Chr(Ord(c) - 32);
    If Length(s) < MAX_STR Then s := s + c;
    LogAdvance;
    LogSkipBlanks;
  End;
  LexReadAlphaNum := s;
End;

{ ---- Lecture de chiffres decimaux depuis log_rec. ---- }
Function LexReadDigits : TString;
Var s : TString;
Begin
  s := '';
  While (Not LogAtEnd) And (LogCurChar In ['0'..'9']) Do
  Begin
    If Length(s) < MAX_STR Then s := s + LogCurChar;
    LogAdvance;
  End;
  LexReadDigits := s;
End;

{ --------------------------------------------------------------------------
  LexDoRead : lecture effective d un token dans tok.
  Appele par LexNext et LexPeekKind/LexPeekVal.
  Quand l enregistrement logique est epuise, retourne TK_NEWLINE
  et charge automatiquement le suivant (ou TK_EOF si fin de fichier).
  -------------------------------------------------------------------------- }
Procedure LexDoRead(Var tok : TToken);
Var
  c      : Char;
  s, t   : TString;
  n      : Integer;
  code   : Integer;
  hlen   : Integer;
  i      : Integer;
  is_dbl : Boolean;
Begin
  { Identifiant mis en attente par un split de mot-cle precedent }
  If pending_id <> '' Then
  Begin
    s          := pending_id;
    pending_id := '';
    tok.line   := log_lineno;
    tok.col    := log_pos;
    tok.val    := '';
    tok.int_val  := 0;
    tok.real_val := 0;
    tok.lbl_num  := 0;
    If LexIsKeyword(s) Then
    Begin
      tok.kind := TK_KEYWORD;
      tok.val  := s;
    End
    Else If LexSplitKw(s) Then
    Begin
      tok.kind := TK_KEYWORD;
      tok.val  := s;
    End
    Else
    Begin
      If Length(s) > 6 Then s := Copy(s, 1, 6);
      tok.kind := TK_IDENT;
      tok.val  := s;
    End;
    Exit;
  End;

  LogSkipBlanks;

  { Fin de l enregistrement logique courant -> TK_NEWLINE }
  If LogAtEnd Then
  Begin
    tok.kind    := TK_NEWLINE;
    tok.val     := '';
    tok.lbl_num := log_label;
    tok.line    := log_lineno;
    tok.col     := 0;
    { Pre-charger le prochain enregistrement pour le prochain appel }
    If Not SrcNextLogRecord Then
    Begin
      tok.kind := TK_EOF;  { Fin de fichier immediate }
    End;
    Exit;
  End;

  c := LogCurChar;
  tok.line := log_lineno;
  tok.col  := log_pos;
  tok.val  := '';
  tok.int_val  := 0;
  tok.real_val := 0;
  tok.lbl_num  := 0;

  { ---- Chaine litterale Fortran : 'abc' (apostrophe doublee = '') ---- }
  If c = '''' Then
  Begin
    LogAdvance;
    s := '';
    Repeat
      If LogAtEnd Then
      Begin
        ErrorMsg('Chaine litterale non fermee en fin d enregistrement');
        Break;
      End;
      If LogCurChar = '''' Then
      Begin
        LogAdvance;
        If (Not LogAtEnd) And (LogCurChar = '''') Then
        Begin
          s := s + '''';
          LogAdvance;
        End
        Else
          Break;
      End
      Else
      Begin
        s := s + LogCurChar;
        LogAdvance;
      End;
    Until False;
    tok.kind := TK_STRING;
    tok.val  := s;
    Exit;
  End;

  { ---- Entier ou reel commencant par un chiffre ---- }
  If c In ['0'..'9'] Then
  Begin
    s := LexReadDigits;

    { Hollerith : nHccc... }
    If (Not LogAtEnd) And (LogCurChar In ['H','h']) Then
    Begin
      Val(s, hlen, code);
      If (code = 0) And (hlen > 0) Then
      Begin
        LogAdvance;  { consommer 'H' }
        t := '';
        For i := 1 To hlen Do
        Begin
          If LogAtEnd Then Break;
          t := t + LogCurChar;
          LogAdvance;
        End;
        tok.kind    := TK_HOLLERITH;
        tok.val     := t;
        tok.int_val := hlen;
        Exit;
      End;
    End;

    { Reel : n.m  ou  n.mE+p  ou  n.mD+p }
    If (Not LogAtEnd) And (LogCurChar = '.') Then
    Begin
      s := s + '.'; LogAdvance;
      s := s + LexReadDigits;
      is_dbl := False;
      If Not LogAtEnd Then
      Begin
        If LogCurChar In ['E','e'] Then
        Begin
          s := s + 'E'; LogAdvance;
          If (Not LogAtEnd) And (LogCurChar In ['+','-']) Then
          Begin s := s + LogCurChar; LogAdvance; End;
          s := s + LexReadDigits;
        End
        Else If LogCurChar In ['D','d'] Then
        Begin
          s := s + 'D'; LogAdvance; is_dbl := True;
          If (Not LogAtEnd) And (LogCurChar In ['+','-']) Then
          Begin s := s + LogCurChar; LogAdvance; End;
          s := s + LexReadDigits;
        End;
      End;
      tok.val := s;
      If is_dbl Then tok.kind := TK_DOUBLE Else tok.kind := TK_REAL;
      Exit;
    End;

    { Exposant direct sur entier : 1E3  ou  1D3 }
    If Not LogAtEnd Then
    Begin
      If LogCurChar In ['E','e'] Then
      Begin
        s := s + 'E'; LogAdvance;
        If (Not LogAtEnd) And (LogCurChar In ['+','-']) Then
        Begin s := s + LogCurChar; LogAdvance; End;
        s := s + LexReadDigits;
        tok.kind := TK_REAL; tok.val := s;
        Exit;
      End
      Else If LogCurChar In ['D','d'] Then
      Begin
        s := s + 'D'; LogAdvance;
        If (Not LogAtEnd) And (LogCurChar In ['+','-']) Then
        Begin s := s + LogCurChar; LogAdvance; End;
        s := s + LexReadDigits;
        tok.kind := TK_DOUBLE; tok.val := s;
        Exit;
      End;
    End;

    { Entier simple }
    Val(s, n, code);
    tok.kind    := TK_INTEGER;
    tok.val     := s;
    tok.int_val := n;
    Exit;
  End;

  { ---- Operateurs ponctuels : .EQ. .AND. .TRUE. .5 ---- }
  If c = '.' Then
  Begin
    LogAdvance;
    LogSkipBlanks;

    { Reel commencant par un point : .5E3 }
    If (Not LogAtEnd) And (LogCurChar In ['0'..'9']) Then
    Begin
      s := '.' + LexReadDigits;
      is_dbl := False;
      If Not LogAtEnd Then
      Begin
        If LogCurChar In ['E','e'] Then
        Begin
          s := s + 'E'; LogAdvance;
          If (Not LogAtEnd) And (LogCurChar In ['+','-']) Then
          Begin s := s + LogCurChar; LogAdvance; End;
          s := s + LexReadDigits;
        End
        Else If LogCurChar In ['D','d'] Then
        Begin
          s := s + 'D'; LogAdvance; is_dbl := True;
          If (Not LogAtEnd) And (LogCurChar In ['+','-']) Then
          Begin s := s + LogCurChar; LogAdvance; End;
          s := s + LexReadDigits;
        End;
      End;
      tok.val := s;
      If is_dbl Then tok.kind := TK_DOUBLE Else tok.kind := TK_REAL;
      Exit;
    End;

    { Mot entre points : .TRUE. .FALSE. .EQ. .AND. etc. }
    s := LexReadLetters;
    { Consommer le '.' fermant }
    If (Not LogAtEnd) And (LogCurChar = '.') Then LogAdvance;

    If (s = 'TRUE') Or (s = 'FALSE') Then
    Begin
      tok.kind    := TK_LOGICAL;
      tok.val     := s;
      tok.int_val := Ord(s = 'TRUE');
      Exit;
    End;
    If (s = 'EQ') Or (s = 'NE') Or (s = 'LT') Or
       (s = 'LE') Or (s = 'GT') Or (s = 'GE') Then
    Begin
      tok.kind := TK_RELOP; tok.val := s; Exit;
    End;
    If (s = 'AND') Or (s = 'OR') Or (s = 'NOT') Or
       (s = 'EQV') Or (s = 'NEQV') Then
    Begin
      tok.kind := TK_LOGOP; tok.val := s; Exit;
    End;

    If s = '' Then
      ErrorMsg('Point decimal isole inattendu')
    Else
      ErrorMsg('Operateur point inconnu : .' + s + '.');
    tok.kind := TK_OP;
    tok.val  := '.' + s + '.';
    Exit;
  End;

  { ---- ** et * ---- }
  If c = '*' Then
  Begin
    LogAdvance;
    If (Not LogAtEnd) And (LogCurChar = '*') Then
    Begin LogAdvance; tok.kind := TK_OP; tok.val := '**'; End
    Else
    Begin tok.kind := TK_OP; tok.val := '*'; End;
    Exit;
  End;

  { ---- // et / ---- }
  If c = '/' Then
  Begin
    LogAdvance;
    If (Not LogAtEnd) And (LogCurChar = '/') Then
    Begin LogAdvance; tok.kind := TK_OP; tok.val := '//'; End
    Else
    Begin tok.kind := TK_OP; tok.val := '/'; End;
    Exit;
  End;

  { ---- Operateurs et ponctuation simples ---- }
  If c = '+' Then Begin LogAdvance; tok.kind := TK_OP;    tok.val := '+'; Exit; End;
  If c = '-' Then Begin LogAdvance; tok.kind := TK_OP;    tok.val := '-'; Exit; End;
  If c = '=' Then Begin LogAdvance; tok.kind := TK_PUNCT; tok.val := '='; Exit; End;
  If c = '(' Then Begin LogAdvance; tok.kind := TK_PUNCT; tok.val := '('; Exit; End;
  If c = ')' Then Begin LogAdvance; tok.kind := TK_PUNCT; tok.val := ')'; Exit; End;
  If c = ',' Then Begin LogAdvance; tok.kind := TK_PUNCT; tok.val := ','; Exit; End;
  If c = ':' Then Begin LogAdvance; tok.kind := TK_PUNCT; tok.val := ':'; Exit; End;

  { ---- Identifiant ou mot-cle ---- }
  If c In ['A'..'Z','a'..'z'] Then
  Begin
    { Lire partie alphabetique seulement (les blancs sont sautes) }
    s := LexReadLetters;

    { Cas DOUBLE + PRECISION (deux mots separes ou colles) }
    If s = 'DOUBLE' Then
    Begin
      LogSkipBlanks;
      If Not LogAtEnd Then
      Begin
        t := LexReadLetters;
        If t = 'PRECISION' Then s := 'DOUBLEPRECISION'
        Else
        Begin
          { 't' consomme mais pas reconnu -> on le perd ; signaler }
          WarnMsg('Attendu PRECISION apres DOUBLE, obtenu : ' + t);
        End;
      End;
    End;

    { Mot-cle reconnu : retourner TK_KEYWORD }
    If LexIsKeyword(s) Then
    Begin
      tok.kind := TK_KEYWORD;
      tok.val  := s;
      Exit;
    End;

    { Keyword colle a un identifiant (F77 blank-strip) : separer }
    If LexSplitKw(s) Then
    Begin
      tok.kind := TK_KEYWORD;
      tok.val  := s;
      Exit;  { pending_id contient le suffixe }
    End;

    { Sinon : lire la suite alphanumerique de l identifiant }
    t := LexReadAlphaNum;
    s := s + t;
    If Length(s) > 6 Then
    Begin
      WarnMsg('Identifiant trop long (max 6 car. en F77) : ' + s);
      s := Copy(s, 1, 6);
    End;
    tok.kind := TK_IDENT;
    tok.val  := s;
    Exit;
  End;

  { ---- Caractere inconnu : signaler et avancer ---- }
  ErrorMsg('Caractere inattendu : ' + c);
  LogAdvance;
  tok.kind := TK_OP;
  tok.val  := c;
End;

{ --------------------------------------------------------------------------
  LexNext : avance cur_tok vers le token suivant.
  Si un token a ete pre-lu par LexEnsurePeek (has_peek=True),
  le retourne directement sans relire la source.
  -------------------------------------------------------------------------- }
Procedure LexNext;
Begin
  If has_peek Then
  Begin
    cur_tok  := peek_tok;
    has_peek := False;
    Exit;
  End;
  LexDoRead(cur_tok);
End;

{ --------------------------------------------------------------------------
  LexPeekKind / LexPeekVal : consulte le prochain token sans consommer
  cur_tok.  En Turbo Pascal, une fonction ne peut pas retourner un record ;
  on expose deux accesseurs scalaires sur le token mis en cache (peek_tok).
  -------------------------------------------------------------------------- }
Procedure LexEnsurePeek;
Begin
  If Not has_peek Then
  Begin
    LexDoRead(peek_tok);
    has_peek := True;
  End;
End;

Function LexPeekKind : TTokenKind;
Begin
  LexEnsurePeek;
  LexPeekKind := peek_tok.kind;
End;

Function LexPeekVal : TString;
Begin
  LexEnsurePeek;
  LexPeekVal := peek_tok.val;
End;

{ --------------------------------------------------------------------------
  LexExpect : verifie cur_tok.val = val puis avance. Sinon erreur.
  -------------------------------------------------------------------------- }
Procedure LexExpect(Const val : TString);
Begin
  If cur_tok.val <> val Then
    ErrorMsg('Attendu ''' + val + ''', obtenu ''' + cur_tok.val + '''');
  LexNext;
End;

{ --------------------------------------------------------------------------
  LexExpectKind : verifie cur_tok.kind = k puis avance. Sinon erreur.
  -------------------------------------------------------------------------- }
Procedure LexExpectKind(k : TTokenKind);
Const
  TK_NAME : Array[TK_IDENT..TK_EOF] of String[12] = (
    'IDENT','INTEGER','REAL','DOUBLE','STRING','LOGICAL',
    'HOLLERITH','KEYWORD','RELOP','LOGOP','OP','PUNCT',
    'LABEL','NEWLINE','EOF'
  );
Begin
  If cur_tok.kind <> k Then
    ErrorMsg('Token attendu : ' + TK_NAME[k] +
             ', obtenu : ' + TK_NAME[cur_tok.kind] +
             ' (''' + cur_tok.val + ''')');
  LexNext;
End;

{ --------------------------------------------------------------------------
  LexInit : initialise le lexer pour le debut de la compilation.
  Lit le premier enregistrement logique et remplit cur_tok.
  -------------------------------------------------------------------------- }
Procedure LexInit;
Begin
  has_peek        := False;
  pending_id      := '';
  cur_tok.kind    := TK_NEWLINE;
  cur_tok.val     := '';
  cur_tok.lbl_num := 0;
  cur_tok.line    := 0;
  cur_tok.col     := 0;
  SrcInit;
  If SrcNextLogRecord Then
    LexNext
  Else
  Begin
    cur_tok.kind := TK_EOF;
    cur_tok.val  := '';
  End;
End;

{ ============================================================
  TABLE DES SYMBOLES ET PORTEE
  ============================================================
  En Fortran 77 il n'y a qu'une seule portee par unite de programme
  (PROGRAM / SUBROUTINE / FUNCTION / BLOCK DATA).  Pas de portees
  imbriquees.  Les blocs COMMON et les noms de procedures sont
  "globaux" (scope_unit = 0).

  Fonctions exposees :
    SymFind(name)             -- cherche dans portee courante + globale
    SymFindLocal(name)        -- cherche uniquement dans l'unite courante
    SymEnter(name,kind,dtype) -- cree un nouveau symbole
    SymReset                  -- purge les symboles de l'unite courante

    LabelFind(num)            -- cherche une etiquette par numero
    LabelEnter(num)           -- cree si necessaire, retourne index
    LabelMarkDefined(num,ln)  -- marque l'etiquette comme vue dans source
    LabelCheckAll             -- verifie les ref. non definies apres END
    LabelReset                -- purge la table pour une nouvelle unite

    CommonFind(name)          -- cherche un bloc COMMON par nom
    CommonEnter(name)         -- cree si necessaire, retourne index

    FmtFind(lbl_num)          -- cherche un FORMAT par etiquette
    FmtEnter(lbl_num, text)   -- enregistre un FORMAT
  ============================================================ }

{ --------------------------------------------------------------------------
  SymFindLocal : chercher un symbole dans l'unite de programme courante
  seulement. Ne remonte pas aux globaux (scope_unit = 0).
  Retourne l'index (1..sym_count) ou 0 si non trouve.
  -------------------------------------------------------------------------- }
Function SymFindLocal(Const aname : TString) : Integer;
Var i : Integer;
Begin
  SymFindLocal := 0;
  For i := 1 To sym_count Do
    If (sym_table^[i].name = aname) And
       (sym_table^[i].scope_unit = cur_proc_idx) Then
    Begin
      SymFindLocal := i;
      Exit;
    End;
End;

{ --------------------------------------------------------------------------
  SymFind : chercher un symbole d'abord dans la portee courante,
  puis parmi les globaux (scope_unit = 0 : procedures, INTRINSIC…).
  Retourne l'index (1..sym_count) ou 0 si non trouve.
  -------------------------------------------------------------------------- }
Function SymFind(Const aname : TString) : Integer;
Var i : Integer;
Begin
  SymFind := 0;
  { 1. Unite courante }
  For i := 1 To sym_count Do
    If (sym_table^[i].name = aname) And
       (sym_table^[i].scope_unit = cur_proc_idx) Then
    Begin
      SymFind := i;
      Exit;
    End;
  { 2. Globaux }
  For i := 1 To sym_count Do
    If (sym_table^[i].name = aname) And
       (sym_table^[i].scope_unit = 0) Then
    Begin
      SymFind := i;
      Exit;
    End;
End;

{ --------------------------------------------------------------------------
  SymEnter : ajouter un nouveau symbole dans la table.
  Le nom est tronque a 6 chars avec avertissement si necessaire.
  Signale une erreur si le symbole existe deja dans l'unite courante.
  Retourne l'index cree (ou l'index existant en cas de doublon).
  -------------------------------------------------------------------------- }
Function SymEnter(Const aname : TString; akind : TSymKind;
                  adtype : TDataType) : Integer;
Var
  idx   : Integer;
  sname : TString;
  d     : Integer;
Begin
  SymEnter := 0;
  sname := aname;
  If Length(sname) > 6 Then
  Begin
    WarnMsg('Identifiant tronque a 6 chars : ' + sname);
    sname := Copy(sname, 1, 6);
  End;
  { Doublon dans la portee courante ? }
  idx := SymFindLocal(sname);
  If idx > 0 Then
  Begin
    ErrorMsg('Symbole deja declare dans cette unite : ' + sname);
    SymEnter := idx;
    Exit;
  End;
  { Place disponible ? }
  If sym_count >= MAX_SYM Then
  Begin
    ErrorMsg('Table symboles saturee (MAX=' + IntToStr(MAX_SYM) + ')');
    Exit;
  End;
  Inc(sym_count);
  idx := sym_count;
  With sym_table^[idx] Do
  Begin
    name       := sname;
    kind       := akind;
    dtype      := adtype;
    char_len   := 1;
    type_size  := DataTypeSize(adtype, 1);
    ndim       := 0;
    For d := 1 To MAX_DIM Do
    Begin
      dims[d].lb := 1;
      dims[d].ub := 0;
    End;
    asm_label  := 'FV_' + sname;
    bp_offset  := 0;
    is_save    := False;
    is_dummy   := False;
    is_defined := False;
    common_blk := 0;
    common_off := 0;
    equiv_grp  := 0;
    equiv_off  := 0;
    const_ival := 0;
    const_rval := 0;
    const_sval := '';
    proc_idx   := 0;
    scope_unit := cur_proc_idx;
  End;
  SymEnter := idx;
End;

{ --------------------------------------------------------------------------
  SymReset : supprimer tous les symboles appartenant a l'unite courante
  (scope_unit = cur_proc_idx).  Les symboles globaux (scope_unit = 0)
  sont conserves.  A appeler apres la generation de code d'une unite.
  -------------------------------------------------------------------------- }
Procedure SymReset;
Var i, j : Integer;
Begin
  j := 0;
  For i := 1 To sym_count Do
    If sym_table^[i].scope_unit <> cur_proc_idx Then
    Begin
      Inc(j);
      sym_table^[j] := sym_table^[i];
    End;
  sym_count := j;
End;

{ ==========================================================================
  Table des etiquettes numeriques (FORMAT, GOTO, DO …)
  ========================================================================== }

{ --------------------------------------------------------------------------
  LabelFind : chercher une etiquette par son numero.
  Retourne l'index (1..lbl_count) ou 0 si non trouvee.
  -------------------------------------------------------------------------- }
Function LabelFind(anum : Integer) : Integer;
Var i : Integer;
Begin
  LabelFind := 0;
  For i := 1 To lbl_count Do
    If lbl_table^[i].num = anum Then
    Begin
      LabelFind := i;
      Exit;
    End;
End;

{ --------------------------------------------------------------------------
  LabelEnter : creer une entree pour l'etiquette anum si elle n'existe pas.
  Retourne l'index existant ou nouvellement cree (0 si table saturee).
  -------------------------------------------------------------------------- }
Function LabelEnter(anum : Integer) : Integer;
Var idx : Integer;
Begin
  idx := LabelFind(anum);
  If idx > 0 Then
  Begin
    LabelEnter := idx;
    Exit;
  End;
  If lbl_count >= MAX_LABELS Then
  Begin
    ErrorMsg('Table etiquettes saturee (MAX=' + IntToStr(MAX_LABELS) + ')');
    LabelEnter := 0;
    Exit;
  End;
  Inc(lbl_count);
  idx := lbl_count;
  With lbl_table^[idx] Do
  Begin
    num        := anum;
    asm_label  := 'FL_' + IntToStr(anum);
    defined    := False;
    referenced := False;
    do_end     := False;
    line       := 0;
  End;
  LabelEnter := idx;
End;

{ --------------------------------------------------------------------------
  LabelMarkDefined : marquer une etiquette comme definie (vue en cols 1-5).
  Signale une erreur si elle est redeclare avec un numero deja defini.
  -------------------------------------------------------------------------- }
Procedure LabelMarkDefined(anum : Integer; aline : Integer);
Var idx : Integer;
Begin
  idx := LabelEnter(anum);
  If idx = 0 Then Exit;
  With lbl_table^[idx] Do
  Begin
    If defined Then
      ErrorMsg('Etiquette ' + IntToStr(anum) +
               ' deja definie (premiere a la ligne ' + IntToStr(line) + ')')
    Else
    Begin
      defined := True;
      line    := aline;
    End;
  End;
End;

{ --------------------------------------------------------------------------
  LabelCheckAll : controler en fin d'unite qu'il n'y a pas d'etiquettes
  referencees (GOTO/DO) mais jamais definies dans le source.
  -------------------------------------------------------------------------- }
Procedure LabelCheckAll;
Var i : Integer;
Begin
  For i := 1 To lbl_count Do
    With lbl_table^[i] Do
      If referenced And Not defined Then
        ErrorMsg('Etiquette ' + IntToStr(num) +
                 ' referencee mais jamais definie');
End;

{ --------------------------------------------------------------------------
  LabelReset : reinitialiser la table des etiquettes pour une nouvelle
  unite de programme.
  -------------------------------------------------------------------------- }
Procedure LabelReset;
Begin
  lbl_count := 0;
End;

{ ==========================================================================
  Table des blocs COMMON
  ========================================================================== }

{ --------------------------------------------------------------------------
  CommonFind : chercher un bloc COMMON par son nom.
  '' = BLANK COMMON. Retourne l'index (1..common_count) ou 0.
  -------------------------------------------------------------------------- }
Function CommonFind(Const aname : TString) : Integer;
Var i : Integer;
Begin
  CommonFind := 0;
  For i := 1 To common_count Do
    If common_table^[i].name = aname Then
    Begin
      CommonFind := i;
      Exit;
    End;
End;

{ --------------------------------------------------------------------------
  CommonEnter : creer un bloc COMMON s'il n'existe pas encore.
  Retourne l'index existant ou nouvellement cree (0 si table saturee).
  -------------------------------------------------------------------------- }
Function CommonEnter(Const aname : TString) : Integer;
Var idx : Integer;
Begin
  idx := CommonFind(aname);
  If idx > 0 Then
  Begin
    CommonEnter := idx;
    Exit;
  End;
  If common_count >= MAX_COMMON Then
  Begin
    ErrorMsg('Table COMMON saturee (MAX=' + IntToStr(MAX_COMMON) + ')');
    CommonEnter := 0;
    Exit;
  End;
  Inc(common_count);
  idx := common_count;
  With common_table^[idx] Do
  Begin
    name       := aname;
    If aname = '' Then asm_label := '_FC_BLANK_'
    Else             asm_label := '_FC_' + aname + '_';
    total_size := 0;
  End;
  CommonEnter := idx;
End;

{ ==========================================================================
  Table des enonces FORMAT
  ========================================================================== }

{ --------------------------------------------------------------------------
  FmtFind : chercher un FORMAT par son numero d'etiquette.
  Retourne l'index (1..fmt_count) ou 0 si non trouve.
  -------------------------------------------------------------------------- }
Function FmtFind(anum : Integer) : Integer;
Var i : Integer;
Begin
  FmtFind := 0;
  For i := 1 To fmt_count Do
    If fmt_table^[i].lbl_num = anum Then
    Begin
      FmtFind := i;
      Exit;
    End;
End;

{ --------------------------------------------------------------------------
  FmtEnter : enregistrer un enonce FORMAT.
  Si le numero existe deja, le texte est remplace avec avertissement.
  Retourne l'index (0 si table saturee).
  -------------------------------------------------------------------------- }
Function FmtEnter(anum : Integer; Const atext : TString) : Integer;
Var idx : Integer;
Begin
  idx := FmtFind(anum);
  If idx > 0 Then
  Begin
    WarnMsg('FORMAT ' + IntToStr(anum) + ' redefini');
    fmt_table^[idx].text := atext;
    FmtEnter := idx;
    Exit;
  End;
  If fmt_count >= MAX_FORMAT Then
  Begin
    ErrorMsg('Table FORMAT saturee (MAX=' + IntToStr(MAX_FORMAT) + ')');
    FmtEnter := 0;
    Exit;
  End;
  Inc(fmt_count);
  idx := fmt_count;
  With fmt_table^[idx] Do
  Begin
    lbl_num   := anum;
    text      := atext;
    asm_label := 'FK_FMT_' + IntToStr(anum);
  End;
  FmtEnter := idx;
End;

{ ============================================================
  TYPAGE IMPLICITE ET DECLARATIONS DE TYPE
  ============================================================
  Regle F77 par defaut : I J K L M N -> INTEGER, reste -> REAL.
  IMPLICIT NONE interdit tout type implicite.
  IMPLICIT type(ranges) modifie les regles pour des plages de lettres.
  Declarations explicites : INTEGER/REAL/DOUBLEPRECISION/COMPLEX/
  LOGICAL/CHARACTER [*n] var [*m] , var ...

  Fonctions exposees :
    ImplicitReset           -- reinit regles par defaut (entre unites)
    ApplyImplicit(name)     -- type implicite par 1ere lettre du nom
    SymGetOrCreate(name)    -- trouve ou cree un symbole avec type implicite
    ParseStarSize(default)  -- consomme [*n] ; retourne n ou default
    ParseImplicit           -- parse enonce IMPLICIT (cur_tok apres kw)
    ParseTypeDecl(dt)       -- parse liste de variables typees
  ============================================================ }

{ --------------------------------------------------------------------------
  ImplicitReset : reinitialiser les regles implicites pour une nouvelle
  unite de programme.  I-N -> INTEGER, reste -> REAL (norme F77 par defaut).
  -------------------------------------------------------------------------- }
Procedure ImplicitReset;
Var c : Char;
Begin
  impl_none := False;
  For c := 'A' To 'Z' Do
    impl_type[c] := DT_REAL;
  For c := 'I' To 'N' Do
    impl_type[c] := DT_INTEGER;
End;

{ --------------------------------------------------------------------------
  ApplyImplicit : retourner le type implicite d'une variable d'apres
  la premiere lettre de son nom.
  -------------------------------------------------------------------------- }
Function ApplyImplicit(Const aname : TString) : TDataType;
Var c : Char;
Begin
  If Length(aname) = 0 Then
  Begin
    ApplyImplicit := DT_INTEGER;
    Exit;
  End;
  c := aname[1];
  If (c >= 'a') And (c <= 'z') Then c := Chr(Ord(c) - 32);
  If (c >= 'A') And (c <= 'Z') Then
    ApplyImplicit := impl_type[c]
  Else
    ApplyImplicit := DT_INTEGER;
End;

{ --------------------------------------------------------------------------
  SymGetOrCreate : trouver un symbole dans la portee courante, ou en creer
  un nouveau avec son type implicite.  Si IMPLICIT NONE est actif et que
  le symbole n'existe pas, signale une erreur.
  Retourne l'index dans sym_table (0 = erreur).
  -------------------------------------------------------------------------- }
Function SymGetOrCreate(Const aname : TString) : Integer;
Var
  idx : Integer;
  dt  : TDataType;
Begin
  idx := SymFind(aname);
  If idx > 0 Then
  Begin
    SymGetOrCreate := idx;
    Exit;
  End;
  If impl_none Then
  Begin
    ErrorMsg('Variable non declaree (IMPLICIT NONE actif) : ' + aname);
    SymGetOrCreate := 0;
    Exit;
  End;
  dt  := ApplyImplicit(aname);
  idx := SymEnter(aname, SK_VAR, dt);
  If idx > 0 Then
  Begin
    sym_table^[idx].type_size := DataTypeSize(dt, 1);
    sym_table^[idx].char_len  := 1;
  End;
  SymGetOrCreate := idx;
End;

{ --------------------------------------------------------------------------
  ParseStarSize : consommer un specificateur de taille optionnel [*n].
  Si absent, retourne default_sz.  Valeur -1 = taille ajustable (*).
  cur_tok doit etre positionne sur le token courant.
  -------------------------------------------------------------------------- }
Function ParseStarSize(default_sz : Integer) : Integer;
Begin
  ParseStarSize := default_sz;
  If (cur_tok.kind = TK_OP) And (cur_tok.val = '*') Then
  Begin
    LexNext;
    { CHARACTER*(*) : taille ajustable pour parametres formels }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
    Begin
      LexNext;
      If (cur_tok.kind = TK_OP) And (cur_tok.val = '*') Then LexNext
      Else ErrorMsg('Attendu * dans CHARACTER*(*)');
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext
      Else ErrorMsg('Attendu ) dans CHARACTER*(*)');
      ParseStarSize := -1;   { -1 = ajustable }
    End
    Else If cur_tok.kind = TK_INTEGER Then
    Begin
      ParseStarSize := cur_tok.int_val;
      LexNext;
    End
    Else
      ErrorMsg('Taille numerique attendue apres * dans declaration de type');
  End;
End;

{ --------------------------------------------------------------------------
  ParseImplicit : parser un enonce IMPLICIT.
  Appele avec cur_tok sur le premier token APRES le mot-cle IMPLICIT.
  Syntaxe :
    IMPLICIT NONE
    IMPLICIT type[*n](lettre[-lettre] [, ...]) [, type[*n](...)] ...
  -------------------------------------------------------------------------- }
Procedure ParseImplicit;
Var
  dt       : TDataType;
  sz       : Integer;
  c1, c2   : Char;
  c        : Char;
Begin
  { IMPLICIT NONE }
  If (cur_tok.kind = TK_IDENT) And (cur_tok.val = 'NONE') Then
  Begin
    impl_none := True;
    For c := 'A' To 'Z' Do impl_type[c] := DT_NONE;
    LexNext;
    Exit;
  End;

  { IMPLICIT type[*n](ranges) [, type[*n](ranges)] ... }
  While cur_tok.kind = TK_KEYWORD Do
  Begin
    { Identifier le type }
    dt := DT_NONE;
    If      cur_tok.val = 'INTEGER'         Then dt := DT_INTEGER
    Else If cur_tok.val = 'REAL'            Then dt := DT_REAL
    Else If cur_tok.val = 'DOUBLEPRECISION' Then dt := DT_DOUBLE
    Else If cur_tok.val = 'COMPLEX'         Then dt := DT_COMPLEX
    Else If cur_tok.val = 'LOGICAL'         Then dt := DT_LOGICAL
    Else If cur_tok.val = 'CHARACTER'       Then dt := DT_CHARACTER
    Else
    Begin
      ErrorMsg('Type inconnu dans IMPLICIT : ' + cur_tok.val);
      Exit;
    End;
    LexNext;

    { Taille optionnelle *n }
    sz := ParseStarSize(DataTypeSize(dt, 1));

    { '(' liste de plages ')' }
    If (cur_tok.kind <> TK_PUNCT) Or (cur_tok.val <> '(') Then
    Begin
      ErrorMsg('Attendu ( apres le type dans IMPLICIT');
      Exit;
    End;
    LexNext;  { consommer '(' }

    Repeat
      { Premiere lettre de la plage }
      If (cur_tok.kind <> TK_IDENT) Or (Length(cur_tok.val) <> 1) Then
      Begin
        ErrorMsg('Lettre unique attendue dans plage IMPLICIT');
        Exit;
      End;
      c1 := cur_tok.val[1];
      c2 := c1;
      LexNext;

      { Plage c1-c2 ? }
      If (cur_tok.kind = TK_OP) And (cur_tok.val = '-') Then
      Begin
        LexNext;
        If (cur_tok.kind = TK_IDENT) And (Length(cur_tok.val) = 1) Then
        Begin
          c2 := cur_tok.val[1];
          LexNext;
        End
        Else
          ErrorMsg('Lettre de fin de plage attendue dans IMPLICIT');
      End;

      { Appliquer le type a toutes les lettres de la plage }
      If c2 >= c1 Then
        For c := c1 To c2 Do impl_type[c] := dt
      Else
        ErrorMsg('Plage IMPLICIT invalide : ' + c1 + '-' + c2);

      { Virgule : autre plage dans les memes parentheses }
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
        LexNext
      Else
        Break;
    Until (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')');

    { ')' fermant }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
      LexNext
    Else
      ErrorMsg('Attendu ) a la fin de la plage IMPLICIT');

    { Virgule : autre type-spec }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      LexNext
    Else
      Break;
  End;
End;

{ --------------------------------------------------------------------------
  ParseTypeDecl : parser un enonce de declaration de type.
  Appele avec dt = le type de base, cur_tok sur le premier token apres
  le mot-cle de type (et apres l'eventuel *n global).
  Syntaxe :
    INTEGER [*sz] var1 [*n] [(dim)] , var2 [*n] , ...
  Pour chaque variable :
    - si elle existe deja, son type est mis a jour
    - sinon, elle est creee avec SK_VAR et le type declare
  Les dimensions entre parentheses dans une declaration de type (extensions)
  sont simplement ignorees ici (traitee via DIMENSION).
  -------------------------------------------------------------------------- }
Procedure ParseTypeDecl(dt : TDataType);
Var
  def_sz  : Integer;   { taille par defaut du type }
  var_sz  : Integer;   { taille pour cette variable }
  vname   : TString;
  idx     : Integer;
Begin
  def_sz := DataTypeSize(dt, 1);
  { Taille globale optionnelle apres le type : INTEGER*2 var1, var2 }
  def_sz := ParseStarSize(def_sz);

  { Liste de variables }
  Repeat
    If cur_tok.kind <> TK_IDENT Then
    Begin
      ErrorMsg('Identificateur attendu dans declaration de type');
      Exit;
    End;
    vname := cur_tok.val;
    LexNext;

    { Taille specifique a cette variable : var*n }
    var_sz := ParseStarSize(def_sz);

    { Trouver ou creer le symbole }
    idx := SymFindLocal(vname);
    If idx = 0 Then
    Begin
      { Nouveau symbole : creer avec SK_VAR }
      idx := SymEnter(vname, SK_VAR, dt);
    End
    Else
    Begin
      { Symbole existant (ex. DIMENSION deja vu) : mettre a jour le type }
      sym_table^[idx].dtype := dt;
    End;

    If idx > 0 Then
    Begin
      sym_table^[idx].dtype     := dt;
      sym_table^[idx].type_size := var_sz;
      If dt = DT_CHARACTER Then
        sym_table^[idx].char_len := var_sz
      Else
        sym_table^[idx].char_len := 1;
    End;

    { Ignorer les dimensions eventuellement presentes ici :
      ex. INTEGER A(10) dans une declaration de type (extension F77).
      Elles seront traitees par le parseur DIMENSION. }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
    Begin
      LexNext;
      While (cur_tok.kind <> TK_PUNCT) Or (cur_tok.val <> ')') Do
      Begin
        If (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF) Then
        Begin
          ErrorMsg('Parenthese non fermee dans declaration de type');
          Exit;
        End;
        LexNext;
      End;
      LexNext; { consommer ')' }
    End;

    { Separateur de variables }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      LexNext
    Else
      Break;
  Until (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF);
End;

{ ============================================================
  DECLARATIONS DIMENSION ET TABLEAUX
  ============================================================
  DIMENSION var(borne[,borne]...) avec 1 a 7 dimensions (norme F77).
  Borne simple n  -> lb=1, ub=n
  Borne double m:n -> lb=m, ub=n
  Borne ajustable * -> ub=-1 (dummy arrays de taille inconnue)

  Fonctions exposees :
    DimExtent(idx,d)        -- etendue de la dimension d (ub-lb+1)
    ArrayTotalElems(idx)    -- produit de toutes les etendues
    ArrayTotalSize(idx)     -- ArrayTotalElems * type_size (octets)
    ArrayStride(idx,d)      -- pas d'adressage pour la dim d (col-major)
    ParseBoundExpr(v,adj)   -- lire une borne (entier ou *)
    ParseDimSpec(idx)       -- parse (dims) et remplit sym_table^[idx]
    ParseDimension          -- parse enonce DIMENSION complet
  ============================================================ }

{ --------------------------------------------------------------------------
  DimExtent : etendue de la dimension d (ub - lb + 1).
  Les dimensions ajustables (ub = -1) retournent 0.
  -------------------------------------------------------------------------- }
Function DimExtent(idx, d : Integer) : Integer;
Var lb, ub : Integer;
Begin
  DimExtent := 0;
  If (idx < 1) Or (idx > sym_count) Then Exit;
  If (d < 1) Or (d > sym_table^[idx].ndim) Then Exit;
  lb := sym_table^[idx].dims[d].lb;
  ub := sym_table^[idx].dims[d].ub;
  If ub = -1 Then DimExtent := 0   { ajustable -> etendue inconnue }
  Else            DimExtent := ub - lb + 1;
End;

{ --------------------------------------------------------------------------
  ArrayTotalElems : produit des etendues de toutes les dimensions.
  Retourne 0 si au moins une dimension est ajustable.
  -------------------------------------------------------------------------- }
Function ArrayTotalElems(idx : Integer) : Integer;
Var i, prod, ext : Integer;
Begin
  ArrayTotalElems := 0;
  If (idx < 1) Or (idx > sym_count) Then Exit;
  If sym_table^[idx].ndim = 0 Then
  Begin
    ArrayTotalElems := 1;
    Exit;
  End;
  prod := 1;
  For i := 1 To sym_table^[idx].ndim Do
  Begin
    ext := DimExtent(idx, i);
    If ext = 0 Then Exit;   { dimension ajustable -> total inconnu }
    prod := prod * ext;
  End;
  ArrayTotalElems := prod;
End;

{ --------------------------------------------------------------------------
  ArrayTotalSize : taille totale en octets = total_elems * type_size.
  -------------------------------------------------------------------------- }
Function ArrayTotalSize(idx : Integer) : Integer;
Begin
  ArrayTotalSize := ArrayTotalElems(idx) * sym_table^[idx].type_size;
End;

{ --------------------------------------------------------------------------
  ArrayStride : pas (stride) de la dimension d en ordre column-major.
  stride(1) = 1
  stride(d) = etendue(1) * etendue(2) * ... * etendue(d-1)
  Retourne 0 si une dimension precedente est ajustable.
  -------------------------------------------------------------------------- }
Function ArrayStride(idx, d : Integer) : Integer;
Var i, s, ext : Integer;
Begin
  ArrayStride := 0;
  If d < 1 Then Exit;
  s := 1;
  For i := 1 To d - 1 Do
  Begin
    ext := DimExtent(idx, i);
    If ext = 0 Then Exit;
    s := s * ext;
  End;
  ArrayStride := s;
End;

{ --------------------------------------------------------------------------
  ParseBoundExpr : lire une expression de borne (entier signé ou *).
  out_val     = valeur numerique (0 si ajustable)
  out_adj     = True si la borne est ajustable (*)
  Supporte uniquement les constantes entieres simples (et + / - unaire).
  -------------------------------------------------------------------------- }
Procedure ParseBoundExpr(Var out_val : Integer; Var out_adj : Boolean);
Var sign : Integer;
Begin
  out_val := 0;
  out_adj := False;

  If (cur_tok.kind = TK_OP) And (cur_tok.val = '*') Then
  Begin
    out_adj := True;
    LexNext;
    Exit;
  End;

  sign := 1;
  If (cur_tok.kind = TK_OP) And (cur_tok.val = '-') Then
  Begin
    sign := -1;
    LexNext;
  End
  Else If (cur_tok.kind = TK_OP) And (cur_tok.val = '+') Then
    LexNext;

  If cur_tok.kind = TK_INTEGER Then
  Begin
    out_val := sign * Integer(cur_tok.int_val);
    LexNext;
  End
  Else
    ErrorMsg('Borne de dimension attendue (entier ou *), obtenu : ' +
             cur_tok.val);
End;

{ --------------------------------------------------------------------------
  ParseDimSpec : parser la liste de dimensions d'un tableau.
  cur_tok doit etre sur '(' a l'entree.
  Remplit sym_table^[idx].dims[1..ndim] et sym_table^[idx].ndim.
  Met a jour sym_table^[idx].kind := SK_ARRAY.
  -------------------------------------------------------------------------- }
Procedure ParseDimSpec(idx : Integer);
Var
  d        : Integer;
  lb, ub   : Integer;
  v1, v2   : Integer;
  adj1,adj2: Boolean;
Begin
  If (cur_tok.kind <> TK_PUNCT) Or (cur_tok.val <> '(') Then
  Begin
    ErrorMsg('Attendu ( pour la liste de dimensions');
    Exit;
  End;
  LexNext;  { consommer '(' }

  d := 0;
  Repeat
    If d >= MAX_DIM Then
    Begin
      ErrorMsg('Trop de dimensions (max ' + IntToStr(MAX_DIM) + ')');
      { avancer jusqu'a ')' }
      While (cur_tok.kind <> TK_PUNCT) Or (cur_tok.val <> ')') Do
      Begin
        If (cur_tok.kind = TK_EOF) Or (cur_tok.kind = TK_NEWLINE) Then Break;
        LexNext;
      End;
      Break;
    End;

    Inc(d);

    { Lire premiere valeur }
    ParseBoundExpr(v1, adj1);

    { Deux-points ? -> lb:ub }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ':') Then
    Begin
      LexNext;
      lb := v1;
      ParseBoundExpr(v2, adj2);
      If adj2 Then ub := -1
      Else         ub := v2;
    End
    Else
    Begin
      { Borne simple : lb=1, ub=v1 (ou -1 si ajustable) }
      lb := 1;
      If adj1 Then ub := -1
      Else         ub := v1;
    End;

    If (ub <> -1) And (ub < lb) Then
      ErrorMsg('Borne superieure < borne inferieure dans DIMENSION');

    sym_table^[idx].dims[d].lb := lb;
    sym_table^[idx].dims[d].ub := ub;

    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      LexNext
    Else
      Break;
  Until (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')');

  { Fermer ')' }
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
    LexNext
  Else
    ErrorMsg('Attendu ) pour fermer la liste de dimensions');

  sym_table^[idx].ndim := d;
  sym_table^[idx].kind := SK_ARRAY;

  { Mettre a jour la taille totale si toutes dimensions connues }
  sym_table^[idx].type_size := DataTypeSize(sym_table^[idx].dtype,
                                             sym_table^[idx].char_len);
End;

{ --------------------------------------------------------------------------
  ParseDimension : parser un enonce DIMENSION complet.
  Appele avec cur_tok sur le premier token apres le mot-cle DIMENSION.
  Syntaxe :
    DIMENSION var(dim_spec) [, var(dim_spec)] ...
  -------------------------------------------------------------------------- }
Procedure ParseDimension;
Var
  vname : TString;
  idx   : Integer;
Begin
  Repeat
    If cur_tok.kind <> TK_IDENT Then
    Begin
      ErrorMsg('Identificateur attendu dans DIMENSION');
      Exit;
    End;
    vname := cur_tok.val;
    LexNext;

    { Trouver ou creer le symbole (avec type implicite si nouveau) }
    idx := SymFindLocal(vname);
    If idx = 0 Then
      idx := SymGetOrCreate(vname);

    If idx = 0 Then Exit;

    { Parser le specificateur de dimensions }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
    Begin
      ParseDimSpec(idx);
    End
    Else
    Begin
      ErrorMsg('Liste de dimensions attendue apres ' + vname +
               ' dans DIMENSION');
      Exit;
    End;

    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      LexNext
    Else
      Break;
  Until (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF);
End;

{ ============================================================
  DECLARATIONS COMMON, EQUIVALENCE ET SAVE
  ============================================================
  Fonctions exposees :
    ParseCommonVarIntoBlock(ci, vname) -- attacher une variable au bloc ci
    ParseCommon                        -- parser un enonce COMMON complet
    ParseEquivalence                   -- parser un enonce EQUIVALENCE
    ParseSave                          -- parser un enonce SAVE
  Architecture memoire :
    sym_table^[i].common_blk = index du bloc COMMON (1..common_count)
    sym_table^[i].common_off = offset en octets dans le bloc
    sym_table^[i].asm_label  = '_FC_NOM_' ou '_FC_NOM_+off'
    sym_table^[i].equiv_grp  = numero du groupe EQUIVALENCE (1..equiv_count)
    sym_table^[i].equiv_off  = offset dans le groupe (0 sans indice)
    sym_table^[i].is_save    = True si SAVE applique
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseCommonVarIntoBlock : attacher la variable vname au bloc COMMON ci.
  Met a jour sym_table^[idx].common_blk, common_off et total_size du bloc.
  Si le token courant est '(' apres vname, une liste de dimensions est
  parsee (declaration implicite de tableau a l'interieur de COMMON).
  -------------------------------------------------------------------------- }
Procedure ParseCommonVarIntoBlock(ci : Integer; Const vname : TString);
Var
  idx : Integer;
  vsz : Integer;
  off : Integer;
Begin
  idx := SymGetOrCreate(vname);
  If idx = 0 Then Exit;

  { Dimensions optionnelles dans COMMON : COMMON /B/ A(10,3) }
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
    ParseDimSpec(idx);

  { Verifier que la variable n'est pas deja dans un autre bloc COMMON }
  If sym_table^[idx].common_blk <> 0 Then
  Begin
    If sym_table^[idx].common_blk <> ci Then
      ErrorMsg('Variable ' + vname + ' deja dans un autre bloc COMMON')
    Else
      WarnMsg('Variable ' + vname + ' apparait deux fois dans le meme COMMON');
    Exit;
  End;

  { Taille a allouer dans le bloc }
  If sym_table^[idx].ndim > 0 Then
    vsz := ArrayTotalSize(idx)
  Else
  Begin
    vsz := sym_table^[idx].type_size;
    If vsz <= 0 Then
      vsz := DataTypeSize(sym_table^[idx].dtype, sym_table^[idx].char_len);
  End;
  If vsz <= 0 Then vsz := 2;    { securite : INTEGER par defaut }

  { Offset = fin courante du bloc, puis etendre le bloc }
  off := common_table^[ci].total_size;
  sym_table^[idx].common_blk := ci;
  sym_table^[idx].common_off := off;
  common_table^[ci].total_size := off + vsz;

  { Label ASM : base du bloc [+ offset] }
  If off = 0 Then
    sym_table^[idx].asm_label := common_table^[ci].asm_label
  Else
    sym_table^[idx].asm_label := common_table^[ci].asm_label
                                  + '+' + IntToStr(off);
End;

{ --------------------------------------------------------------------------
  ParseCommon : parser un enonce COMMON complet.
  Syntaxe F77 :
    COMMON [/nom/] v1 [, v2 ...] [/nom2/ v3 ...]
    COMMON // v1, v2 ...   -> BLANK COMMON (slashes doubles)
  Le mot-cle COMMON est deja consomme avant l'appel.
  -------------------------------------------------------------------------- }
Procedure ParseCommon;
Var
  block_name : TString;
  ci         : Integer;
  vname      : TString;
  more_segs  : Boolean;
Begin
  more_segs := True;
  While more_segs
    And (cur_tok.kind <> TK_NEWLINE)
    And (cur_tok.kind <> TK_EOF) Do
  Begin
    { --- Detecter le nom du segment : /nom/ ou // --- }
    If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
    Begin
      LexNext;
      If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
      Begin
        { // = BLANK COMMON }
        block_name := '';
        LexNext;
      End
      Else If cur_tok.kind = TK_IDENT Then
      Begin
        block_name := cur_tok.val;
        LexNext;
        { Consommer '/' fermant }
        If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
          LexNext
        Else
          ErrorMsg('Attendu / fermant apres le nom du bloc COMMON');
      End
      Else
      Begin
        ErrorMsg('Nom de bloc COMMON invalide apres /');
        block_name := '';
        If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then LexNext;
      End;
    End
    Else
      { Pas de / : BLANK COMMON implicite (seul segment sans modifier) }
      block_name := '';

    { Obtenir ou creer le bloc COMMON }
    ci := CommonEnter(block_name);
    If ci = 0 Then Exit;

    { --- Liste de variables separees par des virgules --- }
    Repeat
      If cur_tok.kind <> TK_IDENT Then
      Begin
        ErrorMsg('Identificateur attendu dans la liste COMMON');
        Break;
      End;
      vname := cur_tok.val;
      LexNext;
      ParseCommonVarIntoBlock(ci, vname);

      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      Begin
        LexNext;
        { Nouveau segment si on a '/' apres la virgule }
        If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
          Break;   { sortir de la boucle vars -> traiter le segment suivant }
      End
      Else
      Begin
        more_segs := False;  { pas de ',' -> fin du COMMON }
        Break;
      End;
    Until (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF);
  End;
End;

{ --------------------------------------------------------------------------
  ParseEquivalence : parser un enonce EQUIVALENCE.
  Syntaxe F77 :
    EQUIVALENCE (v1, v2 [, v3, ...]) [, (v4, v5, ...) ...]
  Le mot-cle EQUIVALENCE est deja consomme avant l'appel.
  Chaque groupe recoit un index equiv_grp unique (1..equiv_count).
  Les sous-elements de tableau (v(i)) sont reconnus mais l'offset n'est
  pas calcule ici (necessiterait le generateur d'expressions).
  Une equivalence entre deux blocs COMMON distincts est une erreur F77.
  -------------------------------------------------------------------------- }
Procedure ParseEquivalence;
Var
  vname    : TString;
  idx      : Integer;
  base_idx : Integer;
  grp      : Integer;
Begin
  Repeat
    LexExpect('(');
    grp      := 0;
    base_idx := 0;

    { --- Lire la liste de variables du groupe --- }
    Repeat
      If cur_tok.kind <> TK_IDENT Then
      Begin
        ErrorMsg('Identificateur attendu dans EQUIVALENCE');
        Break;
      End;
      vname := cur_tok.val;
      LexNext;

      { Sous-element de tableau optionnel : (v(i)) -> ignorer l'indice }
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
      Begin
        WarnMsg('Sous-element de tableau dans EQUIVALENCE non supporte : ' + vname);
        LexNext;
        While Not ((cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')' ))
              And (cur_tok.kind <> TK_NEWLINE)
              And (cur_tok.kind <> TK_EOF) Do
          LexNext;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
      End;

      idx := SymGetOrCreate(vname);
      If idx > 0 Then
      Begin
        If base_idx = 0 Then
        Begin
          { Premier element du groupe : variable de reference (offset=0) }
          Inc(equiv_count);
          grp      := equiv_count;
          base_idx := idx;
          sym_table^[idx].equiv_grp := grp;
          sym_table^[idx].equiv_off := 0;
        End
        Else
        Begin
          { Verifier coherence inter-COMMON }
          If (sym_table^[idx].common_blk <> 0)
          And (sym_table^[base_idx].common_blk <> 0)
          And (sym_table^[idx].common_blk <> sym_table^[base_idx].common_blk) Then
            ErrorMsg('EQUIVALENCE illegale entre deux blocs COMMON distincts : '
                     + vname)
          Else
          Begin
            sym_table^[idx].equiv_grp := grp;
            sym_table^[idx].equiv_off := 0;   { offset a affiner }
          End;
        End;
      End;

      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
        LexNext
      Else
        Break;
    Until (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')');

    { Fermer la parenthese du groupe }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
      LexNext
    Else
      ErrorMsg('Attendu ) pour fermer un groupe EQUIVALENCE');

    { Groupe suivant ? }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      LexNext
    Else
      Break;
  Until (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF);
End;

{ --------------------------------------------------------------------------
  ParseSave : parser un enonce SAVE.
  Syntaxe F77 :
    SAVE              -> toutes les variables locales sont preservees
    SAVE v1, v2, ...  -> uniquement les variables listees
    SAVE /COMMON/ ... -> ignore (COMMON est toujours statique en F77)
  Le mot-cle SAVE est deja consomme avant l'appel.
  -------------------------------------------------------------------------- }
Procedure ParseSave;
Var
  vname : TString;
  idx   : Integer;
  i     : Integer;
Begin
  If (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF) Then
  Begin
    { SAVE sans liste : marquer toutes les variables locales scalaires }
    For i := 1 To sym_count Do
      If (sym_table^[i].kind = SK_VAR)
      And (sym_table^[i].common_blk = 0) Then
        sym_table^[i].is_save := True;
    NoteMsg('SAVE sans liste : toutes les variables locales preservees');
  End
  Else
  Begin
    { SAVE avec liste explicite }
    Repeat
      If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
      Begin
        { SAVE /nom/ : COMMON est toujours statique en F77, rien a faire }
        LexNext;
        If cur_tok.kind = TK_IDENT Then
        Begin
          vname := cur_tok.val;
          LexNext;
          WarnMsg('SAVE /COMMON/ superflu (COMMON toujours statique) : /'
                  + vname + '/');
        End;
        If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then LexNext;
      End
      Else If cur_tok.kind = TK_IDENT Then
      Begin
        vname := cur_tok.val;
        LexNext;
        idx := SymGetOrCreate(vname);
        If idx > 0 Then
          sym_table^[idx].is_save := True;
      End
      Else
      Begin
        ErrorMsg('Identificateur ou /COMMON/ attendu dans SAVE');
        Break;
      End;

      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
        LexNext
      Else
        Break;
    Until (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF);
  End;
End;

{ ============================================================
  DECLARATION DATA ET CONSTANTES NOMMEES (PARAMETER)
  ============================================================
  Fonctions exposees :
    ParseDataConst(out_dt, out_ival, out_rval, out_sval)
        -- lire une constante litterale Fortran 77 (toujours avec signe)
    ParseData
        -- parser un enonce DATA complet
    ParseParameter
        -- parser un enonce PARAMETER (constantes symboliques)
  Architecture :
    DATA scalaire  -> sym_table^[idx].const_ival/rval/sval + is_defined
    PARAMETER      -> sym_table^[idx].kind = SK_PARAM_CONST + const_*
    Emission DATA  -> deferred (generateur de code 8086)
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseDataConst : lire une constante litterale Fortran 77 avec signe.
  Reconnus : entier, reel, double, logique .TRUE./.FALSE., chaine,
             hollerith, complexe (re,im), reference a un PARAMETER.
  Retourne le type et les trois champs de valeur.
  -------------------------------------------------------------------------- }
Procedure ParseDataConst(Var out_dt   : TDataType;
                         Var out_ival : LongInt;
                         Var out_rval : Real;
                         Var out_sval : TString);
Var
  neg     : Boolean;
  pi      : Integer;
  im_dt   : TDataType;
  im_ival : LongInt;
  im_rval : Real;
  im_sval : TString;
Begin
  out_dt   := DT_INTEGER;
  out_ival := 0;
  out_rval := 0.0;
  out_sval := '';
  im_dt    := DT_REAL;
  im_ival  := 0;
  im_rval  := 0.0;
  im_sval  := '';

  { Signe unaire optionnel }
  neg := False;
  If (cur_tok.kind = TK_OP) And (cur_tok.val = '-') Then
  Begin
    neg := True;
    LexNext;
  End
  Else If (cur_tok.kind = TK_OP) And (cur_tok.val = '+') Then
    LexNext;

  If cur_tok.kind = TK_INTEGER Then
  Begin
    out_dt   := DT_INTEGER;
    out_ival := cur_tok.int_val;
    If neg Then out_ival := -out_ival;
    LexNext;
  End
  Else If cur_tok.kind = TK_REAL Then
  Begin
    out_dt   := DT_REAL;
    out_rval := cur_tok.real_val;
    If neg Then out_rval := -out_rval;
    LexNext;
  End
  Else If cur_tok.kind = TK_DOUBLE Then
  Begin
    out_dt   := DT_DOUBLE;
    out_rval := cur_tok.real_val;
    If neg Then out_rval := -out_rval;
    LexNext;
  End
  Else If cur_tok.kind = TK_LOGICAL Then
  Begin
    out_dt := DT_LOGICAL;
    If cur_tok.val = '.TRUE.' Then out_ival := -1 Else out_ival := 0;
    LexNext;
  End
  Else If cur_tok.kind = TK_STRING Then
  Begin
    out_dt   := DT_CHARACTER;
    out_sval := cur_tok.val;
    LexNext;
  End
  Else If cur_tok.kind = TK_HOLLERITH Then
  Begin
    out_dt   := DT_CHARACTER;
    out_sval := cur_tok.val;
    LexNext;
  End
  Else If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
  Begin
    { Constante COMPLEX : (partie_reelle, partie_imaginaire) }
    LexNext;
    ParseDataConst(out_dt, out_ival, out_rval, out_sval);
    out_dt := DT_COMPLEX;
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
    Begin
      LexNext;
      ParseDataConst(im_dt, im_ival, im_rval, im_sval);
      { Partie imaginaire stockee dans out_ival (ecrasement approx.) }
      { Emission complete }
    End
    Else
      WarnMsg('Constante COMPLEX : virgule manquante entre re et im');
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
      LexNext
    Else
      ErrorMsg('Attendu ) apres la partie imaginaire de la constante COMPLEX');
  End
  Else If cur_tok.kind = TK_IDENT Then
  Begin
    { Reference a une constante PARAMETER deja declaree }
    pi := SymFind(cur_tok.val);
    If (pi > 0) And (sym_table^[pi].kind = SK_PARAM_CONST) Then
    Begin
      out_dt   := sym_table^[pi].dtype;
      out_ival := sym_table^[pi].const_ival;
      out_rval := sym_table^[pi].const_rval;
      out_sval := sym_table^[pi].const_sval;
      If neg Then
      Begin
        out_ival := -out_ival;
        out_rval := -out_rval;
      End;
    End
    Else
      ErrorMsg('Constante symbolique inconnue dans DATA/PARAMETER : ' + cur_tok.val);
    LexNext;
  End
  Else
  Begin
    ErrorMsg('Constante litterale attendue, lu : ' + cur_tok.val);
    LexNext;
  End;
End;

{ --------------------------------------------------------------------------
  ParseDataApply : appliquer la valeur (dt/ival/rval/sval) au symbole idx.
  Met a jour les champs const_* et is_defined.
  -------------------------------------------------------------------------- }
Procedure ParseDataApply(idx : Integer; dt : TDataType;
                         ival : LongInt; rval : Real;
                         Const sval : TString);
Begin
  If (idx < 1) Or (idx > sym_count) Then Exit;
  sym_table^[idx].const_ival := ival;
  sym_table^[idx].const_rval := rval;
  sym_table^[idx].const_sval := sval;
  sym_table^[idx].is_defined := True;
  { Verification de coherence de type (avertissement seulement) }
  If (sym_table^[idx].dtype <> DT_NONE)
  And (sym_table^[idx].dtype <> dt)
  And Not ((sym_table^[idx].dtype = DT_REAL) And (dt = DT_INTEGER)) Then
    WarnMsg('Type de constante DATA (' + DataTypeName(dt) + ') different du type'
            + ' de la variable (' + DataTypeName(sym_table^[idx].dtype) + ')');
  If opt_debug Then
    NoteMsg('DATA ' + sym_table^[idx].name + ' = ' + IntToStr(ival));
End;

{ --------------------------------------------------------------------------
  ParseData : parser un enonce DATA complet.
  Syntaxe F77 :
    DATA varlist / vallist / [, varlist / vallist /  ...]
  Elements de varlist autorises :
    var           -> scalaire entier
    var(e)        -> element de tableau (indice ignore)
    var(ib:ie)    -> sous-chaine CHARACTER (ignore pour l'instant)
    (var(i),i=l,u[,s]) -> DO implicite (liste partielle supportee)
  Elements de vallist :
    constante      -> une valeur
    n * constante  -> n repetitions de la meme valeur (n entier > 0)
  Le mot-cle DATA est deja consomme avant l'appel.
  -------------------------------------------------------------------------- }
Procedure ParseData;
Var
  { --- cote variables --- }
  vname   : TString;
  idx     : Integer;
  { --- cote valeurs --- }
  val_dt  : TDataType;
  val_iv  : LongInt;
  val_rv  : Real;
  val_sv  : TString;
  rep     : LongInt;     { compteur de repetition egal a n dans n*val }
  more    : Boolean;
  skip_i  : Integer;     { compteur de ) a consommer pour DO implicite }
Var
  { Buffer de variables (liste du groupe courant) }
  var_list   : Array[1..256] of Integer;  { indices sym_table }
  var_count  : Integer;                   { nombre de variables dans var_list }
  v          : Integer;                   { index courant dans var_list }
Begin
  Repeat   { boucle sur les groupes varlist / vallist / }

    { ===== COTE GAUCHE : varlist ===== }
    var_count := 0;
    more := True;
    While more
      And (cur_tok.kind <> TK_EOF)
      And (cur_tok.kind <> TK_NEWLINE) Do
    Begin
      { Test : on a atteint le '/' ? }
      If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then Break;

      { DO implicite : ( ident(...), ident = lb, ub [,step] ) }
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
      Begin
        WarnMsg('DO implicite dans DATA partiellement supporte');
        skip_i := 1;
        LexNext;
        { Parser les variables interieures jusqu'a la , de controle }
        While (skip_i > 0)
          And (cur_tok.kind <> TK_EOF)
          And (cur_tok.kind <> TK_NEWLINE) Do
        Begin
          If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
            Inc(skip_i)
          Else If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
          Begin
            Dec(skip_i);
            If skip_i = 0 Then Break;
          End
          Else If (cur_tok.kind = TK_IDENT) And (skip_i = 1) Then
          Begin
            vname := cur_tok.val;
            { Regarder si c'est une variable de data ou la var de controle }
            { Heuristique : si prochain token est '(' ou ',' on est dans les vars }
            If var_count < 256 Then
            Begin
              Inc(var_count);
              var_list[var_count] := SymGetOrCreate(vname);
            End;
          End;
          LexNext;
        End;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
      End
      Else If cur_tok.kind = TK_IDENT Then
      Begin
        vname := cur_tok.val;
        LexNext;
        idx := SymGetOrCreate(vname);

        { Sous-element / sous-chaine optionnel(le) : var(e) ou var(ib:ie) }
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
        Begin
          LexNext;
          { Consommer jusqu'a la ) correspondante }
          skip_i := 1;
          While (skip_i > 0)
            And (cur_tok.kind <> TK_EOF)
            And (cur_tok.kind <> TK_NEWLINE) Do
          Begin
            If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
              Inc(skip_i)
            Else If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
              Dec(skip_i);
            If skip_i > 0 Then LexNext Else LexNext;
          End;
          { Pour un tableau, on inscrit l'index mais sans calculer l'offset }
        End;

        If var_count < 256 Then
        Begin
          Inc(var_count);
          var_list[var_count] := idx;
        End;
      End
      Else
      Begin
        ErrorMsg('Element de liste DATA invalide : ' + cur_tok.val);
        LexNext;
      End;

      { Separateur entre elements de la varlist }
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      Begin
        LexNext;
        { Si apres la virgule on a '/', c'est la fin de la varlist }
        If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
          more := False;
      End
      Else
        more := False;
    End;

    { Consommer le '/' separateur gauche }
    If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
      LexNext
    Else
    Begin
      ErrorMsg('Attendu / avant la liste de valeurs DATA');
      Exit;
    End;

    { ===== COTE DROIT : vallist ===== }
    v    := 1;
    more := True;
    While more
      And Not ((cur_tok.kind = TK_OP) And (cur_tok.val = '/'))
      And (cur_tok.kind <> TK_EOF)
      And (cur_tok.kind <> TK_NEWLINE) Do
    Begin
      { Detecter la repetition : n*val }
      rep := 1;
      If cur_tok.kind = TK_INTEGER Then
      Begin
        { Peut etre n* ou juste un entier }
        rep := cur_tok.int_val;
        LexNext;
        If (cur_tok.kind = TK_OP) And (cur_tok.val = '*') Then
        Begin
          LexNext;   { consommer '*', rep deja dans rep }
        End
        Else
        Begin
          { N'etait pas n*, c'etait la valeur elle-meme : emettre }
          val_dt  := DT_INTEGER;
          val_iv  := rep;
          val_rv  := 0.0;
          val_sv  := '';
          rep := 1;
          { Appliquer directement sans relire de constante }
          If v <= var_count Then
          Begin
            If var_list[v] > 0 Then
              ParseDataApply(var_list[v], val_dt, val_iv, val_rv, val_sv);
            Inc(v);
          End;
          { Separateur }
          If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
            LexNext;
          Continue;
        End;
      End;

      { Lire la valeur reelle }
      ParseDataConst(val_dt, val_iv, val_rv, val_sv);

      { Appliquer rep fois }
      While rep > 0 Do
      Begin
        If v <= var_count Then
        Begin
          If var_list[v] > 0 Then
            ParseDataApply(var_list[v], val_dt, val_iv, val_rv, val_sv);
          Inc(v);
        End;
        Dec(rep);
      End;

      { Separateur ou fin }
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
        LexNext
      Else
        more := False;
    End;

    { Verification : nombre de valeurs coherent ? }
    If v - 1 < var_count Then
      WarnMsg('DATA : moins de valeurs que de variables dans le groupe');
    If v - 1 > var_count Then
      WarnMsg('DATA : plus de valeurs que de variables dans le groupe');

    { Consommer le '/' fermant }
    If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
      LexNext
    Else
    Begin
      ErrorMsg('Attendu / apres la liste de valeurs DATA');
      Exit;
    End;

    { Groupe suivant ? Virgule optionnelle avant la prochaine varlist }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      LexNext;

  Until (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF);
End;

{ --------------------------------------------------------------------------
  ParseParamConstExpr : evaluer une expression constante simple pour PARAMETER.
  Gere : litteraux signes, references a d'autres PARAMETER, et les
  operations  + - * /  entre constantes entieres ou reelles.
  Retourne le type et la valeur evaluee via des var-params.
  -------------------------------------------------------------------------- }
Procedure ParseParamConstExpr(Var out_dt   : TDataType;
                               Var out_ival : LongInt;
                               Var out_rval : Real;
                               Var out_sval : TString);
Var
  rdt : TDataType;
  riv : LongInt;
  rrv : Real;
  rsv : TString;
  op  : TString;
Begin
  { Terme gauche }
  ParseDataConst(out_dt, out_ival, out_rval, out_sval);

  { Operateurs * / + - binaires (precedence simplifiee : gauche-droite) }
  While (cur_tok.kind = TK_OP)
    And ((cur_tok.val = '+') Or (cur_tok.val = '-')
      Or (cur_tok.val = '*') Or (cur_tok.val = '/')) Do
  Begin
    op := cur_tok.val;
    LexNext;
    ParseDataConst(rdt, riv, rrv, rsv);

    { Harmoniser les types : si un des deux est REAL/DOUBLE, resultat REAL }
    If (out_dt = DT_INTEGER) And (rdt = DT_INTEGER) Then
    Begin
      If op = '+' Then out_ival := out_ival + riv
      Else If op = '-' Then out_ival := out_ival - riv
      Else If op = '*' Then out_ival := out_ival * riv
      Else If op = '/' Then
      Begin
        If riv = 0 Then ErrorMsg('Division par zero dans PARAMETER')
        Else out_ival := out_ival Div riv;
      End;
    End
    Else
    Begin
      { Promouvoir en reel }
      If out_dt = DT_INTEGER Then
      Begin
        out_rval := out_ival;
        out_dt   := DT_REAL;
      End;
      If rdt = DT_INTEGER Then rrv := riv;
      If op = '+' Then out_rval := out_rval + rrv
      Else If op = '-' Then out_rval := out_rval - rrv
      Else If op = '*' Then out_rval := out_rval * rrv
      Else If op = '/' Then
      Begin
        If rrv = 0.0 Then ErrorMsg('Division par zero dans PARAMETER')
        Else out_rval := out_rval / rrv;
      End;
      If rdt = DT_DOUBLE Then out_dt := DT_DOUBLE;
    End;
  End;
End;

{ --------------------------------------------------------------------------
  ParseParameter : parser un enonce PARAMETER.
  Syntaxe F77 :
    PARAMETER (nom = expr_const [, nom = expr_const ...])
  Le mot-cle PARAMETER est deja consomme avant l'appel.
  Chaque constante est creee dans la table des symboles avec
  kind = SK_PARAM_CONST et les champs const_ival / const_rval / const_sval.
  -------------------------------------------------------------------------- }
Procedure ParseParameter;
Var
  pname  : TString;
  idx    : Integer;
  p_dt   : TDataType;
  p_ival : LongInt;
  p_rval : Real;
  p_sval : TString;
Begin
  LexExpect('(');

  Repeat
    { Nom de la constante symbolique }
    If cur_tok.kind <> TK_IDENT Then
    Begin
      ErrorMsg('Identificateur attendu dans PARAMETER');
      Break;
    End;
    pname := cur_tok.val;
    LexNext;

    LexExpect('=');

    { Expression constante }
    ParseParamConstExpr(p_dt, p_ival, p_rval, p_sval);

    { Inscrire la constante dans la table des symboles }
    idx := SymFindLocal(pname);
    If idx = 0 Then
    Begin
      { Creer une nouvelle entree }
      idx := SymEnter(pname, SK_PARAM_CONST, p_dt);
    End
    Else If sym_table^[idx].kind = SK_PARAM_CONST Then
    Begin
      WarnMsg('PARAMETER ' + pname + ' redefini');
    End
    Else
    Begin
      { La variable existait deja (ex: declaree INTEGER avant PARAMETER) }
      sym_table^[idx].kind := SK_PARAM_CONST;
    End;

    If idx > 0 Then
    Begin
      sym_table^[idx].dtype      := p_dt;
      sym_table^[idx].const_ival := p_ival;
      sym_table^[idx].const_rval := p_rval;
      sym_table^[idx].const_sval := p_sval;
      sym_table^[idx].is_defined := True;
      If opt_debug Then
        NoteMsg('PARAMETER ' + pname + ' = ' + IntToStr(p_ival));
    End;

    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      LexNext
    Else
      Break;
  Until (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')');

  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
    LexNext
  Else
    ErrorMsg('Attendu ) pour fermer l''enonce PARAMETER');
End;

{ ============================================================
  GENERATEUR DE CODE 8086 - PRIMITIVES
  ============================================================
  Fonctions exposees :
    EmitLabel(lbl)            -- emettre un label MASM (col 0)
    EmitI0(mn)                -- instruction sans operande
    EmitI1(mn, op)            -- instruction un operande
    EmitI2(mn, dst, src)      -- instruction deux operandes
    EmitDB(val)               -- directive DB octet
    EmitDBs(val, n)           -- directive DB n DUP(val)
    EmitDW(val)               -- directive DW mot 16 bits
    EmitDWi(n)                -- directive DW valeur entiere
    EmitDD(val)               -- directive DD double mot 32 bits
    EmitDQ(val)               -- directive DQ quad mot 64 bits
    EmitDup(sz, val)          -- directive DUP(val) avec taille sz
    EmitStr(s)                -- directive DB avec chaine Fortran
    EmitComment(s)            -- ligne commentaire ';'
    EmitSep                   -- ligne separatrice '; ---'
    EmitBlank                 -- ligne vide
    GenBranchLabel            -- generer un label interne unique _FB_nnn
    GenDataLabel              -- generer un label donnee unique _FK_nnn
    GenProgramHeader          -- entete du fichier ASM (.MODEL SMALL)
    GenDataSegBegin/End       -- .DATA begin/end
    GenCodeSegBegin/End       -- .CODE begin/end
    GenProcBegin(nm,nparams)  -- PROC FAR/NEAR + prologue BP
    GenProcEnd(nm)            -- epilogue + ENDP
    GenProgramEpilogue        -- MOV AX,4C00h / INT 21h
    GenProgramEntry           -- point d'entree START
  ============================================================ }

{ --------------------------------------------------------------------------
  Helpers d'ecriture dans cur_out
  -------------------------------------------------------------------------- }

{ Ecrire une ligne brute dans la sortie courante }
Procedure EmitRaw(Const s : TString);
Begin
  Writeln(cur_out^, s);
End;

{ --------------------------------------------------------------------------
  EmitLabel : emettre un label MASM sans indentation (col 0).
  Ajoute ':' uniquement si pas deja present.
  -------------------------------------------------------------------------- }
Procedure EmitLabel(Const lbl : TString);
Var s : TString;
Begin
  s := lbl;
  If (Length(s) > 0) And (s[Length(s)] <> ':') Then s := s + ':';
  EmitRaw(s);
End;

{ --------------------------------------------------------------------------
  EmitI0 : instruction sans operande (ex: NOP, RET, PUSHF).
  -------------------------------------------------------------------------- }
Procedure EmitI0(Const mn : TString);
Begin
  EmitRaw('        ' + mn);
  Inc(instr_count);
End;

{ --------------------------------------------------------------------------
  EmitI1 : instruction un operande (ex: INC AX, PUSH BX).
  -------------------------------------------------------------------------- }
Procedure EmitI1(Const mn, op : TString);
Begin
  EmitRaw('        ' + mn + ' ' + op);
  Inc(instr_count);
End;

{ --------------------------------------------------------------------------
  EmitI2 : instruction deux operandes (ex: MOV AX, BX).
  -------------------------------------------------------------------------- }
Procedure EmitI2(Const mn, dst, src : TString);
Begin
  EmitRaw('        ' + mn + ' ' + dst + ', ' + src);
  Inc(instr_count);
End;

{ --------------------------------------------------------------------------
  Directives de donnees
  -------------------------------------------------------------------------- }

Procedure EmitDB(Const val : TString);
Begin
  EmitRaw('        DB ' + val);
End;

Procedure EmitDBi(n : Integer);
Begin
  EmitRaw('        DB ' + IntToStr(n));
End;

Procedure EmitDBs(Const val : TString; n : Integer);
{ DB n DUP(val) }
Begin
  If n = 1 Then
    EmitDB(val)
  Else
    EmitRaw('        DB ' + IntToStr(n) + ' DUP(' + val + ')');
End;

{ emit une chaine CHARACTER Fortran : DB len, 'chars...' }
{ Format Fortran : longueur fixe, pas null-terminated, blank-padded }
Procedure EmitDBStr(Const s : TString);
Var i   : Integer;
    res : TString;
    c   : Char;
    inq : Boolean;  { dans un segment de chaine }
Begin
  If Length(s) = 0 Then
  Begin
    EmitRaw('        DB 0');
    Exit;
  End;
  { Decomposer en segments String + bytes hex pour les caracteres speciaux }
  res  := '        DB ';
  inq  := False;
  For i := 1 To Length(s) Do
  Begin
    c := s[i];
    If (Ord(c) >= 32) And (Ord(c) < 127) And (c <> '''') Then
    Begin
      If Not inq Then
      Begin
        If i > 1 Then res := res + ', ';
        res := res + '''';
        inq := True;
      End;
      res := res + c;
    End
    Else
    Begin
      If inq Then
      Begin
        res := res + '''';
        inq := False;
      End;
      If Length(res) > 8 Then res := res + ', ';
      res := res + IntToStr(Ord(c));
    End;
  End;
  If inq Then res := res + '''';
  EmitRaw(res);
End;

Procedure EmitDW(Const val : TString);
Begin
  EmitRaw('        DW ' + val);
End;

Procedure EmitDWi(n : LongInt);
Begin
  EmitRaw('        DW ' + IntToStr(n));
End;

Procedure EmitDD(Const val : TString);
Begin
  EmitRaw('        DD ' + val);
End;

Procedure EmitDDi(n : LongInt);
Begin
  EmitRaw('        DD ' + IntToStr(n));
End;

Procedure EmitDQ(Const val : TString);
Begin
  EmitRaw('        DQ ' + val);
End;

{ DB/DW/DD selon DataType et valeur en TString }
Procedure EmitDataValue(dt : TDataType; Const val : TString);
Begin
  Case dt Of
    DT_INTEGER   : EmitDW(val);
    DT_REAL      : EmitDD(val);    { valeur reelle = DD (4 octets) }
    DT_DOUBLE    : EmitDQ(val);    { double = DQ (8 octets) }
    DT_COMPLEX   : Begin EmitDD(val); EmitDD('0'); End; { re + im }
    DT_LOGICAL   : EmitDW(val);
    DT_CHARACTER : EmitDBStr(val);
  Else
    EmitDW(val);
  End;
End;

{ --------------------------------------------------------------------------
  EmitComment, EmitSep, EmitBlank : decoration
  -------------------------------------------------------------------------- }

Procedure EmitComment(Const s : TString);
Begin
  EmitRaw('; ' + s);
End;

Procedure EmitSep;
Begin
  EmitRaw('; ' + '------------------------------------------------------------');
End;

Procedure EmitBlank;
Begin
  EmitRaw('');
End;

{ --------------------------------------------------------------------------
  GenBranchLabel : generer un nouveau label interne FB (branche)
  -------------------------------------------------------------------------- }
Function GenBranchLabel : TString;
Begin
  Inc(branch_lbl_count);
  GenBranchLabel := FB_PFX + IntToStr(branch_lbl_count);
End;

{ --------------------------------------------------------------------------
  GenDataLabel : generer un nouveau label de constante FK
  -------------------------------------------------------------------------- }
Function GenDataLabel : TString;
Begin
  Inc(data_lbl_count);
  GenDataLabel := FK_PFX + IntToStr(data_lbl_count);
End;

{ --------------------------------------------------------------------------
  GenProgramHeader : emettre l'entete du fichier ASM.
  Modele memoire SMALL (code < 64 Ko, data < 64 Ko) comme BCPL86.
  -------------------------------------------------------------------------- }
Procedure GenProgramHeader;
Begin
  EmitComment('Genere par F77C86 v' + F77_VERSION + ' - ' + F77_DATE);
  EmitComment('Source : ' + src_fname);
  EmitBlank;
  EmitRaw('        .MODEL SMALL');
  EmitRaw('        .STACK ' + IntToStr(STACK_SIZE));
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenDataSegBegin / GenDataSegEnd
  -------------------------------------------------------------------------- }
Procedure GenDataSegBegin;
Begin
  EmitBlank;
  EmitRaw('        .DATA');
  EmitBlank;
End;

Procedure GenDataSegEnd;
Begin
  EmitBlank;
  EmitComment('--- Fin segment .DATA ---');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenCodeSegBegin / GenCodeSegEnd
  -------------------------------------------------------------------------- }
Procedure GenCodeSegBegin;
Begin
  EmitBlank;
  EmitRaw('        .CODE');
  EmitBlank;
End;

Procedure GenCodeSegEnd;
Begin
  EmitBlank;
  EmitComment('--- Fin segment .CODE ---');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenProcBegin : emettre le prologue d'un sous-programme Fortran.
  Convention Fortran 77 :
    - PROC NEAR (modele SMALL)
    - Prologue standard : PUSH BP / MOV BP, SP
    - Arguments passes PAR REFERENCE (pointeurs 16 bits sur pile)
    - Acces arg i : MOV BX, [BP + 4 + (i-1)*2] (depuis la droite: dernier arg en premier)
      (BP+0 = ancien BP, BP+2 = adresse retour, BP+4 = 1er arg)
    - Registres preserves : SI, DI, DS (convention standard 86)
  -------------------------------------------------------------------------- }
Procedure GenProcBegin(Const nm : TString; nparams : Integer);
Begin
  EmitBlank;
  EmitSep;
  EmitComment('PROCEDURE/FUNCTION : ' + nm
              + ' (' + IntToStr(nparams) + ' parametre(s))');
  EmitSep;
  EmitLabel(FP_PFX + nm);
  EmitRaw(FP_PFX + nm + '  PROC NEAR');
  EmitI1('PUSH', 'BP');
  EmitI2('MOV',  'BP', 'SP');
  EmitI1('PUSH', 'SI');
  EmitI1('PUSH', 'DI');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenProcEnd : emettre l'epilogue d'un sous-programme.
  Depiler les parametres (convention appelant = non - F77 = callee clean).
  Norme F77 : les arg sont empiles par l'appelant, nettoyes par l'appelant.
  Ici on utilise RET simple (l'appelant fait ADD SP, nparams*2 apres le CALL).
  -------------------------------------------------------------------------- }
Procedure GenProcEnd(Const nm : TString);
Begin
  EmitBlank;
  EmitI1('POP', 'DI');
  EmitI1('POP', 'SI');
  EmitI1('POP', 'BP');
  EmitI0('RET');
  EmitRaw(FP_PFX + nm + '  ENDP');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenInitSeg : emettre les instructions d'initialisation des registres de
  segment DS au point d'entree (START).
  -------------------------------------------------------------------------- }
Procedure GenInitSeg;
Begin
  EmitI2('MOV', 'AX', '@DATA');
  EmitI2('MOV', 'DS', 'AX');
End;

{ --------------------------------------------------------------------------
  GenProgramEntry : emettre le point d'entree START.
  -------------------------------------------------------------------------- }
Procedure GenProgramEntry;
Begin
  EmitBlank;
  EmitSep;
  EmitComment('Point d''entree du programme');
  EmitSep;
  EmitLabel('START');
  GenInitSeg;
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenProgramEpilogue : emettre la sortie propre via DOS INT 21h.
  AX = 4C00h -> exit code 0.
  -------------------------------------------------------------------------- }
Procedure GenProgramEpilogue;
Begin
  EmitBlank;
  EmitComment('Fin du programme principal');
  EmitI2('MOV', 'AX', '4C00h');
  EmitI0('INT 21h');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenFileEnd : emettre la directive END de fin de fichier ASM.
  -------------------------------------------------------------------------- }
Procedure GenFileEnd(Const entry_label : TString);
Begin
  EmitBlank;
  If entry_label <> '' Then
    EmitRaw('        END ' + entry_label)
  Else
    EmitRaw('        END');
End;

{ --------------------------------------------------------------------------
  GenPushArg : pousser l'adresse d'un argument (convention by-reference).
  Pour les variables locales (BP-offset) : LEA AX, [BP-offset] ; PUSH AX
  Pour les variables statiques (label) : MOV AX, OFFSET label ; PUSH AX
  -------------------------------------------------------------------------- }
Procedure GenPushArgByRef(idx : Integer);
Var s : TSymRef;
Begin
  If (idx < 1) Or (idx > sym_count) Then Exit;
  s := sym_table^[idx];
  If s.common_blk > 0 Then
  Begin
    { Variable de COMMON : adresse directe }
    EmitI2('MOV', 'AX', 'OFFSET ' + s.asm_label);
    EmitI1('PUSH', 'AX');
  End
  Else If s.bp_offset < 0 Then
  Begin
    { Variable locale ou parametre : [BP + offset] }
    EmitI2('LEA', 'AX', '[BP' + IntToStr(s.bp_offset) + ']');
    EmitI1('PUSH', 'AX');
  End
  Else If s.asm_label <> '' Then
  Begin
    { Variable statique ou SAVE : adresse directe }
    EmitI2('MOV', 'AX', 'OFFSET ' + s.asm_label);
    EmitI1('PUSH', 'AX');
  End
  Else
  Begin
    WarnMsg('GenPushArgByRef : symbole sans adresse - ' + s.name);
    EmitI2('MOV', 'AX', '0');
    EmitI1('PUSH', 'AX');
  End;
End;

{ --------------------------------------------------------------------------
  GenLoadInt : charger un entier 16 bits dans AX.
  Selon la nature du symbole : constante PARAMETER, var locale ou statique.
  -------------------------------------------------------------------------- }
Procedure GenLoadInt(idx : Integer);
Var s : TSymRef;
Begin
  If (idx < 1) Or (idx > sym_count) Then
  Begin
    EmitI2('MOV', 'AX', '0');
    Exit;
  End;
  s := sym_table^[idx];
  If s.kind = SK_PARAM_CONST Then
  Begin
    EmitI2('MOV', 'AX', IntToStr(s.const_ival));
  End
  Else If s.is_dummy And (s.bp_offset > 0) Then
  Begin
    { Parametre by-reference : deref [BP+n] }
    EmitI2('MOV', 'BX', 'WORD PTR [BP+' + IntToStr(s.bp_offset) + ']');
    EmitI2('MOV', 'AX', 'WORD PTR [BX]');
  End
  Else If s.bp_offset < 0 Then
  Begin
    EmitI2('MOV', 'AX', 'WORD PTR [BP' + IntToStr(s.bp_offset) + ']');
  End
  Else If s.asm_label <> '' Then
  Begin
    EmitI2('MOV', 'AX', 'WORD PTR [' + s.asm_label + ']');
  End
  Else
    EmitI2('MOV', 'AX', '0');
End;

{ --------------------------------------------------------------------------
  GenStoreInt : stocker AX dans une variable entiere.
  -------------------------------------------------------------------------- }
Procedure GenStoreInt(idx : Integer);
Var s : TSymRef;
Begin
  If (idx < 1) Or (idx > sym_count) Then Exit;
  s := sym_table^[idx];
  If s.is_dummy And (s.bp_offset > 0) Then
  Begin
    { Parametre by-reference : deref [BP+n] }
    EmitI2('MOV', 'BX', 'WORD PTR [BP+' + IntToStr(s.bp_offset) + ']');
    EmitI2('MOV', 'WORD PTR [BX]', 'AX');
  End
  Else If s.bp_offset < 0 Then
    EmitI2('MOV', 'WORD PTR [BP' + IntToStr(s.bp_offset) + ']', 'AX')
  Else If s.asm_label <> '' Then
    EmitI2('MOV', 'WORD PTR [' + s.asm_label + ']', 'AX')
  Else
    WarnMsg('GenStoreInt : symbole sans adresse - ' + s.name);
End;

{ --------------------------------------------------------------------------
  GenVarDecl : emettre la declaration d'espace pour une variable en .DATA.
  Utilise les champs dtype, char_len, type_size, ndim, dims de TSymRec.
  Variables DATA-initialisees : emit la valeur; sinon : DW/DD/DQ 0.
  -------------------------------------------------------------------------- }
Procedure GenVarDecl(idx : Integer);
Var s  : TSymRef;
    sz : Integer;
    di : Integer;
    ne : LongInt;  { nombre d'elements total pour les tableaux }
Begin
  If (idx < 1) Or (idx > sym_count) Then Exit;
  s := sym_table^[idx];
  If s.kind = SK_PARAM_CONST Then Exit;  { pas de DATA pour les PARAMETER }
  If s.common_blk > 0 Then Exit;         { COMMON gere separement          }
  If s.asm_label = '' Then Exit;         { symbole sans label (parametre)  }
  If s.kind = SK_SUBR Then Exit;
  If s.kind = SK_FUNC Then Exit;

  sz := DataTypeSize(s.dtype, s.char_len);

  { Calculer le nombre d'elements pour les tableaux }
  ne := 1;
  If s.ndim > 0 Then
  Begin
    For di := 1 To s.ndim Do
      ne := ne * (s.dims[di].ub - s.dims[di].lb + 1);
  End;

  EmitComment('VAR ' + s.name + ' (' + DataTypeName(s.dtype) + ')');
  EmitLabel(s.asm_label);

  If s.is_defined Then
  Begin
    { Variable initialisee par DATA }
    Case s.dtype Of
      DT_INTEGER   : EmitDWi(s.const_ival);
      DT_LOGICAL   : EmitDWi(s.const_ival);
      DT_REAL      : EmitRaw('        DD 0    ; reel init');
      DT_DOUBLE    : EmitRaw('        DQ 0    ; double init');
      DT_COMPLEX   : EmitRaw('        DD 0, 0 ; complexe init');
      DT_CHARACTER :
      Begin
        EmitDBStr(s.const_sval);
        { Completer par des espaces si necessaire }
        If s.char_len > Length(s.const_sval) Then
          EmitDBs('''  ''', s.char_len - Length(s.const_sval));
      End;
    Else
      EmitDBs('0', sz);
    End;
  End
  Else
  Begin
    { Variable non initialisee : allouer de l'espace avec zero }
    If ne > 1 Then
    Begin
      Case sz Of
        1 : EmitDBs('0', ne);
        2 : EmitRaw('        DW ' + IntToStr(ne) + ' DUP(0)');
        4 : EmitRaw('        DD ' + IntToStr(ne) + ' DUP(0)');
        8 : EmitRaw('        DQ ' + IntToStr(ne) + ' DUP(0)');
      Else
        EmitRaw('        DB ' + IntToStr(ne * sz) + ' DUP(0)');
      End;
    End
    Else
    Begin
      Case sz Of
        1 : EmitDB('0');
        2 : EmitDW('0');
        4 : EmitDD('0');
        8 : EmitDQ('0');
      Else
        EmitDBs('0', sz);
      End;
    End;
  End;
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenCommonBlockDecl : emettre la declaration d'un bloc COMMON en .DATA.
  Alloue common_table^[ci].total_size octets avec le label _FC_nom_.
  -------------------------------------------------------------------------- }
Procedure GenCommonBlockDecl(ci : Integer);
Var cb : TCommonRef;
Begin
  If (ci < 1) Or (ci > common_count) Then Exit;
  cb := common_table^[ci];
  EmitComment('COMMON /' + cb.name + '/ (' + IntToStr(cb.total_size) + ' octets)');
  EmitLabel(FC_PFX + cb.name + '_');
  If cb.total_size > 0 Then
    EmitRaw('        DB ' + IntToStr(cb.total_size) + ' DUP(0)')
  Else
    EmitRaw('        DB 1 DUP(0)   ; COMMON vide');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenAllVarDecls : emettre toutes les declarations de variables du proc.
  Appele au debut du segment .DATA apres GenDataSegBegin.
  -------------------------------------------------------------------------- }
Procedure GenAllVarDecls(proc_idx : Integer);
Var i : Integer;
Begin
  { Blocs COMMON en premier }
  For i := 1 To common_count Do
    GenCommonBlockDecl(i);
  { Puis toutes les variables du proc courant }
  For i := 1 To sym_count Do
    If sym_table^[i].scope_unit = proc_idx Then
      GenVarDecl(i);
End;

{ --------------------------------------------------------------------------
  GenCallSub : generer un CALL a un sous-programme Fortran.
  Empile OFFSET des args de droite a gauche, puis CALL, puis ADD SP.
  Les args sont des indices dans sym_table.
  arg_idx est un tableau d'indices sym_table, nargs le nombre d'args.
  -------------------------------------------------------------------------- }
Procedure GenCallSub(Const sub_label : TString;
                     Var arg_idx : Array of Integer;
                     nargs : Integer);
Var i : Integer;
Begin
  EmitComment('CALL ' + sub_label);
  { Empiler de droite a gauche (dernier arg en premier sur pile) }
  For i := nargs - 1 DownTo 0 Do
    GenPushArgByRef(arg_idx[i]);
  EmitRaw('        CALL ' + sub_label);
  If nargs > 0 Then
    EmitI2('ADD', 'SP', IntToStr(nargs * 2));
  EmitBlank;
End;

{ ============================================================
  EXPRESSIONS ARITHMETIQUES ENTIERES
  ============================================================
  Architecture :
    ParseIntFactor   -- primaire : literal, var, PARAMETER, (expr),
                        appel de fonction entiere
    ParseIntPower    -- ** (puissance, droit-associatif) via _FRT_IPOW
    ParseIntUnary    -- signe unaire + - avant ParseIntPower
    ParseIntTerm     -- * / IMUL IDIV (gauche-associatif)
    ParseIntExpr     -- + - ADD SUB (gauche-associatif)
  Convention : le resultat est toujours dans AX.
  Binaire : PUSH AX (gauche), eval droite -> AX,
            MOV CX,AX ; POP AX ; op AX,CX.
  Divisions Fortran 77 = troncature vers zero : CWD + IDIV AX.
  ============================================================ }

{ Declarations Forward pour la recursivite mutuelle }
Procedure ParseIntExpr; Forward;
Procedure ParseCharExpr; Forward;  { definie apres ParseRealFactor }

{ --------------------------------------------------------------------------
  GenIntrinsicInt1 : emettre le code pour une fonction intrinsèque entiere
  a 1 argument (expression deja evaluee dans AX).
  -------------------------------------------------------------------------- }
Procedure GenIntrinsicInt1(Const fname : TString);
Var lbl : TString;
Begin
  If (fname = 'ABS') Or (fname = 'IABS') Then
  Begin
    lbl := GenBranchLabel;
    EmitI2('CMP', 'AX', '0');
    EmitI1('JGE', lbl);
    EmitI1('NEG', 'AX');
    EmitLabel(lbl);
  End
  Else If (fname = 'INT') Or (fname = 'IFIX') Or (fname = 'IDINT') Then
  Begin
    { Argument reel : stub - supposer que AX contient deja la partie entiere }
    EmitComment('Conversion ' + fname + ' : stub');
  End
  Else If (fname = 'NOT') Or (fname = 'LNOT') Then
  Begin
    { NOT logique Fortran : NOT AX }
    EmitI1('NOT', 'AX');
  End
  Else
  Begin
    WarnMsg('Fonction intrinsèque entiere non supportee : ' + fname);
    EmitComment('Stub non implemente : ' + fname);
    EmitI2('MOV', 'AX', '0');
  End;
End;

{ --------------------------------------------------------------------------
  GenIntrinsicInt2 : emettre le code pour une fonction intrinsèque entiere
  a 2 arguments. arg1 dans BX, arg2 dans CX a l'entree.
  Resultat dans AX.
  -------------------------------------------------------------------------- }
Procedure GenIntrinsicInt2(Const fname : TString);
Var lbl1, lbl2 : TString;
Begin
  { A l'entree : BX = arg1, CX = arg2 }
  If (fname = 'MOD') Or (fname = 'AMOD') Or (fname = 'DMOD')
  Or (fname = 'MODULO') Then
  Begin
    { MOD(a,b) = reste : AX := a ; CX := b ; CWD ; IDIV CX -> DX=reste }
    EmitI2('MOV', 'AX', 'BX');
    EmitComment('MOD : ' + fname);
    EmitI0('CWD');
    EmitI1('IDIV', 'CX');
    EmitI2('MOV', 'AX', 'DX');    { reste dans DX }
  End
  Else If (fname = 'MIN') Or (fname = 'MIN0') Or (fname = 'IMIN0')
       Or (fname = 'AMIN0') Or (fname = 'AMIN1') Or (fname = 'DMIN1') Then
  Begin
    lbl1 := GenBranchLabel;
    EmitI2('MOV', 'AX', 'BX');
    EmitI2('CMP', 'BX', 'CX');
    EmitI1('JLE', lbl1);           { si BX <= CX, BX est le min }
    EmitI2('MOV', 'AX', 'CX');    { sinon CX est le min }
    EmitLabel(lbl1);
  End
  Else If (fname = 'MAX') Or (fname = 'MAX0') Or (fname = 'IMAX0')
       Or (fname = 'AMAX0') Or (fname = 'AMAX1') Or (fname = 'DMAX1') Then
  Begin
    lbl1 := GenBranchLabel;
    EmitI2('MOV', 'AX', 'BX');
    EmitI2('CMP', 'BX', 'CX');
    EmitI1('JGE', lbl1);           { si BX >= CX, BX est le max }
    EmitI2('MOV', 'AX', 'CX');    { sinon CX est le max }
    EmitLabel(lbl1);
  End
  Else If (fname = 'DIM') Or (fname = 'IDIM') Or (fname = 'DDIM') Then
  Begin
    { DIM(a,b) = max(a-b, 0) }
    lbl1 := GenBranchLabel;
    EmitI2('MOV', 'AX', 'BX');
    EmitI2('SUB', 'AX', 'CX');       { AX = a - b }
    EmitI2('CMP', 'AX', '0');
    EmitI1('JG', lbl1);
    EmitI2('MOV', 'AX', '0');
    EmitLabel(lbl1);
  End
  Else If (fname = 'SIGN') Or (fname = 'ISIGN') Or (fname = 'DSIGN') Then
  Begin
    { SIGN(a,b) = |a| * sign(b) }
    lbl1 := GenBranchLabel;
    lbl2 := GenBranchLabel;
    EmitI2('MOV', 'AX', 'BX');
    EmitI2('CMP', 'AX', '0');
    EmitI1('JGE', lbl1);
    EmitI1('NEG', 'AX');           { AX = |a| }
    EmitLabel(lbl1);
    EmitI2('CMP', 'CX', '0');
    EmitI1('JGE', lbl2);
    EmitI1('NEG', 'AX');           { si b<0, neger }
    EmitLabel(lbl2);
  End
  Else If fname = 'IAND' Then
  Begin
    EmitI2('MOV', 'AX', 'BX');
    EmitI2('AND', 'AX', 'CX');
  End
  Else If fname = 'IOR' Then
  Begin
    EmitI2('MOV', 'AX', 'BX');
    EmitI2('OR',  'AX', 'CX');
  End
  Else If fname = 'IEOR' Then
  Begin
    EmitI2('MOV', 'AX', 'BX');
    EmitI2('XOR', 'AX', 'CX');
  End
  Else If (fname = 'ISHFT') Or (fname = 'ISHFTC') Then
  Begin
    { BX=valeur, CX=nombre de positions (>0=gauche, <0=droite) }
    lbl1 := GenBranchLabel;
    lbl2 := GenBranchLabel;
    EmitI2('MOV', 'AX', 'BX');
    EmitI2('TEST', 'CX', 'CX');
    EmitI1('JL', lbl1);
    EmitRaw('        SHL AX,CL');   { decalage gauche }
    EmitI1('JMP', lbl2);
    EmitLabel(lbl1);
    EmitI1('NEG', 'CX');
    EmitRaw('        SHR AX,CL');   { decalage droit logique }
    EmitLabel(lbl2);
  End
  Else If fname = 'IBCLR' Then
  Begin
    { IBCLR(a,b) = a AND NOT(1 << b) ; BX=a, CX=b }
    EmitI2('MOV', 'DX', '1');
    EmitRaw('        SHL DX,CL');
    EmitI1('NOT', 'DX');
    EmitI2('MOV', 'AX', 'BX');
    EmitI2('AND', 'AX', 'DX');
  End
  Else If fname = 'IBSET' Then
  Begin
    { IBSET(a,b) = a OR (1 << b) ; BX=a, CX=b }
    EmitI2('MOV', 'DX', '1');
    EmitRaw('        SHL DX,CL');
    EmitI2('MOV', 'AX', 'BX');
    EmitI2('OR',  'AX', 'DX');
  End
  Else If fname = 'BTEST' Then
  Begin
    { BTEST(a,b) = (a >> b) AND 1 ; BX=a, CX=b }
    EmitI2('MOV', 'AX', 'BX');
    EmitRaw('        SHR AX,CL');
    EmitI2('AND', 'AX', '1');
  End
  Else
  Begin
    WarnMsg('Fonction intrinsèque entiere 2-args non supportee : ' + fname);
    EmitI2('MOV', 'AX', '0');
  End;
End;

{ --------------------------------------------------------------------------
  ParseIntFactor : parser un primaire entier.
  Resultats dans AX.
  -------------------------------------------------------------------------- }
Procedure ParseIntFactor;
Var
  vname  : TString;
  idx    : Integer;
  ai     : Array[0..MAX_PARAM] of Integer;  { indices arg pour appel }
  nargs  : Integer;
  j      : Integer;  { boucle empilage args }
Begin
  { Entier litteral }
  If cur_tok.kind = TK_INTEGER Then
  Begin
    EmitI2('MOV', 'AX', IntToStr(cur_tok.int_val));
    LexNext;
  End

  { Parenthese }
  Else If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
  Begin
    LexNext;
    ParseIntExpr;
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
      LexNext
    Else
      ErrorMsg('Attendu ) apres expression entre parentheses');
  End

  { Identificateur : PARAMETER, variable, ou appel de fonction }
  Else If cur_tok.kind = TK_IDENT Then
  Begin
    vname := cur_tok.val;
    LexNext;
    idx := SymFind(vname);

    { Appel de fonction : IDENT ( }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
    Begin
      LexNext;
      nargs := 0;

      { ---- Fonctions a arguments CHARACTER ---- }
      If vname = 'LEN' Then
      Begin
        ParseCharExpr;              { AX=ptr, CX=longueur }
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
        EmitI2('MOV', 'AX', 'CX'); { retourner la longueur }
      End
      Else If vname = 'ICHAR' Then
      Begin
        ParseCharExpr;              { AX=ptr, CX=longueur }
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
        EmitI2('MOV', 'BX', 'AX');
        EmitRaw('        MOV AL,BYTE PTR [BX]');
        EmitI2('XOR', 'AH', 'AH'); { AX = code ASCII du premier caractere }
      End
      Else If (vname = 'LNBLNK') Or (vname = 'LEN_TRIM') Then
      Begin
        ParseCharExpr;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
        EmitI1('PUSH', 'CX');
        EmitI1('PUSH', 'AX');
        EmitRaw('        CALL ' + FRT_PFX + 'LNBLNK');
        EmitI2('ADD', 'SP', '4');
      End
      Else If vname = 'INDEX' Then
      Begin
        ParseCharExpr;
        EmitI1('PUSH', 'CX'); EmitI1('PUSH', 'AX');
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
        ParseCharExpr;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
        EmitI1('PUSH', 'CX'); EmitI1('PUSH', 'AX');
        EmitRaw('        CALL ' + FRT_PFX + 'INDEX');
        EmitI2('ADD', 'SP', '8');
      End
      Else
      Begin
        { ---- Boucle generique pour args entiers ---- }
        If Not ((cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')')) Then
        Repeat
          If (cur_tok.kind = TK_IDENT)
          And ((LexPeekKind = TK_PUNCT) And (LexPeekVal = ','))
          Or ((cur_tok.kind = TK_IDENT)
              And ((LexPeekKind = TK_PUNCT) And (LexPeekVal = ')')))
          Then
          Begin
            ai[nargs] := SymFind(cur_tok.val);
            If ai[nargs] = 0 Then ai[nargs] := SymGetOrCreate(cur_tok.val);
            LexNext;
            Inc(nargs);
          End
          Else
          Begin
            ParseIntExpr;
            ai[nargs] := 0;
            Inc(nargs);
          End;
          If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
            LexNext
          Else
            Break;
        Until (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')');

        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;

        { ---- Dispatch intrinsèques entiers ---- }
        If (nargs = 1) And ((vname = 'ABS') Or (vname = 'IABS')
          Or (vname = 'INT') Or (vname = 'IFIX') Or (vname = 'IDINT')
          Or (vname = 'NOT') Or (vname = 'LNOT')) Then
        Begin
          If ai[0] > 0 Then GenLoadInt(ai[0]);
          GenIntrinsicInt1(vname);
        End
        Else If (nargs = 2) And ((vname = 'MOD') Or (vname = 'MIN0')
          Or (vname = 'MAX0') Or (vname = 'MIN') Or (vname = 'MAX')
          Or (vname = 'IMAX0') Or (vname = 'IMIN0') Or (vname = 'DIM')
          Or (vname = 'IDIM') Or (vname = 'SIGN') Or (vname = 'ISIGN')
          Or (vname = 'IAND') Or (vname = 'IOR') Or (vname = 'IEOR')
          Or (vname = 'ISHFT') Or (vname = 'ISHFTC')
          Or (vname = 'IBCLR') Or (vname = 'IBSET') Or (vname = 'BTEST')) Then
        Begin
          If ai[0] > 0 Then GenLoadInt(ai[0]) Else EmitComment('arg1 = expr');
          EmitI2('MOV', 'BX', 'AX');
          If ai[1] > 0 Then GenLoadInt(ai[1]) Else EmitComment('arg2 = expr');
          EmitI2('MOV', 'CX', 'AX');
          GenIntrinsicInt2(vname);
        End
        Else
        Begin
          { Fonction utilisateur : passer les args par reference }
          EmitComment('CALL ' + vname + ' (' + IntToStr(nargs) + ' arg(s))');
          For j := nargs - 1 DownTo 0 Do
            If ai[j] > 0 Then GenPushArgByRef(ai[j])
            Else EmitComment('arg[' + IntToStr(j) + '] = expr (stub)');
          EmitRaw('        CALL ' + FP_PFX + vname);
          If nargs > 0 Then
            EmitI2('ADD', 'SP', IntToStr(nargs * 2));
          { Resultat dans AX }
        End;
      End;  { Else non-CHARACTER }
    End  { Appel de fonction }

    Else
    Begin
      { Variable scalaire ou PARAMETER }
      If idx = 0 Then idx := SymGetOrCreate(vname);
      GenLoadInt(idx);
    End;
  End  { TK_IDENT }

  Else
  Begin
    ErrorMsg('Facteur entier attendu, obtenu : ' + cur_tok.val);
    EmitI2('MOV', 'AX', '0');
    LexNext;
  End;
End;

{ --------------------------------------------------------------------------
  ParseIntPower : parser l'operateur ** (exposant entier, droit-assoc).
  base ** exp -> CALL _FRT_IPOW (AX=base, CX=exp -> AX=resultat)
  -------------------------------------------------------------------------- }
Procedure ParseIntPower;
Begin
  ParseIntFactor;

  { ** est droit-associatif : si on voit '**', on recurse sur ParseIntPower }
  If (cur_tok.kind = TK_OP) And (cur_tok.val = '**') Then
  Begin
    LexNext;
    EmitComment('** : puissance entiere via _FRT_IPOW');
    EmitI1('PUSH', 'AX');    { sauvegarder la base }
    ParseIntPower;            { recursion droite: exposant dans AX }
    EmitI2('MOV', 'CX', 'AX');
    EmitI1('POP', 'AX');     { restaurer la base }
    EmitRaw('        CALL ' + FRT_PFX + 'IPOW');
    { _FRT_IPOW : AX=base, CX=exposant -> AX=resultat }
  End;
End;

{ --------------------------------------------------------------------------
  ParseIntUnary : signe unaire optionnel + - avant ParseIntPower.
  -------------------------------------------------------------------------- }
Procedure ParseIntUnary;
Var neg : Boolean;
Begin
  neg := False;
  If (cur_tok.kind = TK_OP) And (cur_tok.val = '-') Then
  Begin neg := True;  LexNext; End
  Else If (cur_tok.kind = TK_OP) And (cur_tok.val = '+') Then
    LexNext;

  ParseIntPower;

  If neg Then EmitI1('NEG', 'AX');
End;

{ --------------------------------------------------------------------------
  ParseIntTerm : * / (gauche-associatif).
  -------------------------------------------------------------------------- }
Procedure ParseIntTerm;
Var op : TString;
Begin
  ParseIntUnary;

  While (cur_tok.kind = TK_OP)
    And ((cur_tok.val = '*') Or (cur_tok.val = '/')) Do
  Begin
    op := cur_tok.val;
    LexNext;
    EmitI1('PUSH', 'AX');
    ParseIntUnary;
    EmitI2('MOV', 'CX', 'AX');
    EmitI1('POP', 'AX');
    If op = '*' Then
    Begin
      EmitI1('IMUL', 'CX');
      { IMUL : DX:AX = AX * CX. On garde AX (16 bits). }
    End
    Else
    Begin
      { Division Fortran 77 : troncature vers zero (CWD + IDIV) }
      EmitI0('CWD');          { etendre AX -> DX:AX (signe) }
      EmitI1('IDIV', 'CX');  { AX = quotient, DX = reste }
    End;
  End;
End;

{ --------------------------------------------------------------------------
  ParseIntExpr : + - (gauche-associatif). Point d'entree principal.
  -------------------------------------------------------------------------- }
Procedure ParseIntExpr;
Var op : TString;
Begin
  ParseIntTerm;

  While (cur_tok.kind = TK_OP)
    And ((cur_tok.val = '+') Or (cur_tok.val = '-')) Do
  Begin
    op := cur_tok.val;
    LexNext;
    EmitI1('PUSH', 'AX');
    ParseIntTerm;
    EmitI2('MOV', 'CX', 'AX');
    EmitI1('POP', 'AX');
    If op = '+' Then
      EmitI2('ADD', 'AX', 'CX')
    Else
      EmitI2('SUB', 'AX', 'CX');
  End;
End;

{ ============================================================
  EXPRESSIONS ARITHMETIQUES REELLES ET DOUBLE PRECISION
  ============================================================
  Convention registres :
    REAL (4 octets IEEE 754) : DX = mot haut, AX = mot bas.
    DOUBLE (8 octets)        : traite comme REAL (stub reduit).
  Sauvegarde gauche : PUSH DX ; PUSH AX  (AX au sommet).
  Appel binaire _FRT_Fxxx :
    PUSH DX_gauche ; PUSH AX_gauche    (4 octets, deja sur pile)
    eval droite → DX:AX
    PUSH DX ; PUSH AX                  (4 octets droite)
    CALL _FRT_Fxxx  (pour les corps)
    ADD SP, 8                          (nettoyer 4 mots = 8 octets)
    Resultat dans DX:AX.
  Constantes reelles : label FK_nnn en .DATA inline (DD) chargé
    par deux MOV WORD PTR. IEEE 754 encode par FPC au compile-time.
  Conversions :
    INTEGER -> REAL : GenIntToReal  (CALL _FRT_ITOF)
    REAL -> INTEGER : GenRealToInt  (CALL _FRT_FTOI)
  ============================================================ }

Procedure ParseRealExpr; Forward;

{ --------------------------------------------------------------------------
  WordLoHi : decomposer un LongInt 32 bits en bas et haut 16 bits.
  -------------------------------------------------------------------------- }
Procedure WordLoHi(n : LongInt; Var lo, hi : Word);
Begin
  lo := Word(n And $FFFF);
  hi := Word((n Shr 16) And $FFFF);
End;

{ --------------------------------------------------------------------------
  RealToLong : convertir un Real Pascal en LongInt 32 bits (IEEE 754 single).
  Utilise le bloc de 4 octets memoire de la variable FPC.
  NOTE : FPC stocke Real (6 octets extended ou 4 octets single selon config).
  On utilise Single (4 octets) pour le format IEEE 754.
  -------------------------------------------------------------------------- }
Function RealToIEEE32(r : Real) : LongInt;
Var s : Single;
    n : LongInt;
Begin
  s := r;
  Move(s, n, 4);
  RealToIEEE32 := n;
End;

{ --------------------------------------------------------------------------
  GenRealConst : charger une constante reelle dans DX:AX.
  Pour 0.0 : XOR/XOR.
  Pour les autres : creer un label FK_nnn en .DATA (inline segment switch),
  puis charger via deux MOV WORD PTR.
  -------------------------------------------------------------------------- }
Procedure GenRealConst(r : Real; dt : TDataType);
Var lbl    : TString;
    ieee32 : LongInt;
    lo, hi : Word;
Begin
  If r = 0.0 Then
  Begin
    EmitI2('XOR', 'AX', 'AX');
    EmitI2('XOR', 'DX', 'DX');
    Exit;
  End;

  lbl    := GenDataLabel;
  ieee32 := RealToIEEE32(r);
  WordLoHi(ieee32, lo, hi);

  { Emettre la constante dans la section .DATA (switch inline MASM) }
  EmitRaw('        .DATA');
  EmitLabel(lbl);
  If dt = DT_DOUBLE Then
    EmitRaw('        DQ 0' + IntToStr(lo) + 'h, 0' + IntToStr(hi) + 'h  ; double ~' + IntToStr(Round(r)))
  Else
    EmitRaw('        DW 0' + IntToStr(lo) + 'h, 0' + IntToStr(hi) + 'h  ; real ~' + IntToStr(Round(r)));
  EmitRaw('        .CODE');

  { Charger dans DX:AX }
  EmitI2('MOV', 'AX', 'WORD PTR [' + lbl + ']');
  EmitI2('MOV', 'DX', 'WORD PTR [' + lbl + '+2]');
End;

{ --------------------------------------------------------------------------
  GenLoadReal : charger une variable REAL (ou DOUBLE) dans DX:AX.
  -------------------------------------------------------------------------- }
Procedure GenLoadReal(idx : Integer);
Var s : TSymRef;
Begin
  If (idx < 1) Or (idx > sym_count) Then
  Begin
    EmitI2('XOR', 'AX', 'AX');
    EmitI2('XOR', 'DX', 'DX');
    Exit;
  End;
  s := sym_table^[idx];
  If s.kind = SK_PARAM_CONST Then
  Begin
    GenRealConst(s.const_rval, s.dtype);
  End
  Else If s.bp_offset < 0 Then
  Begin
    EmitI2('MOV', 'AX', 'WORD PTR [BP' + IntToStr(s.bp_offset) + ']');
    EmitI2('MOV', 'DX', 'WORD PTR [BP' + IntToStr(s.bp_offset + 2) + ']');
  End
  Else If s.asm_label <> '' Then
  Begin
    EmitI2('MOV', 'AX', 'WORD PTR [' + s.asm_label + ']');
    EmitI2('MOV', 'DX', 'WORD PTR [' + s.asm_label + '+2]');
  End
  Else
  Begin
    EmitI2('XOR', 'AX', 'AX');
    EmitI2('XOR', 'DX', 'DX');
  End;
End;

{ --------------------------------------------------------------------------
  GenStoreReal : stocker DX:AX dans une variable REAL (ou DOUBLE).
  -------------------------------------------------------------------------- }
Procedure GenStoreReal(idx : Integer);
Var s : TSymRef;
Begin
  If (idx < 1) Or (idx > sym_count) Then Exit;
  s := sym_table^[idx];
  If s.is_dummy And (s.bp_offset > 0) Then
  Begin
    EmitI2('MOV', 'BX', 'WORD PTR [BP+' + IntToStr(s.bp_offset) + ']');
    EmitI2('MOV', 'WORD PTR [BX]', 'AX');
    EmitI2('MOV', 'WORD PTR [BX+2]', 'DX');
  End
  Else If s.bp_offset < 0 Then
  Begin
    EmitI2('MOV', 'WORD PTR [BP' + IntToStr(s.bp_offset) + ']', 'AX');
    EmitI2('MOV', 'WORD PTR [BP' + IntToStr(s.bp_offset + 2) + ']', 'DX');
  End
  Else If s.asm_label <> '' Then
  Begin
    EmitI2('MOV', 'WORD PTR [' + s.asm_label + ']', 'AX');
    EmitI2('MOV', 'WORD PTR [' + s.asm_label + '+2]', 'DX');
  End
  Else
    WarnMsg('GenStoreReal : symbole sans adresse - ' + s.name);
End;

{ --------------------------------------------------------------------------
  GenIntToReal : convertir AX (entier 16 bits signe) en DX:AX (REAL).
  Appel : PUSH AX (argument) ; CALL _FRT_ITOF ; ADD SP,2.
  -------------------------------------------------------------------------- }
Procedure GenIntToReal;
Begin
  EmitComment('Conversion INTEGER -> REAL (_FRT_ITOF)');
  EmitI1('PUSH', 'AX');
  EmitRaw('        CALL ' + FRT_PFX + 'ITOF');
  EmitI2('ADD', 'SP', '2');
  { Resultat dans DX:AX }
End;

{ --------------------------------------------------------------------------
  GenRealToInt : convertir DX:AX (REAL) en AX (entier, troncature vers 0).
  Appel : PUSH DX ; PUSH AX ; CALL _FRT_FTOI ; ADD SP,4.
  -------------------------------------------------------------------------- }
Procedure GenRealToInt;
Begin
  EmitComment('Conversion REAL -> INTEGER (_FRT_FTOI)');
  EmitI1('PUSH', 'DX');
  EmitI1('PUSH', 'AX');
  EmitRaw('        CALL ' + FRT_PFX + 'FTOI');
  EmitI2('ADD', 'SP', '4');
  { Resultat dans AX }
End;

{ --------------------------------------------------------------------------
  GenRealBinOp : emettre un appel a _FRT_Fxxx pour une operation binaire.
  Avant l'appel : gauche deja sauvee sur pile (PUSH DX_g ; PUSH AX_g).
  Droite dans DX:AX. On empile droite, puis appelle, puis nettoie.
  Convention pile (apres les 4 PUSH, croissant-vers-haut) :
    [SP+0]=AX_droit  [SP+2]=DX_droit
    [SP+4]=AX_gauche [SP+6]=DX_gauche
  -------------------------------------------------------------------------- }
Procedure GenRealBinOp(Const frt_name : TString);
Begin
  EmitI1('PUSH', 'DX');        { droite hi }
  EmitI1('PUSH', 'AX');        { droite lo }
  EmitRaw('        CALL ' + FRT_PFX + frt_name);
  EmitI2('ADD', 'SP', '8');   { nettoyer 4 mots (gauche + droite) }
  { Resultat dans DX:AX }
End;

{ --------------------------------------------------------------------------
  ParseRealFactor : parser un primaire reel. Resultat dans DX:AX.
  -------------------------------------------------------------------------- }
Procedure ParseRealFactor;
Var
  vname : TString;
  idx   : Integer;
Begin
  { Entier litteral : promouvoir en reel }
  If cur_tok.kind = TK_INTEGER Then
  Begin
    EmitI2('MOV', 'AX', IntToStr(cur_tok.int_val));
    LexNext;
    GenIntToReal;
  End

  { Reel litteral }
  Else If cur_tok.kind = TK_REAL Then
  Begin
    GenRealConst(cur_tok.real_val, DT_REAL);
    LexNext;
  End

  { Double litteral }
  Else If cur_tok.kind = TK_DOUBLE Then
  Begin
    GenRealConst(cur_tok.real_val, DT_DOUBLE);
    LexNext;
  End

  { Parenthese }
  Else If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
  Begin
    LexNext;
    ParseRealExpr;
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
      LexNext
    Else
      ErrorMsg('Attendu ) apres expression reelle entre parentheses');
  End

  { Identificateur : PARAMETER, variable reelle, conversion }
  Else If cur_tok.kind = TK_IDENT Then
  Begin
    vname := cur_tok.val;
    LexNext;

    { Appel de fonction : IDENT( }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
    Begin
      LexNext;

      { ---- Fonctions a 2 arguments reels ---- }
      If (vname = 'ATAN2') Or (vname = 'DATAN2') Or
         (vname = 'SIGN')  Or (vname = 'DSIGN') Or
         (vname = 'MOD')   Or (vname = 'AMOD')  Or (vname = 'DMOD') Or
         (vname = 'DIM')   Or (vname = 'DDIM') Then
      Begin
        ParseRealExpr;                              { arg1 -> DX:AX }
        EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX'); { sauver arg1 }
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
        ParseRealExpr;                              { arg2 -> DX:AX }
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
        EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX'); { arg2 }
        If (vname = 'ATAN2') Or (vname = 'DATAN2') Then
        Begin
          EmitRaw('        CALL ' + FRT_PFX + 'ATAN2');
          EmitI2('ADD', 'SP', '8');
        End
        Else If (vname = 'SIGN') Or (vname = 'DSIGN') Then
        Begin
          EmitRaw('        CALL ' + FRT_PFX + 'FSIGN');
          EmitI2('ADD', 'SP', '8');
        End
        Else If (vname = 'MOD') Or (vname = 'AMOD') Or (vname = 'DMOD') Then
        Begin
          EmitRaw('        CALL ' + FRT_PFX + 'FMOD');
          EmitI2('ADD', 'SP', '8');
        End
        Else
        Begin  { DIM, DDIM }
          EmitRaw('        CALL ' + FRT_PFX + 'FDIM');
          EmitI2('ADD', 'SP', '8');
        End;
      End

      { ---- AMIN1, AMAX1, DMIN1, DMAX1 : N >= 2 args (reduction pairwise) ---- }
      Else If (vname = 'AMIN1') Or (vname = 'DMIN1') Or
              (vname = 'AMAX1') Or (vname = 'DMAX1') Then
      Begin
        ParseRealExpr;   { accumulateur initial dans DX:AX }
        While (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Do
        Begin
          LexNext;
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          ParseRealExpr;
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          If (vname = 'AMIN1') Or (vname = 'DMIN1') Then
          Begin
            EmitRaw('        CALL ' + FRT_PFX + 'FMIN');
            EmitI2('ADD', 'SP', '8');
          End
          Else
          Begin
            EmitRaw('        CALL ' + FRT_PFX + 'FMAX');
            EmitI2('ADD', 'SP', '8');
          End;
        End;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
      End

      { ---- Fonctions a 1 argument reel ---- }
      Else
      Begin
        ParseRealExpr;   { arg1 -> DX:AX }
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;

        If (vname = 'ABS') Or (vname = 'DABS') Or (vname = 'CABS') Then
        Begin
          EmitI2('AND', 'DH', '7Fh');
        End
        Else If (vname = 'FLOAT') Or (vname = 'REAL') Or (vname = 'SNGL')
             Or (vname = 'DBLE') Then
        Begin
          EmitComment(vname + ' : conversion vers reel');
        End
        Else If (vname = 'IFIX') Or (vname = 'INT') Or (vname = 'IDINT') Then
        Begin
          GenRealToInt;
          GenIntToReal;
        End
        Else If (vname = 'SQRT') Or (vname = 'DSQRT') Then
        Begin
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          EmitRaw('        CALL ' + FRT_PFX + 'SQRT');
          EmitI2('ADD', 'SP', '4');
        End
        Else If (vname = 'EXP') Or (vname = 'DEXP') Then
        Begin
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          EmitRaw('        CALL ' + FRT_PFX + 'EXP');
          EmitI2('ADD', 'SP', '4');
        End
        Else If (vname = 'LOG') Or (vname = 'ALOG') Or (vname = 'DLOG') Then
        Begin
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          EmitRaw('        CALL ' + FRT_PFX + 'LOG');
          EmitI2('ADD', 'SP', '4');
        End
        Else If (vname = 'LOG10') Or (vname = 'ALOG10') Or (vname = 'DLOG10') Then
        Begin
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          EmitRaw('        CALL ' + FRT_PFX + 'LOG10');
          EmitI2('ADD', 'SP', '4');
        End
        Else If (vname = 'SIN') Or (vname = 'DSIN') Then
        Begin
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          EmitRaw('        CALL ' + FRT_PFX + 'SIN');
          EmitI2('ADD', 'SP', '4');
        End
        Else If (vname = 'COS') Or (vname = 'DCOS') Then
        Begin
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          EmitRaw('        CALL ' + FRT_PFX + 'COS');
          EmitI2('ADD', 'SP', '4');
        End
        Else If (vname = 'TAN') Or (vname = 'DTAN') Then
        Begin
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          EmitRaw('        CALL ' + FRT_PFX + 'TAN');
          EmitI2('ADD', 'SP', '4');
        End
        Else If (vname = 'ATAN') Or (vname = 'DATAN') Then
        Begin
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          EmitRaw('        CALL ' + FRT_PFX + 'ATAN');
          EmitI2('ADD', 'SP', '4');
        End
        Else If (vname = 'ASIN') Or (vname = 'DASIN') Then
        Begin
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          EmitRaw('        CALL ' + FRT_PFX + 'ASIN');
          EmitI2('ADD', 'SP', '4');
        End
        Else If (vname = 'ACOS') Or (vname = 'DACOS') Then
        Begin
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          EmitRaw('        CALL ' + FRT_PFX + 'ACOS');
          EmitI2('ADD', 'SP', '4');
        End
        Else If (vname = 'SINH') Or (vname = 'DSINH') Then
        Begin
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          EmitRaw('        CALL ' + FRT_PFX + 'SINH');
          EmitI2('ADD', 'SP', '4');
        End
        Else If (vname = 'COSH') Or (vname = 'DCOSH') Then
        Begin
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          EmitRaw('        CALL ' + FRT_PFX + 'COSH');
          EmitI2('ADD', 'SP', '4');
        End
        Else If (vname = 'TANH') Or (vname = 'DTANH') Then
        Begin
          EmitI1('PUSH', 'DX'); EmitI1('PUSH', 'AX');
          EmitRaw('        CALL ' + FRT_PFX + 'TANH');
          EmitI2('ADD', 'SP', '4');
        End
        Else
        Begin
          { Fonction utilisateur reelle : resultat dans DX:AX }
          EmitComment('CALL reel ' + vname);
          EmitRaw('        CALL ' + FP_PFX + vname);
        End;
      End;  { 1-arg }
    End  { appel de fonction }

    Else
    Begin
      { Variable scalaire ou PARAMETER reel }
      idx := SymFind(vname);
      If idx = 0 Then idx := SymGetOrCreate(vname);
      If sym_table^[idx].dtype = DT_INTEGER Then
      Begin
        { Variable entiere dans un contexte reel : promouvoir }
        GenLoadInt(idx);
        GenIntToReal;
      End
      Else
        GenLoadReal(idx);
    End;
  End  { TK_IDENT }

  Else
  Begin
    ErrorMsg('Facteur reel attendu, obtenu : ' + cur_tok.val);
    EmitI2('XOR', 'AX', 'AX');
    EmitI2('XOR', 'DX', 'DX');
    LexNext;
  End;
End;

{ --------------------------------------------------------------------------
  ParseRealPower : ** (droit-associatif, via _FRT_FPOW).
  -------------------------------------------------------------------------- }
Procedure ParseRealPower;
Begin
  ParseRealFactor;

  If (cur_tok.kind = TK_OP) And (cur_tok.val = '**') Then
  Begin
    LexNext;
    EmitComment('** reel via _FRT_FPOW');
    EmitI1('PUSH', 'DX');     { sauvegarder base hi }
    EmitI1('PUSH', 'AX');     { sauvegarder base lo }
    ParseRealPower;            { recursion droite : exposant dans DX:AX }
    GenRealBinOp('FPOW');
  End;
End;

{ --------------------------------------------------------------------------
  ParseRealUnary : signe unaire + - avant ParseRealPower.
  -------------------------------------------------------------------------- }
Procedure ParseRealUnary;
Var neg : Boolean;
Begin
  neg := False;
  If (cur_tok.kind = TK_OP) And (cur_tok.val = '-') Then
  Begin neg := True; LexNext; End
  Else If (cur_tok.kind = TK_OP) And (cur_tok.val = '+') Then
    LexNext;

  ParseRealPower;

  If neg Then
  Begin
    EmitComment('NEG reel (_FRT_FNEG)');
    EmitI1('PUSH', 'DX');
    EmitI1('PUSH', 'AX');
    EmitRaw('        CALL ' + FRT_PFX + 'FNEG');
    EmitI2('ADD', 'SP', '4');
  End;
End;

{ --------------------------------------------------------------------------
  ParseRealTerm : * / (gauche-associatif, via _FRT_FMUL / _FRT_FDIV).
  -------------------------------------------------------------------------- }
Procedure ParseRealTerm;
Var op : TString;
Begin
  ParseRealUnary;

  While (cur_tok.kind = TK_OP)
    And ((cur_tok.val = '*') Or (cur_tok.val = '/')) Do
  Begin
    op := cur_tok.val;
    LexNext;
    EmitI1('PUSH', 'DX');    { sauvegarder gauche hi }
    EmitI1('PUSH', 'AX');    { sauvegarder gauche lo }
    ParseRealUnary;
    If op = '*' Then
      GenRealBinOp('FMUL')
    Else
      GenRealBinOp('FDIV');
  End;
End;

{ --------------------------------------------------------------------------
  ParseRealExpr : + - (gauche-associatif, via _FRT_FADD / _FRT_FSUB).
  Point d'entree principal pour les expressions reelles.
  -------------------------------------------------------------------------- }
Procedure ParseRealExpr;
Var op : TString;
Begin
  ParseRealTerm;

  While (cur_tok.kind = TK_OP)
    And ((cur_tok.val = '+') Or (cur_tok.val = '-')) Do
  Begin
    op := cur_tok.val;
    LexNext;
    EmitI1('PUSH', 'DX');    { sauvegarder gauche hi }
    EmitI1('PUSH', 'AX');    { sauvegarder gauche lo }
    ParseRealTerm;
    If op = '+' Then
      GenRealBinOp('FADD')
    Else
      GenRealBinOp('FSUB');
  End;
End;

{ ============================================================
  EXPRESSIONS LOGIQUES ET RELATIONNELLES
  ============================================================
  Priorite F77 (du plus fort au plus faible) :
    expressions arithmetiques
    .NOT.
    .AND.
    .OR.
    .EQV. / .NEQV.
  Convention : .TRUE. = -1 (0FFFFh), .FALSE. = 0 (meme que BCPL86).
  Relations entre entiers : CMP AX,CX + Jxx inline.
  Relations entre reels : CALL _FRT_FCMP (stub).
  Operateurs logiques : NOT/AND/OR/XOR/XNOR directs sur 16 bits.
  ============================================================ }

Procedure ParseLogExpr; Forward;

{ --------------------------------------------------------------------------
  GenCmpIntRelop : apres CMP AX,CX, emettre le code qui met AX := -1 ou 0
  selon l'operateur relop (EQ NE LT LE GT GE).
  Technique : un saut conditionnel vers un label "vrai", AX:=0, JMP done,
  label_vrai: AX:=-1, label_done:.
  -------------------------------------------------------------------------- }
Procedure GenCmpIntRelop(Const relop : TString);
Var lbl_true, lbl_done : TString;
Begin
  lbl_true := GenBranchLabel;
  lbl_done := GenBranchLabel;

  { Le CMP AX,CX est deja emis par l'appelant }
  If relop = 'EQ' Then      EmitI1('JE',  lbl_true)
  Else If relop = 'NE' Then EmitI1('JNE', lbl_true)
  Else If relop = 'LT' Then EmitI1('JL',  lbl_true)
  Else If relop = 'LE' Then EmitI1('JLE', lbl_true)
  Else If relop = 'GT' Then EmitI1('JG',  lbl_true)
  Else If relop = 'GE' Then EmitI1('JGE', lbl_true)
  Else
  Begin
    WarnMsg('GenCmpIntRelop : relop inconnu ' + relop);
    EmitI1('JE', lbl_true);
  End;

  { Branche FALSE }
  EmitI2('MOV', 'AX', '0');
  EmitI1('JMP', lbl_done);

  { Branche TRUE }
  EmitLabel(lbl_true);
  EmitI2('MOV', 'AX', '0FFFFh');   { -1 en complement a deux }

  EmitLabel(lbl_done);
End;

{ --------------------------------------------------------------------------
  ParseRelExpr : expression avec operateurs relationnels.
  Syntaxe : arith_expr [relop arith_expr]
  Resultat dans AX : -1 (.TRUE.) ou 0 (.FALSE.).
  Pour les reels, on appelle _FRT_FCMP puis on interprete AX comme signe.
  -------------------------------------------------------------------------- }
Procedure ParseRelExpr;
Var
  relop  : TString;
  ldt    : TDataType;   { type detecte a gauche }
  lbl_t, lbl_d : TString;
  li     : Integer;     { index symbole gauche pour detection de type }
Begin
  { Evaluer le cote gauche }
  { Heuristique de type : si le token courant est TK_REAL ou TK_DOUBLE,
    ou si c'est un ident avec dtype REAL/DOUBLE -> ParseRealExpr.
    Sinon ParseIntExpr. On fait une detection simple ici. }
  ldt := DT_INTEGER;
  If (cur_tok.kind = TK_REAL) Or (cur_tok.kind = TK_DOUBLE) Then
    ldt := DT_REAL
  Else If (cur_tok.kind = TK_IDENT) Then
  Begin
    li := SymFind(cur_tok.val);
    If li > 0 Then
      If (sym_table^[li].dtype = DT_REAL) Or (sym_table^[li].dtype = DT_DOUBLE)
      Then ldt := DT_REAL;
  End;

  If ldt = DT_REAL Then
    ParseRealExpr
  Else
    ParseIntExpr;

  { Relop optionnel }
  If cur_tok.kind <> TK_RELOP Then Exit;   { expression logique simple }

  relop := cur_tok.val;
  LexNext;

  { Evaluer cote droit }
  If ldt = DT_REAL Then
  Begin
    { Sauvegarder gauche (DX:AX) sur pile }
    EmitI1('PUSH', 'DX');
    EmitI1('PUSH', 'AX');
    ParseRealExpr;
    { droite dans DX:AX, empiler pour _FRT_FCMP }
    EmitI1('PUSH', 'DX');
    EmitI1('PUSH', 'AX');
    EmitComment('Comparaison reelle _FRT_FCMP .' + relop + '.');
    EmitRaw('        CALL ' + FRT_PFX + 'FCMP');
    EmitI2('ADD', 'SP', '8');   { nettoyer 4 mots (gauche + droite) }
    { _FRT_FCMP retourne dans AX : -1 si g<d, 0 si g=d, +1 si g>d }
    { Interpreter selon relop -> generer -1/0 dans AX }
    EmitI2('CMP', 'AX', '0');
    lbl_t := GenBranchLabel;
    lbl_d := GenBranchLabel;
    If relop = 'EQ' Then      EmitI1('JE',  lbl_t)
    Else If relop = 'NE' Then EmitI1('JNE', lbl_t)
    Else If relop = 'LT' Then EmitI1('JL',  lbl_t)
    Else If relop = 'LE' Then EmitI1('JLE', lbl_t)
    Else If relop = 'GT' Then EmitI1('JG',  lbl_t)
    Else If relop = 'GE' Then EmitI1('JGE', lbl_t)
    Else EmitI1('JE', lbl_t);
    EmitI2('MOV', 'AX', '0');
    EmitI1('JMP', lbl_d);
    EmitLabel(lbl_t);
    EmitI2('MOV', 'AX', '0FFFFh');
    EmitLabel(lbl_d);
  End
  Else
  Begin
    { Entiers : sauvegarder gauche dans CX }
    EmitI2('MOV', 'CX', 'AX');
    ParseIntExpr;
    { droite dans AX, echanger : on veut gauche dans AX, droite dans CX }
    EmitI2('XCHG', 'AX', 'CX');
    EmitComment('Comparaison entiere .' + relop + '.');
    EmitI2('CMP', 'AX', 'CX');
    GenCmpIntRelop(relop);
  End;
End;

{ --------------------------------------------------------------------------
  ParseLogPrimary : primaire logique.
  Reconnu : .TRUE./.FALSE., variable LOGICAL, (expr_logique),
            ou expression relationnelle.
  -------------------------------------------------------------------------- }
Procedure ParseLogPrimary;
Var idx : Integer;
Begin
  { .TRUE. ou .FALSE. }
  If cur_tok.kind = TK_LOGICAL Then
  Begin
    If cur_tok.val = 'TRUE' Then
      EmitI2('MOV', 'AX', '0FFFFh')
    Else
      EmitI2('MOV', 'AX', '0');
    LexNext;
    Exit;
  End;

  { Parenthese : sous-expression logique }
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
  Begin
    LexNext;
    ParseLogExpr;
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
      LexNext
    Else
      ErrorMsg('Attendu ) apres expression logique');
    Exit;
  End;

  { Variable LOGICAL ou expression relationnelle }
  If cur_tok.kind = TK_IDENT Then
  Begin
    idx := SymFind(cur_tok.val);
    If (idx > 0) And (sym_table^[idx].dtype = DT_LOGICAL)
    And (LexPeekKind <> TK_RELOP)
    And Not ((LexPeekKind = TK_PUNCT) And (LexPeekVal = '('))
    Then
    Begin
      { Charger la variable logique directement }
      GenLoadInt(idx);
      LexNext;
      Exit;
    End;
  End;

  { Sinon : expression relationnelle (arithmetique + relop optionnel) }
  ParseRelExpr;
End;

{ --------------------------------------------------------------------------
  ParseLogNot : .NOT. expr (unaire, droit-associatif).
  -------------------------------------------------------------------------- }
Procedure ParseLogNot;
Var has_not : Boolean;
Begin
  has_not := False;
  If (cur_tok.kind = TK_LOGOP) And (cur_tok.val = 'NOT') Then
  Begin
    has_not := True;
    LexNext;
  End;

  ParseLogPrimary;

  If has_not Then
  Begin
    EmitComment('.NOT.');
    EmitI1('NOT', 'AX');
  End;
End;

{ --------------------------------------------------------------------------
  ParseLogAnd : expr .AND. expr (gauche-associatif).
  -------------------------------------------------------------------------- }
Procedure ParseLogAnd;
Begin
  ParseLogNot;

  While (cur_tok.kind = TK_LOGOP) And (cur_tok.val = 'AND') Do
  Begin
    LexNext;
    EmitI1('PUSH', 'AX');
    ParseLogNot;
    EmitI2('MOV', 'CX', 'AX');
    EmitI1('POP', 'AX');
    EmitComment('.AND.');
    EmitI2('AND', 'AX', 'CX');
  End;
End;

{ --------------------------------------------------------------------------
  ParseLogOr : expr .OR. expr (gauche-associatif).
  -------------------------------------------------------------------------- }
Procedure ParseLogOr;
Begin
  ParseLogAnd;

  While (cur_tok.kind = TK_LOGOP) And (cur_tok.val = 'OR') Do
  Begin
    LexNext;
    EmitI1('PUSH', 'AX');
    ParseLogAnd;
    EmitI2('MOV', 'CX', 'AX');
    EmitI1('POP', 'AX');
    EmitComment('.OR.');
    EmitI2('OR', 'AX', 'CX');
  End;
End;

{ --------------------------------------------------------------------------
  ParseLogExpr : expr .EQV./.NEQV. expr (gauche-associatif).
  .EQV.  = XNOR = NOT XOR : AX := NOT (AX XOR CX)
  .NEQV. = XOR             : AX := AX XOR CX
  Point d'entree principal pour les expressions logiques.
  -------------------------------------------------------------------------- }
Procedure ParseLogExpr;
Var op : TString;
Begin
  ParseLogOr;

  While (cur_tok.kind = TK_LOGOP)
    And ((cur_tok.val = 'EQV') Or (cur_tok.val = 'NEQV')) Do
  Begin
    op := cur_tok.val;
    LexNext;
    EmitI1('PUSH', 'AX');
    ParseLogOr;
    EmitI2('MOV', 'CX', 'AX');
    EmitI1('POP', 'AX');
    EmitI2('XOR', 'AX', 'CX');
    If op = 'EQV' Then
    Begin
      EmitComment('.EQV. (XNOR)');
      EmitI1('NOT', 'AX');
    End
    Else
      EmitComment('.NEQV. (XOR)');
  End;
End;

{ ============================================================
  EXPRESSIONS CARACTERES (CHARACTER)
  ============================================================
  Convention registres pour les expressions CHARACTER :
    AX = adresse (offset near) de la chaine dans DS
    CX = longueur en octets
  Format Fortran 77 : blank-padded, longueur fixe, non null-terminated.
  Litteraux de chaine : label FK_nnn cree en .DATA inline.

  Primitives emises :
    GenStrLiteral(s,n)         -- label FK_nnn + DB + charge AX,CX
    GenLoadStrAddr(idx)        -- AX=offset, CX=char_len pour variable
    GenSubstrAddr(idx,lo,hi)   -- AX=offset+lo-1, CX=hi-lo+1
    GenStrConcat(...)          -- CALL _FRT_SCAT
    GenStrAssign(dst_idx)      -- CALL _FRT_SCOPY
  Fonctions intrinsèques :
    LEN(s)   -> MOV AX, char_len
    INDEX(s1,s2) -> CALL _FRT_INDEX -> AX=position (1-based, 0=absent)
    CHAR(i)  -> CALL _FRT_CHAR  -> AX=adresse d'un octet temp
    ICHAR(s) -> CALL _FRT_ICHAR -> AX=code ASCII premier caractere
  ============================================================ }

{ --------------------------------------------------------------------------
  GenStrLiteral : emettre une constante chaine en .DATA, charger AX + CX.
  AX = offset de la chaine, CX = longueur.
  -------------------------------------------------------------------------- }
Procedure GenStrLiteral(Const s : TString);
Var lbl : TString;
    n   : Integer;
Begin
  n   := Length(s);
  lbl := GenDataLabel;

  { Emettre la chaine dans .DATA }
  EmitRaw('        .DATA');
  EmitLabel(lbl);
  If n = 0 Then
    EmitRaw('        DB 1 DUP('' '')')  { chaine vide = 1 espace }
  Else
    EmitDBStr(s);
  EmitRaw('        .CODE');

  { Charger adresse et longueur }
  EmitI2('MOV', 'AX', 'OFFSET ' + lbl);
  EmitI2('MOV', 'CX', IntToStr(n));
End;

{ --------------------------------------------------------------------------
  GenLoadStrAddr : charger l'adresse et la longueur d'une variable CHARACTER.
  AX = offset, CX = char_len.
  -------------------------------------------------------------------------- }
Procedure GenLoadStrAddr(idx : Integer);
Var s : TSymRef;
Begin
  If (idx < 1) Or (idx > sym_count) Then
  Begin
    EmitI2('MOV', 'AX', '0');
    EmitI2('MOV', 'CX', '0');
    Exit;
  End;
  s := sym_table^[idx];
  EmitI2('MOV', 'CX', IntToStr(s.char_len));
  If s.bp_offset < 0 Then
    EmitI2('LEA', 'AX', '[BP' + IntToStr(s.bp_offset) + ']')
  Else If s.asm_label <> '' Then
    EmitI2('MOV', 'AX', 'OFFSET ' + s.asm_label)
  Else
    EmitI2('MOV', 'AX', '0');
End;

{ --------------------------------------------------------------------------
  GenSubstrAddr : sous-chaine var(lo:hi).
  AX = adresse + lo - 1, CX = hi - lo + 1.
  lo et hi sont des valeurs connues a la compilation (constantes simples).
  Si lo ou hi = 0 -> valeurs par defaut (1 ou char_len).
  -------------------------------------------------------------------------- }
Procedure GenSubstrAddr(idx : Integer; lo_val, hi_val : Integer);
Var s   : TSymRef;
    eff : Integer;   { longueur effective }
Begin
  If (idx < 1) Or (idx > sym_count) Then
  Begin
    EmitI2('MOV', 'AX', '0');
    EmitI2('MOV', 'CX', '1');
    Exit;
  End;
  s := sym_table^[idx];

  { Valeurs par defaut }
  If lo_val < 1 Then lo_val := 1;
  If (hi_val < 1) Or (hi_val > s.char_len) Then hi_val := s.char_len;
  eff := hi_val - lo_val + 1;
  If eff < 0 Then eff := 0;

  EmitI2('MOV', 'CX', IntToStr(eff));
  If s.bp_offset < 0 Then
    EmitI2('LEA', 'AX', '[BP' + IntToStr(s.bp_offset + lo_val - 1) + ']')
  Else If s.asm_label <> '' Then
  Begin
    EmitI2('MOV', 'AX', 'OFFSET ' + s.asm_label);
    If lo_val > 1 Then
      EmitI2('ADD', 'AX', IntToStr(lo_val - 1));
  End
  Else
    EmitI2('MOV', 'AX', '0');
End;

{ --------------------------------------------------------------------------
  SaveStrOnStack : sauvegarder AX+CX sur la pile avant d'evaluer
  le membre droit d'une concatenation.
  Retour : PUSH AX (adresse) puis PUSH CX (longueur).
  Apres l'eval du membre droit, la pile contient :
    [SP+0]=CX_g [SP+2]=AX_g  [SP+4]=CX_d [SP+6]=AX_d
  -------------------------------------------------------------------------- }
Procedure SaveStrOnStack;
Begin
  EmitI1('PUSH', 'AX');   { adresse gauche }
  EmitI1('PUSH', 'CX');   { longueur gauche }
End;

{ --------------------------------------------------------------------------
  GenStrConcat : concatenation //.
  Avant l'appel :
    AX=addr_gauche CX=len_gauche (sauves sur pile par SaveStrOnStack)
    AX=addr_droit  CX=len_droit  (dans registres)
  Genere un buffer temporaire dans la pile puis appelle _FRT_SCAT.
  Convention _FRT_SCAT (4 args par ref) :
    PUSH WORD len_droit
    PUSH WORD addr_droit
    PUSH WORD len_gauche
    PUSH WORD addr_gauche
    CALL _FRT_SCAT
    ADD SP, 8
  Resultat dans AX (adresse du buffer interne), CX = len_gauche + len_droit.
  -------------------------------------------------------------------------- }
Procedure GenStrConcat;
Begin
  { La pile contient : [SP] = len_g, [SP+2] = addr_g }
  { AX = addr_d, CX = len_d }
  EmitComment('Concatenation // via _FRT_SCAT');
  EmitI1('PUSH', 'CX');   { len_droit }
  EmitI1('PUSH', 'AX');   { addr_droit }
  { Recuperer gauche depuis pile : [SP+4]=len_g, [SP+6]=addr_g }
  EmitI2('MOV', 'BX', 'SP');
  EmitRaw('        PUSH WORD PTR [BX+6]');   { addr_gauche }
  EmitRaw('        PUSH WORD PTR [BX+4]');   { len_gauche  }
  EmitRaw('        CALL ' + FRT_PFX + 'SCAT');
  EmitI2('ADD', 'SP', '8');
  { Nettoyer les 2 mots gauche restes sur pile }
  EmitI2('ADD', 'SP', '4');
  { AX = adresse resultat, CX = longueur totale (retournee dans _FRT_SCAT) }
End;

{ --------------------------------------------------------------------------
  GenStrAssign : affectation d'une expression CHARACTER dans une variable.
  AX = addr_src, CX = len_src (dans registres).
  Genere CALL _FRT_SCOPY(dst_addr, dst_len, src_addr, src_len).
  _FRT_SCOPY gere la troncature et le remplissage par espaces.
  -------------------------------------------------------------------------- }
Procedure GenStrAssign(dst_idx : Integer);
Var s : TSymRef;
Begin
  If (dst_idx < 1) Or (dst_idx > sym_count) Then Exit;
  s := sym_table^[dst_idx];

  EmitComment('Affectation CHARACTER -> ' + s.name + ' via _FRT_SCOPY');
  EmitI1('PUSH', 'CX');                           { src_len }
  EmitI1('PUSH', 'AX');                           { src_addr }
  EmitI2('MOV', 'BX', IntToStr(s.char_len));
  EmitI1('PUSH', 'BX');                           { dst_len }
  If s.bp_offset < 0 Then
  Begin
    EmitI2('LEA', 'BX', '[BP' + IntToStr(s.bp_offset) + ']');
    EmitI1('PUSH', 'BX');
  End
  Else
  Begin
    EmitI2('MOV', 'BX', 'OFFSET ' + s.asm_label);
    EmitI1('PUSH', 'BX');
  End;
  EmitRaw('        CALL ' + FRT_PFX + 'SCOPY');
  EmitI2('ADD', 'SP', '8');
End;

{ --------------------------------------------------------------------------
  ParseCharPrimary : parser un primaire CHARACTER.
  Reconnu :
    - Litterale 'texte'
    - Variable CHARACTER (scalaire ou element de tableau)
    - Variable(lo:hi) = sous-chaine
    - Fonctions LEN, INDEX, CHAR, ICHAR (resultat entier ou adresse)
  Resultat : AX = adresse, CX = longueur.
  -------------------------------------------------------------------------- }
Procedure ParseCharPrimary;
Var
  vname  : TString;
  idx    : Integer;
  lo_val : Integer;
  hi_val : Integer;
  pt     : TToken;
Begin
  { Litterale de chaine }
  If (cur_tok.kind = TK_STRING) Or (cur_tok.kind = TK_HOLLERITH) Then
  Begin
    GenStrLiteral(cur_tok.val);
    LexNext;
    Exit;
  End;

  { Parenthese }
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
  Begin
    LexNext;
    ParseCharPrimary;   { recursion (pas de concatenation dans les parens) }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
    Exit;
  End;

  { Identificateur }
  If cur_tok.kind <> TK_IDENT Then
  Begin
    ErrorMsg('Expression CHARACTER attendue, obtenu : ' + cur_tok.val);
    EmitI2('MOV', 'AX', '0'); EmitI2('MOV', 'CX', '0');
    LexNext;
    Exit;
  End;

  vname := cur_tok.val;
  LexNext;

  { Fonctions intrinsèques CHARACTER }
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
  Begin
    LexNext;

    If vname = 'LEN' Then
    Begin
      { LEN(str) -> AX = char_len de la variable }
      If cur_tok.kind = TK_IDENT Then
      Begin
        idx := SymFind(cur_tok.val);
        If idx > 0 Then
          EmitI2('MOV', 'AX', IntToStr(sym_table^[idx].char_len))
        Else
          EmitI2('MOV', 'AX', '0');
        LexNext;
      End
      Else
      Begin
        ParseCharPrimary;   { AX = addr, CX = longueur }
        EmitI2('MOV', 'AX', 'CX');
      End;
      EmitI2('MOV', 'CX', '2');   { resultat = entier 2 octets }
    End

    Else If vname = 'INDEX' Then
    Begin
      { INDEX(str, substr) -> CALL _FRT_INDEX -> AX = position (1-based ou 0) }
      ParseCharPrimary;              { AX=addr_str, CX=len_str }
      EmitI1('PUSH', 'CX');
      EmitI1('PUSH', 'AX');
      LexExpect(',');
      ParseCharPrimary;              { AX=addr_substr, CX=len_substr }
      EmitI1('PUSH', 'CX');
      EmitI1('PUSH', 'AX');
      EmitRaw('        CALL ' + FRT_PFX + 'INDEX');
      EmitI2('ADD', 'SP', '8');
      { AX = position }
      EmitI2('MOV', 'CX', '2');
    End

    Else If vname = 'CHAR' Then
    Begin
      { CHAR(i) -> CALL _FRT_CHAR -> AX = adresse d'un octet temporaire }
      ParseIntExpr;          { AX = code ASCII }
      EmitI1('PUSH', 'AX');
      EmitRaw('        CALL ' + FRT_PFX + 'CHAR');
      EmitI2('ADD', 'SP', '2');
      EmitI2('MOV', 'CX', '1');
    End

    Else If vname = 'ICHAR' Then
    Begin
      { ICHAR(str) -> code ASCII du premier caractere }
      ParseCharPrimary;
      EmitI1('PUSH', 'CX');
      EmitI1('PUSH', 'AX');
      EmitRaw('        CALL ' + FRT_PFX + 'ICHAR');
      EmitI2('ADD', 'SP', '4');
      EmitI2('MOV', 'CX', '2');
    End

    Else If vname = 'LNBLNK' Then
    Begin
      { LNBLNK(str) = longueur sans espaces finaux }
      ParseCharPrimary;
      EmitI1('PUSH', 'CX');
      EmitI1('PUSH', 'AX');
      EmitRaw('        CALL ' + FRT_PFX + 'LNBLNK');
      EmitI2('ADD', 'SP', '4');
      EmitI2('MOV', 'CX', '2');
    End

    Else
    Begin
      { Appel de fonction CHARACTER utilisateur / non reconnu }
      EmitComment('Appel fonction CHARACTER ' + vname);
      ParseCharPrimary;
      EmitI1('PUSH', 'CX');
      EmitI1('PUSH', 'AX');
      EmitRaw('        CALL ' + FP_PFX + vname);
      EmitI2('ADD', 'SP', '4');
    End;

    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
    Exit;
  End;

  { Variable scalaire CHARACTER ou sous-chaine }
  idx := SymFind(vname);
  If idx = 0 Then idx := SymGetOrCreate(vname);

  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
  Begin
    { Peut etre tableau(idx) ou sous-chaine(lo:hi) }
    LexNext;
    lo_val := 1; hi_val := 0;

    { Detecter si c'est une sous-chaine : on regarde apres l'entier }
    If cur_tok.kind = TK_INTEGER Then
    Begin
      lo_val := cur_tok.int_val;
      LexNext;
    End;

    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ':') Then
    Begin
      { Sous-chaine : var(lo:hi) }
      LexNext;
      If cur_tok.kind = TK_INTEGER Then
      Begin
        hi_val := cur_tok.int_val;
        LexNext;
      End;
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
      GenSubstrAddr(idx, lo_val, hi_val);
    End
    Else
    Begin
      { Acces tableau : ignorer l'indice pour l'instant (stub) }
      EmitComment('Acces tableau CHARACTER ' + vname + '(' + IntToStr(lo_val) + ') stub');
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
      GenLoadStrAddr(idx);
    End;
  End
  Else
  Begin
    { Variable scalaire ordinaire }
    GenLoadStrAddr(idx);
  End;
End;

{ --------------------------------------------------------------------------
  ParseCharExpr : expression CHARACTER avec concatenation //.
  // est gauche-associatif.
  Resultat : AX = adresse, CX = longueur.
  -------------------------------------------------------------------------- }
Procedure ParseCharExpr;
Begin
  ParseCharPrimary;

  While (cur_tok.kind = TK_OP) And (cur_tok.val = '//') Do
  Begin
    LexNext;
    SaveStrOnStack;
    ParseCharPrimary;
    GenStrConcat;
  End;
End;

{ ============================================================
  TABLE DES LABELS ET INSTRUCTIONS DE BRANCHEMENT SIMPLES
  ============================================================
  La table des labels (lbl_table) et ses fonctions primitives
  (LabelFind, LabelEnter, LabelMarkDefined, LabelCheckAll) sont deja
  implementees.
  Ce partie ajoute la generation de code :

    GenNumLabel(anum)       -- emettre le label ASM FL_nnnnn:
    GenGotoSimple(anum)     -- JMP FL_nnnnn
    GenGotoComputed(...)    -- GOTO (n1,n2,...), i (table de sauts)
    GenAssignedGoto(idx)    -- GOTO var (saut assigne via pointeur)
    ParseGoto               -- parser GOTO simple, calcule, assigne
    ParseAssign             -- parser ASSIGN n TO var
    ParseContinue           -- instruction CONTINUE (label vide)
    ParseStop               -- STOP [n]
    ParsePause              -- PAUSE [n]

  Backpatching : a la fin de chaque unite de programme, appeler
  LabelCheckAll pour verifier que tous les labels references sont definis.
  ============================================================ }

{ --------------------------------------------------------------------------
  LabelGetAsm : retourner le nom ASM d'un label numerique Fortran.
  Cree l'entree si elle n'existe pas, marque referenced = True.
  -------------------------------------------------------------------------- }
Function LabelGetAsm(anum : Integer) : TString;
Var idx : Integer;
Begin
  idx := LabelEnter(anum);
  If idx > 0 Then
  Begin
    lbl_table^[idx].referenced := True;
    LabelGetAsm := lbl_table^[idx].asm_label;
  End
  Else
    LabelGetAsm := 'FL_' + IntToStr(anum);
End;

{ --------------------------------------------------------------------------
  GenNumLabel : emettre un label Fortran numerique (FL_nnnnn:).
  Marque le label comme defini dans lbl_table.
  -------------------------------------------------------------------------- }
{ --------------------------------------------------------------------------
  CloseDo : emettre le code de fermeture de la boucle DO au niveau 'depth'.
  Pile en entree : [SP]=step, [SP+2]=niter.
  1. Incrementer la variable de boucle de step.
  2. Decrementer niter ; si > 0, retourner en haut de boucle.
  3. Depiler step+niter ; emettre label de fin.
  -------------------------------------------------------------------------- }
Procedure CloseDo(depth : Integer);
Var vname : TString;
Begin
  vname := sym_table^[do_var_si[depth]].name;
  EmitComment('DO: fin iteration ' + vname);
  { Incrementer la variable de boucle par step }
  EmitI2('MOV', 'BX', 'WORD PTR [SP]');       { BX = step }
  GenLoadInt(do_var_si[depth]);                { AX = var }
  EmitI2('ADD', 'AX', 'BX');                  { AX = var + step }
  GenStoreInt(do_var_si[depth]);               { var = AX }
  { Decrementer le compteur d'iterations }
  EmitRaw('        DEC WORD PTR [SP+2]');      { niter-- }
  EmitI1('JNZ', do_top_lbl[depth]);           { niter > 0 : reboucler }
  EmitI2('ADD', 'SP', '4');                   { depiler niter + step }
  EmitLabel(do_end_lbl[depth]);               { label de fin de boucle }
  Dec(do_depth);
End;

Procedure GenNumLabel(anum : Integer);
Var di : Integer;
Begin
  { Verifier si ce label ferme un ou plusieurs DO imbrique(s) }
  While (do_depth > 0) And (do_lbl_num[do_depth] = anum) Do
    CloseDo(do_depth);
  LabelMarkDefined(anum, log_lineno);
  EmitLabel(LabelGetAsm(anum));
End;

{ --------------------------------------------------------------------------
  GenGotoSimple : emettre JMP FL_nnnnn.
  -------------------------------------------------------------------------- }
Procedure GenGotoSimple(anum : Integer);
Begin
  EmitComment('GOTO ' + IntToStr(anum));
  EmitI1('JMP', LabelGetAsm(anum));
End;

{ --------------------------------------------------------------------------
  GenGotoComputed : GOTO (n1, n2, ..., nk), i
  Algorithme :
    1. Charger i dans AX (1-based)
    2. DEC AX ; CMP AX, k ; JAE lbl_done (hors bornes : pas de saut)
    3. Multiplier l'index par 2 (chaque pointeur de table = 1 DW = 2 octets)
    4. En fait on utilise une table de DW d'adresses patchees
    5. MOV BX, AX ; SHL BX, 1 (×2 si on mettrrait des NEAR ptr)
       mais MASM ne permet pas de table JMP inline facilement.
    Strategie utilisee ici : serie de CMP AX, k / JE FL_nk.
    Avantage : ne requiert pas de segment special, fonctionne en SMALL.
  -------------------------------------------------------------------------- }
Procedure GenGotoComputed(Var nums : Array of Integer; count : Integer;
                          var_idx : Integer);
Var
  i      : Integer;
  lbl_done : TString;
Begin
  lbl_done := GenBranchLabel;
  EmitComment('GOTO calcule (' + IntToStr(count) + ' cibles)');

  { Charger l'indice dans AX }
  GenLoadInt(var_idx);

  { Pour chaque cible, CMP AX, i ; JE FL_ni }
  For i := 0 To count - 1 Do
  Begin
    EmitI2('CMP', 'AX', IntToStr(i + 1));
    EmitI1('JE', LabelGetAsm(nums[i]));
  End;
  { Cas hors bornes : tomber en avance }
  EmitLabel(lbl_done);
End;

{ --------------------------------------------------------------------------
  GenAssignedGoto : GOTO var  (saut assigne via ASSIGN prealable).
  La variable contient l'offset 16 bits du label ASM (stocke par ASSIGN).
  Technique : JMP [var]  (indirect via memoire).
  -------------------------------------------------------------------------- }
Procedure GenAssignedGoto(var_idx : Integer);
Var s : TSymRef;
Begin
  EmitComment('GOTO assigne (ASSIGN ... TO var)');
  If (var_idx < 1) Or (var_idx > sym_count) Then
  Begin
    WarnMsg('GenAssignedGoto : variable inconnue');
    Exit;
  End;
  s := sym_table^[var_idx];
  If s.bp_offset < 0 Then
    EmitRaw('        JMP WORD PTR [BP' + IntToStr(s.bp_offset) + ']')
  Else If s.asm_label <> '' Then
    EmitRaw('        JMP WORD PTR [' + s.asm_label + ']')
  Else
    WarnMsg('GenAssignedGoto : variable sans adresse ' + s.name);
End;

{ --------------------------------------------------------------------------
  ParseGoto : parser et generer un enonce GOTO.
  Formes F77 :
    GOTO n                       -- saut simple
    GOTO (n1, n2, ..., nk), i   -- saut calcule
    GOTO v                       -- saut assigne (v est une variable entiere)
    GOTO v, (n1, ..., nk)        -- saut assigne avec liste (variante)
  Le mot-cle GOTO est deja consomme avant l'appel.
  -------------------------------------------------------------------------- }
Procedure ParseGoto;
Var
  nums     : Array[0..255] of Integer;
  count    : Integer;
  anum     : Integer;
  var_idx  : Integer;
  vname    : TString;
Begin
  { Saut calcule : GOTO (n1, ...), i }
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
  Begin
    LexNext;
    count := 0;
    While (cur_tok.kind = TK_INTEGER) Or
          ((cur_tok.kind = TK_LABEL) And (count < 256)) Do
    Begin
      If cur_tok.kind = TK_INTEGER Then nums[count] := cur_tok.int_val
      Else nums[count] := cur_tok.lbl_num;
      Inc(count);
      LexNext;
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
    End;
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
    { virgule optionnelle }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
    { variable d'indice }
    If cur_tok.kind = TK_IDENT Then
    Begin
      var_idx := SymFind(cur_tok.val);
      If var_idx = 0 Then var_idx := SymGetOrCreate(cur_tok.val);
      LexNext;
    End
    Else
    Begin
      ErrorMsg('Variable d''index attendue dans GOTO calcule');
      var_idx := 0;
      If cur_tok.kind = TK_INTEGER Then
      Begin
        var_idx := 0;
        LexNext;
      End;
    End;
    GenGotoComputed(nums, count, var_idx);
    Exit;
  End;

  { Saut assigne : GOTO var ou GOTO var, (liste) }
  If cur_tok.kind = TK_IDENT Then
  Begin
    vname   := cur_tok.val;
    var_idx := SymFind(vname);
    If var_idx = 0 Then var_idx := SymGetOrCreate(vname);
    LexNext;
    { Eventuellement une liste optionnelle (ignoree dans la norme) }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
    Begin
      LexNext;  { consommer , }
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
      Begin
        LexNext;
        While Not ((cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')'))
          And (cur_tok.kind <> TK_NEWLINE)
          And (cur_tok.kind <> TK_EOF) Do
          LexNext;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
      End;
    End;
    GenAssignedGoto(var_idx);
    Exit;
  End;

  { Saut simple : GOTO n }
  If cur_tok.kind = TK_INTEGER Then
    anum := cur_tok.int_val
  Else If cur_tok.kind = TK_LABEL Then
    anum := cur_tok.lbl_num
  Else
  Begin
    ErrorMsg('Numero d''etiquette attendu apres GOTO, obtenu : ' + cur_tok.val);
    anum := 0;
  End;
  LexNext;
  If anum > 0 Then GenGotoSimple(anum);
End;

{ --------------------------------------------------------------------------
  ParseAssign : ASSIGN n TO var.
  Stocke l'offset du label FL_n dans la variable entiere var.
  ASSIGN n TO v == MOV WORD PTR [v], OFFSET FL_n
  -------------------------------------------------------------------------- }
Procedure ParseAssign;
Var
  anum    : Integer;
  var_idx : Integer;
  s       : TSymRef;
Begin
  { Lire le numero de label }
  If cur_tok.kind = TK_INTEGER Then
    anum := cur_tok.int_val
  Else If cur_tok.kind = TK_LABEL Then
    anum := cur_tok.lbl_num
  Else
  Begin
    ErrorMsg('Numero d''etiquette attendu dans ASSIGN');
    anum := 0;
  End;
  LexNext;

  { Consommer TO }
  If (cur_tok.kind = TK_IDENT) And (cur_tok.val = 'TO') Then
    LexNext
  Else
    ErrorMsg('Attendu TO dans ASSIGN n TO var');

  { Lire la variable }
  If cur_tok.kind <> TK_IDENT Then
  Begin
    ErrorMsg('Variable attendue dans ASSIGN ... TO var');
    Exit;
  End;
  var_idx := SymFind(cur_tok.val);
  If var_idx = 0 Then var_idx := SymGetOrCreate(cur_tok.val);
  LexNext;

  If (anum > 0) And (var_idx > 0) Then
  Begin
    EmitComment('ASSIGN ' + IntToStr(anum) + ' TO ' + sym_table^[var_idx].name);
    s := sym_table^[var_idx];
    If s.bp_offset < 0 Then
      EmitI2('MOV', 'WORD PTR [BP' + IntToStr(s.bp_offset) + ']',
             'OFFSET ' + LabelGetAsm(anum))
    Else If s.asm_label <> '' Then
      EmitI2('MOV', 'WORD PTR [' + s.asm_label + ']',
             'OFFSET ' + LabelGetAsm(anum))
    Else
      WarnMsg('ASSIGN : variable sans adresse ' + s.name);
  End;
End;

{ --------------------------------------------------------------------------
  ParseContinue : instruction vide.
  Le label eventuel a deja ete emis par le dispatcher principal.
  On ne gene aucune instruction.
  -------------------------------------------------------------------------- }
Procedure ParseContinue;
Begin
  EmitComment('CONTINUE');
  { Aucune instruction : juste un point d'ancrage pour l'etiquette }
  EmitI0('NOP');
End;

{ --------------------------------------------------------------------------
  ParseStop : STOP [chaine | entier].
  STOP         -> CALL _FRT_STOP_0
  STOP n       -> MOV AX, n ; PUSH AX ; CALL _FRT_STOP_N ; ADD SP, 2
  STOP 'msg'   -> afficher msg puis exit
  -------------------------------------------------------------------------- }
Procedure ParseStop;
Var n : Integer;
Begin
  If (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF) Then
  Begin
    EmitComment('STOP');
    EmitRaw('        CALL ' + FRT_PFX + 'STOP_0');
    Exit;
  End;

  If cur_tok.kind = TK_INTEGER Then
  Begin
    n := cur_tok.int_val;
    LexNext;
    EmitComment('STOP ' + IntToStr(n));
    EmitI2('MOV', 'AX', IntToStr(n));
    EmitI1('PUSH', 'AX');
    EmitRaw('        CALL ' + FRT_PFX + 'STOP_N');
    EmitI2('ADD', 'SP', '2');
    Exit;
  End;

  If cur_tok.kind = TK_STRING Then
  Begin
    EmitComment('STOP ''' + cur_tok.val + '''');
    GenStrLiteral(cur_tok.val);   { AX=addr, CX=len }
    EmitI1('PUSH', 'CX');
    EmitI1('PUSH', 'AX');
    EmitRaw('        CALL ' + FRT_PFX + 'STOP_S');
    EmitI2('ADD', 'SP', '4');
    LexNext;
    Exit;
  End;

  { Ignorer les autres formes }
  EmitRaw('        CALL ' + FRT_PFX + 'STOP_0');
  LexNext;
End;

{ --------------------------------------------------------------------------
  ParsePause : PAUSE [chaine | entier].
  Affiche un message et attend une touche (DOS INT 21h 08h).
  -------------------------------------------------------------------------- }
Procedure ParsePause;
Var n : Integer;
Begin
  If (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF) Then
  Begin
    EmitComment('PAUSE');
    EmitRaw('        CALL ' + FRT_PFX + 'PAUSE');
    Exit;
  End;

  If cur_tok.kind = TK_INTEGER Then
  Begin
    n := cur_tok.int_val;
    LexNext;
    EmitComment('PAUSE ' + IntToStr(n));
    EmitI2('MOV', 'AX', IntToStr(n));
    EmitI1('PUSH', 'AX');
    EmitRaw('        CALL ' + FRT_PFX + 'PAUSE_N');
    EmitI2('ADD', 'SP', '2');
    Exit;
  End;

  If cur_tok.kind = TK_STRING Then
  Begin
    EmitComment('PAUSE ''' + cur_tok.val + '''');
    GenStrLiteral(cur_tok.val);
    EmitI1('PUSH', 'CX');
    EmitI1('PUSH', 'AX');
    EmitRaw('        CALL ' + FRT_PFX + 'PAUSE_S');
    EmitI2('ADD', 'SP', '4');
    LexNext;
    Exit;
  End;

  EmitRaw('        CALL ' + FRT_PFX + 'PAUSE');
  LexNext;
End;

{ ============================================================
  BOUCLE DO
  ============================================================
  Syntaxe F77 :
    DO label var = debut, fin [, pas]
      corps
  label [CONTINUE ou autre instruction]

  Convention pile durant le corps de la boucle :
    [SP]    = pas  (word signe)
    [SP+2]  = niter (word signe, decremente a chaque iteration)
  niter = MAX( INT((fin - debut + pas) / pas), 0 )
  Si niter <= 0 : sauter directement a lbl_end (boucle vide).
  ============================================================ }

Procedure ParseDo;
Var
  lbl_num  : Integer;    { etiquette F77 de fin de boucle    }
  lbl_top  : TString;   { label ASM en haut de boucle       }
  lbl_end  : TString;   { label ASM de fin de boucle        }
  var_idx  : Integer;   { index sym de la variable de ctrl  }
  var_name : TString;
Begin
  { Verifier la profondeur d'imbrication }
  If do_depth >= MAX_SCOPE Then
  Begin
    ErrorMsg('DO trop profondement imbrique (max ' + IntToStr(MAX_SCOPE) + ')');
    Exit;
  End;

  { Lire l'etiquette numerique F77 }
  If cur_tok.kind <> TK_INTEGER Then
  Begin
    ErrorMsg('DO : etiquette numerique attendue');
    Exit;
  End;
  lbl_num := cur_tok.int_val;
  LexNext;

  { Virgule optionnelle entre etiquette et variable (extension commune) }
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;

  { Lire la variable de controle }
  If cur_tok.kind <> TK_IDENT Then
  Begin
    ErrorMsg('DO : identifiant attendu pour la variable de controle');
    Exit;
  End;
  var_name := cur_tok.val;
  LexNext;
  var_idx := SymGetOrCreate(var_name);
  If sym_table^[var_idx].dtype = DT_NONE Then
    sym_table^[var_idx].dtype := DT_INTEGER;

  LexExpect('=');

  { Evaluer la valeur initiale et initialiser la variable }
  EmitComment('DO: init variable ' + var_name);
  ParseIntExpr;              { AX = debut }
  GenStoreInt(var_idx);      { var = debut }

  LexExpect(',');

  { Evaluer la borne superieure et la pousser temporairement }
  ParseIntExpr;              { AX = fin }
  EmitI1('PUSH', 'AX');     { [SP] = fin }

  { Evaluer le pas (ou 1 par defaut) }
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
  Begin
    LexNext;
    ParseIntExpr;            { AX = pas }
  End
  Else
    EmitI2('MOV', 'AX', '1');
  EmitI1('PUSH', 'AX');     { [SP]=pas, [SP+2]=fin }

  { Calcul de niter = MAX(INT((fin-debut+pas)/pas), 0) }
  EmitComment('DO: calcul niter = (fin-debut+pas)/pas');
  EmitI2('MOV', 'BX', 'WORD PTR [SP]');    { BX = pas }
  GenLoadInt(var_idx);                      { AX = var (= debut) }
  EmitI2('MOV', 'CX', 'AX');               { CX = debut }
  EmitI2('MOV', 'AX', 'WORD PTR [SP+2]'); { AX = fin }
  EmitI2('SUB', 'AX', 'CX');               { AX = fin - debut }
  EmitI2('ADD', 'AX', 'BX');               { AX = fin - debut + pas }
  EmitRaw('        CWD');
  EmitI1('IDIV', 'BX');                    { AX = niter }

  { Preparer les labels }
  lbl_end := GenBranchLabel;
  lbl_top := GenBranchLabel;

  { Si niter <= 0 : boucle vide, sauter a la fin }
  EmitI2('CMP', 'AX', '0');
  EmitI1('JLE', lbl_end);

  { Remplacer fin sur la pile par niter : [SP+2]=niter, [SP]=pas }
  EmitI2('MOV', 'WORD PTR [SP+2]', 'AX'); { niter }

  { Enregistrer le contexte dans la pile DO }
  Inc(do_depth);
  do_top_lbl[do_depth] := lbl_top;
  do_end_lbl[do_depth] := lbl_end;
  do_var_si[do_depth]  := var_idx;
  do_lbl_num[do_depth] := lbl_num;

  { Marquer l'etiquette comme DO_END dans la table des labels }
  LabelGetAsm(lbl_num);   { s'assurer qu'elle est enregistree }

  { Emettre le label en haut de boucle }
  EmitLabel(lbl_top);
End;

{ ============================================================
  INSTRUCTION IF ARITHMETIQUE ET IF LOGIQUE
  ============================================================
  Trois formes F77 :
    IF arithmetique  : IF (expr_arith) n1, n2, n3
    IF logique       : IF (expr_log) instruction_simple
    IF bloc          : IF (expr_log) THEN
                         ...
                       [ELSEIF (expr_log) THEN
                         ...]...
                       [ELSE
                         ...]
                       ENDIF

  Convention :
    .TRUE./-1/non-zero -> branche prise
    .FALSE./0 -> branche non prise
  Pile de blocs IF :
    if_depth                -- niveau d'imbrication courant (1..MAX_SCOPE)
    if_else_lbl[1..depth]  -- label du ELSE courant
    if_end_lbl [1..depth]  -- label du ENDIF courant
  ============================================================ }

{ Forward pour ParseStatement (implementee) }
Procedure ParseStatement; Forward;

{ Forward pour ParseFmtIoList (implementee) }
Procedure ParseFmtIoList(is_write : Boolean; unit_num : Integer;
                          fmt_anum : Integer; Const fmt_str : TString); Forward;

{ Forward pour ParseFormatStmt (implementee) }
Procedure ParseFormatStmt(fmt_lbl : Integer); Forward;

{ Forwards pour les E/S fichiers (implementees) }
Procedure ParseOpen; Forward;
Procedure ParseClose; Forward;
Procedure ParseSimpleIo(Const frt_suffix : TString); Forward;
Procedure ParseInquire; Forward;

{ Forwards pour SUBROUTINE/CALL/END (implementees) }
Procedure ParseSubroutineDecl; Forward;
Procedure ParseCallStmt; Forward;
Procedure ParseEnd; Forward;

{ Forward pour FUNCTION (implementee) }
Procedure ParseFunctionDecl(ret_dtype : TDataType); Forward;

{ Forward pour BLOCK DATA (implementee) }
Procedure ParseBlockData; Forward;

{ Forward pour PROGRAM (implementee) }
Procedure ParseProgramDecl; Forward;

{ --------------------------------------------------------------------------
  ParseIfArith : IF (expr) n1, n2, n3
  Le mot-cle IF et la ( sont deja consommes.
  expr est evaluee, resultat dans AX.
  CMP AX, 0 : JL -> n1, JE -> n2, JG -> n3.
  -------------------------------------------------------------------------- }
Procedure ParseIfArith(n1, n2, n3 : Integer);
Begin
  EmitComment('IF arithmetique -> n1=' + IntToStr(n1)
              + ' n2=' + IntToStr(n2) + ' n3=' + IntToStr(n3));
  EmitI2('CMP', 'AX', '0');
  EmitI1('JL',  LabelGetAsm(n1));
  EmitI1('JE',  LabelGetAsm(n2));
  EmitI1('JG',  LabelGetAsm(n3)); { ou JMP n3 -> meme chose si AX>0 }
End;

{ --------------------------------------------------------------------------
  ParseIfLogic : IF (cond) instruction_simple
  cond dans AX. Test: CMP AX, 0 ; JE lbl_skip ; instruction ; lbl_skip:.
  -------------------------------------------------------------------------- }
Procedure ParseIfLogic;
Var lbl_skip : TString;
Begin
  lbl_skip := GenBranchLabel;
  EmitComment('IF logique');
  EmitI2('CMP', 'AX', '0');
  EmitI1('JE', lbl_skip);
  { Instruction inline (une seule) }
  ParseStatement;
  EmitLabel(lbl_skip);
End;

{ --------------------------------------------------------------------------
  ParseIfBlock : traiter le corps d'un IF bloc depuis THEN jusqu'a ENDIF.
  La condition est deja evaluee et testee (JE lbl_else).
  Strategy : on parse les statements du corps jusqu'a trouver ELSE,
  ELSEIF ou ENDIF en debut de ligne logique.
  -------------------------------------------------------------------------- }
Procedure ParseIfBlock;
Var
  lbl_else : TString;
  lbl_end  : TString;
  kw       : TString;
Begin
  If if_depth >= MAX_SCOPE Then
  Begin
    ErrorMsg('IF trop profondement imbrique (max ' + IntToStr(MAX_SCOPE) + ')');
    Exit;
  End;

  lbl_else := GenBranchLabel;   { label du ELSE ou ENDIF si pas de ELSE }
  lbl_end  := GenBranchLabel;   { label du ENDIF }

  Inc(if_depth);
  if_else_lbl[if_depth] := lbl_else;
  if_end_lbl[if_depth]  := lbl_end;

  { Sauter vers ELSE si la condition est fausse (le JE a ete emis par ParseIf) }
  { Le JE est sur lbl_else }

  { Parser les statements du corps THEN...ELSE/ELSEIF/ENDIF }
  While (cur_tok.kind <> TK_EOF) Do
  Begin
    { Avancer jusqu'au prochain token significatif en debut de ligne }
    While (cur_tok.kind = TK_NEWLINE) Do LexNext;
    If cur_tok.kind = TK_EOF Then Break;

    kw := cur_tok.val;

    If kw = 'ELSEIF' Then
    Begin
      { Fermer le bloc precedent }
      EmitI1('JMP', lbl_end);
      EmitLabel(lbl_else);
      { Nouveau label else }
      lbl_else := GenBranchLabel;
      if_else_lbl[if_depth] := lbl_else;

      LexNext;  { consommer ELSEIF }
      LexExpect('(');
      ParseLogExpr;      { condition dans AX }
      LexExpect(')');
      { Consommer THEN }
      If cur_tok.val = 'THEN' Then LexNext;
      EmitI2('CMP', 'AX', '0');
      EmitI1('JE', lbl_else);
      Continue;
    End;

    If kw = 'ELSE' Then
    Begin
      EmitI1('JMP', lbl_end);
      EmitLabel(lbl_else);
      lbl_else := lbl_end;  { il n'y a pas de ELSE apres le ELSE }
      if_else_lbl[if_depth] := lbl_end;
      LexNext;  { consommer ELSE }
      Continue;
    End;

    If kw = 'ENDIF' Then
    Begin
      EmitLabel(lbl_else);  { au cas ou pas de ELSE }
      EmitLabel(lbl_end);
      Dec(if_depth);
      LexNext;  { consommer ENDIF }
      Break;
    End;

    { Statement ordinaire du corps du IF }
    ParseStatement;
  End;
End;

{ --------------------------------------------------------------------------
  ParseIf : dispatcher principal pour l'enonce IF.
  Le mot-cle IF est deja consomme.
  Syntaxe commune : IF ( expr ) ...
  Apres la ), la suite determine la forme :
    - entier, entier, entier         -> IF arithmetique
    - THEN (fin de ligne)            -> IF bloc
    - autre                          -> IF logique (instruction inline)
  -------------------------------------------------------------------------- }
Procedure ParseIf;
Var
  lbl_else : TString;
  n1, n2, n3 : Integer;
Begin
  LexExpect('(');
  { Tenter d'abord une expression logique/arithmetique }
  ParseLogExpr;   { resultat dans AX - gere entier ET logique }
  LexExpect(')');

  { Regarder la suite }
  If cur_tok.kind = TK_INTEGER Then
  Begin
    { IF arithmetique : 3 labels }
    n1 := cur_tok.int_val; LexNext;
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
    n2 := cur_tok.int_val; LexNext;
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
    n3 := cur_tok.int_val; LexNext;
    ParseIfArith(n1, n2, n3);
    Exit;
  End;

  If cur_tok.val = 'THEN' Then
  Begin
    { IF bloc : condition dans AX, evaluer vers lbl_else }
    lbl_else := '';
    LexNext;  { consommer THEN }
    { Consommer la fin de ligne }
    While cur_tok.kind = TK_NEWLINE Do LexNext;
    { Emettre le saut conditionnel vers le ELSE/ENDIF }
    lbl_else := GenBranchLabel;
    if_depth := if_depth;  { sera incremente dans ParseIfBlock }
    EmitI2('CMP', 'AX', '0');
    EmitI1('JE', lbl_else);
    { Pousser les labels dans la pile avant d'appeler ParseIfBlock }
    If if_depth < MAX_SCOPE Then
    Begin
      Inc(if_depth);
      if_else_lbl[if_depth] := lbl_else;
      if_end_lbl[if_depth]  := GenBranchLabel;
    End;

    { Parser le corps du IF bloc en boucle }
    While (cur_tok.kind <> TK_EOF) Do
    Begin
      While cur_tok.kind = TK_NEWLINE Do LexNext;
      If cur_tok.kind = TK_EOF Then Break;

      If cur_tok.val = 'ELSE' Then
      Begin
        EmitI1('JMP', if_end_lbl[if_depth]);
        EmitLabel(if_else_lbl[if_depth]);
        LexNext;  { consommer ELSE }
        { ELSE IF ou ELSE tout court ? }
        If cur_tok.val = 'IF' Then
        Begin
          LexNext;  { consommer IF }
          LexExpect('(');
          ParseLogExpr;
          LexExpect(')');
          If cur_tok.val = 'THEN' Then LexNext;
          { Nouveau label else }
          if_else_lbl[if_depth] := GenBranchLabel;
          EmitI2('CMP', 'AX', '0');
          EmitI1('JE', if_else_lbl[if_depth]);
          Continue;
        End;
        { ELSE seul : nothing to do, fall through }
        Continue;
      End;

      If (cur_tok.val = 'ELSEIF') Then
      Begin
        EmitI1('JMP', if_end_lbl[if_depth]);
        EmitLabel(if_else_lbl[if_depth]);
        LexNext;  { consommer ELSEIF }
        LexExpect('(');
        ParseLogExpr;
        LexExpect(')');
        If cur_tok.val = 'THEN' Then LexNext;
        if_else_lbl[if_depth] := GenBranchLabel;
        EmitI2('CMP', 'AX', '0');
        EmitI1('JE', if_else_lbl[if_depth]);
        Continue;
      End;

      If (cur_tok.val = 'ENDIF') Then
      Begin
        EmitLabel(if_else_lbl[if_depth]);  { label ELSE non utilise si pas de ELSE }
        EmitLabel(if_end_lbl[if_depth]);
        Dec(if_depth);
        LexNext;  { consommer ENDIF }
        Break;
      End;

      ParseStatement;
    End;
    Exit;
  End;

  { IF logique : instruction inline }
  ParseIfLogic;
End;

{ ============================================================
  AFFECTATION ET E/S SIMPLES
  ============================================================
  Affectation scalaire et tableaux (calcul d'adresse colonne-major F77).
  PRINT *, liste  ->  _FRT_PRINT_I / _FRT_PRINT_R / _FRT_PRINT_L /
                      _FRT_PRINT_S / _FRT_PRINT_NL
  READ  *, liste  ->  _FRT_READ_I  / _FRT_READ_R
  WRITE(6,*) liste  : equivalent PRINT *
  READ (5,*) liste  : equivalent READ *
  ============================================================ }

{ --------------------------------------------------------------------------
  PeekExprType : heuristique de type a partir du token courant.
  -------------------------------------------------------------------------- }
Function PeekExprType : TDataType;
Var si : Integer;
Begin
  PeekExprType := DT_INTEGER;
  Case cur_tok.kind Of
    TK_REAL    : PeekExprType := DT_REAL;
    TK_STRING  : PeekExprType := DT_CHARACTER;
    TK_LOGICAL : PeekExprType := DT_LOGICAL;
    TK_IDENT :
    Begin
      si := SymFind(cur_tok.val);
      If si > 0 Then PeekExprType := sym_table^[si].dtype;
    End;
  End;
End;

{ --------------------------------------------------------------------------
  GenPrintItem : evaluer une expression et emettre l appel _FRT_PRINT_x.
  -------------------------------------------------------------------------- }
Procedure GenPrintItem;
Var dt : TDataType;
Begin
  dt := PeekExprType;
  Case dt Of
    DT_REAL, DT_DOUBLE :
    Begin
      ParseRealExpr;
      EmitI1('PUSH', 'DX');
      EmitI1('PUSH', 'AX');
      EmitRaw('        CALL ' + FRT_PFX + 'PRINT_R');
      EmitI2('ADD', 'SP', '4');
    End;
    DT_LOGICAL :
    Begin
      ParseLogExpr;
      EmitI1('PUSH', 'AX');
      EmitRaw('        CALL ' + FRT_PFX + 'PRINT_L');
      EmitI2('ADD', 'SP', '2');
    End;
    DT_CHARACTER :
    Begin
      ParseCharExpr;            { AX=ptr, CX=len }
      EmitI1('PUSH', 'CX');
      EmitI1('PUSH', 'AX');
      EmitRaw('        CALL ' + FRT_PFX + 'PRINT_S');
      EmitI2('ADD', 'SP', '4');
    End;
    Else
    Begin
      ParseIntExpr;
      EmitI1('PUSH', 'AX');
      EmitRaw('        CALL ' + FRT_PFX + 'PRINT_I');
      EmitI2('ADD', 'SP', '2');
    End;
  End;
End;

{ --------------------------------------------------------------------------
  ParsePrintStar : emettre la liste d une instruction PRINT * / WRITE(6,*).
  Appelant : a deja consomme le format (* ou num) et la virgule.
  -------------------------------------------------------------------------- }
Procedure ParsePrintStar;
Begin
  EmitComment('PRINT *');
  If (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Then
  Begin
    GenPrintItem;
    While (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Do
    Begin
      LexNext;
      If (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF) Then Break;
      GenPrintItem;
    End;
  End;
  EmitRaw('        CALL ' + FRT_PFX + 'PRINT_NL');
End;

{ --------------------------------------------------------------------------
  ParseReadItem : lire une valeur dans une variable scalaire depuis stdin.
  -------------------------------------------------------------------------- }
Procedure ParseReadItem;
Var si : Integer;
    nm : TString;
    s  : TSymRef;
Begin
  If cur_tok.kind <> TK_IDENT Then
  Begin
    WarnMsg('READ * : identifiant attendu, ' + cur_tok.val + ' trouve');
    LexNext;
    Exit;
  End;
  nm := cur_tok.val;
  LexNext;
  si := SymGetOrCreate(nm);
  If sym_table^[si].dtype = DT_NONE Then
    sym_table^[si].dtype := DT_INTEGER;
  s := sym_table^[si];
  { Pousser l adresse de la variable }
  If s.bp_offset < 0 Then
    EmitRaw('        LEA AX, [BP' + IntToStr(s.bp_offset) + ']')
  Else If s.asm_label <> '' Then
    EmitI2('MOV', 'AX', 'OFFSET ' + s.asm_label)
  Else
  Begin
    WarnMsg('READ * : variable sans adresse - ' + nm);
    Exit;
  End;
  EmitI1('PUSH', 'AX');
  Case s.dtype Of
    DT_REAL, DT_DOUBLE :
    Begin
      EmitRaw('        CALL ' + FRT_PFX + 'READ_R');
      EmitI2('ADD', 'SP', '2');
    End;
    Else
    Begin
      EmitRaw('        CALL ' + FRT_PFX + 'READ_I');
      EmitI2('ADD', 'SP', '2');
    End;
  End;
End;

{ --------------------------------------------------------------------------
  ParseReadStar : traiter la liste d une READ * / READ(5,*).
  Appelant : a deja consomme le format et la virgule.
  -------------------------------------------------------------------------- }
Procedure ParseReadStar;
Begin
  EmitComment('READ *');
  If (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Then
  Begin
    ParseReadItem;
    While (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Do
    Begin
      LexNext;
      If (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF) Then Break;
      ParseReadItem;
    End;
  End;
End;

{ --------------------------------------------------------------------------
  ParseAssignStmt : var [(indices)] = expr
  cur_tok doit etre sur l identificateur de la lvalue.
  -------------------------------------------------------------------------- }
Procedure ParseAssignStmt;
Var
  nm     : TString;
  si     : Integer;
  s      : TSymRef;
  lhs_dt : TDataType;
  rhs_dt : TDataType;
  is_arr : Boolean;
  stride : Integer;
  di     : Integer;
Begin
  nm := cur_tok.val;
  LexNext;       { consommer le nom }

  si := SymGetOrCreate(nm);
  If sym_table^[si].dtype = DT_NONE Then
    sym_table^[si].dtype := DT_INTEGER;
  s      := sym_table^[si];
  lhs_dt := s.dtype;
  is_arr := False;

  { Tableau : parser les indices, calculer l offset colonne-major dans BX }
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
  Begin
    is_arr := True;
    LexNext;        { consommer ( }
    EmitComment('Adresse tableau ' + nm);
    EmitI2('MOV', 'BX', '0');
    stride := 1;
    For di := 1 To s.ndim Do
    Begin
      ParseIntExpr;                                          { AX = indice }
      EmitI2('SUB', 'AX', IntToStr(s.dims[di].lb));         { AX -= lb    }
      If stride > 1 Then
      Begin
        EmitI2('MOV', 'CX', IntToStr(stride));
        EmitRaw('        IMUL CX');
      End;
      EmitI2('ADD', 'BX', 'AX');
      stride := stride * (s.dims[di].ub - s.dims[di].lb + 1);
      If di < s.ndim Then
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
    End;
    { BX = index element. Multiplier par type_size. }
    If s.type_size = 2 Then
      EmitI2('SHL', 'BX', '1')
    Else If s.type_size = 4 Then
    Begin
      EmitI2('SHL', 'BX', '1');
      EmitI2('SHL', 'BX', '1');
    End
    Else If s.type_size > 2 Then
    Begin
      EmitI2('MOV', 'CX', IntToStr(s.type_size));
      EmitRaw('        XCHG AX, BX');
      EmitRaw('        IMUL CX');
      EmitRaw('        XCHG AX, BX');
    End;
    LexExpect(')');
    EmitI1('PUSH', 'BX');   { sauvegarder l offset en octets }
  End;

  LexExpect('=');

  { Evaluer le RHS avec conversion de type si necessaire }
  rhs_dt := PeekExprType;
  Case lhs_dt Of
    DT_REAL, DT_DOUBLE :
    Begin
      If rhs_dt In [DT_REAL, DT_DOUBLE] Then
        ParseRealExpr           { DX:AX }
      Else
      Begin
        ParseIntExpr;           { AX }
        GenIntToReal;           { DX:AX }
      End;
    End;
    DT_LOGICAL : ParseLogExpr;  { AX }
    DT_CHARACTER :
    Begin
      If Not is_arr Then
      Begin
        ParseCharExpr;          { AX=ptr, CX=len }
        GenStrAssign(si);
      End
      Else
        WarnMsg('Affectation tableau CHARACTER non supportee');
      Exit;
    End;
    Else { DT_INTEGER }
    Begin
      If rhs_dt In [DT_REAL, DT_DOUBLE] Then
      Begin
        ParseRealExpr;          { DX:AX }
        GenRealToInt;           { AX }
      End
      Else
        ParseIntExpr;           { AX }
    End;
  End;

  { Stocker le resultat }
  If is_arr Then
  Begin
    EmitI1('POP', 'BX');    { BX = offset en octets }
    If s.asm_label <> '' Then
    Begin
      Case lhs_dt Of
        DT_REAL, DT_DOUBLE :
        Begin
          EmitI2('MOV', 'WORD PTR [' + s.asm_label + '+BX]', 'AX');
          EmitI2('ADD', 'BX', '2');
          EmitI2('MOV', 'WORD PTR [' + s.asm_label + '+BX]', 'DX');
        End;
        Else
          EmitI2('MOV', 'WORD PTR [' + s.asm_label + '+BX]', 'AX');
      End;
    End
    Else
      WarnMsg('Tableau argument formel : affectation indirecte non supportee');
  End
  Else
  Begin
    Case lhs_dt Of
      DT_REAL, DT_DOUBLE : GenStoreReal(si);
      Else                  GenStoreInt(si);
    End;
  End;
End;

{ ============================================================
  ParseStatement - implementation complete (remplace le stub)
  Dispatcher principal de tous les enonces F77.
  ============================================================ }
Procedure ParseStatement;
Var
  anum    : Integer;
  kw      : TString;
  is_star : Boolean;
  tmp_int : Integer;
  tmp_i   : Integer;
  fstr    : TString;
  rfstr   : TString;
  wfstr   : TString;
  rfmt    : Integer;
  wfmt    : Integer;
Begin
  { Ignorer les lignes vides }
  While cur_tok.kind = TK_NEWLINE Do LexNext;
  If cur_tok.kind = TK_EOF Then Exit;

  { Etiquette numerique en debut d enonce (ex : 10 CONTINUE) }
  last_stmt_lbl := 0;
  If cur_tok.kind = TK_INTEGER Then
  Begin
    anum := cur_tok.int_val;
    last_stmt_lbl := anum;
    LexNext;
    GenNumLabel(anum);
    While cur_tok.kind = TK_NEWLINE Do LexNext;
    If (cur_tok.kind = TK_EOF) Or (cur_tok.kind = TK_NEWLINE) Then Exit;
  End;

  kw := cur_tok.val;

  { ---- F77 fixed-format : le lexer colle kw+identifiant en un seul token. ----
    ---- KwSplitAt separe le prefixe mot-cle du nom colle (ne consomme pas). ---- }
  pre_ident := '';
  If Not LexIsKeyword(kw) Then
  Begin
    { Tester du plus long au plus court pour eviter les fausses correspondances }
    If      KwSplitAt(kw, 'DOUBLEPRECISION', pre_ident) Then kw := 'DOUBLEPRECISION'
    Else If KwSplitAt(kw, 'INTEGERFUNCTION', pre_ident) Then
      Begin kw := 'INTEGER'; pre_ident := 'FUNCTION' + pre_ident; End
    Else If KwSplitAt(kw, 'REALFUNCTION', pre_ident) Then
      Begin kw := 'REAL';    pre_ident := 'FUNCTION' + pre_ident; End
    Else If KwSplitAt(kw, 'LOGICALFUNCTION', pre_ident) Then
      Begin kw := 'LOGICAL'; pre_ident := 'FUNCTION' + pre_ident; End
    Else If KwSplitAt(kw, 'CHARACTERFUNCTION', pre_ident) Then
      Begin kw := 'CHARACTER'; pre_ident := 'FUNCTION' + pre_ident; End
    Else If KwSplitAt(kw, 'COMPLEXFUNCTION', pre_ident) Then
      Begin kw := 'COMPLEX'; pre_ident := 'FUNCTION' + pre_ident; End
    Else If KwSplitAt(kw, 'INTEGER', pre_ident)    And (pre_ident <> '') Then kw := 'INTEGER'
    Else If KwSplitAt(kw, 'REAL', pre_ident)       And (pre_ident <> '') Then kw := 'REAL'
    Else If KwSplitAt(kw, 'LOGICAL', pre_ident)    And (pre_ident <> '') Then kw := 'LOGICAL'
    Else If KwSplitAt(kw, 'CHARACTER', pre_ident)  And (pre_ident <> '') Then kw := 'CHARACTER'
    Else If KwSplitAt(kw, 'SUBROUTINE', pre_ident) Then kw := 'SUBROUTINE'
    Else If KwSplitAt(kw, 'BLOCKDATA', pre_ident)  Then kw := 'BLOCKDATA'
    Else If KwSplitAt(kw, 'FUNCTION', pre_ident)   And (pre_ident <> '') Then kw := 'FUNCTION'
    Else If KwSplitAt(kw, 'CALL', pre_ident)       And (pre_ident <> '') Then kw := 'CALL'
    Else If KwSplitAt(kw, 'PROGRAM', pre_ident)    And (pre_ident <> '') Then kw := 'PROGRAM'
    Else pre_ident := '';
  End;

  { ---- Mots-cles deja implementes ---- }
  If kw = 'IF'       Then Begin LexNext; ParseIf;       Exit; End;
  If kw = 'GOTO'     Then Begin LexNext; ParseGoto;     Exit; End;
  If kw = 'ASSIGN'   Then Begin LexNext; ParseAssign;   Exit; End;
  If kw = 'CONTINUE' Then Begin LexNext; ParseContinue; Exit; End;
  If kw = 'STOP'     Then Begin LexNext; ParseStop;     Exit; End;
  If kw = 'PAUSE'    Then Begin LexNext; ParsePause;    Exit; End;
  If kw = 'DO'       Then Begin LexNext; ParseDo;       Exit; End;

  { ---- RETURN ---- }
  If kw = 'RETURN' Then
  Begin
    LexNext;
    EmitComment('RETURN');
    { Si on est dans une FUNCTION : charger la valeur de retour }
    If cur_func_result_si > 0 Then
    Begin
      If cur_func_ret_type = DT_REAL Then
        GenLoadReal(cur_func_result_si)
      Else
        GenLoadInt(cur_func_result_si);
    End;
    If cur_ret_lbl <> '' Then
      EmitI1('JMP', cur_ret_lbl)
    Else
      EmitRaw('        RET');
    Exit;
  End;

  { ---- PRINT * ou PRINT fmt, liste ---- }
  If kw = 'PRINT' Then
  Begin
    LexNext;
    is_star := False;
    tmp_int := 0;
    If (cur_tok.kind = TK_OP) And (cur_tok.val = '*') Then
    Begin
      is_star := True; LexNext;
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
      ParsePrintStar;
    End
    Else If cur_tok.kind = TK_INTEGER Then
    Begin
      tmp_int := cur_tok.int_val; LexNext;
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
      ParseFmtIoList(True, 6, tmp_int, '');
    End
    Else If cur_tok.kind = TK_STRING Then
    Begin
      is_star := False;
      fstr := cur_tok.val; LexNext;
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
      ParseFmtIoList(True, 6, 0, fstr);
    End
    Else
    Begin
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
      ParsePrintStar;
    End;
    Exit;
  End;

  { ---- READ *, liste ou READ(unit, fmt) liste ---- }
  If kw = 'READ' Then
  Begin
    LexNext;
    is_star := False;
    tmp_int := 0;
    If (cur_tok.kind = TK_OP) And (cur_tok.val = '*') Then
    Begin
      is_star := True; LexNext;
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
      ParseReadStar;
    End
    Else If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
    Begin
      LexNext;  { ( }
      { lire le numero d'unite }
      If cur_tok.kind = TK_INTEGER Then Begin tmp_int := cur_tok.int_val; LexNext; End
      Else If (cur_tok.kind = TK_OP) And (cur_tok.val = '*') Then
        Begin tmp_int := 5; LexNext; End
      Else
        Begin tmp_int := 5; LexNext; End;
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
      { lire le format }
      If (cur_tok.kind = TK_OP) And (cur_tok.val = '*') Then
      Begin
        is_star := True; LexNext;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
        ParseReadStar;
      End
      Else If cur_tok.kind = TK_INTEGER Then
      Begin
        rfmt := cur_tok.int_val; LexNext;
        While (cur_tok.val <> ')') And (cur_tok.kind <> TK_EOF) Do LexNext;
        If cur_tok.val = ')' Then LexNext;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
        ParseFmtIoList(False, tmp_int, rfmt, '');
      End
      Else If cur_tok.kind = TK_STRING Then
      Begin
        rfstr := cur_tok.val; LexNext;
        While (cur_tok.val <> ')') And (cur_tok.kind <> TK_EOF) Do LexNext;
        If cur_tok.val = ')' Then LexNext;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
        ParseFmtIoList(False, tmp_int, 0, rfstr);
      End
      Else
      Begin
        While (cur_tok.val <> ')') And (cur_tok.kind <> TK_EOF) Do LexNext;
        If cur_tok.val = ')' Then LexNext;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
        ParseReadStar;
      End;
    End
    Else
    Begin
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
      ParseReadStar;
    End;
    Exit;
  End;

  { ---- WRITE(unit, fmt) liste ---- }
  If kw = 'WRITE' Then
  Begin
    LexNext;
    is_star := False;
    tmp_int := 6;
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
    Begin
      LexNext;  { ( }
      If cur_tok.kind = TK_INTEGER Then Begin tmp_int := cur_tok.int_val; LexNext; End
      Else If (cur_tok.kind = TK_OP) And (cur_tok.val = '*') Then
        Begin tmp_int := 6; LexNext; End
      Else
        LexNext;
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
      If (cur_tok.kind = TK_OP) And (cur_tok.val = '*') Then
      Begin
        is_star := True; LexNext;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
        ParsePrintStar;
      End
      Else If cur_tok.kind = TK_INTEGER Then
      Begin
        wfmt := cur_tok.int_val; LexNext;
        While (cur_tok.val <> ')') And (cur_tok.kind <> TK_EOF) Do LexNext;
        If cur_tok.val = ')' Then LexNext;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
        ParseFmtIoList(True, tmp_int, wfmt, '');
      End
      Else If cur_tok.kind = TK_STRING Then
      Begin
        wfstr := cur_tok.val; LexNext;
        While (cur_tok.val <> ')') And (cur_tok.kind <> TK_EOF) Do LexNext;
        If cur_tok.val = ')' Then LexNext;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
        ParseFmtIoList(True, tmp_int, 0, wfstr);
      End
      Else
      Begin
        While (cur_tok.val <> ')') And (cur_tok.kind <> TK_EOF) Do LexNext;
        If cur_tok.val = ')' Then LexNext;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
        ParsePrintStar;
      End;
    End
    Else
    Begin
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
      ParsePrintStar;
    End;
    Exit;
  End;

  { ---- OPEN / CLOSE / REWIND / BACKSPACE / ENDFILE / INQUIRE ---- }
  If kw = 'OPEN'      Then Begin LexNext; ParseOpen;               Exit; End;
  If kw = 'CLOSE'     Then Begin LexNext; ParseClose;              Exit; End;
  If kw = 'REWIND'    Then Begin LexNext; ParseSimpleIo('REWIND');    Exit; End;
  If kw = 'BACKSPACE' Then Begin LexNext; ParseSimpleIo('BACKSPACE'); Exit; End;
  If kw = 'ENDFILE'   Then Begin LexNext; ParseSimpleIo('ENDFILE');   Exit; End;
  If kw = 'INQUIRE'   Then Begin LexNext; ParseInquire;            Exit; End;

  If kw = 'BLOCKDATA'  Then Begin LexNext; ParseBlockData;              Exit; End;
  If kw = 'PROGRAM'    Then Begin LexNext; ParseProgramDecl;            Exit; End;
  If kw = 'CALL'       Then Begin LexNext; ParseCallStmt;               Exit; End;
  If kw = 'SUBROUTINE' Then Begin LexNext; ParseSubroutineDecl;         Exit; End;
  If kw = 'FUNCTION'   Then Begin LexNext; ParseFunctionDecl(DT_NONE);  Exit; End;
  If kw = 'END'        Then Begin LexNext; ParseEnd;                    Exit; End;

  { ---- FORMAT label : capturer et emettre la spec en .DATA ---- }
  If kw = 'FORMAT' Then
  Begin
    LexNext;  { consommer FORMAT }
    { cur_tok doit etre sur '(' }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
      ParseFormatStmt(last_stmt_lbl)
    Else
    Begin
      WarnMsg('FORMAT ( attendu');
      While (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Do LexNext;
    End;
    Exit;
  End;

  { ---- Enonces de declaration : dispatcher ou intercepter FUNCTION ---- }
  If (kw = 'INTEGER') Or (kw = 'REAL') Or (kw = 'DOUBLE') Or
     (kw = 'DOUBLEPRECISION') Or
     (kw = 'LOGICAL') Or (kw = 'CHARACTER') Or (kw = 'COMPLEX') Then
  Begin
    LexNext;  { consommer le mot-cle de type }
    { INTEGER FUNCTION / REAL FUNCTION / etc. (prefixe colle ou token suivant) }
    If Copy(pre_ident, 1, 8) = 'FUNCTION' Then
    Begin
      pre_ident := Copy(pre_ident, 9, 255);
      If      kw = 'INTEGER'           Then ParseFunctionDecl(DT_INTEGER)
      Else If kw = 'REAL'              Then ParseFunctionDecl(DT_REAL)
      Else If kw = 'LOGICAL'           Then ParseFunctionDecl(DT_LOGICAL)
      Else If (kw = 'DOUBLE') Or
              (kw = 'DOUBLEPRECISION') Then ParseFunctionDecl(DT_DOUBLE)
      Else If kw = 'CHARACTER'         Then ParseFunctionDecl(DT_CHARACTER)
      Else                                  ParseFunctionDecl(DT_NONE);
    End
    Else If cur_tok.val = 'FUNCTION' Then
    Begin
      LexNext;  { consommer FUNCTION }
      If      kw = 'INTEGER'           Then ParseFunctionDecl(DT_INTEGER)
      Else If kw = 'REAL'              Then ParseFunctionDecl(DT_REAL)
      Else If kw = 'LOGICAL'           Then ParseFunctionDecl(DT_LOGICAL)
      Else If (kw = 'DOUBLE') Or
              (kw = 'DOUBLEPRECISION') Then ParseFunctionDecl(DT_DOUBLE)
      Else If kw = 'CHARACTER'         Then ParseFunctionDecl(DT_CHARACTER)
      Else                                  ParseFunctionDecl(DT_NONE);
    End
    Else
    Begin
      { Declaration de type simple (INTEGER X, REAL Y...) : ignorer les noms de var }
      pre_ident := '';
      While (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Do LexNext;
    End;
    Exit;
  End;

  { Declarations F77 avec semantique propre }
  If kw = 'COMMON'      Then Begin LexNext; pre_ident := ''; ParseCommon;      Exit; End;
  If kw = 'DATA'        Then Begin LexNext; pre_ident := ''; ParseData;        Exit; End;
  If kw = 'DIMENSION'   Then Begin LexNext; pre_ident := ''; ParseDimension;   Exit; End;
  If kw = 'EQUIVALENCE' Then Begin LexNext; pre_ident := ''; ParseEquivalence; Exit; End;
  If kw = 'SAVE'        Then Begin LexNext; pre_ident := ''; ParseSave;        Exit; End;
  If kw = 'IMPLICIT'    Then Begin LexNext; pre_ident := ''; ParseImplicit;    Exit; End;
  If kw = 'EXTERNAL' Then
  Begin
    LexNext; pre_ident := '';
    { Marquer les noms comme SK_EXTERNAL dans la sym_table }
    While (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Do
    Begin
      If cur_tok.kind = TK_IDENT Then
      Begin
        tmp_i := SymGetOrCreate(cur_tok.val);
        If tmp_i > 0 Then sym_table^[tmp_i].kind := SK_EXTERNAL;
      End;
      LexNext;
    End;
    Exit;
  End;
  If kw = 'INTRINSIC' Then
  Begin
    { Fonctions intrinseques : ignorer (traitees a l'appel) }
    LexNext; pre_ident := '';
    While (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Do LexNext;
    Exit;
  End;
  If kw = 'PARAMETER' Then
  Begin
    { evaluer expressions constantes - ignorer pour l'instant }
    LexNext; pre_ident := '';
    While (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Do LexNext;
    Exit;
  End;

  { ---- Affectation : IDENT [(indices)] = expr ---- }
  If cur_tok.kind = TK_IDENT Then
  Begin
    ParseAssignStmt;
    Exit;
  End;

  { Instruction non reconnue : sauter a la fin de ligne }
  WarnMsg('Instruction non reconnue : ' + kw);
  While (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Do LexNext;
End;

{ ============================================================
  READ / WRITE AVEC FORMAT
  ============================================================
  Format spec : stockee comme chaine 0-terminee en .DATA sous
  le label _FF_nnnnn (independant du label code _FL_nnnnn).
  Convention runtime :
    PUSH unit_num
    PUSH OFFSET _FF_nnnnn  (ou AX pour chaine litterale)
    pour chaque arg (gauche -> droite) :
      PUSH type_code  (0=INTEGER, 1=REAL, 2=CHARACTER, 3=LOGICAL)
      PUSH valeur (ou DX+AX pour REAL, AX+CX pour CHARACTER)
    PUSH arg_count
    CALL _FRT_FMT_WRITE  ou  _FRT_FMT_READ
    ADD SP, octets_depiles
  ============================================================ }

{ Retourne le label ASM d une spec FORMAT pour le numero F77 anum. }
Function FmtGetAsmLabel(anum : Integer) : TString;
Begin
  FmtGetAsmLabel := 'FK_FMT_' + IntToStr(anum);
End;

{ --------------------------------------------------------------------------
  FmtTokStr : convertit le token courant en fragment de chaine format.
  -------------------------------------------------------------------------- }
Function FmtTokStr : TString;
Var s : TString;
Begin
  Case cur_tok.kind Of
    TK_STRING : FmtTokStr := '''' + cur_tok.val + '''';
    TK_INTEGER : FmtTokStr := IntToStr(cur_tok.int_val);
    Else FmtTokStr := cur_tok.val;
  End;
End;

{ --------------------------------------------------------------------------
  ParseFormatStmt : capturer la spec FORMAT(...)  comme chaine brute,
  emettre dans .DATA sous _FF_nnnnn: DB '...', 0.
  cur_tok doit etre sur '(' au moment de l'appel.
  -------------------------------------------------------------------------- }
Procedure ParseFormatStmt(fmt_lbl : Integer);
Var
  raw   : TString;
  depth : Integer;
  lbl   : TString;
Begin
  raw   := '';
  depth := 0;
  lbl   := FmtGetAsmLabel(fmt_lbl);

  { Collecter tous les tokens jusqu'a la parenthese fermante de niveau 0 }
  While (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Do
  Begin
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
    Begin
      Inc(depth);
      If depth > 1 Then raw := raw + '(';
      LexNext;
      Continue;
    End;
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
    Begin
      Dec(depth);
      If depth <= 0 Then Begin LexNext; Break; End;
      raw := raw + ')';
      LexNext;
      Continue;
    End;
    raw := raw + FmtTokStr;
    LexNext;
  End;

  { Enregistrer dans la table FORMAT (utilise FmtEnter existant) }
  FmtEnter(fmt_lbl, raw);

  { Emettre la chaine en .DATA }
  EmitRaw('        .DATA');
  EmitLabel(lbl);
  If Length(raw) = 0 Then
    EmitRaw('        DB 0')
  Else
    EmitRaw('        DB ' + '''' + raw + '''' + ', 0');
  EmitRaw('        .CODE');
End;

{ --------------------------------------------------------------------------
  ParseFmtArgPush : evaluer et pousser un item de liste I/O sur la pile.
  Retourne le nombre de words pousses (pour calcul ADD SP).
  -------------------------------------------------------------------------- }
Function ParseFmtArgPush(is_write : Boolean) : Integer;
Var
  dt  : TDataType;
  si  : Integer;
  nm  : TString;
  s   : TSymRef;
Begin
  ParseFmtArgPush := 0;
  dt := PeekExprType;

  If is_write Then
  Begin
    Case dt Of
      DT_REAL, DT_DOUBLE :
      Begin
        ParseRealExpr;           { DX:AX }
        EmitI1('PUSH', 'DX');
        EmitI1('PUSH', 'AX');
        EmitI2('MOV', 'AX', '1');
        EmitI1('PUSH', 'AX');    { type code = 1 (REAL) }
        ParseFmtArgPush := 3;
      End;
      DT_CHARACTER :
      Begin
        ParseCharExpr;           { AX=ptr, CX=len }
        EmitI1('PUSH', 'CX');
        EmitI1('PUSH', 'AX');
        EmitI2('MOV', 'AX', '2');
        EmitI1('PUSH', 'AX');    { type code = 2 (STR) }
        ParseFmtArgPush := 3;
      End;
      DT_LOGICAL :
      Begin
        ParseLogExpr;            { AX }
        EmitI1('PUSH', 'AX');
        EmitI2('MOV', 'AX', '3');
        EmitI1('PUSH', 'AX');    { type code = 3 (LOGICAL) }
        ParseFmtArgPush := 2;
      End;
      Else
      Begin
        ParseIntExpr;            { AX }
        EmitI1('PUSH', 'AX');
        EmitI2('MOV', 'AX', '0');
        EmitI1('PUSH', 'AX');    { type code = 0 (INTEGER) }
        ParseFmtArgPush := 2;
      End;
    End;
  End
  Else
  Begin
    { READ : pousser l'adresse de la variable + type }
    If cur_tok.kind <> TK_IDENT Then
    Begin
      WarnMsg('READ format : identifiant attendu');
      LexNext;
      Exit;
    End;
    nm := cur_tok.val;
    LexNext;
    si := SymGetOrCreate(nm);
    If sym_table^[si].dtype = DT_NONE Then sym_table^[si].dtype := DT_INTEGER;
    s  := sym_table^[si];
    If s.bp_offset < 0 Then
      EmitRaw('        LEA AX, [BP' + IntToStr(s.bp_offset) + ']')
    Else If s.asm_label <> '' Then
      EmitI2('MOV', 'AX', 'OFFSET ' + s.asm_label)
    Else
    Begin
      WarnMsg('READ format : variable sans adresse - ' + nm);
      Exit;
    End;
    EmitI1('PUSH', 'AX');
    Case s.dtype Of
      DT_REAL, DT_DOUBLE :
      Begin
        EmitI2('MOV', 'AX', '1'); EmitI1('PUSH', 'AX');
      End;
      DT_CHARACTER :
      Begin
        EmitI2('MOV', 'AX', '2'); EmitI1('PUSH', 'AX');
        EmitI1('PUSH', IntToStr(s.char_len));  { longueur max }
        ParseFmtArgPush := 3;
        Exit;
      End;
      DT_LOGICAL :
      Begin
        EmitI2('MOV', 'AX', '3'); EmitI1('PUSH', 'AX');
      End;
      Else
      Begin
        EmitI2('MOV', 'AX', '0'); EmitI1('PUSH', 'AX');
      End;
    End;
    ParseFmtArgPush := 2;
  End;
End;

{ --------------------------------------------------------------------------
  ParseFmtIoList : emettre le code WRITE/READ formate.
  fmt_anum = 0 si format =  chaine litterale (fmt_str utilise a la place).
  -------------------------------------------------------------------------- }
Procedure ParseFmtIoList(is_write : Boolean; unit_num : Integer;
                          fmt_anum : Integer; Const fmt_str : TString);
Var
  nargs      : Integer;
  stack_words: Integer;
  frt_name   : TString;
  lbl        : TString;
Begin
  nargs := 0;
  stack_words := 0;

  If is_write Then frt_name := 'FMT_WRITE' Else frt_name := 'FMT_READ';
  EmitComment(frt_name + ' unit=' + IntToStr(unit_num));

  { Pousser les arguments de la liste (gauche -> droite) }
  While (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Do
  Begin
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then Break;
    Inc(nargs);
    Inc(stack_words, ParseFmtArgPush(is_write));
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
  End;

  { Pousser le nombre d'arguments }
  EmitI2('MOV', 'AX', IntToStr(nargs));
  EmitI1('PUSH', 'AX');
  Inc(stack_words);

  { Pousser l'adresse de la spec format }
  If fmt_anum > 0 Then
  Begin
    EmitI2('MOV', 'AX', 'OFFSET ' + FmtGetAsmLabel(fmt_anum));
    EmitI1('PUSH', 'AX');
  End
  Else If fmt_str <> '' Then
  Begin
    { Chaine litterale : emettre en .DATA }
    lbl := GenDataLabel;
    EmitRaw('        .DATA');
    EmitLabel(lbl);
    EmitRaw('        DB ' + '''' + fmt_str + '''' + ', 0');
    EmitRaw('        .CODE');
    EmitI2('MOV', 'AX', 'OFFSET ' + lbl);
    EmitI1('PUSH', 'AX');
  End
  Else
  Begin
    { Format libre * : pousser 0 pour signifier format libre }
    EmitI2('MOV', 'AX', '0');
    EmitI1('PUSH', 'AX');
  End;
  Inc(stack_words);

  { Pousser le numero d'unite logique }
  EmitI2('MOV', 'AX', IntToStr(unit_num));
  EmitI1('PUSH', 'AX');
  Inc(stack_words);

  { Appel runtime }
  EmitRaw('        CALL ' + FRT_PFX + frt_name);
  EmitI2('ADD', 'SP', IntToStr(stack_words * 2));
End;

{ ============================================================
  INSTRUCTIONS D'E/S FICHIERS
  ============================================================
  OPEN(unit [,FILE=str] [,STATUS=str] [,ACCESS=str] [,FORM=str]
            [,RECL=n] [,IOSTAT=var] [,ERR=lbl])
  CLOSE(unit [,STATUS=str] [,IOSTAT=var] [,ERR=lbl])
  REWIND(unit [,IOSTAT=var] [,ERR=lbl])
  BACKSPACE(unit [,IOSTAT=var] [,ERR=lbl])
  ENDFILE(unit [,IOSTAT=var] [,ERR=lbl])
  INQUIRE(unit|FILE=str, ...) -- simplifie : warning

  Convention appel runtime :
    OPEN        : PUSH unit ; PUSH OFFSET filename (0=aucun) ;
                  PUSH status_code ; CALL _FRT_OPEN ; ADD SP,6
    CLOSE       : PUSH unit ; PUSH status_code ; CALL _FRT_CLOSE ; ADD SP,4
    REWIND      : PUSH unit ; CALL _FRT_REWIND ; ADD SP,2
    BACKSPACE   : PUSH unit ; CALL _FRT_BACKSPACE ; ADD SP,2
    ENDFILE     : PUSH unit ; CALL _FRT_ENDFILE ; ADD SP,2
    Apres chaque appel :
      Si IOSTAT=var : MOV [var], AX
      Si ERR=lbl   : CMP AX,0 ; JNZ FL_lbl
  Codes STATUS pour OPEN : 0=inconnu 1=OLD 2=NEW 3=REPLACE 4=SCRATCH
  Codes STATUS pour CLOSE: 0=KEEP 1=DELETE
  ============================================================ }

{ --------------------------------------------------------------------------
  IoCvtStatusOpen : convertit une chaine STATUS en code entier pour OPEN.
  -------------------------------------------------------------------------- }
Function IoCvtStatusOpen(Const s : TString) : Integer;
Begin
  If      s = 'OLD'     Then IoCvtStatusOpen := 1
  Else If s = 'NEW'     Then IoCvtStatusOpen := 2
  Else If s = 'REPLACE' Then IoCvtStatusOpen := 3
  Else If s = 'SCRATCH' Then IoCvtStatusOpen := 4
  Else                       IoCvtStatusOpen := 0;
End;

{ --------------------------------------------------------------------------
  IoCvtStatusClose : convertit une chaine STATUS en code entier pour CLOSE.
  -------------------------------------------------------------------------- }
Function IoCvtStatusClose(Const s : TString) : Integer;
Begin
  If s = 'DELETE' Then IoCvtStatusClose := 1
  Else                 IoCvtStatusClose := 0;  { KEEP par defaut }
End;

{ --------------------------------------------------------------------------
  IoEmitIostatErr : emettre le code IOSTAT/ERR apres un appel runtime.
  AX = code de retour (0 = OK).
  -------------------------------------------------------------------------- }
Procedure IoEmitIostatErr(iostat_si : Integer; err_lnum : Integer);
Var lbl_ok : TString;
Begin
  If iostat_si > 0 Then
    GenStoreInt(iostat_si);   { MOV [var], AX }
  If err_lnum > 0 Then
  Begin
    lbl_ok := GenBranchLabel;
    EmitI2('CMP', 'AX', '0');
    EmitI1('JE',  lbl_ok);
    EmitI1('JMP', LabelGetAsm(err_lnum));
    EmitLabel(lbl_ok);
  End;
End;

{ --------------------------------------------------------------------------
  IoSkipToClose : avancer jusqu'a ')' (fin de liste de controle).
  -------------------------------------------------------------------------- }
Procedure IoSkipToClose;
Begin
  While (cur_tok.val <> ')') And (cur_tok.kind <> TK_NEWLINE)
        And (cur_tok.kind <> TK_EOF) Do LexNext;
  If cur_tok.val = ')' Then LexNext;
End;

{ --------------------------------------------------------------------------
  IoParseUnit : lire le numero d'unite apres '('.
  Supporte UNIT=n et n positionnels.
  -------------------------------------------------------------------------- }
Function IoParseUnit : Integer;
Var u : Integer;
Begin
  u := 0;
  { UNIT=n }
  If (cur_tok.kind = TK_IDENT) And (cur_tok.val = 'UNIT') Then
  Begin
    LexNext;  { consommer UNIT }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '=') Then LexNext;
  End;
  If cur_tok.kind = TK_INTEGER Then
  Begin
    u := cur_tok.int_val;
    LexNext;
  End
  Else
  Begin
    WarnMsg('IO : numero d''unite entier attendu');
    LexNext;
  End;
  IoParseUnit := u;
End;

{ --------------------------------------------------------------------------
  ParseOpen : OPEN(unit [,kv-pairs...])
  -------------------------------------------------------------------------- }
Procedure ParseOpen;
Var
  unit_num    : Integer;
  status_code : Integer;
  iostat_si   : Integer;
  err_lnum    : Integer;
  file_lbl    : TString;      { label ASM de la chaine filename }
  kw          : TString;
  sval        : TString;
  has_file    : Boolean;
Begin
  unit_num    := 0;
  status_code := 0;
  iostat_si   := 0;
  err_lnum    := 0;
  file_lbl    := '';
  has_file    := False;

  { Lire les parametres entre parentheses }
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then LexNext;

  unit_num := IoParseUnit;

  { Parcourir les paires mot-cle=valeur }
  While (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Do
  Begin
    LexNext;  { , }
    If cur_tok.kind <> TK_IDENT Then Begin IoSkipToClose; Break; End;
    kw := cur_tok.val; LexNext;
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '=') Then LexNext;

    If kw = 'FILE' Then
    Begin
      has_file := True;
      If cur_tok.kind = TK_STRING Then
      Begin
        sval := cur_tok.val; LexNext;
        { Emettre la chaine en .DATA }
        file_lbl := GenDataLabel;
        EmitRaw('        .DATA');
        EmitLabel(file_lbl);
        EmitRaw('        DB ' + '''' + sval + '''' + ', 0');
        EmitRaw('        .CODE');
      End
      Else
      Begin
        { Variable CHARACTER : charger adresse }
        ParseCharExpr;            { AX = ptr }
        file_lbl := '';           { signifier "adresse dans AX" }
      End;
    End
    Else If kw = 'STATUS' Then
    Begin
      If cur_tok.kind = TK_STRING Then
      Begin
        status_code := IoCvtStatusOpen(cur_tok.val);
        LexNext;
      End
      Else
      Begin
        { expression : ignorer, garder 0 }
        While (cur_tok.kind <> TK_PUNCT) Or
              ((cur_tok.val <> ',') And (cur_tok.val <> ')')) Do
          LexNext;
      End;
    End
    Else If kw = 'IOSTAT' Then
    Begin
      If cur_tok.kind = TK_IDENT Then
      Begin
        iostat_si := SymGetOrCreate(cur_tok.val);
        If sym_table^[iostat_si].dtype = DT_NONE Then
          sym_table^[iostat_si].dtype := DT_INTEGER;
        LexNext;
      End
      Else LexNext;
    End
    Else If kw = 'ERR' Then
    Begin
      If cur_tok.kind = TK_INTEGER Then
      Begin
        err_lnum := cur_tok.int_val;
        LexNext;
      End
      Else LexNext;
    End
    Else
    Begin
      { Param non reconnu (ACCESS, FORM, RECL, BLANK...) : ignorer valeur }
      While (cur_tok.kind <> TK_PUNCT) Or
            ((cur_tok.val <> ',') And (cur_tok.val <> ')')) Do
      Begin
        If (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF) Then Break;
        LexNext;
      End;
    End;
  End;
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;

  { Generer le code }
  EmitComment('OPEN unit=' + IntToStr(unit_num));
  EmitI2('MOV', 'AX', IntToStr(status_code));
  EmitI1('PUSH', 'AX');                            { status }
  If has_file And (file_lbl <> '') Then
    EmitI2('MOV', 'AX', 'OFFSET ' + file_lbl)
  Else If Not has_file Then
    EmitI2('MOV', 'AX', '0')
  { sinon : AX deja charge par ParseCharExpr } ;
  EmitI1('PUSH', 'AX');                            { filename ptr }
  EmitI2('MOV', 'AX', IntToStr(unit_num));
  EmitI1('PUSH', 'AX');                            { unit }
  EmitRaw('        CALL ' + FRT_PFX + 'OPEN');
  EmitI2('ADD', 'SP', '6');
  IoEmitIostatErr(iostat_si, err_lnum);
End;

{ --------------------------------------------------------------------------
  ParseClose : CLOSE(unit [,STATUS=str] [,IOSTAT=var] [,ERR=lbl])
  -------------------------------------------------------------------------- }
Procedure ParseClose;
Var
  unit_num    : Integer;
  status_code : Integer;
  iostat_si   : Integer;
  err_lnum    : Integer;
  kw          : TString;
Begin
  unit_num    := 0;
  status_code := 0;
  iostat_si   := 0;
  err_lnum    := 0;

  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then LexNext;
  unit_num := IoParseUnit;

  While (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Do
  Begin
    LexNext;
    If cur_tok.kind <> TK_IDENT Then Begin IoSkipToClose; Break; End;
    kw := cur_tok.val; LexNext;
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '=') Then LexNext;
    If kw = 'STATUS' Then
    Begin
      If cur_tok.kind = TK_STRING Then
      Begin
        status_code := IoCvtStatusClose(cur_tok.val);
        LexNext;
      End
      Else LexNext;
    End
    Else If kw = 'IOSTAT' Then
    Begin
      If cur_tok.kind = TK_IDENT Then
      Begin
        iostat_si := SymGetOrCreate(cur_tok.val);
        If sym_table^[iostat_si].dtype = DT_NONE Then
          sym_table^[iostat_si].dtype := DT_INTEGER;
        LexNext;
      End
      Else LexNext;
    End
    Else If kw = 'ERR' Then
    Begin
      If cur_tok.kind = TK_INTEGER Then
        Begin err_lnum := cur_tok.int_val; LexNext; End
      Else LexNext;
    End
    Else
    Begin
      While (cur_tok.kind <> TK_PUNCT) Or
            ((cur_tok.val <> ',') And (cur_tok.val <> ')')) Do
      Begin
        If (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF) Then Break;
        LexNext;
      End;
    End;
  End;
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;

  EmitComment('CLOSE unit=' + IntToStr(unit_num));
  EmitI2('MOV', 'AX', IntToStr(status_code));
  EmitI1('PUSH', 'AX');
  EmitI2('MOV', 'AX', IntToStr(unit_num));
  EmitI1('PUSH', 'AX');
  EmitRaw('        CALL ' + FRT_PFX + 'CLOSE');
  EmitI2('ADD', 'SP', '4');
  IoEmitIostatErr(iostat_si, err_lnum);
End;

{ --------------------------------------------------------------------------
  ParseSimpleIo : REWIND / BACKSPACE / ENDFILE (unit [,IOSTAT=var] [,ERR=lbl])
  frt_suffix = 'REWIND', 'BACKSPACE' ou 'ENDFILE'.
  -------------------------------------------------------------------------- }
Procedure ParseSimpleIo(Const frt_suffix : TString);
Var
  unit_num  : Integer;
  iostat_si : Integer;
  err_lnum  : Integer;
  kw        : TString;
Begin
  unit_num  := 0;
  iostat_si := 0;
  err_lnum  := 0;

  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then LexNext;
  unit_num := IoParseUnit;

  While (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Do
  Begin
    LexNext;
    If cur_tok.kind <> TK_IDENT Then Begin IoSkipToClose; Break; End;
    kw := cur_tok.val; LexNext;
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '=') Then LexNext;
    If kw = 'IOSTAT' Then
    Begin
      If cur_tok.kind = TK_IDENT Then
      Begin
        iostat_si := SymGetOrCreate(cur_tok.val);
        If sym_table^[iostat_si].dtype = DT_NONE Then
          sym_table^[iostat_si].dtype := DT_INTEGER;
        LexNext;
      End
      Else LexNext;
    End
    Else If kw = 'ERR' Then
    Begin
      If cur_tok.kind = TK_INTEGER Then
        Begin err_lnum := cur_tok.int_val; LexNext; End
      Else LexNext;
    End
    Else LexNext;
  End;
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;

  EmitComment(frt_suffix + ' unit=' + IntToStr(unit_num));
  EmitI2('MOV', 'AX', IntToStr(unit_num));
  EmitI1('PUSH', 'AX');
  EmitRaw('        CALL ' + FRT_PFX + frt_suffix);
  EmitI2('ADD', 'SP', '2');
  IoEmitIostatErr(iostat_si, err_lnum);
End;

{ --------------------------------------------------------------------------
  ParseInquire : INQUIRE(unit|FILE=str [,...]) -- implementation simplifiee.
  Emet CALL _FRT_INQUIRE(unit) et ignore les parametres de sortie.
  -------------------------------------------------------------------------- }
Procedure ParseInquire;
Var unit_num : Integer;
Begin
  unit_num := 0;
  WarnMsg('INQUIRE : implementation simplifiee');
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then LexNext;
  { Chercher UNIT= ou numero positionnel }
  If (cur_tok.kind = TK_IDENT) And (cur_tok.val = 'FILE') Then
  Begin
    { INQUIRE(FILE=str,...) -> pas de numero d'unite }
    IoSkipToClose;
  End
  Else
  Begin
    unit_num := IoParseUnit;
    IoSkipToClose;
    EmitComment('INQUIRE unit=' + IntToStr(unit_num));
    EmitI2('MOV', 'AX', IntToStr(unit_num));
    EmitI1('PUSH', 'AX');
    EmitRaw('        CALL ' + FRT_PFX + 'INQUIRE');
    EmitI2('ADD', 'SP', '2');
  End;
End;

{ ============================================================
  SUBROUTINE ET CALL
  ============================================================
  Convention 8086 by-reference (.MODEL SMALL, NEAR calls) :
    - L'appelant pousse les ADRESSES de chaque argument (PUSH OFFSET var
      ou LEA AX,[BP+n] / PUSH AX pour dummy local).
    - Le sous-programme accede a l'argument via indirection :
      MOV BX, [BP+4+i*2] ; MOV AX, [BX]  (load)
      MOV BX, [BP+4+i*2] ; MOV [BX], AX  (store)
    - Cadre de pile :
        [BP+4]           = adresse arg 0 (premier argument)
        [BP+6]           = adresse arg 1, ...
        [BP+2]           = adresse retour
        [BP+0]           = ancien BP
  Nettoyage pile : a la charge de l'APPELANT (ADD SP, nargs*2).
  ============================================================ }

{ --------------------------------------------------------------------------
  ImplicitType : retourner le type implicite F77 pour une lettre initiale.
  I..N -> INTEGER, reste -> REAL (sauf IMPLICIT NONE -> DT_NONE).
  -------------------------------------------------------------------------- }
Function ImplicitType(c : Char) : TDataType;
Begin
  If impl_none Then
    ImplicitType := DT_NONE
  Else
    ImplicitType := impl_type[c];
End;

{ --------------------------------------------------------------------------
  GenPushArgAddr : pousser l'adresse d'un argument effectif sur la pile.
  Si l'argument est un identifiant connu : LEA/OFFSET.
  Sinon : evaluer en entier, sauver dans temp anonyme, pousser adresse.
  Retourne True si OK, False si skip.
  -------------------------------------------------------------------------- }
Function GenPushArgAddr(Const nm : TString) : Boolean;
Var
  si  : Integer;
  s   : TSymRef;
  tmp : TString;
Begin
  GenPushArgAddr := True;
  si := SymFind(nm);
  If si < 1 Then si := SymGetOrCreate(nm);
  If si < 1 Then
  Begin
    WarnMsg('CALL : argument inconnu - ' + nm);
    GenPushArgAddr := False;
    Exit;
  End;
  s := sym_table^[si];
  If s.is_dummy And (s.bp_offset > 0) Then
  Begin
    { Repasser l''adresse reelle du dummy : MOV AX,[BP+n] ; PUSH AX }
    EmitI2('MOV', 'AX', 'WORD PTR [BP+' + IntToStr(s.bp_offset) + ']');
    EmitI1('PUSH', 'AX');
  End
  Else If s.bp_offset < 0 Then
  Begin
    EmitRaw('        LEA AX, [BP' + IntToStr(s.bp_offset) + ']');
    EmitI1('PUSH', 'AX');
  End
  Else If s.asm_label <> '' Then
  Begin
    EmitI2('MOV', 'AX', 'OFFSET ' + s.asm_label);
    EmitI1('PUSH', 'AX');
  End
  Else
  Begin
    WarnMsg('CALL : argument sans adresse - ' + nm);
    GenPushArgAddr := False;
  End;
End;

{ --------------------------------------------------------------------------
  ParseCallStmt : CALL nom [(arg1, arg2, ...)]
  Le mot-cle CALL est deja consomme.
  -------------------------------------------------------------------------- }
Procedure ParseCallStmt;
Var
  sub_name  : TString;
  nargs     : Integer;
  nm        : TString;
  ok        : Boolean;
  ai        : Integer;
  j         : Integer;
  found     : Boolean;
  arg_names : Array[0..31] of TString;
Begin
  { Nom depuis pre_ident (F77 kw colle) ou token suivant }
  If pre_ident <> '' Then
  Begin
    sub_name  := pre_ident;
    pre_ident := '';
  End
  Else
  Begin
    If cur_tok.kind <> TK_IDENT Then
    Begin
      ErrorMsg('CALL : identifiant attendu');
      While (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Do LexNext;
      Exit;
    End;
    sub_name := cur_tok.val;
    LexNext;
  End;
  nargs := 0;

  { Enregistrer le nom pour emission EXTRN eventuelle }
  found := False;
  For j := 1 To called_list_cnt Do
    If called_list[j] = sub_name Then Begin found := True; Break; End;
  If Not found And (called_list_cnt < 128) Then
  Begin
    Inc(called_list_cnt);
    called_list[called_list_cnt] := sub_name;
  End;

  EmitComment('CALL ' + sub_name);

  { Collecter et pousser les arguments (adresses, droite->gauche) }
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
  Begin
    LexNext;  { ( }
    nargs := 0;
    While (cur_tok.val <> ')') And (cur_tok.kind <> TK_NEWLINE)
          And (cur_tok.kind <> TK_EOF) Do
    Begin
      If cur_tok.kind = TK_IDENT Then
      Begin
        arg_names[nargs] := cur_tok.val;
        Inc(nargs);
        LexNext;
      End
      Else
      Begin
        WarnMsg('CALL ' + sub_name + ' : argument non-ident ignore');
        LexNext;
      End;
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
    End;
    If cur_tok.val = ')' Then LexNext;

    { Pousser de droite a gauche }
    For ai := nargs - 1 DownTo 0 Do
    Begin
      ok := GenPushArgAddr(arg_names[ai]);
      If Not ok Then
      Begin
        EmitI2('MOV', 'AX', '0');
        EmitI1('PUSH', 'AX');
      End;
    End;
  End;

  EmitRaw('        CALL ' + FP_PFX + sub_name);
  If nargs > 0 Then
    EmitI2('ADD', 'SP', IntToStr(nargs * 2));
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  ParseSubroutineDecl : SUBROUTINE nom [(p1,p2,...)]
  Emet le prologue et enregistre les parametres formels.
  -------------------------------------------------------------------------- }
Procedure ParseSubroutineDecl;
Var
  subr_name  : TString;
  pi         : Integer;
  si         : Integer;
  bp_off     : Integer;
  pname      : TString;
  pidx       : Integer;
Begin
  { Nom depuis pre_ident (F77 kw colle) ou token suivant }
  If pre_ident <> '' Then
  Begin
    subr_name := pre_ident;
    pre_ident := '';
  End
  Else
  Begin
    If cur_tok.kind <> TK_IDENT Then
    Begin
      ErrorMsg('SUBROUTINE : identifiant attendu');
      While (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Do LexNext;
      Exit;
    End;
    subr_name := cur_tok.val;
    LexNext;
  End;

  { Enregistrer dans proc_table }
  If proc_count < MAX_PROC Then
  Begin
    Inc(proc_count);
    pidx := proc_count;
    proc_table^[pidx].name        := subr_name;
    proc_table^[pidx].asm_label   := FP_PFX + subr_name;
    proc_table^[pidx].is_function := False;
    proc_table^[pidx].ret_type    := DT_NONE;
    proc_table^[pidx].param_count := 0;
    cur_proc_idx := pidx;
  End
  Else
  Begin
    ErrorMsg('Table proc saturee');
    Exit;
  End;

  cur_subr_name := subr_name;
  cur_ret_lbl   := GenBranchLabel;

  { Compter et enregistrer les parametres formels }
  pi := 0;
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
  Begin
    LexNext;  { ( }
    While (cur_tok.val <> ')') And (cur_tok.kind <> TK_NEWLINE)
          And (cur_tok.kind <> TK_EOF) Do
    Begin
      If cur_tok.kind <> TK_IDENT Then Begin LexNext; Continue; End;
      pname  := cur_tok.val;
      bp_off := 4 + pi * 2;  { [BP+4] = arg0, [BP+6] = arg1, ... }
      LexNext;

      { Entrer dans sym_table }
      si := SymGetOrCreate(pname);
      sym_table^[si].dtype      := ImplicitType(pname[1]);
      sym_table^[si].is_dummy   := True;
      sym_table^[si].bp_offset  := bp_off;
      sym_table^[si].asm_label  := '';  { acces par indirection BP }
      sym_table^[si].scope_unit := cur_proc_idx;

      { Enregistrer dans proc_table }
      If pi < MAX_PARAM Then
      Begin
        proc_table^[pidx].params[pi + 1].name      := pname;
        proc_table^[pidx].params[pi + 1].dtype     := sym_table^[si].dtype;
        proc_table^[pidx].params[pi + 1].bp_offset := bp_off;
        proc_table^[pidx].params[pi + 1].is_array  := False;
      End;
      Inc(pi);

      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
    End;
    If cur_tok.val = ')' Then LexNext;
  End;
  proc_table^[pidx].param_count := pi;

  { Emettre le prologue }
  GenProcBegin(subr_name, pi);
End;

{ --------------------------------------------------------------------------
  ParseEnd : enonce END - ferme le sous-programme courant ou le programme.
  -------------------------------------------------------------------------- }
Procedure ParseEnd;
Begin
  If cur_subr_name <> '' Then
  Begin
    { Emettre le label de retour et l'epilogue }
    EmitLabel(cur_ret_lbl);
    { Pour une FUNCTION : charger le resultat dans AX ou DX:AX avant le RET }
    If cur_func_result_si > 0 Then
    Begin
      EmitComment('Charger la valeur de retour de la FUNCTION');
      If cur_func_ret_type = DT_REAL Then
        GenLoadReal(cur_func_result_si)
      Else
        GenLoadInt(cur_func_result_si);
    End;
    GenProcEnd(cur_subr_name);
    cur_subr_name      := '';
    cur_ret_lbl        := '';
    cur_proc_idx       := 0;
    cur_func_result_si := 0;
    cur_func_ret_type  := DT_NONE;
  End
  Else If Not prog_epilogue_done Then
  Begin
    { Fin du programme principal : epilogue seul. GenFileEnd est appele
      APRES les routines runtime, depuis le programme principal. }
    GenProgramEpilogue;
    prog_epilogue_done := True;
  End;
End;

{ ============================================================
  DECLARATION ET APPEL DE FONCTION (FUNCTION)
  ============================================================
  FUNCTION nom [(params)] ... nom = expr ... RETURN ... END
  Convention : la valeur de retour est stockee dans une variable
  statique _FV_<nom>_RES (accessible depuis toute l'unite).
  L'appelant recupere la valeur dans AX (INTEGER/LOGICAL) ou
  DX:AX (REAL).
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseFunctionDecl : traiter la declaration FUNCTION.
  ret_dtype : type deduit du prefixe (INTEGER, REAL, LOGICAL, DOUBLE)
              ou DT_NONE pour type implicite.
  Le mot-cle FUNCTION a deja ete consomme.
  -------------------------------------------------------------------------- }
Procedure ParseFunctionDecl(ret_dtype : TDataType);
Var
  fn_name    : TString;
  res_label  : TString;
  pi, si     : Integer;
  bp_off     : Integer;
  pk         : Integer;
  pname      : TString;
  si_p       : Integer;
Begin
  { Nom depuis pre_ident (F77 kw colle) ou token suivant }
  If pre_ident <> '' Then
  Begin
    fn_name   := pre_ident;
    pre_ident := '';
  End
  Else
  Begin
    If cur_tok.kind <> TK_IDENT Then
    Begin
      ErrorMsg('FUNCTION : identifiant attendu');
      While (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Do LexNext;
      Exit;
    End;
    fn_name := cur_tok.val;
    LexNext;
  End;

  { Type de retour implicite si non specifie }
  If ret_dtype = DT_NONE Then
    ret_dtype := ImplicitType(fn_name[1]);

  { Enregistrer dans proc_table }
  If proc_count >= MAX_PROC Then
  Begin
    ErrorMsg('Table proc saturee');
    Exit;
  End;
  Inc(proc_count);
  pi := proc_count;
  proc_table^[pi].name        := fn_name;
  proc_table^[pi].asm_label   := FP_PFX + fn_name;
  proc_table^[pi].is_function := True;
  proc_table^[pi].ret_type    := ret_dtype;
  proc_table^[pi].param_count := 0;
  proc_table^[pi].local_size  := DataTypeSize(ret_dtype, 0);
  cur_proc_idx      := pi;
  cur_subr_name     := fn_name;
  cur_func_ret_type := ret_dtype;

  { Allouer la variable resultat en .DATA (switch inline) }
  res_label := FV_PFX + fn_name + '_RES';
  EmitRaw('        .DATA');
  EmitRaw(res_label + ':');
  If ret_dtype = DT_REAL Then
    EmitRaw('        DD 0    ; resultat FUNCTION ' + fn_name)
  Else
    EmitRaw('        DW 0    ; resultat FUNCTION ' + fn_name);
  EmitRaw('        .CODE');

  { Entrer le nom de la fonction dans sym_table -> variable resultat }
  si := SymGetOrCreate(fn_name);
  sym_table^[si].dtype      := ret_dtype;
  sym_table^[si].asm_label  := res_label;
  sym_table^[si].bp_offset  := 0;   { acces par asm_label, pas par BP }
  sym_table^[si].is_dummy   := False;
  sym_table^[si].scope_unit := pi;
  cur_func_result_si := si;

  { Parser les parametres formels }
  pk := 0;
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
  Begin
    LexNext;  { ( }
    While (cur_tok.val <> ')') And (cur_tok.kind <> TK_NEWLINE)
          And (cur_tok.kind <> TK_EOF) Do
    Begin
      If cur_tok.kind <> TK_IDENT Then Begin LexNext; Continue; End;
      pname  := cur_tok.val;
      bp_off := 4 + pk * 2;  { [BP+4]=arg0, [BP+6]=arg1, ... }
      LexNext;

      si_p := SymGetOrCreate(pname);
      sym_table^[si_p].dtype      := ImplicitType(pname[1]);
      sym_table^[si_p].is_dummy   := True;
      sym_table^[si_p].bp_offset  := bp_off;
      sym_table^[si_p].asm_label  := '';
      sym_table^[si_p].scope_unit := pi;

      If pk < MAX_PARAM Then
      Begin
        proc_table^[pi].params[pk + 1].name      := pname;
        proc_table^[pi].params[pk + 1].dtype     := sym_table^[si_p].dtype;
        proc_table^[pi].params[pk + 1].bp_offset := bp_off;
        proc_table^[pi].params[pk + 1].is_array  := False;
      End;
      Inc(pk);

      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then LexNext;
    End;
    If cur_tok.val = ')' Then LexNext;
  End;
  proc_table^[pi].param_count := pk;

  { Label de retour }
  cur_ret_lbl := GenBranchLabel;

  { Prologue }
  GenProcBegin(fn_name, pk);
End;

{ ============================================================
  BLOCK DATA ET UNITES DE COMPILATION MULTIPLES
  ============================================================ }

{ --------------------------------------------------------------------------
  GenPublicDecls : emettre les directives PUBLIC pour tous les sous-programmes
  definis dans cette unite et pour tous les blocs COMMON.
  Appele depuis GenRuntimeRoutines (dans la section .CODE du tmp_file).
  -------------------------------------------------------------------------- }
Procedure GenPublicDecls;
Var i : Integer;
Begin
  If (proc_count = 0) And (common_count = 0) Then Exit;
  EmitRaw('; --- Symboles exportes (PUBLIC) ---');
  For i := 1 To proc_count Do
    EmitRaw('        PUBLIC ' + proc_table^[i].asm_label);
  For i := 1 To common_count Do
    EmitRaw('        PUBLIC ' + common_table^[i].asm_label);
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenExtrnDecls : emettre les directives EXTRN pour les sous-programmes
  externes. Sources :
    - SK_EXTERNAL dans sym_table (declarees via EXTERNAL xxx)
    - Appels CALL a des sous-programmes non definis localement (dans
      proc_table) enregistres dans called_list durant le parsing.
  -------------------------------------------------------------------------- }
Procedure GenExtrnDecls;
Var i, j  : Integer;
    lbl   : TString;
    found : Boolean;
Begin
  { Symboles declares EXTERNAL by the user }
  For i := 1 To sym_count Do
    If sym_table^[i].kind = SK_EXTERNAL Then
    Begin
      lbl := FP_PFX + sym_table^[i].name;
      EmitRaw('        EXTRN ' + lbl + ':NEAR');
    End;
  { Appels a des sous-programmes non definis dans proc_table }
  For i := 1 To called_list_cnt Do
  Begin
    found := False;
    For j := 1 To proc_count Do
      If proc_table^[j].name = called_list[i] Then
      Begin found := True; Break; End;
    If Not found Then
    Begin
      { Verifier aussi qu il n est pas deja emis par SK_EXTERNAL }
      found := False;
      For j := 1 To sym_count Do
        If (sym_table^[j].kind = SK_EXTERNAL) And
           (sym_table^[j].name = called_list[i]) Then
        Begin found := True; Break; End;
      If Not found Then
        EmitRaw('        EXTRN ' + FP_PFX + called_list[i] + ':NEAR');
    End;
  End;
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  ParseBlockData : parser une unite BLOCK DATA [nom] ... END.
  En Fortran 77, une unite BLOCK DATA initialise les blocs COMMON nommes.
  Seules les declarations et enonces DATA sont autorises.
  -------------------------------------------------------------------------- }
Procedure ParseBlockData;
Var bd_name : TString;
Begin
  bd_name := '';
  { Nom depuis pre_ident (F77 kw colle) ou token suivant }
  If pre_ident <> '' Then
  Begin
    bd_name   := pre_ident;
    pre_ident := '';
  End
  Else
  Begin
    While cur_tok.kind = TK_NEWLINE Do LexNext;
    If (cur_tok.kind = TK_IDENT) And (cur_tok.val <> 'END') Then
    Begin
      bd_name := cur_tok.val;
      LexNext;
    End;
  End;
  block_data_name := bd_name;
  in_block_data   := True;
  { Mettre un marqueur dans cur_subr_name pour que ParseEnd ne
    declenche pas GenProgramEpilogue }
  cur_subr_name := '$BD_' + bd_name;
  cur_ret_lbl   := '';
  If bd_name <> '' Then
    EmitComment('BLOCK DATA ' + bd_name + ' (initialisation COMMON)')
  Else
    EmitComment('BLOCK DATA (initialisation BLANK COMMON)');
  { Boucle de parsing : seuls declarations + DATA autorises }
  While cur_tok.kind <> TK_EOF Do
  Begin
    While cur_tok.kind = TK_NEWLINE Do LexNext;
    If cur_tok.kind = TK_EOF Then Break;
    If cur_tok.val = 'END' Then
    Begin
      LexNext;  { consommer END }
      Break;
    End;
    { Reconnaitre les declarations valides dans BLOCK DATA (TK_KEYWORD) }
    If cur_tok.val = 'COMMON' Then
    Begin
      LexNext;
      If pending_id <> '' Then
      Begin
        { COMMON colle a un nom : rare, pousser le pending_id }
        { ParseCommon attend le premier / ou nom directement -> le re-injecter }
        pending_id := '';  { ignorer - COMMON seuls sont valides ici }
      End;
      ParseCommon;
    End
    Else If cur_tok.val = 'DATA' Then
    Begin LexNext; If pending_id <> '' Then pending_id := ''; ParseData; End
    Else If cur_tok.val = 'DIMENSION' Then
    Begin LexNext; If pending_id <> '' Then pending_id := ''; ParseDimension; End
    Else If cur_tok.val = 'IMPLICIT' Then
    Begin LexNext; If pending_id <> '' Then pending_id := ''; ParseImplicit; End
    Else If cur_tok.val = 'EQUIVALENCE' Then
    Begin LexNext; If pending_id <> '' Then pending_id := ''; ParseEquivalence; End
    Else If cur_tok.val = 'SAVE' Then
    Begin LexNext; If pending_id <> '' Then pending_id := ''; ParseSave; End
    Else If (cur_tok.val = 'INTEGER') Or (cur_tok.val = 'REAL') Or
            (cur_tok.val = 'LOGICAL') Or (cur_tok.val = 'DOUBLE') Or
            (cur_tok.val = 'DOUBLEPRECISION') Or
            (cur_tok.val = 'CHARACTER') Or (cur_tok.val = 'COMPLEX') Or
            (cur_tok.val = 'EXTERNAL') Or (cur_tok.val = 'INTRINSIC') Then
    Begin
      LexNext;
      pending_id := '';
      While (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Do
        LexNext;
    End
    Else If cur_tok.val = 'PARAMETER' Then
    Begin
      LexNext;
      pending_id := '';
      While (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Do
        LexNext;
    End
    Else
    Begin
      WarnMsg('Enonce non autorise dans BLOCK DATA : ' + cur_tok.val);
      pending_id := '';
      While (cur_tok.kind <> TK_NEWLINE) And (cur_tok.kind <> TK_EOF) Do
        LexNext;
    End;
    { Avancer sur la ligne suivante }
    While cur_tok.kind = TK_NEWLINE Do LexNext;
  End;
  { Reinitialiser le contexte }
  in_block_data   := False;
  block_data_name := '';
  cur_subr_name   := '';
  cur_ret_lbl     := '';
End;

{ ============================================================
  PROGRAMME PRINCIPAL (PROGRAM nom)
  ============================================================
  PROGRAM [nom] : unite principale en F77.
  Au point d'entree START (deja ecrit par GenProgramEntry), on emet :
    CALL _FP_<nom>      ; appel de la routine programme
    MOV AX, 4C00h
    INT 21h             ; epilogue DOS
  Puis le corps est traite comme une subroutine NEAR sans parametres.
  L'enonce END ferme la proc via ParseEnd (GenProcEnd).
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseProgramDecl : traiter la declaration PROGRAM [nom].
  Le mot-cle PROGRAM a deja ete consomme.
  -------------------------------------------------------------------------- }
Procedure ParseProgramDecl;
Var
  pg_name : TString;
  pi      : Integer;
Begin
  { Nom depuis pre_ident (F77 kw colle ex. "PROGRAMHELLO") ou token suivant }
  pg_name := '';
  If pre_ident <> '' Then
  Begin
    pg_name   := pre_ident;
    pre_ident := '';
  End
  Else
  Begin
    While cur_tok.kind = TK_NEWLINE Do LexNext;
    If cur_tok.kind = TK_IDENT Then
    Begin
      pg_name := cur_tok.val;
      LexNext;
    End;
  End;
  If pg_name = '' Then pg_name := 'MAIN';

  prog_name   := pg_name;
  cur_unit_kw := 'PROGRAM';

  { Enregistrer dans proc_table (pour PUBLIC + stats) }
  pi := 0;
  If proc_count < MAX_PROC Then
  Begin
    Inc(proc_count);
    pi := proc_count;
    proc_table^[pi].name        := pg_name;
    proc_table^[pi].asm_label   := FP_PFX + pg_name;
    proc_table^[pi].is_function := False;
    proc_table^[pi].ret_type    := DT_NONE;
    proc_table^[pi].param_count := 0;
  End
  Else
    ErrorMsg('Table proc saturee pour PROGRAM ' + pg_name);

  { --- Emettre au point d'entree START (cur_out = out_file ici) ---
    CALL vers la routine body + epilogue DOS }
  EmitComment('Appel du programme principal ' + pg_name);
  EmitI1('CALL', FP_PFX + pg_name);
  EmitBlank;
  EmitComment('Fin du programme principal');
  EmitI2('MOV', 'AX', '4C00h');
  EmitI0('INT 21h');
  prog_epilogue_done := True;

  { --- Corps du programme comme routine NEAR ---
    GenProcBegin emet le label + PROC NEAR + PUSH BP/SP/SI/DI }
  cur_proc_idx  := pi;
  cur_subr_name := pg_name;
  cur_ret_lbl   := GenBranchLabel;
  GenProcBegin(pg_name, 0);
End;

{ ============================================================
  RUNTIME FORTRAN 77 (_FRT_xxx)
  ============================================================
  Toutes les routines sont emises dans tmp_file (via SwitchToTmp).
  AppendTmpToOut les recopie dans out_file avant GenFileEnd.

  Conventions d'appel (toutes NEAR, appelant nettoie la pile) :
    _FRT_IPOW   : AX=base, CX=exp -> AX=resultat (pas de passe-par-pile)
    _FRT_PRINT_I : AX=entier signe -> affiche en decimal
    _FRT_PRINT_NL : () -> emet CR+LF
    _FRT_PRINT_S : AX=ptr, CX=len -> affiche CX caracteres
    _FRT_PRINT_L : AX=0->.FALSE. sinon .TRUE.
    _FRT_READ_I : () -> AX=entier lu depuis stdin
    _FRT_READ_NL : () -> vide le tampon jusqu'au retour chariot
    _FRT_SCOPY : [SP+4]=dst_addr, [SP+6]=dst_len, [SP+8]=src_addr, [SP+10]=src_len
    _FRT_SCMP  : [SP+4]=ptr1, [SP+6]=len1, [SP+8]=ptr2, [SP+10]=len2 -> AX=-1/0/1
    _FRT_SCAT  : [SP+4]=addr_g, [SP+6]=len_g, [SP+8]=addr_d, [SP+10]=len_d
                 -> AX=ptr result, CX=len combinee
    _FRT_STOP_0 : terminer avec code 0
    _FRT_STOP_N : AX=code -> afficher et terminer
    _FRT_PAUSE  : AX=code -> afficher et attendre touche
    _FRT_ITOF  : [SP+4]=entier 16 bits -> DX:AX=float IEEE 754
    _FRT_FTOI  : [SP+4]=AX_lo, [SP+6]=DX_hi (float) -> AX=entier tronque
    _FRT_FADD/_FRT_FSUB/_FRT_FMUL/_FRT_FDIV : stubs float (retournent 0)
    _FRT_FCMP  : stub comparaison float -> AX=0
    _FRT_LNBLNK : AX=ptr, CX=len -> AX=longueur sans blancs finaux
    _FRT_INDEX  : pile -> AX=position (1-base) ou 0
  ============================================================ }

{ Emettre une procedure runtime (helper interne) }
Procedure GenRuntimeRoutines;

  { Raccourcis internes }
  Procedure R(Const s : TString);
  Begin EmitRaw(s); End;

  Procedure P(Const nm : TString);
  Begin
    R('');
    R('; ' + StringOfChar('-', 60));
    R('; ' + nm);
    R('; ' + StringOfChar('-', 60));
    R(FRT_PFX + nm + '  PROC NEAR');
    R('        PUSH BP');
    R('        MOV  BP, SP');
    R('        PUSH BX');
    R('        PUSH CX');
    R('        PUSH DX');
    R('        PUSH SI');
    R('        PUSH DI');
    R('');
  End;

  Procedure EP(Const nm : TString);
  Begin
    R('');
    R('        POP  DI');
    R('        POP  SI');
    R('        POP  DX');
    R('        POP  CX');
    R('        POP  BX');
    R('        POP  BP');
    R('        RET');
    R(FRT_PFX + nm + '  ENDP');
    R('');
  End;

Begin
  SwitchToTmp;

  R('');
  R('; ============================================================');
  R('; F77C86 Runtime Library (_FRT_xxx) - 8086 NEAR mode');
  R('; ============================================================');
  R('        .CODE');
  R('');

  { ---- Donnees internes du runtime (inline .DATA) ---- }
  R('        .DATA');
  R(FRT_PFX + 'SCAT_BUF  DB  256 DUP(20h)  ; buffer interne SCAT (espaces)');
  R(FRT_PFX + 'MSG_TRUE  DB  ''.TRUE.''');
  R(FRT_PFX + 'MSG_FALSE DB  ''.FALSE.''');
  R(FRT_PFX + 'MSG_PAUSE DB  ''PAUSE'', 0Dh, 0Ah, ''$''');

  { Blocs COMMON, variables statiques et subroutines du programme }
  GenAllVarDecls(0);
  R('        .CODE');
  R('');

  { Directives PUBLIC et EXTRN }
  GenPublicDecls;
  GenExtrnDecls;

  { ============================================================ }
  { _FRT_IPOW : AX=base, CX=exp -> AX=base**exp (entier, CX modifie) }
  { ============================================================ }
  R('; --- _FRT_IPOW : AX=base, CX=exp -> AX=resultat ---');
  R(FRT_PFX + 'IPOW  PROC NEAR');
  R('        PUSH BX');
  R('        TEST CX, CX');
  R('        JG   _IPOW_pos');
  R('        MOV  AX, 1          ; exp<=0 -> return 1');
  R('        POP  BX');
  R('        RET');
  R('_IPOW_pos:');
  R('        MOV  BX, AX         ; BX = base');
  R('        MOV  AX, 1          ; AX = accumulator');
  R('_IPOW_loop:');
  R('        IMUL BX              ; DX:AX = AX * BX');
  R('        LOOP _IPOW_loop');
  R('        POP  BX');
  R('        RET');
  R(FRT_PFX + 'IPOW  ENDP');
  R('');

  { ============================================================ }
  { _FRT_PRINT_NL : emet CR+LF sur stdout (AH=02h) }
  { ============================================================ }
  R('; --- _FRT_PRINT_NL : CR+LF ---');
  R(FRT_PFX + 'PRINT_NL  PROC NEAR');
  R('        PUSH DX');
  R('        MOV  AH, 02h');
  R('        MOV  DL, 0Dh');
  R('        INT  21h');
  R('        MOV  DL, 0Ah');
  R('        INT  21h');
  R('        POP  DX');
  R('        RET');
  R(FRT_PFX + 'PRINT_NL  ENDP');
  R('');

  { ============================================================ }
  { _FRT_PRINT_I : AX=entier signe -> afficher en decimal }
  { ============================================================ }
  R('; --- _FRT_PRINT_I : AX=entier -> decimal ---');
  R(FRT_PFX + 'PRINT_I  PROC NEAR');
  R('        PUSH BX');
  R('        PUSH CX');
  R('        PUSH DX');
  R('        TEST AX, AX');
  R('        JGE  _PRI_pos');
  R('        PUSH AX');
  R('        MOV  AH, 02h');
  R('        MOV  DL, 2Dh         ; ''-''');
  R('        INT  21h');
  R('        POP  AX');
  R('        NEG  AX');
  R('_PRI_pos:');
  R('        MOV  BX, 10');
  R('        MOV  CX, 0           ; compteur de chiffres');
  R('_PRI_divl:');
  R('        XOR  DX, DX');
  R('        DIV  BX              ; AX=quot, DX=reste');
  R('        PUSH DX              ; empiler le chiffre');
  R('        INC  CX');
  R('        TEST AX, AX');
  R('        JNZ  _PRI_divl');
  R('_PRI_prtl:');
  R('        POP  DX');
  R('        ADD  DL, 30h         ; ''0''+chiffre');
  R('        MOV  AH, 02h');
  R('        INT  21h');
  R('        LOOP _PRI_prtl');
  R('        POP  DX');
  R('        POP  CX');
  R('        POP  BX');
  R('        RET');
  R(FRT_PFX + 'PRINT_I  ENDP');
  R('');

  { ============================================================ }
  { _FRT_PRINT_S : AX=ptr, CX=len -> afficher CX caracteres }
  { ============================================================ }
  R('; --- _FRT_PRINT_S : AX=ptr, CX=len -> afficher la chaine ---');
  R(FRT_PFX + 'PRINT_S  PROC NEAR');
  R('        PUSH BX');
  R('        PUSH CX');
  R('        PUSH DX');
  R('        PUSH SI');
  R('        MOV  SI, AX');
  R('        TEST CX, CX');
  R('        JZ   _PRS_done');
  R('_PRS_loop:');
  R('        MOV  DL, [SI]');
  R('        INC  SI');
  R('        MOV  AH, 02h');
  R('        INT  21h');
  R('        LOOP _PRS_loop');
  R('_PRS_done:');
  R('        POP  SI');
  R('        POP  DX');
  R('        POP  CX');
  R('        POP  BX');
  R('        RET');
  R(FRT_PFX + 'PRINT_S  ENDP');
  R('');

  { ============================================================ }
  { _FRT_PRINT_L : AX=0->'.FALSE.' sinon '.TRUE.' }
  { ============================================================ }
  R('; --- _FRT_PRINT_L : AX=0->.FALSE. sinon .TRUE. ---');
  R(FRT_PFX + 'PRINT_L  PROC NEAR');
  R('        PUSH DX');
  R('        TEST AX, AX');
  R('        JZ   _PRL_false');
  R('        ; Afficher .TRUE.');
  R('        MOV  AH, 02h');
  R('        MOV  DL, 2Eh  ; ''.'''); R('        INT  21h');
  R('        MOV  DL, 54h  ; T');   R('        INT  21h');
  R('        MOV  DL, 52h  ; R');   R('        INT  21h');
  R('        MOV  DL, 55h  ; U');   R('        INT  21h');
  R('        MOV  DL, 45h  ; E');   R('        INT  21h');
  R('        MOV  DL, 2Eh  ; ''.'''); R('        INT  21h');
  R('        JMP  _PRL_done');
  R('_PRL_false:');
  R('        MOV  AH, 02h');
  R('        MOV  DL, 2Eh  ; ''.'''); R('        INT  21h');
  R('        MOV  DL, 46h  ; F');   R('        INT  21h');
  R('        MOV  DL, 41h  ; A');   R('        INT  21h');
  R('        MOV  DL, 4Ch  ; L');   R('        INT  21h');
  R('        MOV  DL, 53h  ; S');   R('        INT  21h');
  R('        MOV  DL, 45h  ; E');   R('        INT  21h');
  R('        MOV  DL, 2Eh  ; ''.'''); R('        INT  21h');
  R('_PRL_done:');
  R('        POP  DX');
  R('        RET');
  R(FRT_PFX + 'PRINT_L  ENDP');
  R('');

  { ============================================================ }
  { _FRT_READ_I : lire un entier depuis stdin -> AX }
  { ============================================================ }
  R('; --- _FRT_READ_I : lire un entier -> AX ---');
  R(FRT_PFX + 'READ_I  PROC NEAR');
  R('        PUSH BX');
  R('        PUSH CX');
  R('        PUSH DX');
  R('        XOR  AX, AX          ; accumulateur');
  R('        MOV  BX, 1           ; signe +');
  R('; Ignorer espaces initiaux');
  R('_RDI_sp:');
  R('        MOV  AH, 08h         ; lire sans echo');
  R('        INT  21h');
  R('        MOV  DL, AL          ; echo manuel');
  R('        MOV  AH, 02h');
  R('        INT  21h');
  R('        CMP  AL, 20h');
  R('        JE   _RDI_sp');
  R('        CMP  AL, 09h         ; TAB');
  R('        JE   _RDI_sp');
  R('; Signe ?');
  R('        CMP  AL, 2Dh         ; ''-''');
  R('        JNE  _RDI_nsg');
  R('        MOV  BX, -1');
  R('        MOV  AH, 08h');
  R('        INT  21h');
  R('        MOV  DL, AL');
  R('        MOV  AH, 02h');
  R('        INT  21h');
  R('_RDI_nsg:');
  R('; Lire les chiffres');
  R('        XOR  AX, AX');
  R('        MOV  CX, 10');
  R('_RDI_dg:');
  R('        CMP  AL, 30h');
  R('        JB   _RDI_dn');
  R('        CMP  AL, 39h');
  R('        JA   _RDI_dn');
  R('        SUB  AL, 30h');
  R('        XCHG AX, DX          ; DX = AX (ancien), AX = chiffre');
  R('        PUSH AX');
  R('        MOV  AX, DX');
  R('        IMUL CX              ; DX:AX = ancien*10');
  R('        POP  DX              ; DX = chiffre');
  R('        ADD  AX, DX');
  R('        MOV  AH, 08h');
  R('        INT  21h');
  R('        MOV  DL, AL');
  R('        PUSH AX');
  R('        MOV  AH, 02h');
  R('        INT  21h');
  R('        POP  AX');
  R('        JMP  _RDI_dg');
  R('_RDI_dn:');
  R('        IMUL BX              ; appliquer le signe');
  R('        POP  DX');
  R('        POP  CX');
  R('        POP  BX');
  R('        RET');
  R(FRT_PFX + 'READ_I  ENDP');
  R('');

  { ============================================================ }
  { _FRT_READ_NL : vider l'entree jusqu'au prochain CR }
  { ============================================================ }
  R('; --- _FRT_READ_NL : vider tampon -> CR ---');
  R(FRT_PFX + 'READ_NL  PROC NEAR');
  R('        PUSH AX');
  R('        PUSH DX');
  R('_RNLI_loop:');
  R('        MOV  AH, 08h');
  R('        INT  21h');
  R('        CMP  AL, 0Dh');
  R('        JNE  _RNLI_loop');
  R('        POP  DX');
  R('        POP  AX');
  R('        RET');
  R(FRT_PFX + 'READ_NL  ENDP');
  R('');

  { ============================================================ }
  { _FRT_SCOPY : copier src dans dst avec troncature/blanc-remplissage }
  { Convention pile (NEAR, BP-relative) :                          }
  {   [BP+4]=dst_addr, [BP+6]=dst_len, [BP+8]=src_addr, [BP+10]=src_len }
  { ============================================================ }
  R('; --- _FRT_SCOPY(dst_addr,dst_len,src_addr,src_len) ---');
  R(FRT_PFX + 'SCOPY  PROC NEAR');
  R('        PUSH BP');
  R('        MOV  BP, SP');
  R('        PUSH BX');
  R('        PUSH CX');
  R('        PUSH DX');
  R('        PUSH SI');
  R('        PUSH DI');
  R('        MOV  DI, WORD PTR [BP+4]  ; dst_addr');
  R('        MOV  CX, WORD PTR [BP+6]  ; dst_len');
  R('        MOV  SI, WORD PTR [BP+8]  ; src_addr');
  R('        MOV  BX, WORD PTR [BP+10] ; src_len');
  R('        TEST CX, CX');
  R('        JZ   _SCPY_done');
  R('_SCPY_loop:');
  R('        TEST BX, BX');
  R('        JZ   _SCPY_pad');
  R('        MOV  AL, [SI]');
  R('        INC  SI');
  R('        DEC  BX');
  R('        JMP  _SCPY_wr');
  R('_SCPY_pad:');
  R('        MOV  AL, 20h           ; espace');
  R('_SCPY_wr:');
  R('        MOV  [DI], AL');
  R('        INC  DI');
  R('        LOOP _SCPY_loop');
  R('_SCPY_done:');
  R('        POP  DI');
  R('        POP  SI');
  R('        POP  DX');
  R('        POP  CX');
  R('        POP  BX');
  R('        POP  BP');
  R('        RET');
  R(FRT_PFX + 'SCOPY  ENDP');
  R('');

  { ============================================================ }
  { _FRT_SCMP : comparer deux chaines Fortran -> AX=-1/0/+1       }
  { [BP+4]=ptr1,[BP+6]=len1,[BP+8]=ptr2,[BP+10]=len2              }
  { ============================================================ }
  R('; --- _FRT_SCMP(ptr1,len1,ptr2,len2) -> AX ---');
  R(FRT_PFX + 'SCMP  PROC NEAR');
  R('        PUSH BP');
  R('        MOV  BP, SP');
  R('        PUSH BX');
  R('        PUSH CX');
  R('        PUSH DX');
  R('        PUSH SI');
  R('        PUSH DI');
  R('        MOV  SI, WORD PTR [BP+4]   ; ptr1');
  R('        MOV  CX, WORD PTR [BP+6]   ; len1');
  R('        MOV  DI, WORD PTR [BP+8]   ; ptr2');
  R('        MOV  DX, WORD PTR [BP+10]  ; len2');
  R('; Comparer min(len1,len2) caracteres');
  R('        MOV  BX, CX');
  R('        CMP  BX, DX');
  R('        JBE  _SCM_mc');
  R('        MOV  BX, DX');
  R('_SCM_mc:');
  R('        TEST BX, BX');
  R('        JZ   _SCM_rest');
  R('_SCM_loop:');
  R('        MOV  AL, [SI]');
  R('        MOV  AH, [DI]');
  R('        INC  SI');
  R('        INC  DI');
  R('        CMP  AL, AH');
  R('        JB   _SCM_lt');
  R('        JA   _SCM_gt');
  R('        DEC  BX');
  R('        JNZ  _SCM_loop');
  R('_SCM_rest:');
  R('; Chaines egales sur min(len) : comparer les longueurs');
  R('        CMP  CX, DX');
  R('        JB   _SCM_lt');
  R('        JA   _SCM_gt');
  R('        XOR  AX, AX');
  R('        JMP  _SCM_done');
  R('_SCM_lt:');
  R('        MOV  AX, -1');
  R('        JMP  _SCM_done');
  R('_SCM_gt:');
  R('        MOV  AX, 1');
  R('_SCM_done:');
  R('        POP  DI');
  R('        POP  SI');
  R('        POP  DX');
  R('        POP  CX');
  R('        POP  BX');
  R('        POP  BP');
  R('        RET');
  R(FRT_PFX + 'SCMP  ENDP');
  R('');

  { ============================================================ }
  { _FRT_SCAT : concatener deux chaines dans un buffer interne     }
  { [BP+4]=addr_g,[BP+6]=len_g,[BP+8]=addr_d,[BP+10]=len_d        }
  { -> AX=_FRT_SCAT_BUF, CX=len_g+len_d                           }
  { ============================================================ }
  R('; --- _FRT_SCAT(addr_g,len_g,addr_d,len_d) -> AX=buf,CX=len ---');
  R(FRT_PFX + 'SCAT  PROC NEAR');
  R('        PUSH BP');
  R('        MOV  BP, SP');
  R('        PUSH BX');
  R('        PUSH DX');
  R('        PUSH SI');
  R('        PUSH DI');
  R('        MOV  DI, OFFSET ' + FRT_PFX + 'SCAT_BUF');
  R('        MOV  SI, WORD PTR [BP+4]   ; addr_g');
  R('        MOV  CX, WORD PTR [BP+6]   ; len_g');
  R('        MOV  BX, WORD PTR [BP+8]   ; addr_d');
  R('        MOV  DX, WORD PTR [BP+10]  ; len_d');
  R('; Copier gauche');
  R('        PUSH CX');
  R('        TEST CX, CX');
  R('        JZ   _SCAT_d');
  R('_SCAT_gl:');
  R('        MOV  AL, [SI]');
  R('        MOV  [DI], AL');
  R('        INC  SI');
  R('        INC  DI');
  R('        LOOP _SCAT_gl');
  R('_SCAT_d:');
  R('; Copier droite');
  R('        MOV  SI, BX');
  R('        MOV  CX, DX');
  R('        TEST CX, CX');
  R('        JZ   _SCAT_fin');
  R('_SCAT_dr:');
  R('        MOV  AL, [SI]');
  R('        MOV  [DI], AL');
  R('        INC  SI');
  R('        INC  DI');
  R('        LOOP _SCAT_dr');
  R('_SCAT_fin:');
  R('        POP  CX              ; CX = len_g');
  R('        ADD  CX, DX          ; CX = len_g + len_d');
  R('        MOV  AX, OFFSET ' + FRT_PFX + 'SCAT_BUF');
  R('        POP  DI');
  R('        POP  SI');
  R('        POP  DX');
  R('        POP  BX');
  R('        POP  BP');
  R('        RET');
  R(FRT_PFX + 'SCAT  ENDP');
  R('');

  { ============================================================ }
  { _FRT_STOP_0 : arreter le programme (exit code 0) }
  { ============================================================ }
  R('; --- _FRT_STOP_0 : exit code 0 ---');
  R(FRT_PFX + 'STOP_0  PROC NEAR');
  R('        MOV  AX, 4C00h');
  R('        INT  21h');
  R(FRT_PFX + 'STOP_0  ENDP');
  R('');

  { ============================================================ }
  { _FRT_STOP_N : AX=code -> afficher puis sortir }
  { ============================================================ }
  R('; --- _FRT_STOP_N : AX=n, afficher puis exit ---');
  R(FRT_PFX + 'STOP_N  PROC NEAR');
  R('        PUSH AX');
  R('        CALL ' + FRT_PFX + 'PRINT_I');
  R('        CALL ' + FRT_PFX + 'PRINT_NL');
  R('        POP  AX');
  R('        MOV  AH, 4Ch');
  R('        INT  21h');
  R(FRT_PFX + 'STOP_N  ENDP');
  R('');

  { ============================================================ }
  { _FRT_PAUSE : AX=code -> afficher ''PAUSE'', attendre touche }
  { ============================================================ }
  R('; --- _FRT_PAUSE : AX=code, afficher et attendre ---');
  R(FRT_PFX + 'PAUSE  PROC NEAR');
  R('        PUSH DX');
  R('        TEST AX, AX');
  R('        JZ   _PAUSE_nn');
  R('        PUSH AX');
  R('        CALL ' + FRT_PFX + 'PRINT_I');
  R('        CALL ' + FRT_PFX + 'PRINT_NL');
  R('        POP  AX');
  R('_PAUSE_nn:');
  R('        MOV  AH, 09h');
  R('        MOV  DX, OFFSET ' + FRT_PFX + 'MSG_PAUSE');
  R('        INT  21h            ; afficher PAUSE');
  R('        MOV  AH, 08h');
  R('        INT  21h            ; attendre touche');
  R('        POP  DX');
  R('        RET');
  R(FRT_PFX + 'PAUSE  ENDP');
  R('');

  { ============================================================ }
  { _FRT_ITOF : [SP+4]=entier 16 bits -> DX:AX = float IEEE 754  }
  { ============================================================ }
  R('; --- _FRT_ITOF : [SP+4]=int16 -> DX:AX=float32 ---');
  R(FRT_PFX + 'ITOF  PROC NEAR');
  R('        PUSH BP');
  R('        MOV  BP, SP');
  R('        PUSH BX');
  R('        PUSH CX');
  R('        PUSH SI');
  R('        MOV  AX, WORD PTR [BP+4]   ; AX = entier');
  R('        XOR  SI, SI');
  R('        TEST AX, AX');
  R('        JNZ  _ITOF_nz');
  R('        XOR  DX, DX           ; return 0.0');
  R('        JMP  _ITOF_done');
  R('_ITOF_nz:');
  R('        JGE  _ITOF_pos');
  R('        MOV  SI, 8000h        ; bit signe negatif');
  R('        NEG  AX');
  R('_ITOF_pos:');
  R('; Normaliser : decaler gauche jusqu''a bit 15 = 1');
  R('        MOV  CX, 0');
  R('_ITOF_norm:');
  R('        TEST AX, 8000h');
  R('        JNZ  _ITOF_normed');
  R('        SHL  AX, 1');
  R('        INC  CX');
  R('        JMP  _ITOF_norm');
  R('_ITOF_normed:');
  R('; AX=norme, CX=nb decalages, exp=142-CX');
  R('        PUSH AX              ; sauver valeur normalisee');
  R('        MOV  DX, 142');
  R('        SUB  DX, CX          ; DX = exposant');
  R('        MOV  BX, 7');
  R('        MOV  CL, BL          ; CL = 7');
  R('        SHL  DX, CL          ; DX = exp << 7 (bits [14:7])');
  R('        POP  AX              ; AX = valeur normalisee');
  R('        PUSH AX');
  R('        MOV  BX, AX');
  R('        MOV  CL, 8');
  R('        SHR  BX, CL          ; BX = AX >> 8 = N[15:8]');
  R('        AND  BX, 007Fh       ; BX = N[14:8] (7 bits mantisse haute)');
  R('        OR   DX, BX          ; DX |= mantisse haute');
  R('        OR   DX, SI          ; DX |= bit signe');
  R('; AX = (N[7:0]) << 8');
  R('        POP  AX');
  R('        AND  AX, 00FFh       ; AX = N[7:0]');
  R('        MOV  AH, AL          ; AH = N[7:0]');
  R('        XOR  AL, AL          ; AL = 0');
  R('_ITOF_done:');
  R('        POP  SI');
  R('        POP  CX');
  R('        POP  BX');
  R('        POP  BP');
  R('        RET');
  R(FRT_PFX + 'ITOF  ENDP');
  R('');

  { ============================================================ }
  { _FRT_FTOI : [SP+4]=AX_lo,[SP+6]=DX_hi -> AX = entier tronque }
  { ============================================================ }
  R('; --- _FRT_FTOI : [SP+4]=lo,[SP+6]=hi -> AX=int16 ---');
  R(FRT_PFX + 'FTOI  PROC NEAR');
  R('        PUSH BP');
  R('        MOV  BP, SP');
  R('        PUSH BX');
  R('        PUSH CX');
  R('        PUSH DX');
  R('        PUSH SI');
  R('        MOV  DX, WORD PTR [BP+6]   ; DX = mot haut du float');
  R('        MOV  AX, WORD PTR [BP+4]   ; AX = mot bas');
  R('        MOV  SI, DX');
  R('        AND  SI, 8000h             ; SI = bit signe');
  R('; Extraire exposant : DX[14:7]');
  R('        MOV  BX, DX');
  R('        AND  BX, 7F80h');
  R('        MOV  CL, 7');
  R('        SHR  BX, CL                ; BX = exposant biais');
  R('        CMP  BX, 127');
  R('        JB   _FTOI_zero            ; |val| < 1 -> 0');
  R('        CMP  BX, 142');
  R('        JA   _FTOI_ovfl            ; > 32767 -> saturer');
  R('; Reconstituer la mantisse avec bit implicite');
  R('        AND  DX, 007Fh');
  R('        OR   DX, 0080h             ; DX[7:0] = mantisse[23:16] avec bit implicite');
  R('        SUB  BX, 127               ; BX = exposant reel (0..15)');
  R('; Construire {DX[7:0],AX[15:8]} dans CX');
  R('        PUSH BX');
  R('        MOV  CL, 8');
  R('        SHL  DX, CL                ; DX = DX[7:0] << 8');
  R('        SHR  AX, CL                ; AX = AX[15:8]');
  R('        OR   DX, AX                ; DX = {mantisse[23:16],mantisse[15:8]}');
  R('; Decaler droite de (15-exp) positions');
  R('        POP  BX');
  R('        MOV  CX, 15');
  R('        SUB  CX, BX                ; CX = 15-exp');
  R('        JZ   _FTOI_ns');
  R('        MOV  CL, CL');
  R('_FTOI_shr:');
  R('        SHR  DX, 1');
  R('        LOOP _FTOI_shr');
  R('_FTOI_ns:');
  R('        MOV  AX, DX');
  R('        TEST SI, SI');
  R('        JZ   _FTOI_done');
  R('        NEG  AX');
  R('        JMP  _FTOI_done');
  R('_FTOI_zero:');
  R('        XOR  AX, AX');
  R('        JMP  _FTOI_done');
  R('_FTOI_ovfl:');
  R('        TEST SI, SI');
  R('        JZ   _FTOI_op');
  R('        MOV  AX, 8000h');
  R('        JMP  _FTOI_done');
  R('_FTOI_op:');
  R('        MOV  AX, 7FFFh');
  R('_FTOI_done:');
  R('        POP  SI');
  R('        POP  DX');
  R('        POP  CX');
  R('        POP  BX');
  R('        POP  BP');
  R('        RET');
  R(FRT_PFX + 'FTOI  ENDP');
  R('');

  { ============================================================ }
  { Operations float - STUBS (retournent 0 ou AX) }
  { Convention : gauche=[SP+4..6], droite=[SP+8..10] -> DX:AX }
  { ============================================================ }
  R('; --- _FRT_FADD / FSUB / FMUL / FDIV / FCMP : stubs ---');
  R(FRT_PFX + 'FADD  PROC NEAR');
  R('        MOV  AX, WORD PTR [SP+4]');
  R('        MOV  DX, WORD PTR [SP+6]');
  R('        RET');
  R(FRT_PFX + 'FADD  ENDP');
  R('');
  R(FRT_PFX + 'FSUB  PROC NEAR');
  R('        MOV  AX, WORD PTR [SP+4]');
  R('        MOV  DX, WORD PTR [SP+6]');
  R('        RET');
  R(FRT_PFX + 'FSUB  ENDP');
  R('');
  R(FRT_PFX + 'FMUL  PROC NEAR');
  R('        XOR  AX, AX');
  R('        XOR  DX, DX');
  R('        RET');
  R(FRT_PFX + 'FMUL  ENDP');
  R('');
  R(FRT_PFX + 'FDIV  PROC NEAR');
  R('        XOR  AX, AX');
  R('        XOR  DX, DX');
  R('        RET');
  R(FRT_PFX + 'FDIV  ENDP');
  R('');
  R(FRT_PFX + 'FCMP  PROC NEAR');
  R('        XOR  AX, AX');
  R('        RET');
  R(FRT_PFX + 'FCMP  ENDP');
  R('');
  R(FRT_PFX + 'FMOD  PROC NEAR');
  R('        XOR  AX, AX');
  R('        XOR  DX, DX');
  R('        RET');
  R(FRT_PFX + 'FMOD  ENDP');
  R('');
  R(FRT_PFX + 'FDIM  PROC NEAR');
  R('        XOR  AX, AX');
  R('        XOR  DX, DX');
  R('        RET');
  R(FRT_PFX + 'FDIM  ENDP');
  R('');
  R(FRT_PFX + 'FSIGN PROC NEAR');
  R('        MOV  AX, WORD PTR [SP+4]');
  R('        MOV  DX, WORD PTR [SP+6]');
  R('        RET');
  R(FRT_PFX + 'FSIGN ENDP');
  R('');
  R(FRT_PFX + 'FMIN  PROC NEAR');
  R('        MOV  AX, WORD PTR [SP+4]');
  R('        MOV  DX, WORD PTR [SP+6]');
  R('        RET');
  R(FRT_PFX + 'FMIN  ENDP');
  R('');
  R(FRT_PFX + 'FMAX  PROC NEAR');
  R('        MOV  AX, WORD PTR [SP+4]');
  R('        MOV  DX, WORD PTR [SP+6]');
  R('        RET');
  R(FRT_PFX + 'FMAX  ENDP');
  R('');
  { Stubs trig/transcendantales -> 0 }
  R(FRT_PFX + 'SQRT  PROC NEAR'); R('        XOR AX,AX'); R('        XOR DX,DX'); R('        RET'); R(FRT_PFX + 'SQRT  ENDP'); R('');
  R(FRT_PFX + 'EXP   PROC NEAR'); R('        XOR AX,AX'); R('        XOR DX,DX'); R('        RET'); R(FRT_PFX + 'EXP   ENDP'); R('');
  R(FRT_PFX + 'LOG   PROC NEAR'); R('        XOR AX,AX'); R('        XOR DX,DX'); R('        RET'); R(FRT_PFX + 'LOG   ENDP'); R('');
  R(FRT_PFX + 'LOG10 PROC NEAR'); R('        XOR AX,AX'); R('        XOR DX,DX'); R('        RET'); R(FRT_PFX + 'LOG10 ENDP'); R('');
  R(FRT_PFX + 'SIN   PROC NEAR'); R('        XOR AX,AX'); R('        XOR DX,DX'); R('        RET'); R(FRT_PFX + 'SIN   ENDP'); R('');
  R(FRT_PFX + 'COS   PROC NEAR'); R('        XOR AX,AX'); R('        XOR DX,DX'); R('        RET'); R(FRT_PFX + 'COS   ENDP'); R('');
  R(FRT_PFX + 'TAN   PROC NEAR'); R('        XOR AX,AX'); R('        XOR DX,DX'); R('        RET'); R(FRT_PFX + 'TAN   ENDP'); R('');
  R(FRT_PFX + 'ASIN  PROC NEAR'); R('        XOR AX,AX'); R('        XOR DX,DX'); R('        RET'); R(FRT_PFX + 'ASIN  ENDP'); R('');
  R(FRT_PFX + 'ACOS  PROC NEAR'); R('        XOR AX,AX'); R('        XOR DX,DX'); R('        RET'); R(FRT_PFX + 'ACOS  ENDP'); R('');
  R(FRT_PFX + 'ATAN  PROC NEAR'); R('        XOR AX,AX'); R('        XOR DX,DX'); R('        RET'); R(FRT_PFX + 'ATAN  ENDP'); R('');
  R(FRT_PFX + 'ATAN2 PROC NEAR'); R('        XOR AX,AX'); R('        XOR DX,DX'); R('        RET'); R(FRT_PFX + 'ATAN2 ENDP'); R('');
  R(FRT_PFX + 'SINH  PROC NEAR'); R('        XOR AX,AX'); R('        XOR DX,DX'); R('        RET'); R(FRT_PFX + 'SINH  ENDP'); R('');
  R(FRT_PFX + 'COSH  PROC NEAR'); R('        XOR AX,AX'); R('        XOR DX,DX'); R('        RET'); R(FRT_PFX + 'COSH  ENDP'); R('');
  R(FRT_PFX + 'TANH  PROC NEAR'); R('        XOR AX,AX'); R('        XOR DX,DX'); R('        RET'); R(FRT_PFX + 'TANH  ENDP'); R('');

  { ============================================================ }
  { _FRT_LNBLNK : AX=ptr, CX=len -> AX=longueur sans blancs finaux }
  { ============================================================ }
  R('; --- _FRT_LNBLNK : AX=ptr, CX=len -> AX=longueur effective ---');
  R(FRT_PFX + 'LNBLNK  PROC NEAR');
  R('        PUSH BX');
  R('        PUSH SI');
  R('        MOV  SI, AX');
  R('        ADD  SI, CX          ; SI = ptr + len (apres la fin)');
  R('        DEC  SI              ; SI = ptr + len - 1 (dernier char)');
  R('        MOV  BX, CX          ; BX = longueur courante');
  R('_LNB_loop:');
  R('        TEST BX, BX');
  R('        JZ   _LNB_done');
  R('        CMP  BYTE PTR [SI], 20h');
  R('        JNE  _LNB_done');
  R('        DEC  SI');
  R('        DEC  BX');
  R('        JMP  _LNB_loop');
  R('_LNB_done:');
  R('        MOV  AX, BX');
  R('        POP  SI');
  R('        POP  BX');
  R('        RET');
  R(FRT_PFX + 'LNBLNK  ENDP');
  R('');

  { ============================================================ }
  { _FRT_INDEX : [SP+4]=ptr_s,[SP+6]=len_s,[SP+8]=ptr_p,[SP+10]=len_p -> AX }
  { ============================================================ }
  R('; --- _FRT_INDEX(s,ls,p,lp) -> AX=position (1-base) ou 0 ---');
  R(FRT_PFX + 'INDEX  PROC NEAR');
  R('        PUSH BP');
  R('        MOV  BP, SP');
  R('        PUSH BX');
  R('        PUSH CX');
  R('        PUSH DX');
  R('        PUSH SI');
  R('        PUSH DI');
  R('        MOV  SI, WORD PTR [BP+4]   ; ptr_s');
  R('        MOV  CX, WORD PTR [BP+6]   ; len_s');
  R('        MOV  DI, WORD PTR [BP+8]   ; ptr_p');
  R('        MOV  DX, WORD PTR [BP+10]  ; len_p');
  R('        XOR  AX, AX               ; resultat = 0 (non trouve)');
  R('        TEST DX, DX');
  R('        JZ   _IDX_done             ; pattern vide -> 0');
  R('        MOV  BX, 0                 ; position courante (0-base)');
  R('_IDX_outer:');
  R('        MOV  AX, CX');
  R('        SUB  AX, BX');
  R('        CMP  AX, DX');
  R('        JB   _IDX_nf              ; plus assez de chars');
  R('        PUSH SI');
  R('        PUSH DI');
  R('        PUSH BX');
  R('        PUSH CX');
  R('        MOV  SI, WORD PTR [BP+4]');
  R('        ADD  SI, BX               ; SI = ptr_s + pos');
  R('        MOV  DI, WORD PTR [BP+8]');
  R('        MOV  CX, DX');
  R('_IDX_inner:');
  R('        MOV  AL, [SI]');
  R('        CMP  AL, [DI]');
  R('        JNE  _IDX_mism');
  R('        INC  SI');
  R('        INC  DI');
  R('        LOOP _IDX_inner');
  R('        POP  CX');
  R('        POP  BX');
  R('        POP  DI');
  R('        POP  SI');
  R('        MOV  AX, BX');
  R('        INC  AX                   ; convertir en 1-base');
  R('        JMP  _IDX_done');
  R('_IDX_mism:');
  R('        POP  CX');
  R('        POP  BX');
  R('        POP  DI');
  R('        POP  SI');
  R('        INC  BX');
  R('        JMP  _IDX_outer');
  R('_IDX_nf:');
  R('        XOR  AX, AX');
  R('_IDX_done:');
  R('        POP  DI');
  R('        POP  SI');
  R('        POP  DX');
  R('        POP  CX');
  R('        POP  BX');
  R('        POP  BP');
  R('        RET');
  R(FRT_PFX + 'INDEX  ENDP');
  R('');

  R('; ============================================================');
  R('; Fin du runtime F77C86');
  R('; ============================================================');

  SwitchToMain;
End;

{ ============================================================
  Programme principal
  ============================================================ }

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('F77C86 - Cette commande permet de lancer le compilateur Fortran 77 pour l''assembleur de ',
          'microprocesseur 8086');
  WriteLn;
  Writeln('Syntaxe : F77C86 [options] source.f [sortie.asm]');
  WriteLn;
  Writeln('Options :');
  Writeln('  -v     : mode verbeux (afficher les etapes)');
  Writeln('  -d     : mode debogage (commentaires supplementaires)');
  Writeln('  -nr    : ne pas emettre le runtime FRT dans le .ASM');
  Writeln('  -h     : afficher cette aide');
  Writeln('Source : fichier .F ou .F77 en format fixe Fortran 77');
  Writeln('Sortie : fichier .ASM au format MASM/TASM, modele SMALL');
  Halt(0);
 End;
 InitTables;
 ParseArgs;
 OpenFiles;
 Writeln('F77C86 v', F77_VERSION, ' - Compilation de ', src_fname);
  { Phase 1 : Entete ASM + segments vides }
 GenProgramHeader;
 GenDataSegBegin;
 GenDataSegEnd;
 GenCodeSegBegin;
 GenProgramEntry;
  { Phase 2 : Parser le source F77 }
 LexInit;
 Repeat
  While cur_tok.kind = TK_NEWLINE Do LexNext;
  If cur_tok.kind = TK_EOF Then Break;
  ParseStatement;
 Until cur_tok.kind = TK_EOF;
  { Si le source n'avait pas d'enonce END pour le programme principal }
 If Not prog_epilogue_done Then GenProgramEpilogue;
  { Phase 3 : Emettre les routines runtime dans tmp_file }
 GenRuntimeRoutines;
  { Phase 4 : Fusionner tmp_file dans out_file (subroutines + runtime) }
 AppendTmpToOut;
  { Phase 5 : Directive de fin de fichier ASM }
 GenFileEnd('START');
 CloseFiles;
 Writeln('Compilation terminee : ', err_count, ' erreur(s), ',
         warn_count, ' avertissement(s).');
 Writeln('Statistiques         : ', phys_lines, ' ligne(s) F77, ',
         sym_count,  ' symbole(s), ',
         lbl_count,  ' etiquette(s) F77, ',
         proc_count, ' procedure(s).');
 If err_count > 0 Then Halt(1);
END.
