{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Rust vers assembleur 8086
}

Program RUST86;

{$I-}   { Desactiver les IO-check pour gerer nous-memes les erreurs }

{ ============================================================
  INFRASTRUCTURE GENERALE
  ============================================================ }

{ --- Constantes de dimensionnement --- }
Const
  RUST86_VERSION = '1.0';
  RUST86_DATE    = '2026-03-04';

  MAX_SYM    = {$IFDEF FPC}2048{$ELSE}64{$ENDIF};   { entrees table des symboles             }
  MAX_PROC   = {$IFDEF FPC}256{$ELSE}64{$ENDIF};     { fonctions fn                           }
  MAX_IMPL   = {$IFDEF FPC}64{$ELSE}32{$ENDIF};    { blocs impl (impl Type / impl Trait for Type) }
  MAX_METHOD = {$IFDEF FPC}256{$ELSE}30{$ENDIF};   { methodes total dans tous les blocs impl      }
  MAX_BORROW   = {$IFDEF FPC}128{$ELSE}32{$ENDIF};  { verrous d'emprunt actifs simultanement max }
  MAX_LIFETIME = {$IFDEF FPC}64{$ELSE}16{$ENDIF};   { annotations de duree de vie actives max   }
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};  { profondeur max de boucles imbriquees      }
  MAX_DATA   = {$IFDEF FPC}256{$ELSE}32{$ENDIF};    { entrees maxi dans le segment de donnees }
  MAX_PARAM  = {$IFDEF FPC}32{$ELSE}8{$ENDIF};      { parametres par fonction                }
  MAX_FIELD  = {$IFDEF FPC}64{$ELSE}32{$ENDIF};    { champs par struct/enum                     }
  MAX_FIELDS_TOTAL = {$IFDEF FPC}512{$ELSE}64{$ENDIF}; { bassin global de champs pour tous les types }
  MAX_CONST  = 512;   { constantes (const / static immuable)       }
  MAX_TYPE   = 64;    { descripteurs de type                       }
  MAX_LABEL  = 2048;  { labels internes (if/loop/match/break...)   }
  MAX_SCOPE  = 64;    { profondeur maximale de portee              }
  MAX_ERRORS = 30;    { arret apres N erreurs                      }
  MAX_STR    = {$IFDEF FPC}255{$ELSE}80{$ENDIF};    { longueur maximale d'une TString        }
  MAX_IMPORT = 32;    { fichiers mod / use inclus                  }
  MAX_SWITCH = 256;   { branches par match                         }
  MAX_MANGLE = 128;   { longueur maximale d'un nom mangle          }
  STACK_SIZE = 1024;  { taille segment pile en octets              }

  { Prefixes des etiquettes assembleur 8086 }
  RS_VAR_PFX  = '_RSV_';   { variables statiques / statics (.DATA)    }
  RS_FN_PFX   = '_RSF_';   { fonctions Rust                            }
  RS_IMPL_PFX = '_IMP_';   { methodes impl Type::fn                    }
  RS_LABEL_PFX= '_RSL_';   { etiquettes de controle (if/loop/match)   }
  RS_STR_PFX  = '_RSK_';   { constantes de chaines litterales          }
  RS_RT_PFX   = '_RSRT_';  { routines runtime (panic, print, memcpy)   }
  RS_MOD_PFX  = '_MOD_';   { fonctions definies dans les modules Rust   }

  { Codes de sortie du programme }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { ============================================================
    Indices des types primitifs dans TypeTab
    Ces constantes garantissent un acces direct O(1) aux types
    de base sans recherche par nom.
    ============================================================ }
  TY_IDX_I8    = 0;   { i8   : entier signe  8 bits (1 octet)        }
  TY_IDX_U8    = 1;   { u8   : entier non-signe 8 bits (1 octet)     }
  TY_IDX_I16   = 2;   { i16  : entier signe 16 bits (2 octets)       }
  TY_IDX_U16   = 3;   { u16  : entier non-signe 16 bits (2 octets)   }
  TY_IDX_I32   = 4;   { i32  : entier signe 32 bits (4 octets DX:AX) }
  TY_IDX_U32   = 5;   { u32  : entier non-signe 32 bits (4 octets)   }
  TY_IDX_ISIZE = 6;   { isize: ptr-signe 16 bits sur 8086            }
  TY_IDX_USIZE = 7;   { usize: ptr non-signe 16 bits sur 8086        }
  TY_IDX_BOOL  = 8;   { bool : 0=false 1=true (1 octet)              }
  TY_IDX_CHAR  = 9;   { char : Unicode tronque a u8 sur 8086         }
  TY_IDX_UNIT  = 10;  { ()   : type unite, taille 0                  }
  TY_IDX_STR   = 11;  { &str : pointeur fat (ptr+len) 4 octets       }
  TY_PRIM_COUNT= 12;  { nombre de types primitifs pre-enregistres    }
  TY_UNKNOWN   = -1;  { type non resolu / erreur                     }

{ --- Types fondamentaux --- }
Type
  TString = String[MAX_STR];

  { ---- Categories de tokens ---- }
  TTokenKind = (
    TK_IDENT,     { identificateur                                }
    TK_KEYWORD,   { mot-cle Rust reserve                          }
    TK_INTEGER,   { litteral entier : 42  0xFF  0b1010  0o17      }
    TK_FLOAT,     { litteral flottant : 3.14  1e10                }
    TK_CHAR,      { litteral caractere : 'A'  '\n'                }
    TK_STRING,    { litteral chaine : "hello"  r#"raw"#           }
    TK_BYTE,      { byte literal : b'A'                           }
    TK_OP,        { operateur simple ou compose (+ += -> :: ...)   }
    TK_PUNCT,     { ponctuation : ; , . ( ) [ ] < > @ # _ $      }
    TK_LIFETIME,  { lifetime annotation : 'a  'static             }
    TK_EOF        { fin de fichier source                          }
  );

  { ---- Enregistrement d'un token ---- }
  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;       { representation brute du token      }
    IntVal   : LongInt;       { si TK_INTEGER ou TK_CHAR (codepoint) }
    FloatVal : Real;          { si TK_FLOAT                        }
    Line     : Integer;       { ligne dans le source (1-base)      }
    Col      : Integer;       { colonne dans le source (1-base)    }
  End;

  { ---- Options de la ligne de commande ---- }
  TOptions = Record
    SrcFile    : TString;     { fichier source .rs                 }
    OutFile    : TString;     { fichier sortie .asm (defaut: src.asm) }
    Verbose    : Boolean;     { -v : messages detailles            }
    DebugTok   : Boolean;     { -d : afficher chaque token         }
    Edition    : Integer;     { --edition : 2015/2018/2021 (defaut 2021) }
    NoOptim    : Boolean;     { --no-opt : desactiver optimisations }
  End;

  { ---- Categorie d'un symbole ---- }
  TSymCat = (
    SC_VAR,      { variable locale (sur la pile)            }
    SC_PARAM,    { parametre de fonction                     }
    SC_FN,       { fonction / methode                        }
    SC_CONST,    { constante (const)                         }
    SC_STATIC,   { variable statique (static)                }
    SC_TYPEDEF,  { alias de type (type Foo = ...)            }
    SC_FIELD,    { champ de struct / enum                    }
    SC_IMPL      { methode via impl (mungling _IMP_T_fn)     }
  );

  { ---- Enregistrement de la table des symboles ---- }
  TSymRec = Record
    Name     : TString;       { nom Rust du symbole                }
    Cat      : TSymCat;       { categorie                          }
    TypeIdx  : Integer;       { index dans la table de types }
    ScopeLevel : Integer;     { niveau de portee (0 = global)      }
    Offset   : Integer;       { offset BP pour locals/params (negatif pour locals) }
    MangledName : TString;    { etiquette assembleur 8086          }
    IsMut    : Boolean;       { variable mutable                   }
    IsRef    : Boolean;       { symbole est une reference &T       }
    DeclLine : Integer;       { ligne de declaration dans le source }
  End;

  { ============================================================
    Categorie d'un descripteur de type
    ============================================================ }
  TTypeKind = (
    TKD_PRIM,    { type scalaire primitif (i8..u32, bool, char, ()) }
    TKD_REF,     { reference &T ou &mut T                          }
    TKD_PTR,     { pointeur brut *const T ou *mut T     }
    TKD_ARRAY,   { tableau de taille fixe [T; N]                   }
    TKD_TUPLE,   { tuple (T1, T2, ...)                             }
    TKD_STRUCT,  { struct avec champs nommes                      }
    TKD_ENUM,    { enum avec variantes et donnees                  }
    TKD_FN,      { pointeur de fonction fn(T1) -> T2               }
    TKD_UNKNOWN  { type non encore resolu                          }
  );

  { ============================================================
    Descripteur d'un bloc impl
    ============================================================ }
  TImplRec = Record
    TypeName   : TString;   { nom du type recepteur (ex: 'Point')     }
    TraitName  : TString;   { nom du trait implante (vide si impl libre) }
    MethodBase : Integer;   { premier index dans MethodTab             }
    MethodCount: Integer;   { nombre de methodes de ce bloc            }
    TypeIdx    : Integer;   { index dans TypeTab (-1 si non resolu)    }
  End;

  { ---- Descripteur d'une methode impl ---- }
  TMethodRec = Record
    Name       : TString;   { nom Rust de la methode (ex: 'push')     }
    MangledName: TString;   { etiquette 8086 (ex: '_IMP_Point_push')  }
    RetTypeIdx : Integer;   { index du type de retour dans TypeTab     }
    IsPublic   : Boolean;   { methode pub ou privee                    }
    ImplIdx    : Integer;   { index du bloc impl parent dans ImplTab   }
  End;

  { ============================================================
    Emprunts : &T (partage) et &mut T (mutable)
    ============================================================ }
  TBorrowKind = (BK_SHARED, BK_MUT);  { partage ou mutable }

  TBorrowRec = Record
    VarName  : TString;      { nom de la variable empruntee            }
    Kind     : TBorrowKind;  { BK_SHARED = &T  ou  BK_MUT = &mut T    }
    TypeIdx  : Integer;      { index du type pointe dans TypeTab       }
    IsActive : Boolean;      { emprunt encore actif dans la portee     }
    DeclLine : Integer;      { numero de ligne de la declaration       }
  End;

  { ============================================================
    Durees de vie : lifetime elision uniquement
    ============================================================ }
  TLifetimeRec = Record
    Name      : TString;   { etiquette Rust : 'a, 'b, 'static ...      }
    ScopeLevel: Integer;   { niveau de portee de la declaration         }
    DeclLine  : Integer;   { ligne source de la declaration             }
    IsElided  : Boolean;   { vrai si inferee par l'elision standard     }
    IsComplex : Boolean;   { vrai si annotation complexe non verifiee   }
  End;

  { ============================================================
    Valeur d'une expression et son emplacement 8086
    ============================================================ }
  TExprKind = (
    EK_NONE,   { valeur invalide / expression vide              }
    EK_IMM,    { immediat : constante entiere                   }
    EK_AX,     { valeur 16 bits dans le registre AX             }
    EK_DXAX,   { valeur 32 bits dans DX:AX                     }
    EK_MEM     { memoire : [BP + Offset]                        }
  );

  TExprVal = Record
    Kind    : TExprKind;  { ou est la valeur                    }
    ImmVal  : LongInt;    { valeur si EK_IMM                    }
    TypeIdx : Integer;    { type de l'expression dans TypeTab   }
    Offset  : Integer;    { offset BP si EK_MEM                 }
  End;

  { ---- Enregistrement d'un type (table de types TypeTab) ---- }
  TTypeRec = Record
    Kind      : TTypeKind; { categorie du type                     }
    Name      : TString;   { nom Rust canonique (ex: 'i32', 'bool')}
    Size      : Integer;   { taille en octets sur 8086             }
    Align     : Integer;   { alignement requis en octets           }
    Signed    : Boolean;   { vrai si type entier signe             }
    ElemType  : Integer;   { index type element (ref,array,fn ret) }
    ElemCount : Integer;   { nb elements (taille tableau) ou params}
    FieldBase : Integer;   { premier champ dans FieldTab (struct)  }
    FieldCount: Integer;   { nombre de champs (struct/tuple/enum)  }
  End;

  { ============================================================
    Descripteur d'un element/champ d'un type compose
              Utilise pour les tuples, tableaux, structs, enums.
    ============================================================ }
  TFieldRec = Record
    Name    : TString;   { nom du champ (vide pour tuples/arrays)  }
    TypeIdx : Integer;   { index du type de cet element            }
    Offset  : Integer;   { offset en octets depuis le debut du type}
  End;

  { ---- Tableau de types elements pour TypeAddTuple ---- }
  TTupleElems = Array[0..MAX_PARAM - 1] Of Integer;

{ --- Variables globales du compilateur --- }
Var
  Opts       : TOptions;
  ErrorCount : Integer;      { nombre d'erreurs rencontrees        }
  WarnCount  : Integer;      { nombre d'avertissements             }
  TotalLines : LongInt;      { lignes sources analysees            }
  TotalSyms  : Integer;      { symboles enregistres                }
  GExprDummy : TExprVal;     { TP7 : recoit les TExprVal ignores   }

{ --- Variables globales du lexer --- }
Var
  LexSrcF   : Text;          { fichier source ouvert              }
  LexLine   : String;        { ligne courante                     }
  LexLineNo : Integer;       { numero de ligne (1-base)           }
  LexColNo  : Integer;       { colonne courante dans LexLine      }
  LexEOF    : Boolean;       { vrai si fin de fichier atteinte    }
  LexOpened : Boolean;       { vrai si LexSrcF est ouvert         }
  CurToken  : TToken;        { token courant                      }

{ --- Variables globales de la table des symboles --- }
Var
  SymTab     : Array[0..MAX_SYM - 1]   Of TSymRec;  { table des symboles  }
  SymCount   : Integer;                              { nb symboles inseres }
  ScopeStack : Array[0..MAX_SCOPE - 1] Of Integer;  { debut de chaque portee dans SymTab }
  ScopeTop   : Integer;                              { index sommet de pile de portees    }
  CurScope   : Integer;                              { niveau de portee courant (0=global)}
  LabelSeq   : Integer;                              { compteur global de labels uniques  }

{ --- Variables globales du systeme de types --- }
Var
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;  { descripteurs de types           }
  TypeCount : Integer;                              { nb de types enregistres          }

{ --- Variables globales des champs de types composes --- }
Var
  FieldTab   : Array[0..MAX_FIELDS_TOTAL - 1] Of TFieldRec; { pool de champs/elements }
  FieldCount : Integer;                                      { nb entrees utilisees    }

{ --- Variables globales des blocs impl --- }
Var
  ImplTab    : Array[0..MAX_IMPL   - 1] Of TImplRec;    { blocs impl enregistres  }
  ImplCount  : Integer;                                  { nb de blocs impl        }
  MethodTab  : Array[0..MAX_METHOD - 1] Of TMethodRec;  { methodes de tous les impl }
  MethodCount: Integer;                                  { nb de methodes total    }

{ --- Variables globales des emprunts --- }
Var
  BorrowTab  : Array[0..MAX_BORROW - 1] Of TBorrowRec;  { table des emprunts actifs }
  BorrowCount: Integer;                                  { nb d'emprunts enregistres }

{ --- Variables globales des durees de vie --- }
Var
  LifetimeTab  : Array[0..MAX_LIFETIME - 1] Of TLifetimeRec; { annotations actives  }
  LifetimeCount: Integer;                                     { nb d'annotations      }

{ --- Variables globales d'emission de code --- }
Var
  OutF       : Text;     { fichier de sortie ASM                    }
  OutFOpen   : Boolean;  { vrai si OutF est ouvert en ecriture      }
  CurFrameSize : Integer;  { taille de pile locale (octets) }
  LoopTop      : Integer;  { niveau de boucle courant (0 = hors boucle) }
  LoopBreakLbl : Array[0..MAX_LOOP_NEST-1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST-1] Of TString;

{ --- Variables globales du segment de donnees --- }
Type
  TDataKind = (DK_WORD, DK_BYTE, DK_STR);  { entier 16b, octet, chaine }
  TDataRec  = Record
    LblName  : TString;        { etiquette assembleur (ex: _RSV_CNT) }
    Kind     : TDataKind;      { type de donnee                      }
    IntVal   : LongInt;        { valeur entiere pour DK_WORD/DK_BYTE }
    StrVal   : TString;        { valeur chaine pour DK_STR           }
    TypeIdx  : Integer;        { indice TypeTab                      }
  End;
Var
  DataTab    : Array[0..MAX_DATA-1] Of TDataRec;
  DataCount  : Integer;  { nb d'entrees dans DataTab }

{ --- Variables globales de modules --- }
Var
  CurModPath    : TString;   { chemin de module courant ex: 'foo::bar' (vide = racine) }
  ModDepth      : Integer;   { profondeur d'imbrication de mod BLOC }
  InUnsafeDepth : Integer;   { profondeur de bloc unsafe courant }
  RuntimeEmitted: Boolean;   { routines runtime deja emises dans OutF }

{ ============================================================
  Procedure : Erreur fatale
  ============================================================ }
Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('RUST86: Erreur fatale: ', Msg);
  Halt(EXIT_ERROR);
End;

{ ============================================================
  Procedure : Afficher aide et quitter
  ============================================================ }
Procedure ShowHelp;
Begin
  WriteLn('RUST86 v', RUST86_VERSION, ' (', RUST86_DATE, ')');
  WriteLn('Cette commande permet de lancer le compilateur Rust vers assembleur 8086');
  WriteLn;
  WriteLn('Syntaxe: RUST86 <source.rs> [<sortie.asm>] [options]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  -v              Mode verbeux (messages detailles)');
  WriteLn('  -d              Debug tokens (affiche chaque token analyse)');
  WriteLn('  --edition N     Edition Rust cible : 2015, 2018 ou 2021 (defaut: 2021)');
  WriteLn('  --no-opt        Desactiver les optimisations peephole');
  WriteLn('  -h, --help      Afficher cette aide');
  WriteLn;
  WriteLn('Exemples:');
  WriteLn('  RUST86 hello.rs');
  WriteLn('  RUST86 hello.rs hello.asm -v');
  WriteLn('  RUST86 main.rs main.asm --edition 2018');
  Halt(EXIT_OK);
End;

{ ============================================================
  Procedure : Initialiser les options par defaut
  ============================================================ }
Procedure InitOptions;
Begin
  Opts.SrcFile  := '';
  Opts.OutFile  := '';
  Opts.Verbose  := False;
  Opts.DebugTok := False;
  Opts.Edition  := 2021;
  Opts.NoOptim  := False;
End;

{ ============================================================
  Procedure : Construire le nom de sortie par defaut
             Remplace l'extension .rs par .asm
  ============================================================ }
Procedure BuildOutName;
Var
  I   : Integer;
  Base: TString;
Begin
  Base := Opts.SrcFile;
  { Chercher le dernier point dans le nom }
  I := Length(Base);
  While (I > 0) And (Base[I] <> '.') Do Dec(I);
  If I > 1 Then
    Opts.OutFile := Copy(Base, 1, I - 1) + '.asm'
  Else
    Opts.OutFile := Base + '.asm';
End;

{ ============================================================
  Procedure : Analyser les arguments de la ligne de commande
  ============================================================ }
Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
Begin
  If ParamCount = 0 Then ShowHelp;
  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If (Arg = '-h') Or (Arg = '--help') Then
      ShowHelp
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugTok := True
    Else If Arg = '--no-opt' Then
      Opts.NoOptim := True
    Else If Arg = '--edition' Then
    Begin
      Inc(I);
      If I > ParamCount Then FatalError('--edition attend un argument (2015/2018/2021)');
      Arg := ParamStr(I);
      If Arg = '2015' Then Opts.Edition := 2015
      Else If Arg = '2018' Then Opts.Edition := 2018
      Else If Arg = '2021' Then Opts.Edition := 2021
      Else FatalError('Edition inconnue: ' + Arg + ' (valeurs: 2015 2018 2021)');
    End
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
      FatalError('Option inconnue: ' + Arg)
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
      FatalError('Argument inattendu: ' + Arg);
    Inc(I);
  End;
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('RUST86: Erreur - aucun fichier source specifie.');
    WriteLn('Utilisez RUST86 --help pour l''aide.');
    Halt(EXIT_USAGE);
  End;
  If Opts.OutFile = '' Then BuildOutName;
End;

{ ============================================================
  Procedure : Afficher le banneau de demarrage
  ============================================================ }
Procedure ShowBanner;
Begin
  If Opts.Verbose Then
  Begin
    WriteLn('RUST86 v', RUST86_VERSION, ' - Compilateur Rust -> 8086');
    WriteLn('Source  : ', Opts.SrcFile);
    WriteLn('Sortie  : ', Opts.OutFile);
    WriteLn('Edition : ', Opts.Edition);
    WriteLn;
  End;
End;

{ ============================================================
  Procedure : Afficher les statistiques de compilation
  ============================================================ }
Procedure ShowStats;
Begin
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('Lignes analysees : ', TotalLines);
  WriteLn('Symboles         : ', TotalSyms);
  WriteLn('Erreurs          : ', ErrorCount);
  WriteLn('Avertissements   : ', WarnCount);
  If ErrorCount = 0 Then
    WriteLn('Compilation reussie -> ', Opts.OutFile)
  Else
    WriteLn('Compilation echouee (', ErrorCount, ' erreur(s))');
End;

{ ============================================================
  LEXER : TOKENS DE BASE
  ============================================================ }

{ ============================================================
  Fonction : LexCurChar - caractere a la position courante
  ============================================================ }
Function LexCurChar : Char;
Begin
  If (LexColNo >= 1) And (LexColNo <= Length(LexLine)) Then
    LexCurChar := LexLine[LexColNo]
  Else
    LexCurChar := #0;
End;

{ ============================================================
  Procedure : LexAdvance - avancer d'un caractere
  ============================================================ }
Procedure LexAdvance;
Begin
  Inc(LexColNo);
End;

{ ============================================================
  Fonction : LexPeek - regarder le caractere suivant sans avancer
  ============================================================ }
Function LexPeek : Char;
Begin
  If LexColNo + 1 <= Length(LexLine) Then
    LexPeek := LexLine[LexColNo + 1]
  Else
    LexPeek := #0;
End;

{ ============================================================
  Procedure : LexNextLine - lire la prochaine ligne du fichier
  ============================================================ }
Procedure LexNextLine;
Begin
  If EOF(LexSrcF) Then
  Begin
    LexEOF  := True;
    LexLine := '';
    LexColNo := 1;
  End Else
  Begin
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

{ ============================================================
  Procedure : LexError - erreur lexicale (non fatale)
  ============================================================ }
Procedure LexError(Const Msg : TString);
Begin
  WriteLn('RUST86:', LexLineNo, ':', LexColNo, ': Erreur: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('Trop d''erreurs - compilation abandonnee');
End;

{ ============================================================
  Procedure : MakeToken - initialiser un TToken
  ============================================================ }
Procedure MakeToken(Var T : TToken; K : TTokenKind;
                    Const V : TString; L, C : Integer);
Begin
  T.Kind     := K;
  T.Val      := V;
  T.IntVal   := 0;
  T.FloatVal := 0.0;
  T.Line     := L;
  T.Col      := C;
End;

{ ============================================================
  Procedure : LexSkipLineComment - ignorer commentaire // ...
  ============================================================ }
Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ ============================================================
  Procedure : LexSkipBlockComment - ignorer commentaire /* ... */
             Rust supporte les commentaires blocs imbriques.
  ============================================================ }
Procedure LexSkipBlockComment;
Var
  Depth : Integer;
  C     : Char;
Begin
  Depth := 1;
  While (Not LexEOF) And (Depth > 0) Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
      Continue;
    End;
    C := LexCurChar;
    LexAdvance;
    If C = '/' Then
    Begin
      If LexCurChar = '*' Then
      Begin
        LexAdvance;
        Inc(Depth);
      End;
    End Else If C = '*' Then
    Begin
      If LexCurChar = '/' Then
      Begin
        LexAdvance;
        Dec(Depth);
      End;
    End;
  End;
  If Depth > 0 Then
    LexError('Commentaire bloc non ferme en fin de fichier');
End;

{ ============================================================
  Procedure : LexSkipWS - ignorer espaces et commentaires
  ============================================================ }
Procedure LexSkipWS;
Var
  C : Char;
Begin
  Repeat
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;
    If LexEOF Then Exit;
    C := LexCurChar;
    If (C = ' ') Or (C = #9) Or (C = #13) Or (C = #10) Then
      LexAdvance
    Else If (C = '/') And (LexPeek = '/') Then
      LexSkipLineComment
    Else If (C = '/') And (LexPeek = '*') Then
    Begin
      LexAdvance;  { consommer '/' }
      LexAdvance;  { consommer '*' }
      LexSkipBlockComment;
    End Else
      Exit;
  Until False;
End;

{ ============================================================
  Fonctions utilitaires sur les caracteres
  ============================================================ }
Function IsAlpha(C : Char) : Boolean;
Begin
  IsAlpha := ((C >= 'a') And (C <= 'z')) Or
             ((C >= 'A') And (C <= 'Z')) Or
             (C = '_');
End;

Function IsDigit(C : Char) : Boolean;
Begin
  IsDigit := (C >= '0') And (C <= '9');
End;

Function IsAlNum(C : Char) : Boolean;
Begin
  IsAlNum := IsAlpha(C) Or IsDigit(C);
End;

Function IsHexDigit(C : Char) : Boolean;
Begin
  IsHexDigit := IsDigit(C) Or
                ((C >= 'a') And (C <= 'f')) Or
                ((C >= 'A') And (C <= 'F'));
End;

Function HexVal(C : Char) : Integer;
Begin
  If   (C >= '0') And (C <= '9') Then HexVal := Ord(C) - Ord('0')
  Else If (C >= 'a') And (C <= 'f') Then HexVal := Ord(C) - Ord('a') + 10
  Else HexVal := Ord(C) - Ord('A') + 10;
End;

{ ============================================================
  LEXER : OPERATEURS ET MOTS-CLES RUST
  ============================================================ }

{ --- Table des mots-cles Rust (44 entrees : 0..43) --- }
Const
  RUST_KW : Array[0..43] Of String[10] = (
    'fn',       'let',      'mut',      'if',       'else',
    'match',    'loop',     'while',    'for',      'in',
    'return',   'struct',   'enum',     'impl',     'trait',
    'use',      'mod',      'pub',      'self',     'Self',
    'super',    'crate',    'const',    'static',   'type',
    'where',    'unsafe',   'extern',   'as',       'ref',
    'break',    'continue', 'dyn',      'move',     'async',
    'await',    'true',     'false',    'box',      'do',
    'macro',    'try',      'yield',    'abstract'
  );

{ ============================================================
  Fonction : IsRustKeyword - verifier si une chaine est un mot-cle
  ============================================================ }
Function IsRustKeyword(Const S : TString) : Boolean;
Var
  I : Integer;
Begin
  IsRustKeyword := False;
  For I := 0 To 43 Do
    If S = RUST_KW[I] Then
    Begin
      IsRustKeyword := True;
      Exit;
    End;
End;

{ ============================================================
  Procedure : LexScanIdent - lire un identifiant ou mot-cle
  ============================================================ }
Procedure LexScanIdent(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  S := '';
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
        IsAlNum(LexCurChar) Do
  Begin
    If Length(S) < MAX_STR Then S := S + LexCurChar;
    LexAdvance;
  End;
  If IsRustKeyword(S) Then
    MakeToken(T, TK_KEYWORD, S, SL, SC)
  Else
    MakeToken(T, TK_IDENT, S, SL, SC);
End;

{ ============================================================
  Procedure : LexScanNumber - lire un litteral entier
             Bases supportees : decimal, 0x hex, 0b binaire, 0o octal
             Les underscores de lisibilite sont ignores.
             Le suffixe de type (u8, i32, usize...) est stocke
             dans Val mais non interprete.
  ============================================================ }
Procedure LexScanNumber(Var T : TToken; SL, SC : Integer);
Var
  S     : TString;
  Val   : LongInt;
  Base  : Integer;
  C     : Char;
  Fv    : Real;     { partie flottante                      }
  Div10 : Real;     { diviseur de position decimale         }
Begin
  S    := '';
  Val  := 0;
  Base := 10;
  C    := LexCurChar;

  { Detecter le prefixe de base }
  If (C = '0') And (LexPeek <> #0) Then
  Begin
    Case LexPeek Of
      'x','X': Begin
        S := '0x'; LexAdvance; LexAdvance;
        Base := 16;
      End;
      'b','B': Begin
        S := '0b'; LexAdvance; LexAdvance;
        Base := 2;
      End;
      'o','O': Begin
        S := '0o'; LexAdvance; LexAdvance;
        Base := 8;
      End;
    Else
      Val := 0; S := '0'; LexAdvance;
    End;
  End Else
  Begin
    Val := Ord(C) - Ord('0');
    S   := C;
    LexAdvance;
  End;

  { Lire les chiffres selon la base, underscores ignores }
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) Do
  Begin
    C := LexCurChar;
    If C = '_' Then Begin LexAdvance; Continue; End;
    Case Base Of
      2  : If (C = '0') Or (C = '1') Then
           Begin
             Val := Val * 2 + (Ord(C) - Ord('0'));
             If Length(S) < MAX_STR Then S := S + C;
             LexAdvance;
           End Else Break;
      8  : If (C >= '0') And (C <= '7') Then
           Begin
             Val := Val * 8 + (Ord(C) - Ord('0'));
             If Length(S) < MAX_STR Then S := S + C;
             LexAdvance;
           End Else Break;
      10 : If IsDigit(C) Then
           Begin
             Val := Val * 10 + (Ord(C) - Ord('0'));
             If Length(S) < MAX_STR Then S := S + C;
             LexAdvance;
           End Else Break;
      16 : If IsHexDigit(C) Then
           Begin
             Val := Val * 16 + HexVal(C);
             If Length(S) < MAX_STR Then S := S + C;
             LexAdvance;
           End Else Break;
    End;
  End;

  { Suffixe de type optionnel : u8 i8 u16 i16 u32 i32 usize isize }
  If (Not LexEOF) And (LexColNo <= Length(LexLine)) Then
  Begin
    C := LexCurChar;
    If (C = 'u') Or (C = 'i') Then
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
            IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
  End;

  { ---- Detection flottant (base decimale uniquement) ---- }
  If (Base = 10) And (Not LexEOF) And (LexColNo <= Length(LexLine)) And
     (LexCurChar = '.') And (LexPeek <> '.') And IsDigit(LexPeek) Then
  Begin
    Fv    := Val * 1.0;
    Div10 := 10.0;
    If Length(S) < MAX_STR Then S := S + '.';
    LexAdvance;
    While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
          (IsDigit(LexCurChar) Or (LexCurChar = '_')) Do
    Begin
      If LexCurChar <> '_' Then
      Begin
        Fv    := Fv + (Ord(LexCurChar) - Ord('0')) / Div10;
        Div10 := Div10 * 10.0;
        If Length(S) < MAX_STR Then S := S + LexCurChar;
      End;
      LexAdvance;
    End;
    { Exposant optionnel e/E }
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) And
       ((LexCurChar = 'e') Or (LexCurChar = 'E')) Then
    Begin
      If Length(S) < MAX_STR Then S := S + LexCurChar;
      LexAdvance;
      If (LexColNo <= Length(LexLine)) And
         ((LexCurChar = '+') Or (LexCurChar = '-')) Then
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
            IsDigit(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End;
    { Suffixe f32 / f64 }
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) And
       (LexCurChar = 'f') Then
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
            IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    MakeToken(T, TK_FLOAT, S, SL, SC);
    T.FloatVal := Fv;
    Exit;
  End;
  MakeToken(T, TK_INTEGER, S, SL, SC);
  T.IntVal := Val;
End;

{ ============================================================
  LEXER : LITTERAUX CHAINES ET CARACTERES
  ============================================================ }

{ ============================================================
  Fonction : LexScanEscape - decoder une sequence d'echappement
             Appelee apres consommation du backslash.
             Retourne le caractere; IntOut = valeur numerique.
  ============================================================ }
Function LexScanEscape(Var IntOut : LongInt) : Char;
Var
  C    : Char;
  Code : LongInt;
  I    : Integer;
Begin
  IntOut := 0;
  Code   := 0;
  If LexColNo > Length(LexLine) Then
  Begin
    LexError('Sequence d''echappement incomplete');
    LexScanEscape := '?';
    Exit;
  End;
  C := LexCurChar;
  LexAdvance;
  Case C Of
    'n'  : Begin LexScanEscape := #10;  IntOut := 10; End;
    't'  : Begin LexScanEscape := #9;   IntOut := 9;  End;
    'r'  : Begin LexScanEscape := #13;  IntOut := 13; End;
    '0'  : Begin LexScanEscape := #0;   IntOut := 0;  End;
    #34  : Begin LexScanEscape := #34;  IntOut := 34; End;
    '''' : Begin LexScanEscape := ''''; IntOut := 39; End;
    #92  : Begin LexScanEscape := #92;  IntOut := 92; End;
    'x'  : Begin
             { \xNN - deux chiffres hexadecimaux 00..FF }
             Code := 0;
             For I := 1 To 2 Do
             Begin
               If (LexColNo > Length(LexLine)) Or
                  (Not IsHexDigit(LexCurChar)) Then
               Begin
                 LexError('x: 2 chiffres hexa attendus');
                 Break;
               End;
               Code := Code * 16 + HexVal(LexCurChar);
               LexAdvance;
             End;
             IntOut := Code;
             LexScanEscape := Chr(Code And $FF);
           End;
    'u'  : Begin
             { sequence u Unicode, tronque a 8 bits sur 8086 }
             Code := 0;
             If (LexColNo <= Length(LexLine)) And (LexCurChar = '{') Then
               LexAdvance
             Else
               LexError('u: accolade ouvrante attendue');
             While (LexColNo <= Length(LexLine)) And
                   (LexCurChar <> '}') Do
             Begin
               If IsHexDigit(LexCurChar) Then
                 Code := Code * 16 + HexVal(LexCurChar)
               Else
               Begin
                 LexError('Chiffre hexa attendu dans sequence unicode');
                 Break;
               End;
               LexAdvance;
             End;
             If (LexColNo <= Length(LexLine)) And (LexCurChar = '}') Then
               LexAdvance
             Else
               LexError('u: accolade fermante manquante');
             IntOut := Code;
             LexScanEscape := Chr(Code And $FF);
           End;
  Else
    LexError('Sequence d''echappement inconnue');
    LexScanEscape := C;
    IntOut := Ord(C);
  End;
End;

{ ============================================================
  Procedure : LexScanCharLit - lire un litteral caractere 'X'
  ============================================================ }
Procedure LexScanCharLit(Var T : TToken; SL, SC : Integer);
Var
  C  : Char;
  IV : LongInt;
Begin
  LexAdvance; { consommer guillemet-simple ouverture }
  IV := 0;
  If LexColNo > Length(LexLine) Then
  Begin
    LexError('Litteral caractere non ferme');
    MakeToken(T, TK_CHAR, '''?''', SL, SC);
    Exit;
  End;
  C := LexCurChar;
  If Ord(C) = 92 Then  { backslash }
  Begin
    LexAdvance;
    C := LexScanEscape(IV);
  End Else
  Begin
    IV := Ord(C);
    LexAdvance;
  End;
  If (LexColNo <= Length(LexLine)) And (LexCurChar = '''') Then
    LexAdvance
  Else
    LexError('Guillemet-simple fermant manquant dans litteral caractere');
  MakeToken(T, TK_CHAR, '''' + C + '''', SL, SC);
  T.IntVal := IV;
End;

{ ============================================================
  Procedure : LexScanStrLit - lire un litteral chaine "..."
  ============================================================ }
Procedure LexScanStrLit(Var T : TToken; SL, SC : Integer);
Var
  S    : TString;
  C    : Char;
  IV   : LongInt;
  Done : Boolean;
Begin
  LexAdvance; { consommer guillemet-double ouverture }
  S    := '';
  Done := False;
  While Not Done Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexError('Chaine non fermee en fin de ligne');
      Done := True;
    End Else If Ord(LexCurChar) = 34 Then  { guillemet-double fermant }
    Begin
      LexAdvance;
      Done := True;
    End Else If Ord(LexCurChar) = 92 Then  { backslash }
    Begin
      LexAdvance;
      C := LexScanEscape(IV);
      If Length(S) < MAX_STR Then S := S + C;
    End Else
    Begin
      C := LexCurChar;
      LexAdvance;
      If Length(S) < MAX_STR Then S := S + C;
    End;
  End;
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ============================================================
  Procedure : LexScanRawStr - lire une raw string r"..." ou r#"..."#
             Le nombre de # doit correspondre en ouverture et fermeture.
             Les raw strings peuvent couvrir plusieurs lignes.
  ============================================================ }
Procedure LexScanRawStr(Var T : TToken; SL, SC : Integer);
Var
  S      : TString;
  Hashes : Integer;
  K      : Integer;
  C      : Char;
  Done   : Boolean;
Begin
  LexAdvance; { consommer 'r' }
  Hashes := 0;
  While (LexColNo <= Length(LexLine)) And (LexCurChar = '#') Do
  Begin
    Inc(Hashes);
    LexAdvance;
  End;
  If (LexColNo > Length(LexLine)) Or (Ord(LexCurChar) <> 34) Then
  Begin
    LexError('Raw string: guillemet-double attendu');
    MakeToken(T, TK_STRING, '', SL, SC);
    Exit;
  End;
  LexAdvance; { consommer guillemet-double ouverture }
  S    := '';
  Done := False;
  While Not Done Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      { Raw strings Rust peuvent s''etendre sur plusieurs lignes }
      If Length(S) < MAX_STR Then S := S + #10;
      LexNextLine;
      If LexEOF Then
      Begin
        LexError('Raw string non fermee en fin de fichier');
        Done := True;
      End;
    End Else
    Begin
      C := LexCurChar;
      If Ord(C) <> 34 Then
      Begin
        LexAdvance;
        If Length(S) < MAX_STR Then S := S + C;
      End Else
      Begin
        LexAdvance; { consommer guillemet-double potentiel de fermeture }
        K := 0;
        While (K < Hashes) And (LexColNo <= Length(LexLine)) And
              (LexCurChar = '#') Do
        Begin
          Inc(K);
          LexAdvance;
        End;
        If K = Hashes Then
          Done := True
        Else
        Begin
          { Pas la vraie fermeture - reintegrer les chars lus }
          If Length(S) < MAX_STR Then S := S + #34;
          While K > 0 Do
          Begin
            If Length(S) < MAX_STR Then S := S + '#';
            Dec(K);
          End;
        End;
      End;
    End;
  End;
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ============================================================
  Procedure : LexScanByteLit - lire un byte literal b'X'
  ============================================================ }
Procedure LexScanByteLit(Var T : TToken; SL, SC : Integer);
Var
  C  : Char;
  IV : LongInt;
Begin
  LexAdvance; { consommer 'b' }
  LexAdvance; { consommer guillemet-simple ouverture }
  IV := 0;
  If LexColNo > Length(LexLine) Then
  Begin
    LexError('Byte literal non ferme');
    MakeToken(T, TK_BYTE, 'b?', SL, SC);
    Exit;
  End;
  C := LexCurChar;
  If Ord(C) = 92 Then  { backslash }
  Begin
    LexAdvance;
    C := LexScanEscape(IV);
  End Else
  Begin
    IV := Ord(C) And $FF;
    LexAdvance;
  End;
  If (LexColNo <= Length(LexLine)) And (LexCurChar = '''') Then
    LexAdvance
  Else
    LexError('Guillemet-simple fermant manquant dans byte literal');
  MakeToken(T, TK_BYTE, 'b' + '''' + C + '''', SL, SC);
  T.IntVal := IV And $FF;
End;

{ ============================================================
  Procedure : LexScanByteStr - lire une byte string b"..."
  ============================================================ }
Procedure LexScanByteStr(Var T : TToken; SL, SC : Integer);
Var
  S    : TString;
  C    : Char;
  IV   : LongInt;
  Done : Boolean;
Begin
  LexAdvance; { consommer 'b' }
  LexAdvance; { consommer guillemet-double ouverture }
  S    := '';
  Done := False;
  While Not Done Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexError('Byte string non fermee en fin de ligne');
      Done := True;
    End Else If Ord(LexCurChar) = 34 Then
    Begin
      LexAdvance;
      Done := True;
    End Else If Ord(LexCurChar) = 92 Then
    Begin
      LexAdvance;
      C := LexScanEscape(IV);
      If Length(S) < MAX_STR Then S := S + C;
    End Else
    Begin
      C := LexCurChar;
      LexAdvance;
      If Length(S) < MAX_STR Then S := S + C;
    End;
  End;
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ============================================================
  Procedure : LexScanLifetime - lire une annotation de duree de vie
             Exemples : 'a  'static  'lifetime_name
  ============================================================ }
Procedure LexScanLifetime(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  LexAdvance; { consommer guillemet-simple }
  S := '''';
  While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
  Begin
    If Length(S) < MAX_STR Then S := S + LexCurChar;
    LexAdvance;
  End;
  MakeToken(T, TK_LIFETIME, S, SL, SC);
End;

{ ============================================================
  Procedure : LexScanOp - scanner un operateur simple ou compose
             Operateurs Rust reconnus :
             +  +=    -  ->  -=    *  *=    /  /=    %  %=
             &  &&  &=   |  ||  |=    ^  ^=    !  !=
             =  ==  =>    <  <=  <<  <<=    >  >=  >>  >>=
             :  ::    .  ..  ..=    ?  @  #
  ============================================================ }
Procedure LexScanOp(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
  C : Char;
  P : Char;
Begin
  C := LexCurChar;
  P := LexPeek;
  S := C;
  LexAdvance;
  Case C Of
    '+': If P = '=' Then Begin S := '+='; LexAdvance; End;
    '-': If P = '>' Then Begin S := '->'; LexAdvance; End
         Else If P = '=' Then Begin S := '-='; LexAdvance; End;
    '*': If P = '=' Then Begin S := '*='; LexAdvance; End;
    '/': If P = '=' Then Begin S := '/='; LexAdvance; End;
    '%': If P = '=' Then Begin S := '%='; LexAdvance; End;
    '&': If P = '&' Then Begin S := '&&'; LexAdvance; End
         Else If P = '=' Then Begin S := '&='; LexAdvance; End;
    '|': If P = '|' Then Begin S := '||'; LexAdvance; End
         Else If P = '=' Then Begin S := '|='; LexAdvance; End;
    '^': If P = '=' Then Begin S := '^='; LexAdvance; End;
    '!': If P = '=' Then Begin S := '!='; LexAdvance; End;
    '=': If P = '=' Then Begin S := '=='; LexAdvance; End
         Else If P = '>' Then Begin S := '=>'; LexAdvance; End;
    '<': If P = '=' Then Begin S := '<='; LexAdvance; End
         Else If P = '<' Then
         Begin
           S := '<<'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '<<='; LexAdvance; End;
         End;
    '>': If P = '=' Then Begin S := '>='; LexAdvance; End
         Else If P = '>' Then
         Begin
           S := '>>'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '>>='; LexAdvance; End;
         End;
    ':': If P = ':' Then Begin S := '::'; LexAdvance; End;
    '.': If P = '.' Then
         Begin
           S := '..'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '..='; LexAdvance; End;
         End;
  End;
  MakeToken(T, TK_OP, S, SL, SC);
End;

{ ============================================================
  Procedure : LexScanPunct - consommer un caractere de ponctuation
  ============================================================ }
Procedure LexScanPunct(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  S := LexCurChar;
  LexAdvance;
  MakeToken(T, TK_PUNCT, S, SL, SC);
End;

{ ============================================================
  Procedure : LexNextToken - produire le token suivant
  ============================================================ }
Procedure LexNextToken(Var T : TToken);
Var
  SL, SC : Integer;
  C      : Char;
Begin
  LexSkipWS;
  If LexEOF Or (LexColNo > Length(LexLine)) Then
  Begin
    MakeToken(T, TK_EOF, '', LexLineNo, LexColNo);
    Exit;
  End;
  SL := LexLineNo;
  SC := LexColNo;
  C  := LexCurChar;
  { Raw string r"..." ou r#"..."# }
  If (C = 'r') And ((Ord(LexPeek) = 34) Or (LexPeek = '#')) Then
  Begin
    LexScanRawStr(T, SL, SC); Exit;
  End;
  { Byte string b"..." ou byte literal b'.' }
  If C = 'b' Then
  Begin
    If Ord(LexPeek) = 34 Then Begin LexScanByteStr(T, SL, SC); Exit; End;
    If LexPeek = ''''     Then Begin LexScanByteLit(T, SL, SC); Exit; End;
  End;
  { Identifiant ou mot-cle }
  If IsAlpha(C) Then
  Begin
    LexScanIdent(T, SL, SC); Exit;
  End;
  { Litteraux numeriques }
  If IsDigit(C) Then
  Begin
    LexScanNumber(T, SL, SC); Exit;
  End;
  { Litteral chaine "..." }
  If Ord(C) = 34 Then Begin LexScanStrLit(T, SL, SC); Exit; End;
  { Litteral caractere 'X' OU annotation de duree de vie 'a }
  { Heuristique : ' + lettre + pas de ' en col+2 -> lifetime }
  If C = '''' Then
  Begin
    If IsAlpha(LexPeek) And
       ((LexColNo + 2 > Length(LexLine)) Or
        (LexLine[LexColNo + 2] <> '''')) Then
    Begin
      LexScanLifetime(T, SL, SC); Exit;
    End;
    LexScanCharLit(T, SL, SC); Exit;
  End;
  { Operateurs simples et composes Rust }
  Case C Of
    '+','-','*','/','%','&','|','^','!','=','<','>',':','.','?','@','#':
    Begin
      LexScanOp(T, SL, SC); Exit;
    End;
  End;
  { Ponctuation pure : ; , ( ) [ ] et blocs }
  LexScanPunct(T, SL, SC);
End;

{ ============================================================
  Procedure : LexInit - ouvrir le fichier et initialiser l'etat
  ============================================================ }
Procedure LexInit;
Begin
  LexOpened := False;
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened := True;
  LexEOF    := False;
  LexLineNo := 0;
  LexColNo  := 1;
  LexLine   := '';
  LexNextLine;
End;

{ ============================================================
  Procedure : LexClose - fermer le fichier source
  ============================================================ }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ============================================================
  Procedure : PrintToken - afficher un token (mode -d)
  ============================================================ }
Procedure PrintToken(Const T : TToken);
Var
  KS : String[10];
  NS : TString;
Begin
  Case T.Kind Of
    TK_IDENT    : KS := 'IDENT   ';
    TK_INTEGER  : KS := 'INTEGER ';
    TK_FLOAT    : KS := 'FLOAT   ';
    TK_CHAR     : KS := 'CHAR    ';
    TK_STRING   : KS := 'STRING  ';
    TK_BYTE     : KS := 'BYTE    ';
    TK_OP       : KS := 'OP      ';
    TK_PUNCT    : KS := 'PUNCT   ';
    TK_KEYWORD  : KS := 'KEYWORD ';
    TK_LIFETIME : KS := 'LIFETIME';
    TK_EOF      : KS := 'EOF     ';
  End;
  Write('[', T.Line, ':', T.Col, '] ', KS, ' "', T.Val, '"');
  If T.Kind = TK_INTEGER Then
  Begin
    Str(T.IntVal, NS);
    Write(' =', NS);
  End Else If T.Kind = TK_FLOAT Then
  Begin
    Str(T.FloatVal : 0 : 6, NS);
    Write(' =', NS);
  End Else If T.Kind = TK_CHAR Then
  Begin
    Str(T.IntVal, NS);
    Write(' cp=', NS);
  End Else If T.Kind = TK_BYTE Then
  Begin
    Str(T.IntVal, NS);
    Write(' val=', NS);
  End;
  WriteLn;
End;

{ ============================================================
  SYSTEME DE TYPES PRIMITIFS
  ============================================================ }

{ ============================================================
  Fonction  : TypeAddRec - enregistrer un type dans TypeTab
              Usage interne uniquement (TypeInit l'utilise).
  ============================================================ }
Function TypeAddRec(AKind : TTypeKind; Const AName : TString;
                    ASize, AAlign : Integer;
                    ASigned : Boolean;
                    AElem, ACount : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
  Begin
    WriteLn('RUST86: FATAL - table de types pleine');
    Halt(EXIT_ERROR);
  End;
  Idx := TypeCount;
  TypeTab[Idx].Kind       := AKind;
  TypeTab[Idx].Name       := AName;
  TypeTab[Idx].Size       := ASize;
  TypeTab[Idx].Align      := AAlign;
  TypeTab[Idx].Signed     := ASigned;
  TypeTab[Idx].ElemType   := AElem;
  TypeTab[Idx].ElemCount  := ACount;
  TypeTab[Idx].FieldBase  := 0;
  TypeTab[Idx].FieldCount := 0;
  Inc(TypeCount);
  TypeAddRec := Idx;
End;

{ ============================================================
  Procedure : TypeInit - enregistrer tous les types primitifs
              Doit etre appelee en tout premier avant toute
              compilation (avant meme SymInit).
  Mapping 8086 :
    i8 / u8    ->  1 octet  (AL/BL/CL/DL)
    i16 / u16  ->  2 octets (AX/BX)
    i32 / u32  ->  4 octets paire DX:AX
    isize/usize->  2 octets (equivalents u16 sur 8086)
    bool       ->  1 octet  (0 = false, 1 = true)
    char       ->  1 octet  (codepoint Unicode tronque en u8)
    ()         ->  0 octet  (type unite, pas de valeur)
    &str       ->  4 octets (ptr 2o + len 2o)
  ============================================================ }
Procedure TypeInit;
Var
  I : Integer;
Begin
  TypeCount  := 0;
  FieldCount := 0;  { bassin de champs }
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Kind       := TKD_UNKNOWN;
    TypeTab[I].Name       := '';
    TypeTab[I].Size       := 0;
    TypeTab[I].Align      := 1;
    TypeTab[I].Signed     := False;
    TypeTab[I].ElemType   := TY_UNKNOWN;
    TypeTab[I].ElemCount  := 0;
    TypeTab[I].FieldBase  := 0;
    TypeTab[I].FieldCount := 0;
  End;
  { Index fixes : TY_IDX_* }
  TypeAddRec(TKD_PRIM, 'i8',    1, 1, True,  TY_UNKNOWN, 0);  { 0  }
  TypeAddRec(TKD_PRIM, 'u8',    1, 1, False, TY_UNKNOWN, 0);  { 1  }
  TypeAddRec(TKD_PRIM, 'i16',   2, 2, True,  TY_UNKNOWN, 0);  { 2  }
  TypeAddRec(TKD_PRIM, 'u16',   2, 2, False, TY_UNKNOWN, 0);  { 3  }
  TypeAddRec(TKD_PRIM, 'i32',   4, 2, True,  TY_UNKNOWN, 0);  { 4  }
  TypeAddRec(TKD_PRIM, 'u32',   4, 2, False, TY_UNKNOWN, 0);  { 5  }
  TypeAddRec(TKD_PRIM, 'isize', 2, 2, True,  TY_UNKNOWN, 0);  { 6  }
  TypeAddRec(TKD_PRIM, 'usize', 2, 2, False, TY_UNKNOWN, 0);  { 7  }
  TypeAddRec(TKD_PRIM, 'bool',  1, 1, False, TY_UNKNOWN, 0);  { 8  }
  TypeAddRec(TKD_PRIM, 'char',  1, 1, False, TY_UNKNOWN, 0);  { 9  }
  TypeAddRec(TKD_PRIM, '()',    0, 1, False, TY_UNKNOWN, 0);  { 10 }
  TypeAddRec(TKD_REF,  '&str',  4, 2, False, TY_IDX_U8,  0);  { 11 }
End;

{ ============================================================
  Fonction  : TypeSizeof - taille en octets d'un type
              Retourne 0 pour les types inconnus / unit.
  ============================================================ }
Function TypeSizeof(Idx : Integer) : Integer;
Begin
  If (Idx < 0) Or (Idx >= TypeCount) Then
    TypeSizeof := 0
  Else
    TypeSizeof := TypeTab[Idx].Size;
End;

{ ============================================================
  Fonction  : TypeAlign - alignement requis d'un type en octets
  ============================================================ }
Function TypeAlign(Idx : Integer) : Integer;
Begin
  If (Idx < 0) Or (Idx >= TypeCount) Then
    TypeAlign := 1
  Else
    TypeAlign := TypeTab[Idx].Align;
End;

{ ============================================================
  Fonction  : TypeIsSigned - vrai si type entier signe
  ============================================================ }
Function TypeIsSigned(Idx : Integer) : Boolean;
Begin
  If (Idx < 0) Or (Idx >= TypeCount) Then
    TypeIsSigned := False
  Else
    TypeIsSigned := TypeTab[Idx].Signed;
End;

{ ============================================================
  Fonction  : TypeName - nom canonique Rust d'un type
  ============================================================ }
Function TypeName(Idx : Integer) : TString;
Begin
  If (Idx < 0) Or (Idx >= TypeCount) Then
    TypeName := '?'
  Else
    TypeName := TypeTab[Idx].Name;
End;

{ ============================================================
  Fonction  : TypeFind - chercher un type par nom canonique
              Retourne l'index ou TY_UNKNOWN (-1).
              Pour les primitifs, acces en O(TY_PRIM_COUNT).
  ============================================================ }
Function TypeFind(Const AName : TString) : Integer;
Var
  I : Integer;
Begin
  For I := 0 To TypeCount - 1 Do
    If TypeTab[I].Name = AName Then
    Begin
      TypeFind := I;
      Exit;
    End;
  TypeFind := TY_UNKNOWN;
End;

{ ============================================================
  Fonction  : TypeKindName - nom lisible de TTypeKind
  ============================================================ }
Function TypeKindName(K : TTypeKind) : TString;
Begin
  Case K Of
    TKD_PRIM   : TypeKindName := 'prim  ';
    TKD_REF    : TypeKindName := 'ref   ';
    TKD_PTR    : TypeKindName := 'ptr   ';
    TKD_ARRAY  : TypeKindName := 'array ';
    TKD_TUPLE  : TypeKindName := 'tuple ';
    TKD_STRUCT : TypeKindName := 'struct';
    TKD_ENUM   : TypeKindName := 'enum  ';
    TKD_FN     : TypeKindName := 'fn    ';
  Else
    TypeKindName := '?     ';
  End;
End;

{ ============================================================
  Procedure : TypeDump - afficher la table de types (mode -v)
  ============================================================ }
Procedure TypeDump;
Var
  I   : Integer;
  J   : Integer;
  SZ  : String[4];
  ALN : String[4];
  OFS : String[6];
  FB  : Integer;
Begin
  WriteLn;
  WriteLn('--- Table des types (', TypeCount, ' entrees) ---');
  For I := 0 To TypeCount - 1 Do
  Begin
    Str(TypeTab[I].Size,  SZ);
    Str(TypeTab[I].Align, ALN);
    Write('  [', I, '] kind=', TypeKindName(TypeTab[I].Kind),
          ' size=', SZ,
          ' align=', ALN,
          ' signed=', TypeTab[I].Signed,
          ' name=', TypeTab[I].Name);
    If TypeTab[I].ElemType >= 0 Then
      Write(' elem->', TypeTab[I].ElemType);
    WriteLn;
    { Pour tuples, tableaux, structs et enums : afficher les elements }
    If TypeTab[I].Kind In [TKD_TUPLE, TKD_ARRAY, TKD_STRUCT, TKD_ENUM] Then
    Begin
      If TypeTab[I].Kind = TKD_ARRAY Then
      Begin
        Str(TypeSizeof(TypeTab[I].ElemType), SZ);
        WriteLn('      array[', TypeTab[I].ElemCount, '] of ',
                TypeName(TypeTab[I].ElemType),
                ' (elem-size=', SZ, ')');
      End Else If TypeTab[I].Kind = TKD_ENUM Then
      Begin
        FB := TypeTab[I].FieldBase;
        For J := 0 To TypeTab[I].FieldCount - 1 Do
        Begin
          Str(FieldTab[FB + J].Offset, OFS);  { Offset = discriminant }
          Write('      #', OFS, ' ', FieldTab[FB + J].Name);
          If FieldTab[FB + J].TypeIdx <> TY_IDX_UNIT Then
            Write(' (', TypeName(FieldTab[FB + J].TypeIdx), ')');
          WriteLn;
        End;
      End Else
      Begin
        FB := TypeTab[I].FieldBase;
        For J := 0 To TypeTab[I].FieldCount - 1 Do
        Begin
          Str(FieldTab[FB + J].Offset, OFS);
          If FieldTab[FB + J].Name <> '' Then
            Write('      .', FieldTab[FB + J].Name)
          Else
            Write('      .', J);
          WriteLn(' @+', OFS,
                  ' type=', TypeName(FieldTab[FB + J].TypeIdx));
        End;
      End;
    End;
  End;
End;

{ ============================================================
  TYPES COMPOSES : TUPLES ET TABLEAUX
  ============================================================ }

{ ============================================================
  Fonction  : TypeAlignUp - arrondir V au prochain multiple de A
  ============================================================ }
Function TypeAlignUp(V, A : Integer) : Integer;
Begin
  If A <= 1 Then
    TypeAlignUp := V
  Else If (V Mod A) = 0 Then
    TypeAlignUp := V
  Else
    TypeAlignUp := V + (A - (V Mod A));
End;

{ ============================================================
  Fonction  : TypeAddField - ajouter un element dans le pool
              Usage interne uniquement.
              Retourne l'index dans FieldTab.
  ============================================================ }
Function TypeAddField(Const AName : TString;
                      ATypeIdx, AOffset : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If FieldCount >= MAX_FIELDS_TOTAL Then
  Begin
    WriteLn('RUST86: FATAL - pool de champs plein (MAX_FIELDS_TOTAL)');
    Halt(EXIT_ERROR);
  End;
  Idx := FieldCount;
  FieldTab[Idx].Name    := AName;
  FieldTab[Idx].TypeIdx := ATypeIdx;
  FieldTab[Idx].Offset  := AOffset;
  Inc(FieldCount);
  TypeAddField := Idx;
End;

{ ============================================================
  Fonction  : TypeAddArray - creer le type tableau [T; N]
              Taille = N * sizeof(T), alignement = align(T).
              Retourne l'index dans TypeTab.
  ============================================================ }
Function TypeAddArray(AElemIdx, N : Integer) : Integer;
Var
  Idx   : Integer;
  ESz   : Integer;
  EAln  : Integer;
  TName : TString;
  NS    : String[12];
Begin
  ESz  := TypeSizeof(AElemIdx);
  EAln := TypeAlign(AElemIdx);
  { Enregistrer le descripteur (nom provisoire vide) }
  Idx  := TypeAddRec(TKD_ARRAY, '', ESz * N, EAln, False, AElemIdx, N);
  { Construire le nom canonique '[T; N]' }
  TName := '[';
  TName := TName + TypeName(AElemIdx);
  TName := TName + '; ';
  Str(N, NS);
  TName := TName + NS;
  TName := TName + ']';
  TypeTab[Idx].Name := TName;
  TypeAddArray := Idx;
End;

{ ============================================================
  Fonction  : TypeAddTuple - creer un type tuple (T1, T2, ..., TN)
              sur 8086 : elements places sequentiellement, chacun
              aligne a son propre alignement. Taille finale arrondie
              a l'alignement maximal des elements.
              Retourne l'index dans TypeTab.
  ============================================================ }
Function TypeAddTuple(Const Elems : TTupleElems; N : Integer) : Integer;
Var
  Idx    : Integer;
  I      : Integer;
  Cur    : Integer;
  MaxAln : Integer;
  ESz    : Integer;
  EAln   : Integer;
  FB     : Integer;
  TName  : TString;
  NS     : String[4];
Begin
  If N = 0 Then
  Begin
    TypeAddTuple := TY_IDX_UNIT;
    Exit;
  End;
  Cur    := 0;
  MaxAln := 1;
  FB     := FieldCount;
  For I := 0 To N - 1 Do
  Begin
    ESz  := TypeSizeof(Elems[I]);
    EAln := TypeAlign(Elems[I]);
    Cur  := TypeAlignUp(Cur, EAln);
    Str(I, NS);
    TypeAddField(NS, Elems[I], Cur);
    Inc(Cur, ESz);
    If EAln > MaxAln Then MaxAln := EAln;
  End;
  Cur   := TypeAlignUp(Cur, MaxAln);
  { Nom canonique '(T1, T2, ...)' }
  TName := '(';
  For I := 0 To N - 1 Do
  Begin
    If I > 0 Then TName := TName + ', ';
    TName := TName + TypeName(Elems[I]);
  End;
  TName := TName + ')';
  Idx := TypeAddRec(TKD_TUPLE, TName, Cur, MaxAln, False, TY_UNKNOWN, N);
  TypeTab[Idx].FieldBase  := FB;
  TypeTab[Idx].FieldCount := N;
  TypeAddTuple := Idx;
End;

{ ============================================================
  Fonction  : TypeElemOffset - offset en octets de l'element K
              dans un type compose (array, tuple, struct).
  ============================================================ }
Function TypeElemOffset(TypeIdx, K : Integer) : Integer;
Var
  FB  : Integer;
  FC  : Integer;
  ESz : Integer;
Begin
  If (TypeIdx < 0) Or (TypeIdx >= TypeCount) Then
  Begin
    TypeElemOffset := 0;
    Exit;
  End;
  Case TypeTab[TypeIdx].Kind Of
    TKD_ARRAY :
    Begin
      ESz := TypeSizeof(TypeTab[TypeIdx].ElemType);
      TypeElemOffset := K * ESz;
    End;
    TKD_TUPLE, TKD_STRUCT :
    Begin
      FB := TypeTab[TypeIdx].FieldBase;
      FC := TypeTab[TypeIdx].FieldCount;
      If (K >= 0) And (K < FC) Then
        TypeElemOffset := FieldTab[FB + K].Offset
      Else
        TypeElemOffset := 0;
    End;
  Else
    TypeElemOffset := 0;
  End;
End;

{ ============================================================
  Fonction  : TypeElemType - type de l'element K dans un type
              compose (retourne TY_UNKNOWN si hors bornes).
  ============================================================ }
Function TypeElemType(TypeIdx, K : Integer) : Integer;
Var
  FB : Integer;
  FC : Integer;
Begin
  If (TypeIdx < 0) Or (TypeIdx >= TypeCount) Then
  Begin
    TypeElemType := TY_UNKNOWN;
    Exit;
  End;
  Case TypeTab[TypeIdx].Kind Of
    TKD_ARRAY :
      TypeElemType := TypeTab[TypeIdx].ElemType;
    TKD_TUPLE, TKD_STRUCT :
    Begin
      FB := TypeTab[TypeIdx].FieldBase;
      FC := TypeTab[TypeIdx].FieldCount;
      If (K >= 0) And (K < FC) Then
        TypeElemType := FieldTab[FB + K].TypeIdx
      Else
        TypeElemType := TY_UNKNOWN;
    End;
  Else
    TypeElemType := TY_UNKNOWN;
  End;
End;

{ ============================================================
  TYPES COMPOSES : STRUCT
  ============================================================ }

{ ============================================================
  Fonction  : TypeAddStructBegin - creer un descripteur TKD_STRUCT
              vide et retourner son index.
              Les champs sont ensuite ajoutes avec TypeAddStructField
              puis finalises avec TypeAddStructEnd.
  ============================================================ }
Function TypeAddStructBegin(Const AName : TString) : Integer;
Begin
  TypeAddStructBegin := TypeAddRec(TKD_STRUCT, AName, 0, 1, False, TY_UNKNOWN, 0);
  TypeTab[TypeCount - 1].FieldBase  := FieldCount;
  TypeTab[TypeCount - 1].FieldCount := 0;
End;

{ ============================================================
  Procedure : TypeAddStructField - ajouter un champ nomme a un
              struct en cours de construction.
              AStructIdx : index du struct dans TypeTab
              AFieldName : nom Rust du champ
              AFieldType : index du type du champ dans TypeTab
  ============================================================ }
Procedure TypeAddStructField(AStructIdx : Integer;
                             Const AFieldName : TString;
                             AFieldType : Integer);
Var
  ESz   : Integer;
  EAln  : Integer;
  Cur   : Integer;
  MaxA  : Integer;
Begin
  ESz  := TypeSizeof(AFieldType);
  EAln := TypeAlign(AFieldType);
  Cur  := TypeTab[AStructIdx].Size;
  Cur  := TypeAlignUp(Cur, EAln);
  TypeAddField(AFieldName, AFieldType, Cur);
  Inc(TypeTab[AStructIdx].FieldCount);
  Inc(Cur, ESz);
  TypeTab[AStructIdx].Size := Cur;
  MaxA := TypeTab[AStructIdx].Align;
  If EAln > MaxA Then
    TypeTab[AStructIdx].Align := EAln;
End;

{ ============================================================
  Procedure : TypeAddStructEnd - finaliser un struct :
              arrondir la taille totale a l'alignement maximal.
              (Requis en C/Rust pour que les tableaux de structs
              soient correctement alignes.)
  ============================================================ }
Procedure TypeAddStructEnd(AStructIdx : Integer);
Var
  A : Integer;
Begin
  A := TypeTab[AStructIdx].Align;
  TypeTab[AStructIdx].Size := TypeAlignUp(TypeTab[AStructIdx].Size, A);
End;

{ ============================================================
  Fonction  : TypeAddTupleStruct - creer un struct-tuple nomme
              (struct Foo(T1, T2)) : champs .0 .1 .2 ...
              Disposition identique a TypeAddTuple mais nomme.
  ============================================================ }
Function TypeAddTupleStruct(Const AName : TString;
                            Const Elems : TTupleElems;
                            N : Integer) : Integer;
Var
  Idx  : Integer;
  I    : Integer;
  NS   : String[4];
Begin
  Idx := TypeAddStructBegin(AName);
  For I := 0 To N - 1 Do
  Begin
    Str(I, NS);
    TypeAddStructField(Idx, NS, Elems[I]);
  End;
  TypeAddStructEnd(Idx);
  TypeAddTupleStruct := Idx;
End;

{ ============================================================
  Fonction  : TypeAddUnitStruct - creer un struct-unite
              (struct Foo;) : taille 0, aucun champ.
  ============================================================ }
Function TypeAddUnitStruct(Const AName : TString) : Integer;
Var
  Idx : Integer;
Begin
  Idx := TypeAddStructBegin(AName);
  TypeAddStructEnd(Idx);
  TypeAddUnitStruct := Idx;
End;

{ ============================================================
  Fonction  : TypeFindField - chercher un champ par nom dans un
              struct ou tuple. Retourne l'index dans FieldTab
              (absolu), ou -1 si non trouve.
  ============================================================ }
Function TypeFindField(AStructIdx : Integer;
                       Const AFieldName : TString) : Integer;
Var
  FB : Integer;
  FC : Integer;
  I  : Integer;
Begin
  If (AStructIdx < 0) Or (AStructIdx >= TypeCount) Then
  Begin
    TypeFindField := -1;
    Exit;
  End;
  FB := TypeTab[AStructIdx].FieldBase;
  FC := TypeTab[AStructIdx].FieldCount;
  For I := 0 To FC - 1 Do
    If FieldTab[FB + I].Name = AFieldName Then
    Begin
      TypeFindField := FB + I;
      Exit;
    End;
  TypeFindField := -1;
End;

{ ============================================================
  Fonction  : TypeFieldOffset - offset d'un champ par nom
              dans un struct. Retourne 0 si non trouve.
  ============================================================ }
Function TypeFieldOffset(AStructIdx : Integer;
                         Const AFieldName : TString) : Integer;
Var
  FIdx : Integer;
Begin
  FIdx := TypeFindField(AStructIdx, AFieldName);
  If FIdx < 0 Then
    TypeFieldOffset := 0
  Else
    TypeFieldOffset := FieldTab[FIdx].Offset;
End;

{ ============================================================
  TYPES COMPOSES : ENUM
  Encodage 8086 :
    octet 0    = tag discriminant (u8, 0..N-1)
    octets 1.. = donnees de la variante (payload)
  Taille totale = 1 + max_payload, arrondi a max_align.
  Dans FieldTab, chaque entree de variante utilise :
    Name    = nom de la variante
    TypeIdx = type du payload (TY_IDX_UNIT si variante unite)
    Offset  = valeur du discriminant (0, 1, 2, ...)
  ============================================================ }

{ ============================================================
  Fonction  : TypeAddEnumBegin - creer un descripteur TKD_ENUM
              vide et retourner son index.
  ============================================================ }
Function TypeAddEnumBegin(Const AName : TString) : Integer;
Var
  Idx : Integer;
Begin
  Idx := TypeAddRec(TKD_ENUM, AName, 0, 1, False, TY_UNKNOWN, 0);
  TypeTab[Idx].FieldBase  := FieldCount;
  TypeTab[Idx].FieldCount := 0;
  TypeTab[Idx].ElemCount  := 0;  { prochain discriminant }
  TypeAddEnumBegin := Idx;
End;

{ ============================================================
  Fonction  : TypeAddVariantUnit - ajouter une variante unite
              (sans donnees) a un enum.
              Exemple : None dans Option<T>.
              Retourne la valeur du discriminant.
  ============================================================ }
Function TypeAddVariantUnit(AEnumIdx : Integer;
                            Const AVarName : TString) : Integer;
Var
  Tag : Integer;
Begin
  Tag := TypeTab[AEnumIdx].ElemCount;
  TypeAddField(AVarName, TY_IDX_UNIT, Tag);  { Offset = discriminant }
  Inc(TypeTab[AEnumIdx].FieldCount);
  Inc(TypeTab[AEnumIdx].ElemCount);
  TypeAddVariantUnit := Tag;
End;

{ ============================================================
  NOTE : Pour les variantes avec donnees (tuple ou struct),
  construire le type payload EN PREMIER (TypeAddTupleStruct ou
  TypeAddStructBegin/Field/End), PUIS appeler TypeAddEnumBegin,
  puis TypeAddVariantUnit / TypeAddVariantWithPayload.
  Cela garantit que les entrees de variantes dans FieldTab
  restent contigu‚s.
  ============================================================ }

{ ============================================================
  Fonction  : TypeAddVariantWithPayload - ajouter une variante
              avec un type payload deja construit (struct, tuple
              ou primitif). Pour les variantes struct :
              construire d'abord le payload avec TypeAddStructBegin
              puis appeler cette fonction.
              Retourne le discriminant.
  ============================================================ }
Function TypeAddVariantWithPayload(AEnumIdx : Integer;
                                   Const AVarName : TString;
                                   PayloadTypeIdx : Integer) : Integer;
Var
  Tag    : Integer;
  PldSz  : Integer;
  PldAln : Integer;
Begin
  Tag    := TypeTab[AEnumIdx].ElemCount;
  PldSz  := TypeSizeof(PayloadTypeIdx);
  PldAln := TypeAlign(PayloadTypeIdx);
  TypeAddField(AVarName, PayloadTypeIdx, Tag);
  Inc(TypeTab[AEnumIdx].FieldCount);
  Inc(TypeTab[AEnumIdx].ElemCount);
  If PldSz > TypeTab[AEnumIdx].Size Then
    TypeTab[AEnumIdx].Size := PldSz;
  If PldAln > TypeTab[AEnumIdx].Align Then
    TypeTab[AEnumIdx].Align := PldAln;
  TypeAddVariantWithPayload := Tag;
End;

{ ============================================================
  Procedure : TypeAddEnumEnd - finaliser un enum :
              taille = 1 (tag) + max_payload, arrondi a l'alignement.
              Si l'enum est purement unite (pas de payload),
              la taille reste 1.
  ============================================================ }
Procedure TypeAddEnumEnd(AEnumIdx : Integer);
Var
  MaxPld : Integer;
  A      : Integer;
Begin
  MaxPld := TypeTab[AEnumIdx].Size;  { max payload accumule }
  A      := TypeTab[AEnumIdx].Align;
  If A < 1 Then A := 1;
  { taille = 1 (tag u8) + payload aligne apres le tag }
  TypeTab[AEnumIdx].Size := TypeAlignUp(1 + MaxPld, A);
  TypeTab[AEnumIdx].Align := A;
End;

{ ============================================================
  Fonction  : TypeFindVariant - chercher une variante par nom
              dans un enum. Retourne l'index absolu dans
              FieldTab, ou -1 si non trouve.
  ============================================================ }
Function TypeFindVariant(AEnumIdx : Integer;
                         Const AVarName : TString) : Integer;
Var
  FB : Integer;
  FC : Integer;
  I  : Integer;
Begin
  If (AEnumIdx < 0) Or (AEnumIdx >= TypeCount) Then
  Begin
    TypeFindVariant := -1;
    Exit;
  End;
  If TypeTab[AEnumIdx].Kind <> TKD_ENUM Then
  Begin
    TypeFindVariant := -1;
    Exit;
  End;
  FB := TypeTab[AEnumIdx].FieldBase;
  FC := TypeTab[AEnumIdx].FieldCount;
  For I := 0 To FC - 1 Do
    If FieldTab[FB + I].Name = AVarName Then
    Begin
      TypeFindVariant := FB + I;
      Exit;
    End;
  TypeFindVariant := -1;
End;

{ ============================================================
  Fonction  : TypeVariantDiscriminant - retourne la valeur du
              discriminant d'une variante (ou -1 si non trouvee).
  ============================================================ }
Function TypeVariantDiscriminant(AEnumIdx : Integer;
                                 Const AVarName : TString) : Integer;
Var
  FIdx : Integer;
Begin
  FIdx := TypeFindVariant(AEnumIdx, AVarName);
  If FIdx < 0 Then
    TypeVariantDiscriminant := -1
  Else
    TypeVariantDiscriminant := FieldTab[FIdx].Offset;  { Offset stocke le tag }
End;

{ ============================================================
  Fonction  : TypeVariantPayload - retourne l'index du type
              payload d'une variante (TY_IDX_UNIT si unite).
  ============================================================ }
Function TypeVariantPayload(AEnumIdx : Integer;
                            Const AVarName : TString) : Integer;
Var
  FIdx : Integer;
Begin
  FIdx := TypeFindVariant(AEnumIdx, AVarName);
  If FIdx < 0 Then
    TypeVariantPayload := TY_IDX_UNIT
  Else
    TypeVariantPayload := FieldTab[FIdx].TypeIdx;
End;

{ ============================================================
  TRAITS ET IMPL (SANS DYNAMIC DISPATCH)
  ============================================================ }

{ ============================================================
  Procedure : ImplInit - initialiser les tables impl/methode
  ============================================================ }
Procedure ImplInit;
Var
  I : Integer;
Begin
  ImplCount   := 0;
  MethodCount := 0;
  For I := 0 To MAX_IMPL - 1 Do
  Begin
    ImplTab[I].TypeName    := '';
    ImplTab[I].TraitName   := '';
    ImplTab[I].MethodBase  := 0;
    ImplTab[I].MethodCount := 0;
    ImplTab[I].TypeIdx     := TY_UNKNOWN;
  End;
  For I := 0 To MAX_METHOD - 1 Do
  Begin
    MethodTab[I].Name        := '';
    MethodTab[I].MangledName := '';
    MethodTab[I].RetTypeIdx  := TY_IDX_UNIT;
    MethodTab[I].IsPublic    := False;
    MethodTab[I].ImplIdx     := -1;
  End;
End;

{ ============================================================
  Fonction  : ImplAdd - enregistrer un nouveau bloc impl Type
              ou impl Trait for Type.
              ATraitName = '' si c'est un impl libre.
              Retourne l'index du bloc impl ou -1 si table pleine.
  ============================================================ }
Function ImplAdd(Const ATypeName : TString;
                 Const ATraitName : TString) : Integer;
Var
  Idx : Integer;
Begin
  If ImplCount >= MAX_IMPL Then
  Begin
    WriteLn('RUST86: FATAL - table impl pleine (MAX_IMPL=', MAX_IMPL, ')');
    Halt(EXIT_ERROR);
  End;
  Idx := ImplCount;
  ImplTab[Idx].TypeName    := ATypeName;
  ImplTab[Idx].TraitName   := ATraitName;
  ImplTab[Idx].MethodBase  := MethodCount;
  ImplTab[Idx].MethodCount := 0;
  ImplTab[Idx].TypeIdx     := TypeFind(ATypeName);
  Inc(ImplCount);
  ImplAdd := Idx;
End;

{ ============================================================
  Fonction  : ImplFind - trouver le premier bloc impl d'un type
              (impl libre, sans trait). Retourne l'index ou -1.
  ============================================================ }
Function ImplFind(Const ATypeName : TString) : Integer;
Var
  I : Integer;
Begin
  For I := 0 To ImplCount - 1 Do
    If (ImplTab[I].TypeName = ATypeName) And
       (ImplTab[I].TraitName = '') Then
    Begin
      ImplFind := I;
      Exit;
    End;
  ImplFind := -1;
End;

{ ============================================================
  Fonction  : ImplFindTrait - trouver un bloc impl Trait for Type.
              Retourne l'index ou -1.
  ============================================================ }
Function ImplFindTrait(Const ATypeName : TString;
                       Const ATraitName : TString) : Integer;
Var
  I : Integer;
Begin
  For I := 0 To ImplCount - 1 Do
    If (ImplTab[I].TypeName  = ATypeName) And
       (ImplTab[I].TraitName = ATraitName) Then
    Begin
      ImplFindTrait := I;
      Exit;
    End;
  ImplFindTrait := -1;
End;

{ ============================================================
  Fonction  : ImplAddMethod - enregistrer une methode dans un
              bloc impl et dans la table des symboles.
              Le nom mangle est _IMP_TypeName_MethodName.
              Retourne l'index dans MethodTab ou -1.
  ============================================================ }
Function ImplAddMethod(AImplIdx : Integer;
                       Const AName : TString;
                       ARetTypeIdx : Integer;
                       AIsPublic   : Boolean) : Integer;
Var
  Idx    : Integer;
  MN     : TString;
  TName  : TString;
Begin
  If MethodCount >= MAX_METHOD Then
  Begin
    WriteLn('RUST86: FATAL - table methodes pleine (MAX_METHOD=', MAX_METHOD, ')');
    Halt(EXIT_ERROR);
  End;
  Idx   := MethodCount;
  TName := ImplTab[AImplIdx].TypeName;
  MN    := RS_IMPL_PFX + TName + '_' + AName;
  MethodTab[Idx].Name        := AName;
  MethodTab[Idx].MangledName := MN;
  MethodTab[Idx].RetTypeIdx  := ARetTypeIdx;
  MethodTab[Idx].IsPublic    := AIsPublic;
  MethodTab[Idx].ImplIdx     := AImplIdx;
  Inc(ImplTab[AImplIdx].MethodCount);
  Inc(MethodCount);
  { Note : enregistrement dans SymTab effectue par le parseur }
  ImplAddMethod := Idx;
End;

{ ============================================================
  Fonction  : ImplFindMethod - chercher une methode par nom dans
              un bloc impl. Retourne l'index dans MethodTab ou -1.
  ============================================================ }
Function ImplFindMethod(AImplIdx : Integer;
                        Const AName : TString) : Integer;
Var
  I    : Integer;
  Base : Integer;
  Cnt  : Integer;
Begin
  If (AImplIdx < 0) Or (AImplIdx >= ImplCount) Then
  Begin
    ImplFindMethod := -1;
    Exit;
  End;
  Base := ImplTab[AImplIdx].MethodBase;
  Cnt  := ImplTab[AImplIdx].MethodCount;
  For I := Base To Base + Cnt - 1 Do
    If MethodTab[I].Name = AName Then
    Begin
      ImplFindMethod := I;
      Exit;
    End;
  ImplFindMethod := -1;
End;

{ ============================================================
  Procedure : ImplCheckDynTrait - signaler une erreur si l'on
              rencontre le mot-cle 'dyn' (dynamic dispatch).
              Le dynamic dispatch n'est pas supporte sur 8086/TP7.
  ============================================================ }
Procedure ImplCheckDynTrait(Const TraitName : TString);
Begin
  Inc(ErrorCount);
  WriteLn('RUST86: Erreur [dyn non supporte] : dyn ', TraitName,
          ' - le dispatch dynamique est interdit sur cible 8086.');
  If ErrorCount >= MAX_ERRORS Then
    FatalError('Trop d' + #39 + 'erreurs, compilation abandonnee.');
End;

{ ============================================================
  Procedure : ImplDump - afficher les blocs impl (mode -v)
  ============================================================ }
Procedure ImplDump;
Var
  I : Integer;
  J : Integer;
  B : Integer;
Begin
  WriteLn;
  WriteLn('--- Table impl (', ImplCount, ' blocs, ', MethodCount, ' methodes) ---');
  For I := 0 To ImplCount - 1 Do
  Begin
    Write('  impl[', I, '] type=', ImplTab[I].TypeName);
    If ImplTab[I].TraitName <> '' Then
      Write(' trait=', ImplTab[I].TraitName);
    WriteLn(' methods=', ImplTab[I].MethodCount);
    B := ImplTab[I].MethodBase;
    For J := B To B + ImplTab[I].MethodCount - 1 Do
    Begin
      Write('    .', MethodTab[J].Name);
      If MethodTab[J].IsPublic Then Write(' [pub]');
      WriteLn(' -> ', MethodTab[J].MangledName,
              ' ret=', TypeName(MethodTab[J].RetTypeIdx));
    End;
  End;
End;

{ ============================================================
  TABLE DES SYMBOLES
  ============================================================ }

{ ============================================================
  Procedure : SymInit - initialiser la table des symboles
  ============================================================ }
Procedure SymInit;
Begin
  SymCount  := 0;
  ScopeTop  := 0;
  CurScope  := 0;
  LabelSeq  := 0;
  ScopeStack[0] := 0;
End;

{ ============================================================
  Procedure : SymEnterScope - entrer dans une nouvelle portee
  ============================================================ }
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE - 1 Then
  Begin
    LexError('Profondeur de portee maximale atteinte');
    Exit;
  End;
  Inc(CurScope);
  Inc(ScopeTop);
  ScopeStack[ScopeTop] := SymCount;
End;

{ ============================================================
  Procedure : SymLeaveScope - quitter la portee courante
             Les symboles de la portee sont retires de la table.
  ============================================================ }
Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then
  Begin
    LexError('Desequilibre de portees : LeaveScope sans EnterScope');
    Exit;
  End;
  SymCount := ScopeStack[ScopeTop];
  Dec(ScopeTop);
  Dec(CurScope);
End;

{ ============================================================
  Fonction : SymMangle - construire l'etiquette assembleur 8086
             pour un symbole selon sa categorie et son chemin.
             Exemples :
               SC_FN     "foo"         -> _RSF_foo
               SC_VAR    "x" (local)   -> (offset BP, pas d'etiquette)
               SC_STATIC "CNT"         -> _RSV_CNT
               SC_IMPL   "Vec::push"   -> _IMP_Vec_push
  ============================================================ }
Function SymMangle(Cat : TSymCat; Const BaseName : TString) : TString;
Var
  S : TString;
  I : Integer;
  T : TString;
  J : Integer;
Begin
  S := BaseName;
  { Remplacer :: par _ dans le nom }
  I := 1;
  While I <= Length(S) - 1 Do
  Begin
    If (S[I] = ':') And (S[I + 1] = ':') Then
    Begin
      Delete(S, I, 2);
      If I <= Length(S) Then
        System.Insert('_', S, I);
    End Else
      Inc(I);
  End;
  Case Cat Of
    SC_FN : Begin
      If CurModPath <> '' Then Begin
        T := CurModPath + '::' + BaseName;
        J := 1;
        While J <= Length(T) - 1 Do Begin
          If (T[J] = ':') And (T[J+1] = ':') Then Begin
            Delete(T, J, 2);
            If J <= Length(T) Then System.Insert('_', T, J);
          End Else Inc(J);
        End;
        SymMangle := RS_MOD_PFX + T;
      End Else
        SymMangle := RS_FN_PFX + S;
    End;
    SC_STATIC : SymMangle := RS_VAR_PFX  + S;
    SC_CONST  : SymMangle := RS_VAR_PFX  + S;
    SC_IMPL   : SymMangle := RS_IMPL_PFX + S;
    SC_TYPEDEF: SymMangle := '_RST_'     + S;
  Else
    SymMangle := '_RSL_' + S;   { locals : etiquette rarement emise }
  End;
End;

{ ============================================================
  Fonction : SymAdd - ajouter un symbole dans la table
             Retourne l'index du symbole ajoute (0-base)
             ou -1 en cas d'erreur.
  ============================================================ }
Function SymAdd(Const AName : TString; ACat : TSymCat;
                ATypeIdx : Integer; AIsMut : Boolean;
                AOffset : Integer; ADeclLine : Integer) : Integer;
Var
  Idx  : Integer;
  MN   : TString;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    LexError('Table des symboles pleine');
    SymAdd := -1;
    Exit;
  End;
  Idx := SymCount;
  SymTab[Idx].Name       := AName;
  SymTab[Idx].Cat        := ACat;
  SymTab[Idx].TypeIdx    := ATypeIdx;
  SymTab[Idx].ScopeLevel := CurScope;
  SymTab[Idx].Offset     := AOffset;
  SymTab[Idx].IsMut      := AIsMut;
  SymTab[Idx].IsRef      := False;
  SymTab[Idx].DeclLine   := ADeclLine;
  If (ACat = SC_VAR) Or (ACat = SC_PARAM) Then
    MN := ''   { variables locales : acces par [BP+offset], pas d'etiquette globale }
  Else
    MN := SymMangle(ACat, AName);
  SymTab[Idx].MangledName := MN;
  Inc(SymCount);
  Inc(TotalSyms);
  SymAdd := Idx;
End;

{ ============================================================
  Fonction : SymFindLocal - chercher un symbole dans la portee
             courante uniquement (pour detecter les redeclarations).
             Retourne l'index ou -1.
  ============================================================ }
Function SymFindLocal(Const AName : TString) : Integer;
Var
  I     : Integer;
  Start : Integer;
Begin
  Start := ScopeStack[ScopeTop];
  For I := SymCount - 1 DownTo Start Do
    If SymTab[I].Name = AName Then
    Begin
      SymFindLocal := I;
      Exit;
    End;
  SymFindLocal := -1;
End;

{ ============================================================
  Fonction : SymFind - chercher un symbole dans toutes les portees
             (portee la plus proche en premier).
             Retourne l'index ou -1.
  ============================================================ }
Function SymFind(Const AName : TString) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].Name = AName Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := -1;
End;

{ ============================================================
  Fonction : SymFindCat - chercher un symbole d'une categorie
             precise dans toutes les portees.
             Retourne l'index ou -1.
  ============================================================ }
Function SymFindCat(Const AName : TString; ACat : TSymCat) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].Name = AName) And (SymTab[I].Cat = ACat) Then
    Begin
      SymFindCat := I;
      Exit;
    End;
  SymFindCat := -1;
End;

{ ============================================================
  Fonction : SymNewLabel - generer une etiquette locale unique
             Exemple : SymNewLabel('IF') -> '_RSL_IF_17'
  ============================================================ }
Function SymNewLabel(Const Prefix : TString) : TString;
Var
  NS : TString;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, NS);
  SymNewLabel := RS_LABEL_PFX + Prefix + '_' + NS;
End;

{ ============================================================
  Procedure : SymCatName - nom lisible d'une categorie de symbole
  ============================================================ }
Function SymCatName(Cat : TSymCat) : TString;
Begin
  Case Cat Of
    SC_VAR     : SymCatName := 'var   ';
    SC_PARAM   : SymCatName := 'param ';
    SC_FN      : SymCatName := 'fn    ';
    SC_CONST   : SymCatName := 'const ';
    SC_STATIC  : SymCatName := 'static';
    SC_TYPEDEF : SymCatName := 'type  ';
    SC_FIELD   : SymCatName := 'field ';
    SC_IMPL    : SymCatName := 'impl  ';
  Else
    SymCatName := '?     ';
  End;
End;

{ ============================================================
  Procedure : SymDump - afficher la table des symboles (debug)
  ============================================================ }
Procedure SymDump;
Var
  I   : Integer;
  MN  : TString;
  OFS : String[8];
Begin
  WriteLn;
  WriteLn('--- Table des symboles (', SymCount, ' entrees) ---');
  For I := 0 To SymCount - 1 Do
  Begin
    Str(SymTab[I].Offset, OFS);
    MN := SymTab[I].MangledName;
    If MN = '' Then MN := '[BP' + OFS + ']';
    Write('  [', I, '] sc=', SymTab[I].ScopeLevel,
          ' cat=', SymCatName(SymTab[I].Cat),
          ' mut=', SymTab[I].IsMut,
          ' name=', SymTab[I].Name);
    If MN <> '' Then Write(' -> ', MN);
    WriteLn;
  End;
End;

{ ============================================================
  REFERENCES ET EMPRUNTS
  BorrowInit, TypeAddRef, BorrowAdd, BorrowCheckMutConflict,
  BorrowRelease, BorrowDump
  ============================================================ }

{ ---- BorrowInit : initialise la table des emprunts ---- }
Procedure BorrowInit;
Var I : Integer;
Begin
  For I := 0 To MAX_BORROW - 1 Do Begin
    BorrowTab[I].VarName  := '';
    BorrowTab[I].Kind     := BK_SHARED;
    BorrowTab[I].TypeIdx  := TY_UNKNOWN;
    BorrowTab[I].IsActive := False;
    BorrowTab[I].DeclLine := 0;
  End;
  BorrowCount := 0;
End;

{ ---- TypeAddRef : cree un type reference &T ou &mut T ----
  AElemIdx = index du type pointe, AIsMut = True pour &mut T.
  Retourne l'index dans TypeTab.                            }
Function TypeAddRef(AElemIdx : Integer; AIsMut : Boolean) : Integer;
Var
  Idx : Integer;
  Nom : TString;
Begin
  If AIsMut Then Nom := '&mut ' + TypeName(AElemIdx)
            Else Nom := '&'     + TypeName(AElemIdx);
  Idx := TypeAddRec(TKD_REF, Nom, 2, 2, False, AElemIdx, 0);
  TypeAddRef := Idx;
End;

{ ---- TypeAddPtr : cree un type pointeur brut *const T ou *mut T ----
  AElemIdx = index du type pointe, AIsMut = True pour *mut T.           }
Function TypeAddPtr(AElemIdx : Integer; AIsMut : Boolean) : Integer;
Var
  Idx : Integer;
  Nom : TString;
Begin
  If AIsMut Then Nom := '*mut '   + TypeName(AElemIdx)
            Else Nom := '*const ' + TypeName(AElemIdx);
  Idx := TypeAddRec(TKD_PTR, Nom, 2, 2, False, AElemIdx, 0);
  TypeAddPtr := Idx;
End;

{ ---- BorrowAdd : enregistre un nouvel emprunt ----
  Retourne l'index dans BorrowTab.                  }
Function BorrowAdd(Const AVarName : TString; AKind : TBorrowKind;
                   ATypeIdx, ADeclLine : Integer) : Integer;
Var Idx : Integer;
Begin
  If BorrowCount >= MAX_BORROW Then Begin
    WriteLn('RUST86: FATAL - table d'#39'emprunts pleine (MAX_BORROW=', MAX_BORROW, ')');
    Halt(EXIT_ERROR);
  End;
  Idx := BorrowCount;
  BorrowTab[Idx].VarName  := AVarName;
  BorrowTab[Idx].Kind     := AKind;
  BorrowTab[Idx].TypeIdx  := ATypeIdx;
  BorrowTab[Idx].IsActive := True;
  BorrowTab[Idx].DeclLine := ADeclLine;
  Inc(BorrowCount);
  BorrowAdd := Idx;
End;

{ ---- BorrowCheckMutConflict : unicite reference mutable ----
  Retourne True si une reference &mut pour AVarName est deja
  active (emet une erreur de compilation dans ce cas).      }
Function BorrowCheckMutConflict(Const AVarName : TString) : Boolean;
Var I : Integer;
Begin
  BorrowCheckMutConflict := False;
  For I := 0 To BorrowCount - 1 Do Begin
    If BorrowTab[I].IsActive And (BorrowTab[I].Kind = BK_MUT)
       And (BorrowTab[I].VarName = AVarName) Then Begin
      WriteLn('RUST86: erreur: variable ', AVarName,
              ' possede deja une reference mutable active',
              ' (declaree a la ligne ', BorrowTab[I].DeclLine, ')');
      Inc(ErrorCount);
      BorrowCheckMutConflict := True;
      Exit;
    End;
  End;
End;

{ ---- BorrowRelease : desactive tous les emprunts d'une variable ---- }
Procedure BorrowRelease(Const AVarName : TString);
Var I : Integer;
Begin
  For I := 0 To BorrowCount - 1 Do Begin
    If BorrowTab[I].VarName = AVarName Then
      BorrowTab[I].IsActive := False;
  End;
End;

{ ---- BorrowDump : affiche la table des emprunts en mode -v ---- }
Procedure BorrowDump;
Var I : Integer;
Begin
  WriteLn('--- BorrowTab (', BorrowCount, ' entrees) ---');
  For I := 0 To BorrowCount - 1 Do Begin
    Write('  [', I, '] var=', BorrowTab[I].VarName, ' kind=');
    If BorrowTab[I].Kind = BK_MUT Then Write('&mut') Else Write('&');
    Write(' tyidx=', BorrowTab[I].TypeIdx,
          ' active=', BorrowTab[I].IsActive,
          ' line=', BorrowTab[I].DeclLine);
    WriteLn;
  End;
End;

{ ============================================================
  DUREES DE VIE (LIFETIME ELISION UNIQUEMENT)
  LifetimeInit, LifetimeAdd, LifetimeFind, LifetimeElide, LifetimeDump
  ============================================================ }

{ ---- LifetimeInit : vider la table des durees de vie ---- }
Procedure LifetimeInit;
Var I : Integer;
Begin
  For I := 0 To MAX_LIFETIME - 1 Do Begin
    LifetimeTab[I].Name       := '';
    LifetimeTab[I].ScopeLevel := 0;
    LifetimeTab[I].DeclLine   := 0;
    LifetimeTab[I].IsElided   := False;
    LifetimeTab[I].IsComplex  := False;
  End;
  LifetimeCount := 0;
End;

{ ---- LifetimeAdd : enregistrer une annotation de duree de vie ----
  Retourne l'index dans LifetimeTab.                              }
Function LifetimeAdd(Const AName : TString; AScopeLevel, ADeclLine : Integer;
                     AIsElided : Boolean) : Integer;
Var Idx : Integer;
Begin
  If LifetimeCount >= MAX_LIFETIME Then Begin
    WriteLn('RUST86: FATAL - table lifetimes pleine (MAX_LIFETIME=', MAX_LIFETIME, ')');
    Halt(EXIT_ERROR);
  End;
  Idx := LifetimeCount;
  LifetimeTab[Idx].Name       := AName;
  LifetimeTab[Idx].ScopeLevel := AScopeLevel;
  LifetimeTab[Idx].DeclLine   := ADeclLine;
  LifetimeTab[Idx].IsElided   := AIsElided;
  LifetimeTab[Idx].IsComplex  := False;
  Inc(LifetimeCount);
  LifetimeAdd := Idx;
End;

{ ---- LifetimeFind : rechercher une lifetime par son nom ----
  Retourne l'index ou -1 si absente.                          }
Function LifetimeFind(Const AName : TString) : Integer;
Var I : Integer;
Begin
  LifetimeFind := -1;
  For I := 0 To LifetimeCount - 1 Do
    If LifetimeTab[I].Name = AName Then Begin
      LifetimeFind := I;
      Exit;
    End;
End;

{ ---- LifetimeElide : appliquer les regles d'elision standard ----
  AInputRefCount = nombre de references en entree de la signature.
  Regle 1 : 0 refs en entree -> pas de sortie lifetime (OK, True).
  Regle 2 : 1 ref en entree  -> elision : sortie = meme lifetime (OK, True).
  Sinon    : complexe -> avertissement, retourne False.            }
Function LifetimeElide(AInputRefCount : Integer) : Boolean;
Begin
  If AInputRefCount <= 1 Then Begin
    LifetimeElide := True;
    Exit;
  End;
  WriteLn('RUST86: avertissement: ',
          AInputRefCount, ' references en entree, ',
          'l', #39, 'elision de duree de vie ne s', #39,
          'applique pas, annotation explicite non verifiee.');
  Inc(WarnCount);
  LifetimeElide := False;
End;

{ ---- LifetimeDump : afficher la table des durees de vie en mode -v ---- }
Procedure LifetimeDump;
Var I : Integer;
Begin
  WriteLn('--- LifetimeTab (', LifetimeCount, ' entrees) ---');
  For I := 0 To LifetimeCount - 1 Do Begin
    Write('  [', I, '] name=', LifetimeTab[I].Name,
          ' scope=', LifetimeTab[I].ScopeLevel,
          ' line=',  LifetimeTab[I].DeclLine,
          ' elided=', LifetimeTab[I].IsElided,
          ' complex=', LifetimeTab[I].IsComplex);
    WriteLn;
  End;
End;

{ ============================================================
  PARSEUR D'EXPRESSIONS ET GENERATION DE CODE 8086
  EmitOpen, EmitClose, EmitRaw, EmitInstr, EmitLabel, EmitComment,
  BinOpPrec, ExprMakeImm, ExprMakeNone, ExprLoad,
  ExprEmitBinOp, ParserAdvance,
  ParseExprPrec (Forward), ParsePrimary, ParseExprPrec, ParseExpr
  ============================================================ }

{ ---- EmitOpen : ouvrir le fichier de sortie en ecriture ---- }
Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  {$I-}
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('RUST86: Erreur - impossible de creer ', Opts.OutFile);
    Inc(ErrorCount);
    OutFOpen := False;
    Exit;
  End;
  OutFOpen := True;
End;

{ ---- EmitClose : fermer le fichier de sortie ---- }
Procedure EmitClose;
Begin
  If OutFOpen Then Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ---- EmitRaw : ecrire une ligne brute dans le fichier de sortie ---- }
Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then WriteLn(OutF, S);
End;

{ ---- EmitInstr : instruction indentee TAB mnemo TAB operandes ---- }
Procedure EmitInstr(Const Mnem, Ops : TString);
Begin
  If Not OutFOpen Then Exit;
  If Ops <> '' Then
    WriteLn(OutF, #9, Mnem, #9, Ops)
  Else
    WriteLn(OutF, #9, Mnem);
End;

{ ---- EmitLabel : ecrire une etiquette suivie de ':' ---- }
Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then WriteLn(OutF, Lbl, ':');
End;

{ ---- EmitComment : ecrire un commentaire ---- }
Procedure EmitComment(Const Msg : TString);
Begin
  If OutFOpen Then WriteLn(OutF, '; ', Msg);
End;

{ ---- BinOpPrec : precedence d'un operateur binaire (0 = pas binaire) ----
  Echelle croissante || (1) -> * / % (9). Suit les priorites Rust.    }
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If Op = '||'                                    Then BinOpPrec := 1
  Else If Op = '&&'                               Then BinOpPrec := 2
  Else If (Op = '==') Or (Op = '!=')
       Or (Op = '<')  Or (Op = '>')
       Or (Op = '<=') Or (Op = '>=')              Then BinOpPrec := 3
  Else If Op = '|'                                Then BinOpPrec := 4
  Else If Op = '^'                                Then BinOpPrec := 5
  Else If Op = '&'                                Then BinOpPrec := 6
  Else If (Op = '<<') Or (Op = '>>')             Then BinOpPrec := 7
  Else If (Op = '+')  Or (Op = '-')              Then BinOpPrec := 8
  Else If (Op = '*')  Or (Op = '/') Or (Op = '%') Then BinOpPrec := 9
  Else                                             BinOpPrec := 0;
End;

{ ---- ExprMakeImm : construire un TExprVal immediat ---- }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
End;

{ ---- ExprMakeNone : valeur invalide (erreur ou vide) ---- }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
End;

{ ---- ExprLoad : materialiser la valeur dans AX (emet MOV AX si besoin) ---- }
Procedure ExprLoad(Var E : TExprVal);
Var S : TString;
Begin
  Case E.Kind Of
    EK_IMM  : Begin
                 Str(E.ImmVal, S);
                 EmitInstr('MOV', 'AX, ' + S);
                 E.Kind := EK_AX;
               End;
    EK_MEM  : Begin
                 Str(Abs(E.Offset), S);
                 If E.Offset >= 0 Then
                   EmitInstr('MOV', 'AX, [BP+' + S + ']')
                 Else
                   EmitInstr('MOV', 'AX, [BP-' + S + ']');
                 E.Kind := EK_AX;
               End;
    EK_AX   : ;   { deja dans AX }
    EK_DXAX : ;   { deja dans DX:AX }
    EK_NONE : ;
  End;
End;

{ ---- ExprEmitBinOp : generer le code 8086 pour un operateur binaire ----
  Pliage de constantes si L et R sont EK_IMM.
  Sinon : charge L dans AX et emet l'instruction 8086.                 }
Procedure ExprEmitBinOp(Const Op : TString; Var L : TExprVal; Var R : TExprVal);
Var RS : TString;
Begin
  { Pliage de constantes : les deux immediats }
  If (L.Kind = EK_IMM) And (R.Kind = EK_IMM) Then Begin
    If      Op = '+'  Then L.ImmVal := L.ImmVal + R.ImmVal
    Else If Op = '-'  Then L.ImmVal := L.ImmVal - R.ImmVal
    Else If Op = '*'  Then L.ImmVal := L.ImmVal * R.ImmVal
    Else If Op = '/'  Then Begin
      If R.ImmVal = 0 Then Begin
        WriteLn('RUST86: erreur: division par zero'); Inc(ErrorCount);
      End Else L.ImmVal := L.ImmVal Div R.ImmVal;
    End
    Else If Op = '%'  Then Begin
      If R.ImmVal = 0 Then Begin
        WriteLn('RUST86: erreur: modulo par zero'); Inc(ErrorCount);
      End Else L.ImmVal := L.ImmVal Mod R.ImmVal;
    End
    Else If Op = '&'  Then L.ImmVal := L.ImmVal And R.ImmVal
    Else If Op = '|'  Then L.ImmVal := L.ImmVal Or  R.ImmVal
    Else If Op = '^'  Then L.ImmVal := L.ImmVal Xor R.ImmVal
    Else If Op = '<<' Then L.ImmVal := L.ImmVal Shl R.ImmVal
    Else If Op = '>>' Then L.ImmVal := L.ImmVal Shr R.ImmVal
    Else If Op = '==' Then Begin If L.ImmVal =  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '!=' Then Begin If L.ImmVal <> R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '<'  Then Begin If L.ImmVal <  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '<=' Then Begin If L.ImmVal <= R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '>'  Then Begin If L.ImmVal >  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '>=' Then Begin If L.ImmVal >= R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '&&' Then Begin If (L.ImmVal <> 0) And (R.ImmVal <> 0) Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '||' Then Begin If (L.ImmVal <> 0) Or  (R.ImmVal <> 0) Then L.ImmVal := 1 Else L.ImmVal := 0; End;
    { L reste EK_IMM avec la valeur pliee }
    Exit;
  End;
  { Cas general : L dans AX, R immediat ou via BX }
  ExprLoad(L);
  If R.Kind = EK_IMM Then Begin
    Str(R.ImmVal, RS);
    If      Op = '+'  Then EmitInstr('ADD',  'AX, ' + RS)
    Else If Op = '-'  Then EmitInstr('SUB',  'AX, ' + RS)
    Else If Op = '&'  Then EmitInstr('AND',  'AX, ' + RS)
    Else If Op = '|'  Then EmitInstr('OR',   'AX, ' + RS)
    Else If Op = '^'  Then EmitInstr('XOR',  'AX, ' + RS)
    Else If Op = '<<' Then EmitInstr('SHL',  'AX, ' + RS)
    Else If Op = '>>' Then Begin
      If TypeIsSigned(L.TypeIdx) Then EmitInstr('SAR', 'AX, ' + RS)
                                  Else EmitInstr('SHR', 'AX, ' + RS);
    End
    Else If Op = '*'  Then EmitInstr('IMUL', RS)
    Else If Op = '/'  Then Begin
      EmitInstr('MOV', 'BX, ' + RS);
      EmitInstr('CWD', '');
      EmitInstr('IDIV', 'BX');
    End
    Else If Op = '%'  Then Begin
      EmitInstr('MOV', 'BX, ' + RS);
      EmitInstr('CWD', '');
      EmitInstr('IDIV', 'BX');
      EmitInstr('MOV', 'AX, DX');
    End
    Else If Op = '==' Then Begin EmitInstr('CMP', 'AX, ' + RS); EmitInstr('MOV', 'AX, 0'); EmitInstr('SETE',  'AL'); End
    Else If Op = '!=' Then Begin EmitInstr('CMP', 'AX, ' + RS); EmitInstr('MOV', 'AX, 0'); EmitInstr('SETNE', 'AL'); End
    Else If Op = '<'  Then Begin EmitInstr('CMP', 'AX, ' + RS); EmitInstr('MOV', 'AX, 0'); EmitInstr('SETL',  'AL'); End
    Else If Op = '<=' Then Begin EmitInstr('CMP', 'AX, ' + RS); EmitInstr('MOV', 'AX, 0'); EmitInstr('SETLE', 'AL'); End
    Else If Op = '>'  Then Begin EmitInstr('CMP', 'AX, ' + RS); EmitInstr('MOV', 'AX, 0'); EmitInstr('SETG',  'AL'); End
    Else If Op = '>=' Then Begin EmitInstr('CMP', 'AX, ' + RS); EmitInstr('MOV', 'AX, 0'); EmitInstr('SETGE', 'AL'); End
    Else If Op = '&&' Then EmitInstr('AND', 'AX, ' + RS)
    Else If Op = '||' Then EmitInstr('OR',  'AX, ' + RS);
  End Else Begin
    { R non immediat -> charger dans BX via pile intermediaire }
    EmitInstr('PUSH', 'AX');        { sauvegarder L }
    ExprLoad(R);
    EmitInstr('MOV',  'BX, AX');    { BX = R }
    EmitInstr('POP',  'AX');        { AX = L }
    If      Op = '+'  Then EmitInstr('ADD',  'AX, BX')
    Else If Op = '-'  Then EmitInstr('SUB',  'AX, BX')
    Else If Op = '&'  Then EmitInstr('AND',  'AX, BX')
    Else If Op = '|'  Then EmitInstr('OR',   'AX, BX')
    Else If Op = '^'  Then EmitInstr('XOR',  'AX, BX')
    Else If Op = '*'  Then EmitInstr('IMUL', 'BX')
    Else If Op = '/'  Then Begin EmitInstr('CWD', ''); EmitInstr('IDIV', 'BX'); End
    Else If Op = '%'  Then Begin EmitInstr('CWD', ''); EmitInstr('IDIV', 'BX'); EmitInstr('MOV', 'AX, DX'); End
    Else Begin
      EmitInstr('CMP', 'AX, BX');
      EmitInstr('MOV', 'AX, 0');
      If      Op = '==' Then EmitInstr('SETE',  'AL')
      Else If Op = '!=' Then EmitInstr('SETNE', 'AL')
      Else If Op = '<'  Then EmitInstr('SETL',  'AL')
      Else If Op = '<=' Then EmitInstr('SETLE', 'AL')
      Else If Op = '>'  Then EmitInstr('SETG',  'AL')
      Else If Op = '>=' Then EmitInstr('SETGE', 'AL');
    End;
  End;
  L.Kind := EK_AX;
End;

{ ---- ParserAdvance : consommer le token courant, avancer au suivant ---- }
Procedure ParserAdvance;
Begin
  LexNextToken(CurToken);
End;

{ Declarations anticipees pour la recursion mutuelle }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;

{ ============================================================
  Appels de fonctions et de methodes
  ParseCallArgs, EmitCallSite
  ============================================================ }

{ ---- ParseCallArgs : analyser la liste d'arguments et les empiler ----
  Precondition : CurToken est '(' (l'apostrophe ouvrante).
  Les arguments sont evalues gauche-droite, pousses droite-gauche (cdecl).
  Retourne le nombre d'arguments consommes.                              }
Function ParseCallArgs : Integer;
Var
  Args   : Array[0..MAX_PARAM - 1] Of TExprVal;
  ArgCnt : Integer;
  I      : Integer;
Begin
  ArgCnt := 0;
  ParserAdvance;   { consommer '(' }
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
        (CurToken.Kind <> TK_EOF) Do Begin
    If ArgCnt >= MAX_PARAM Then Begin
      WriteLn('RUST86: erreur ligne ', CurToken.Line,
              ': trop d', #39, 'arguments (max=', MAX_PARAM, ')');
      Inc(ErrorCount);
      Break;
    End;
    ParseExprPrec(1, Args[ArgCnt]);
    Inc(ArgCnt);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;   { consommer la virgule }
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;     { consommer la parenthese fermante }
  { Pousser les arguments de droite a gauche (convention cdecl) }
  For I := ArgCnt - 1 DownTo 0 Do Begin
    ExprLoad(Args[I]);
    EmitInstr('PUSH', 'AX');
  End;
  ParseCallArgs := ArgCnt;
End;

{ ---- EmitCallSite : emettre CALL + nettoyage pile (cdecl) ----
  ManglName  : etiquette 8086 de la fonction.
  ArgCnt     : nombre d'arguments (chacun 2 octets sur 8086).
  RetTypeIdx : type de retour (determine AX / DX:AX / rien).
  Retourne un TExprVal decrivant la valeur de retour.          }
Procedure EmitCallSite(Const ManglName : TString;
                       ArgCnt, RetTypeIdx : Integer; Var Res : TExprVal);
Var NSP : TString;
Begin
  EmitInstr('CALL', ManglName);
  { nettoyage par l'appelant : ADD SP, n*2 }
  If ArgCnt > 0 Then Begin
    Str(ArgCnt * 2, NSP);
    EmitInstr('ADD', 'SP, ' + NSP);
  End;
  Res.ImmVal := 0;
  Res.Offset := 0;
  If RetTypeIdx = TY_IDX_UNIT Then Begin
    Res.Kind    := EK_NONE;
    Res.TypeIdx := TY_IDX_UNIT;
  End Else If TypeSizeof(RetTypeIdx) > 2 Then Begin
    Res.Kind    := EK_DXAX;
    Res.TypeIdx := RetTypeIdx;
  End Else Begin
    Res.Kind    := EK_AX;
    Res.TypeIdx := RetTypeIdx;
  End;
End;

{ ---- DataAdd : forward declare pour usage dans ParsePrimary ---- }
Procedure DataAdd(Const ALbl : TString; AKind : TDataKind;
                  AInt : LongInt; Const AStr : TString;
                  ATy : Integer); Forward;

{ ---- ParseClosureExpr doit etre resolu apres ParseBlock ---- }
Procedure ParseClosureExpr(ParamsClosed : Boolean; Var Res : TExprVal); Forward;

{ ---- ParseMacroCall doit etre resolu apres le corps de ParsePrimary ---- }
Procedure ParseMacroCall(Const MacroName : TString; Var Res : TExprVal); Forward;

{ ---- ParsePrimary : expression primaire (lit., ident., unaire, groupe) ---- }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  E     : TExprVal;
  S     : TString;
  Idx   : Integer;
  Name  : TString;    { identificateur courant                       }
  MethN : TString;    { nom de la methode apres '.'                  }
  MangN : TString;    { nom mangle de la fonction ou methode         }
  RetTy : Integer;    { type de retour de la fonction                }
  ACnt  : Integer;    { nombre d'arguments de l'appel                }
  ELine : Integer;    { ligne pour messages d'erreur                 }
Begin
  ExprMakeNone(E);
  If CurToken.Kind = TK_INTEGER Then Begin
    ExprMakeImm(CurToken.IntVal, TY_IDX_I32, E);
    ParserAdvance;
  End Else If CurToken.Kind = TK_STRING Then Begin
    { chaine litterale : ajouter dans DataTab  et retourner OFFSET }
    S := RS_STR_PFX + SymNewLabel('S');
    DataAdd(S, DK_STR, 0, CurToken.Val, TY_IDX_STR);
    EmitInstr('MOV', 'AX, OFFSET ' + S);
    E.Kind    := EK_AX;
    E.TypeIdx := TY_IDX_STR;
    E.ImmVal  := 0;
    E.Offset  := 0;
    ParserAdvance;
  End Else If CurToken.Kind = TK_CHAR Then Begin
    { caractere litteral : constante immediate }
    ExprMakeImm(CurToken.IntVal, TY_IDX_U8, E);
    ParserAdvance;
  End Else If (CurToken.Kind = TK_KEYWORD) And
              ((CurToken.Val = 'true') Or (CurToken.Val = 'false')) Then Begin
    { booleen : true=1, false=0 }
    If CurToken.Val = 'true' Then
      ExprMakeImm(1, TY_IDX_BOOL, E)
    Else
      ExprMakeImm(0, TY_IDX_BOOL, E);
    ParserAdvance;
  End Else If CurToken.Kind = TK_IDENT Then Begin
    Name  := CurToken.Val;
    ELine := CurToken.Line;
    ParserAdvance;   { avancer : CurToken = token apres l'ident }
    { --- Appel de macro : name!(...) --- }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '!') Then Begin
      ParserAdvance;   { consommer '!' }
      ParseMacroCall(Name, E);
    End Else
    { --- Appel de fonction : name(...) --- }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then Begin
      Idx := SymFindCat(Name, SC_FN);
      If Idx >= 0 Then Begin
        MangN := SymTab[Idx].MangledName;
        RetTy := SymTab[Idx].TypeIdx;
      End Else Begin
        MangN := RS_FN_PFX + Name;
        RetTy := TY_IDX_UNIT;   { type de retour inconnu : suppose unit }
        WriteLn('RUST86: avertissement ligne ', ELine,
                ': fonction non declaree, appel : ', Name);
        Inc(WarnCount);
      End;
      ACnt := ParseCallArgs;   { consomme '(' args... ')' et pousse les args }
      EmitCallSite(MangN, ACnt, RetTy, E);
    End Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '.') Then Begin
      { --- Appel de methode : obj.method(...) --- }
      ParserAdvance;   { consommer '.' }
      If CurToken.Kind <> TK_IDENT Then Begin
        WriteLn('RUST86: erreur ligne ', ELine,
                ': nom de methode attendu apres le point');
        Inc(ErrorCount);
      End Else Begin
        MethN := CurToken.Val;
        ParserAdvance;   { consommer nom_methode }
        { rechercher le type de l'objet pour construire le nom mangle }
        Idx := SymFind(Name);
        If Idx >= 0 Then Begin
          MangN := RS_IMPL_PFX + TypeName(SymTab[Idx].TypeIdx) + '_' + MethN;
          RetTy := TY_IDX_UNIT;   { type de retour affine par le parseur complet }
        End Else Begin
          MangN := RS_IMPL_PFX + Name + '_' + MethN;
          RetTy := TY_IDX_UNIT;
          WriteLn('RUST86: avertissement ligne ', ELine,
                  ': type de ', Name, ' non resolu, appel : ', MethN);
          Inc(WarnCount);
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then Begin
          ACnt := ParseCallArgs;
          EmitCallSite(MangN, ACnt, RetTy, E);
        End Else Begin
          WriteLn('RUST86: erreur ligne ', ELine,
                  ': parenthese attendue apres le nom de methode');
          Inc(ErrorCount);
        End;
      End;
    End Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '::') Then Begin
      { --- Appel statique : Trait::fn(...) --- }
      ParserAdvance;   { consommer '::' }
      If CurToken.Kind <> TK_IDENT Then Begin
        WriteLn('RUST86: erreur ligne ', ELine,
                ': nom de fonction attendu apres :: dans ', Name);
        Inc(ErrorCount);
      End Else Begin
        MethN := CurToken.Val;
        ParserAdvance;   { consommer nom_fn }
        MangN := RS_IMPL_PFX + Name + '_' + MethN;
        RetTy := TY_IDX_UNIT;   { type de retour affine }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then Begin
          ACnt := ParseCallArgs;
          EmitCallSite(MangN, ACnt, RetTy, E);
        End Else Begin
          WriteLn('RUST86: erreur ligne ', ELine,
                  ': parenthese attendue apres Trait::', MethN);
          Inc(ErrorCount);
        End;
      End;
    End Else Begin
      { --- Variable ordinaire --- }
      Idx := SymFind(Name);
      If Idx >= 0 Then Begin
        E.Kind    := EK_MEM;
        E.Offset  := SymTab[Idx].Offset;
        E.TypeIdx := SymTab[Idx].TypeIdx;
        E.ImmVal  := 0;
      End Else Begin
        WriteLn('RUST86: erreur ligne ', ELine,
                ': identifiant inconnu : ', Name);
        Inc(ErrorCount);
      End;
    End;
  End Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then Begin
    ParserAdvance;
    ParseExprPrec(1, E);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance
    Else Begin
      WriteLn('RUST86: erreur ligne ', CurToken.Line,
              ': parenthese fermante attendue');
      Inc(ErrorCount);
    End;
  End Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then Begin
    ParserAdvance;
    ParsePrimary(E);
    If E.Kind = EK_IMM Then
      E.ImmVal := -E.ImmVal
    Else Begin
      ExprLoad(E);
      EmitInstr('NEG', 'AX');
    End;
  End Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '!') Then Begin
    ParserAdvance;
    ParsePrimary(E);
    If E.Kind = EK_IMM Then Begin
      If E.ImmVal = 0 Then E.ImmVal := 1 Else E.ImmVal := 0;
    End Else Begin
      ExprLoad(E);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('MOV',  'AX, 0');
      EmitInstr('SETE', 'AL');
    End;
  End Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '*') Then Begin
    { deref *ptr : operation unsafe uniquement }
    If InUnsafeDepth = 0 Then Begin
      WriteLn('RUST86: erreur ligne ', CurToken.Line,
              ': deref pointeur brut interdit hors unsafe');
      Inc(ErrorCount);
    End;
    ParserAdvance;
    ParsePrimary(E);
    ExprLoad(E);
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('MOV', 'AX, [BX]');
  End Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '&') Then Begin
    { &borrow : adresse de la variable }
    ParserAdvance;
    If CurToken.Kind = TK_IDENT Then Begin
      Idx := SymFind(CurToken.Val);
      If Idx >= 0 Then Begin
        Str(Abs(SymTab[Idx].Offset), S);
        If SymTab[Idx].Offset >= 0 Then
          EmitInstr('LEA', 'AX, [BP+' + S + ']')
        Else
          EmitInstr('LEA', 'AX, [BP-' + S + ']');
        E.Kind    := EK_AX;
        E.TypeIdx := TypeAddRef(SymTab[Idx].TypeIdx, False);
        E.ImmVal  := 0;
        E.Offset  := 0;
      End Else Begin
        WriteLn('RUST86: erreur ligne ', CurToken.Line,
                ': variable inconnue dans &borrow: ', CurToken.Val);
        Inc(ErrorCount);
      End;
      ParserAdvance;
    End;
  End Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '||') Then Begin
    { closure sans parametres : || expr ou || BLOC }
    ParserAdvance;           { consommer '||' }
    ParseClosureExpr(True, E);
  End Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '|') Then Begin
    { closure avec parametres : |p1, p2| expr ou |p1| BLOC }
    ParserAdvance;           { consommer '|' ouvrant }
    ParseClosureExpr(False, E);
  End Else Begin
    If CurToken.Kind <> TK_EOF Then Begin
      WriteLn('RUST86: erreur ligne ', CurToken.Line,
              ': expression attendue, trouve "', CurToken.Val, '"');
      Inc(ErrorCount);
      ParserAdvance;
    End;
  End;
  Res := E;
End;

{ ---- ParseExprPrec : boucle Pratt par precedence croissante ---- }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);  { corps du Forward declre plus haut }
Var
  L    : TExprVal;
  R    : TExprVal;
  Op   : TString;
  Prec : Integer;
Begin
  ParsePrimary(L);
  While CurToken.Kind = TK_OP Do Begin
    Op   := CurToken.Val;
    Prec := BinOpPrec(Op);
    If Prec < MinPrec Then Break;
    ParserAdvance;
    ParseExprPrec(Prec + 1, R);
    ExprEmitBinOp(Op, L, R);
  End;
  Res := L;
End;

{ ---- ParseExpr : point d'entree du parseur d'expressions ---- }
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParserAdvance;           { charger le 1er token dans CurToken }
  ParseExprPrec(1, Res);
End;

{ ============================================================
  LET, AFFECTATION, BLOCS
  ParseTypeName, ParseLetStmt, ParseCompoundAssign,
  ParseStmt (Forward), ParseBlock, ParseStmt corpus
  ============================================================ }

{ ---- ParseTypeName : reconnaitre un nom de type Rust ----
  Consomme le token courant si c'est un type connu.
  Retourne l'index TypeTab ou TY_UNKNOWN si non reconnu.   }
Function ParseTypeName : Integer;
Var N : TString; Idx : Integer; IsMut : Boolean; Inner : Integer;
Begin
  Idx := TY_UNKNOWN;
  { pointeur brut : *const T ou *mut T }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '*') Then Begin
    ParserAdvance;
    IsMut := False;
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'mut') Then Begin
      IsMut := True; ParserAdvance;
    End Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'const') Then
      ParserAdvance;
    Inner := ParseTypeName;
    If Inner = TY_UNKNOWN Then Inner := TY_IDX_I16;
    ParseTypeName := TypeAddPtr(Inner, IsMut);
    Exit;
  End;
  N := CurToken.Val;
  If CurToken.Kind = TK_IDENT Then Begin
    Idx := TypeFind(N);
    If Idx >= 0 Then ParserAdvance
                Else Idx := TY_UNKNOWN;
  End;
  ParseTypeName := Idx;
End;

{ Declarations anticipees pour ParseStmt/ParseBlock/ParseTopLevel }
Procedure ParseStmt; Forward;
Procedure ParseTopLevel; Forward;
Procedure ParseUseDecl; Forward;
Procedure ParseModDecl; Forward;
Procedure ParseUnsafeBlock; Forward;
Procedure ParseExternDecl; Forward;

{ ---- ParseBlock : analyser un bloc stmt* entre accolades ----
  Ouvre une portee, analyse les instructions, ferme la portee.
  La derniere expression sans ';' est la valeur du bloc.     }
Procedure ParseBlock(Var Res : TExprVal);
Var E : TExprVal;
Begin
  ExprMakeNone(E);
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{')) Then Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line, ': accolade ouvrante attendue');
    Inc(ErrorCount);
    Res := E;
    Exit;
  End;
  ParserAdvance;   { consommer l'ouverture d'accolade }
  SymEnterScope;
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}'))
        And (CurToken.Kind <> TK_EOF) Do Begin
    { expression finale sans ';' = valeur du bloc }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then Break;
    ParseStmt;
  End;
  SymLeaveScope;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance   { consommer l'accolade fermante }
  Else Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line, ': accolade fermante attendue');
    Inc(ErrorCount);
  End;
  Res := E;
End;

{ ============================================================
  CLOSURES (FORME SIMPLIFIEE)
  ParseClosureExpr : closure non-capturante emise comme fn anonyme
  Signature : |params| expr   ou   |params| BLOC
  Convention cdecl 8086 : params a [BP+4], [BP+6], ...
  Si la closure accede a une variable hors portee -> warning
  ============================================================ }

{ ---- ParseClosureExpr : corps apres consommation du pipe ouvrant ----
  ParamsClosed = True  -> '||' deja consomme, aucun parametre a lire.
  ParamsClosed = False -> lit les params jusqu'au pipe fermant.        }
Procedure ParseClosureExpr(ParamsClosed : Boolean; Var Res : TExprVal); { corps du Forward }
Var
  LblClo    : TString;
  LblCloEnd : TString;
  E         : TExprVal;
  ParamName : TString;
  ParamOfs  : Integer;
  ParamCnt  : Integer;
  HasMut    : Boolean;
  OfsStr    : TString;
Begin
  LblClo    := SymNewLabel('CLO');
  LblCloEnd := SymNewLabel('CLOEND');

  { le corps de la closure est emis ici-meme ; on saute par-dessus }
  EmitInstr('JMP', LblCloEnd);
  EmitLabel(LblClo);

  { prologue cdecl 8086 }
  EmitInstr('PUSH', 'BP');
  EmitInstr('MOV',  'BP, SP');

  { enregistrer les parametres dans une portee locale }
  SymEnterScope;
  ParamCnt := 0;

  If Not ParamsClosed Then Begin
    { lire les parametres jusqu'au pipe fermant }
    While Not ((CurToken.Kind = TK_OP) And (CurToken.Val = '|'))
          And (CurToken.Kind <> TK_EOF) Do Begin
      HasMut := False;
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'mut') Then Begin
        HasMut := True;
        ParserAdvance;
      End;
      If CurToken.Kind = TK_IDENT Then Begin
        ParamName := CurToken.Val;
        ParserAdvance;
        { type optionnel : name }
        If (CurToken.Kind = TK_OP) And (CurToken.Val = ':') Then Begin
          ParserAdvance;
          ParseTypeName;
        End;
        { offset cdecl : BP+4 premier, BP+6 deuxieme, etc. }
        ParamOfs := 4 + ParamCnt * 2;
        Str(ParamOfs, OfsStr);
        SymAdd(ParamName, SC_PARAM, TY_IDX_I16, HasMut, ParamOfs, 0);
        Inc(ParamCnt);
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
    End;
    { consommer le pipe fermant }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '|') Then
      ParserAdvance;
  End;

  { corps de la closure : BLOC ou expression }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParseBlock(GExprDummy)
  Else Begin
    ParseExprPrec(1, E);
    ExprLoad(E);
  End;

  SymLeaveScope;

  { epilogue cdecl 8086 }
  EmitInstr('POP', 'BP');
  EmitInstr('RET', '');

  { label de saut post-corps }
  EmitLabel(LblCloEnd);

  { retourner l'adresse de la closure dans AX }
  EmitInstr('MOV', 'AX, OFFSET ' + LblClo);
  E.Kind    := EK_AX;
  E.TypeIdx := TY_IDX_UNIT;
  E.ImmVal  := 0;
  E.Offset  := 0;
  Res := E;
End;

{ ---- ParseLetStmt : analyser let [mut] name [: Type] [= expr]; ----
  Alloue l'espace sur la pile (SUB SP, taille) et enregistre le symbole. }
Procedure ParseLetStmt;
Var
  IsMut   : Boolean;
  VarName : TString;
  TyIdx   : Integer;
  VarSize : Integer;
  OfsStr  : TString;
  E       : TExprVal;
Begin
  { consommer 'let' (deja consomme par ParseStmt) }
  IsMut := False;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'mut') Then Begin
    IsMut := True;
    ParserAdvance;
  End;
  If CurToken.Kind <> TK_IDENT Then Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line, ': nom de variable attendu apres let');
    Inc(ErrorCount);
    Exit;
  End;
  VarName := CurToken.Val;
  ParserAdvance;
  { type optionnel : Type }
  TyIdx := TY_IDX_I16;   { type par defaut i16 }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':') Then Begin
    ParserAdvance;
    TyIdx := ParseTypeName;
    If TyIdx = TY_UNKNOWN Then Begin
      WriteLn('RUST86: avertissement: type inconnu pour ', VarName, ', i16 assume');
      Inc(WarnCount);
      TyIdx := TY_IDX_I16;
    End;
  End;
  { allouer sur la pile : taille minimale = 2 octets (word 8086) }
  VarSize := TypeSizeof(TyIdx);
  If VarSize < 2 Then VarSize := 2;
  Dec(CurFrameSize, VarSize);
  Str(VarSize, OfsStr);
  EmitComment('let ' + VarName + ' : ' + TypeName(TyIdx));
  EmitInstr('SUB', 'SP, ' + OfsStr);
  { enregistrer dans SymTab avec offset BP-relatif (negatif) }
  SymAdd(VarName, SC_VAR, TyIdx, IsMut, CurFrameSize, CurToken.Line);
  { initialiseur optionnel = expr }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then Begin
    ParserAdvance;
    ParseExprPrec(1, E);
    ExprLoad(E);
    Str(Abs(CurFrameSize), OfsStr);
    EmitInstr('MOV', '[BP-' + OfsStr + '], AX');
  End;
  { point-virgule }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance
  Else Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line, ': point-virgule attendu apres let');
    Inc(ErrorCount);
  End;
End;

{ ---- ParseCompoundAssign : generer l'instruction composee (+=, -=...) ----
  AName = nom de la variable cible, Op = operateur binaire de base.    }
Procedure ParseCompoundAssign(Const AName, Op : TString);
Var
  Idx    : Integer;
  E      : TExprVal;
  OfsStr : TString;
  L      : TExprVal;
Begin
  Idx := SymFind(AName);
  If Idx < 0 Then Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line, ': variable inconnue : ', AName);
    Inc(ErrorCount);
    Exit;
  End;
  If Not SymTab[Idx].IsMut Then Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': tentative d', #39, 'affectation d', #39, 'une variable non-mut : ', AName);
    Inc(ErrorCount);
  End;
  { charger la valeur courante dans L }
  L.Kind    := EK_MEM;
  L.Offset  := SymTab[Idx].Offset;
  L.TypeIdx := SymTab[Idx].TypeIdx;
  L.ImmVal  := 0;
  { evaluer le membre droit }
  ParseExprPrec(1, E);
  ExprEmitBinOp(Op, L, E);   { resultat dans AX }
  Str(Abs(SymTab[Idx].Offset), OfsStr);
  If SymTab[Idx].Offset >= 0 Then
    EmitInstr('MOV', '[BP+' + OfsStr + '], AX')
  Else
    EmitInstr('MOV', '[BP-' + OfsStr + '], AX');
End;

{ ============================================================
  IF / ELSE / IF LET
  ParseIfStmt : generer les sauts conditionnels 8086
  Labels : _RSL_ELSE_N et _RSL_ENDIF_N via SymNewLabel
  ============================================================ }

{ ---- ParseIfStmt : analyser  if cond BLOC [else BLOC|if]  ----
  Supporte egalement if let IDENT = expr BLOC (liaison simple). }
Procedure ParseIfStmt;
Var
  LblElse   : TString;
  LblEndif  : TString;
  Cond      : TExprVal;
  HasElse   : Boolean;
  PatName   : TString;
  HasPat    : Boolean;
  PatVarOfs : Integer;
  VarSize   : Integer;
  OfsStr    : TString;
Begin
  { 'if' deja consomme par l'appelant }
  HasPat    := False;
  PatName   := '';
  PatVarOfs := 0;

  { --- if let Pattern = expr --- }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'let') Then Begin
    ParserAdvance;   { consommer 'let' }
    HasPat := True;
    If CurToken.Kind = TK_IDENT Then Begin
      PatName := CurToken.Val;
      ParserAdvance;
    End Else Begin
      WriteLn('RUST86: avertissement ligne ', CurToken.Line,
              ': motif complexe dans if let, simplifie');
      Inc(WarnCount);
    End;
    { consommer '=' }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      ParserAdvance
    Else Begin
      WriteLn('RUST86: erreur ligne ', CurToken.Line,
              ': ''='' attendu dans if let');
      Inc(ErrorCount);
    End;
  End;

  { evaluer la condition (ou valeur de if let) dans AX }
  ParseExprPrec(1, Cond);
  ExprLoad(Cond);

  { generer les labels locaux uniques }
  LblElse  := SymNewLabel('ELSE');
  LblEndif := SymNewLabel('ENDIF');

  { TEST AX, AX puis saut conditionnel vers branche else }
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JZ', LblElse);

  { si if let avec variable, allouer et lier AX au nom }
  If HasPat And (PatName <> '_') And (PatName <> '') Then Begin
    VarSize := 2;   { i16 par defaut }
    Dec(CurFrameSize, VarSize);
    PatVarOfs := CurFrameSize;
    EmitInstr('SUB', 'SP, 2');
    SymAdd(PatName, SC_VAR, TY_IDX_I16, False, PatVarOfs, CurToken.Line);
    Str(Abs(PatVarOfs), OfsStr);
    EmitInstr('MOV', '[BP-' + OfsStr + '], AX');
  End;

  { branche then }
  ParseBlock(GExprDummy);

  HasElse := (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else');
  If HasElse Then
    EmitInstr('JMP', LblEndif);

  { etiquette else (atterrissage du JZ) }
  EmitLabel(LblElse);

  If HasElse Then Begin
    ParserAdvance;   { consommer 'else' }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'if') Then Begin
      ParserAdvance;   { consommer 'if' }
      ParseIfStmt;     { else if : appel recursif }
    End Else
      ParseBlock(GExprDummy);
    EmitLabel(LblEndif);
  End;
End;

{ ============================================================
  BOUCLES : loop, while, for..in, break, continue
  LoopPush/LoopPop, ParseLoopStmt, ParseWhileStmt, ParseForInStmt
  ============================================================ }

Procedure LoopPush(Const BrkLbl, ContLbl : TString);
Begin
  If LoopTop >= MAX_LOOP_NEST - 1 Then Begin
    WriteLn('RUST86: FATAL - boucles trop imbriquees (max=', MAX_LOOP_NEST, ')');
    Halt(EXIT_ERROR);
  End;
  Inc(LoopTop);
  LoopBreakLbl[LoopTop] := BrkLbl;
  LoopContLbl[LoopTop]  := ContLbl;
End;

Procedure LoopPop;
Begin
  If LoopTop > 0 Then Dec(LoopTop);
End;

{ ---- ParseLoopStmt : loop BLOC ---- }
Procedure ParseLoopStmt;
Var
  LblLoop  : TString;
  LblBreak : TString;
Begin
  LblLoop  := SymNewLabel('LOOP');
  LblBreak := SymNewLabel('BREAK');
  LoopPush(LblBreak, LblLoop);
  EmitLabel(LblLoop);
  ParseBlock(GExprDummy);
  EmitInstr('JMP', LblLoop);
  EmitLabel(LblBreak);
  LoopPop;
End;

{ ---- ParseWhileStmt : while cond BLOC ---- }
Procedure ParseWhileStmt;
Var
  LblLoop  : TString;
  LblBreak : TString;
  Cond     : TExprVal;
Begin
  LblLoop  := SymNewLabel('LOOP');
  LblBreak := SymNewLabel('BREAK');
  LoopPush(LblBreak, LblLoop);
  EmitLabel(LblLoop);
  ParseExprPrec(1, Cond);
  ExprLoad(Cond);
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JZ', LblBreak);
  ParseBlock(GExprDummy);
  EmitInstr('JMP', LblLoop);
  EmitLabel(LblBreak);
  LoopPop;
End;

{ ---- ParseForInStmt : for var in Start..End BLOC ----
  Gere les intervalles a..b (exclusif) et a..=b (inclusif).
  Variable de boucle allouee sur la pile (i16 par defaut).   }
Procedure ParseForInStmt;
Var
  VarName   : TString;
  LblLoop   : TString;
  LblBreak  : TString;
  StartE    : TExprVal;
  EndE      : TExprVal;
  OfsStr    : TString;
  VarOfs    : Integer;
  Inclusive : Boolean;
Begin
  LblLoop  := SymNewLabel('LOOP');
  LblBreak := SymNewLabel('BREAK');
  { lire le nom de la variable de boucle }
  If CurToken.Kind <> TK_IDENT Then Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line, ': variable attendue dans for..in');
    Inc(ErrorCount);
    Exit;
  End;
  VarName := CurToken.Val;
  ParserAdvance;
  { consommer 'in' }
  If Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'in')) Then Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': mot-cle ''in'' attendu dans for');
    Inc(ErrorCount);
    Exit;
  End;
  ParserAdvance;
  { evaluer la borne de debut -- ParseExprPrec s'arrete avant '..' }
  ParseExprPrec(1, StartE);
  { consommer '..' ou '..=' }
  Inclusive := False;
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '..=') Then Begin
    Inclusive := True;
    ParserAdvance;
  End Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '..') Then
    ParserAdvance
  Else Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': ''..'' ou ''..='' attendu dans for..in');
    Inc(ErrorCount);
  End;
  { evaluer la borne de fin -- s'arrete sur l'accolade ouvrante }
  ParseExprPrec(1, EndE);
  { allouer la variable de boucle sur la pile }
  Dec(CurFrameSize, 2);
  VarOfs := CurFrameSize;
  Str(Abs(VarOfs), OfsStr);
  EmitInstr('SUB', 'SP, 2');
  SymEnterScope;
  SymAdd(VarName, SC_VAR, TY_IDX_I16, True, VarOfs, 0);
  EmitComment('init var boucle ' + VarName);
  ExprLoad(StartE);
  EmitInstr('MOV', '[BP-' + OfsStr + '], AX');
  LoopPush(LblBreak, LblLoop);
  { tete de boucle : tester borne }
  EmitLabel(LblLoop);
  EmitComment('test borne ' + VarName);
  ExprLoad(EndE);
  EmitInstr('MOV', 'BX, AX');
  Str(Abs(VarOfs), OfsStr);
  EmitInstr('MOV', 'AX, [BP-' + OfsStr + ']');
  EmitInstr('CMP', 'AX, BX');
  If Inclusive Then
    EmitInstr('JG',  LblBreak)
  Else
    EmitInstr('JGE', LblBreak);
  { corps de boucle }
  ParseBlock(GExprDummy);
  { incrementer la variable }
  Str(Abs(VarOfs), OfsStr);
  EmitInstr('INC', 'WORD PTR [BP-' + OfsStr + ']');
  EmitInstr('JMP', LblLoop);
  EmitLabel(LblBreak);
  LoopPop;
  SymLeaveScope;
End;

{ ============================================================
  MATCH / FILTRAGE PAR MOTIF
  match expr BraceOpen bras* BraceClose
  Motifs : litteral entier, _ (joker), ident (liaison)
  Garde : if cond apres le motif avant =>
  Generation : CMP BX, lit + JNE bras_suivant + JMP fin_match
  ============================================================ }

Procedure ParseMatchStmt;
Var
  LblEnd   : TString;
  LblNext  : TString;
  Subject  : TExprVal;
  Guard    : TExprVal;
  Pat      : TString;
  PatIsNum : Boolean;
  PatVal   : LongInt;
  OfsStr   : TString;
  IsNeg    : Boolean;
  VarOfs   : Integer;
  InScope  : Boolean;
Begin
  { 'match' deja consomme par l'appelant }
  LblEnd := SymNewLabel('MEND');

  { evaluer le sujet dans AX, sauvegarder dans BX }
  ParseExprPrec(1, Subject);
  ExprLoad(Subject);
  EmitInstr('MOV', 'BX, AX');

  { accolade ouvrante du bloc match }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance
  Else Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': accolade ouvrante attendue apres match expr');
    Inc(ErrorCount);
    Exit;
  End;

  { boucle sur les bras : motif [if garde] => corps [,] }
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}'))
        And (CurToken.Kind <> TK_EOF) Do Begin

    LblNext  := SymNewLabel('MARM');
    Pat      := '';
    PatIsNum := False;
    PatVal   := 0;
    IsNeg    := False;
    InScope  := False;

    { motif negatif facultatif }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then Begin
      IsNeg := True;
      ParserAdvance;
    End;

    { motif : entier, _ ou ident }
    If CurToken.Kind = TK_INTEGER Then Begin
      PatIsNum := True;
      PatVal   := CurToken.IntVal;
      If IsNeg Then PatVal := -PatVal;
      ParserAdvance;
    End Else If CurToken.Kind = TK_IDENT Then Begin
      Pat := CurToken.Val;
      ParserAdvance;
    End Else Begin
      WriteLn('RUST86: erreur ligne ', CurToken.Line,
              ': motif inattendu dans match');
      Inc(ErrorCount);
      Exit;
    End;

    { comparer BX avec le motif entier -> sauter si different }
    If PatIsNum Then Begin
      Str(PatVal, OfsStr);
      EmitInstr('CMP', 'BX, ' + OfsStr);
      EmitInstr('JNE', LblNext);
    End Else If Pat <> '_' Then Begin
      { liaison variable : allouer sur la pile et charger BX }
      SymEnterScope;
      InScope := True;
      Dec(CurFrameSize, 2);
      VarOfs := CurFrameSize;
      Str(Abs(VarOfs), OfsStr);
      EmitInstr('SUB', 'SP, 2');
      SymAdd(Pat, SC_VAR, TY_IDX_I16, False, VarOfs, CurToken.Line);
      EmitInstr('MOV', '[BP-' + OfsStr + '], BX');
    End;
    { _ joker : pas de comparaison }

    { garde optionnelle : if cond }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'if') Then Begin
      ParserAdvance;
      ParseExprPrec(1, Guard);
      ExprLoad(Guard);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JZ', LblNext);
    End;

    { consommer '=>' }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=>') Then
      ParserAdvance
    Else Begin
      WriteLn('RUST86: erreur ligne ', CurToken.Line,
              ': ''=>'' attendu dans bras match');
      Inc(ErrorCount);
    End;

    { corps du bras : bloc ou expression }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
      ParseBlock(GExprDummy)
    Else Begin
      ParseExprPrec(1, Subject);
      ExprLoad(Subject);
    End;

    { liberer la portee de liaison si necessaire }
    If InScope Then SymLeaveScope;

    { sauter a la fin du match puis etiquette du bras suivant }
    EmitInstr('JMP', LblEnd);
    EmitLabel(LblNext);

    { virgule optionnelle entre bras }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
  End;

  { accolade fermante du match }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance
  Else Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': accolade fermante attendue en fin de match');
    Inc(ErrorCount);
  End;

  EmitLabel(LblEnd);
End;

{ ============================================================
  SEGMENT DE DONNEES : STATICS ET CONSTS
  TDataRec/DataTab, DataAdd, EmitDataSeg
  ParseStaticDecl, ParseConstDecl
  Gestion des chaines litterales TK_STRING dans ParsePrimary
  ============================================================ }

{ ---- DataAdd : enregistrer une entree dans DataTab ---- }
Procedure DataAdd(Const ALbl : TString; AKind : TDataKind;
                  AInt : LongInt; Const AStr : TString; ATy : Integer);
Begin
  If DataCount >= MAX_DATA Then Begin
    WriteLn('RUST86: FATAL DataTab pleine (MAX_DATA=', MAX_DATA, ')');
    Halt(EXIT_ERROR);
  End;
  DataTab[DataCount].LblName := ALbl;
  DataTab[DataCount].Kind    := AKind;
  DataTab[DataCount].IntVal  := AInt;
  DataTab[DataCount].StrVal  := AStr;
  DataTab[DataCount].TypeIdx := ATy;
  Inc(DataCount);
End;

{ ============================================================
  GENERATION FINALE ET FICHIER .ASM
  EmitHeader : en-tete MASM (MODEL SMALL, STACK, _TEXT SEGMENT)
  EmitFooter : fermer _TEXT, emettre _DATA, emettre END
  Rewrite Run : pipeline complet source -> .ASM
  ============================================================ }

{ ---- EmitHeader : emettre l'en-tete MASM du fichier .ASM ---- }
Procedure EmitHeader;
Var NS : TString;
Begin
  If Not OutFOpen Then Exit;
  WriteLn(OutF, '; Generated by RUST86 v', RUST86_VERSION, ' (', RUST86_DATE, ')');
  Str(STACK_SIZE, NS);
  WriteLn(OutF, '; Cible : 8086 DOS (.MODEL SMALL)');
  WriteLn(OutF, '; Pile  : ', NS, ' octets');
  WriteLn(OutF);
  WriteLn(OutF, '        .MODEL  SMALL');
  WriteLn(OutF, '        .STACK  ', NS);
  WriteLn(OutF);
  WriteLn(OutF, '_TEXT   SEGMENT PUBLIC ''CODE''');
  WriteLn(OutF, '        ASSUME  CS:_TEXT');
  WriteLn(OutF);
End;

{ ---- EmitDataSeg : emettre toutes les entrees DataTab dans le fichier ASM ----
  Appele apres emission du code (section TEXT) pour clore le segment.          }
Procedure EmitDataSeg;
Var
  I   : Integer;
  J   : Integer;
  B   : Byte;
  S   : TString;
  NS  : TString;
Begin
  If Not OutFOpen Then Exit;
  If DataCount = 0 Then Exit;
  WriteLn(OutF);
  WriteLn(OutF, '_DATA   SEGMENT PUBLIC ''DATA''');
  WriteLn(OutF, '        ASSUME  DS:_DATA');
  For I := 0 To DataCount - 1 Do Begin
    Case DataTab[I].Kind Of
      DK_WORD : Begin
        Str(DataTab[I].IntVal, NS);
        WriteLn(OutF, DataTab[I].LblName, ':');
        WriteLn(OutF, '        DW      ', NS);
      End;
      DK_BYTE : Begin
        Str(DataTab[I].IntVal, NS);
        WriteLn(OutF, DataTab[I].LblName, ':');
        WriteLn(OutF, '        DB      ', NS);
      End;
      DK_STR : Begin
        S := DataTab[I].StrVal;
        WriteLn(OutF, DataTab[I].LblName, ':');
        Write(OutF,   '        DB      ');
        For J := 1 To Length(S) Do Begin
          B := Ord(S[J]);
          Str(B, NS);
          If J > 1 Then Write(OutF, ',');
          Write(OutF, NS);
        End;
        WriteLn(OutF, ',0');
      End;
    End;
  End;
  WriteLn(OutF, '_DATA   ENDS');
End;

{ ---- ParseStaticDecl : static [mut] NAME : Type = expr; ---- }
Procedure ParseStaticDecl;
Var
  IsMut   : Boolean;
  VarName : TString;
  TyIdx   : Integer;
  MangN   : TString;
  E       : TExprVal;
Begin
  IsMut := False;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'mut') Then Begin
    IsMut := True;
    ParserAdvance;
  End;
  If CurToken.Kind <> TK_IDENT Then Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': nom attendu apres static');
    Inc(ErrorCount); Exit;
  End;
  VarName := CurToken.Val;
  ParserAdvance;
  TyIdx := TY_IDX_I16;
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':') Then Begin
    ParserAdvance;
    TyIdx := ParseTypeName;
    If TyIdx = TY_UNKNOWN Then TyIdx := TY_IDX_I16;
  End;
  MangN := RS_VAR_PFX + VarName;
  SymAdd(VarName, SC_STATIC, TyIdx, IsMut, 0, CurToken.Line);
  SymTab[SymCount-1].MangledName := MangN;
  { initialiseur optionnel }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then Begin
    ParserAdvance;
    ParseExprPrec(1, E);
    If E.Kind = EK_IMM Then Begin
      If TypeSizeof(TyIdx) <= 1 Then
        DataAdd(MangN, DK_BYTE, E.ImmVal, '', TyIdx)
      Else
        DataAdd(MangN, DK_WORD, E.ImmVal, '', TyIdx);
    End Else Begin
      WriteLn('RUST86: avertissement ligne ', CurToken.Line,
              ': initialiseur static non constant, 0 suppose pour ', VarName);
      Inc(WarnCount);
      DataAdd(MangN, DK_WORD, 0, '', TyIdx);
    End;
  End Else
    DataAdd(MangN, DK_WORD, 0, '', TyIdx);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ---- ParseConstDecl : const NAME : Type = expr; ---- }
Procedure ParseConstDecl;
Var
  VarName : TString;
  TyIdx   : Integer;
  MangN   : TString;
  E       : TExprVal;
Begin
  If CurToken.Kind <> TK_IDENT Then Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': nom attendu apres const');
    Inc(ErrorCount); Exit;
  End;
  VarName := CurToken.Val;
  ParserAdvance;
  TyIdx := TY_IDX_I16;
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':') Then Begin
    ParserAdvance;
    TyIdx := ParseTypeName;
    If TyIdx = TY_UNKNOWN Then TyIdx := TY_IDX_I16;
  End;
  If Not ((CurToken.Kind = TK_OP) And (CurToken.Val = '=')) Then Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': ''='' attendu dans const');
    Inc(ErrorCount); Exit;
  End;
  ParserAdvance;
  ParseExprPrec(1, E);
  MangN := RS_VAR_PFX + VarName;
  SymAdd(VarName, SC_CONST, TyIdx, False, 0, CurToken.Line);
  SymTab[SymCount-1].MangledName := MangN;
  If E.Kind = EK_IMM Then Begin
    If TypeSizeof(TyIdx) <= 1 Then
      DataAdd(MangN, DK_BYTE, E.ImmVal, '', TyIdx)
    Else
      DataAdd(MangN, DK_WORD, E.ImmVal, '', TyIdx);
  End Else Begin
    WriteLn('RUST86: avertissement ligne ', CurToken.Line,
            ': const non pliable, 0 suppose pour ', VarName);
    Inc(WarnCount);
    DataAdd(MangN, DK_WORD, 0, '', TyIdx);
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ============================================================
  GESTION MEMOIRE : PILE ET CADRE DE PILE
  ParseReturnStmt, ParseFnDecl, ParseTopLevel
  Prologue : PUSH BP / MOV BP,SP
  Locaux   : chaque let emet SUB SP, n (incremental)
  Epilogue : MOV SP,BP / POP BP / RET
  N total  : -CurFrameSize apres le corps
  ============================================================ }

{ ---- ParseReturnStmt : return [expr]; ---- }
Procedure ParseReturnStmt;
Var E : TExprVal;
Begin
  { 'return' deja consomme }
  If Not ((CurToken.Kind = TK_PUNCT) And
         ((CurToken.Val = ';') Or (CurToken.Val = '}'))) Then Begin
    ParseExprPrec(1, E);
    ExprLoad(E);
  End;
  EmitInstr('MOV', 'SP, BP');
  EmitInstr('POP', 'BP');
  EmitInstr('RET', '');
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ---- ParseFnDecl : analyser fn name(params) [-> RetType] BLOC ----
  Enregistre la fonction dans SymTab, emet le code 8086 complet.   }
Procedure ParseFnDecl(IsPub : Boolean);
Var
  FnName   : TString;
  MangName : TString;
  RetTy    : Integer;
  ParamCnt : Integer;
  ParamN   : TString;
  ParamTy  : Integer;
  ParamOfs : Integer;
  SaveFrm  : Integer;
  FrameN   : Integer;
  NSP      : TString;
Begin
  { 'fn' deja consomme }
  If CurToken.Kind <> TK_IDENT Then Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': nom de fonction attendu apres fn');
    Inc(ErrorCount);
    Exit;
  End;
  FnName := CurToken.Val;
  ParserAdvance;
  SymAdd(FnName, SC_FN, TY_IDX_I16, IsPub, 0, CurToken.Line);
  MangName := SymTab[SymCount-1].MangledName;  { calcule par SymAdd via SymMangle }
  { consommer '(' }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': parenthese attendue apres le nom de fn');
    Inc(ErrorCount);
    Exit;
  End;
  ParserAdvance;
  SaveFrm  := CurFrameSize;
  CurFrameSize := 0;
  SymEnterScope;
  ParamCnt := 0;
  { lire les parametres }
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
        (CurToken.Kind <> TK_EOF) Do Begin
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'self') Then Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then ParserAdvance;
      Continue;
    End;
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'mut') Then
      ParserAdvance;
    If CurToken.Kind <> TK_IDENT Then Begin
      WriteLn('RUST86: erreur ligne ', CurToken.Line, ': parametre attendu');
      Inc(ErrorCount); Break;
    End;
    ParamN := CurToken.Val;
    ParserAdvance;
    ParamTy := TY_IDX_I16;
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':') Then Begin
      ParserAdvance;
      ParamTy := ParseTypeName;
      If ParamTy = TY_UNKNOWN Then ParamTy := TY_IDX_I16;
    End;
    ParamOfs := 4 + ParamCnt * 2;
    SymAdd(ParamN, SC_PARAM, ParamTy, False, ParamOfs, CurToken.Line);
    Inc(ParamCnt);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then ParserAdvance;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
  { type de retour optionnel }
  RetTy := TY_IDX_UNIT;
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '->') Then Begin
    ParserAdvance;
    RetTy := ParseTypeName;
    If RetTy = TY_UNKNOWN Then RetTy := TY_IDX_UNIT;
  End;
  { prologue 8086 }
  Str(ParamCnt, NSP);
  EmitComment('fn ' + FnName + '  params=' + NSP);
  If IsPub Then EmitRaw('        PUBLIC  ' + MangName);
  EmitLabel(MangName);
  EmitInstr('PUSH', 'BP');
  EmitInstr('MOV',  'BP, SP');
  { corps : locaux emis incrementalement par ParseLetStmt }
  ParseBlock(GExprDummy);
  { epilogue implicite }
  FrameN := -CurFrameSize;
  Str(FrameN,  NSP);
  EmitComment('frame size = ' + NSP + ' bytes');
  EmitInstr('MOV', 'SP, BP');
  EmitInstr('POP', 'BP');
  EmitInstr('RET', '');
  SymLeaveScope;
  CurFrameSize := SaveFrm;
End;

{ ============================================================
  MODULES ET USE
  ParseUseDecl : use chemin::nom [as alias];
  ParseModDecl : mod nom BLOC avec imbrication de CurModPath
  SymMangle(SC_FN) integre CurModPath -> _MOD_path_fn
  ============================================================ }

{ ---- ParseUseDecl : use chemin::nom [as alias]; ---- }
Procedure ParseUseDecl;
Var
  Path  : TString;
  Alias : TString;
  MangN : TString;
  Idx   : Integer;
Begin
  { 'use' deja consomme }
  Path := '';
  If CurToken.Kind <> TK_IDENT Then Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': identifiant attendu apres use');
    Inc(ErrorCount); Exit;
  End;
  Path := CurToken.Val; ParserAdvance;
  { lire la suite du chemin : :: ident* }
  While (CurToken.Kind = TK_OP) And (CurToken.Val = '::') Do Begin
    ParserAdvance;
    If CurToken.Kind = TK_IDENT Then Begin
      Path := Path + '::' + CurToken.Val; ParserAdvance;
    End Else Break;
  End;
  { optionnel : as alias }
  Alias := '';
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'as') Then Begin
    ParserAdvance;
    If CurToken.Kind = TK_IDENT Then Begin
      Alias := CurToken.Val; ParserAdvance;
    End;
  End;
  { deduire alias depuis la derniere partie du chemin }
  If Alias = '' Then Begin
    Alias := Path;
    Idx := Length(Alias);
    While (Idx > 0) And (Alias[Idx] <> ':') Do Dec(Idx);
    If Idx > 0 Then Alias := Copy(Alias, Idx+1, 255);
  End;
  { enregistrer l'alias dans la table des symboles }
  MangN := SymMangle(SC_FN, Path);
  SymAdd(Alias, SC_TYPEDEF, TY_IDX_I16, False, 0, CurToken.Line);
  If SymCount > 0 Then
    SymTab[SymCount-1].MangledName := MangN;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
  If Opts.Verbose Then
    WriteLn('use ', Path, ' as ', Alias, ' -> ', MangN);
End;

{ ---- ParseModDecl : mod nom BLOC declarations ---- }
Procedure ParseModDecl;
Var
  Name    : TString;
  OldPath : TString;
Begin
  { 'mod' deja consomme }
  If CurToken.Kind <> TK_IDENT Then Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': nom de module attendu apres mod');
    Inc(ErrorCount); Exit;
  End;
  Name := CurToken.Val; ParserAdvance;
  OldPath := CurModPath;
  If CurModPath = '' Then CurModPath := Name
  Else CurModPath := CurModPath + '::' + Name;
  Inc(ModDepth);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then Begin
    ParserAdvance;  { consommer l'accolade d'ouverture }
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}'))
          And (CurToken.Kind <> TK_EOF) Do Begin
      ParseTopLevel;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
      ParserAdvance;
  End Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then Begin
    { mod externe : mod name; -- ignorer corps }
    ParserAdvance;
  End;
  Dec(ModDepth);
  CurModPath := OldPath;
  If Opts.Verbose Then
    WriteLn('mod ', Name, ' OK (depth=', ModDepth+1, ')');
