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
{ TODO 06 - Modes d'adressage : analyse et encodage }
{ TODO 07 - Generateur de code : emission et sections }
{ TODO 08 - Directives assembleur de base (ORG, DC, DS, EQU, END) }
{ TODO 09 - Directives assembleur avancees (SECTION, INCLUDE, macros) }
{ TODO 10 - Assemblage conditionnel (IF, IFDEF, IFEQ, etc.) }
{ TODO 11 - Instructions de transfert de donnees }
{ TODO 12 - Instructions arithmetiques entieres }
{ TODO 13 - Instructions logiques et de manipulation de bits }
{ TODO 14 - Instructions de decalage et rotation }
{ TODO 15 - Instructions de branchement et controle de flux }
{ TODO 16 - Instructions BCD et operations speciales }
{ TODO 17 - Encodage binaire des instructions (passe 2) }
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
  MAX_LINE          = 1024;   { Longueur max d'une ligne source        }
  MAX_INCLUDE_DEPTH = 8;      { Profondeur max d'imbrication INCLUDE   }
  MAX_SECTIONS      = 16;     { Sections max                           }
  MAX_FIXUP         = 4096;   { Fixups max (references a resoudre)     }
  MAX_EXPR_DEPTH    = 32;     { Profondeur max d'expression            }
  MAX_DEF_SYMS      = 32;     { Symboles predefinis max (-d)           }
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
    (U = 'BVC') or (U = 'BVS') Then Begin IsOpcode := True; Exit; End;
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
    (U = 'TRAP') or (U = 'TRAPV') or (U = 'CHK') Then Begin IsOpcode := True; Exit; End;
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
    (U = 'MACRO') or (U = 'ENDM') Then Begin IsDirective := True; Exit; End;
 If (U = 'IF') or (U = 'IFDEF') or (U = 'IFNDEF') or
    (U = 'IFEQ') or (U = 'IFNE') or (U = 'IFGT') or
    (U = 'IFGE') or (U = 'IFLT') or (U = 'IFLE') or
    (U = 'ELSE') or (U = 'ENDC') or (U = 'ENDIF') Then Begin IsDirective := True; Exit; End;
 If (U = 'XDEF') or (U = 'XREF') or (U = 'PUBLIC') or
    (U = 'EXTERN') Then Begin IsDirective := True; Exit; End;
 If (U = 'OPT') or (U = 'LIST') or (U = 'NOLIST') or
    (U = 'PAGE') or (U = 'TTL') Then Begin IsDirective := True; Exit; End;
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
 WriteLn('Taille code    : ', CodeSize, ' octets');
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
 Idx := FindSym(UName);

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
{ Procedure Run : stub pour le programme principal                             }
{ ============================================================================ }

Procedure Run;
Var TokName: String;
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

 { Initialiser la table des symboles }
 InitSymTable;

 { Ouvrir le fichier listing si demande }
 ListOpen(Opts.ListFile);

 { Ouvrir le fichier source et lexer }
 SrcOpen(Opts.SrcFile);
 SrcGetLine;
 NextToken;

 While cur_tok <> TOK_EOF do
 Begin
  Case cur_tok of
   TOK_IDENT:     TokName := 'IDENT';
   TOK_INTEGER:   TokName := 'INTEGER';
   TOK_STRING:    TokName := 'STRING';
   TOK_CHAR:      TokName := 'CHAR';
   TOK_REGISTER:  TokName := 'REGISTER';
   TOK_OPCODE:    TokName := 'OPCODE';
   TOK_DIRECTIVE: TokName := 'DIRECTIVE';
   TOK_LABEL:     TokName := 'LABEL';
   TOK_COMMA:     TokName := 'COMMA';
   TOK_LPAREN:    TokName := 'LPAREN';
   TOK_RPAREN:    TokName := 'RPAREN';
   TOK_PLUS:      TokName := 'PLUS';
   TOK_MINUS:     TokName := 'MINUS';
   TOK_STAR:      TokName := 'STAR';
   TOK_SLASH:     TokName := 'SLASH';
   TOK_HASH:      TokName := 'HASH';
   TOK_DOT:       TokName := 'DOT';
   TOK_COLON:     TokName := 'COLON';
   TOK_EQUAL:     TokName := 'EQUAL';
   TOK_AMPERSAND: TokName := 'AMPERSAND';
   TOK_PIPE:      TokName := 'PIPE';
   TOK_CARET:     TokName := 'CARET';
   TOK_PERCENT:   TokName := 'PERCENT';
   TOK_TILDE:     TokName := 'TILDE';
   TOK_LSHIFT:    TokName := 'LSHIFT';
   TOK_RSHIFT:    TokName := 'RSHIFT';
   TOK_EOL:       TokName := 'EOL';
  Else
   TokName := 'UNKNOWN';
  End;
  If cur_tok = TOK_EOL Then
   WriteLn(PadRight(IntToStr(cur_tok_line), 5), ' ', PadRight(TokName, 12))
  Else If cur_tok = TOK_INTEGER Then
   WriteLn(PadRight(IntToStr(cur_tok_line), 5), ' ', PadRight(TokName, 12),
           ' ', cur_tok_str, ' = ', cur_tok_val)
  Else If cur_tok_size <> 0 Then
   WriteLn(PadRight(IntToStr(cur_tok_line), 5), ' ', PadRight(TokName, 12),
           ' ', cur_tok_str, ' (size=', cur_tok_size, ')')
  Else
   WriteLn(PadRight(IntToStr(cur_tok_line), 5), ' ', PadRight(TokName, 12),
           ' ', cur_tok_str);
  NextToken;
 End;

 SrcClose;

 { Table des symboles dans le listing si demandee }
 ListSymbolTable;

 { Fermer le fichier listing }
 ListClose;

 { Afficher le bilan de compilation }
 BilanCompilation;
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
