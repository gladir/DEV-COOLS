{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Clone de Motorola Macro Assembler (ASM68)
                Assembleur pour la famille Motorola 68000
                Genere du code objet S-Record a partir de sources assembleur 68000
}

{ ---------------------------------------------------------------------------- }
{  ARCHITECTURE GENERALE                                                       }
{ ---------------------------------------------------------------------------- }
{  1. Lexeur    : SrcGetLine, NextToken -> cur_tok / cur_tok_str               }
{  2. Parser    : ParseLine -> etiquette, opcode, operandes                    }
{  3. CodeGen   : Emit8, Emit16, Emit32 -> buffer section (big-endian)        }
{  4. Symboles  : sym_table (etiquettes, EQU, SET, XDEF, XREF)               }
{  5. Assemble  : deux passes -> resolution symboles puis generation code      }
{  6. Sortie    : fichier objet S-Record Motorola, listing optionnel           }
{ ---------------------------------------------------------------------------- }

{ TODO 01 - Infrastructure, options de ligne de commande et constantes [IMPLEMENTE] }
{ TODO 02 - Lexeur : lecture source et tokenisation [IMPLEMENTE] }
{ TODO 03 - Gestion des erreurs, avertissements et listing [IMPLEMENTE] }
{ TODO 04 - Table des symboles : etiquettes, EQU, SET [IMPLEMENTE] }
{ TODO 05 - Analyseur d'expressions arithmetiques [IMPLEMENTE] }
{ TODO 06 - Modes d'adressage : analyse et encodage [IMPLEMENTE] }
{ TODO 07 - Generateur de code : emission et sections [IMPLEMENTE] }
{ TODO 08 - Directives assembleur de base (ORG, DC, DS, EQU, END) [IMPLEMENTE] }
{ TODO 09 - Directives assembleur avancees (SECTION, INCLUDE, macros) [IMPLEMENTE] }
{ TODO 10 - Assemblage conditionnel (IF, IFDEF, IFEQ, etc.) [IMPLEMENTE] }
{ TODO 11 - Instructions de transfert de donnees [IMPLEMENTE] }
{ TODO 12 - Instructions arithmetiques entieres [IMPLEMENTE] }
{ TODO 13 - Instructions logiques et de manipulation de bits [IMPLEMENTE] }
{ TODO 14 - Instructions de decalage et rotation [IMPLEMENTE] }
{ TODO 15 - Instructions de branchement et controle de flux [IMPLEMENTE] }
{ TODO 16 - Instructions BCD et operations speciales [IMPLEMENTE] }
{ TODO 17 - Encodage binaire des instructions (passe 2) [IMPLEMENTE] }
{ TODO 18 - Architecture deux passes de l'assembleur }
{ TODO 19 - Parseur de ligne assembleur }
{ TODO 20 - Generation du fichier objet (format S-Record Motorola) }
{ TODO 21 - Gestion des fichiers INCLUDE et pile de sources }
{ TODO 22 - Gestion des macros (MACRO/ENDM) }
{ TODO 23 - Directives de listing et mise en page }
{ TODO 24 - Programme principal et orchestration complete }
{ TODO 25 - Programmes de test et validation (SAMPLES\ASM68\) }

Program ASM68;

{$A-}
{$I-}

{ ============================================================================ }
{ TODO 01 - Infrastructure, options de ligne de commande et constantes         }
{ ============================================================================ }

Const

  { ------------------------------------------------------------------ }
  { Limites des tables (dimensionnement)                                }
  { ------------------------------------------------------------------ }
  MAX_SYM           = 2048;   { Symboles max (etiquettes + EQU + SET)  }
  MAX_LABEL         = 9999;   { Limite compteur labels internes        }
  MAX_MACRO         = 256;    { Macros max                             }
  MAX_MACRO_LINES   = 256;    { Lignes max dans le corps d'une macro   }
  MAX_MACRO_PARAMS  = 16;     { Parametres max par macro               }
  MAX_INC_LINES     = 2048;   { Lignes max d'un fichier INCLUDE        }
  MAX_LINE          = 1024;   { Longueur max d'une ligne source        }
  MAX_INCLUDE_DEPTH = 8;      { Profondeur max d'imbrication INCLUDE   }
  MAX_SECTIONS      = 16;     { Sections max                           }
  MAX_FIXUP         = 4096;   { Fixups max (references a resoudre)     }
  MAX_EXPR_DEPTH    = 32;     { Profondeur max d'expression            }
  MAX_DEF_SYMS      = 32;     { Symboles predefinis max (-d)           }
  MAX_COND_DEPTH    = 32;     { Profondeur max d'imbrication IF        }
  MAX_INC_PATHS     = 16;     { Repertoires INCLUDE max (-i)           }
  MAX_SEC_SIZE      = 65536;  { Taille max d'une section en octets     }
  MAX_ERRORS        = 100;    { Erreurs max avant arret                }
  MAX_LIST_BYTES    = 6;      { Octets max affiches par ligne listing  }
  LIST_PAGE_SIZE    = 60;     { Lignes par page dans le listing        }

  { ------------------------------------------------------------------ }
  { Tailles d'operande (suffixes .B, .W, .L)                           }
  { ------------------------------------------------------------------ }
  SIZE_BYTE = 1;              { .B  - octet (8 bits)                   }
  SIZE_WORD = 2;              { .W  - mot (16 bits, defaut)            }
  SIZE_LONG = 4;              { .L  - long mot (32 bits)               }

  { ------------------------------------------------------------------ }
  { Registres du 68000                                                  }
  { ------------------------------------------------------------------ }
  { Registres de donnees D0-D7 }
  REG_D0 =  0;
  REG_D1 =  1;
  REG_D2 =  2;
  REG_D3 =  3;
  REG_D4 =  4;
  REG_D5 =  5;
  REG_D6 =  6;
  REG_D7 =  7;
  { Registres d'adresses A0-A7 (A7 = SP) }
  REG_A0 =  8;
  REG_A1 =  9;
  REG_A2 = 10;
  REG_A3 = 11;
  REG_A4 = 12;
  REG_A5 = 13;
  REG_A6 = 14;
  REG_A7 = 15;             { Stack Pointer (SP)                        }
  { Registres speciaux }
  REG_PC  = 16;             { Program Counter                          }
  REG_SR  = 17;             { Status Register (complet 16 bits)        }
  REG_CCR = 18;             { Condition Code Register (octet bas SR)   }
  REG_USP = 19;             { User Stack Pointer                       }
  REG_SSP = 20;             { Supervisor Stack Pointer                 }
  REG_NONE = -1;            { Pas de registre                          }

  { ------------------------------------------------------------------ }
  { Modes d'adressage du 68000 (14 modes)                              }
  { ------------------------------------------------------------------ }
  AM_NONE          =  0;    { Pas de mode (implicite)                  }
  AM_DATA_REG      =  1;    { Dn           (mode 000, reg n)           }
  AM_ADDR_REG      =  2;    { An           (mode 001, reg n)           }
  AM_ADDR_IND      =  3;    { (An)         (mode 010, reg n)           }
  AM_ADDR_IND_POST =  4;    { (An)+        (mode 011, reg n)           }
  AM_ADDR_IND_PRE  =  5;    { -(An)        (mode 100, reg n)           }
  AM_ADDR_IND_DISP =  6;    { d16(An)      (mode 101, reg n)           }
  AM_ADDR_IND_IDX  =  7;    { d8(An,Xn.s)  (mode 110, reg n)          }
  AM_ABS_SHORT     =  8;    { xxx.W        (mode 111, reg 000)         }
  AM_ABS_LONG      =  9;    { xxx.L        (mode 111, reg 001)         }
  AM_PC_DISP       = 10;    { d16(PC)      (mode 111, reg 010)         }
  AM_PC_IDX        = 11;    { d8(PC,Xn.s)  (mode 111, reg 011)        }
  AM_IMMEDIATE     = 12;    { #imm         (mode 111, reg 100)         }
  AM_REG_LIST      = 13;    { D0-D3/A0-A2  (pour MOVEM)               }
  AM_SR_CCR        = 14;    { SR ou CCR    (registre d'etat)           }

  { ------------------------------------------------------------------ }
  { Types de tokens                                                     }
  { ------------------------------------------------------------------ }
  TOK_UNKNOWN   =  0;
  TOK_IDENT     =  1;       { Identifiant                              }
  TOK_INTEGER   =  2;       { Litteral entier (dec, hex, oct, bin)     }
  TOK_STRING    =  3;       { Chaine entre apostrophes '...'           }
  TOK_CHAR      =  4;       { Caractere isole 'x'                     }
  TOK_REGISTER  =  5;       { Registre (D0-D7, A0-A7, SP, PC, etc.)  }
  TOK_OPCODE    =  6;       { Mnemonique d'instruction 68000           }
  TOK_DIRECTIVE =  7;       { Directive assembleur (ORG, DC, etc.)    }
  TOK_LABEL     =  8;       { Etiquette (identifiant suivi de ':')    }
  TOK_COMMA     =  9;       { ,                                        }
  TOK_LPAREN    = 10;       { (                                        }
  TOK_RPAREN    = 11;       { )                                        }
  TOK_PLUS      = 12;       { +                                        }
  TOK_MINUS     = 13;       { -                                        }
  TOK_STAR      = 14;       { *                                        }
  TOK_SLASH     = 15;       { /                                        }
  TOK_HASH      = 16;       { #                                        }
  TOK_DOT       = 17;       { .                                        }
  TOK_COLON     = 18;       { :                                        }
  TOK_EQUAL     = 19;       { =                                        }
  TOK_EOL       = 20;       { Fin de ligne                             }
  TOK_AMPERSAND = 21;       { &                                        }
  TOK_PIPE      = 22;       { |                                        }
  TOK_CARET     = 23;       { ^                                        }
  TOK_PERCENT   = 24;       { %  (modulo dans expressions)             }
  TOK_TILDE     = 25;       { ~  (complement bit a bit)                }
  TOK_LSHIFT    = 26;       { << (decalage gauche)                     }
  TOK_RSHIFT    = 27;       { >> (decalage droite)                     }
  TOK_EOF       = 99;       { Fin de fichier                           }

  { ------------------------------------------------------------------ }
  { Types d'erreur                                                      }
  { ------------------------------------------------------------------ }
  ERR_SYNTAX    = 1;         { Erreur de syntaxe                       }
  ERR_OPERAND   = 2;         { Operande invalide                       }
  ERR_RANGE     = 3;         { Valeur hors limites                     }
  ERR_UNDEFINED = 4;         { Symbole non defini                      }
  ERR_DUPLICATE = 5;         { Symbole deja defini                     }
  ERR_PHASE     = 6;         { Erreur de phase (valeur change)         }
  ERR_INTERNAL  = 7;         { Erreur interne de l'assembleur          }

  { ------------------------------------------------------------------ }
  { Types de symbole                                                    }
  { ------------------------------------------------------------------ }
  SYM_LABEL    = 0;          { Etiquette (adresse)                     }
  SYM_EQU      = 1;          { Constante EQU (non redefinissable)      }
  SYM_SET      = 2;          { Variable SET (redefinissable)           }
  SYM_EXTERNAL = 3;          { Symbole externe (XREF)                  }
  SYM_ENTRY    = 4;          { Symbole exporte (XDEF)                  }

  { ------------------------------------------------------------------ }
  { Types de section                                                    }
  { ------------------------------------------------------------------ }
  SEC_CODE = 0;              { Section code (TEXT)                      }
  SEC_DATA = 1;              { Section donnees initialisees             }
  SEC_BSS  = 2;              { Section donnees non initialisees         }

  { ------------------------------------------------------------------ }
  { Types de fixup                                                      }
  { ------------------------------------------------------------------ }
  FIX_ABSOLUTE    = 0;       { Reference absolue                       }
  FIX_PC_RELATIVE = 1;       { Reference relative au PC                }

{ ============================================================================ }
{ Types internes                                                               }
{ ============================================================================ }

Type

  { --- Options de ligne de commande --- }
  TOptions = Record
    SrcFile       : String;                             { Fichier source           }
    ObjFile       : String;                             { Fichier objet (-o)       }
    ListFile      : String;                             { Fichier listing (-l)     }
    DefSymCount   : Integer;                            { Nombre de symboles -d    }
    DefSymbols    : Array[1..MAX_DEF_SYMS] of String[64]; { Symboles predefinis    }
    IncPathCount  : Integer;                            { Nombre de repertoires -i }
    IncludePaths  : Array[1..MAX_INC_PATHS] of String;  { Repertoires INCLUDE      }
    ErrorsOnly    : Boolean;                            { -e : erreurs seulement   }
    ShowWarnings  : Boolean;                            { -w : afficher warnings   }
    IncludeSymTable : Boolean;                          { -s : symboles dans listing}
    NoObject      : Boolean;                            { -n : pas de fichier objet}
    ExpandMacros  : Boolean;                            { -x : expansion macros    }
  End;

  { --- Operande analyse --- }
  TOperand = Record
    Mode    : Integer;        { AM_xxx : mode d'adressage              }
    Reg     : Integer;        { REG_xxx : registre principal           }
    Disp    : LongInt;        { Deplacement (d8 ou d16)                }
    IdxReg  : Integer;        { REG_xxx : registre d'index             }
    IdxSize : Integer;        { SIZE_WORD ou SIZE_LONG pour index      }
    Imm32   : LongInt;        { Valeur immediate 32 bits               }
    SymRef  : String[64];     { Reference symbolique (nom)             }
    ExprStr : String;         { Expression source brute                }
  End;

  { --- Entree de la table des symboles (TODO 04) --- }
  TSymEntry = Record
    Name       : String[64];  { Nom du symbole (majuscules)            }
    Value      : LongInt;     { Valeur (adresse ou constante 32 bits)  }
    Section    : Integer;     { SEC_CODE, SEC_DATA, SEC_BSS            }
    SymType    : Integer;     { SYM_LABEL, SYM_EQU, SYM_SET, etc.     }
    Defined    : Boolean;     { True si symbole defini                 }
    Referenced : Boolean;     { True si symbole reference              }
    Pass1Value : LongInt;     { Valeur en passe 1 (verif phase)        }
    LineNum    : Integer;     { Numero de ligne de definition          }
  End;

  { --- Section de code/donnees (TODO 07) --- }
  TSectionBuf = Array[0..MAX_SEC_SIZE - 1] of Byte;
  PSectionBuf = ^TSectionBuf;

  TSection = Record
    Name     : String[32];    { Nom de la section (CODE, DATA, etc.)   }
    SecType  : Integer;       { SEC_CODE, SEC_DATA, SEC_BSS            }
    Origin   : LongInt;       { Adresse d'origine (ORG)                }
    CurAddr  : LongInt;       { Offset courant dans le buffer          }
    Buf      : PSectionBuf;   { Buffer de code (alloue dynamiquement)  }
    Size     : LongInt;       { Taille maximale utilisee               }
  End;

  { --- Fixup : reference a resoudre en passe 2 (TODO 07) --- }
  TFixup = Record
    Section  : Integer;       { Index de section (1..SectionCount)     }
    Offset   : LongInt;       { Offset dans le buffer de la section    }
    Size     : Integer;       { Taille du champ : 8, 16 ou 32 bits    }
    SymIdx   : Integer;       { Index dans SymTable (0 = absolu)       }
    FixType  : Integer;       { FIX_ABSOLUTE ou FIX_PC_RELATIVE        }
    Addend   : LongInt;       { Valeur a ajouter (addend)              }
  End;

  { --- Macro : definition de macro (TODO 09) --- }
  TMacroEntry = Record
    Name       : String[64];     { Nom de la macro (majuscules)           }
    ParamCount : Integer;        { Nombre de parametres formels           }
    ParamNames : Array[1..MAX_MACRO_PARAMS] of String[32]; { Noms params }
    Body       : Array[1..MAX_MACRO_LINES] of String;      { Corps       }
    BodyCount  : Integer;        { Nombre de lignes du corps              }
    LineNum    : Integer;        { Ligne de definition                    }
  End;

  { --- Buffer de lignes pour INCLUDE (TODO 09) --- }
  TIncLineBuf = Array[1..MAX_INC_LINES] of String;
  PIncLineBuf = ^TIncLineBuf;

{ ============================================================================ }
{ Variables globales                                                           }
{ ============================================================================ }

Var

  { --- Options --- }
  Opts : TOptions;

  { --- Compteurs globaux --- }
  ErrorCount   : Integer;
  WarningCount : Integer;
  LineCount    : Integer;
  CodeSize     : LongInt;

  { --- Etat du lexeur (TODO 02) --- }
  src_file     : Text;         { Fichier source ouvert                  }
  src_opened   : Boolean;      { True si fichier source ouvert          }
  src_line     : String;       { Ligne courante                         }
  src_line_num : Integer;      { Numero de la ligne courante            }
  src_col      : Integer;      { Colonne courante (1-base)              }
  src_eof      : Boolean;      { True si fin de fichier atteinte        }
  cur_tok      : Integer;      { Type de token courant (TOK_xxx)        }
  cur_tok_str  : String;       { Texte du token courant                 }
  cur_tok_val  : LongInt;      { Valeur du token si TOK_INTEGER         }
  cur_tok_line : Integer;      { Ligne du token courant                 }
  cur_tok_col  : Integer;      { Colonne du token courant               }
  cur_tok_size : Integer;      { Suffixe taille (.B=1 .W=2 .L=4 .S=0)  }
  peek_valid   : Boolean;      { True si token en attente dans peek_*   }
  peek_tok     : Integer;      { Token en attente (type)                }
  peek_tok_str : String;       { Token en attente (texte)               }
  peek_tok_val : LongInt;      { Token en attente (valeur)              }
  peek_tok_line: Integer;      { Token en attente (ligne)               }
  peek_tok_col : Integer;      { Token en attente (colonne)             }
  peek_tok_size: Integer;      { Token en attente (suffixe taille)      }

  { --- Etat du listing (TODO 03) --- }
  list_file     : Text;         { Fichier listing                        }
  list_opened   : Boolean;      { True si fichier listing ouvert         }
  list_page_num : Integer;      { Numero de page courante                }
  list_line_num : Integer;      { Ligne sur la page courante             }
  list_title    : String;       { Titre du listing (directive TTL)       }
  list_enabled  : Boolean;      { True si listing actif (LIST/NOLIST)    }
  list_expand   : Boolean;      { True si expansion macros visible       }

  { --- Table des symboles (TODO 04) --- }
  SymTable      : Array[1..MAX_SYM] of TSymEntry; { Table des symboles   }
  SymCount      : Integer;      { Nombre de symboles dans la table       }
  last_global_sym : String[64]; { Derniere etiquette globale (pour loc.) }

  { --- Evaluateur d'expressions (TODO 05) --- }
  expr_pc       : LongInt;      { Adresse courante (pour * et $)         }
  expr_depth    : Integer;      { Profondeur de recursion courante       }

  { --- Sections et generateur de code (TODO 07) --- }
  Sections      : Array[1..MAX_SECTIONS] of TSection; { Sections          }
  SectionCount  : Integer;      { Nombre de sections                     }
  CurSection    : Integer;      { Index de la section courante (1-base)  }
  Fixups        : Array[1..MAX_FIXUP] of TFixup; { Table des fixups      }
  FixupCount    : Integer;      { Nombre de fixups enregistres           }

  { --- Etat de l'assemblage (TODO 08) --- }
  pass_num         : Integer;      { Passe courante (1 ou 2)              }
  end_source       : Boolean;      { True si directive END rencontree     }
  start_address    : LongInt;      { Adresse de demarrage (END expr)      }
  start_address_set: Boolean;      { True si adresse de demarrage definie }
  cur_label        : String;       { Etiquette de la ligne courante       }

  { --- Macros et includes (TODO 09) --- }
  MacroTable     : Array[1..MAX_MACRO] of ^TMacroEntry; { Table macros   }
  MacroCount     : Integer;      { Nombre de macros definies              }
  macro_expanding: Boolean;      { True si expansion de macro en cours    }
  macro_narg     : Integer;      { NARG pendant expansion                 }
  macro_unique_id: Integer;      { Compteur pour etiquettes uniques (\@)  }
  include_depth  : Integer;      { Profondeur d'imbrication INCLUDE       }

  { --- Assemblage conditionnel (TODO 10) --- }
  cond_stack     : Array[1..MAX_COND_DEPTH] of Record
                     assembling : Boolean;  { True si on assemble dans ce niveau  }
                     else_seen  : Boolean;  { True si ELSE deja rencontre         }
                     outer_asm  : Boolean;  { True si le niveau parent assemble   }
                   End;
  cond_depth     : Integer;      { Profondeur courante d'imbrication IF   }

{ ============================================================================ }
{ Fonctions utilitaires                                                        }
{ ============================================================================ }

Function UpCaseStr(Const S: String): String;
Var I: Integer; R: String;
Begin
 R := S;
 For I := 1 to Length(R) do
  R[I] := UpCase(R[I]);
 UpCaseStr := R;
End;

Function IntToStr(N: LongInt): String;
Var S: String;
Begin
 Str(N, S);
 IntToStr := S;
End;

Function IntToHex(N: LongInt; Digits: Integer): String;
Const
  HexChars: Array[0..15] of Char = '0123456789ABCDEF';
Var
  S: String;
  I: Integer;
  V: LongInt;
Begin
 S := '';
 V := N;
 If Digits <= 0 Then Digits := 1;
 For I := 1 to 8 do
 Begin
  S := HexChars[V and $F] + S;
  V := V shr 4;
 End;
 { Tronquer a la longueur demandee }
 While (Length(S) > Digits) and (S[1] = '0') do
  Delete(S, 1, 1);
 While Length(S) < Digits do
  S := '0' + S;
 IntToHex := S;
End;

Function HexToInt(Const S: String): LongInt;
Var
  I: Integer;
  V: LongInt;
  C: Char;
Begin
 V := 0;
 For I := 1 to Length(S) do
 Begin
  C := UpCase(S[I]);
  If (C >= '0') and (C <= '9') Then
   V := V * 16 + Ord(C) - Ord('0')
  Else If (C >= 'A') and (C <= 'F') Then
   V := V * 16 + Ord(C) - Ord('A') + 10
  Else
  Begin
   HexToInt := 0;
   Exit;
  End;
 End;
 HexToInt := V;
End;

Function Trim(Const S: String): String;
Var
  L, R: Integer;
Begin
 L := 1;
 While (L <= Length(S)) and (S[L] = ' ') do Inc(L);
 R := Length(S);
 While (R >= L) and (S[R] = ' ') do Dec(R);
 If L > R Then
  Trim := ''
 Else
  Trim := Copy(S, L, R - L + 1);
End;

Function PadRight(Const S: String; Width: Integer): String;
Var R: String;
Begin
 R := S;
 While Length(R) < Width do
  R := R + ' ';
 PadRight := R;
End;

Function FileExists(Const FileName: String): Boolean;
Var F: Text;
Begin
 Assign(F, FileName);
 {$I-} Reset(F); {$I+}
 If IOResult = 0 Then
 Begin
  Close(F);
  FileExists := True;
 End
 Else
  FileExists := False;
End;

{ ============================================================================ }
{ TODO 02 - Lexeur : lecture source et tokenisation                            }
{ ============================================================================ }

{ ---------- Lecture source ---------- }

Procedure SrcOpen(Const FileName: String);
Begin
 Assign(src_file, FileName);
 {$I-} Reset(src_file); {$I+}
 If IOResult <> 0 Then
 Begin
  WriteLn('Erreur fatale: impossible d''ouvrir ', FileName);
  Halt(2);
 End;
 src_opened   := True;
 src_line     := '';
 src_line_num := 0;
 src_col      := 1;
 src_eof      := False;
 peek_valid   := False;
End;

Procedure SrcClose;
Begin
 If src_opened Then
 Begin
  Close(src_file);
  src_opened := False;
 End;
End;

Function SrcGetLine: Boolean;
Begin
 If src_eof or Eof(src_file) Then
 Begin
  src_eof := True;
  src_line := '';
  src_col := 1;
  SrcGetLine := False;
  Exit;
 End;
 ReadLn(src_file, src_line);
 Inc(src_line_num);
 Inc(LineCount);
 src_col := 1;
 src_eof := False;
 SrcGetLine := True;
End;

{ ---------- Lecture caractere par caractere ---------- }

Function SrcPeekChar: Char;
Begin
 If src_col <= Length(src_line) Then
  SrcPeekChar := src_line[src_col]
 Else
  SrcPeekChar := #0;
End;

Function SrcGetChar: Char;
Begin
 If src_col <= Length(src_line) Then
 Begin
  SrcGetChar := src_line[src_col];
  Inc(src_col);
 End
 Else
  SrcGetChar := #0;
End;

{ ---------- Espaces et commentaires ---------- }

Procedure SkipWhitespace;
Begin
 While (src_col <= Length(src_line)) and
       (src_line[src_col] in [' ', #9]) do
  Inc(src_col);
End;

Function SkipComment: Boolean;
{ Retourne True si le reste de la ligne est un commentaire }
Begin
 SkipComment := False;
 If src_col > Length(src_line) Then
 Begin
  SkipComment := True;
  Exit;
 End;
 { ';' commence un commentaire n'importe ou }
 If src_line[src_col] = ';' Then
 Begin
  src_col := Length(src_line) + 1;
  SkipComment := True;
  Exit;
 End;
 { '*' en debut de ligne (colonne 1) = commentaire }
 If (src_col = 1) and (src_line[1] = '*') Then
 Begin
  src_col := Length(src_line) + 1;
  SkipComment := True;
  Exit;
 End;
End;

{ ---------- Reconnaissance de registres, opcodes, directives ---------- }

Function IsRegister(Const S: String; Var RegNum: Integer): Boolean;
Var U: String;
Begin
 U := UpCaseStr(S);
 IsRegister := True;
 { Registres de donnees D0-D7 }
 If (Length(U) = 2) and (U[1] = 'D') and (U[2] >= '0') and (U[2] <= '7') Then
  RegNum := Ord(U[2]) - Ord('0')
 { Registres d'adresses A0-A7 }
 Else If (Length(U) = 2) and (U[1] = 'A') and (U[2] >= '0') and (U[2] <= '7') Then
  RegNum := REG_A0 + Ord(U[2]) - Ord('0')
 { Registres speciaux }
 Else If U = 'SP' Then RegNum := REG_A7
 Else If U = 'PC' Then RegNum := REG_PC
 Else If U = 'SR' Then RegNum := REG_SR
 Else If U = 'CCR' Then RegNum := REG_CCR
 Else If U = 'USP' Then RegNum := REG_USP
 Else If U = 'SSP' Then RegNum := REG_SSP
 Else
 Begin
  IsRegister := False;
  RegNum := REG_NONE;
 End;
End;

Function IsOpcode(Const S: String): Boolean;
Var U: String;
Begin
 U := UpCaseStr(S);
 IsOpcode := False;
 { Supprime suffixe de taille pour comparer }
 If (Length(U) > 2) and (U[Length(U) - 1] = '.') and
    (U[Length(U)] in ['B', 'W', 'L', 'S']) Then
  U := Copy(U, 1, Length(U) - 2);
 { Instructions de transfert }
 If (U = 'MOVE') or (U = 'MOVEA') or (U = 'MOVEQ') or
    (U = 'MOVEM') or (U = 'MOVEP') Then Begin IsOpcode := True; Exit; End;
 If (U = 'LEA') or (U = 'PEA') or (U = 'EXG') or
    (U = 'SWAP') or (U = 'LINK') or (U = 'UNLK') Then Begin IsOpcode := True; Exit; End;
 { Instructions arithmetiques }
 If (U = 'ADD') or (U = 'ADDA') or (U = 'ADDI') or
    (U = 'ADDQ') or (U = 'ADDX') Then Begin IsOpcode := True; Exit; End;
 If (U = 'SUB') or (U = 'SUBA') or (U = 'SUBI') or
    (U = 'SUBQ') or (U = 'SUBX') Then Begin IsOpcode := True; Exit; End;
 If (U = 'MULS') or (U = 'MULU') or
    (U = 'DIVS') or (U = 'DIVU') Then Begin IsOpcode := True; Exit; End;
 If (U = 'NEG') or (U = 'NEGX') or (U = 'CLR') or
    (U = 'EXT') or (U = 'TAS') Then Begin IsOpcode := True; Exit; End;
 { Instructions de comparaison et test }
 If (U = 'CMP') or (U = 'CMPA') or (U = 'CMPI') or
    (U = 'CMPM') or (U = 'TST') Then Begin IsOpcode := True; Exit; End;
 { Instructions logiques }
 If (U = 'AND') or (U = 'ANDI') or
    (U = 'OR') or (U = 'ORI') or
    (U = 'EOR') or (U = 'EORI') or
    (U = 'NOT') Then Begin IsOpcode := True; Exit; End;
 { Instructions de decalage et rotation }
 If (U = 'ASL') or (U = 'ASR') or
    (U = 'LSL') or (U = 'LSR') or
    (U = 'ROL') or (U = 'ROR') or
    (U = 'ROXL') or (U = 'ROXR') Then Begin IsOpcode := True; Exit; End;
 { Instructions de bits }
 If (U = 'BTST') or (U = 'BSET') or
    (U = 'BCLR') or (U = 'BCHG') Then Begin IsOpcode := True; Exit; End;
 { Instructions de branchement }
 If (U = 'BRA') or (U = 'BSR') or
    (U = 'BCC') or (U = 'BCS') or (U = 'BEQ') or (U = 'BNE') or
    (U = 'BGE') or (U = 'BGT') or (U = 'BLE') or (U = 'BLT') or
    (U = 'BHI') or (U = 'BLS') or (U = 'BMI') or (U = 'BPL') or
    (U = 'BVC') or (U = 'BVS') or
    (U = 'BHS') or (U = 'BLO') Then Begin IsOpcode := True; Exit; End;
 { Instructions DBcc }
 If (U = 'DBCC') or (U = 'DBCS') or (U = 'DBEQ') or (U = 'DBNE') or
    (U = 'DBGE') or (U = 'DBGT') or (U = 'DBLE') or (U = 'DBLT') or
    (U = 'DBHI') or (U = 'DBLS') or (U = 'DBMI') or (U = 'DBPL') or
    (U = 'DBVC') or (U = 'DBVS') or
    (U = 'DBF') or (U = 'DBT') or (U = 'DBRA') Then Begin IsOpcode := True; Exit; End;
 { Instructions Scc }
 If (U = 'SCC') or (U = 'SCS') or (U = 'SEQ') or (U = 'SNE') or
    (U = 'SGE') or (U = 'SGT') or (U = 'SLE') or (U = 'SLT') or
    (U = 'SHI') or (U = 'SLS') or (U = 'SMI') or (U = 'SPL') or
    (U = 'SVC') or (U = 'SVS') or
    (U = 'SF') or (U = 'ST') Then Begin IsOpcode := True; Exit; End;
 { Instructions de saut }
 If (U = 'JMP') or (U = 'JSR') Then Begin IsOpcode := True; Exit; End;
 { Instructions speciales }
 If (U = 'NOP') or (U = 'RESET') or (U = 'STOP') or
    (U = 'RTE') or (U = 'RTS') or (U = 'RTR') or
    (U = 'TRAP') or (U = 'TRAPV') or (U = 'CHK') or
    (U = 'ILLEGAL') Then Begin IsOpcode := True; Exit; End;
 { Instructions BCD }
 If (U = 'ABCD') or (U = 'SBCD') or (U = 'NBCD') Then Begin IsOpcode := True; Exit; End;
End;

Function IsDirective(Const S: String): Boolean;
Var U: String;
Begin
 U := UpCaseStr(S);
 IsDirective := False;
 { Supprime suffixe de taille pour comparer }
 If (Length(U) > 2) and (U[Length(U) - 1] = '.') and
    (U[Length(U)] in ['B', 'W', 'L', 'S']) Then
  U := Copy(U, 1, Length(U) - 2);
 If (U = 'ORG') or (U = 'DC') or (U = 'DS') or
    (U = 'EQU') or (U = 'END') or (U = 'SET') Then Begin IsDirective := True; Exit; End;
 If (U = 'SECTION') or (U = 'INCLUDE') or
    (U = 'MACRO') or (U = 'ENDM') or
    (U = 'MEXIT') Then Begin IsDirective := True; Exit; End;
 If (U = 'IF') or (U = 'IFDEF') or (U = 'IFNDEF') or
    (U = 'IFEQ') or (U = 'IFNE') or (U = 'IFGT') or
    (U = 'IFGE') or (U = 'IFLT') or (U = 'IFLE') or
    (U = 'IFC') or (U = 'IFNC') or
    (U = 'ELSE') or (U = 'ENDC') or (U = 'ENDIF') Then Begin IsDirective := True; Exit; End;
 If (U = 'XDEF') or (U = 'XREF') or (U = 'PUBLIC') or
    (U = 'EXTERN') or (U = 'ENTRY') or
    (U = 'EXTERNAL') Then Begin IsDirective := True; Exit; End;
 If (U = 'OPT') or (U = 'LIST') or (U = 'NOLIST') or
    (U = 'PAGE') or (U = 'TTL') or (U = 'SPC') Then Begin IsDirective := True; Exit; End;
 If (U = 'CNOP') or (U = 'EVEN') or (U = 'ALIGN') or
    (U = 'FAIL') Then Begin IsDirective := True; Exit; End;
 If (U = 'REPT') or (U = 'ENDR') or (U = 'DCB') Then Begin IsDirective := True; Exit; End;
End;

{ ---------- Fonctions de lexage individuelles ---------- }

Procedure LexIdent;
{ Lit un identifiant commencant par lettre ou '_' ou '.'
  Determine si c'est un registre, opcode, directive ou simple identifiant.
  Gere les suffixes de taille .B .W .L .S pour les opcodes/directives }
Var
  RegNum: Integer;
  BaseIdent: String;
  U: String;
Begin
 cur_tok_str := '';
 { Un identifiant peut commencer par lettre, '_', ou '.' (etiquette locale) }
 While (src_col <= Length(src_line)) and
       (src_line[src_col] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.']) do
 Begin
  cur_tok_str := cur_tok_str + src_line[src_col];
  Inc(src_col);
 End;
 U := UpCaseStr(cur_tok_str);
 cur_tok_str := U;
 cur_tok_size := 0;

 { Verifier d'abord si c'est un registre }
 If IsRegister(U, RegNum) Then
 Begin
  cur_tok := TOK_REGISTER;
  cur_tok_val := RegNum;
  Exit;
 End;

 { Extraire le suffixe de taille si present (.B .W .L .S) }
 BaseIdent := U;
 If (Length(U) > 2) and (U[Length(U) - 1] = '.') and
    (U[Length(U)] in ['B', 'W', 'L', 'S']) Then
 Begin
  Case U[Length(U)] of
   'B': cur_tok_size := SIZE_BYTE;
   'W': cur_tok_size := SIZE_WORD;
   'L': cur_tok_size := SIZE_LONG;
   'S': cur_tok_size := SIZE_BYTE; { .S = short branch = .B }
  End;
  BaseIdent := Copy(U, 1, Length(U) - 2);
 End;

 { Verifier si c'est un opcode }
 If IsOpcode(BaseIdent) Then
 Begin
  cur_tok := TOK_OPCODE;
  cur_tok_str := BaseIdent;
  Exit;
 End;

 { Verifier si c'est une directive }
 If IsDirective(BaseIdent) Then
 Begin
  cur_tok := TOK_DIRECTIVE;
  cur_tok_str := BaseIdent;
  Exit;
 End;

 { Sinon c'est un identifiant simple (etiquette, symbole) }
 cur_tok := TOK_IDENT;
 cur_tok_size := 0; { pas de suffixe pour un ident }
End;

Procedure LexNumber;
{ Lit un litteral entier :
  $xxxx ou 0xFFFF -> hexadecimal
  @nnn ou 0onnn   -> octal
  %bbbb ou 0bnnnn -> binaire
  sinon            -> decimal }
Var
  S: String;
  V: LongInt;
  C: Char;
Begin
 cur_tok := TOK_INTEGER;
 cur_tok_val := 0;
 cur_tok_str := '';

 C := src_line[src_col];

 { $xxxx : hexadecimal }
 If C = '$' Then
 Begin
  cur_tok_str := '$';
  Inc(src_col);
  S := '';
  While (src_col <= Length(src_line)) and
        (UpCase(src_line[src_col]) in ['0'..'9', 'A'..'F']) do
  Begin
   S := S + src_line[src_col];
   Inc(src_col);
  End;
  cur_tok_str := cur_tok_str + S;
  cur_tok_val := HexToInt(S);
  Exit;
 End;

 { @nnn : octal }
 If C = '@' Then
 Begin
  cur_tok_str := '@';
  Inc(src_col);
  S := '';
  V := 0;
  While (src_col <= Length(src_line)) and
        (src_line[src_col] in ['0'..'7']) do
  Begin
   S := S + src_line[src_col];
   V := V * 8 + Ord(src_line[src_col]) - Ord('0');
   Inc(src_col);
  End;
  cur_tok_str := cur_tok_str + S;
  cur_tok_val := V;
  Exit;
 End;

 { %bbbb : binaire }
 If C = '%' Then
 Begin
  cur_tok_str := '%';
  Inc(src_col);
  S := '';
  V := 0;
  While (src_col <= Length(src_line)) and
        (src_line[src_col] in ['0', '1']) do
  Begin
   S := S + src_line[src_col];
   V := V * 2 + Ord(src_line[src_col]) - Ord('0');
   Inc(src_col);
  End;
  cur_tok_str := cur_tok_str + S;
  cur_tok_val := V;
  Exit;
 End;

 { Nombre commencant par 0 : verifier 0x, 0o, 0b }
 If C = '0' Then
 Begin
  cur_tok_str := '0';
  Inc(src_col);
  If src_col <= Length(src_line) Then
  Begin
   { 0xFFFF : hexadecimal }
   If UpCase(src_line[src_col]) = 'X' Then
   Begin
    cur_tok_str := cur_tok_str + src_line[src_col];
    Inc(src_col);
    S := '';
    While (src_col <= Length(src_line)) and
          (UpCase(src_line[src_col]) in ['0'..'9', 'A'..'F']) do
    Begin
     S := S + src_line[src_col];
     Inc(src_col);
    End;
    cur_tok_str := cur_tok_str + S;
    cur_tok_val := HexToInt(S);
    Exit;
   End;
   { 0onnn : octal }
   If UpCase(src_line[src_col]) = 'O' Then
   Begin
    cur_tok_str := cur_tok_str + src_line[src_col];
    Inc(src_col);
    S := '';
    V := 0;
    While (src_col <= Length(src_line)) and
          (src_line[src_col] in ['0'..'7']) do
    Begin
     S := S + src_line[src_col];
     V := V * 8 + Ord(src_line[src_col]) - Ord('0');
     Inc(src_col);
    End;
    cur_tok_str := cur_tok_str + S;
    cur_tok_val := V;
    Exit;
   End;
   { 0bnnnn : binaire }
   If UpCase(src_line[src_col]) = 'B' Then
   Begin
    cur_tok_str := cur_tok_str + src_line[src_col];
    Inc(src_col);
    S := '';
    V := 0;
    While (src_col <= Length(src_line)) and
          (src_line[src_col] in ['0', '1']) do
    Begin
     S := S + src_line[src_col];
     V := V * 2 + Ord(src_line[src_col]) - Ord('0');
     Inc(src_col);
    End;
    cur_tok_str := cur_tok_str + S;
    cur_tok_val := V;
    Exit;
   End;
  End;
  { Suite de chiffres decimaux apres le 0 initial }
  V := 0;
  While (src_col <= Length(src_line)) and
        (src_line[src_col] in ['0'..'9']) do
  Begin
   cur_tok_str := cur_tok_str + src_line[src_col];
   V := V * 10 + Ord(src_line[src_col]) - Ord('0');
   Inc(src_col);
  End;
  cur_tok_val := V;
  Exit;
 End;

 { Nombre decimal pur }
 V := 0;
 While (src_col <= Length(src_line)) and
       (src_line[src_col] in ['0'..'9']) do
 Begin
  cur_tok_str := cur_tok_str + src_line[src_col];
  V := V * 10 + Ord(src_line[src_col]) - Ord('0');
  Inc(src_col);
 End;
 cur_tok_val := V;
End;

Procedure LexString;
{ Lit une chaine entre apostrophes '...'
  Double apostrophe '' = apostrophe litterale dans la chaine }
Begin
 cur_tok := TOK_STRING;
 cur_tok_str := '';
 Inc(src_col); { sauter l'apostrophe ouvrante }
 While src_col <= Length(src_line) do
 Begin
  If src_line[src_col] = '''' Then
  Begin
   Inc(src_col);
   { Double apostrophe = apostrophe litterale }
   If (src_col <= Length(src_line)) and (src_line[src_col] = '''') Then
   Begin
    cur_tok_str := cur_tok_str + '''';
    Inc(src_col);
   End
   Else
    Exit; { fin de chaine }
  End
  Else
  Begin
   cur_tok_str := cur_tok_str + src_line[src_col];
   Inc(src_col);
  End;
 End;
 { Chaine non fermee - pas d'erreur ici, sera geree plus tard }
End;

{ ---------- Dispatcher principal ---------- }

Procedure NextToken;
{ Lit le prochain token depuis la source.
  Si peek_valid, retourne le token en attente }
Var
  C: Char;
Begin
 { Si un token est en attente (PeekToken), le retourner }
 If peek_valid Then
 Begin
  cur_tok      := peek_tok;
  cur_tok_str  := peek_tok_str;
  cur_tok_val  := peek_tok_val;
  cur_tok_line := peek_tok_line;
  cur_tok_col  := peek_tok_col;
  cur_tok_size := peek_tok_size;
  peek_valid   := False;
  Exit;
 End;

 cur_tok_size := 0;

 { Boucle pour sauter les lignes vides / commentaires }
 While True do
 Begin
  { Sauter les espaces }
  SkipWhitespace;

  { Verifier si on est en fin de ligne ou commentaire }
  If src_col > Length(src_line) Then
  Begin
   { Fin de ligne : retourner TOK_EOL sauf si c'etait deja un EOL }
   cur_tok := TOK_EOL;
   cur_tok_str := '';
   cur_tok_val := 0;
   cur_tok_line := src_line_num;
   cur_tok_col := src_col;
   { Lire la ligne suivante pour le prochain appel }
   If Not SrcGetLine Then
   Begin
    cur_tok := TOK_EOF;
    Exit;
   End;
   Exit;
  End;

  { Verifier commentaire }
  If SkipComment Then
  Begin
   cur_tok := TOK_EOL;
   cur_tok_str := '';
   cur_tok_val := 0;
   cur_tok_line := src_line_num;
   cur_tok_col := src_col;
   If Not SrcGetLine Then
   Begin
    cur_tok := TOK_EOF;
    Exit;
   End;
   Exit;
  End;

  Break; { On a trouve du contenu a analyser }
 End;

 { Position du token }
 cur_tok_line := src_line_num;
 cur_tok_col  := src_col;

 C := src_line[src_col];

 { Identifier ou mot-cle (lettre, '_', '.' pour etiquette locale) }
 If C in ['A'..'Z', 'a'..'z', '_'] Then
 Begin
  LexIdent;
  { Verifier si un ':' suit immediatement un identifiant => etiquette }
  If (cur_tok = TOK_IDENT) and (src_col <= Length(src_line)) and
     (src_line[src_col] = ':') Then
  Begin
   cur_tok := TOK_LABEL;
   Inc(src_col);
  End;
  Exit;
 End;

 { Etiquette locale commencant par '.' }
 If (C = '.') and (src_col + 1 <= Length(src_line)) and
    (src_line[src_col + 1] in ['A'..'Z', 'a'..'z', '_']) Then
 Begin
  LexIdent;
  If (cur_tok = TOK_IDENT) and (src_col <= Length(src_line)) and
     (src_line[src_col] = ':') Then
  Begin
   cur_tok := TOK_LABEL;
   Inc(src_col);
  End;
  Exit;
 End;

 { Nombre : decimal, hex ($, 0x), octal (@, 0o), binaire (%, 0b) }
 If C in ['0'..'9'] Then
 Begin
  LexNumber;
  Exit;
 End;
 If (C = '$') and (src_col + 1 <= Length(src_line)) and
    (UpCase(src_line[src_col + 1]) in ['0'..'9', 'A'..'F']) Then
 Begin
  LexNumber;
  Exit;
 End;
 If (C = '@') and (src_col + 1 <= Length(src_line)) and
    (src_line[src_col + 1] in ['0'..'7']) Then
 Begin
  LexNumber;
  Exit;
 End;
 If (C = '%') and (src_col + 1 <= Length(src_line)) and
    (src_line[src_col + 1] in ['0', '1']) Then
 Begin
  LexNumber;
  Exit;
 End;

 { Chaine entre apostrophes }
 If C = '''' Then
 Begin
  LexString;
  { Si un seul caractere, c'est un TOK_CHAR }
  If Length(cur_tok_str) = 1 Then
  Begin
   cur_tok := TOK_CHAR;
   cur_tok_val := Ord(cur_tok_str[1]);
  End;
  Exit;
 End;

 { Caracteres simples }
 Inc(src_col);
 cur_tok_str := C;
 cur_tok_val := 0;

 Case C of
  ',': cur_tok := TOK_COMMA;
  '(': cur_tok := TOK_LPAREN;
  ')': cur_tok := TOK_RPAREN;
  '+': cur_tok := TOK_PLUS;
  '-': cur_tok := TOK_MINUS;
  '*': cur_tok := TOK_STAR;
  '/': cur_tok := TOK_SLASH;
  '#': cur_tok := TOK_HASH;
  '.': cur_tok := TOK_DOT;
  ':': cur_tok := TOK_COLON;
  '=': cur_tok := TOK_EQUAL;
  '&': cur_tok := TOK_AMPERSAND;
  '|': cur_tok := TOK_PIPE;
  '^': cur_tok := TOK_CARET;
  '%': cur_tok := TOK_PERCENT;
  '~': cur_tok := TOK_TILDE;
  '<': Begin
        If (src_col <= Length(src_line)) and (src_line[src_col] = '<') Then
        Begin
         cur_tok := TOK_LSHIFT;
         cur_tok_str := '<<';
         Inc(src_col);
        End
        Else
         cur_tok := TOK_UNKNOWN;
       End;
  '>': Begin
        If (src_col <= Length(src_line)) and (src_line[src_col] = '>') Then
        Begin
         cur_tok := TOK_RSHIFT;
         cur_tok_str := '>>';
         Inc(src_col);
        End
        Else
         cur_tok := TOK_UNKNOWN;
       End;
 Else
  cur_tok := TOK_UNKNOWN;
 End;
End;

{ ---------- Helpers de parsing ---------- }

Procedure Consume(Expected: Integer);
{ Verifie que le token courant est du type attendu, puis avance }
Begin
 If cur_tok <> Expected Then
 Begin
  WriteLn('Ligne ', cur_tok_line, ': token inattendu "', cur_tok_str,
          '" (attendu type ', Expected, ')');
  Inc(ErrorCount);
 End;
 NextToken;
End;

Procedure Expect(Expected: Integer);
{ Verifie que le token courant est du type attendu (sans avancer) }
Begin
 If cur_tok <> Expected Then
 Begin
  WriteLn('Ligne ', cur_tok_line, ': token inattendu "', cur_tok_str,
          '" (attendu type ', Expected, ')');
  Inc(ErrorCount);
 End;
End;

Procedure PeekToken;
{ Lit le prochain token et le stocke pour consultation sans consommer.
  Le token courant reste inchange. }
Var
  save_tok      : Integer;
  save_str      : String;
  save_val      : LongInt;
  save_line     : Integer;
  save_col      : Integer;
  save_size     : Integer;
Begin
 If peek_valid Then Exit; { deja en cache }
 { Sauvegarder le token courant }
 save_tok  := cur_tok;
 save_str  := cur_tok_str;
 save_val  := cur_tok_val;
 save_line := cur_tok_line;
 save_col  := cur_tok_col;
 save_size := cur_tok_size;
 { Lire le prochain }
 NextToken;
 { Stocker dans peek }
 peek_tok      := cur_tok;
 peek_tok_str  := cur_tok_str;
 peek_tok_val  := cur_tok_val;
 peek_tok_line := cur_tok_line;
 peek_tok_col  := cur_tok_col;
 peek_tok_size := cur_tok_size;
 peek_valid    := True;
 { Restaurer le token courant }
 cur_tok      := save_tok;
 cur_tok_str  := save_str;
 cur_tok_val  := save_val;
 cur_tok_line := save_line;
 cur_tok_col  := save_col;
 cur_tok_size := save_size;
End;

{ ============================================================================ }
{ TODO 03 - Gestion des erreurs, avertissements et listing                     }
{ ============================================================================ }

{ ---------- Erreurs et avertissements ---------- }

Procedure Error(Line, Col: Integer; Const Msg: String);
{ Erreur non fatale : affiche, incremente ErrorCount, arrete a MAX_ERRORS }
Begin
 WriteLn('*** Erreur ligne ', Line, ', col ', Col, ': ', Msg);
 Inc(ErrorCount);
 If ErrorCount >= MAX_ERRORS Then
 Begin
  WriteLn('*** Trop d''erreurs (', MAX_ERRORS, '), assemblage interrompu.');
  Halt(1);
 End;
End;

Procedure Warning(Line, Col: Integer; Const Msg: String);
{ Avertissement non bloquant, incremente WarningCount }
Begin
 If Opts.ShowWarnings Then
  WriteLn('Avertissement ligne ', Line, ', col ', Col, ': ', Msg);
 Inc(WarningCount);
End;

Procedure FatalError(Const Msg: String);
{ Erreur fatale : affiche et arrete immediatement }
Begin
 WriteLn('*** Erreur fatale: ', Msg);
 Halt(1);
End;

{ ---------- Fichier listing ---------- }

Procedure ListOpen(Const FileName: String);
Begin
 If FileName = '' Then
 Begin
  list_opened := False;
  Exit;
 End;
 Assign(list_file, FileName);
 {$I-} Rewrite(list_file); {$I+}
 If IOResult <> 0 Then
 Begin
  WriteLn('Avertissement: impossible de creer le listing ', FileName);
  list_opened := False;
  Exit;
 End;
 list_opened   := True;
 list_page_num := 1;
 list_line_num := 0;
 list_title    := '';
 list_enabled  := True;
 list_expand   := Opts.ExpandMacros;
End;

Procedure ListClose;
Begin
 If list_opened Then
 Begin
  Close(list_file);
  list_opened := False;
 End;
End;

Procedure ListFormFeed;
{ Saut de page dans le listing }
Begin
 If Not list_opened Then Exit;
 WriteLn(list_file, #12); { form feed }
 Inc(list_page_num);
 list_line_num := 0;
End;

Procedure ListTitle(Const Title: String);
{ Definit le titre du listing (directive TTL) }
Begin
 list_title := Title;
End;

Procedure ListPageHeader;
{ Affiche l'en-tete de page dans le listing }
Begin
 If Not list_opened Then Exit;
 WriteLn(list_file, 'ASM68 - Assembleur Motorola 68000');
 If list_title <> '' Then
  WriteLn(list_file, list_title);
 WriteLn(list_file, PadRight('', 70), 'Page ', list_page_num);
 WriteLn(list_file);
 list_line_num := 4;
End;

Procedure ListPage;
{ Force un saut de page si necessaire }
Begin
 If Not list_opened Then Exit;
 ListFormFeed;
 ListPageHeader;
End;

Procedure ListLine(Addr: LongInt; Const Bytes: String; ByteCount: Integer;
                   Const Source: String);
{ Affiche une ligne de listing au format :
  AAAAAA  XX XX XX XX XX XX  source line
  Addr      = adresse courante (6 hex)
  Bytes     = octets generes (chaine brute de chars)
  ByteCount = nombre d'octets dans Bytes
  Source    = ligne source originale }
Var
  Line: String;
  I: Integer;
  HexPart: String;
Begin
 If Not list_opened Then Exit;
 If Not list_enabled Then Exit;

 { Pagination }
 If list_line_num >= LIST_PAGE_SIZE Then
  ListPage;

 { Formater l'adresse : 6 hex }
 Line := IntToHex(Addr, 6) + '  ';

 { Formater les octets (jusqu'a MAX_LIST_BYTES) }
 HexPart := '';
 For I := 1 to MAX_LIST_BYTES do
 Begin
  If I <= ByteCount Then
   HexPart := HexPart + IntToHex(Ord(Bytes[I]), 2) + ' '
  Else
   HexPart := HexPart + '   ';
 End;

 Line := Line + HexPart + ' ' + Source;
 WriteLn(list_file, Line);
 Inc(list_line_num);

 { Si plus de MAX_LIST_BYTES octets, lignes de continuation }
 I := MAX_LIST_BYTES + 1;
 While I <= ByteCount do
 Begin
  If list_line_num >= LIST_PAGE_SIZE Then
   ListPage;
  Line := '        '; { 8 espaces pour aligner }
  HexPart := '';
  While (I <= ByteCount) and ((I - 1) mod MAX_LIST_BYTES < MAX_LIST_BYTES) do
  Begin
   HexPart := HexPart + IntToHex(Ord(Bytes[I]), 2) + ' ';
   Inc(I);
   If (I - 1) mod MAX_LIST_BYTES = 0 Then Break;
  End;
  Line := Line + HexPart;
  WriteLn(list_file, Line);
  Inc(list_line_num);
 End;
End;

{ ---------- Helpers d'affichage symboles (utilises par ListSymbolTable) --- }

Function SymTypeName(T: Integer): String; Forward;
Function SymSectionName(S: Integer): String; Forward;

Procedure ListSymbolTable;
{ Affiche la table des symboles triee dans le listing.
  Tri par insertion simple sur les noms. }
Var
  SortIdx : Array[1..MAX_SYM] of Integer;
  I, J, Tmp : Integer;
Begin
 If Not list_opened Then Exit;
 If Not Opts.IncludeSymTable Then Exit;
 If SymCount = 0 Then Exit;
 ListPage;
 WriteLn(list_file, '--- Table des symboles ---');
 WriteLn(list_file);
 WriteLn(list_file, PadRight('Symbole', 24), PadRight('Valeur', 12),
         PadRight('Type', 10), 'Section');
 WriteLn(list_file, PadRight('-------', 24), PadRight('------', 12),
         PadRight('----', 10), '-------');
 { Initialiser les index de tri }
 For I := 1 to SymCount do
  SortIdx[I] := I;
 { Tri par insertion sur le nom }
 For I := 2 to SymCount do
 Begin
  Tmp := SortIdx[I];
  J := I - 1;
  While (J >= 1) and (SymTable[SortIdx[J]].Name > SymTable[Tmp].Name) do
  Begin
   SortIdx[J + 1] := SortIdx[J];
   Dec(J);
  End;
  SortIdx[J + 1] := Tmp;
 End;
 { Afficher les symboles tries }
 For I := 1 to SymCount do
 Begin
  If list_line_num >= LIST_PAGE_SIZE Then
   ListPage;
  WriteLn(list_file,
          PadRight(SymTable[SortIdx[I]].Name, 24),
          PadRight(IntToHex(SymTable[SortIdx[I]].Value, 8), 12),
          PadRight(SymTypeName(SymTable[SortIdx[I]].SymType), 10),
          SymSectionName(SymTable[SortIdx[I]].Section));
  Inc(list_line_num);
 End;
 WriteLn(list_file);
 WriteLn(list_file, SymCount, ' symbole(s).');
 WriteLn(list_file);
End;

{ ---------- Bilan de compilation ---------- }

Procedure BilanCompilation;
{ Affiche les statistiques de compilation }
Var I: Integer;
Begin
 WriteLn;
 WriteLn('ASM68 - Assembleur Motorola 68000');
 WriteLn('Source         : ', Opts.SrcFile);
 WriteLn('Objet          : ', Opts.ObjFile);
 If Opts.ListFile <> '' Then
  WriteLn('Listing        : ', Opts.ListFile);
 WriteLn;
 WriteLn('Lignes lues    : ', LineCount);
 WriteLn('Symboles       : ', SymCount);
 WriteLn('Sections       : ', SectionCount);
 For I := 1 to SectionCount do
  WriteLn('  ', Sections[I].Name, ' : ', Sections[I].Size,
          ' octets (org=$', IntToHex(Sections[I].Origin, 6), ')');
 WriteLn('Fixups         : ', FixupCount);
 WriteLn('Macros         : ', MacroCount);
 WriteLn('Taille code    : ', CodeSize, ' octets');
 If start_address_set Then
  WriteLn('Adresse debut  : $', IntToHex(start_address, 6));
 WriteLn('Erreurs        : ', ErrorCount);
 WriteLn('Avertissements : ', WarningCount);
End;

{ ============================================================================ }
{ TODO 04 - Table des symboles : etiquettes, EQU, SET                         }
{ ============================================================================ }

{ ---------- Helpers d'affichage ---------- }

Function SymTypeName(T: Integer): String;
{ Retourne le nom du type de symbole pour affichage }
Begin
 Case T of
  SYM_LABEL:    SymTypeName := 'LABEL';
  SYM_EQU:      SymTypeName := 'EQU';
  SYM_SET:      SymTypeName := 'SET';
  SYM_EXTERNAL: SymTypeName := 'XREF';
  SYM_ENTRY:    SymTypeName := 'XDEF';
 Else
  SymTypeName := '???';
 End;
End;

Function SymSectionName(S: Integer): String;
{ Retourne le nom de la section pour affichage }
Begin
 Case S of
  SEC_CODE: SymSectionName := 'CODE';
  SEC_DATA: SymSectionName := 'DATA';
  SEC_BSS:  SymSectionName := 'BSS';
 Else
  SymSectionName := 'ABS';
 End;
End;

{ ---------- Recherche et ajout ---------- }

Function FindSym(Const Name: String): Integer;
{ Recherche un symbole par nom (insensible a la casse).
  Pour les etiquettes locales (.xxx ou @xxx), le nom est prefixe
  par la derniere etiquette globale pour limiter la portee.
  Retourne l'index (1..SymCount) ou 0 si non trouve. }
Var
  I: Integer;
  UName: String;
Begin
 UName := UpCaseStr(Name);
 { Prefixer les etiquettes locales (.xxx) avec la derniere etiquette globale }
 If (Length(UName) > 0) and ((UName[1] = '.') or (UName[1] = '@')) Then
  UName := last_global_sym + UName;
 { Recherche en ordre inverse pour trouver la def la plus recente (SET) }
 For I := SymCount DownTo 1 do
 Begin
  If SymTable[I].Name = UName Then
  Begin
   FindSym := I;
   Exit;
  End;
 End;
 FindSym := 0;
End;

Function AddSym(Const Name: String; Value: LongInt; Section, SymType: Integer;
                LineNum: Integer): Integer;
{ Ajoute un symbole a la table.
  - LABEL/EQU : erreur si deja defini (sauf si meme valeur en passe 2)
  - SET : redefinition autorisee (met a jour la valeur)
  - EXTERNAL/ENTRY : ajout sans valeur definie
  Retourne l'index du symbole ou 0 si erreur. }
Var
  Idx: Integer;
  UName: String;
Begin
 UName := UpCaseStr(Name);
 { Prefixer les etiquettes locales (.xxx) avec la derniere etiquette globale }
 If (Length(UName) > 0) and ((UName[1] = '.') or (UName[1] = '@')) Then
  UName := last_global_sym + UName;
 Idx := FindSym(Name);

 { Si symbole existe deja }
 If Idx <> 0 Then
 Begin
  { SET est redefinissable }
  If (SymType = SYM_SET) Then
  Begin
   SymTable[Idx].Value   := Value;
   SymTable[Idx].Section := Section;
   SymTable[Idx].LineNum := LineNum;
   SymTable[Idx].Defined := True;
   AddSym := Idx;
   Exit;
  End;
  { Si le symbole existant etait un EXTERNAL et on le definit maintenant }
  If (SymTable[Idx].SymType = SYM_EXTERNAL) and (SymType = SYM_LABEL) Then
  Begin
   SymTable[Idx].Value   := Value;
   SymTable[Idx].Section := Section;
   SymTable[Idx].SymType := SYM_LABEL;
   SymTable[Idx].Defined := True;
   SymTable[Idx].LineNum := LineNum;
   AddSym := Idx;
   Exit;
  End;
  { Si le symbole existe et est deja defini, erreur de doublon }
  If SymTable[Idx].Defined Then
  Begin
   Error(LineNum, 1, 'symbole deja defini: ' + UName);
   AddSym := 0;
   Exit;
  End;
  { Symbole existe mais pas encore defini (forward reference) -> definir }
  SymTable[Idx].Value   := Value;
  SymTable[Idx].Section := Section;
  SymTable[Idx].SymType := SymType;
  SymTable[Idx].Defined := True;
  SymTable[Idx].LineNum := LineNum;
  AddSym := Idx;
  Exit;
 End;

 { Nouveau symbole }
 If SymCount >= MAX_SYM Then
 Begin
  Error(LineNum, 1, 'table des symboles pleine (' + IntToStr(MAX_SYM) + ')');
  AddSym := 0;
  Exit;
 End;
 Inc(SymCount);
 SymTable[SymCount].Name       := UName;
 SymTable[SymCount].Value      := Value;
 SymTable[SymCount].Section    := Section;
 SymTable[SymCount].SymType    := SymType;
 SymTable[SymCount].Defined    := (SymType <> SYM_EXTERNAL);
 SymTable[SymCount].Referenced := False;
 SymTable[SymCount].Pass1Value := Value;
 SymTable[SymCount].LineNum    := LineNum;

 { Memoriser la derniere etiquette globale (pour portee locale) }
 If (SymType = SYM_LABEL) and (Length(UName) > 0) and
    (UName[1] <> '.') and (UName[1] <> '@') Then
  last_global_sym := UName;

 AddSym := SymCount;
End;

Procedure UpdateSym(Const Name: String; Value: LongInt);
{ Met a jour la valeur d'un symbole existant (pour SET ou passe 2).
  Verifie la coherence de phase pour les LABEL/EQU en passe 2. }
Var
  Idx: Integer;
  UName: String;
Begin
 UName := UpCaseStr(Name);
 Idx := FindSym(UName);
 If Idx = 0 Then Exit; { Symbole non trouve, rien a faire }

 { Pour SET, mise a jour libre }
 If SymTable[Idx].SymType = SYM_SET Then
 Begin
  SymTable[Idx].Value := Value;
  Exit;
 End;

 { Pour LABEL/EQU, verification de phase : erreur si valeur change }
 If SymTable[Idx].Defined and (SymTable[Idx].Pass1Value <> Value) Then
 Begin
  Error(SymTable[Idx].LineNum, 1,
        'erreur de phase pour symbole ' + UName +
        ' (passe1=' + IntToStr(SymTable[Idx].Pass1Value) +
        ', passe2=' + IntToStr(Value) + ')');
 End;

 SymTable[Idx].Value := Value;
End;

{ ---------- Initialisation ---------- }

Procedure InitSymTable;
{ Initialise la table des symboles et ajoute les symboles predefinis (-d) }
Var
  I: Integer;
Begin
 SymCount := 0;
 last_global_sym := '';
 { Ajouter les symboles predefinis de la ligne de commande (-d) }
 For I := 1 to Opts.DefSymCount do
  AddSym(Opts.DefSymbols[I], 1, SEC_CODE, SYM_EQU, 0);
End;

{ ============================================================================ }
{ TODO 05 - Analyseur d'expressions arithmetiques                              }
{ ============================================================================ }

{ Evaluateur d'expressions recursif avec precedence d'operateurs.
  Niveaux de priorite (croissante) :
    1 : | (OR bit a bit)
    2 : ^ (XOR bit a bit)
    3 : & (AND bit a bit)
    4 : << >> (decalages)
    5 : + - (addition, soustraction)
    6 : * / % (multiplication, division, modulo)
    7 : ~ - (complement, negation unaire)
    8 : primaire (nombre, symbole, *, $, parentheses)
}

Function EvalExpr: LongInt; Forward;

Function EvalPrimary: LongInt;
{ Niveau 8 : nombre litteral, symbole, adresse courante (*, $), parentheses }
Var
  V: LongInt;
  Idx: Integer;
  SymName: String;
Begin
 EvalPrimary := 0;

 Case cur_tok of
  TOK_INTEGER:
  Begin
   EvalPrimary := cur_tok_val;
   NextToken;
  End;

  TOK_CHAR:
  Begin
   EvalPrimary := cur_tok_val;
   NextToken;
  End;

  TOK_STAR:
  Begin
   { * = adresse courante (PC) }
   EvalPrimary := expr_pc;
   NextToken;
  End;

  TOK_IDENT:
  Begin
   { Symbole : rechercher dans la table }
   SymName := cur_tok_str;
   Idx := FindSym(SymName);
   If Idx <> 0 Then
   Begin
    SymTable[Idx].Referenced := True;
    If SymTable[Idx].Defined Then
     EvalPrimary := SymTable[Idx].Value
    Else
    Begin
     { Symbole pas encore defini (forward) - retourner 0 en passe 1 }
     EvalPrimary := 0;
    End;
   End
   Else
   Begin
    { Symbole inconnu : ajouter comme forward reference }
    Idx := AddSym(SymName, 0, SEC_CODE, SYM_LABEL, cur_tok_line);
    If Idx <> 0 Then
    Begin
     SymTable[Idx].Defined := False;
     SymTable[Idx].Referenced := True;
    End;
    EvalPrimary := 0;
   End;
   NextToken;
  End;

  TOK_LPAREN:
  Begin
   { Expression entre parentheses }
   NextToken; { consommer '(' }
   V := EvalExpr;
   If cur_tok = TOK_RPAREN Then
    NextToken { consommer ')' }
   Else
    Error(cur_tok_line, cur_tok_col, 'parenthese fermante attendue');
   EvalPrimary := V;
  End;

 Else
  Error(cur_tok_line, cur_tok_col,
        'expression attendue, token inattendu: ' + cur_tok_str);
  NextToken;
 End;
End;

Function EvalUnary: LongInt;
{ Niveau 7 : operateurs unaires ~ (complement) et - (negation) et + (identite) }
Begin
 If cur_tok = TOK_MINUS Then
 Begin
  NextToken;
  EvalUnary := -EvalUnary;
 End
 Else If cur_tok = TOK_PLUS Then
 Begin
  NextToken;
  EvalUnary := EvalUnary;
 End
 Else If cur_tok = TOK_TILDE Then
 Begin
  NextToken;
  EvalUnary := Not EvalUnary;
 End
 Else
  EvalUnary := EvalPrimary;
End;

Function EvalMulDiv: LongInt;
{ Niveau 6 : *, /, % (multiplication, division, modulo) }
Var
  Left, Right: LongInt;
Begin
 Left := EvalUnary;
 While cur_tok in [TOK_STAR, TOK_SLASH, TOK_PERCENT] do
 Begin
  Case cur_tok of
   TOK_STAR:
   Begin
    NextToken;
    Left := Left * EvalUnary;
   End;
   TOK_SLASH:
   Begin
    NextToken;
    Right := EvalUnary;
    If Right = 0 Then
    Begin
     Error(cur_tok_line, cur_tok_col, 'division par zero');
     Left := 0;
    End
    Else
     Left := Left div Right;
   End;
   TOK_PERCENT:
   Begin
    NextToken;
    Right := EvalUnary;
    If Right = 0 Then
    Begin
     Error(cur_tok_line, cur_tok_col, 'modulo par zero');
     Left := 0;
    End
    Else
     Left := Left mod Right;
   End;
  End;
 End;
 EvalMulDiv := Left;
End;

Function EvalAddSub: LongInt;
{ Niveau 5 : +, - (addition, soustraction) }
Var Left: LongInt;
Begin
 Left := EvalMulDiv;
 While cur_tok in [TOK_PLUS, TOK_MINUS] do
 Begin
  If cur_tok = TOK_PLUS Then
  Begin
   NextToken;
   Left := Left + EvalMulDiv;
  End
  Else
  Begin
   NextToken;
   Left := Left - EvalMulDiv;
  End;
 End;
 EvalAddSub := Left;
End;

Function EvalShift: LongInt;
{ Niveau 4 : <<, >> (decalages gauche/droite) }
Var
  Left: LongInt;
  Shift: LongInt;
Begin
 Left := EvalAddSub;
 While cur_tok in [TOK_LSHIFT, TOK_RSHIFT] do
 Begin
  If cur_tok = TOK_LSHIFT Then
  Begin
   NextToken;
   Shift := EvalAddSub;
   If (Shift >= 0) and (Shift < 32) Then
    Left := Left shl Shift
   Else
   Begin
    Warning(cur_tok_line, cur_tok_col,
            'decalage hors limites: ' + IntToStr(Shift));
    Left := 0;
   End;
  End
  Else
  Begin
   NextToken;
   Shift := EvalAddSub;
   If (Shift >= 0) and (Shift < 32) Then
    Left := Left shr Shift
   Else
   Begin
    Warning(cur_tok_line, cur_tok_col,
            'decalage hors limites: ' + IntToStr(Shift));
    Left := 0;
   End;
  End;
 End;
 EvalShift := Left;
End;

Function EvalAnd: LongInt;
{ Niveau 3 : & (AND bit a bit) }
Var Left: LongInt;
Begin
 Left := EvalShift;
 While cur_tok = TOK_AMPERSAND do
 Begin
  NextToken;
  Left := Left and EvalShift;
 End;
 EvalAnd := Left;
End;

Function EvalXor: LongInt;
{ Niveau 2 : ^ (XOR bit a bit) }
Var Left: LongInt;
Begin
 Left := EvalAnd;
 While cur_tok = TOK_CARET do
 Begin
  NextToken;
  Left := Left xor EvalAnd;
 End;
 EvalXor := Left;
End;

Function EvalOr: LongInt;
{ Niveau 1 : | (OR bit a bit) }
Var Left: LongInt;
Begin
 Left := EvalXor;
 While cur_tok = TOK_PIPE do
 Begin
  NextToken;
  Left := Left or EvalXor;
 End;
 EvalOr := Left;
End;

Function EvalExpr: LongInt;
{ Point d'entree de l'evaluateur d'expressions.
  Verifie la profondeur de recursion. }
Begin
 Inc(expr_depth);
 If expr_depth > MAX_EXPR_DEPTH Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'expression trop profonde (>' + IntToStr(MAX_EXPR_DEPTH) + ')');
  EvalExpr := 0;
  Dec(expr_depth);
  Exit;
 End;
 EvalExpr := EvalOr;
 Dec(expr_depth);
End;

Function EvalExprCheck(Size: Integer): LongInt;
{ Evalue une expression et verifie les debordements selon la taille.
  Size = SIZE_BYTE (1), SIZE_WORD (2) ou SIZE_LONG (4). }
Var V: LongInt;
Begin
 V := EvalExpr;
 Case Size of
  SIZE_BYTE:
   If (V < -128) or (V > 255) Then
    Warning(cur_tok_line, cur_tok_col,
            'valeur hors limites 8 bits: ' + IntToStr(V));
  SIZE_WORD:
   If (V < -32768) or (V > 65535) Then
    Warning(cur_tok_line, cur_tok_col,
            'valeur hors limites 16 bits: ' + IntToStr(V));
  { SIZE_LONG : pas de verification, LongInt suffit }
 End;
 EvalExprCheck := V;
End;

{ ============================================================================ }
{ TODO 06 - Modes d'adressage : analyse et encodage                            }
{ ============================================================================ }

{ Analyse des 14 modes d'adressage du 68000 et encodage EA (mode:3, reg:3).
  ParseOperand lit les tokens et remplit un TOperand.
  EncodeEA produit les 6 bits mode/reg.
  CalcExtWords compte les mots d'extension (0, 1 ou 2).
  EmitExtWords emet les mots d'extension via Emit16/Emit32 (TODO 07).
  CheckEAMask valide qu'un mode est permis par l'instruction.
  ParseRegList analyse D0-D3/A0-A2 pour MOVEM. }

{ Forward declarations pour le generateur de code (TODO 07) }
Procedure Emit8(B: Byte); Forward;
Procedure Emit16(W: Word); Forward;
Procedure Emit32(L: LongInt); Forward;

Procedure InitOperand(Var Op: TOperand);
{ Initialise un operande a un etat neutre }
Begin
 Op.Mode    := AM_NONE;
 Op.Reg     := REG_NONE;
 Op.Disp    := 0;
 Op.IdxReg  := REG_NONE;
 Op.IdxSize := SIZE_WORD;
 Op.Imm32   := 0;
 Op.SymRef  := '';
 Op.ExprStr := '';
End;

{ ---------- Encodage et mots d'extension ---------- }

Function EncodeEA(Const Op: TOperand): Integer;
{ Encode un operande en 6 bits mode:3 reg:3 pour le champ EA.
  Retourne (mode shl 3) or reg, ou -1 si mode non encodable. }
Var Md, Rg: Integer;
Begin
 Md := -1; Rg := 0;
 Case Op.Mode of
  AM_DATA_REG:
  Begin
   Md := 0; Rg := Op.Reg;  { mode 000, reg = Dn }
  End;
  AM_ADDR_REG:
  Begin
   Md := 1; Rg := Op.Reg - REG_A0; { mode 001, reg = An }
  End;
  AM_ADDR_IND:
  Begin
   Md := 2; Rg := Op.Reg - REG_A0; { mode 010, reg = An }
  End;
  AM_ADDR_IND_POST:
  Begin
   Md := 3; Rg := Op.Reg - REG_A0; { mode 011, reg = An }
  End;
  AM_ADDR_IND_PRE:
  Begin
   Md := 4; Rg := Op.Reg - REG_A0; { mode 100, reg = An }
  End;
  AM_ADDR_IND_DISP:
  Begin
   Md := 5; Rg := Op.Reg - REG_A0; { mode 101, reg = An }
  End;
  AM_ADDR_IND_IDX:
  Begin
   Md := 6; Rg := Op.Reg - REG_A0; { mode 110, reg = An }
  End;
  AM_ABS_SHORT:
  Begin
   Md := 7; Rg := 0; { mode 111, reg = 000 }
  End;
  AM_ABS_LONG:
  Begin
   Md := 7; Rg := 1; { mode 111, reg = 001 }
  End;
  AM_PC_DISP:
  Begin
   Md := 7; Rg := 2; { mode 111, reg = 010 }
  End;
  AM_PC_IDX:
  Begin
   Md := 7; Rg := 3; { mode 111, reg = 011 }
  End;
  AM_IMMEDIATE:
  Begin
   Md := 7; Rg := 4; { mode 111, reg = 100 }
  End;
 Else
  { AM_NONE, AM_REG_LIST, AM_SR_CCR : pas d'encodage EA standard }
  EncodeEA := -1;
  Exit;
 End;
 EncodeEA := (Md shl 3) or Rg;
End;

Function CalcExtWords(Const Op: TOperand; OpSize: Integer): Integer;
{ Nombre de mots d'extension pour un operande :
  0 : Dn, An, (An), (An)+, -(An)
  1 : d16(An), d16(PC), d8(An,Xn), d8(PC,Xn), xxx.W
  2 : xxx.L, #imm.L
  Pour #imm : 1 mot pour .B/.W, 2 mots pour .L }
Begin
 Case Op.Mode of
  AM_DATA_REG,
  AM_ADDR_REG,
  AM_ADDR_IND,
  AM_ADDR_IND_POST,
  AM_ADDR_IND_PRE:
   CalcExtWords := 0;

  AM_ADDR_IND_DISP,
  AM_PC_DISP:
   CalcExtWords := 1;

  AM_ADDR_IND_IDX,
  AM_PC_IDX:
   CalcExtWords := 1; { brief extension word }

  AM_ABS_SHORT:
   CalcExtWords := 1;

  AM_ABS_LONG:
   CalcExtWords := 2;

  AM_IMMEDIATE:
  Begin
   If OpSize = SIZE_LONG Then
    CalcExtWords := 2
   Else
    CalcExtWords := 1;
  End;
 Else
  CalcExtWords := 0;
 End;
End;

Function EncodeExtWordIdx(Const Op: TOperand): Integer;
{ Calcule le brief extension word pour les modes indexes :
  bit 15    : D/A (0=Dn, 1=An)
  bits 14-12: numero du registre index (0-7)
  bit 11    : W/L (0=word, 1=long)
  bits 10-8 : 000
  bits 7-0  : deplacement signe 8 bits }
Var W: Integer;
    IdxN: Integer;
Begin
 W := 0;
 { D/A et numero }
 If Op.IdxReg >= REG_A0 Then
 Begin
  W := W or $8000; { A register }
  IdxN := Op.IdxReg - REG_A0;
 End
 Else
  IdxN := Op.IdxReg; { D register }
 W := W or ((IdxN and 7) shl 12);
 { W/L }
 If Op.IdxSize = SIZE_LONG Then
  W := W or $0800;
 { Deplacement 8 bits signe }
 W := W or (Op.Disp and $FF);
 EncodeExtWordIdx := W;
End;

Procedure EmitExtWords(Const Op: TOperand; OpSize: Integer);
{ Emettre les mots d'extension d'un operande dans la section courante.
  Appele apres l'emission du mot d'instruction principal.
  Les mots d'extension dependent du mode d'adressage :
  - d16(An), d16(PC) : 1 mot d'extension (deplacement 16 bits)
  - d8(An,Xn), d8(PC,Xn) : 1 mot d'extension (brief extension word)
  - xxx.W : 1 mot d'extension (adresse 16 bits)
  - xxx.L : 2 mots d'extension (adresse 32 bits)
  - #imm : 1 mot (.B/.W) ou 2 mots (.L) d'extension }
Begin
 Case Op.Mode of
  AM_ADDR_IND_DISP,
  AM_PC_DISP:
   Emit16(Word(Op.Disp and $FFFF));

  AM_ADDR_IND_IDX,
  AM_PC_IDX:
   Emit16(Word(EncodeExtWordIdx(Op)));

  AM_ABS_SHORT:
   Emit16(Word(Op.Disp and $FFFF));

  AM_ABS_LONG:
   Emit32(Op.Disp);

  AM_IMMEDIATE:
  Begin
   If OpSize = SIZE_LONG Then
    Emit32(Op.Imm32)
   Else
    Emit16(Word(Op.Imm32 and $FFFF));
  End;
 End;
End;

Function CheckEAMask(Const Op: TOperand; Mask: Integer): Boolean;
{ Verifie que le mode d'adressage de Op est autorise par le masque.
  Chaque bit du masque correspond a un mode AM_xxx :
    bit 0  = AM_DATA_REG      bit 7  = AM_ABS_SHORT
    bit 1  = AM_ADDR_REG      bit 8  = AM_ABS_LONG
    bit 2  = AM_ADDR_IND      bit 9  = AM_PC_DISP
    bit 3  = AM_ADDR_IND_POST bit 10 = AM_PC_IDX
    bit 4  = AM_ADDR_IND_PRE  bit 11 = AM_IMMEDIATE
    bit 5  = AM_ADDR_IND_DISP bit 12 = AM_REG_LIST
    bit 6  = AM_ADDR_IND_IDX  bit 13 = AM_SR_CCR }
Var BitPos: Integer;
Begin
 BitPos := Op.Mode - 1; { AM_DATA_REG=1 -> bit 0 etc }
 If (BitPos >= 0) and (BitPos < 16) Then
  CheckEAMask := (Mask and (1 shl BitPos)) <> 0
 Else
  CheckEAMask := False;
End;

{ Masques d'adressage predefinis couramment utilises }
Const
  { Tous les modes de donnees (pas An) }
  EA_DATA     = $0FFD;  { Dn, (An), (An)+, -(An), d(An), d(An,Xn), }
                         { xxx.W, xxx.L, d(PC), d(PC,Xn), #imm      }
  { Tous les modes memoire (pas Dn ni An) }
  EA_MEMORY   = $0FFC;  { (An), (An)+, -(An), d(An), d(An,Xn),      }
                         { xxx.W, xxx.L, d(PC), d(PC,Xn), #imm      }
  { Modes controlables (adressables sans effet de bord) }
  EA_CONTROL  = $0BE4;  { (An), d(An), d(An,Xn),                    }
                         { xxx.W, xxx.L, d(PC), d(PC,Xn)             }
  { Modes alterables (pas PC-relative, pas immediat) }
  EA_ALTER    = $01FF;  { Dn, An, (An), (An)+, -(An), d(An),        }
                         { d(An,Xn), xxx.W, xxx.L                    }
  { Donnees alterables }
  EA_DATA_ALT = $01FD;  { Dn, (An), (An)+, -(An), d(An),            }
                         { d(An,Xn), xxx.W, xxx.L                    }
  { Memoire alterable }
  EA_MEM_ALT  = $01FC;  { (An), (An)+, -(An), d(An),                }
                         { d(An,Xn), xxx.W, xxx.L                    }
  { Registres uniquement }
  EA_DN_ONLY  = $0001;  { Dn seulement }
  EA_AN_ONLY  = $0002;  { An seulement }
  { Tous les modes }
  EA_ALL      = $3FFF;  { Tous les 14 modes }

{ ---------- Analyse des operandes ---------- }

Function ParseRegNum(Const Name: String): Integer;
{ Retourne le numero de registre (REG_xxx) ou REG_NONE }
Var R: Integer;
Begin
 If IsRegister(Name, R) Then
  ParseRegNum := R
 Else
  ParseRegNum := REG_NONE;
End;

Procedure ParseOperand(Var Op: TOperand);
{ Analyse un operande a partir de la position courante du lexeur.
  Remplit les champs Mode, Reg, Disp, IdxReg, IdxSize, Imm32, SymRef.

  Syntaxes reconnues :
    Dn              -> AM_DATA_REG
    An              -> AM_ADDR_REG
    SR, CCR         -> AM_SR_CCR
    #expr           -> AM_IMMEDIATE
    -(An)           -> AM_ADDR_IND_PRE
    (An)            -> AM_ADDR_IND
    (An)+           -> AM_ADDR_IND_POST
    d16(An)         -> AM_ADDR_IND_DISP
    d8(An,Xn.s)    -> AM_ADDR_IND_IDX
    d16(PC)         -> AM_PC_DISP
    d8(PC,Xn.s)    -> AM_PC_IDX
    expr.W          -> AM_ABS_SHORT
    expr.L          -> AM_ABS_LONG
    expr            -> AM_ABS_LONG (defaut) ou AM_ABS_SHORT si < $FFFF
}
Var
  RegN: Integer;
  BaseReg: Integer;
  IdxR: Integer;
  IdxS: Integer;
  V: LongInt;
  SaveLine, SaveCol: Integer;
Begin
 InitOperand(Op);

 { --- #imm : immediat --- }
 If cur_tok = TOK_HASH Then
 Begin
  NextToken; { consommer '#' }
  Op.Mode  := AM_IMMEDIATE;
  Op.Imm32 := EvalExpr;
  Exit;
 End;

 { --- -(An) : pre-decrement --- }
 If cur_tok = TOK_MINUS Then
 Begin
  { Sauvegarder position au cas ou ce n'est pas -(An) }
  SaveLine := cur_tok_line;
  SaveCol  := cur_tok_col;
  NextToken; { consommer '-' }
  If cur_tok = TOK_LPAREN Then
  Begin
   NextToken; { consommer '(' }
   If cur_tok = TOK_REGISTER Then
   Begin
    RegN := ParseRegNum(cur_tok_str);
    If (RegN >= REG_A0) and (RegN <= REG_A7) Then
    Begin
     Op.Mode := AM_ADDR_IND_PRE;
     Op.Reg  := RegN;
     NextToken; { consommer registre }
     If cur_tok = TOK_RPAREN Then
      NextToken { consommer ')' }
     Else
      Error(cur_tok_line, cur_tok_col, ') attendue apres -(An)');
     Exit;
    End;
   End;
   { Pas un registre d'adresse valide : traiter comme expression unaire }
   Error(SaveLine, SaveCol,
         'registre d''adresse attendu apres -(');
   Exit;
  End;
  { Pas '(' apres '-' : on retombe dans expression normale }
  { Le '-' a deja ete consomme, on evalue l'expression et on la negate }
  V := -EvalExpr;
  { Verifier si suivi de (An) ou (An,Xn) ou (PC) comme pour expr(An) }
  If cur_tok = TOK_LPAREN Then
  Begin
   NextToken; { consommer '(' }
   If cur_tok = TOK_REGISTER Then
   Begin
    BaseReg := ParseRegNum(cur_tok_str);
    NextToken;
    If BaseReg = REG_PC Then
    Begin
     If cur_tok = TOK_COMMA Then
     Begin
      NextToken;
      If cur_tok = TOK_REGISTER Then
      Begin
       IdxR := ParseRegNum(cur_tok_str);
       IdxS := SIZE_WORD;
       If cur_tok_size = SIZE_LONG Then IdxS := SIZE_LONG;
       NextToken;
       Op.Mode := AM_PC_IDX; Op.Reg := REG_PC;
       Op.Disp := V; Op.IdxReg := IdxR; Op.IdxSize := IdxS;
      End;
     End
     Else
     Begin
      Op.Mode := AM_PC_DISP; Op.Reg := REG_PC; Op.Disp := V;
     End;
    End
    Else If (BaseReg >= REG_A0) and (BaseReg <= REG_A7) Then
    Begin
     If cur_tok = TOK_COMMA Then
     Begin
      NextToken;
      If cur_tok = TOK_REGISTER Then
      Begin
       IdxR := ParseRegNum(cur_tok_str);
       IdxS := SIZE_WORD;
       If cur_tok_size = SIZE_LONG Then IdxS := SIZE_LONG;
       NextToken;
       Op.Mode := AM_ADDR_IND_IDX; Op.Reg := BaseReg;
       Op.Disp := V; Op.IdxReg := IdxR; Op.IdxSize := IdxS;
      End;
     End
     Else
     Begin
      Op.Mode := AM_ADDR_IND_DISP; Op.Reg := BaseReg; Op.Disp := V;
     End;
    End
    Else
     Error(cur_tok_line, cur_tok_col,
           'registre d''adresse ou PC attendu');
    If cur_tok = TOK_RPAREN Then NextToken;
    Exit;
   End;
  End;
  Op.Mode := AM_ABS_LONG;
  Op.Disp := V;
  If (V >= -32768) and (V <= 32767) Then
   Op.Mode := AM_ABS_SHORT;
  Exit;
 End;

 { --- (An), (An)+, d(An,Xn), d(PC), d(PC,Xn) : parenthese en tete --- }
 If cur_tok = TOK_LPAREN Then
 Begin
  NextToken; { consommer '(' }
  If cur_tok = TOK_REGISTER Then
  Begin
   RegN := ParseRegNum(cur_tok_str);
   NextToken; { consommer registre }

   If RegN = REG_PC Then
   Begin
    { d(PC) ou d(PC,Xn.s) }
    If cur_tok = TOK_RPAREN Then
    Begin
     NextToken; { consommer ')' }
     Op.Mode := AM_PC_DISP;
     Op.Reg  := REG_PC;
     Op.Disp := 0;
     Exit;
    End
    Else If cur_tok = TOK_COMMA Then
    Begin
     { (PC,Xn.s) -> PC index avec disp=0 }
     NextToken; { consommer ',' }
     If cur_tok = TOK_REGISTER Then
     Begin
      IdxR := ParseRegNum(cur_tok_str);
      IdxS := SIZE_WORD;
      If cur_tok_size = SIZE_LONG Then
       IdxS := SIZE_LONG
      Else If cur_tok_size = SIZE_WORD Then
       IdxS := SIZE_WORD;
      NextToken; { consommer registre index }
      Op.Mode    := AM_PC_IDX;
      Op.Reg     := REG_PC;
      Op.IdxReg  := IdxR;
      Op.IdxSize := IdxS;
      Op.Disp    := 0;
      If cur_tok = TOK_RPAREN Then
       NextToken { consommer ')' }
      Else
       Error(cur_tok_line, cur_tok_col, ') attendue apres (PC,Xn)');
      Exit;
     End;
    End;
   End
   Else If (RegN >= REG_A0) and (RegN <= REG_A7) Then
   Begin
    { (An), (An)+, (An,Xn.s) }
    If cur_tok = TOK_RPAREN Then
    Begin
     NextToken; { consommer ')' }
     { Verifier si (An)+ }
     If cur_tok = TOK_PLUS Then
     Begin
      Op.Mode := AM_ADDR_IND_POST;
      Op.Reg  := RegN;
      NextToken; { consommer '+' }
      Exit;
     End;
     { Sinon (An) simple }
     Op.Mode := AM_ADDR_IND;
     Op.Reg  := RegN;
     Exit;
    End
    Else If cur_tok = TOK_COMMA Then
    Begin
     { (An,Xn.s) -> index avec disp=0 }
     NextToken; { consommer ',' }
     If cur_tok = TOK_REGISTER Then
     Begin
      IdxR := ParseRegNum(cur_tok_str);
      IdxS := SIZE_WORD;
      If cur_tok_size = SIZE_LONG Then
       IdxS := SIZE_LONG
      Else If cur_tok_size = SIZE_WORD Then
       IdxS := SIZE_WORD;
      NextToken; { consommer registre index }
      Op.Mode    := AM_ADDR_IND_IDX;
      Op.Reg     := RegN;
      Op.IdxReg  := IdxR;
      Op.IdxSize := IdxS;
      Op.Disp    := 0;
      If cur_tok = TOK_RPAREN Then
       NextToken { consommer ')' }
      Else
       Error(cur_tok_line, cur_tok_col, ') attendue apres (An,Xn)');
      Exit;
     End;
    End;
   End;
   { Autre registre entre parentheses : erreur }
   Error(cur_tok_line, cur_tok_col,
         'registre d''adresse ou PC attendu entre parentheses');
   Exit;
  End;
  { Pas un registre apres '(' : erreur de syntaxe }
  Error(cur_tok_line, cur_tok_col,
        'registre attendu apres (');
  Exit;
 End;

 { --- Registre seul : Dn, An, SR, CCR --- }
 If cur_tok = TOK_REGISTER Then
 Begin
  RegN := ParseRegNum(cur_tok_str);
  If (RegN >= REG_D0) and (RegN <= REG_D7) Then
  Begin
   Op.Mode := AM_DATA_REG;
   Op.Reg  := RegN;
  End
  Else If (RegN >= REG_A0) and (RegN <= REG_A7) Then
  Begin
   Op.Mode := AM_ADDR_REG;
   Op.Reg  := RegN;
  End
  Else If (RegN = REG_SR) or (RegN = REG_CCR) Then
  Begin
   Op.Mode := AM_SR_CCR;
   Op.Reg  := RegN;
  End
  Else
  Begin
   { USP, SSP -> AM_ADDR_REG (cas special) }
   Op.Mode := AM_SR_CCR;
   Op.Reg  := RegN;
  End;
  NextToken; { consommer registre }
  Exit;
 End;

 { --- expr, expr(An), expr(An,Xn.s), expr(PC), expr(PC,Xn.s) --- }
 { L'expression peut etre un symbole, nombre, ou expression complexe }
 V := EvalExpr;

 If cur_tok = TOK_LPAREN Then
 Begin
  { expr(An), expr(An,Xn), expr(PC), expr(PC,Xn) }
  NextToken; { consommer '(' }
  If cur_tok = TOK_REGISTER Then
  Begin
   BaseReg := ParseRegNum(cur_tok_str);
   NextToken; { consommer registre }

   If BaseReg = REG_PC Then
   Begin
    If cur_tok = TOK_COMMA Then
    Begin
     { expr(PC,Xn.s) }
     NextToken; { consommer ',' }
     If cur_tok = TOK_REGISTER Then
     Begin
      IdxR := ParseRegNum(cur_tok_str);
      IdxS := SIZE_WORD;
      If cur_tok_size = SIZE_LONG Then
       IdxS := SIZE_LONG
      Else If cur_tok_size = SIZE_WORD Then
       IdxS := SIZE_WORD;
      NextToken; { consommer registre index }
      Op.Mode    := AM_PC_IDX;
      Op.Reg     := REG_PC;
      Op.Disp    := V;
      Op.IdxReg  := IdxR;
      Op.IdxSize := IdxS;
      If (V < -128) or (V > 127) Then
       Warning(cur_tok_line, cur_tok_col,
               'deplacement index hors limites 8 bits: ' + IntToStr(V));
     End
     Else
      Error(cur_tok_line, cur_tok_col,
            'registre index attendu apres ,');
    End
    Else
    Begin
     { expr(PC) }
     Op.Mode := AM_PC_DISP;
     Op.Reg  := REG_PC;
     Op.Disp := V;
     If (V < -32768) or (V > 32767) Then
      Warning(cur_tok_line, cur_tok_col,
              'deplacement PC hors limites 16 bits: ' + IntToStr(V));
    End;
   End
   Else If (BaseReg >= REG_A0) and (BaseReg <= REG_A7) Then
   Begin
    If cur_tok = TOK_COMMA Then
    Begin
     { expr(An,Xn.s) }
     NextToken; { consommer ',' }
     If cur_tok = TOK_REGISTER Then
     Begin
      IdxR := ParseRegNum(cur_tok_str);
      IdxS := SIZE_WORD;
      If cur_tok_size = SIZE_LONG Then
       IdxS := SIZE_LONG
      Else If cur_tok_size = SIZE_WORD Then
       IdxS := SIZE_WORD;
      NextToken; { consommer registre index }
      Op.Mode    := AM_ADDR_IND_IDX;
      Op.Reg     := BaseReg;
      Op.Disp    := V;
      Op.IdxReg  := IdxR;
      Op.IdxSize := IdxS;
      If (V < -128) or (V > 127) Then
       Warning(cur_tok_line, cur_tok_col,
               'deplacement index hors limites 8 bits: ' + IntToStr(V));
     End
     Else
      Error(cur_tok_line, cur_tok_col,
            'registre index attendu apres ,');
    End
    Else
    Begin
     { expr(An) }
     Op.Mode := AM_ADDR_IND_DISP;
     Op.Reg  := BaseReg;
     Op.Disp := V;
     If (V < -32768) or (V > 32767) Then
      Warning(cur_tok_line, cur_tok_col,
              'deplacement hors limites 16 bits: ' + IntToStr(V));
    End;
   End
   Else
    Error(cur_tok_line, cur_tok_col,
          'registre d''adresse ou PC attendu dans le mode d''adressage');

   If cur_tok = TOK_RPAREN Then
    NextToken { consommer ')' }
   Else
    Error(cur_tok_line, cur_tok_col, ') attendue');
   Exit;
  End
  Else
  Begin
   Error(cur_tok_line, cur_tok_col,
         'registre attendu apres ( dans le mode d''adressage');
   Exit;
  End;
 End;

 { Pas de parenthese : adresse absolue }
 { Choisir short ou long selon la valeur }
 Op.Disp := V;
 If (V >= 0) and (V <= $FFFF) Then
  Op.Mode := AM_ABS_SHORT
 Else
  Op.Mode := AM_ABS_LONG;
End;

{ ---------- Analyse de liste de registres pour MOVEM ---------- }

Function ParseRegList(Const S: String): Word;
{ Analyse une chaine de type D0-D3/A0-A2 et retourne un masque 16 bits.
  Bits 0-7  = D0-D7
  Bits 8-15 = A0-A7
  Formats : reg, reg-reg, reg/reg, reg-reg/reg-reg
}
Var
  Mask: Word;
  I, Len: Integer;
  U: String;
  RegA, RegB: Integer;
  J: Integer;

 Function ParseOneReg(Var Pos: Integer): Integer;
 { Lit un nom de registre a partir de Pos dans U, retourne REG_xxx }
 Var Name: String;
     R: Integer;
 Begin
  ParseOneReg := REG_NONE;
  Name := '';
  While (Pos <= Len) and (U[Pos] in ['A'..'Z', '0'..'9']) do
  Begin
   Name := Name + U[Pos];
   Inc(Pos);
  End;
  If IsRegister(Name, R) Then
   ParseOneReg := R;
 End;

Begin
 Mask := 0;
 U := UpCaseStr(S);
 Len := Length(U);
 I := 1;

 While I <= Len do
 Begin
  { Sauter espaces }
  While (I <= Len) and (U[I] = ' ') do Inc(I);
  If I > Len Then Break;

  { Lire un registre }
  RegA := ParseOneReg(I);
  If RegA = REG_NONE Then
  Begin
   Warning(0, 0, 'registre invalide dans la liste: ' + S);
   ParseRegList := Mask;
   Exit;
  End;

  { Verifier si c'est une plage reg-reg }
  If (I <= Len) and (U[I] = '-') Then
  Begin
   Inc(I); { consommer '-' }
   RegB := ParseOneReg(I);
   If RegB = REG_NONE Then
   Begin
    Warning(0, 0, 'registre invalide dans la plage: ' + S);
    ParseRegList := Mask;
    Exit;
   End;
   { Remplir la plage }
   If RegA <= RegB Then
    For J := RegA to RegB do
    Begin
     If J <= REG_D7 Then
      Mask := Mask or Word(1 shl J)
     Else If (J >= REG_A0) and (J <= REG_A7) Then
      Mask := Mask or Word(1 shl (J - REG_A0 + 8));
    End
   Else
    For J := RegB to RegA do
    Begin
     If J <= REG_D7 Then
      Mask := Mask or Word(1 shl J)
     Else If (J >= REG_A0) and (J <= REG_A7) Then
      Mask := Mask or Word(1 shl (J - REG_A0 + 8));
    End;
  End
  Else
  Begin
   { Registre seul }
   If RegA <= REG_D7 Then
    Mask := Mask or Word(1 shl RegA)
   Else If (RegA >= REG_A0) and (RegA <= REG_A7) Then
    Mask := Mask or Word(1 shl (RegA - REG_A0 + 8));
  End;

  { Sauter '/' ou ',' separateur }
  If (I <= Len) and (U[I] in ['/', ',']) Then
   Inc(I);
 End;

 ParseRegList := Mask;
End;

Function OperandModeName(Mode: Integer): String;
{ Retourne un nom lisible pour un mode d'adressage }
Begin
 Case Mode of
  AM_NONE:          OperandModeName := 'NONE';
  AM_DATA_REG:      OperandModeName := 'Dn';
  AM_ADDR_REG:      OperandModeName := 'An';
  AM_ADDR_IND:      OperandModeName := '(An)';
  AM_ADDR_IND_POST: OperandModeName := '(An)+';
  AM_ADDR_IND_PRE:  OperandModeName := '-(An)';
  AM_ADDR_IND_DISP: OperandModeName := 'd(An)';
  AM_ADDR_IND_IDX:  OperandModeName := 'd(An,Xn)';
  AM_ABS_SHORT:     OperandModeName := 'abs.W';
  AM_ABS_LONG:      OperandModeName := 'abs.L';
  AM_PC_DISP:       OperandModeName := 'd(PC)';
  AM_PC_IDX:        OperandModeName := 'd(PC,Xn)';
  AM_IMMEDIATE:     OperandModeName := '#imm';
  AM_REG_LIST:      OperandModeName := 'reglist';
  AM_SR_CCR:        OperandModeName := 'SR/CCR';
 Else
  OperandModeName := '???';
 End;
End;

{ ============================================================================ }
{ TODO 07 - Generateur de code : emission et sections                          }
{ ============================================================================ }

{ Gestion des sections (CODE, DATA, BSS) et emission de code big-endian.
  Chaque section possede un buffer dynamique, une adresse d'origine et
  un offset courant. Les fixups enregistrent les references a resoudre
  lors de la passe 2 (symboles non encore definis, references PC-relatives). }

{ ---------- Initialisation et gestion des sections ---------- }

Procedure InitSections;
{ Cree les trois sections par defaut : CODE, DATA, BSS.
  Alloue les buffers dynamiques. CurSection pointe sur CODE. }
Begin
 SectionCount := 3;
 CurSection   := 1;

 { Section 1 : CODE (text) }
 Sections[1].Name    := 'CODE';
 Sections[1].SecType := SEC_CODE;
 Sections[1].Origin  := 0;
 Sections[1].CurAddr := 0;
 Sections[1].Size    := 0;
 New(Sections[1].Buf);
 FillChar(Sections[1].Buf^, MAX_SEC_SIZE, 0);

 { Section 2 : DATA }
 Sections[2].Name    := 'DATA';
 Sections[2].SecType := SEC_DATA;
 Sections[2].Origin  := 0;
 Sections[2].CurAddr := 0;
 Sections[2].Size    := 0;
 New(Sections[2].Buf);
 FillChar(Sections[2].Buf^, MAX_SEC_SIZE, 0);

 { Section 3 : BSS }
 Sections[3].Name    := 'BSS';
 Sections[3].SecType := SEC_BSS;
 Sections[3].Origin  := 0;
 Sections[3].CurAddr := 0;
 Sections[3].Size    := 0;
 New(Sections[3].Buf);
 FillChar(Sections[3].Buf^, MAX_SEC_SIZE, 0);

 { Initialiser les fixups }
 FixupCount := 0;
End;

Procedure FreeSections;
{ Libere les buffers dynamiques des sections }
Var I: Integer;
Begin
 For I := 1 to SectionCount do
  If Sections[I].Buf <> Nil Then
  Begin
   Dispose(Sections[I].Buf);
   Sections[I].Buf := Nil;
  End;
End;

Function FindSection(Const Name: String): Integer;
{ Recherche une section par nom (insensible a la casse).
  Retourne l'index (1..SectionCount) ou 0 si non trouvee. }
Var
  I: Integer;
  UName: String;
Begin
 UName := UpCaseStr(Name);
 FindSection := 0;
 For I := 1 to SectionCount do
  If UpCaseStr(Sections[I].Name) = UName Then
  Begin
   FindSection := I;
   Exit;
  End;
End;

Procedure SetSection(Const Name: String; SecType: Integer);
{ Change la section courante. Cree la section si elle n'existe pas. }
Var Idx: Integer;
Begin
 Idx := FindSection(Name);
 If Idx > 0 Then
 Begin
  CurSection := Idx;
  Exit;
 End;
 { Creer une nouvelle section }
 If SectionCount >= MAX_SECTIONS Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'trop de sections (max ' +
        IntToStr(MAX_SECTIONS) + ')');
  Exit;
 End;
 Inc(SectionCount);
 Sections[SectionCount].Name    := Name;
 Sections[SectionCount].SecType := SecType;
 Sections[SectionCount].Origin  := 0;
 Sections[SectionCount].CurAddr := 0;
 Sections[SectionCount].Size    := 0;
 New(Sections[SectionCount].Buf);
 FillChar(Sections[SectionCount].Buf^, MAX_SEC_SIZE, 0);
 CurSection := SectionCount;
End;

{ ---------- Emission de code (big-endian, Motorola byte order) ---------- }

Procedure Emit8(B: Byte);
{ Emettre un octet dans la section courante }
Begin
 If (CurSection < 1) or (CurSection > SectionCount) Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'pas de section courante');
  Exit;
 End;
 If Sections[CurSection].CurAddr >= MAX_SEC_SIZE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'section pleine (' +
        IntToStr(MAX_SEC_SIZE) + ' octets max)');
  Exit;
 End;
 Sections[CurSection].Buf^[Sections[CurSection].CurAddr] := B;
 Inc(Sections[CurSection].CurAddr);
 If Sections[CurSection].CurAddr > Sections[CurSection].Size Then
  Sections[CurSection].Size := Sections[CurSection].CurAddr;
End;

Procedure Emit16(W: Word);
{ Emettre un mot 16 bits en big-endian (octet de poids fort d'abord) }
Begin
 Emit8(Byte(W shr 8));  { poids fort }
 Emit8(Byte(W and $FF)); { poids faible }
End;

Procedure Emit32(L: LongInt);
{ Emettre un long mot 32 bits en big-endian }
Begin
 Emit16(Word(L shr 16));   { mot de poids fort }
 Emit16(Word(L and $FFFF)); { mot de poids faible }
End;

Procedure EmitBytes(Const Buf: Array of Byte; Len: Integer);
{ Emettre un bloc d'octets dans la section courante }
Var I: Integer;
Begin
 For I := 0 to Len - 1 do
  Emit8(Buf[I]);
End;

{ ---------- Adresse courante et alignement ---------- }

Function GetPC: LongInt;
{ Retourne l'adresse courante : Origin + CurAddr de la section courante }
Begin
 If (CurSection >= 1) and (CurSection <= SectionCount) Then
  GetPC := Sections[CurSection].Origin + Sections[CurSection].CurAddr
 Else
  GetPC := 0;
End;

Procedure AlignPC(N: Integer);
{ Aligne l'adresse courante sur une frontiere de N octets.
  Remplit avec des octets nuls (00). N doit etre une puissance de 2. }
Var Addr: LongInt;
    Pad: Integer;
Begin
 If (N <= 0) or (CurSection < 1) or (CurSection > SectionCount) Then Exit;
 Addr := GetPC;
 If (Addr mod N) <> 0 Then
 Begin
  Pad := N - Integer(Addr mod N);
  While Pad > 0 do
  Begin
   Emit8(0);
   Dec(Pad);
  End;
 End;
End;

{ ---------- Patch : ecrire dans le buffer a une position donnee ---------- }

Procedure Patch8(SecIdx: Integer; Offset: LongInt; B: Byte);
{ Ecrit un octet a une position donnee dans le buffer d'une section }
Begin
 If (SecIdx >= 1) and (SecIdx <= SectionCount) and
    (Offset >= 0) and (Offset < MAX_SEC_SIZE) Then
  Sections[SecIdx].Buf^[Offset] := B;
End;

Procedure Patch16(SecIdx: Integer; Offset: LongInt; W: Word);
{ Ecrit un mot 16 bits big-endian a une position donnee }
Begin
 Patch8(SecIdx, Offset,     Byte(W shr 8));
 Patch8(SecIdx, Offset + 1, Byte(W and $FF));
End;

Procedure Patch32(SecIdx: Integer; Offset: LongInt; L: LongInt);
{ Ecrit un long mot 32 bits big-endian a une position donnee }
Begin
 Patch16(SecIdx, Offset,     Word(L shr 16));
 Patch16(SecIdx, Offset + 2, Word(L and $FFFF));
End;

{ ---------- Fixups : references a resoudre en passe 2 ---------- }

Procedure AddFixup(SecIdx: Integer; Offset: LongInt; Size: Integer;
                   SymIdx: Integer; FixType: Integer; Addend: LongInt);
{ Enregistre une reference a resoudre en passe 2.
  SecIdx  = section contenant la reference
  Offset  = position dans le buffer
  Size    = taille du champ (8, 16 ou 32)
  SymIdx  = index du symbole dans SymTable (0 = absolu)
  FixType = FIX_ABSOLUTE ou FIX_PC_RELATIVE
  Addend  = valeur a ajouter a la valeur du symbole }
Begin
 If FixupCount >= MAX_FIXUP Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'trop de fixups (max ' +
        IntToStr(MAX_FIXUP) + ')');
  Exit;
 End;
 Inc(FixupCount);
 Fixups[FixupCount].Section := SecIdx;
 Fixups[FixupCount].Offset  := Offset;
 Fixups[FixupCount].Size    := Size;
 Fixups[FixupCount].SymIdx  := SymIdx;
 Fixups[FixupCount].FixType := FixType;
 Fixups[FixupCount].Addend  := Addend;
End;

Procedure ResolveFixups;
{ Resoudre toutes les references enregistrees.
  Pour chaque fixup, recupere la valeur du symbole, ajoute l'addend,
  puis applique le patch dans le buffer de la section correspondante.
  Pour les fixups PC-relatifs, soustrait l'adresse du fixup. }
Var
  I: Integer;
  SymVal: LongInt;
  FixAddr: LongInt;
  FinalVal: LongInt;
Begin
 For I := 1 to FixupCount do
 Begin
  { Recuperer la valeur du symbole }
  If (Fixups[I].SymIdx >= 1) and (Fixups[I].SymIdx <= SymCount) Then
  Begin
   If Not SymTable[Fixups[I].SymIdx].Defined Then
   Begin
    Error(0, 0, 'fixup: symbole non defini: ' +
          SymTable[Fixups[I].SymIdx].Name);
    Continue;
   End;
   SymVal := SymTable[Fixups[I].SymIdx].Value;
  End
  Else
   SymVal := 0;

  FinalVal := SymVal + Fixups[I].Addend;

  { Ajustement PC-relatif }
  If Fixups[I].FixType = FIX_PC_RELATIVE Then
  Begin
   FixAddr := Sections[Fixups[I].Section].Origin + Fixups[I].Offset;
   FinalVal := FinalVal - FixAddr;
  End;

  { Appliquer le patch selon la taille }
  Case Fixups[I].Size of
   8:  Patch8(Fixups[I].Section, Fixups[I].Offset, Byte(FinalVal and $FF));
   16: Patch16(Fixups[I].Section, Fixups[I].Offset, Word(FinalVal and $FFFF));
   32: Patch32(Fixups[I].Section, Fixups[I].Offset, FinalVal);
  End;
 End;
End;

Function SectionTypeName(T: Integer): String;
{ Retourne le nom du type de section pour affichage }
Begin
 Case T of
  SEC_CODE: SectionTypeName := 'CODE';
  SEC_DATA: SectionTypeName := 'DATA';
  SEC_BSS:  SectionTypeName := 'BSS';
 Else
  SectionTypeName := '???';
 End;
End;

{ ============================================================================ }
{ TODO 08 - Directives assembleur de base (ORG, DC, DS, EQU, END)             }
{ ============================================================================ }

{ ---------- ORG : fixer l'adresse d'origine ---------- }

Procedure DirORG;
{ ORG expr - fixe l'adresse d'origine de la section courante.
  Met a jour l'Origin et le CurAddr (relatif) de la section. }
Var V: LongInt;
Begin
 V := EvalExpr;
 If V < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'ORG: adresse negative');
  Exit;
 End;
 Sections[CurSection].Origin  := V;
 Sections[CurSection].CurAddr := 0;
 expr_pc := V;
End;

{ ---------- EQU / SET : constantes et variables d'assemblage ---------- }

Procedure DirEQU(Const LblName: String);
{ label EQU expr - definit une constante d'assemblage (non redefinissable) }
Var V: LongInt;
Begin
 If LblName = '' Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'EQU necessite une etiquette');
  Exit;
 End;
 V := EvalExpr;
 AddSym(LblName, V, CurSection, SYM_EQU, cur_tok_line);
End;

Procedure DirSET(Const LblName: String);
{ label SET expr - definit une variable d'assemblage (redefinissable) }
Var V: LongInt;
Begin
 If LblName = '' Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'SET necessite une etiquette');
  Exit;
 End;
 V := EvalExpr;
 AddSym(LblName, V, CurSection, SYM_SET, cur_tok_line);
End;

{ ---------- DC : Define Constant ---------- }

Procedure DirDC(Size: Integer);
{ DC.B val[,val,...] - Define Constant (octets, mots, long mots).
  DC.W val[,val,...]   Pour DC.B, les chaines ('...') sont supportees.
  DC.L val[,val,...] }
Var
  V: LongInt;
  S: String;
  I: Integer;
  First: Boolean;
Begin
 If Size = 0 Then Size := SIZE_WORD; { defaut = .W }
 First := True;
 Repeat
  If Not First Then
   NextToken; { consommer la virgule }
  First := False;

  { Chaine de caracteres pour DC.B }
  If (Size = SIZE_BYTE) and (cur_tok = TOK_STRING) Then
  Begin
   S := cur_tok_str;
   For I := 1 to Length(S) do
    Emit8(Byte(Ord(S[I])));
   NextToken;
  End
  Else
  Begin
   V := EvalExpr;
   Case Size of
    SIZE_BYTE: Emit8(Byte(V and $FF));
    SIZE_WORD:
    Begin
     AlignPC(2);
     Emit16(Word(V and $FFFF));
    End;
    SIZE_LONG:
    Begin
     AlignPC(2);
     Emit32(V);
    End;
   End;
  End;
 Until cur_tok <> TOK_COMMA;
End;

{ ---------- DCB : Define Constant Block ---------- }

Procedure DirDCB(Size: Integer);
{ DCB.s count,value - repetition d'une valeur.
  Ex: DCB.W 100,$FFFF = 100 mots valant $FFFF }
Var
  Count: LongInt;
  Value: LongInt;
  I: LongInt;
Begin
 If Size = 0 Then Size := SIZE_WORD;
 Count := EvalExpr;
 If Count < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'DCB: compteur negatif');
  Exit;
 End;
 Value := 0;
 If cur_tok = TOK_COMMA Then
 Begin
  NextToken;
  Value := EvalExpr;
 End;
 For I := 1 to Count do
 Begin
  Case Size of
   SIZE_BYTE: Emit8(Byte(Value and $FF));
   SIZE_WORD:
   Begin
    If I = 1 Then AlignPC(2);
    Emit16(Word(Value and $FFFF));
   End;
   SIZE_LONG:
   Begin
    If I = 1 Then AlignPC(2);
    Emit32(Value);
   End;
  End;
 End;
End;

{ ---------- DS : Define Storage ---------- }

Procedure DirDS(Size: Integer);
{ DS.B count - reserver count octets (non initialises / remplis de zero).
  DS.W count   DS.W 0 = alignement sur mot.
  DS.L count }
Var
  Count: LongInt;
  Total: LongInt;
  I: LongInt;
Begin
 If Size = 0 Then Size := SIZE_WORD;
 Count := EvalExpr;
 If Count < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'DS: compteur negatif');
  Exit;
 End;
 { DS.W 0 = alignement sur mot (convention Motorola) }
 If (Count = 0) and (Size = SIZE_WORD) Then
 Begin
  AlignPC(2);
  Exit;
 End;
 { DS.L 0 = alignement sur long mot }
 If (Count = 0) and (Size = SIZE_LONG) Then
 Begin
  AlignPC(4);
  Exit;
 End;
 { Aligner avant si taille > byte }
 If Size > SIZE_BYTE Then AlignPC(2);
 Total := Count * Size;
 For I := 1 to Total do
  Emit8(0);
End;

{ ---------- EVEN : aligner sur adresse paire ---------- }

Procedure DirEVEN;
{ EVEN - equivalent a DS.W 0 (aligner sur adresse paire) }
Begin
 AlignPC(2);
End;

{ ---------- CNOP : aligner avec offset ---------- }

Procedure DirCNOP;
{ CNOP offset,alignment - aligne sur une frontiere de 'alignment' octets,
  puis ajoute 'offset' octets de padding.
  Ex: CNOP 0,4 = aligner sur long mot }
Var
  Offset_: LongInt;
  Align_: LongInt;
Begin
 Offset_ := EvalExpr;
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'CNOP: virgule attendue');
  Exit;
 End;
 NextToken;
 Align_ := EvalExpr;
 If Align_ <= 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'CNOP: alignement invalide');
  Exit;
 End;
 AlignPC(Integer(Align_));
 While Offset_ > 0 do
 Begin
  Emit8(0);
  Dec(Offset_);
 End;
End;

{ ---------- END : fin du source ---------- }

Procedure DirEND;
{ END [expr] - fin du source. expr est l'adresse de demarrage optionnelle. }
Var V: LongInt;
Begin
 end_source := True;
 If (cur_tok <> TOK_EOL) and (cur_tok <> TOK_EOF) Then
 Begin
  V := EvalExpr;
  start_address := V;
  start_address_set := True;
 End;
End;

{ ---------- ProcessLabel : gestion des etiquettes ---------- }

Procedure ProcessLabel(Const LblName: String);
{ Ajoute une etiquette a la table des symboles avec la valeur du PC courant. }
Begin
 If LblName = '' Then Exit;
 AddSym(LblName, GetPC, CurSection, SYM_LABEL, cur_tok_line);
End;

{ ---------- SkipToEOL : sauter jusqu'a la fin de ligne ---------- }

Procedure SkipToEOL;
{ Avance jusqu'au prochain EOL ou EOF. }
Begin
 While (cur_tok <> TOK_EOL) and (cur_tok <> TOK_EOF) do
  NextToken;
End;

{ ============================================================================ }
{ TODO 09 - Directives assembleur avancees (SECTION, INCLUDE, macros)          }
{ ============================================================================ }

{ ParseLine est appele par ExpandMacro, DirINCLUDE et DirREPT }
Procedure ParseLine; Forward;

{ ---------- FindMacro : recherche d'une macro par nom ---------- }

Function FindMacro(Const Name: String): Integer;
Var I: Integer; UName: String;
Begin
 UName := UpCaseStr(Name);
 For I := 1 to MacroCount do
  If MacroTable[I]^.Name = UName Then
  Begin FindMacro := I; Exit; End;
 FindMacro := 0;
End;

{ ---------- FreeMacros : liberer la table des macros ---------- }

Procedure FreeMacros;
Var I: Integer;
Begin
 For I := 1 to MacroCount do
  If MacroTable[I] <> nil Then
  Begin
   Dispose(MacroTable[I]);
   MacroTable[I] := nil;
  End;
 MacroCount := 0;
End;

{ ---------- DirSECTION : changer de section ---------- }

Procedure DirSECTION;
{ SECTION name[,type] - declarer/changer de section.
  Types : CODE/TEXT, DATA, BSS }
Var
  SecName: String;
  SecType: Integer;
  Idx: Integer;
Begin
 If cur_tok <> TOK_IDENT Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'SECTION: nom de section attendu');
  Exit;
 End;
 SecName := UpCaseStr(cur_tok_str);
 NextToken;

 { Determiner le type de section }
 SecType := -1;

 { Type explicite apres virgule }
 If cur_tok = TOK_COMMA Then
 Begin
  NextToken;
  If cur_tok = TOK_IDENT Then
  Begin
   If (UpCaseStr(cur_tok_str) = 'CODE') or
      (UpCaseStr(cur_tok_str) = 'TEXT') Then
    SecType := SEC_CODE
   Else If UpCaseStr(cur_tok_str) = 'DATA' Then
    SecType := SEC_DATA
   Else If UpCaseStr(cur_tok_str) = 'BSS' Then
    SecType := SEC_BSS
   Else
    Warning(cur_tok_line, cur_tok_col,
            'SECTION: type inconnu, defaut CODE');
   NextToken;
  End;
 End;

 { Si pas de type explicite, deduire du nom }
 If SecType = -1 Then
 Begin
  If (SecName = 'CODE') or (SecName = 'TEXT') Then
   SecType := SEC_CODE
  Else If SecName = 'DATA' Then
   SecType := SEC_DATA
  Else If SecName = 'BSS' Then
   SecType := SEC_BSS
  Else
   SecType := SEC_CODE;
 End;

 { Chercher ou creer la section }
 Idx := FindSection(SecName);
 If Idx = 0 Then
 Begin
  If SectionCount >= MAX_SECTIONS Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'SECTION: trop de sections');
   Exit;
  End;
  Inc(SectionCount);
  Sections[SectionCount].Name := SecName;
  Sections[SectionCount].SecType := SecType;
  Sections[SectionCount].Origin := 0;
  Sections[SectionCount].CurAddr := 0;
  New(Sections[SectionCount].Buf);
  FillChar(Sections[SectionCount].Buf^, SizeOf(TSectionBuf), 0);
  Sections[SectionCount].Size := 0;
  CurSection := SectionCount;
 End
 Else
  CurSection := Idx;

 expr_pc := GetPC;
End;

{ ---------- DirINCLUDE : inclusion de fichier source ---------- }

Procedure DirINCLUDE;
{ INCLUDE "filename" - inclure un fichier source.
  Lit toutes les lignes dans un buffer puis les traite inline. }
Var
  FileName: String;
  FullPath: String;
  I: Integer;
  IncFile: Text;
  Found: Boolean;
  IncBuf: PIncLineBuf;
  IncCount: Integer;
  SaveLine: String;
  SaveCol: Integer;
  SaveLineNum: Integer;
  SaveEof: Boolean;
Begin
 { Recuperer le nom de fichier (apostrophes, guillemets ou identifiant) }
 If cur_tok = TOK_STRING Then
 Begin
  FileName := cur_tok_str;
  NextToken;
 End
 Else If (cur_tok = TOK_UNKNOWN) and (cur_tok_str = '"') Then
 Begin
  { Guillemets doubles : lire directement depuis src_line }
  FileName := '';
  While (src_col <= Length(src_line)) and (src_line[src_col] <> '"') do
  Begin
   FileName := FileName + src_line[src_col];
   Inc(src_col);
  End;
  If (src_col <= Length(src_line)) and (src_line[src_col] = '"') Then
   Inc(src_col);
  NextToken;
 End
 Else If cur_tok = TOK_IDENT Then
 Begin
  FileName := cur_tok_str;
  NextToken;
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col, 'INCLUDE: nom de fichier attendu');
  Exit;
 End;

 { Verifier la profondeur d'imbrication }
 If include_depth >= MAX_INCLUDE_DEPTH Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'INCLUDE: imbrication trop profonde');
  Exit;
 End;

 { Chercher le fichier }
 Found := False;
 FullPath := FileName;

 { Essayer le nom tel quel }
 Assign(IncFile, FileName);
 {$I-} Reset(IncFile); {$I+}
 If IOResult = 0 Then
 Begin
  Found := True;
  FullPath := FileName;
 End;

 { Essayer les repertoires -i }
 If Not Found Then
 Begin
  For I := 1 to Opts.IncPathCount do
  Begin
   FullPath := Opts.IncludePaths[I];
   If (Length(FullPath) > 0) and (FullPath[Length(FullPath)] <> '/') and
      (FullPath[Length(FullPath)] <> '\') Then
    FullPath := FullPath + '/';
   FullPath := FullPath + FileName;
   Assign(IncFile, FullPath);
   {$I-} Reset(IncFile); {$I+}
   If IOResult = 0 Then
   Begin
    Found := True;
    Break;
   End;
  End;
 End;

 If Not Found Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'INCLUDE: fichier introuvable: ' + FileName);
  Exit;
 End;

 { Lire toutes les lignes dans le buffer }
 New(IncBuf);
 IncCount := 0;
 While Not Eof(IncFile) do
 Begin
  If IncCount >= MAX_INC_LINES Then
  Begin
   Warning(cur_tok_line, cur_tok_col,
           'INCLUDE: fichier trop long, tronque a ' + FullPath);
   Break;
  End;
  Inc(IncCount);
  ReadLn(IncFile, IncBuf^[IncCount]);
 End;
 Close(IncFile);

 { Sauvegarder l'etat du lexeur }
 SaveLine := src_line;
 SaveCol := src_col;
 SaveLineNum := src_line_num;
 SaveEof := src_eof;

 { Traiter les lignes incluses }
 Inc(include_depth);
 src_eof := True; { Empecher SrcGetLine de lire le fichier principal }

 For I := 1 to IncCount do
 Begin
  src_line := IncBuf^[I];
  src_col := 1;
  Inc(src_line_num);

  NextToken;

  If (cur_tok <> TOK_EOL) and (cur_tok <> TOK_EOF) Then
  Begin
   If end_source Then Break;
   ParseLine;
  End;
 End;

 Dec(include_depth);

 { Restaurer l'etat du lexeur }
 src_line := SaveLine;
 src_col := SaveCol;
 src_line_num := SaveLineNum;
 src_eof := SaveEof;

 Dispose(IncBuf);
End;

{ ---------- DirXDEF / DirENTRY : exporter des symboles ---------- }

Procedure DirXDEF;
{ XDEF sym[,sym,...] ou ENTRY sym - marquer des symboles comme exportes }
Var
  SymName: String;
  Idx: Integer;
Begin
 Repeat
  If (cur_tok <> TOK_IDENT) and (cur_tok <> TOK_LABEL) Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'XDEF: nom de symbole attendu');
   Exit;
  End;
  SymName := UpCaseStr(cur_tok_str);
  Idx := FindSym(SymName);
  If Idx <> 0 Then
   SymTable[Idx].SymType := SYM_ENTRY
  Else
   AddSym(SymName, 0, CurSection, SYM_ENTRY, cur_tok_line);
  NextToken;
  If cur_tok = TOK_COMMA Then
   NextToken
  Else
   Break;
 Until False;
End;

{ ---------- DirXREF / DirEXTERNAL : importer des symboles ---------- }

Procedure DirXREF;
{ XREF sym[,sym,...] ou EXTERNAL sym - declarer symboles externes }
Var
  SymName: String;
  Idx: Integer;
Begin
 Repeat
  If (cur_tok <> TOK_IDENT) and (cur_tok <> TOK_LABEL) Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'XREF: nom de symbole attendu');
   Exit;
  End;
  SymName := UpCaseStr(cur_tok_str);
  Idx := FindSym(SymName);
  If Idx = 0 Then
   AddSym(SymName, 0, CurSection, SYM_EXTERNAL, cur_tok_line);
  NextToken;
  If cur_tok = TOK_COMMA Then
   NextToken
  Else
   Break;
 Until False;
End;

{ ---------- DirMACRO : definition de macro ---------- }

Procedure DirMACRO(Const MacName: String);
{ name MACRO [param1,param2,...] - definir une macro.
  Lit les lignes du corps jusqu'a ENDM. }
Var
  M: ^TMacroEntry;
  Line_: String;
  UDir: String;
Begin
 If MacName = '' Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'MACRO: nom de macro requis');
  SkipToEOL;
  Exit;
 End;

 If MacroCount >= MAX_MACRO Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'MACRO: table des macros pleine');
  SkipToEOL;
  Exit;
 End;

 Inc(MacroCount);
 New(MacroTable[MacroCount]);
 M := MacroTable[MacroCount];
 M^.Name := UpCaseStr(MacName);
 M^.ParamCount := 0;
 M^.BodyCount := 0;
 M^.LineNum := cur_tok_line;

 { Lire les noms de parametres optionnels }
 While (cur_tok <> TOK_EOL) and (cur_tok <> TOK_EOF) do
 Begin
  If (cur_tok = TOK_IDENT) and (M^.ParamCount < MAX_MACRO_PARAMS) Then
  Begin
   Inc(M^.ParamCount);
   M^.ParamNames[M^.ParamCount] := UpCaseStr(cur_tok_str);
  End;
  NextToken;
  If cur_tok = TOK_COMMA Then NextToken;
 End;

 { Lire les lignes du corps jusqu'a ENDM }
 While Not src_eof do
 Begin
  If Not SrcGetLine Then Break;
  Line_ := src_line;

  { Verifier si c'est ENDM }
  UDir := Trim(Line_);
  While (Length(UDir) > 0) and (UDir[1] = #9) do Delete(UDir, 1, 1);
  UDir := UpCaseStr(UDir);
  If (UDir = 'ENDM') or
     ((Length(UDir) > 4) and (Copy(UDir, 1, 4) = 'ENDM') and
      (UDir[5] in [' ', #9, ';'])) Then
  Begin
   { ENDM trouve : charger la ligne suivante pour le lexeur }
   If SrcGetLine Then
    NextToken
   Else
   Begin
    cur_tok := TOK_EOF;
    src_eof := True;
   End;
   Exit;
  End;

  { Ajouter la ligne au corps de la macro }
  If M^.BodyCount < MAX_MACRO_LINES Then
  Begin
   Inc(M^.BodyCount);
   M^.Body[M^.BodyCount] := Line_;
  End
  Else
   Warning(src_line_num, 1, 'MACRO: corps trop long, ligne ignoree');
 End;

 Error(src_line_num, 1, 'MACRO: ENDM manquant pour ' + M^.Name);
End;

{ ---------- ExpandMacro : expansion d'une macro ---------- }

Procedure ExpandMacro(MacIdx: Integer);
{ Expanse une macro avec les arguments de la ligne courante. }
Var
  M: ^TMacroEntry;
  Args: Array[1..MAX_MACRO_PARAMS] of String;
  ArgCount: Integer;
  ArgStr: String;
  I, J, K: Integer;
  Line_: String;
  Result_: String;
  UniqueStr: String;
  P: Integer;
  ParamRef: String;
  ExpLines: Array[1..MAX_MACRO_LINES] of String;
  ExpCount: Integer;
  SaveLine: String;
  SaveCol: Integer;
  SaveEof: Boolean;
Begin
 M := MacroTable[MacIdx];

 { Lire les arguments de la macro }
 ArgCount := 0;
 While (cur_tok <> TOK_EOL) and (cur_tok <> TOK_EOF) do
 Begin
  ArgStr := '';
  While (cur_tok <> TOK_COMMA) and (cur_tok <> TOK_EOL) and
        (cur_tok <> TOK_EOF) do
  Begin
   If ArgStr <> '' Then ArgStr := ArgStr + ' ';
   ArgStr := ArgStr + cur_tok_str;
   NextToken;
  End;
  If ArgStr <> '' Then
  Begin
   Inc(ArgCount);
   If ArgCount <= MAX_MACRO_PARAMS Then
    Args[ArgCount] := ArgStr;
  End;
  If cur_tok = TOK_COMMA Then NextToken;
 End;

 { Remplir les arguments manquants }
 For I := ArgCount + 1 to MAX_MACRO_PARAMS do
  Args[I] := '';

 { Generer un identifiant unique pour \@ }
 Inc(macro_unique_id);
 Str(macro_unique_id, UniqueStr);
 While Length(UniqueStr) < 4 do UniqueStr := '0' + UniqueStr;

 { Substituer les parametres dans chaque ligne du corps }
 ExpCount := 0;
 For I := 1 to M^.BodyCount do
 Begin
  Line_ := M^.Body[I];
  Result_ := '';
  J := 1;
  While J <= Length(Line_) do
  Begin
   If (Line_[J] = '\') and (J < Length(Line_)) Then
   Begin
    Inc(J);
    { \@ = suffixe d'etiquette unique }
    If Line_[J] = '@' Then
    Begin
     Result_ := Result_ + UniqueStr;
     Inc(J);
    End
    { \1..\9 = parametre positionnel }
    Else If (Line_[J] >= '1') and (Line_[J] <= '9') Then
    Begin
     P := Ord(Line_[J]) - Ord('0');
     If P <= ArgCount Then
      Result_ := Result_ + Args[P];
     Inc(J);
    End
    { \nom = parametre nomme }
    Else If (Line_[J] in ['A'..'Z', 'a'..'z', '_']) Then
    Begin
     ParamRef := '';
     While (J <= Length(Line_)) and
           (Line_[J] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
     Begin
      ParamRef := ParamRef + Line_[J];
      Inc(J);
     End;
     { Separateur point optionnel (\param.suffix) }
     If (J <= Length(Line_)) and (Line_[J] = '.') Then Inc(J);
     { Chercher le parametre nomme }
     P := 0;
     For K := 1 to M^.ParamCount do
      If UpCaseStr(ParamRef) = M^.ParamNames[K] Then
      Begin P := K; Break; End;
     If (P > 0) and (P <= MAX_MACRO_PARAMS) Then
      Result_ := Result_ + Args[P]
     Else
      Result_ := Result_ + '\' + ParamRef;
    End
    Else
    Begin
     Result_ := Result_ + '\' + Line_[J];
     Inc(J);
    End;
   End
   Else
   Begin
    Result_ := Result_ + Line_[J];
    Inc(J);
   End;
  End;

  If ExpCount < MAX_MACRO_LINES Then
  Begin
   Inc(ExpCount);
   ExpLines[ExpCount] := Result_;
  End;
 End;

 { Sauvegarder l'etat et traiter les lignes expansees }
 SaveLine := src_line;
 SaveCol := src_col;
 SaveEof := src_eof;

 macro_expanding := True;
 macro_narg := ArgCount;
 src_eof := True; { Empecher SrcGetLine de lire le fichier principal }

 For I := 1 to ExpCount do
 Begin
  src_line := ExpLines[I];
  src_col := 1;

  NextToken;

  { MEXIT : sortie anticipee }
  If (cur_tok = TOK_DIRECTIVE) and (UpCaseStr(cur_tok_str) = 'MEXIT') Then
   Break;

  If (cur_tok <> TOK_EOL) and (cur_tok <> TOK_EOF) Then
   ParseLine;
 End;

 macro_expanding := False;
 macro_narg := 0;

 { Restaurer l'etat }
 src_line := SaveLine;
 src_col := SaveCol;
 src_eof := SaveEof;
End;

{ ---------- DirREPT : repetition de bloc ---------- }

Procedure DirREPT;
{ REPT count ... ENDR - repeter un bloc count fois }
Var
  Count: LongInt;
  Lines_: Array[1..MAX_MACRO_LINES] of String;
  LineCount_: Integer;
  UDir: String;
  I, J: Integer;
  SaveLine: String;
  SaveCol: Integer;
  SaveEof: Boolean;
Begin
 Count := EvalExpr;
 If Count < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'REPT: compteur negatif');
  Count := 0;
 End;

 { Lire le corps jusqu'a ENDR }
 LineCount_ := 0;
 While Not src_eof do
 Begin
  If Not SrcGetLine Then Break;

  UDir := Trim(src_line);
  While (Length(UDir) > 0) and (UDir[1] = #9) do Delete(UDir, 1, 1);
  UDir := UpCaseStr(UDir);
  If (UDir = 'ENDR') or
     ((Length(UDir) > 4) and (Copy(UDir, 1, 4) = 'ENDR') and
      (UDir[5] in [' ', #9, ';'])) Then
   Break;

  If LineCount_ < MAX_MACRO_LINES Then
  Begin
   Inc(LineCount_);
   Lines_[LineCount_] := src_line;
  End;
 End;

 { Sauvegarder l'etat et repeter le bloc }
 SaveLine := src_line;
 SaveCol := src_col;
 SaveEof := src_eof;
 src_eof := True;

 For I := 1 to Count do
 Begin
  For J := 1 to LineCount_ do
  Begin
   src_line := Lines_[J];
   src_col := 1;
   NextToken;
   If (cur_tok <> TOK_EOL) and (cur_tok <> TOK_EOF) Then
    ParseLine;
  End;
 End;

 { Restaurer l'etat }
 src_line := SaveLine;
 src_col := SaveCol;
 src_eof := SaveEof;

 { Charger la ligne suivante }
 If SrcGetLine Then
  NextToken
 Else
 Begin
  cur_tok := TOK_EOF;
  src_eof := True;
 End;
End;

{ ============================================================================ }
{ TODO 10 - Assemblage conditionnel (IF, IFDEF, IFEQ, etc.)                    }
{ ============================================================================ }

Function CondAssembling: Boolean;
{ Retourne True si on assemble au niveau courant }
Begin
 If cond_depth = 0 Then
  CondAssembling := True
 Else
  CondAssembling := cond_stack[cond_depth].assembling;
End;

Procedure CondPush(Assembling_: Boolean);
{ Empiler un nouveau niveau conditionnel }
Begin
 If cond_depth >= MAX_COND_DEPTH Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'imbrication IF trop profonde');
  Exit;
 End;
 Inc(cond_depth);
 cond_stack[cond_depth].outer_asm := CondAssembling;
 { On assemble si le parent assemble ET que la condition est vraie }
 If cond_depth > 1 Then
  cond_stack[cond_depth].assembling := cond_stack[cond_depth - 1].assembling and Assembling_
 Else
  cond_stack[cond_depth].assembling := Assembling_;
 cond_stack[cond_depth].else_seen := False;
End;

Procedure DirIFEQ;
{ IFEQ expr : assembler si expr = 0 }
Var V: LongInt;
Begin
 V := EvalExpr;
 CondPush(V = 0);
 SkipToEOL;
End;

Procedure DirIFNE;
{ IFNE expr : assembler si expr <> 0 }
Var V: LongInt;
Begin
 V := EvalExpr;
 CondPush(V <> 0);
 SkipToEOL;
End;

Procedure DirIFGT;
{ IFGT expr : assembler si expr > 0 }
Var V: LongInt;
Begin
 V := EvalExpr;
 CondPush(V > 0);
 SkipToEOL;
End;

Procedure DirIFGE;
{ IFGE expr : assembler si expr >= 0 }
Var V: LongInt;
Begin
 V := EvalExpr;
 CondPush(V >= 0);
 SkipToEOL;
End;

Procedure DirIFLT;
{ IFLT expr : assembler si expr < 0 }
Var V: LongInt;
Begin
 V := EvalExpr;
 CondPush(V < 0);
 SkipToEOL;
End;

Procedure DirIFLE;
{ IFLE expr : assembler si expr <= 0 }
Var V: LongInt;
Begin
 V := EvalExpr;
 CondPush(V <= 0);
 SkipToEOL;
End;

Procedure DirIFDEF;
{ IFDEF sym : assembler si symbole defini }
Var SymName_: String;
Begin
 If cur_tok = TOK_IDENT Then
 Begin
  SymName_ := cur_tok_str;
  NextToken;
 End
 Else If cur_tok = TOK_LABEL Then
 Begin
  SymName_ := cur_tok_str;
  If (Length(SymName_) > 0) and (SymName_[Length(SymName_)] = ':') Then
   SymName_ := Copy(SymName_, 1, Length(SymName_) - 1);
  NextToken;
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col, 'IFDEF: symbole attendu');
  SymName_ := '';
 End;
 If SymName_ <> '' Then
  CondPush(FindSym(SymName_) <> 0)
 Else
  CondPush(False);
 SkipToEOL;
End;

Procedure DirIFNDEF;
{ IFNDEF sym : assembler si symbole non defini }
Var SymName_: String;
Begin
 If cur_tok = TOK_IDENT Then
 Begin
  SymName_ := cur_tok_str;
  NextToken;
 End
 Else If cur_tok = TOK_LABEL Then
 Begin
  SymName_ := cur_tok_str;
  If (Length(SymName_) > 0) and (SymName_[Length(SymName_)] = ':') Then
   SymName_ := Copy(SymName_, 1, Length(SymName_) - 1);
  NextToken;
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col, 'IFNDEF: symbole attendu');
  SymName_ := '';
 End;
 If SymName_ <> '' Then
  CondPush(FindSym(SymName_) = 0)
 Else
  CondPush(False);
 SkipToEOL;
End;

Procedure DirIFC;
{ IFC str1,str2 : assembler si chaines egales }
Var S1, S2: String;
Begin
 S1 := '';
 S2 := '';
 { Lire premiere chaine }
 If cur_tok = TOK_STRING Then
 Begin
  S1 := cur_tok_str;
  NextToken;
 End
 Else If cur_tok = TOK_IDENT Then
 Begin
  S1 := cur_tok_str;
  NextToken;
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col, 'IFC: chaine attendue');
  CondPush(False);
  SkipToEOL;
  Exit;
 End;
 { Virgule }
 If cur_tok = TOK_COMMA Then
  NextToken
 Else
 Begin
  Error(cur_tok_line, cur_tok_col, 'IFC: virgule attendue');
  CondPush(False);
  SkipToEOL;
  Exit;
 End;
 { Lire seconde chaine }
 If cur_tok = TOK_STRING Then
 Begin
  S2 := cur_tok_str;
  NextToken;
 End
 Else If cur_tok = TOK_IDENT Then
 Begin
  S2 := cur_tok_str;
  NextToken;
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col, 'IFC: seconde chaine attendue');
  CondPush(False);
  SkipToEOL;
  Exit;
 End;
 CondPush(S1 = S2);
 SkipToEOL;
End;

Procedure DirIFNC;
{ IFNC str1,str2 : assembler si chaines differentes }
Var S1, S2: String;
Begin
 S1 := '';
 S2 := '';
 If cur_tok = TOK_STRING Then
 Begin
  S1 := cur_tok_str;
  NextToken;
 End
 Else If cur_tok = TOK_IDENT Then
 Begin
  S1 := cur_tok_str;
  NextToken;
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col, 'IFNC: chaine attendue');
  CondPush(False);
  SkipToEOL;
  Exit;
 End;
 If cur_tok = TOK_COMMA Then
  NextToken
 Else
 Begin
  Error(cur_tok_line, cur_tok_col, 'IFNC: virgule attendue');
  CondPush(False);
  SkipToEOL;
  Exit;
 End;
 If cur_tok = TOK_STRING Then
 Begin
  S2 := cur_tok_str;
  NextToken;
 End
 Else If cur_tok = TOK_IDENT Then
 Begin
  S2 := cur_tok_str;
  NextToken;
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col, 'IFNC: seconde chaine attendue');
  CondPush(False);
  SkipToEOL;
  Exit;
 End;
 CondPush(S1 <> S2);
 SkipToEOL;
End;

Procedure DirELSE_;
{ ELSE : inverser la condition du bloc courant }
Begin
 If cond_depth = 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'ELSE sans IF correspondant');
  SkipToEOL;
  Exit;
 End;
 If cond_stack[cond_depth].else_seen Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'ELSE deja rencontre dans ce bloc IF');
  SkipToEOL;
  Exit;
 End;
 cond_stack[cond_depth].else_seen := True;
 { Inverser: assembler si le parent assemble ET qu'on n'assemblait pas }
 If cond_depth > 1 Then
  cond_stack[cond_depth].assembling :=
   cond_stack[cond_depth - 1].assembling and
   (Not cond_stack[cond_depth].assembling)
 Else
  cond_stack[cond_depth].assembling :=
   Not cond_stack[cond_depth].assembling;
 SkipToEOL;
End;

Procedure DirENDC;
{ ENDC / ENDIF : fin du bloc conditionnel }
Begin
 If cond_depth = 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'ENDC/ENDIF sans IF correspondant');
  SkipToEOL;
  Exit;
 End;
 Dec(cond_depth);
 SkipToEOL;
End;

{ ============================================================================ }
{ TODO 11 - Instructions de transfert de donnees                              }
{ ============================================================================ }
{ MOVE, MOVEA, MOVEQ, MOVEM, MOVEP, LEA, PEA, EXG, SWAP, LINK, UNLK        }

Procedure InstrMOVE(OpSize: Integer);
{ MOVE.s <ea>,<ea> - transfert general
  Encodage : 00 | sz(2) | dstReg(3) | dstMode(3) | srcEA(6)
  sz : 01=byte, 11=word, 10=long
  Champs destination : reg et mode INVERSES par rapport a l'EA normal.
  Formes speciales :
    MOVE.W SR, <ea>   -> $40C0 | dstEA  (lire SR)
    MOVE.W CCR, <ea>  -> $42C0 | dstEA  (lire CCR, 68010+)
    MOVE.W <ea>, CCR  -> $44C0 | srcEA  (ecrire CCR)
    MOVE.W <ea>, SR   -> $46C0 | srcEA  (ecrire SR, privilegie) }
Var
 Src, Dst: TOperand;
 SrcEA, DstEA: Integer;
 SzCode: Integer;
 DstMd, DstRg: Integer;
 InstrW: Word;
 ActualSize: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue apres operande source');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 { --- Forme speciale : MOVE USP, An --- }
 If (Src.Mode = AM_SR_CCR) and (Src.Reg = REG_USP) Then
 Begin
  If Dst.Mode <> AM_ADDR_REG Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         'MOVE USP: destination doit etre un registre An');
   SkipToEOL; Exit;
  End;
  InstrW := $4E68 or Word(Dst.Reg - REG_A0);
  Emit16(InstrW);
  Exit;
 End;

 { --- Forme speciale : MOVE An, USP --- }
 If (Dst.Mode = AM_SR_CCR) and (Dst.Reg = REG_USP) Then
 Begin
  If Src.Mode <> AM_ADDR_REG Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         'MOVE USP: source doit etre un registre An');
   SkipToEOL; Exit;
  End;
  InstrW := $4E60 or Word(Src.Reg - REG_A0);
  Emit16(InstrW);
  Exit;
 End;

 { --- Forme speciale : MOVE SR/CCR, <ea> --- }
 If Src.Mode = AM_SR_CCR Then
 Begin
  DstEA := EncodeEA(Dst);
  If DstEA < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'mode destination invalide pour MOVE SR/CCR');
   SkipToEOL; Exit;
  End;
  If Src.Reg = REG_SR Then
   InstrW := $40C0 or Word(DstEA)
  Else { CCR }
   InstrW := $42C0 or Word(DstEA);
  Emit16(InstrW);
  EmitExtWords(Dst, SIZE_WORD);
  Exit;
 End;

 { --- Forme speciale : MOVE <ea>, CCR/SR --- }
 If Dst.Mode = AM_SR_CCR Then
 Begin
  SrcEA := EncodeEA(Src);
  If SrcEA < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'mode source invalide pour MOVE to CCR/SR');
   SkipToEOL; Exit;
  End;
  If Dst.Reg = REG_CCR Then
   InstrW := $44C0 or Word(SrcEA)
  Else { SR }
   InstrW := $46C0 or Word(SrcEA);
  Emit16(InstrW);
  EmitExtWords(Src, SIZE_WORD);
  Exit;
 End;

 { Verifier si c'est en fait un MOVEA (destination = An) }
 If Dst.Mode = AM_ADDR_REG Then
 Begin
  If ActualSize = SIZE_BYTE Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'MOVE.B vers An interdit, utiliser MOVEA.W ou .L');
   SkipToEOL; Exit;
  End;
  { Encoder comme MOVEA }
  SrcEA := EncodeEA(Src);
  If SrcEA < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'mode d''adressage source invalide');
   SkipToEOL; Exit;
  End;
  If ActualSize = SIZE_WORD Then
   InstrW := $3040
  Else
   InstrW := $2040;
  InstrW := InstrW or Word((Dst.Reg - REG_A0) shl 9) or Word(SrcEA);
  Emit16(InstrW);
  EmitExtWords(Src, ActualSize);
  Exit;
 End;

 { Source : tous les modes }
 If Not CheckEAMask(Src, EA_ALL) Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'mode d''adressage source invalide pour MOVE');
  SkipToEOL; Exit;
 End;
 { Destination : modes data alterable }
 If Not CheckEAMask(Dst, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'mode d''adressage destination invalide pour MOVE');
  SkipToEOL; Exit;
 End;

 SrcEA := EncodeEA(Src);
 DstEA := EncodeEA(Dst);
 If (SrcEA < 0) or (DstEA < 0) Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
  SkipToEOL; Exit;
 End;

 { Taille -> code MOVE }
 Case ActualSize of
  SIZE_BYTE: SzCode := 1;
  SIZE_WORD: SzCode := 3;
  SIZE_LONG: SzCode := 2;
 Else
  SzCode := 3;
 End;

 { Destination : reg et mode inverses }
 DstMd := (DstEA shr 3) and 7;
 DstRg := DstEA and 7;

 InstrW := Word(SzCode shl 12) or Word(DstRg shl 9) or
           Word(DstMd shl 6) or Word(SrcEA);
 Emit16(InstrW);
 EmitExtWords(Src, ActualSize);
 EmitExtWords(Dst, ActualSize);
End;

Procedure InstrMOVEA(OpSize: Integer);
{ MOVEA.s <ea>,An - transfert vers registre d'adresse
  .W : $3040 | (An<<9) | srcEA
  .L : $2040 | (An<<9) | srcEA }
Var
 Src, Dst: TOperand;
 SrcEA: Integer;
 InstrW: Word;
 ActualSize: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 If ActualSize = SIZE_BYTE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'MOVEA.B non supporte');
  SkipToEOL; Exit;
 End;

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue apres operande source');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode <> AM_ADDR_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'MOVEA requiert un registre d''adresse en destination');
  SkipToEOL; Exit;
 End;
 If Not CheckEAMask(Src, EA_ALL) Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'mode d''adressage source invalide pour MOVEA');
  SkipToEOL; Exit;
 End;

 SrcEA := EncodeEA(Src);
 If SrcEA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA source impossible');
  SkipToEOL; Exit;
 End;

 If ActualSize = SIZE_WORD Then
  InstrW := $3040
 Else
  InstrW := $2040;
 InstrW := InstrW or Word((Dst.Reg - REG_A0) shl 9) or Word(SrcEA);
 Emit16(InstrW);
 EmitExtWords(Src, ActualSize);
End;

Procedure InstrMOVEQ;
{ MOVEQ #imm8,Dn - chargement rapide 8 bits signe-etendu
  Encodage : $7000 | (Dn<<9) | (data & $FF) }
Var
 Src, Dst: TOperand;
 InstrW: Word;
 Val8: LongInt;
Begin
 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue apres #imm');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Src.Mode <> AM_IMMEDIATE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'MOVEQ requiert une valeur immediate');
  SkipToEOL; Exit;
 End;
 If Dst.Mode <> AM_DATA_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'MOVEQ requiert un registre Dn en destination');
  SkipToEOL; Exit;
 End;

 Val8 := Src.Imm32;
 If (Val8 < -128) or (Val8 > 127) Then
  Warning(cur_tok_line, cur_tok_col, 'valeur MOVEQ hors plage -128..127');

 InstrW := $7000 or Word(Dst.Reg shl 9) or Word(Val8 and $FF);
 Emit16(InstrW);
End;

Procedure InstrMOVEM(OpSize: Integer);
{ MOVEM.s reglist,<ea> - sauvegarde registres (reg->mem)
  MOVEM.s <ea>,reglist - restauration registres (mem->reg)
  reg->mem : $4880 | (szBit<<6) | EA + mot de masque
  mem->reg : $4C80 | (szBit<<6) | EA + mot de masque
  Pour predecrement -(An), le masque est inverse (bit0=A7, bit15=D0) }
Var
 Op: TOperand;
 RegStr: String;
 Mask: Word;
 SzBit: Integer;
 EA: Integer;
 InstrW: Word;
 RegToMem: Boolean;
 ActualSize: Integer;
 I: Integer;
 RevMask: Word;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 If ActualSize = SIZE_BYTE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'MOVEM.B non supporte');
  SkipToEOL; Exit;
 End;

 If ActualSize = SIZE_LONG Then SzBit := 1 Else SzBit := 0;

 { Determiner la direction : reglist en premier ou EA en premier }
 { Si on voit un registre suivi de '-' ou '/', c'est une reglist }
 RegToMem := False;
 If (cur_tok = TOK_REGISTER) Then
 Begin
  { Reglist en premier -> reg->mem }
  RegToMem := True;
 End;

 If RegToMem Then
 Begin
  { Lire la liste de registres depuis le flux de tokens }
  RegStr := '';
  While (cur_tok = TOK_REGISTER) or (cur_tok = TOK_MINUS) or
        (cur_tok = TOK_SLASH) do
  Begin
   RegStr := RegStr + cur_tok_str;
   NextToken;
  End;
  Mask := ParseRegList(RegStr);

  If cur_tok <> TOK_COMMA Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'virgule attendue apres la liste de registres');
   SkipToEOL; Exit;
  End;
  NextToken;
  ParseOperand(Op);

  { Modes autorises : controle alterable + predecrement }
  If (Op.Mode <> AM_ADDR_IND_PRE) and
     Not CheckEAMask(Op, EA_CONTROL and EA_ALTER) Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'mode d''adressage invalide pour MOVEM reg->mem');
   SkipToEOL; Exit;
  End;

  EA := EncodeEA(Op);
  If EA < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'encodage EA impossible pour MOVEM');
   SkipToEOL; Exit;
  End;

  { Pour predecrement, inverser le masque }
  If Op.Mode = AM_ADDR_IND_PRE Then
  Begin
   RevMask := 0;
   For I := 0 to 15 do
    If (Mask and Word(1 shl I)) <> 0 Then
     RevMask := RevMask or Word(1 shl (15 - I));
   Mask := RevMask;
  End;

  InstrW := $4880 or Word(SzBit shl 6) or Word(EA);
  Emit16(InstrW);
  Emit16(Mask);
  EmitExtWords(Op, ActualSize);
 End
 Else
 Begin
  { EA en premier -> mem->reg }
  ParseOperand(Op);

  If cur_tok <> TOK_COMMA Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'virgule attendue apres l''operande');
   SkipToEOL; Exit;
  End;
  NextToken;

  { Lire la liste de registres }
  RegStr := '';
  While (cur_tok = TOK_REGISTER) or (cur_tok = TOK_MINUS) or
        (cur_tok = TOK_SLASH) do
  Begin
   RegStr := RegStr + cur_tok_str;
   NextToken;
  End;
  Mask := ParseRegList(RegStr);

  { Modes autorises : controle + postincrement }
  If (Op.Mode <> AM_ADDR_IND_POST) and
     Not CheckEAMask(Op, EA_CONTROL) Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'mode d''adressage invalide pour MOVEM mem->reg');
   SkipToEOL; Exit;
  End;

  EA := EncodeEA(Op);
  If EA < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'encodage EA impossible pour MOVEM');
   SkipToEOL; Exit;
  End;

  InstrW := $4C80 or Word(SzBit shl 6) or Word(EA);
  Emit16(InstrW);
  Emit16(Mask);
  EmitExtWords(Op, ActualSize);
 End;
End;

Procedure InstrMOVEP(OpSize: Integer);
{ MOVEP.s Dn,d16(An) ou MOVEP.s d16(An),Dn
  mem->reg .W: $0108 | (Dn<<9) | An  + d16
  mem->reg .L: $0148 | (Dn<<9) | An  + d16
  reg->mem .W: $0188 | (Dn<<9) | An  + d16
  reg->mem .L: $01C8 | (Dn<<9) | An  + d16 }
Var
 Src, Dst: TOperand;
 Dn, An: Integer;
 InstrW: Word;
 Disp16: Integer;
 ActualSize: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 If ActualSize = SIZE_BYTE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'MOVEP.B non supporte');
  SkipToEOL; Exit;
 End;

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If (Src.Mode = AM_DATA_REG) and (Dst.Mode = AM_ADDR_IND_DISP) Then
 Begin
  { reg->mem }
  Dn := Src.Reg;
  An := Dst.Reg - REG_A0;
  Disp16 := Dst.Disp;
  If ActualSize = SIZE_WORD Then
   InstrW := $0188
  Else
   InstrW := $01C8;
  InstrW := InstrW or Word(Dn shl 9) or Word(An);
  Emit16(InstrW);
  Emit16(Word(Disp16 and $FFFF));
 End
 Else If (Src.Mode = AM_ADDR_IND_DISP) and (Dst.Mode = AM_DATA_REG) Then
 Begin
  { mem->reg }
  Dn := Dst.Reg;
  An := Src.Reg - REG_A0;
  Disp16 := Src.Disp;
  If ActualSize = SIZE_WORD Then
   InstrW := $0108
  Else
   InstrW := $0148;
  InstrW := InstrW or Word(Dn shl 9) or Word(An);
  Emit16(InstrW);
  Emit16(Word(Disp16 and $FFFF));
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col,
        'MOVEP requiert Dn,d16(An) ou d16(An),Dn');
  SkipToEOL; Exit;
 End;
End;

Procedure InstrLEA;
{ LEA <ea>,An - chargement d'adresse effective
  Encodage : $41C0 | (An<<9) | srcEA
  Source : modes controle seulement }
Var
 Src, Dst: TOperand;
 SrcEA: Integer;
 InstrW: Word;
Begin
 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue apres operande source');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode <> AM_ADDR_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'LEA requiert un registre d''adresse en destination');
  SkipToEOL; Exit;
 End;
 If Not CheckEAMask(Src, EA_CONTROL) Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'mode d''adressage source invalide pour LEA');
  SkipToEOL; Exit;
 End;

 SrcEA := EncodeEA(Src);
 If SrcEA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $41C0 or Word((Dst.Reg - REG_A0) shl 9) or Word(SrcEA);
 Emit16(InstrW);
 EmitExtWords(Src, SIZE_LONG);
End;

Procedure InstrPEA;
{ PEA <ea> - empiler adresse effective
  Encodage : $4840 | srcEA
  Source : modes controle seulement }
Var
 Src: TOperand;
 SrcEA: Integer;
 InstrW: Word;
Begin
 ParseOperand(Src);

 If Not CheckEAMask(Src, EA_CONTROL) Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'mode d''adressage invalide pour PEA');
  SkipToEOL; Exit;
 End;

 SrcEA := EncodeEA(Src);
 If SrcEA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $4840 or Word(SrcEA);
 Emit16(InstrW);
 EmitExtWords(Src, SIZE_LONG);
End;

Procedure InstrEXG;
{ EXG Xn,Xn - echange de deux registres
  Dx,Dy : $C140 | (Rx<<9) | Ry
  Ax,Ay : $C148 | ((Rx-8)<<9) | (Ry-8)
  Dx,Ay : $C188 | (Rx<<9) | (Ry-8) }
Var
 Src, Dst: TOperand;
 InstrW: Word;
Begin
 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If (Src.Mode = AM_DATA_REG) and (Dst.Mode = AM_DATA_REG) Then
 Begin
  { Dx,Dy }
  InstrW := $C140 or Word(Src.Reg shl 9) or Word(Dst.Reg);
  Emit16(InstrW);
 End
 Else If (Src.Mode = AM_ADDR_REG) and (Dst.Mode = AM_ADDR_REG) Then
 Begin
  { Ax,Ay }
  InstrW := $C148 or Word((Src.Reg - REG_A0) shl 9) or
            Word(Dst.Reg - REG_A0);
  Emit16(InstrW);
 End
 Else If (Src.Mode = AM_DATA_REG) and (Dst.Mode = AM_ADDR_REG) Then
 Begin
  { Dx,Ay }
  InstrW := $C188 or Word(Src.Reg shl 9) or Word(Dst.Reg - REG_A0);
  Emit16(InstrW);
 End
 Else If (Src.Mode = AM_ADDR_REG) and (Dst.Mode = AM_DATA_REG) Then
 Begin
  { Ay,Dx -> encode comme Dx,Ay }
  InstrW := $C188 or Word(Dst.Reg shl 9) or Word(Src.Reg - REG_A0);
  Emit16(InstrW);
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col,
        'EXG requiert deux registres (Dn/An)');
  SkipToEOL; Exit;
 End;
End;

Procedure InstrSWAP;
{ SWAP Dn - echanger les deux moities 16 bits d'un registre
  Encodage : $4840 | Dn }
Var
 Op: TOperand;
 InstrW: Word;
Begin
 ParseOperand(Op);
 If Op.Mode <> AM_DATA_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'SWAP requiert un registre Dn');
  SkipToEOL; Exit;
 End;
 InstrW := $4840 or Word(Op.Reg);
 Emit16(InstrW);
End;

Procedure InstrLINK;
{ LINK An,#disp - creer un cadre de pile
  Encodage : $4E50 | (An-8) suivi du deplacement 16 bits }
Var
 Src, Dst: TOperand;
 InstrW: Word;
Begin
 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue apres An');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Src.Mode <> AM_ADDR_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'LINK requiert un registre d''adresse');
  SkipToEOL; Exit;
 End;
 If Dst.Mode <> AM_IMMEDIATE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'LINK requiert un deplacement immediat');
  SkipToEOL; Exit;
 End;

 InstrW := $4E50 or Word(Src.Reg - REG_A0);
 Emit16(InstrW);
 Emit16(Word(Dst.Imm32 and $FFFF));
End;

Procedure InstrUNLK;
{ UNLK An - detruire le cadre de pile
  Encodage : $4E58 | (An-8) }
Var
 Op: TOperand;
 InstrW: Word;
Begin
 ParseOperand(Op);
 If Op.Mode <> AM_ADDR_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'UNLK requiert un registre d''adresse');
  SkipToEOL; Exit;
 End;
 InstrW := $4E58 or Word(Op.Reg - REG_A0);
 Emit16(InstrW);
End;

{ ============================================================================ }
{ TODO 12 - Instructions arithmetiques entieres                               }
{ ============================================================================ }
{ ADD, ADDA, ADDQ, ADDI, ADDX, SUB, SUBA, SUBQ, SUBI, SUBX,                }
{ MULS, MULU, DIVS, DIVU, NEG, NEGX, CLR, EXT,                              }
{ CMP, CMPA, CMPI, CMPM, TST, TAS                                            }

Function EncodeSizeBits(S: Integer): Integer;
{ Encode la taille en 2 bits pour les instructions ADD/SUB/CMP/etc. :
  00 = byte, 01 = word, 10 = long }
Begin
 Case S of
  SIZE_BYTE: EncodeSizeBits := 0;
  SIZE_WORD: EncodeSizeBits := 1;
  SIZE_LONG: EncodeSizeBits := 2;
 Else
  EncodeSizeBits := 1;
 End;
End;

Procedure InstrADD(OpSize: Integer);
{ ADD.s <ea>,Dn  -> $D000 | Dn<<9 | opmode(3) | srcEA(6)
  ADD.s Dn,<ea>  -> $D000 | Dn<<9 | opmode(3) | dstEA(6)
  opmode ea,Dn : 000=byte, 001=word, 010=long
  opmode Dn,ea : 100=byte, 101=word, 110=long }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits, OpMode: Integer;
 Dn: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode = AM_DATA_REG Then
 Begin
  { ADD <ea>, Dn }
  Dn := Dst.Reg;
  OpMode := SzBits; { 000/001/010 }
  EA := EncodeEA(Src);
  If EA < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'mode source invalide pour ADD');
   SkipToEOL; Exit;
  End;
  InstrW := $D000 or Word(Dn shl 9) or Word(OpMode shl 6) or Word(EA);
  Emit16(InstrW);
  EmitExtWords(Src, ActualSize);
 End
 Else If Src.Mode = AM_DATA_REG Then
 Begin
  { ADD Dn, <ea> }
  Dn := Src.Reg;
  OpMode := SzBits + 4; { 100/101/110 }
  If Not CheckEAMask(Dst, EA_MEM_ALT) Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         'mode destination invalide pour ADD Dn,<ea>');
   SkipToEOL; Exit;
  End;
  EA := EncodeEA(Dst);
  If EA < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'encodage EA destination impossible');
   SkipToEOL; Exit;
  End;
  InstrW := $D000 or Word(Dn shl 9) or Word(OpMode shl 6) or Word(EA);
  Emit16(InstrW);
  EmitExtWords(Dst, ActualSize);
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col,
        'ADD requiert un registre de donnees en source ou destination');
  SkipToEOL;
 End;
End;

Procedure InstrADDA(OpSize: Integer);
{ ADDA.s <ea>,An -> $D0C0 (word) / $D1C0 (long) | An<<9 | srcEA(6) }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 If ActualSize = SIZE_BYTE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'ADDA.B non supporte');
  SkipToEOL; Exit;
 End;

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode <> AM_ADDR_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'ADDA requiert un registre d''adresse en destination');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Src);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'mode source invalide pour ADDA');
  SkipToEOL; Exit;
 End;

 If ActualSize = SIZE_WORD Then
  InstrW := $D0C0
 Else
  InstrW := $D1C0;
 InstrW := InstrW or Word((Dst.Reg - REG_A0) shl 9) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Src, ActualSize);
End;

Procedure InstrADDQ(OpSize: Integer);
{ ADDQ.s #imm3,<ea> -> $5000 | data<<9 | sz<<6 | dstEA(6)
  data = 1..8 (8 est encode comme 0) }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
 Data3: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Src.Mode <> AM_IMMEDIATE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'ADDQ requiert un immediat en source');
  SkipToEOL; Exit;
 End;
 If (Src.Imm32 < 1) or (Src.Imm32 > 8) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'ADDQ : valeur immediate doit etre entre 1 et 8');
  SkipToEOL; Exit;
 End;
 If Not CheckEAMask(Dst, EA_ALTER) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode destination invalide pour ADDQ');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Dst);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA destination impossible');
  SkipToEOL; Exit;
 End;

 Data3 := Src.Imm32 and 7; { 8 -> 0 }
 InstrW := $5000 or Word(Data3 shl 9) or Word(SzBits shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Dst, ActualSize);
End;

Procedure InstrADDI(OpSize: Integer);
{ ADDI.s #imm,<ea> -> $0600 | sz<<6 | dstEA(6) + ext words }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Src.Mode <> AM_IMMEDIATE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'ADDI requiert un immediat en source');
  SkipToEOL; Exit;
 End;
 If Not CheckEAMask(Dst, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode destination invalide pour ADDI');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Dst);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA destination impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $0600 or Word(SzBits shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Src, ActualSize);
 EmitExtWords(Dst, ActualSize);
End;

Procedure InstrADDX(OpSize: Integer);
{ ADDX.s Dn,Dn       -> $D100 | Dn_dst<<9 | sz<<6 | Dn_src
  ADDX.s -(An),-(An) -> $D108 | An_dst<<9 | sz<<6 | An_src }
Var
 Src, Dst: TOperand;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If (Src.Mode = AM_DATA_REG) and (Dst.Mode = AM_DATA_REG) Then
 Begin
  InstrW := $D100 or Word(Dst.Reg shl 9) or Word(SzBits shl 6)
            or Word(Src.Reg);
  Emit16(InstrW);
 End
 Else If (Src.Mode = AM_ADDR_IND_PRE) and (Dst.Mode = AM_ADDR_IND_PRE) Then
 Begin
  InstrW := $D108 or Word((Dst.Reg - REG_A0) shl 9)
            or Word(SzBits shl 6) or Word(Src.Reg - REG_A0);
  Emit16(InstrW);
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col,
        'ADDX requiert Dn,Dn ou -(An),-(An)');
  SkipToEOL;
 End;
End;

Procedure InstrSUB(OpSize: Integer);
{ SUB.s <ea>,Dn  -> $9000 | Dn<<9 | opmode(3) | srcEA(6)
  SUB.s Dn,<ea>  -> $9000 | Dn<<9 | opmode(3) | dstEA(6)
  opmode ea,Dn : 000=byte, 001=word, 010=long
  opmode Dn,ea : 100=byte, 101=word, 110=long }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits, OpMode: Integer;
 Dn: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode = AM_DATA_REG Then
 Begin
  { SUB <ea>, Dn }
  Dn := Dst.Reg;
  OpMode := SzBits;
  EA := EncodeEA(Src);
  If EA < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'mode source invalide pour SUB');
   SkipToEOL; Exit;
  End;
  InstrW := $9000 or Word(Dn shl 9) or Word(OpMode shl 6) or Word(EA);
  Emit16(InstrW);
  EmitExtWords(Src, ActualSize);
 End
 Else If Src.Mode = AM_DATA_REG Then
 Begin
  { SUB Dn, <ea> }
  Dn := Src.Reg;
  OpMode := SzBits + 4;
  If Not CheckEAMask(Dst, EA_MEM_ALT) Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         'mode destination invalide pour SUB Dn,<ea>');
   SkipToEOL; Exit;
  End;
  EA := EncodeEA(Dst);
  If EA < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'encodage EA destination impossible');
   SkipToEOL; Exit;
  End;
  InstrW := $9000 or Word(Dn shl 9) or Word(OpMode shl 6) or Word(EA);
  Emit16(InstrW);
  EmitExtWords(Dst, ActualSize);
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col,
        'SUB requiert un registre de donnees en source ou destination');
  SkipToEOL;
 End;
End;

Procedure InstrSUBA(OpSize: Integer);
{ SUBA.s <ea>,An -> $90C0 (word) / $91C0 (long) | An<<9 | srcEA(6) }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 If ActualSize = SIZE_BYTE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'SUBA.B non supporte');
  SkipToEOL; Exit;
 End;

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode <> AM_ADDR_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'SUBA requiert un registre d''adresse en destination');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Src);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'mode source invalide pour SUBA');
  SkipToEOL; Exit;
 End;

 If ActualSize = SIZE_WORD Then
  InstrW := $90C0
 Else
  InstrW := $91C0;
 InstrW := InstrW or Word((Dst.Reg - REG_A0) shl 9) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Src, ActualSize);
End;

Procedure InstrSUBQ(OpSize: Integer);
{ SUBQ.s #imm3,<ea> -> $5100 | data<<9 | sz<<6 | dstEA(6) }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
 Data3: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Src.Mode <> AM_IMMEDIATE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'SUBQ requiert un immediat en source');
  SkipToEOL; Exit;
 End;
 If (Src.Imm32 < 1) or (Src.Imm32 > 8) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'SUBQ : valeur immediate doit etre entre 1 et 8');
  SkipToEOL; Exit;
 End;
 If Not CheckEAMask(Dst, EA_ALTER) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode destination invalide pour SUBQ');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Dst);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA destination impossible');
  SkipToEOL; Exit;
 End;

 Data3 := Src.Imm32 and 7;
 InstrW := $5100 or Word(Data3 shl 9) or Word(SzBits shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Dst, ActualSize);
End;

Procedure InstrSUBI(OpSize: Integer);
{ SUBI.s #imm,<ea> -> $0400 | sz<<6 | dstEA(6) + ext words }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Src.Mode <> AM_IMMEDIATE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'SUBI requiert un immediat en source');
  SkipToEOL; Exit;
 End;
 If Not CheckEAMask(Dst, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode destination invalide pour SUBI');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Dst);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA destination impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $0400 or Word(SzBits shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Src, ActualSize);
 EmitExtWords(Dst, ActualSize);
End;

Procedure InstrSUBX(OpSize: Integer);
{ SUBX.s Dn,Dn       -> $9100 | Dn_dst<<9 | sz<<6 | Dn_src
  SUBX.s -(An),-(An) -> $9108 | An_dst<<9 | sz<<6 | An_src }
Var
 Src, Dst: TOperand;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If (Src.Mode = AM_DATA_REG) and (Dst.Mode = AM_DATA_REG) Then
 Begin
  InstrW := $9100 or Word(Dst.Reg shl 9) or Word(SzBits shl 6)
            or Word(Src.Reg);
  Emit16(InstrW);
 End
 Else If (Src.Mode = AM_ADDR_IND_PRE) and (Dst.Mode = AM_ADDR_IND_PRE) Then
 Begin
  InstrW := $9108 or Word((Dst.Reg - REG_A0) shl 9)
            or Word(SzBits shl 6) or Word(Src.Reg - REG_A0);
  Emit16(InstrW);
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col,
        'SUBX requiert Dn,Dn ou -(An),-(An)');
  SkipToEOL;
 End;
End;

Procedure InstrMULS(OpSize: Integer);
{ MULS.W <ea>,Dn -> $C1C0 | Dn<<9 | srcEA(6) }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
Begin
 If (OpSize <> 0) and (OpSize <> SIZE_WORD) Then
  Warning(cur_tok_line, cur_tok_col,
          'MULS supporte uniquement .W, taille ignoree');

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode <> AM_DATA_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'MULS requiert un registre de donnees en destination');
  SkipToEOL; Exit;
 End;
 If Not CheckEAMask(Src, EA_DATA) Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'mode source invalide pour MULS');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Src);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA source impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $C1C0 or Word(Dst.Reg shl 9) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Src, SIZE_WORD);
End;

Procedure InstrMULU(OpSize: Integer);
{ MULU.W <ea>,Dn -> $C0C0 | Dn<<9 | srcEA(6) }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
Begin
 If (OpSize <> 0) and (OpSize <> SIZE_WORD) Then
  Warning(cur_tok_line, cur_tok_col,
          'MULU supporte uniquement .W, taille ignoree');

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode <> AM_DATA_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'MULU requiert un registre de donnees en destination');
  SkipToEOL; Exit;
 End;
 If Not CheckEAMask(Src, EA_DATA) Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'mode source invalide pour MULU');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Src);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA source impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $C0C0 or Word(Dst.Reg shl 9) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Src, SIZE_WORD);
End;

Procedure InstrDIVS(OpSize: Integer);
{ DIVS.W <ea>,Dn -> $81C0 | Dn<<9 | srcEA(6) }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
Begin
 If (OpSize <> 0) and (OpSize <> SIZE_WORD) Then
  Warning(cur_tok_line, cur_tok_col,
          'DIVS supporte uniquement .W, taille ignoree');

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode <> AM_DATA_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'DIVS requiert un registre de donnees en destination');
  SkipToEOL; Exit;
 End;
 If Not CheckEAMask(Src, EA_DATA) Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'mode source invalide pour DIVS');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Src);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA source impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $81C0 or Word(Dst.Reg shl 9) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Src, SIZE_WORD);
End;

Procedure InstrDIVU(OpSize: Integer);
{ DIVU.W <ea>,Dn -> $80C0 | Dn<<9 | srcEA(6) }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
Begin
 If (OpSize <> 0) and (OpSize <> SIZE_WORD) Then
  Warning(cur_tok_line, cur_tok_col,
          'DIVU supporte uniquement .W, taille ignoree');

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode <> AM_DATA_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'DIVU requiert un registre de donnees en destination');
  SkipToEOL; Exit;
 End;
 If Not CheckEAMask(Src, EA_DATA) Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'mode source invalide pour DIVU');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Src);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA source impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $80C0 or Word(Dst.Reg shl 9) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Src, SIZE_WORD);
End;

Procedure InstrNEG(OpSize: Integer);
{ NEG.s <ea> -> $4400 | sz<<6 | dstEA(6) }
Var
 Op: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Op);
 If Not CheckEAMask(Op, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode d''adressage invalide pour NEG');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Op);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $4400 or Word(SzBits shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Op, ActualSize);
End;

Procedure InstrNEGX(OpSize: Integer);
{ NEGX.s <ea> -> $4000 | sz<<6 | dstEA(6) }
Var
 Op: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Op);
 If Not CheckEAMask(Op, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode d''adressage invalide pour NEGX');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Op);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $4000 or Word(SzBits shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Op, ActualSize);
End;

Procedure InstrCLR(OpSize: Integer);
{ CLR.s <ea> -> $4200 | sz<<6 | dstEA(6) }
Var
 Op: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Op);
 If Not CheckEAMask(Op, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode d''adressage invalide pour CLR');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Op);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $4200 or Word(SzBits shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Op, ActualSize);
End;

Procedure InstrEXT(OpSize: Integer);
{ EXT.W Dn -> $4880 | Dn    (byte->word)
  EXT.L Dn -> $48C0 | Dn    (word->long) }
Var
 Op: TOperand;
 InstrW: Word;
 ActualSize: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;

 ParseOperand(Op);
 If Op.Mode <> AM_DATA_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'EXT requiert un registre de donnees');
  SkipToEOL; Exit;
 End;

 If ActualSize = SIZE_WORD Then
  InstrW := $4880 or Word(Op.Reg)
 Else If ActualSize = SIZE_LONG Then
  InstrW := $48C0 or Word(Op.Reg)
 Else
 Begin
  Error(cur_tok_line, cur_tok_col, 'EXT.B non supporte');
  SkipToEOL; Exit;
 End;
 Emit16(InstrW);
End;

Procedure InstrCMP(OpSize: Integer);
{ CMP.s <ea>,Dn -> $B000 | Dn<<9 | opmode(3) | srcEA(6)
  opmode : 000=byte, 001=word, 010=long }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode <> AM_DATA_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'CMP requiert un registre de donnees en destination');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Src);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'mode source invalide pour CMP');
  SkipToEOL; Exit;
 End;

 InstrW := $B000 or Word(Dst.Reg shl 9) or Word(SzBits shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Src, ActualSize);
End;

Procedure InstrCMPA(OpSize: Integer);
{ CMPA.s <ea>,An -> $B0C0 (word) / $B1C0 (long) | An<<9 | srcEA(6) }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 If ActualSize = SIZE_BYTE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'CMPA.B non supporte');
  SkipToEOL; Exit;
 End;

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode <> AM_ADDR_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'CMPA requiert un registre d''adresse en destination');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Src);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'mode source invalide pour CMPA');
  SkipToEOL; Exit;
 End;

 If ActualSize = SIZE_WORD Then
  InstrW := $B0C0
 Else
  InstrW := $B1C0;
 InstrW := InstrW or Word((Dst.Reg - REG_A0) shl 9) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Src, ActualSize);
End;

Procedure InstrCMPI(OpSize: Integer);
{ CMPI.s #imm,<ea> -> $0C00 | sz<<6 | dstEA(6) + ext words }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Src.Mode <> AM_IMMEDIATE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'CMPI requiert un immediat en source');
  SkipToEOL; Exit;
 End;
 If Not CheckEAMask(Dst, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode destination invalide pour CMPI');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Dst);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA destination impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $0C00 or Word(SzBits shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Src, ActualSize);
 EmitExtWords(Dst, ActualSize);
End;

Procedure InstrCMPM(OpSize: Integer);
{ CMPM.s (An)+,(An)+ -> $B108 | An_dst<<9 | sz<<6 | An_src }
Var
 Src, Dst: TOperand;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Src.Mode <> AM_ADDR_IND_POST Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'CMPM requiert (An)+ en source');
  SkipToEOL; Exit;
 End;
 If Dst.Mode <> AM_ADDR_IND_POST Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'CMPM requiert (An)+ en destination');
  SkipToEOL; Exit;
 End;

 InstrW := $B108 or Word((Dst.Reg - REG_A0) shl 9)
           or Word(SzBits shl 6) or Word(Src.Reg - REG_A0);
 Emit16(InstrW);
End;

Procedure InstrTST(OpSize: Integer);
{ TST.s <ea> -> $4A00 | sz<<6 | dstEA(6) }
Var
 Op: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Op);
 If Not CheckEAMask(Op, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode d''adressage invalide pour TST');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Op);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $4A00 or Word(SzBits shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Op, ActualSize);
End;

Procedure InstrTAS;
{ TAS.B <ea> -> $4AC0 | dstEA(6) }
Var
 Op: TOperand;
 EA: Integer;
 InstrW: Word;
Begin
 ParseOperand(Op);
 If Not CheckEAMask(Op, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode d''adressage invalide pour TAS');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Op);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $4AC0 or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Op, SIZE_BYTE);
End;

{ ====================================================================== }
{ TODO 13 - Instructions logiques et de manipulation de bits             }
{ ====================================================================== }

Procedure InstrAND(OpSize: Integer);
{ AND.s <ea>,Dn  -> $C000 | Dn<<9 | opmode(3) | srcEA(6)
  AND.s Dn,<ea>  -> $C000 | Dn<<9 | opmode(3) | dstEA(6)
  opmode ea,Dn : 000=byte, 001=word, 010=long
  opmode Dn,ea : 100=byte, 101=word, 110=long }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits, OpMode: Integer;
 Dn: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode = AM_DATA_REG Then
 Begin
  { AND <ea>, Dn }
  Dn := Dst.Reg;
  OpMode := SzBits; { 000/001/010 }
  If Not CheckEAMask(Src, EA_DATA) Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         'mode source invalide pour AND');
   SkipToEOL; Exit;
  End;
  EA := EncodeEA(Src);
  If EA < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'encodage EA source impossible');
   SkipToEOL; Exit;
  End;
  InstrW := $C000 or Word(Dn shl 9) or Word(OpMode shl 6) or Word(EA);
  Emit16(InstrW);
  EmitExtWords(Src, ActualSize);
 End
 Else If Src.Mode = AM_DATA_REG Then
 Begin
  { AND Dn, <ea> }
  Dn := Src.Reg;
  OpMode := SzBits + 4; { 100/101/110 }
  If Not CheckEAMask(Dst, EA_MEM_ALT) Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         'mode destination invalide pour AND Dn,<ea>');
   SkipToEOL; Exit;
  End;
  EA := EncodeEA(Dst);
  If EA < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'encodage EA destination impossible');
   SkipToEOL; Exit;
  End;
  InstrW := $C000 or Word(Dn shl 9) or Word(OpMode shl 6) or Word(EA);
  Emit16(InstrW);
  EmitExtWords(Dst, ActualSize);
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col,
        'AND requiert un registre de donnees en source ou destination');
  SkipToEOL;
 End;