End;

{ ============================================================
  RUNTIME MINIMAL ET PANIC
  EmitRuntime : emettre les 5 routines runtime 8086 dans OutF
  ParseMacroCall : panic! unreachable! debug_assert! print! println!
  RuntimeEmitted flag pour eviter double emission
  ============================================================ }

{ ---- EmitRuntime : emettre les routines runtime en ASM 8086 ---- }
Procedure EmitRuntime;
Begin
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;
  If Not OutFOpen Then Exit;
  EmitRaw('');
  EmitRaw('; -------- RUST86 Runtime --------');
  { === _RSRT_PANIC : SI = message zero-terminated, ecrit stderr + quitte === }
  EmitLabel('_RSRT_PANIC');
  EmitInstr('PUSH', 'BX');
  EmitInstr('PUSH', 'CX');
  EmitInstr('PUSH', 'DX');
  EmitInstr('MOV',  'BX, 2');
  EmitInstr('MOV',  'DX, SI');
  EmitInstr('MOV',  'AX, SI');
  EmitInstr('XOR',  'CX, CX');
  EmitLabel('_RSRT_PANIC_L');
  EmitRaw('        CMP     BYTE PTR [AX], 0');
  EmitInstr('JE',   '_RSRT_PANIC_D');
  EmitInstr('INC',  'AX');
  EmitInstr('INC',  'CX');
  EmitInstr('JMP',  '_RSRT_PANIC_L');
  EmitLabel('_RSRT_PANIC_D');
  EmitInstr('MOV',  'AH, 40h');
  EmitInstr('INT',  '21h');
  EmitInstr('POP',  'DX');
  EmitInstr('POP',  'CX');
  EmitInstr('POP',  'BX');
  EmitInstr('MOV',  'AX, 4C01h');
  EmitInstr('INT',  '21h');
  { === _RSRT_PRINT : SI = message zero-terminated, ecrit stdout === }
  EmitLabel('_RSRT_PRINT');
  EmitInstr('PUSH', 'BX');
  EmitInstr('PUSH', 'CX');
  EmitInstr('PUSH', 'DX');
  EmitInstr('MOV',  'BX, 1');
  EmitInstr('MOV',  'DX, SI');
  EmitInstr('MOV',  'AX, SI');
  EmitInstr('XOR',  'CX, CX');
  EmitLabel('_RSRT_PRINT_L');
  EmitRaw('        CMP     BYTE PTR [AX], 0');
  EmitInstr('JE',   '_RSRT_PRINT_D');
  EmitInstr('INC',  'AX');
  EmitInstr('INC',  'CX');
  EmitInstr('JMP',  '_RSRT_PRINT_L');
  EmitLabel('_RSRT_PRINT_D');
  EmitInstr('MOV',  'AH, 40h');
  EmitInstr('INT',  '21h');
  EmitInstr('POP',  'DX');
  EmitInstr('POP',  'CX');
  EmitInstr('POP',  'BX');
  EmitInstr('RET',  '');
  { === _RSRT_MEMSET : DI = dest, AL = valeur, CX = nb octets === }
  EmitLabel('_RSRT_MEMSET');
  EmitInstr('PUSH', 'CX');
  EmitInstr('PUSH', 'DI');
  EmitLabel('_RSRT_MEMSET_L');
  EmitRaw('        MOV     [DI], AL');
  EmitInstr('INC',  'DI');
  EmitInstr('LOOP', '_RSRT_MEMSET_L');
  EmitInstr('POP',  'DI');
  EmitInstr('POP',  'CX');
  EmitInstr('RET',  '');
  { === _RSRT_MEMCPY : DI = dest, SI = src, CX = nb octets === }
  EmitLabel('_RSRT_MEMCPY');
  EmitInstr('PUSH', 'CX');
  EmitInstr('PUSH', 'SI');
  EmitInstr('PUSH', 'DI');
  EmitLabel('_RSRT_MEMCPY_L');
  EmitRaw('        MOV     AL, [SI]');
  EmitRaw('        MOV     [DI], AL');
  EmitInstr('INC',  'SI');
  EmitInstr('INC',  'DI');
  EmitInstr('LOOP', '_RSRT_MEMCPY_L');
  EmitInstr('POP',  'DI');
  EmitInstr('POP',  'SI');
  EmitInstr('POP',  'CX');
  EmitInstr('RET',  '');
  { === _RSRT_ITOA : AX = entier signe, DI = buffer sortie === }
  EmitLabel('_RSRT_ITOA');
  EmitInstr('PUSH', 'BX');
  EmitInstr('PUSH', 'CX');
  EmitInstr('PUSH', 'DX');
  EmitInstr('PUSH', 'DI');
  EmitInstr('XOR',  'CX, CX');
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JGE',  '_RSRT_ITOA_POS');
  EmitRaw('        MOV     BYTE PTR [DI], 2Dh');
  EmitInstr('INC',  'DI');
  EmitInstr('NEG',  'AX');
  EmitLabel('_RSRT_ITOA_POS');
  EmitInstr('MOV',  'BX, 10');
  EmitLabel('_RSRT_ITOA_DIV');
  EmitInstr('XOR',  'DX, DX');
  EmitInstr('DIV',  'BX');
  EmitInstr('PUSH', 'DX');
  EmitInstr('INC',  'CX');
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JNZ',  '_RSRT_ITOA_DIV');
  EmitLabel('_RSRT_ITOA_POP');
  EmitInstr('POP',  'AX');
  EmitInstr('ADD',  'AL, 30h');
  EmitRaw('        MOV     [DI], AL');
  EmitInstr('INC',  'DI');
  EmitInstr('LOOP', '_RSRT_ITOA_POP');
  EmitRaw('        MOV     BYTE PTR [DI], 0');
  EmitInstr('POP',  'DI');
  EmitInstr('POP',  'DX');
  EmitInstr('POP',  'CX');
  EmitInstr('POP',  'BX');
  EmitInstr('RET',  '');
