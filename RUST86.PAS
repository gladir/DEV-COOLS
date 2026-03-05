{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Rust vers assembleur 8086
}

(*
  ============================================================
  PLAN DE DEVELOPPEMENT - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE GENERALE
            Definir les constantes de dimensionnement (MAX_SYM, MAX_PROC,
            MAX_LABEL, MAX_SCOPE, MAX_ERRORS, MAX_STR, etc.) et les
            types fondamentaux TString/TToken; etablir la structure
            du programme principal (ParseArgs, Run, Cleanup).

  TODO 02 - LEXER : TOKENS DE BASE
            Implanter le scanner de caracteres (ouverture fichier,
            buffer ligne, gestion lignes/colonnes, AvanceChar,
            PeekChar). Reconnaitre les identifiants, les entiers
            decimaux/hexadecimaux (0x...) et les caracteres de
            ponctuation simples.

  TODO 03 - LEXER : LITTERAUX CHAINES ET CARACTERES
            Gerer les litteraux '' (char) et "" (str), les
            sequences d'echappement (\n \t \r \\ \0 \uXXXX),
            les raw strings r#"..."# et les byte literals b'X'.

  TODO 04 - LEXER : OPERATEURS ET MOTS-CLES RUST
            Reconnaitre tous les operateurs Rust (-> :: .. ..=
            => && || != >= <= ** << >> &= |= ^= += -= *= /= %=
            <<=  >>= etc.) et la liste complete des mots-cles
            reserves (fn, let, mut, if, else, match, loop, while,
            for, in, return, struct, enum, impl, trait, use, mod,
            pub, self, Self, super, crate, const, static, type,
            where, unsafe, extern, as, ref, break, continue, dyn).

  TODO 05 - TABLE DES SYMBOLES
            Creer la table des symboles (identifiant, categorie,
            type, portee, offset BP / adresse statique, mutabilite,
            flag reference). Implanter Add/Find/EnterScope/
            LeaveScope avec pile de portees imbriquees.

  TODO 06 - SYSTEME DE TYPES PRIMITIFS
            Modeliser les types scalaires Rust cibles 8086 :
            i8, u8 (1 octet), i16, u16, isize, usize (2 octets),
            i32, u32 (4 octets - paire de registres), bool (1 octet),
            char (4 octets Unicode tronque a u8 sur 8086), () (unit).
            Calculer sizeof et alignement pour chaque type.

  TODO 07 - TYPES COMPOSES : TUPLES ET TABLEAUX
            Gerer les types tuple (T1, T2, ...) et les tableaux
            de taille fixe [T; N]. Calculer l'offset de chaque
            element dans la disposition memoire et generer les
            acces par indice en assembleur 8086.

  TODO 08 - TYPES COMPOSES : STRUCT
            Analyser les declarations struct (struct Nom { champ:
            Type, ... }). Construire la table des champs avec
            offsets 8086 alignes. Gerer les struct tuple
            (struct Foo(T1, T2)) et les struct unites (struct Foo;).

  TODO 09 - TYPES COMPOSES : ENUM
            Analyser les declarations enum (enum Nom { Var1,
            Var2(T), Var3 { champ: T }, ... }). Encoder le
            discriminant (tag 8 bits) suivi des donnees de la
            variante. Etablir la representation memoire 8086
            (taille = tag + max_payload).

  TODO 10 - TRAITS ET IMPL (SANS DYNAMIC DISPATCH)
            Analyser les blocs impl Type { fn ... } et impl Trait
            for Type { fn ... }. Stocker les methodes dans la table
            des symboles avec mungling de nom (_IMPL_Type_fn).
            Exclure le dynamic dispatch (dyn Trait) de la
            cible 8086/TP7 (erreur explicite si rencontre).

  TODO 11 - REFERENCES ET EMPRUNTS (BORROW SIMPLIFIE)
            Modeliser &T et &mut T comme pointeurs 16 bits (offset
            ou segment:offset en mode far optionnel). Implanter la
            verification statique de base : une seule reference
            mutable active par variable. Signaler les violations
            comme erreur de compilation sans implementer la duree
            de vie complete.

  TODO 12 - DUREES DE VIE (LIFETIME ELISION UNIQUEMENT)
            Accepter les annotations de duree de vie ('a) en
            syntaxe sans les verifier au-dela de l'elision
            standard (une seule reference en entree -> meme
            lifetime en sortie). Emettre un avertissement pour
            les lifetimes explicites complexes non verifies.

  TODO 13 - EXPRESSIONS : ARITHMETIQUE ET LOGIQUE
            Implanter le parseur d'expressions par precedence
            (Pratt ou recursif descendant). Couvrir : +, -, *,
            /, %, &, |, ^, !, <<, >>, &&, ||, ==, !=, <, >,
            <=, >= , as (cast), unaire -, !, *deref, &borrow.
            Generer le code 8086 correspondant (ADD, SUB, IMUL,
            IDIV, AND, OR, XOR, SHL, SHR, NEG, NOT, CMP + Jcc).

  TODO 14 - EXPRESSIONS : APPELS DE FONCTIONS ET METHODES
            Gerer les appels fn(args), objet.methode(args) et
            Trait::fn(args). Implanter la convention d'appel
            cdecl 8086 : arguments empiles droite a gauche,
            retour dans AX (8/16 bits) ou DX:AX (32 bits),
            nettoyage par l'appelant.

  TODO 15 - INSTRUCTIONS : LET, AFFECTATION, BLOCS
            Analyser let [mut] motif [: Type] [= expr];.
            Allouer l'espace sur la pile (SUB SP, n). Generer
            les affectations simples et les affectations
            composees (+=, -= etc.). Gerer les blocs { ... }
            comme expressions retournant une valeur.

  TODO 16 - INSTRUCTIONS : IF / ELSE / IF LET
            Analyser if cond { } [else { }] et la forme if let
            Motif = expr { }. Generer les sauts conditionnels
            8086 avec labels locaux _L_THEN_N / _L_ELSE_N /
            _L_ENDIF_N. Gerer if comme expression (les deux
            branches doivent produire le meme type).

  TODO 17 - INSTRUCTIONS : BOUCLES (loop, while, for..in)
            Analyser loop { }, while cond { } et for var in
            expr { } (iterateurs simples : intervalles a..b
            et a..=b sur entiers). Generer les labels de boucle
            _L_LOOP_N / _L_BREAK_N et les instructions break /
            continue avec support des labels de boucle (break
            'label).

  TODO 18 - PATTERN MATCHING (match)
            Analyser match expr { motif => expr, ... }.
            Supporter les motifs : litteral, _, variable,
            tuple, struct, enum incluant les gardes (if cond).
            Generer une chaine de tests 8086 (CMP + Jcc) pour
            les discriminants enum et les litteraux entiers.

  TODO 19 - CLOSURES (FORME SIMPLIFIEE)
            Analyser la syntaxe |params| expr et |params| {
            bloc }. Traiter les closures non-capturantes comme
            des fonctions anonymes emises directement. Emettre
            une erreur explicite pour la capture de variables
            (Fn / FnMut / FnOnce) non implantee sur cible 8086.

  TODO 20 - GESTION MEMOIRE : PILE ET CADRE DE PILE
            Generer le prologue 8086 (PUSH BP / MOV BP,SP /
            SUB SP,N) et l'epilogue (MOV SP,BP / POP BP / RET).
            Calculer N (taille totale des variables locales) en
            fin d'analyse de la fonction. Respecter l'alignement
            8086 sur 2 octets.

  TODO 21 - SEGMENT DE DONNEES : STATICS ET CONSTS
            Emettre les declarations static et const Rust dans
            le segment .DATA de l'assembleur 8086. Gerer les
            chaines litterales (tableau d'octets termine par 0
            ou avec longueur prepend selon le contexte). Attribuer
            des etiquettes prefixees _RS_ (Rust Static).

  TODO 22 - MODULES ET USE
            Analyser les declarations mod nom { ... } et
            use chemin::nom [as alias]. Implanter une resolution
            de noms par chaine de modules imbriquee. Traduire
            les chemins absolus vers les etiquettes assembleur
            par mungling : _MOD_sousmod_fn.

  TODO 23 - BLOCS UNSAFE ET POINTEURS BRUTS
            Reconnaitre unsafe { } et les types *const T / *mut T.
            Dans un bloc unsafe, autoriser la deref de pointeur
            brut (MOV reg,[adr]) et l'appel de fonctions externse
            (extern "C" fn). Hors unsafe, interdire ces operations
            et emettre une erreur de compilation.

  TODO 24 - RUNTIME MINIMAL ET PANIC
            Emettre les routines runtime en assembleur 8086 :
            _RS_PANIC (affiche message + INT 20h), _RS_MEMSET,
            _RS_MEMCPY, _RS_ITOA (formatage entier), _RS_PRINT
            (appel DOS INT 21h AH=40h). Generer l'appel a
            _RS_PANIC pour les cas unreachable!() et les debordements
            verifies (debug_assert).

  TODO 25 - GENERATION FINALE ET FICHIER .ASM
            Assembler les segments produits (en-tete .MODEL SMALL,
            .STACK, .DATA, .CODE) dans le fichier de sortie .ASM.
            Emettre les directives EXTRN et PUBLIC adequats pour
            chaque symbole. Implanter les options de ligne de
            commande (fichier source, fichier sortie, -v verbose,
            -d debug tokens, --edition 2021 etc.) et afficher les
            statistiques de compilation (lignes, symboles, erreurs).

  ============================================================
*)

Program RUST86;

{$I-}   { Desactiver les IO-check pour gerer nous-memes les erreurs }

{ ============================================================
  TODO 01 - INFRASTRUCTURE GENERALE
  ============================================================ }

{ --- Constantes de dimensionnement --- }
Const
  RUST86_VERSION = '1.0';
  RUST86_DATE    = '2026-03-04';

  MAX_SYM    = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};   { entrees table des symboles             }
  MAX_PROC   = {$IFDEF FPC}256{$ELSE}64{$ENDIF};     { fonctions fn                           }
  MAX_IMPL   = 64;    { blocs impl (impl Type / impl Trait for Type) }
  MAX_METHOD = 256;   { methodes total dans tous les blocs impl      }
  MAX_BORROW = 128;   { verrous d'emprunt actifs simultanement max (TODO 11) }
  MAX_PARAM  = {$IFDEF FPC}32{$ELSE}16{$ENDIF};      { parametres par fonction                }
  MAX_FIELD  = 64;    { champs par struct/enum                     }
  MAX_FIELDS_TOTAL = 512; { pool global de champs pour tous les types (TODO 07) }
  MAX_CONST  = 512;   { constantes (const / static immuable)       }
  MAX_TYPE   = 64;    { descripteurs de type                       }
  MAX_LABEL  = 2048;  { labels internes (if/loop/match/break...)   }
  MAX_SCOPE  = 64;    { profondeur maximale de portee              }
  MAX_ERRORS = 30;    { arret apres N erreurs                      }
  MAX_STR    = {$IFDEF FPC}255{$ELSE}127{$ENDIF};    { longueur maximale d'une TString        }
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

  { Codes de sortie du programme }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { ============================================================
    TODO 06 - Indices des types primitifs dans TypeTab
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

  { ---- Categorie d'un symbole (TODO 05) ---- }
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
    TypeIdx  : Integer;       { index dans la table de types (TODO06) }
    ScopeLevel : Integer;     { niveau de portee (0 = global)      }
    Offset   : Integer;       { offset BP pour locals/params (negatif pour locals) }
    MangledName : TString;    { etiquette assembleur 8086          }
    IsMut    : Boolean;       { variable mutable                   }
    IsRef    : Boolean;       { symbole est une reference &T       }
    DeclLine : Integer;       { ligne de declaration dans le source }
  End;

  { ============================================================
    TODO 06 - Categorie d'un descripteur de type
    ============================================================ }
  TTypeKind = (
    TKD_PRIM,    { type scalaire primitif (i8..u32, bool, char, ()) }
    TKD_REF,     { reference &T ou &mut T                          }
    TKD_ARRAY,   { tableau de taille fixe [T; N]                   }
    TKD_TUPLE,   { tuple (T1, T2, ...)                             }
    TKD_STRUCT,  { struct avec champs nommes                      }
    TKD_ENUM,    { enum avec variantes et donnees                  }
    TKD_FN,      { pointeur de fonction fn(T1) -> T2               }
    TKD_UNKNOWN  { type non encore resolu                          }
  );

  { ============================================================
    TODO 10 - Descripteur d'un bloc impl
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
    TODO 11 - Emprunts : &T (partage) et &mut T (mutable)
    ============================================================ }
  TBorrowKind = (BK_SHARED, BK_MUT);  { partage ou mutable }

  TBorrowRec = Record
    VarName  : TString;      { nom de la variable empruntee            }
    Kind     : TBorrowKind;  { BK_SHARED = &T  ou  BK_MUT = &mut T    }
    TypeIdx  : Integer;      { index du type pointe dans TypeTab       }
    IsActive : Boolean;      { emprunt encore actif dans la portee     }
    DeclLine : Integer;      { numero de ligne de la declaration       }
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
    TODO 07 - Descripteur d'un element/champ d'un type compose
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

{ --- Variables globales du lexer (TODO 02) --- }
Var
  LexSrcF   : Text;          { fichier source ouvert              }
  LexLine   : String;        { ligne courante                     }
  LexLineNo : Integer;       { numero de ligne (1-base)           }
  LexColNo  : Integer;       { colonne courante dans LexLine      }
  LexEOF    : Boolean;       { vrai si fin de fichier atteinte    }
  LexOpened : Boolean;       { vrai si LexSrcF est ouvert         }
  CurToken  : TToken;        { token courant                      }

{ --- Variables globales de la table des symboles (TODO 05) --- }
Var
  SymTab     : Array[0..MAX_SYM - 1]   Of TSymRec;  { table des symboles  }
  SymCount   : Integer;                              { nb symboles inseres }
  ScopeStack : Array[0..MAX_SCOPE - 1] Of Integer;  { debut de chaque portee dans SymTab }
  ScopeTop   : Integer;                              { index sommet de pile de portees    }
  CurScope   : Integer;                              { niveau de portee courant (0=global)}
  LabelSeq   : Integer;                              { compteur global de labels uniques  }

{ --- Variables globales du systeme de types (TODO 06) --- }
Var
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;  { descripteurs de types           }
  TypeCount : Integer;                              { nb de types enregistres          }

{ --- Variables globales des champs de types composes (TODO 07) --- }
Var
  FieldTab   : Array[0..MAX_FIELDS_TOTAL - 1] Of TFieldRec; { pool de champs/elements }
  FieldCount : Integer;                                      { nb entrees utilisees    }

{ --- Variables globales des blocs impl (TODO 10) --- }
Var
  ImplTab    : Array[0..MAX_IMPL   - 1] Of TImplRec;    { blocs impl enregistres  }
  ImplCount  : Integer;                                  { nb de blocs impl        }
  MethodTab  : Array[0..MAX_METHOD - 1] Of TMethodRec;  { methodes de tous les impl }
  MethodCount: Integer;                                  { nb de methodes total    }

{ --- Variables globales des emprunts (TODO 11) --- }
Var
  BorrowTab  : Array[0..MAX_BORROW - 1] Of TBorrowRec;  { table des emprunts actifs }
  BorrowCount: Integer;                                  { nb d'emprunts enregistres }

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
  WriteLn('Compilateur Rust vers assembleur 8086');
  WriteLn;
  WriteLn('Usage: RUST86 <source.rs> [<sortie.asm>] [options]');
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
  TODO 02 - LEXER : TOKENS DE BASE
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
  TODO 04 - LEXER : OPERATEURS ET MOTS-CLES RUST
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
             dans Val mais non interprete (reserve pour TODO 06).
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
  TODO 03 - LEXER : LITTERAUX CHAINES ET CARACTERES
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
  TODO 06 - SYSTEME DE TYPES PRIMITIFS
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
  FieldCount := 0;  { TODO 07 - pool de champs }
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
  TODO 07 - TYPES COMPOSES : TUPLES ET TABLEAUX
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
  TODO 08 - TYPES COMPOSES : STRUCT
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
  TODO 09 - TYPES COMPOSES : ENUM
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
  restent contiguës.
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
  TODO 10 - TRAITS ET IMPL (SANS DYNAMIC DISPATCH)
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
  { Note : enregistrement dans SymTab effectue par le parseur (TODO 13) }
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
  TODO 05 - TABLE DES SYMBOLES
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
    SC_FN     : SymMangle := RS_FN_PFX   + S;
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
  TODO 11 - REFERENCES ET EMPRUNTS
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
  Procedure : Corps principal de la compilation
  ============================================================ }
Procedure Run;
Var
  T        : TToken;
  RefIdx   : Integer;   { TODO 11 test : index du type reference cree }
  RefIdx2  : Integer;   { TODO 11 test : deuxieme reference mutable   }
  BIdx     : Integer;   { TODO 11 test : index dans BorrowTab         }
Begin
  { initialiser tous les sous-systemes }
  TypeInit;
  SymInit;
  ImplInit;
  BorrowInit;
  LexInit;
  If Opts.Verbose Then
    WriteLn('RUST86: Analyse lexicale de ', Opts.SrcFile, ' ...');
  Repeat
    LexNextToken(T);
    If Opts.DebugTok Then PrintToken(T);
  Until T.Kind = TK_EOF;
  If Opts.Verbose Then
    WriteLn('RUST86: Analyse lexicale terminee.');
  If Opts.Verbose Then TypeDump;
  If Opts.Verbose Then SymDump;
  If Opts.Verbose Then ImplDump;
  { --- Auto-test TODO 11 : references et emprunts --- }
  If Opts.Verbose Then
  Begin
    { Creer &i16 (partage) et &mut i32 (mutable) }
    RefIdx  := TypeAddRef(TY_IDX_I16, False);
    RefIdx2 := TypeAddRef(TY_IDX_I32, True);
    WriteLn('T11 &i16  tyidx=', RefIdx,  ' name=', TypeTab[RefIdx].Name,
            ' size=', TypeTab[RefIdx].Size);
    WriteLn('T11 &mut i32 tyidx=', RefIdx2, ' name=', TypeTab[RefIdx2].Name,
            ' size=', TypeTab[RefIdx2].Size);
    { Enregistrer un emprunt &mut sur "buf" }
    BIdx := BorrowAdd('buf', BK_MUT, RefIdx2, 42);
    WriteLn('T11 borrow[', BIdx, '] var=', BorrowTab[BIdx].VarName,
            ' active=', BorrowTab[BIdx].IsActive);
    { Tenter un deuxieme &mut sur "buf" -> doit emettre une erreur }
    BorrowCheckMutConflict('buf');
    { Relacher "buf" et retenter -> pas d'erreur }
    BorrowRelease('buf');
    WriteLn('T11 apres release: active=', BorrowTab[BIdx].IsActive);
    BorrowCheckMutConflict('buf');
    { Affichage complet }
    BorrowDump;
    WriteLn('T11 ErrorCount=', ErrorCount);
  End;
  { TODO 12+ : parseur, generation de code }
End;

{ ============================================================
  Procedure : Liberation des ressources
  ============================================================ }
Procedure Cleanup;
Begin
  LexClose;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  TotalSyms  := 0;
  LexOpened  := False;
  { TODO 05 : pre-initialiser la table des symboles }
  TypeCount  := 0;
  FieldCount := 0;  { TODO 07 }
  ImplCount  := 0;  { TODO 10 }
  MethodCount:= 0;  { TODO 10 }
  BorrowCount:= 0;  { TODO 11 }
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
End.