End;

Procedure InstrANDI(OpSize: Integer);
{ ANDI.s #imm,<ea> -> $0200 | sz<<6 | dstEA(6) + ext words
  ANDI #imm,CCR    -> $023C + imm word
  ANDI #imm,SR     -> $027C + imm word }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Src.Mode <> AM_IMMEDIATE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'ANDI requiert un immediat en source');
  SkipToEOL; Exit;
 End;

 { Cas special : ANDI #imm, CCR / SR }
 If Dst.Mode = AM_SR_CCR Then
 Begin
  If Dst.Reg = REG_CCR Then
  Begin
   Emit16($023C);
   Emit16(Word(Src.Imm32 and $FF));
  End
  Else If Dst.Reg = REG_SR Then
  Begin
   Emit16($027C);
   Emit16(Word(Src.Imm32 and $FFFF));
  End
  Else
  Begin
   Error(cur_tok_line, cur_tok_col, 'destination invalide pour ANDI');
   SkipToEOL;
  End;
  Exit;
 End;

 If Not CheckEAMask(Dst, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode destination invalide pour ANDI');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Dst);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA destination impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $0200 or Word(SzBits shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Src, ActualSize);
 EmitExtWords(Dst, ActualSize);
End;

Procedure InstrOR(OpSize: Integer);
{ OR.s <ea>,Dn  -> $8000 | Dn<<9 | opmode(3) | srcEA(6)
  OR.s Dn,<ea>  -> $8000 | Dn<<9 | opmode(3) | dstEA(6)
  opmode ea,Dn : 000=byte, 001=word, 010=long
  opmode Dn,ea : 100=byte, 101=word, 110=long }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits, OpMode: Integer;
 Dn: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode = AM_DATA_REG Then
 Begin
  { OR <ea>, Dn }
  Dn := Dst.Reg;
  OpMode := SzBits; { 000/001/010 }
  If Not CheckEAMask(Src, EA_DATA) Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         'mode source invalide pour OR');
   SkipToEOL; Exit;
  End;
  EA := EncodeEA(Src);
  If EA < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'encodage EA source impossible');
   SkipToEOL; Exit;
  End;
  InstrW := $8000 or Word(Dn shl 9) or Word(OpMode shl 6) or Word(EA);
  Emit16(InstrW);
  EmitExtWords(Src, ActualSize);
 End
 Else If Src.Mode = AM_DATA_REG Then
 Begin
  { OR Dn, <ea> }
  Dn := Src.Reg;
  OpMode := SzBits + 4; { 100/101/110 }
  If Not CheckEAMask(Dst, EA_MEM_ALT) Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         'mode destination invalide pour OR Dn,<ea>');
   SkipToEOL; Exit;
  End;
  EA := EncodeEA(Dst);
  If EA < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'encodage EA destination impossible');
   SkipToEOL; Exit;
  End;
  InstrW := $8000 or Word(Dn shl 9) or Word(OpMode shl 6) or Word(EA);
  Emit16(InstrW);
  EmitExtWords(Dst, ActualSize);
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col,
        'OR requiert un registre de donnees en source ou destination');
  SkipToEOL;
 End;