End;

{ ---- ParseMacroCall : gerer les macros Rust panic! unreachable! etc. ----
  MacroName = nom sans '!', '(' deja attendu                              }
Procedure ParseMacroCall(Const MacroName : TString; Var Res : TExprVal);
Var
  E       : TExprVal;
  Msg     : TString;
  LblMsg  : TString;
  LblSkip : TString;
  Cond    : TExprVal;
Begin
  ExprMakeNone(E);
  { Verifier et consommer '(' }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': '' ( '' attendu apres macro ', MacroName, '!');
    Inc(ErrorCount);
    Res := E;
    Exit;
  End;
  ParserAdvance;   { consommer '(' }
  If MacroName = 'panic' Then Begin
    Msg := 'panic!';
    If CurToken.Kind = TK_STRING Then Begin
      Msg := CurToken.Val; ParserAdvance;
    End;
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
    LblMsg := RS_STR_PFX + SymNewLabel('PANIC');
    DataAdd(LblMsg, DK_STR, 0, Msg, TY_IDX_STR);
    EmitInstr('MOV',  'SI, OFFSET ' + LblMsg);
    EmitInstr('CALL', '_RSRT_PANIC');
  End Else If MacroName = 'unreachable' Then Begin
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
    LblMsg := RS_STR_PFX + SymNewLabel('UNREACH');
    DataAdd(LblMsg, DK_STR, 0, 'unreachable!', TY_IDX_STR);
    EmitInstr('MOV',  'SI, OFFSET ' + LblMsg);
    EmitInstr('CALL', '_RSRT_PANIC');
  End Else If MacroName = 'debug_assert' Then Begin
    ParseExprPrec(1, Cond);
    ExprLoad(Cond);
    LblSkip := SymNewLabel('ASSERT_OK');
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('JNZ',  LblSkip);
    LblMsg := RS_STR_PFX + SymNewLabel('ASSERTMSG');
    DataAdd(LblMsg, DK_STR, 0, 'debug_assert failed', TY_IDX_STR);
    EmitInstr('MOV',  'SI, OFFSET ' + LblMsg);
    EmitInstr('CALL', '_RSRT_PANIC');
    EmitLabel(LblSkip);
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
  End Else If MacroName = 'print' Then Begin
    Msg := '';
    If CurToken.Kind = TK_STRING Then Begin
      Msg := CurToken.Val; ParserAdvance;
    End;
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
    LblMsg := RS_STR_PFX + SymNewLabel('PRINT');
    DataAdd(LblMsg, DK_STR, 0, Msg, TY_IDX_STR);
    EmitInstr('MOV',  'SI, OFFSET ' + LblMsg);
    EmitInstr('CALL', '_RSRT_PRINT');
  End Else If MacroName = 'println' Then Begin
    Msg := '';
    If CurToken.Kind = TK_STRING Then Begin
      Msg := CurToken.Val; ParserAdvance;
    End;
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
    LblMsg := RS_STR_PFX + SymNewLabel('PRINTLN');
    DataAdd(LblMsg, DK_STR, 0, Msg + Chr(10), TY_IDX_STR);
    EmitInstr('MOV',  'SI, OFFSET ' + LblMsg);
    EmitInstr('CALL', '_RSRT_PRINT');
  End Else Begin
    WriteLn('RUST86: avertissement ligne ', CurToken.Line,
            ': macro inconnue ignoree: ', MacroName, '!');
    Inc(WarnCount);
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
  Res := E;
