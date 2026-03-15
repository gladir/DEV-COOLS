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
{ TODO 02 - Lexeur : lecture source et tokenisation }
{ TODO 03 - Gestion des erreurs, avertissements et listing }
{ TODO 04 - Table des symboles : etiquettes, EQU, SET }
{ TODO 05 - Analyseur d'expressions arithmetiques }
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
Begin
 ParseArgs;

 If Opts.SrcFile = '' Then
 Begin
  ShowHelp;
  Halt(1);
 End;

 If Not FileExists(Opts.SrcFile) Then
 Begin
  WriteLn('Erreur fatale: fichier source introuvable: ', Opts.SrcFile);
  Halt(2);
 End;

 ErrorCount   := 0;
 WarningCount := 0;
 LineCount    := 0;
 CodeSize     := 0;

 { --- TODO 02..24 : assemblage complet ici --- }

 WriteLn('ASM68 - Assembleur Motorola 68000');
 WriteLn('Source : ', Opts.SrcFile);
 WriteLn('Objet  : ', Opts.ObjFile);
 If Opts.ListFile <> '' Then
  WriteLn('Listing: ', Opts.ListFile);
 If Opts.DefSymCount > 0 Then
  WriteLn('Symboles predefinis : ', Opts.DefSymCount);
 If Opts.IncPathCount > 0 Then
  WriteLn('Repertoires INCLUDE : ', Opts.IncPathCount);
 WriteLn;
 WriteLn('(TODO 02..24 non encore implementes)');
 WriteLn;
 WriteLn('Lignes lues   : ', LineCount);
 WriteLn('Taille code   : ', CodeSize, ' octets');
 WriteLn('Erreurs       : ', ErrorCount);
 WriteLn('Avertissements: ', WarningCount);
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