End;

Procedure InstrORI(OpSize: Integer);
{ ORI.s #imm,<ea> -> $0000 | sz<<6 | dstEA(6) + ext words
  ORI #imm,CCR    -> $003C + imm word
  ORI #imm,SR     -> $007C + imm word }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Src.Mode <> AM_IMMEDIATE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'ORI requiert un immediat en source');
  SkipToEOL; Exit;
 End;

 { Cas special : ORI #imm, CCR / SR }
 If Dst.Mode = AM_SR_CCR Then
 Begin
  If Dst.Reg = REG_CCR Then
  Begin
   Emit16($003C);
   Emit16(Word(Src.Imm32 and $FF));
  End
  Else If Dst.Reg = REG_SR Then
  Begin
   Emit16($007C);
   Emit16(Word(Src.Imm32 and $FFFF));
  End
  Else
  Begin
   Error(cur_tok_line, cur_tok_col, 'destination invalide pour ORI');
   SkipToEOL;
  End;
  Exit;
 End;

 If Not CheckEAMask(Dst, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode destination invalide pour ORI');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Dst);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA destination impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $0000 or Word(SzBits shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Src, ActualSize);
 EmitExtWords(Dst, ActualSize);
End;

Procedure InstrEOR(OpSize: Integer);
{ EOR.s Dn,<ea> -> $B000 | Dn<<9 | opmode(3) | dstEA(6)
  opmode : 100=byte, 101=word, 110=long (uniquement forme Dn,ea) }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits, OpMode: Integer;
 Dn: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Src.Mode <> AM_DATA_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'EOR requiert un registre de donnees en source');
  SkipToEOL; Exit;
 End;

 Dn := Src.Reg;
 OpMode := SzBits + 4; { 100/101/110 }

 If Not CheckEAMask(Dst, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode destination invalide pour EOR');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Dst);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA destination impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $B000 or Word(Dn shl 9) or Word(OpMode shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Dst, ActualSize);
End;

Procedure InstrEORI(OpSize: Integer);
{ EORI.s #imm,<ea> -> $0A00 | sz<<6 | dstEA(6) + ext words
  EORI #imm,CCR    -> $0A3C + imm word
  EORI #imm,SR     -> $0A7C + imm word }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Src.Mode <> AM_IMMEDIATE Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'EORI requiert un immediat en source');
  SkipToEOL; Exit;
 End;

 { Cas special : EORI #imm, CCR / SR }
 If Dst.Mode = AM_SR_CCR Then
 Begin
  If Dst.Reg = REG_CCR Then
  Begin
   Emit16($0A3C);
   Emit16(Word(Src.Imm32 and $FF));
  End
  Else If Dst.Reg = REG_SR Then
  Begin
   Emit16($0A7C);
   Emit16(Word(Src.Imm32 and $FFFF));
  End
  Else
  Begin
   Error(cur_tok_line, cur_tok_col, 'destination invalide pour EORI');
   SkipToEOL;
  End;
  Exit;
 End;

 If Not CheckEAMask(Dst, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode destination invalide pour EORI');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Dst);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA destination impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $0A00 or Word(SzBits shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Src, ActualSize);
 EmitExtWords(Dst, ActualSize);
End;

Procedure InstrNOT(OpSize: Integer);
{ NOT.s <ea> -> $4600 | sz<<6 | dstEA(6) }
Var
 Op: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
Begin
 ActualSize := OpSize;
 If ActualSize = 0 Then ActualSize := SIZE_WORD;
 SzBits := EncodeSizeBits(ActualSize);

 ParseOperand(Op);
 If Not CheckEAMask(Op, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode d''adressage invalide pour NOT');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Op);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $4600 or Word(SzBits shl 6) or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Op, ActualSize);
End;

{ --- Instructions de manipulation de bits (BTST, BSET, BCLR, BCHG) --- }

Procedure InstrBitOp(DynBase, StatBase: Word; Const Name: String;
                     AllowReadOnly: Boolean);
{ Generique pour BTST/BSET/BCLR/BCHG
  DynBase  = opcode de base pour forme Dn,<ea>
  StatBase = opcode de base pour forme #imm,<ea>
  AllowReadOnly = True pour BTST (EA_DATA), False sinon (EA_DATA_ALT) }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 Dn: Integer;
 EAMask: Integer;
Begin
 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If AllowReadOnly Then
  EAMask := EA_DATA
 Else
  EAMask := EA_DATA_ALT;

 If Not CheckEAMask(Dst, EAMask) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode destination invalide pour ' + Name);
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Dst);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA destination impossible');
  SkipToEOL; Exit;
 End;

 If Src.Mode = AM_DATA_REG Then
 Begin
  { Forme dynamique : Dn, <ea> }
  Dn := Src.Reg;
  InstrW := DynBase or Word(Dn shl 9) or Word(EA);
  Emit16(InstrW);
  EmitExtWords(Dst, SIZE_BYTE);
 End
 Else If Src.Mode = AM_IMMEDIATE Then
 Begin
  { Forme statique : #imm, <ea> }
  InstrW := StatBase or Word(EA);
  Emit16(InstrW);
  Emit16(Word(Src.Imm32 and $FF));
  EmitExtWords(Dst, SIZE_BYTE);
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col,
        Name + ' requiert Dn ou #imm en source');
  SkipToEOL;
 End;
End;

Procedure InstrBTST;
Begin
 InstrBitOp($0100, $0800, 'BTST', True);
End;

Procedure InstrBSET;
Begin
 InstrBitOp($01C0, $08C0, 'BSET', False);
End;

Procedure InstrBCLR;
Begin
 InstrBitOp($0180, $0880, 'BCLR', False);
End;

Procedure InstrBCHG;
Begin
 InstrBitOp($0140, $0840, 'BCHG', False);
End;

{ ====================================================================== }
{ TODO 14 - Instructions de decalage et rotation                         }
{ ====================================================================== }

Procedure InstrShiftRot(OpSize: Integer; TypeBits: Integer;
                        DirBit: Integer; MemBase: Word;
                        Const Name: String);
{ Generique pour ASL/ASR/LSL/LSR/ROL/ROR/ROXL/ROXR.
  TypeBits = 0 (AS), 1 (LS), 2 (ROX), 3 (RO)
  DirBit   = 0 (right), 1 (left)
  MemBase  = opcode de base pour la forme memoire

  Forme registre :
    1110 cnt/reg dr size i/r type reg
    - #count, Dn : i/r=0, cnt = count (1-7, 0 = 8)
    - Dm, Dn     : i/r=1, cnt = Dm

  Forme memoire (1 operande, mot seulement, 1 bit) :
    1110 0 type dr 11 ea(6) }
Var
 Src, Dst: TOperand;
 EA: Integer;
 InstrW: Word;
 ActualSize, SzBits: Integer;
 Count: Integer;
Begin
 ParseOperand(Src);

 If cur_tok = TOK_COMMA Then
 Begin
  { Forme a deux operandes : #imm,Dn ou Dm,Dn }
  NextToken;
  ParseOperand(Dst);

  If Dst.Mode <> AM_DATA_REG Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         Name + ' registre : destination doit etre Dn');
   SkipToEOL; Exit;
  End;

  ActualSize := OpSize;
  If ActualSize = 0 Then ActualSize := SIZE_WORD;
  SzBits := EncodeSizeBits(ActualSize);

  If Src.Mode = AM_IMMEDIATE Then
  Begin
   { #count, Dn }
   Count := Src.Imm32;
   If (Count < 1) or (Count > 8) Then
   Begin
    Error(cur_tok_line, cur_tok_col,
          Name + ' : compteur immediat doit etre entre 1 et 8');
    SkipToEOL; Exit;
   End;
   If Count = 8 Then Count := 0;
   InstrW := $E000 or Word(Count shl 9) or Word(DirBit shl 8)
             or Word(SzBits shl 6) or Word(TypeBits shl 3)
             or Word(Dst.Reg);
   Emit16(InstrW);
  End
  Else If Src.Mode = AM_DATA_REG Then
  Begin
   { Dm, Dn }
   InstrW := $E000 or Word(Src.Reg shl 9) or Word(DirBit shl 8)
             or Word(SzBits shl 6) or Word(1 shl 5)
             or Word(TypeBits shl 3) or Word(Dst.Reg);
   Emit16(InstrW);
  End
  Else
  Begin
   Error(cur_tok_line, cur_tok_col,
         Name + ' requiert #imm ou Dn en source');
   SkipToEOL;
  End;
 End
 Else
 Begin
  { Forme a un operande : decalage memoire (mot, 1 bit) }
  If (OpSize <> 0) and (OpSize <> SIZE_WORD) Then
   Warning(cur_tok_line, cur_tok_col,
           Name + ' memoire : seule la taille .W est autorisee');

  If Not CheckEAMask(Src, EA_MEM_ALT) Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         'mode d''adressage invalide pour ' + Name + ' memoire');
   SkipToEOL; Exit;
  End;

  EA := EncodeEA(Src);
  If EA < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
   SkipToEOL; Exit;
  End;

  InstrW := MemBase or Word(EA);
  Emit16(InstrW);
  EmitExtWords(Src, SIZE_WORD);
 End;
End;

Procedure InstrASL(OpSize: Integer);
Begin InstrShiftRot(OpSize, 0, 1, $E1C0, 'ASL'); End;

Procedure InstrASR(OpSize: Integer);
Begin InstrShiftRot(OpSize, 0, 0, $E0C0, 'ASR'); End;

Procedure InstrLSL(OpSize: Integer);
Begin InstrShiftRot(OpSize, 1, 1, $E3C0, 'LSL'); End;

Procedure InstrLSR(OpSize: Integer);
Begin InstrShiftRot(OpSize, 1, 0, $E2C0, 'LSR'); End;

Procedure InstrROL(OpSize: Integer);
Begin InstrShiftRot(OpSize, 3, 1, $E7C0, 'ROL'); End;

Procedure InstrROR(OpSize: Integer);
Begin InstrShiftRot(OpSize, 3, 0, $E6C0, 'ROR'); End;

Procedure InstrROXL(OpSize: Integer);
Begin InstrShiftRot(OpSize, 2, 1, $E5C0, 'ROXL'); End;

Procedure InstrROXR(OpSize: Integer);
Begin InstrShiftRot(OpSize, 2, 0, $E4C0, 'ROXR'); End;

{ ====================================================================== }
{ TODO 15 - Instructions de branchement et controle de flux              }
{ ====================================================================== }

Function EncodeCondCode(Const CC: String): Integer;
{ Retourne le code condition 4 bits (0-15) pour un suffixe Bcc/DBcc/Scc.
  Retourne -1 si le code condition n'est pas reconnu. }
Begin
 EncodeCondCode := -1;
 If CC = 'T'  Then EncodeCondCode :=  0   { True (toujours)    }
 Else If CC = 'F'  Then EncodeCondCode :=  1   { False (jamais)     }
 Else If CC = 'HI' Then EncodeCondCode :=  2   { HIgh (!C & !Z)     }
 Else If CC = 'LS' Then EncodeCondCode :=  3   { Low or Same (C|Z)  }
 Else If CC = 'CC' Then EncodeCondCode :=  4   { Carry Clear (C=0)  }
 Else If CC = 'HS' Then EncodeCondCode :=  4   { alias CC           }
 Else If CC = 'CS' Then EncodeCondCode :=  5   { Carry Set (C=1)    }
 Else If CC = 'LO' Then EncodeCondCode :=  5   { alias CS           }
 Else If CC = 'NE' Then EncodeCondCode :=  6   { Not Equal (Z=0)    }
 Else If CC = 'EQ' Then EncodeCondCode :=  7   { Equal (Z=1)        }
 Else If CC = 'VC' Then EncodeCondCode :=  8   { oVerflow Clear     }
 Else If CC = 'VS' Then EncodeCondCode :=  9   { oVerflow Set       }
 Else If CC = 'PL' Then EncodeCondCode := 10   { PLus (N=0)         }
 Else If CC = 'MI' Then EncodeCondCode := 11   { MInus (N=1)        }
 Else If CC = 'GE' Then EncodeCondCode := 12   { Greater or Equal   }
 Else If CC = 'LT' Then EncodeCondCode := 13   { Less Than          }
 Else If CC = 'GT' Then EncodeCondCode := 14   { Greater Than       }
 Else If CC = 'LE' Then EncodeCondCode := 15;  { Less or Equal      }
End;

Procedure InstrBcc(Const OpName: String; OpSize: Integer);
{ BRA, BSR, Bcc (BEQ, BNE, BCC, BCS, BMI, BPL, BVS, BVC, BHI, BLS,
  BGE, BLT, BGT, BLE).
  Encodage : 0110 cond disp8
  Si disp8 = $00 -> mot d'extension 16 bits (deplacement .W)
  Si disp8 = disp (>= -128 et <= 127 et != 0) -> .S (8 bits)

  BRA = condition 0 (T=always), BSR = condition 1 (F=never, spe'cial) }
Var
 CC    : Integer;
 CCStr : String;
 TargetVal : LongInt;
 InstrPC   : LongInt;
 Disp      : LongInt;
 InstrW    : Word;
 IsShort   : Boolean;
Begin
 { Determiner le code condition }
 If OpName = 'BRA' Then
  CC := 0 { T = always }
 Else If OpName = 'BSR' Then
  CC := 1 { special }
 Else
 Begin
  { Extraire le suffixe condition apres 'B' }
  CCStr := Copy(OpName, 2, Length(OpName) - 1);
  CC := EncodeCondCode(CCStr);
  If CC < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         'code condition inconnu: ' + OpName);
   SkipToEOL; Exit;
  End;
 End;

 { Evaluer l'adresse cible }
 TargetVal := EvalExpr;
 InstrPC := GetPC;

 { Calculer le deplacement PC-relatif (a partir de PC+2) }
 Disp := TargetVal - (InstrPC + 2);

 { Determiner si deplacement court (.S/.B) ou mot (.W) }
 IsShort := False;
 If OpSize = SIZE_BYTE Then
  IsShort := True    { Forcement .S par le programmeur }
 Else If OpSize = SIZE_WORD Then
  IsShort := False   { Forcement .W par le programmeur }
 Else
 Begin
  { Automatique : .S si le deplacement tient en 8 bits signes
    et n'est pas 0 et pas -1 ($FF est reserve pour le 68020) }
  If (Disp >= -128) and (Disp <= 127) and (Disp <> 0) Then
   IsShort := True
  Else
   IsShort := False;
 End;

 If IsShort Then
 Begin
  { Deplacement 8 bits }
  If (pass_num = 2) and ((Disp < -128) or (Disp > 127)) Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         OpName + '.S : deplacement hors limites 8 bits (' +
         IntToStr(Disp) + ')');
   SkipToEOL; Exit;
  End;
  InstrW := Word($6000 or (CC shl 8) or (Disp and $FF));
  Emit16(InstrW);
 End
 Else
 Begin
  { Deplacement 16 bits : disp8 = $00, suivi du mot d'extension }
  If (pass_num = 2) and ((Disp < -32768) or (Disp > 32767)) Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         OpName + '.W : deplacement hors limites 16 bits (' +
         IntToStr(Disp) + ')');
   SkipToEOL; Exit;
  End;
  InstrW := Word($6000 or (CC shl 8) or $00);
  Emit16(InstrW);
  Emit16(Word(Disp and $FFFF));
 End;
End;

Procedure InstrDBcc(Const OpName: String);
{ DBcc Dn, label
  Encodage : 0101 cond 11001 reg(3) + mot deplacement 16 bits.
  DBRA/DBF = condition 1 (F = toujours decrementer et brancher).
  Le deplacement est PC-relatif (a partir de l'adresse du mot d'extension). }
Var
 CC       : Integer;
 CCStr    : String;
 Reg      : TOperand;
 TargetVal: LongInt;
 InstrPC  : LongInt;
 Disp     : LongInt;
 InstrW   : Word;
Begin
 { Determiner le code condition }
 If (OpName = 'DBRA') or (OpName = 'DBF') Then
  CC := 1 { F = false = toujours boucler }
 Else If OpName = 'DBT' Then
  CC := 0 { T = true = jamais boucler }
 Else
 Begin
  { Extraire le suffixe condition apres 'DB' }
  CCStr := Copy(OpName, 3, Length(OpName) - 2);
  CC := EncodeCondCode(CCStr);
  If CC < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         'code condition inconnu: ' + OpName);
   SkipToEOL; Exit;
  End;
 End;

 { Premier operande : Dn }
 ParseOperand(Reg);
 If Reg.Mode <> AM_DATA_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        OpName + ' requiert un registre Dn en premier operande');
  SkipToEOL; Exit;
 End;

 { Virgule }
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        OpName + ' : virgule attendue apres Dn');
  SkipToEOL; Exit;
 End;
 NextToken;

 { Deuxieme operande : label (expression) }
 InstrPC := GetPC;
 TargetVal := EvalExpr;

 { Le deplacement est relatif a PC+2 (adresse du mot de deplacement) }
 Disp := TargetVal - (InstrPC + 2);

 If (pass_num = 2) and ((Disp < -32768) or (Disp > 32767)) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        OpName + ' : deplacement hors limites 16 bits (' +
        IntToStr(Disp) + ')');
  SkipToEOL; Exit;
 End;

 InstrW := Word($50C8 or (CC shl 8) or Reg.Reg);
 Emit16(InstrW);
 Emit16(Word(Disp and $FFFF));
End;

Procedure InstrScc(Const OpName: String);
{ Scc ea
  Encodage : 0101 cond 11 ea(6)
  Positionne l'octet a $FF si condition vraie, $00 sinon.
  ST = condition 0 (T), SF = condition 1 (F) }
Var
 CC    : Integer;
 CCStr : String;
 Dst   : TOperand;
 EA    : Integer;
 InstrW: Word;
Begin
 { Determiner le code condition }
 If OpName = 'ST' Then
  CC := 0 { T = toujours vrai }
 Else If OpName = 'SF' Then
  CC := 1 { F = toujours faux }
 Else
 Begin
  { Extraire le suffixe condition apres 'S' }
  CCStr := Copy(OpName, 2, Length(OpName) - 1);
  CC := EncodeCondCode(CCStr);
  If CC < 0 Then
  Begin
   Error(cur_tok_line, cur_tok_col,
         'code condition inconnu: ' + OpName);
   SkipToEOL; Exit;
  End;
 End;

 { Operande : ea (data alterable) }
 ParseOperand(Dst);
 If Not CheckEAMask(Dst, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode d''adressage invalide pour ' + OpName);
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Dst);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
  SkipToEOL; Exit;
 End;

 InstrW := Word($50C0 or (CC shl 8) or EA);
 Emit16(InstrW);
 EmitExtWords(Dst, SIZE_BYTE);
End;

Procedure InstrJMP;
{ JMP ea
  Encodage : 0100 1110 11 ea(6)  -> $4EC0 | EA
  Modes autorises : controle (pas Dn, An, (An)+, -(An), #imm) }
Var
 Dst   : TOperand;
 EA    : Integer;
 InstrW: Word;
Begin
 ParseOperand(Dst);
 If Not CheckEAMask(Dst, EA_CONTROL) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode d''adressage invalide pour JMP');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Dst);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $4EC0 or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Dst, SIZE_WORD);
End;

Procedure InstrJSR;
{ JSR ea
  Encodage : 0100 1110 10 ea(6)  -> $4E80 | EA
  Modes autorises : controle }
Var
 Dst   : TOperand;
 EA    : Integer;
 InstrW: Word;
Begin
 ParseOperand(Dst);
 If Not CheckEAMask(Dst, EA_CONTROL) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode d''adressage invalide pour JSR');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Dst);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $4E80 or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Dst, SIZE_WORD);
End;

Procedure InstrRTS;
{ RTS - Return from Subroutine : $4E75 }
Begin
 Emit16($4E75);
End;

Procedure InstrRTE;
{ RTE - Return from Exception : $4E73 }
Begin
 Emit16($4E73);
End;

Procedure InstrRTR;
{ RTR - Return and Restore CCR : $4E77 }
Begin
 Emit16($4E77);
End;

Procedure InstrNOP;
{ NOP - No Operation : $4E71 }
Begin
 Emit16($4E71);
End;

{ ============================================================================ }
{ TODO 16 - Instructions BCD et operations speciales                          }
{ ============================================================================ }
{ ABCD, SBCD, NBCD, CHK, TRAP, TRAPV, MOVE USP, STOP, RESET, ILLEGAL        }

Procedure InstrABCD;
{ ABCD Dn,Dn       -> $C100 | Dn_dst<<9 | Dn_src
  ABCD -(An),-(An) -> $C108 | An_dst<<9 | An_src }
Var
 Src, Dst: TOperand;
 InstrW: Word;
Begin
 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If (Src.Mode = AM_DATA_REG) and (Dst.Mode = AM_DATA_REG) Then
 Begin
  InstrW := $C100 or Word(Dst.Reg shl 9) or Word(Src.Reg);
  Emit16(InstrW);
 End
 Else If (Src.Mode = AM_ADDR_IND_PRE) and (Dst.Mode = AM_ADDR_IND_PRE) Then
 Begin
  InstrW := $C108 or Word((Dst.Reg - REG_A0) shl 9)
            or Word(Src.Reg - REG_A0);
  Emit16(InstrW);
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col,
        'ABCD requiert Dn,Dn ou -(An),-(An)');
  SkipToEOL;
 End;
End;

Procedure InstrSBCD;
{ SBCD Dn,Dn       -> $8100 | Dn_dst<<9 | Dn_src
  SBCD -(An),-(An) -> $8108 | An_dst<<9 | An_src }
Var
 Src, Dst: TOperand;
 InstrW: Word;
Begin
 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If (Src.Mode = AM_DATA_REG) and (Dst.Mode = AM_DATA_REG) Then
 Begin
  InstrW := $8100 or Word(Dst.Reg shl 9) or Word(Src.Reg);
  Emit16(InstrW);
 End
 Else If (Src.Mode = AM_ADDR_IND_PRE) and (Dst.Mode = AM_ADDR_IND_PRE) Then
 Begin
  InstrW := $8108 or Word((Dst.Reg - REG_A0) shl 9)
            or Word(Src.Reg - REG_A0);
  Emit16(InstrW);
 End
 Else
 Begin
  Error(cur_tok_line, cur_tok_col,
        'SBCD requiert Dn,Dn ou -(An),-(An)');
  SkipToEOL;
 End;
End;

Procedure InstrNBCD;
{ NBCD <ea> -> $4800 | EA(6), data alterable }
Var
 Op: TOperand;
 EA: Integer;
 InstrW: Word;
Begin
 ParseOperand(Op);
 If Not CheckEAMask(Op, EA_DATA_ALT) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode d''adressage invalide pour NBCD');
  SkipToEOL; Exit;
 End;

 EA := EncodeEA(Op);
 If EA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $4800 or Word(EA);
 Emit16(InstrW);
 EmitExtWords(Op, SIZE_BYTE);
End;

Procedure InstrCHK(OpSize: Integer);
{ CHK.W <ea>,Dn -> $4180 | Dn<<9 | srcEA(6)
  (68000 = word only) }
Var
 Src, Dst: TOperand;
 SrcEA: Integer;
 InstrW: Word;
Begin
 If (OpSize <> 0) and (OpSize <> SIZE_WORD) Then
  Warning(cur_tok_line, cur_tok_col,
          'CHK: seule la taille .W est supportee sur 68000');

 ParseOperand(Src);
 If cur_tok <> TOK_COMMA Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'virgule attendue');
  SkipToEOL; Exit;
 End;
 NextToken;
 ParseOperand(Dst);

 If Dst.Mode <> AM_DATA_REG Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'CHK: destination doit etre un registre de donnees Dn');
  SkipToEOL; Exit;
 End;

 If Not CheckEAMask(Src, EA_DATA) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'mode d''adressage source invalide pour CHK');
  SkipToEOL; Exit;
 End;

 SrcEA := EncodeEA(Src);
 If SrcEA < 0 Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'encodage EA impossible');
  SkipToEOL; Exit;
 End;

 InstrW := $4180 or Word(Dst.Reg shl 9) or Word(SrcEA);
 Emit16(InstrW);
 EmitExtWords(Src, SIZE_WORD);
End;

Procedure InstrTRAP;
{ TRAP #vector -> $4E40 | vector(4 bits, 0-15) }
Var
 Vec: LongInt;
Begin
 If cur_tok <> TOK_HASH Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'TRAP: # attendu avant le vecteur');
  SkipToEOL; Exit;
 End;
 NextToken;
 Vec := EvalExpr;
 If (Vec < 0) or (Vec > 15) Then
 Begin
  Error(cur_tok_line, cur_tok_col,
        'TRAP: vecteur doit etre entre 0 et 15');
  SkipToEOL; Exit;
 End;
 Emit16(Word($4E40 or (Vec and $0F)));
End;

Procedure InstrTRAPV;
{ TRAPV - Trap on overflow : $4E76 }
Begin
 Emit16($4E76);
End;

Procedure InstrSTOP;
{ STOP #imm -> $4E72 + mot immediat 16 bits }
Var
 Imm: LongInt;
Begin
 If cur_tok <> TOK_HASH Then
 Begin
  Error(cur_tok_line, cur_tok_col, 'STOP: # attendu avant la valeur');
  SkipToEOL; Exit;
 End;
 NextToken;
 Imm := EvalExpr;
 Emit16($4E72);
 Emit16(Word(Imm and $FFFF));
End;

Procedure InstrRESET;
{ RESET - Reset external devices : $4E70 }
Begin
 Emit16($4E70);
End;

Procedure InstrILLEGAL;
{ ILLEGAL - Illegal instruction exception : $4AFC }
Begin
 Emit16($4AFC);
End;

{ ============================================================================ }
{ TODO 17 - Encodage binaire des instructions (passe 2)                        }
{ ============================================================================ }

Function EncodeMoveSizeBits(S: Integer): Integer;
{ Encodage taille MOVE : 01=byte, 11=word, 10=long (different du standard!) }
Begin
 Case S of
  SIZE_BYTE: EncodeMoveSizeBits := 1; { 01 }
  SIZE_WORD: EncodeMoveSizeBits := 3; { 11 }
  SIZE_LONG: EncodeMoveSizeBits := 2; { 10 }
 Else
  EncodeMoveSizeBits := 3; { defaut = word }
 End;
End;

Function EncodeMOVE(SzBits, SrcEA, DstEA: Integer): Word;
{ MOVE : 00ss_ddd_mmm_MMM_rrr - destination mode/reg inverses }
Var
 DstMd, DstRg: Integer;
Begin
 DstMd := (DstEA shr 3) and 7;
 DstRg := DstEA and 7;
 EncodeMOVE := Word(SzBits shl 12) or Word(DstRg shl 9)
               or Word(DstMd shl 6) or Word(SrcEA and $3F);
End;

Function EncodeArith(BaseOp: Word; Dn, OpMode, EA: Integer): Word;
{ Arith : BaseOp | rrr_ooo_MMMRRR (ADD $D000, SUB $9000, CMP $B000, etc.) }
Begin
 EncodeArith := BaseOp or Word(Dn shl 9) or Word(OpMode shl 6)
                or Word(EA and $3F);
End;

Function EncodeImmediate(BaseOp: Word; SzBits, EA: Integer): Word;
{ Immediate : BaseOp | ss_MMMRRR (ADDI $0600, SUBI $0400, CMPI $0C00, etc.) }
Begin
 EncodeImmediate := BaseOp or Word(SzBits shl 6) or Word(EA and $3F);
End;

Function EncodeShift(Count, Dir, SzBits, IR, TypeBits, Reg: Integer): Word;
{ Shift registre : $E000 | cnt_d_ss_ir_tt_rrr }
Begin
 EncodeShift := Word($E000) or Word((Count and 7) shl 9) or Word(Dir shl 8)
                or Word(SzBits shl 6) or Word(IR shl 5)
                or Word(TypeBits shl 3) or Word(Reg and 7);
End;

Function EncodeShiftMem(MemBase: Word; EA: Integer): Word;
{ Shift memoire : MemBase | MMMRRR }
Begin
 EncodeShiftMem := MemBase or Word(EA and $3F);
End;

Function EncodeBranch(CC, Disp8: Integer): Word;
{ Branch : $6000 | cccc_dddddddd }
Begin
 EncodeBranch := Word($6000) or Word(CC shl 8) or Word(Disp8 and $FF);
End;

Function EncodeBitDyn(DynBase: Word; Dn, EA: Integer): Word;
{ Bit dynamique : DynBase | rrr_MMMRRR }
Begin
 EncodeBitDyn := DynBase or Word(Dn shl 9) or Word(EA and $3F);
End;

Function EncodeBitStat(StatBase: Word; EA: Integer): Word;
{ Bit statique : StatBase | MMMRRR }
Begin
 EncodeBitStat := StatBase or Word(EA and $3F);
End;

Function EncodeOneEA(BaseOp: Word; SzBits, EA: Integer): Word;
{ Unaire : BaseOp | ss_MMMRRR (NEG, NEGX, CLR, NOT, TST) }
Begin
 EncodeOneEA := BaseOp or Word(SzBits shl 6) or Word(EA and $3F);
End;

Function CalcInstrSize(Const OpName: String; OpSize: Integer;
                       Const Src, Dst: TOperand): Integer;
{ Calcule la taille totale d'une instruction en octets (passe 1) }
Var
 Total: Integer;
 UpName: String;
Begin
 Total := 2; { mot d'instruction de base }
 UpName := OpName;

 { Branchements courts : 2 octets ; longs : 4 octets }
 If (UpName = 'BRA') or (UpName = 'BSR') or (UpName = 'BHI')
    or (UpName = 'BLS') or (UpName = 'BCC') or (UpName = 'BCS')
    or (UpName = 'BNE') or (UpName = 'BEQ') or (UpName = 'BVC')
    or (UpName = 'BVS') or (UpName = 'BPL') or (UpName = 'BMI')
    or (UpName = 'BGE') or (UpName = 'BLT') or (UpName = 'BGT')
    or (UpName = 'BLE') Then
 Begin
  If OpSize = SIZE_WORD Then
   Total := 4  { mot d'instruction + deplacement 16 bits }
  Else
   Total := 2; { deplacement 8 bits dans le mot d'instruction }
  CalcInstrSize := Total;
  Exit;
 End;

 { DBcc : mot d'instruction + deplacement 16 bits }
 If (UpName = 'DBRA') or (UpName = 'DBT') or (UpName = 'DBF')
    or (UpName = 'DBHI') or (UpName = 'DBLS') or (UpName = 'DBCC')
    or (UpName = 'DBCS') or (UpName = 'DBNE') or (UpName = 'DBEQ')
    or (UpName = 'DBVC') or (UpName = 'DBVS') or (UpName = 'DBPL')
    or (UpName = 'DBMI') or (UpName = 'DBGE') or (UpName = 'DBLT')
    or (UpName = 'DBGT') or (UpName = 'DBLE') Then
 Begin
  CalcInstrSize := 4;
  Exit;
 End;

 { MOVEM : mot d'instruction + masque registres + extension EA dst }
 If UpName = 'MOVEM' Then
 Begin
  Total := 4; { instruction + masque 16 bits }
  If Src.Mode = AM_REG_LIST Then
   Total := Total + 2 * CalcExtWords(Dst, OpSize)
  Else
   Total := Total + 2 * CalcExtWords(Src, OpSize);
  CalcInstrSize := Total;
  Exit;
 End;

 { MOVEP : mot d'instruction + deplacement 16 bits }
 If UpName = 'MOVEP' Then
 Begin
  CalcInstrSize := 4;
  Exit;
 End;

 { LINK : mot d'instruction + deplacement 16 bits }
 If UpName = 'LINK' Then
 Begin
  CalcInstrSize := 4;
  Exit;
 End;

 { STOP : mot d'instruction + donnee immediate 16 bits }
 If UpName = 'STOP' Then
 Begin
  CalcInstrSize := 4;
  Exit;
 End;

 { Cas general : base + extensions source + extensions destination }
 Total := Total + 2 * CalcExtWords(Src, OpSize);
 Total := Total + 2 * CalcExtWords(Dst, OpSize);
 CalcInstrSize := Total;
End;

Procedure AssembleInstruction(Const OpName: String; OpSize: Integer);
{ Dispatch : appelle le bon encodeur selon le mnemonique }
Begin
 { --- Instructions de transfert (TODO 11) --- }
 If OpName = 'MOVE' Then InstrMOVE(OpSize)
 Else If OpName = 'MOVEA' Then InstrMOVEA(OpSize)
 Else If OpName = 'MOVEQ' Then InstrMOVEQ
 Else If OpName = 'MOVEM' Then InstrMOVEM(OpSize)
 Else If OpName = 'MOVEP' Then InstrMOVEP(OpSize)
 Else If OpName = 'LEA' Then InstrLEA
 Else If OpName = 'PEA' Then InstrPEA
 Else If OpName = 'EXG' Then InstrEXG
 Else If OpName = 'SWAP' Then InstrSWAP
 Else If OpName = 'LINK' Then InstrLINK
 Else If OpName = 'UNLK' Then InstrUNLK
 { --- Instructions arithmetiques (TODO 12) --- }
 Else If OpName = 'ADD' Then InstrADD(OpSize)
 Else If OpName = 'ADDA' Then InstrADDA(OpSize)
 Else If OpName = 'ADDQ' Then InstrADDQ(OpSize)
 Else If OpName = 'ADDI' Then InstrADDI(OpSize)
 Else If OpName = 'ADDX' Then InstrADDX(OpSize)
 Else If OpName = 'SUB' Then InstrSUB(OpSize)
 Else If OpName = 'SUBA' Then InstrSUBA(OpSize)
 Else If OpName = 'SUBQ' Then InstrSUBQ(OpSize)
 Else If OpName = 'SUBI' Then InstrSUBI(OpSize)
 Else If OpName = 'SUBX' Then InstrSUBX(OpSize)
 Else If OpName = 'MULS' Then InstrMULS(OpSize)
 Else If OpName = 'MULU' Then InstrMULU(OpSize)
 Else If OpName = 'DIVS' Then InstrDIVS(OpSize)
 Else If OpName = 'DIVU' Then InstrDIVU(OpSize)
 Else If OpName = 'NEG' Then InstrNEG(OpSize)
 Else If OpName = 'NEGX' Then InstrNEGX(OpSize)
 Else If OpName = 'CLR' Then InstrCLR(OpSize)
 Else If OpName = 'EXT' Then InstrEXT(OpSize)
 Else If OpName = 'CMP' Then InstrCMP(OpSize)
 Else If OpName = 'CMPA' Then InstrCMPA(OpSize)
 Else If OpName = 'CMPI' Then InstrCMPI(OpSize)
 Else If OpName = 'CMPM' Then InstrCMPM(OpSize)
 Else If OpName = 'TST' Then InstrTST(OpSize)
 Else If OpName = 'TAS' Then InstrTAS
 { --- Instructions logiques et bit (TODO 13) --- }
 Else If OpName = 'AND' Then InstrAND(OpSize)
 Else If OpName = 'ANDI' Then InstrANDI(OpSize)
 Else If OpName = 'OR' Then InstrOR(OpSize)
 Else If OpName = 'ORI' Then InstrORI(OpSize)
 Else If OpName = 'EOR' Then InstrEOR(OpSize)
 Else If OpName = 'EORI' Then InstrEORI(OpSize)
 Else If OpName = 'NOT' Then InstrNOT(OpSize)
 Else If OpName = 'BTST' Then InstrBTST
 Else If OpName = 'BSET' Then InstrBSET
 Else If OpName = 'BCLR' Then InstrBCLR
 Else If OpName = 'BCHG' Then InstrBCHG
 { --- Instructions de decalage et rotation (TODO 14) --- }
 Else If OpName = 'ASL' Then InstrASL(OpSize)
 Else If OpName = 'ASR' Then InstrASR(OpSize)
 Else If OpName = 'LSL' Then InstrLSL(OpSize)
 Else If OpName = 'LSR' Then InstrLSR(OpSize)
 Else If OpName = 'ROL' Then InstrROL(OpSize)
 Else If OpName = 'ROR' Then InstrROR(OpSize)
 Else If OpName = 'ROXL' Then InstrROXL(OpSize)
 Else If OpName = 'ROXR' Then InstrROXR(OpSize)
 { --- Instructions de branchement et controle de flux (TODO 15) --- }
 Else If OpName = 'BRA' Then InstrBcc('BRA', OpSize)
 Else If OpName = 'BSR' Then InstrBcc('BSR', OpSize)
 Else If OpName = 'BEQ' Then InstrBcc('BEQ', OpSize)
 Else If OpName = 'BNE' Then InstrBcc('BNE', OpSize)
 Else If OpName = 'BCC' Then InstrBcc('BCC', OpSize)
 Else If OpName = 'BCS' Then InstrBcc('BCS', OpSize)
 Else If OpName = 'BHS' Then InstrBcc('BHS', OpSize)
 Else If OpName = 'BLO' Then InstrBcc('BLO', OpSize)
 Else If OpName = 'BMI' Then InstrBcc('BMI', OpSize)
 Else If OpName = 'BPL' Then InstrBcc('BPL', OpSize)
 Else If OpName = 'BVS' Then InstrBcc('BVS', OpSize)
 Else If OpName = 'BVC' Then InstrBcc('BVC', OpSize)
 Else If OpName = 'BHI' Then InstrBcc('BHI', OpSize)
 Else If OpName = 'BLS' Then InstrBcc('BLS', OpSize)
 Else If OpName = 'BGE' Then InstrBcc('BGE', OpSize)
 Else If OpName = 'BLT' Then InstrBcc('BLT', OpSize)
 Else If OpName = 'BGT' Then InstrBcc('BGT', OpSize)
 Else If OpName = 'BLE' Then InstrBcc('BLE', OpSize)
 Else If OpName = 'DBRA' Then InstrDBcc('DBRA')
 Else If OpName = 'DBF'  Then InstrDBcc('DBF')
 Else If OpName = 'DBT'  Then InstrDBcc('DBT')
 Else If OpName = 'DBCC' Then InstrDBcc('DBCC')
 Else If OpName = 'DBCS' Then InstrDBcc('DBCS')
 Else If OpName = 'DBEQ' Then InstrDBcc('DBEQ')
 Else If OpName = 'DBNE' Then InstrDBcc('DBNE')
 Else If OpName = 'DBMI' Then InstrDBcc('DBMI')
 Else If OpName = 'DBPL' Then InstrDBcc('DBPL')
 Else If OpName = 'DBVS' Then InstrDBcc('DBVS')
 Else If OpName = 'DBVC' Then InstrDBcc('DBVC')
 Else If OpName = 'DBHI' Then InstrDBcc('DBHI')
 Else If OpName = 'DBLS' Then InstrDBcc('DBLS')
 Else If OpName = 'DBGE' Then InstrDBcc('DBGE')
 Else If OpName = 'DBLT' Then InstrDBcc('DBLT')
 Else If OpName = 'DBGT' Then InstrDBcc('DBGT')
 Else If OpName = 'DBLE' Then InstrDBcc('DBLE')
 Else If OpName = 'ST'  Then InstrScc('ST')
 Else If OpName = 'SF'  Then InstrScc('SF')
 Else If OpName = 'SEQ' Then InstrScc('SEQ')
 Else If OpName = 'SNE' Then InstrScc('SNE')
 Else If OpName = 'SCC' Then InstrScc('SCC')
 Else If OpName = 'SCS' Then InstrScc('SCS')
 Else If OpName = 'SHI' Then InstrScc('SHI')
 Else If OpName = 'SLS' Then InstrScc('SLS')
 Else If OpName = 'SMI' Then InstrScc('SMI')
 Else If OpName = 'SPL' Then InstrScc('SPL')
 Else If OpName = 'SVS' Then InstrScc('SVS')
 Else If OpName = 'SVC' Then InstrScc('SVC')
 Else If OpName = 'SGE' Then InstrScc('SGE')
 Else If OpName = 'SLT' Then InstrScc('SLT')
 Else If OpName = 'SGT' Then InstrScc('SGT')
 Else If OpName = 'SLE' Then InstrScc('SLE')
 Else If OpName = 'JMP' Then InstrJMP
 Else If OpName = 'JSR' Then InstrJSR
 Else If OpName = 'RTS' Then InstrRTS
 Else If OpName = 'RTE' Then InstrRTE
 Else If OpName = 'RTR' Then InstrRTR
 Else If OpName = 'NOP' Then InstrNOP
 { --- Instructions BCD et operations speciales (TODO 16) --- }
 Else If OpName = 'ABCD' Then InstrABCD
 Else If OpName = 'SBCD' Then InstrSBCD
 Else If OpName = 'NBCD' Then InstrNBCD
 Else If OpName = 'CHK' Then InstrCHK(OpSize)
 Else If OpName = 'TRAP' Then InstrTRAP
 Else If OpName = 'TRAPV' Then InstrTRAPV
 Else If OpName = 'STOP' Then InstrSTOP
 Else If OpName = 'RESET' Then InstrRESET
 Else If OpName = 'ILLEGAL' Then InstrILLEGAL
 Else
 Begin
  Warning(cur_tok_line, cur_tok_col,
          'instruction non encore implementee: ' + OpName);
  SkipToEOL;
 End;
End;

{ ---------- ParseLine : traiter une ligne source ---------- }

Procedure ParseLine;
{ Traite une ligne source : etiquette optionnelle + directive/opcode.
  Appele en boucle par Run pour chaque ligne du source. }
Var
  LblName: String;
  DirName: String;
  DirSize: Integer;
Begin
 cur_label := '';
 LblName := '';

 { Verifier si fin de source }
 If end_source Then Exit;

 { Sauter les lignes vides }
 If cur_tok = TOK_EOL Then
 Begin
  NextToken;
  Exit;
 End;
 If cur_tok = TOK_EOF Then Exit;

 { --- Assemblage conditionnel (TODO 10) --- }
 { Quand on n'assemble pas, on doit quand meme suivre les IF/ENDC imbriqu }
 If Not CondAssembling Then
 Begin
  { Scanner la ligne pour trouver les directives conditionnelles }
  { Sauter l'etiquette eventuelle }
  If cur_tok = TOK_LABEL Then
   NextToken
  Else If cur_tok = TOK_IDENT Then
  Begin
   NextToken;
   If cur_tok = TOK_COLON Then
    NextToken;
  End;
  { Verifier si c'est une directive conditionnelle }
  If cur_tok = TOK_DIRECTIVE Then
  Begin
   DirName := UpCaseStr(cur_tok_str);
   NextToken;
   If (DirName = 'IFEQ') or (DirName = 'IFNE') or
      (DirName = 'IFGT') or (DirName = 'IFGE') or
      (DirName = 'IFLT') or (DirName = 'IFLE') or
      (DirName = 'IFDEF') or (DirName = 'IFNDEF') or
      (DirName = 'IFC') or (DirName = 'IFNC') or
      (DirName = 'IF') Then
   Begin
    { Empiler un faux niveau pour suivre l'imbrication }
    CondPush(False);
    SkipToEOL;
   End
   Else If DirName = 'ELSE' Then
   Begin
    DirELSE_;
   End
   Else If (DirName = 'ENDC') or (DirName = 'ENDIF') Then
   Begin
    DirENDC;
   End
   Else
    SkipToEOL;
  End
  Else
   SkipToEOL;
  If cur_tok = TOK_EOL Then NextToken;
  Exit;
 End;

 { --- Etiquette en debut de ligne --- }
 If cur_tok = TOK_LABEL Then
 Begin
  LblName := cur_tok_str;
  { Retirer le ':' final si present }
  If (Length(LblName) > 0) and (LblName[Length(LblName)] = ':') Then
   LblName := Copy(LblName, 1, Length(LblName) - 1);
  cur_label := LblName;
  NextToken;
  { Si c'est suivi d'un EOL, c'est juste une etiquette }
  If (cur_tok = TOK_EOL) or (cur_tok = TOK_EOF) Then
  Begin
   ProcessLabel(LblName);
   If cur_tok = TOK_EOL Then NextToken;
   Exit;
  End;
 End
 Else If cur_tok = TOK_IDENT Then
 Begin
  { Un identifiant en debut de ligne peut etre une etiquette
    si suivi de EQU, SET, ou ':' }
  LblName := cur_tok_str;
  { Regarder le token suivant pour determiner si c'est une etiquette }
  { On verifie d'abord si le suivant est EQU ou SET }
  NextToken;
  If cur_tok = TOK_COLON Then
  Begin
   { C'est une etiquette avec ':' }
   cur_label := LblName;
   NextToken; { consommer le ':' }
   If (cur_tok = TOK_EOL) or (cur_tok = TOK_EOF) Then
   Begin
    ProcessLabel(LblName);
    If cur_tok = TOK_EOL Then NextToken;
    Exit;
   End;
  End
  Else If (cur_tok = TOK_DIRECTIVE) and
          ((UpCaseStr(cur_tok_str) = 'EQU') or (UpCaseStr(cur_tok_str) = 'SET')) Then
  Begin
   { C'est label EQU/SET expr }
   cur_label := LblName;
   { On continue normalement, la directive va utiliser LblName }
  End
  Else
  Begin
   { Definition de macro : name MACRO [params] }
   If (cur_tok = TOK_DIRECTIVE) and
      (UpCaseStr(cur_tok_str) = 'MACRO') Then
   Begin
    NextToken; { consommer MACRO }
    DirMACRO(LblName);
    If cur_tok = TOK_EOL Then NextToken;
    Exit;
   End
   { Invocation de macro }
   Else If FindMacro(LblName) <> 0 Then
   Begin
    ExpandMacro(FindMacro(LblName));
    Exit;
   End
   Else
   Begin
    { Identifiant inconnu }
    Error(cur_tok_line, cur_tok_col,
          'instruction ou directive inconnue: ' + LblName);
    SkipToEOL;
    If cur_tok = TOK_EOL Then NextToken;
    Exit;
   End;
  End;
 End;

 { --- Directive ou opcode --- }
 If cur_tok = TOK_DIRECTIVE Then
 Begin
  DirName := UpCaseStr(cur_tok_str);
  DirSize := cur_tok_size;
  NextToken; { consommer la directive }

  { Definir l'etiquette si presente (sauf pour EQU/SET qui la gerent) }
  If (DirName <> 'EQU') and (DirName <> 'SET') Then
   ProcessLabel(LblName);

  If DirName = 'ORG' Then
   DirORG
  Else If DirName = 'EQU' Then
   DirEQU(LblName)
  Else If DirName = 'SET' Then
   DirSET(LblName)
  Else If DirName = 'DC' Then
   DirDC(DirSize)
  Else If DirName = 'DCB' Then
   DirDCB(DirSize)
  Else If DirName = 'DS' Then
   DirDS(DirSize)
  Else If DirName = 'EVEN' Then
   DirEVEN
  Else If DirName = 'CNOP' Then
   DirCNOP
  Else If DirName = 'END' Then
   DirEND
  Else If (DirName = 'LIST') Then
  Begin
   list_enabled := True;
   SkipToEOL;
  End
  Else If (DirName = 'NOLIST') Then
  Begin
   list_enabled := False;
   SkipToEOL;
  End
  Else If (DirName = 'TTL') Then
  Begin
   If cur_tok = TOK_STRING Then
   Begin
    list_title := cur_tok_str;
    NextToken;
   End;
   SkipToEOL;
  End
  Else If (DirName = 'SPC') or (DirName = 'PAGE') or
          (DirName = 'OPT') or (DirName = 'FAIL') or
          (DirName = 'ALIGN') Then
  Begin
   { Directives de listing/controle - ignorer les arguments }
   SkipToEOL;
  End
   { --- Directives avancees (TODO 09) --- }
   Else If DirName = 'SECTION' Then
    DirSECTION
   Else If DirName = 'INCLUDE' Then
    DirINCLUDE
   Else If (DirName = 'XDEF') or (DirName = 'ENTRY') or
           (DirName = 'PUBLIC') Then
    DirXDEF
   Else If (DirName = 'XREF') or (DirName = 'EXTERNAL') or
           (DirName = 'EXTERN') Then
    DirXREF
   Else If DirName = 'MACRO' Then
   Begin
    { MACRO sans nom en debut de ligne }
    Error(cur_tok_line, cur_tok_col, 'MACRO: nom de macro requis');
    SkipToEOL;
   End
   Else If DirName = 'REPT' Then
    DirREPT
   Else If DirName = 'ENDM' Then
   Begin
    Warning(cur_tok_line, cur_tok_col, 'ENDM sans MACRO correspondant');
    SkipToEOL;
   End
   Else If DirName = 'ENDR' Then
   Begin
    Warning(cur_tok_line, cur_tok_col, 'ENDR sans REPT correspondant');
    SkipToEOL;
   End
   Else If DirName = 'MEXIT' Then
   Begin
    If Not macro_expanding Then
     Warning(cur_tok_line, cur_tok_col, 'MEXIT en dehors d''une macro');
    SkipToEOL;
   End
   { --- Assemblage conditionnel (TODO 10) --- }
   Else If DirName = 'IFEQ' Then
    DirIFEQ
   Else If DirName = 'IFNE' Then
    DirIFNE
   Else If DirName = 'IFGT' Then
    DirIFGT
   Else If DirName = 'IFGE' Then
    DirIFGE
   Else If DirName = 'IFLT' Then
    DirIFLT
   Else If DirName = 'IFLE' Then
    DirIFLE
   Else If DirName = 'IFDEF' Then
    DirIFDEF
   Else If DirName = 'IFNDEF' Then
    DirIFNDEF
   Else If DirName = 'IFC' Then
    DirIFC
   Else If DirName = 'IFNC' Then
    DirIFNC
   Else If (DirName = 'IF') Then
   Begin
    { IF expr : assembler si expr <> 0 (alias de IFNE) }
    DirIFNE;
   End
   Else If DirName = 'ELSE' Then
    DirELSE_
   Else If (DirName = 'ENDC') or (DirName = 'ENDIF') Then
    DirENDC
   Else
   Begin
    { Directive non encore implementee }
    Warning(cur_tok_line, cur_tok_col,
            'directive non encore implementee: ' + DirName);
    SkipToEOL;
   End;
  End
 Else If cur_tok = TOK_OPCODE Then
 Begin
  { Instruction 68000 }
  DirName := UpCaseStr(cur_tok_str);
  DirSize := cur_tok_size;
  ProcessLabel(LblName);
  NextToken;
  AssembleInstruction(DirName, DirSize);
 End
 Else If (cur_tok <> TOK_EOL) and (cur_tok <> TOK_EOF) Then
 Begin
  { Token inattendu }
  ProcessLabel(LblName);
  Error(cur_tok_line, cur_tok_col,
        'instruction ou directive attendue, trouve: ' + cur_tok_str);
  SkipToEOL;
 End;

 { Mettre a jour expr_pc pour les expressions }
 expr_pc := GetPC;

 { Consommer le EOL }
 If cur_tok = TOK_EOL Then
  NextToken;
End;

{ ============================================================================ }
{ Analyse des options de ligne de commande                                     }
{ ============================================================================ }

Procedure ShowHelp;
Begin
 WriteLn('ASM68 - Clone de Motorola Macro Assembler (ASM68)');
 WriteLn('Assembleur pour la famille Motorola 68000');
 WriteLn;
 WriteLn('Syntaxe : asm68 fichier.asm [options]');
 WriteLn;
 WriteLn('Options :');
 WriteLn('  -o fichier    Nom du fichier objet genere (defaut: source.S68)');
 WriteLn('  -l fichier    Genere un fichier listing');
 WriteLn('  -d symbole    Definit un symbole pour l''assemblage conditionnel');
 WriteLn('  -i repertoire Ajoute un repertoire pour les fichiers INCLUDE');
 WriteLn('  -e            Affiche seulement les erreurs');
 WriteLn('  -w            Affiche les avertissements');
 WriteLn('  -s            Inclut la table des symboles dans le listing');
 WriteLn('  -n            Supprime la generation du fichier objet');
 WriteLn('  -x            Active l''expansion des macros dans le listing');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn('  asm68 hello.asm');
 WriteLn('  asm68 prog.asm -o prog.s68 -l prog.lst -s');
 WriteLn('  asm68 prog.asm -d DEBUG -i includes -e');
End;

Procedure ShowVersion;
Begin
 WriteLn('ASM68 version 0.1 - Assembleur Motorola 68000');
 WriteLn('Clone de Motorola Macro Assembler (ASM68)');
 WriteLn('(C) 2026 - Turbo Pascal / Free Pascal');
End;

Procedure ParseArgs;
Var
  I: Integer;
  Arg: String;
  ExtStart: Integer;
Begin
 { Initialiser les options par defaut }
 Opts.SrcFile       := '';
 Opts.ObjFile       := '';
 Opts.ListFile      := '';
 Opts.DefSymCount   := 0;
 Opts.IncPathCount  := 0;
 Opts.ErrorsOnly    := False;
 Opts.ShowWarnings  := False;
 Opts.IncludeSymTable := False;
 Opts.NoObject      := False;
 Opts.ExpandMacros  := False;

 I := 1;
 While I <= ParamCount do
 Begin
  Arg := ParamStr(I);
  If (Arg = '-o') or (Arg = '-O') Then
  Begin
   Inc(I);
   If I <= ParamCount Then
    Opts.ObjFile := ParamStr(I);
  End
  Else If (Arg = '-l') or (Arg = '-L') Then
  Begin
   Inc(I);
   If I <= ParamCount Then
    Opts.ListFile := ParamStr(I);
  End
  Else If (Arg = '-d') or (Arg = '-D') Then
  Begin
   Inc(I);
   If (I <= ParamCount) and (Opts.DefSymCount < MAX_DEF_SYMS) Then
   Begin
    Inc(Opts.DefSymCount);
    Opts.DefSymbols[Opts.DefSymCount] := UpCaseStr(ParamStr(I));
   End;
  End
  Else If (Arg = '-i') or (Arg = '-I') Then
  Begin
   Inc(I);
   If (I <= ParamCount) and (Opts.IncPathCount < MAX_INC_PATHS) Then
   Begin
    Inc(Opts.IncPathCount);
    Opts.IncludePaths[Opts.IncPathCount] := ParamStr(I);
   End;
  End
  Else If (Arg = '-e') or (Arg = '-E') Then
   Opts.ErrorsOnly := True
  Else If (Arg = '-w') or (Arg = '-W') Then
   Opts.ShowWarnings := True
  Else If (Arg = '-s') or (Arg = '-S') Then
   Opts.IncludeSymTable := True
  Else If (Arg = '-n') or (Arg = '-N') Then
   Opts.NoObject := True
  Else If (Arg = '-x') or (Arg = '-X') Then
   Opts.ExpandMacros := True
  Else If (Arg[1] <> '-') and (Opts.SrcFile = '') Then
   Opts.SrcFile := Arg
  Else
  Begin
   WriteLn('Option inconnue : ', Arg);
   Halt(2);
  End;
  Inc(I);
 End;

 { Generer le nom du fichier objet par defaut si non specifie }
 If (Opts.SrcFile <> '') and (Opts.ObjFile = '') Then
 Begin
  Opts.ObjFile := Opts.SrcFile;
  ExtStart := 0;
  For I := Length(Opts.ObjFile) DownTo 1 do
   If Opts.ObjFile[I] = '.' Then
   Begin ExtStart := I; Break; End;
  If ExtStart > 1 Then
   Opts.ObjFile := Copy(Opts.ObjFile, 1, ExtStart - 1) + '.S68'
  Else
   Opts.ObjFile := Opts.ObjFile + '.S68';
 End;
End;

{ ============================================================================ }
{ Procedure Run : programme principal d'assemblage                             }
{ ============================================================================ }

Procedure Run;
Var I: Integer;
Begin
 ParseArgs;

 If Opts.SrcFile = '' Then
 Begin
  ShowHelp;
  Halt(1);
 End;

 If Not FileExists(Opts.SrcFile) Then
 Begin
  FatalError('fichier source introuvable: ' + Opts.SrcFile);
 End;

 ErrorCount   := 0;
 WarningCount := 0;
 LineCount    := 0;
 CodeSize     := 0;
 expr_pc      := 0;
 expr_depth   := 0;
 pass_num     := 1;
 end_source   := False;
 start_address := 0;
 start_address_set := False;
 cur_label    := '';

 { Initialiser les macros et includes (TODO 09) }
 MacroCount := 0;
 macro_expanding := False;
 macro_narg := 0;
 macro_unique_id := 0;
 include_depth := 0;
 For I := 1 to MAX_MACRO do MacroTable[I] := nil;

 { Initialiser l'assemblage conditionnel (TODO 10) }
 cond_depth := 0;

 { Initialiser la table des symboles }
 InitSymTable;

 { Initialiser les sections (TODO 07) }
 InitSections;

 { Ouvrir le fichier listing si demande }
 ListOpen(Opts.ListFile);

 { Ouvrir le fichier source et lexer }
 SrcOpen(Opts.SrcFile);
 SrcGetLine;
 NextToken;

 { Boucle principale : traiter chaque ligne (TODO 08) }
 While (cur_tok <> TOK_EOF) and (Not end_source) do
 Begin
  ParseLine;
 End;

 { Verifier les blocs conditionnels non fermes (TODO 10) }
 If cond_depth > 0 Then
  Error(cur_tok_line, cur_tok_col,
        IntToStr(cond_depth) + ' bloc(s) IF non ferme(s) (ENDC/ENDIF manquant)');

 { Calculer la taille totale du code genere }
 CodeSize := 0;
 For I := 1 to SectionCount do
  CodeSize := CodeSize + Sections[I].Size;

 SrcClose;

 { Table des symboles dans le listing si demandee }
 ListSymbolTable;

 { Fermer le fichier listing }
 ListClose;

 { Afficher le bilan de compilation }
 BilanCompilation;

 { Liberer les macros (TODO 09) }
 FreeMacros;

 { Liberer les buffers des sections (TODO 07) }
 FreeSections;
End;

{ ============================================================================ }
{ Programme principal                                                          }
{ ============================================================================ }

BEGIN
 If (ParamStr(1) = '/?') or (ParamStr(1) = '--help') or
    (ParamStr(1) = '-h') or (ParamStr(1) = '/h') or
    (ParamStr(1) = '/H') Then
 Begin
  ShowHelp;
  Halt;
 End;
 If (ParamStr(1) = '--version') or (ParamStr(1) = '-v') Then
 Begin
  ShowVersion;
  Halt;
 End;
 Run;
END.