End;

{ ============================================================
  BLOCS UNSAFE ET POINTEURS BRUTS
  ParseUnsafeBlock : unsafe BLOC avec InUnsafeDepth
  ParseExternDecl  : extern ABI fn name() -> T + directive EXTRN
  TypeAddPtr + TKD_PTR dans ParseTypeName
  ============================================================ }

{ ---- ParseUnsafeBlock : unsafe BLOC ---- }
Procedure ParseUnsafeBlock;
Begin
  { 'unsafe' deja consomme }
  Inc(InUnsafeDepth);
  ParseBlock(GExprDummy);
  Dec(InUnsafeDepth);
End;

{ ---- ParseExternDecl : extern ABI fn name(params) -> T; ----
  Reconnait extern ABI simple ou extern ABI BLOC.           }
Procedure ParseExternDecl;
Var
  Name  : TString;
  RetTy : Integer;
Begin
  { 'extern' deja consomme }
  { consommer l'ABI optionnelle ex: "C" }
  If CurToken.Kind = TK_STRING Then
    ParserAdvance;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then Begin
    { extern ABI BLOC - plusieurs declarations fn }
    ParserAdvance;
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}'))
          And (CurToken.Kind <> TK_EOF) Do Begin
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'fn') Then Begin
        ParserAdvance;
        If CurToken.Kind <> TK_IDENT Then Begin Inc(ErrorCount); Break; End;
        Name := CurToken.Val; ParserAdvance;
        RetTy := TY_IDX_UNIT;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then Begin
          ParserAdvance;
          While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
                And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '->') Then Begin
          ParserAdvance;
          RetTy := ParseTypeName;
          If RetTy = TY_UNKNOWN Then RetTy := TY_IDX_UNIT;
        End;
        SymAdd(Name, SC_FN, RetTy, False, 0, CurToken.Line);
        If SymCount > 0 Then Begin
          SymTab[SymCount-1].MangledName := Name;
          SymTab[SymCount-1].IsRef := True;  { marqueur extern }
        End;
        EmitRaw('        EXTRN   ' + Name + ':NEAR');
        If Opts.Verbose Then WriteLn('extern fn ', Name, ' -> EXTRN');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          ParserAdvance;
      End Else ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
      ParserAdvance;
  End Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'fn') Then Begin
    ParserAdvance;
    If CurToken.Kind <> TK_IDENT Then Begin
      WriteLn('RUST86: erreur ligne ', CurToken.Line,
              ': nom attendu apres extern fn');
      Inc(ErrorCount); Exit;
    End;
    Name := CurToken.Val; ParserAdvance;
    RetTy := TY_IDX_UNIT;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then Begin
      ParserAdvance;
      While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
            And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '->') Then Begin
      ParserAdvance;
      RetTy := ParseTypeName;
      If RetTy = TY_UNKNOWN Then RetTy := TY_IDX_UNIT;
    End;
    SymAdd(Name, SC_FN, RetTy, False, 0, CurToken.Line);
    If SymCount > 0 Then Begin
      SymTab[SymCount-1].MangledName := Name;
      SymTab[SymCount-1].IsRef := True;  { marqueur extern }
    End;
    EmitRaw('        EXTRN   ' + Name + ':NEAR');
    If Opts.Verbose Then WriteLn('extern fn ', Name, ' -> EXTRN');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
  End Else Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': fn ou accolade attendue apres extern');
    Inc(ErrorCount);
  End;
End;

{ ---- ParseTopLevel : items de haut niveau (fn, pub fn, mod, use) ---- }
Procedure ParseTopLevel;
Var IsPub : Boolean;
Begin
  IsPub := False;
  { === use chemin::nom [as alias]; === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'use') Then Begin
    ParserAdvance;
    ParseUseDecl;
    Exit;
  End;
  { === mod nom BLOC === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'mod') Then Begin
    ParserAdvance;
    ParseModDecl;
    Exit;
  End;
  { === unsafe fn ou unsafe BLOC === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'unsafe') Then Begin
    ParserAdvance;
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'fn') Then Begin
      ParserAdvance; ParseFnDecl(IsPub);
    End Else
      ParseUnsafeBlock;
    Exit;
  End;
  { === extern ABI fn ... ou extern ABI BLOC === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'extern') Then Begin
    ParserAdvance;
    ParseExternDecl;
    Exit;
  End;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'pub') Then Begin
    IsPub := True; ParserAdvance;
  End;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'fn') Then Begin
    ParserAdvance;
    ParseFnDecl(IsPub);
  End Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'static') Then Begin
    ParserAdvance;
    ParseStaticDecl;
  End Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'const') Then Begin
    ParserAdvance;
    ParseConstDecl;
  End Else Begin
    WriteLn('RUST86: erreur ligne ', CurToken.Line,
            ': declaration attendue (fn, pub fn)');
    Inc(ErrorCount);
    ParserAdvance;
  End;
End;

{ ---- ParseStmt : analyser une instruction ou expression-statement ---- }
Procedure ParseStmt;   { corps du Forward }
Var
  Name   : TString;
  Idx    : Integer;
  E      : TExprVal;
  Rhs    : TExprVal;
  OfsStr : TString;
  Op     : TString;
Begin
  { === static [mut] NAME : Type = expr; === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'static') Then Begin
    ParserAdvance;
    ParseStaticDecl;
    Exit;
  End;
  { === use chemin::nom [as alias]; === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'use') Then Begin
    ParserAdvance;
    ParseUseDecl;
    Exit;
  End;
  { === mod nom BLOC === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'mod') Then Begin
    ParserAdvance;
    ParseModDecl;
    Exit;
  End;
  { === unsafe BLOC === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'unsafe') Then Begin
    ParserAdvance;
    ParseUnsafeBlock;
    Exit;
  End;
  { === extern ABI fn name() -> T; === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'extern') Then Begin
    ParserAdvance;
    ParseExternDecl;
    Exit;
  End;
  { === const NAME : Type = expr; === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'const') Then Begin
    ParserAdvance;
    ParseConstDecl;
    Exit;
  End;
  { === return [expr]; === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'return') Then Begin
    ParserAdvance;
    ParseReturnStmt;
    Exit;
  End;
  { === fn name(params) BLOC === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'fn') Then Begin
    ParserAdvance;
    ParseFnDecl(False);
    Exit;
  End;
  { === pub fn name(params) BLOC === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'pub') Then Begin
    ParserAdvance;
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'fn') Then Begin
      ParserAdvance;
      ParseFnDecl(True);
    End;
    Exit;
  End;
  { === let [mut] name ... === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'let') Then Begin
    ParserAdvance;   { consommer 'let' }
    ParseLetStmt;
    Exit;
  End;
  { === if [let] cond BLOC [else BLOC] === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'if') Then Begin
    ParserAdvance;   { consommer 'if' }
    ParseIfStmt;
    Exit;
  End;
  { === boucle loop BLOC === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'loop') Then Begin
    ParserAdvance;
    ParseLoopStmt;
    Exit;
  End;
  { === boucle while cond BLOC === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'while') Then Begin
    ParserAdvance;
    ParseWhileStmt;
    Exit;
  End;
  { === boucle for var in start..end BLOC === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'for') Then Begin
    ParserAdvance;
    ParseForInStmt;
    Exit;
  End;
  { === match expr BLOC de bras === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'match') Then Begin
    ParserAdvance;
    ParseMatchStmt;
    Exit;
  End;
  { === break : saut vers la sortie de boucle courante === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'break') Then Begin
    If LoopTop > 0 Then
      EmitInstr('JMP', LoopBreakLbl[LoopTop])
    Else Begin
      WriteLn('RUST86: erreur ligne ', CurToken.Line, ': break hors boucle');
      Inc(ErrorCount);
    End;
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
    Exit;
  End;
  { === continue : saut vers la tete de boucle courante === }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'continue') Then Begin
    If LoopTop > 0 Then
      EmitInstr('JMP', LoopContLbl[LoopTop])
    Else Begin
      WriteLn('RUST86: erreur ligne ', CurToken.Line, ': continue hors boucle');
      Inc(ErrorCount);
    End;
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
    Exit;
  End;
  { --- instruction bloc entre accolades --- }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then Begin
    ParseBlock(E);
    { point-virgule optionnel apres un bloc }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
    Exit;
  End;
  { === affectation simple ou composee : name = / name += ... === }
  If CurToken.Kind = TK_IDENT Then Begin
    Name := CurToken.Val;
    ParserAdvance;   { avancer }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then Begin
      ParserAdvance;   { consommer '=' }
      Idx := SymFind(Name);
      If Idx < 0 Then Begin
        WriteLn('RUST86: erreur ligne ', CurToken.Line, ': variable inconnue : ', Name);
        Inc(ErrorCount);
      End Else If Not SymTab[Idx].IsMut Then Begin
        WriteLn('RUST86: erreur ligne ', CurToken.Line,
                ': tentative d', #39, 'affectation d', #39, 'une variable non-mut : ', Name);
        Inc(ErrorCount);
      End Else Begin
        ParseExprPrec(1, E);
        ExprLoad(E);
        Str(Abs(SymTab[Idx].Offset), OfsStr);
        If SymTab[Idx].Offset >= 0 Then
          EmitInstr('MOV', '[BP+' + OfsStr + '], AX')
        Else
          EmitInstr('MOV', '[BP-' + OfsStr + '], AX');
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
      Exit;
    End;
    { affectations composees : += -= *= /= %= &= |= ^= }
    Op := '';
    If CurToken.Kind = TK_OP Then Begin
      If CurToken.Val = '+=' Then Op := '+'
      Else If CurToken.Val = '-=' Then Op := '-'
      Else If CurToken.Val = '*=' Then Op := '*'
      Else If CurToken.Val = '/=' Then Op := '/'
      Else If CurToken.Val = '%=' Then Op := '%'
      Else If CurToken.Val = '&=' Then Op := '&'
      Else If CurToken.Val = '|=' Then Op := '|'
      Else If CurToken.Val = '^=' Then Op := '^';
    End;
    If Op <> '' Then Begin
      ParserAdvance;   { consommer l'operateur compose }
      ParseCompoundAssign(Name, Op);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
      Exit;
    End;
    { sinon : c'est une expression commencant par un ident (appel, etc.) }
    { On recree un TExprVal EK_MEM ou on rappelle ParsePrimary apres avoir }
    { sauvegarde le nom -- ici on re-consomme via SymFind directement        }
    Idx := SymFind(Name);
    If Idx >= 0 Then Begin
      E.Kind    := EK_MEM;
      E.Offset  := SymTab[Idx].Offset;
      E.TypeIdx := SymTab[Idx].TypeIdx;
      E.ImmVal  := 0;
    End Else
      ExprMakeNone(E);
    { continuer l'analyse comme expression binaire }
    While CurToken.Kind = TK_OP Do Begin
      Op := CurToken.Val;
      If BinOpPrec(Op) = 0 Then Break;
      ParserAdvance;
      ParseExprPrec(BinOpPrec(Op) + 1, Rhs);
      ExprEmitBinOp(Op, E, Rhs);
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
    Exit;
  End;
  { === expression-statement quelconque === }
  ParseExprPrec(1, E);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ============================================================
  Procedure : Corps principal de la compilation
  ============================================================ }
Procedure Run;
Var
  HasMain : Boolean;
  I       : Integer;
Begin
  { initialiser tous les sous-systemes }
  TypeInit;
  SymInit;
  ImplInit;
  BorrowInit;
  LifetimeInit;
  If Opts.Verbose Then Begin
    WriteLn('RUST86: Compilation de ', Opts.SrcFile, ' ...');
  End;
  { Ouvrir le fichier de sortie et emettre l'en-tete MASM }
  EmitOpen;
  EmitHeader;
  { Initialiser le parseur : ouvrir la source et lire le premier token }
  LexInit;
  ParserAdvance;
  { Boucle principale : analyser les items de haut niveau }
  While CurToken.Kind <> TK_EOF Do ParseTopLevel;
  LexClose;
  { Routines runtime (toujours emises pour qu'un linker puisse les trouver) }
  EmitRuntime;
  { Fermer le segment de code }
  EmitRaw('');
  EmitRaw('_TEXT   ENDS');
  { Emettre le segment de donnees }
  EmitDataSeg;
  { Epilogue : point d'entree }
  WriteLn(OutF);
  HasMain := False;
  For I := 0 To SymCount - 1 Do
    If (SymTab[I].Cat = SC_FN) And (SymTab[I].Name = 'main') Then
      HasMain := True;
  If HasMain Then
    WriteLn(OutF, '        END     _RSF_main')
  Else
    WriteLn(OutF, '        END');
  EmitClose;
  If Opts.Verbose Then
    WriteLn('RUST86: ', TotalLines, ' lignes, ', SymCount, ' symboles, ',
            ErrorCount, ' erreur(s), ', WarnCount, ' avertissement(s).');
End;

{ ============================================================
  Procedure : Liberation des ressources
  ============================================================ }
Procedure Cleanup;Begin
  LexClose;
  EmitClose;  { fermer le fichier ASM si ouvert }
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
BEGIN
  If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
   ShowHelp;
   Halt(0);
  End;
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  TotalSyms  := 0;
  LexOpened  := False;
  { pre-initialiser la table des symboles }
  TypeCount  := 0;
  FieldCount := 0;
  ImplCount  := 0;
  MethodCount:= 0;
  BorrowCount  := 0;
  LifetimeCount:= 0;
  OutFOpen     := False;
  CurFrameSize := 0;
  LoopTop      := 0;
  DataCount      := 0;
  CurModPath     := '';
  ModDepth       := 0;
  InUnsafeDepth  := 0;
  RuntimeEmitted  := False;
  SymCount   := 0;
  ScopeTop   := 0;
  CurScope   := 0;
  LabelSeq   := 0;
  InitOptions;
  ParseArgs;
  ShowBanner;
  Run;
  Cleanup;
  If Opts.Verbose Then ShowStats;
  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
END.
