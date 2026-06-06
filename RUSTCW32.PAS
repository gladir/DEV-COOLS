{ @author: Sylvain Maltais
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Rust vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  RUSTCW32.PAS - Compilateur Rust vers assembleur 80386 pour
  Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte tous les exemples SAMPLES\RUST\*.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET MODE DE SORTIE [IMPLEMENTE]
            Definir TOptions : SrcFile, OutFile, Verbose, DebugMode,
              Warnings, EmitExe, EmitObj, EmitAsm, NoLink, OptLevel.
            ParseArgs : rustcw32 source.rs [-o out] [-v] [-d] [-w]
              [-obj] [-asm] [-O0..-O2] [-h].
            Defaut : produire un .EXE PE Win32 ; -obj : produire
              seulement un .OBJ COFF ; -asm : conserver aussi un .ASM
              lisible. Valider les extensions .rs et les noms de sortie.
            Ajouter FatalError, WarnMsg, EXIT_OK, EXIT_ERROR, EXIT_USAGE.

  TODO 02 - CONSTANTES 80386, PE/COFF ET LIMITES INTERNES [IMPLEMENTE]
            Definir les constantes PE/COFF : MZ, PE\0\0, machine i386,
              IMAGE_BASE $00400000, alignements section/fichier,
              sous-systeme console, flags .text/.rdata/.data/.bss.
            Prevoir limites : MAX_SYM, MAX_PROC, MAX_PARAM, MAX_LOCAL,
              MAX_CONST, MAX_STATIC, MAX_TYPE, MAX_FIELD, MAX_LABEL,
              MAX_SCOPE, MAX_LOOP_NEST, MAX_IMPORT, MAX_RELOC.
            Definir prefixes ASM : _RSF_ fonctions, _RSV_ statiques,
              _RSK_ chaines, _RSL_ labels, _RSRT_ runtime.

  TODO 03 - LECTURE SOURCE ET GESTION DES ERREURS [IMPLEMENTE]
            Charger le fichier .rs en entree, conserver ligne/colonne,
              chemin courant et nom logique du module.
            Accumuler les erreurs avec contexte : fichier, ligne,
              colonne, token fautif, message clair.
            Arreter apres MAX_ERRORS, mais continuer assez longtemps
              pour diagnostiquer plusieurs erreurs simples.

  TODO 04 - TOKENISEUR RUST [IMPLEMENTE]
            Implementer LexInit, LexNextChar, LexPeekChar, LexNextToken.
            Reconnaitre identificateurs, mots-cles, lifetimes simples,
              entiers decimaux/hex/bin/oct avec underscores, chaines,
              caracteres, commentaires // et /* */ imbriques.
            Reconnaitre operateurs et ponctuation : ::, ->, =>, ..,
              ==, !=, <=, >=, +=, -=, *=, /=, %=, &, *, !, { } ( ) ; , :.

  TODO 05 - MOTS-CLES ET MACROS MINIMALES [IMPLEMENTE]
            Mots-cles necessaires : fn, pub, let, mut, const, static,
              unsafe, extern, return, if, else, while, for, in, loop,
              break, match, true, false.
            Macros supportees pour les exemples : println!, debug_assert!,
              panic!. Les traiter comme formes speciales du parseur,
              pas comme un systeme complet de macros Rust.

  TODO 06 - TYPES PRIMITIFS ET REPRESENTATION 32 BITS [IMPLEMENTE]
            Declarer les types primitifs : i8, u8, i16, u16, i32, u32,
              isize, usize, bool, char, (), pointeurs bruts *const T
              et *mut T.
            Sur Win32 : isize/usize/pointeurs = 32 bits, i16 conserve
              une semantique 16 bits avec extension de signe au besoin.
            Definir taille, alignement, signe et classe de registre.

  TODO 07 - TABLE DES SYMBOLES ET PORTEES [IMPLEMENTE]
            Gerer symboles globaux, fonctions, parametres, variables
              locales, const, static, extern et labels internes.
            Implementer EnterScope/LeaveScope, FindSym/AddSym,
              detection de redeclaration et respect de let mut pour
              les affectations.

  TODO 08 - SIGNATURES DE FONCTIONS [IMPLEMENTE]
            Parser fn name(params) -> type { ... } et pub fn main().
            Stocker nom Rust, nom mangle ASM, type de retour, liste
              des parametres et convention d'appel.
            Prevoir main comme point d'entree console Win32 et fonctions
              internes appelees par CALL.

  TODO 09 - CONSTANTES ET STATICS [IMPLEMENTE]
            Parser const NAME: T = expr; et static mut NAME: T = expr;.
            Placer const dans la table de constantes evaluables a la
              compilation lorsque possible.
            Placer static/static mut dans .data ou .bss avec etiquette
              stable et acces memoire 32 bits.

  TODO 10 - PARSEUR DE BLOCS ET INSTRUCTIONS [IMPLEMENTE]
            Parser blocs { ... }, instructions terminees par ;, return,
              let, affectation, appel de fonction, unsafe { ... }.
            Maintenir offsets de pile pour les variables locales et
              liberer la portee a la sortie du bloc.

  TODO 11 - EXPRESSIONS ET PRECEDENCE [IMPLEMENTE]
            Implementer parseur de precedence : litteraux, variables,
              appels, parentheses, unaires, multiplicatifs, additifs,
              comparaisons, egalite, logiques simples.
            Produire un type d'expression et une valeur en registre ou
              emplacement temporaire.

  TODO 12 - ARITHMETIQUE ENTIERE 80386 [IMPLEMENTE]
            Generer ADD, SUB, IMUL, IDIV/DIV, NEG, CMP pour i16/i32
              et variantes signees/non signees.
            Gerer extensions MOVSX/MOVZX entre i16 et i32.
            Les exemples math.rs doivent compiler add, mul et abs_val.

  TODO 13 - AFFECTATIONS ET MUTABILITE [IMPLEMENTE]
            Autoriser l'affectation seulement vers let mut, static mut
              ou emplacements explicitement mutables.
            Diagnostiquer l'affectation vers let immuable.
            Generer STORE vers pile ou section .data selon symbole.

  TODO 14 - IF / ELSE ET CONDITIONS [IMPLEMENTE]
            Parser if cond { ... } else if ... else { ... }.
            Generer CMP/Jcc et labels uniques.
            Supporter comparaisons <, <=, >, >=, ==, != sur entiers,
              suffisant pour classify et abs_val.

  TODO 15 - WHILE, LOOP, BREAK ET PILE DE BOUCLES [IMPLEMENTE]
            Parser while cond { ... }, loop { ... } et break;.
            Maintenir pile de labels continue/break.
            Les exemples control.rs doivent executer while et loop
              avec sorties conditionnelles.

  TODO 16 - FOR SUR RANGES ENTIERES
            Supporter for i in a..b { ... } comme sucre syntaxique
              compile en initialisation, test, increment et bloc.
            Gerer variable d'iteration locale immuable par defaut.
            Suffisant pour for i in 0..5 dans control.rs.

  TODO 17 - MATCH MINIMAL
            Parser match expr { lit => { ... }, _ => { ... } }.
            Generer comparaison sequentielle et branche par defaut.
            Suffisant pour label_of(code) dans control.rs.

  TODO 18 - APPELS DE FONCTIONS ET CONVENTION D'APPEL
            Definir convention interne : arguments pousses sur pile,
              retour dans EAX, nettoyage par appelant ou appele selon
              choix documente.
            Generer prologue/epilogue EBP, sauvegarde des registres
              necessaires et acces parametres [EBP+offset].
            Supporter appels add(x, y), mul(z, 2), safe_noop(42).

  TODO 19 - EXTERN "C" ET IMPORTS WIN32/CRT
            Parser extern "C" { fn name(params); }.
            Enregistrer symboles externes et relocations COFF.
            Prevoir imports minimaux console/CRT pour puts, ExitProcess,
              WriteConsoleA ou equivalents runtime.

  TODO 20 - UNSAFE ET POINTEURS BRUTS
            Parser unsafe { ... } et marquer le contexte unsafe.
            Supporter declarations *const T et *mut T, litteral 0
              comme pointeur nul, affectation locale de pointeur.
            Pour les exemples, aucun dereferencement requis au depart.

  TODO 21 - MACROS RUNTIME : PRINTLN, DEBUG_ASSERT, PANIC
            println!("texte") : emettre chaine .rdata et appel runtime
              d'ecriture console avec saut de ligne.
            debug_assert!(x) : verifier x != 0 et appeler panic runtime
              si faux, ou l'ignorer selon option future.
            panic!("texte") : afficher message et terminer avec code
              d'erreur non nul.

  TODO 22 - GENERATEUR ASM MASM 80386
            Produire optionnellement un .ASM MASM lisible quand -asm
              est fourni : .386, .MODEL FLAT, sections .CODE/.DATA,
              PUBLIC/EXTERN, labels et commentaires utiles.
            Garder le backend ASM separe du backend binaire COFF/PE
              pour faciliter le debogage.

  TODO 23 - EMISSION COFF .OBJ
            Construire sections .text, .rdata, .data, .bss, table de
              symboles et relocations IMAGE_REL_I386_DIR32/REL32.
            Avec -obj, ecrire uniquement le .OBJ et ne pas lier.
            Verifier que les appels externes restent relocatables.

  TODO 24 - LINKER PE .EXE PAR DEFAUT
            Construire PE32 console minimal : en-tetes DOS/PE, sections,
              table d'import Win32, relocations internes et point
              d'entree.
            Par defaut, produire directement source.exe sans demander
              MASM/LINK externe.
            Appeler ExitProcess au retour de main ou apres panic.

  TODO 25 - TESTS SUR SAMPLES\RUST\*
            Ajouter une commande de validation locale compilant :
              SAMPLES\RUST\hello.rs, math.rs, control.rs,
              unsafe_test.rs.
            Verifier production .EXE par defaut, production .OBJ avec
              -obj, production .ASM additionnelle avec -asm.
            Comparer erreurs attendues, codes de sortie et presence
              des symboles principaux dans .ASM/.OBJ.

  ============================================================ *)

Program RUSTCW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================ }
{ INFRASTRUCTURE ET OPTIONS                                    }
{ ============================================================ }

Const
  RUSTCW32_VERSION = '0.1';
  RUSTCW32_DATE    = '2026';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  OPT_NONE     = 0;
  OPT_BASIC    = 1;
  OPT_ADVANCED = 2;

  { Constantes generales 80386 / Win32 }
  CPU_BITS      = 32;
  WORD_SIZE     = 4;       { taille naturelle d un registre 80386 }
  PTR_SIZE      = 4;       { pointeurs Win32 / usize / isize       }
  STACK_ALIGN   = 4;       { alignement minimal de pile Win32      }
  DEFAULT_BASE  = $00400000;

  { PE/COFF format constants }
  PE_DOS_MAGIC    = $5A4D;       { 'MZ'                              }
  PE_PE_SIG       = $00004550;   { 'PE'#0#0                          }
  PE_MACHINE_I386 = $014C;       { IMAGE_FILE_MACHINE_I386           }
  PE_OPT_SIZE     = 224;         { sizeof IMAGE_OPTIONAL_HEADER32     }
  PE_MAGIC_32     = $010B;       { PE32                               }
  PE_IMG_BASE     = DEFAULT_BASE;{ image base par defaut              }
  PE_SEC_ALIGN    = $1000;       { section alignment (4 KB)           }
  PE_FILE_ALIGN   = $0200;       { file alignment (512 octets)        }
  PE_SUBSYS_CUI   = 3;           { console subsystem                  }
  PE_SUBSYS_GUI   = 2;           { GUI subsystem, reserve futur       }
  PE_NUM_SECTIONS = 4;           { .text, .rdata, .data, .bss         }

  PE_SCN_TEXT     = $60000020;          { CODE | EXECUTE | READ       }
  PE_SCN_RDATA    = $40000040;          { INIT_DATA | READ            }
  PE_SCN_DATA     = LongInt($C0000040); { INIT_DATA | READ | WRITE    }
  PE_SCN_BSS      = LongInt($C0000080); { UNINIT_DATA | READ | WRITE  }

  COFF_RELOC_DIR32 = 6;          { IMAGE_REL_I386_DIR32               }
  COFF_RELOC_REL32 = 20;         { IMAGE_REL_I386_REL32               }
  COFF_SYM_UNDEF   = 0;          { symbole externe non defini         }
  COFF_SYM_ABS     = -1;         { symbole absolu                     }

  { Limites internes }
  MAX_SYM       = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_PROC      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_LOCAL     = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_CONST     = {$IFDEF FPC}1024{$ELSE}128{$ENDIF};
  MAX_STATIC    = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}256{$ELSE}64{$ENDIF};
  MAX_FIELD     = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_IMPORT    = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  MAX_RELOC     = {$IFDEF FPC}8192{$ELSE}1024{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}127{$ENDIF};
  MAX_ERRORS    = 30;

  { Tailles des buffers binaires futurs }
  MAX_BIN_CODE  = {$IFDEF FPC}262144{$ELSE}32768{$ENDIF};
  MAX_BIN_DATA  = {$IFDEF FPC}131072{$ELSE}32768{$ENDIF};
  MAX_BIN_RDATA = {$IFDEF FPC}131072{$ELSE}32768{$ENDIF};
  MAX_ASM_TRACE = {$IFDEF FPC}8192{$ELSE}1024{$ENDIF};

  { Prefixes des etiquettes assembleur 80386 / Win32 }
  RS_FN_PFX     = '_RSF_';       { fonctions Rust                    }
  RS_VAR_PFX    = '_RSV_';       { variables statiques / globals     }
  RS_STR_PFX    = '_RSK_';       { constantes chaines                }
  RS_LABEL_PFX  = '_RSL_';       { labels de controle                }
  RS_RT_PFX     = '_RSRT_';      { routines runtime                  }
  RS_EXT_PFX    = '_RSEXT_';     { symboles externes importes        }
  RS_TYPE_PFX   = '_RST_';       { metadonnees/types futurs          }

  { Indices fixes des types primitifs }
  TY_IDX_I8       = 0;
  TY_IDX_U8       = 1;
  TY_IDX_I16      = 2;
  TY_IDX_U16      = 3;
  TY_IDX_I32      = 4;
  TY_IDX_U32      = 5;
  TY_IDX_ISIZE    = 6;
  TY_IDX_USIZE    = 7;
  TY_IDX_BOOL     = 8;
  TY_IDX_CHAR     = 9;
  TY_IDX_UNIT     = 10;
  TY_IDX_PTR_I16  = 11;          { *const i16, requis par exemples    }
  TY_IDX_MPTR_I16 = 12;          { *mut i16, reserve                  }
  TY_PRIM_COUNT   = 13;
  TY_UNKNOWN      = -1;

Type
  TString = String;

  TTokenKind = (
    TK_EOF,       { fin du fichier source                         }
    TK_IDENT,     { identificateur Rust                            }
    TK_KEYWORD,   { mot-cle Rust reserve                           }
    TK_INTEGER,   { litteral entier                                }
    TK_STRING,    { litteral chaine "..."                          }
    TK_CHAR,      { litteral caractere 'x'                         }
    TK_LIFETIME,  { annotation de duree de vie : 'a, 'static        }
    TK_MACRO,     { macro supportee : println!, debug_assert!, ...  }
    TK_OP,        { operateur simple ou compose                    }
    TK_PUNCT      { ponctuation et separateurs                     }
  );

  TToken = Record
    Kind   : TTokenKind;
    Val    : TString;
    IntVal : LongInt;
    Line   : Integer;
    Col    : Integer;
  End;

  TTypeKind = (
    TYK_PRIM,      { type primitif scalaire                         }
    TYK_PTR        { pointeur brut *const T ou *mut T               }
  );

  TRegClass = (
    RC_NONE,       { aucun registre requis, ex: ()                  }
    RC_BYTE,       { AL/BL/...                                     }
    RC_WORD,       { AX/BX/... avec extension vers EAX si besoin    }
    RC_DWORD       { EAX/EBX/...                                   }
  );

  TTypeRec = Record
    Name      : TString;
    Kind      : TTypeKind;
    Size      : Integer;
    Align     : Integer;
    IsSigned  : Boolean;
    RegClass  : TRegClass;
    BaseType  : Integer;   { pour TYK_PTR                          }
    IsMutPtr  : Boolean;   { True = *mut T, False = *const T        }
  End;

  TSymCat = (
    SC_GLOBAL,    { symbole global generique                         }
    SC_FN,        { fonction Rust                                    }
    SC_PARAM,     { parametre de fonction                            }
    SC_LOCAL,     { variable locale let/let mut                      }
    SC_CONST,     { constante compile-time                           }
    SC_STATIC,    { static / static mut                              }
    SC_EXTERN,    { fonction ou objet extern "C"                    }
    SC_LABEL      { label interne genere                             }
  );

  TSymRec = Record
    Name        : TString;
    MangledName : TString;
    Cat         : TSymCat;
    TypeIdx     : Integer;
    ScopeLevel  : Integer;
    Offset      : LongInt;
    IsMut       : Boolean;
    IsDefined   : Boolean;
    DeclLine    : Integer;
    DeclCol     : Integer;
  End;

  TProcRec = Record
    Name        : TString;
    MangledName : TString;
    RetTypeIdx  : Integer;
    ParamCount  : Integer;
    ParamNames  : Array[0..MAX_PARAM - 1] Of TString;
    ParamTypes  : Array[0..MAX_PARAM - 1] Of Integer;
    IsPublic    : Boolean;
    IsExtern    : Boolean;
    IsMain      : Boolean;
    SymIdx      : Integer;
    DeclLine    : Integer;
    DeclCol     : Integer;
  End;

  TConstRec = Record
    Name       : TString;
    TypeIdx    : Integer;
    IntValue   : LongInt;
    HasIntVal  : Boolean;
    SymIdx     : Integer;
    DeclLine   : Integer;
    DeclCol    : Integer;
  End;

  TStaticRec = Record
    Name        : TString;
    MangledName : TString;
    TypeIdx     : Integer;
    IntValue    : LongInt;
    HasInit     : Boolean;
    IsMut       : Boolean;
    SymIdx      : Integer;
    DeclLine    : Integer;
    DeclCol     : Integer;
  End;

  TExprKind = (
    EK_UNKNOWN,
    EK_LITERAL,
    EK_VAR,
    EK_CALL,
    EK_UNARY,
    EK_BINARY
  );

  TExprRec = Record
    Kind     : TExprKind;
    TypeIdx  : Integer;
    IsConst  : Boolean;
    IntValue : LongInt;
    IsLValue : Boolean;
  End;

  TOptions = Record
    SrcFile   : TString;   { fichier source .rs                 }
    OutFile   : TString;   { sortie principale .exe ou .obj     }
    Verbose   : Boolean;   { -v : banniere et statistiques      }
    DebugMode : Boolean;   { -d : debug tokens futur            }
    Warnings  : Boolean;   { -w : afficher les avertissements   }
    EmitExe   : Boolean;   { produire un .EXE PE Win32          }
    EmitObj   : Boolean;   { produire un .OBJ COFF              }
    EmitAsm   : Boolean;   { conserver un .ASM lisible          }
    NoLink    : Boolean;   { ne pas lier, implique -obj         }
    OptLevel  : Integer;   { 0..2                               }
  End;

Var
  Opts         : TOptions;
  ErrorCount   : Integer;
  WarnCount    : Integer;
  TotalLines   : LongInt;

  { Etat du fichier source courant }
  SourceF       : Text;
  SourceOpened  : Boolean;
  SourceFile    : TString;
  SourceDir     : TString;
  SourceModule  : TString;
  SourceLine    : TString;
  SourceLineNo  : Integer;
  SourceColNo   : Integer;
  SourceEOF     : Boolean;
  CurToken      : TToken;
  TokenCount    : LongInt;
  MacroCount    : LongInt;

  { Types Rust connus }
  TypeTab       : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount     : Integer;

  { Table des symboles et pile de portees }
  SymTab        : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount      : Integer;
  ScopeBase     : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeLevel    : Integer;
  LabelSerial   : LongInt;
  LoopContinue  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopBreak     : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopDepth     : Integer;

  { Fonctions Rust reconnues }
  ProcTab       : Array[0..MAX_PROC - 1] Of TProcRec;
  ProcCount     : Integer;
  MainProcIdx   : Integer;

  { Constantes et statics top-level }
  ConstTab      : Array[0..MAX_CONST - 1] Of TConstRec;
  ConstCount    : Integer;
  StaticTab     : Array[0..MAX_STATIC - 1] Of TStaticRec;
  StaticCount   : Integer;

  { Statistiques de parsing des blocs }
  BlockCount    : LongInt;
  StmtCount     : LongInt;
  LocalCount    : LongInt;
  ExprCount     : LongInt;
  LoopCount     : LongInt;

  { Backend intermediaire 80386 }
  AsmTrace      : Array[0..MAX_ASM_TRACE - 1] Of TString;
  AsmTraceCount : Integer;
  ArithInstrCount : LongInt;
  StoreInstrCount : LongInt;

Procedure FatalError(Const Msg : TString); Forward;

{ ------------------------------------------------------------ }
{ Fonctions utilitaires                                        }
{ ------------------------------------------------------------ }

Function IntToStr_(V : LongInt) : TString;
Var
  S : TString;
Begin
  Str(V, S);
  IntToStr_ := S;
End;

Function StrLowerCase(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'A') And (Tmp[I] <= 'Z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) + 32);
  StrLowerCase := Tmp;
End;

Function IsAlpha(Ch : Char) : Boolean;
Begin
  IsAlpha := ((Ch >= 'A') And (Ch <= 'Z')) Or
             ((Ch >= 'a') And (Ch <= 'z'));
End;

Function IsDigit(Ch : Char) : Boolean;
Begin
  IsDigit := (Ch >= '0') And (Ch <= '9');
End;

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := IsDigit(Ch) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := IsAlpha(Ch) Or (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or IsDigit(Ch);
End;

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then
    HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then
    HexVal := Ord(Ch) - Ord('A') + 10
  Else
    HexVal := Ord(Ch) - Ord('a') + 10;
End;

Function IsRustKeyword(Const S : TString) : Boolean;
Begin
  IsRustKeyword :=
    (S = 'as') Or (S = 'break') Or (S = 'const') Or
    (S = 'continue') Or (S = 'crate') Or (S = 'else') Or
    (S = 'enum') Or (S = 'extern') Or (S = 'false') Or
    (S = 'fn') Or (S = 'for') Or (S = 'if') Or
    (S = 'impl') Or (S = 'in') Or (S = 'let') Or
    (S = 'loop') Or (S = 'match') Or (S = 'mod') Or
    (S = 'move') Or (S = 'mut') Or (S = 'pub') Or
    (S = 'ref') Or (S = 'return') Or (S = 'self') Or
    (S = 'Self') Or (S = 'static') Or (S = 'struct') Or
    (S = 'super') Or (S = 'trait') Or (S = 'true') Or
    (S = 'type') Or (S = 'unsafe') Or (S = 'use') Or
    (S = 'where') Or (S = 'while') Or
    (S = 'async') Or (S = 'await') Or (S = 'dyn');
End;

Function IsRustTodo5Keyword(Const S : TString) : Boolean;
Begin
  IsRustTodo5Keyword :=
    (S = 'fn') Or (S = 'pub') Or (S = 'let') Or (S = 'mut') Or
    (S = 'const') Or (S = 'static') Or (S = 'unsafe') Or
    (S = 'extern') Or (S = 'return') Or (S = 'if') Or
    (S = 'else') Or (S = 'while') Or (S = 'for') Or
    (S = 'in') Or (S = 'loop') Or (S = 'break') Or
    (S = 'match') Or (S = 'true') Or (S = 'false');
End;

Function IsSupportedMacro(Const S : TString) : Boolean;
Begin
  IsSupportedMacro :=
    (S = 'println') Or (S = 'debug_assert') Or (S = 'panic');
End;

Function RegClassName(RC : TRegClass) : TString;
Begin
  Case RC Of
    RC_NONE  : RegClassName := 'none';
    RC_BYTE  : RegClassName := 'byte';
    RC_WORD  : RegClassName := 'word';
    RC_DWORD : RegClassName := 'dword';
  Else
    RegClassName := '?';
  End;
End;

Function TypeKindName(K : TTypeKind) : TString;
Begin
  Case K Of
    TYK_PRIM : TypeKindName := 'prim';
    TYK_PTR  : TypeKindName := 'ptr';
  Else
    TypeKindName := '?';
  End;
End;

Procedure ClearTypeRec(Var T : TTypeRec);
Begin
  T.Name := '';
  T.Kind := TYK_PRIM;
  T.Size := 0;
  T.Align := 1;
  T.IsSigned := False;
  T.RegClass := RC_NONE;
  T.BaseType := TY_UNKNOWN;
  T.IsMutPtr := False;
End;

Function AddType(Const Name : TString; Kind : TTypeKind; Size, Align : Integer;
  IsSigned : Boolean; RegClass : TRegClass; BaseType : Integer;
  IsMutPtr : Boolean) : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
    FatalError('table des types pleine (MAX_TYPE=' + IntToStr_(MAX_TYPE) + ')');

  ClearTypeRec(TypeTab[TypeCount]);
  TypeTab[TypeCount].Name := Name;
  TypeTab[TypeCount].Kind := Kind;
  TypeTab[TypeCount].Size := Size;
  TypeTab[TypeCount].Align := Align;
  TypeTab[TypeCount].IsSigned := IsSigned;
  TypeTab[TypeCount].RegClass := RegClass;
  TypeTab[TypeCount].BaseType := BaseType;
  TypeTab[TypeCount].IsMutPtr := IsMutPtr;
  AddType := TypeCount;
  Inc(TypeCount);
End;

Function FindType(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  FindType := TY_UNKNOWN;
  For I := 0 To TypeCount - 1 Do
    If TypeTab[I].Name = Name Then
    Begin
      FindType := I;
      Exit;
    End;
End;

Function IsPrimitiveTypeName(Const Name : TString) : Boolean;
Begin
  IsPrimitiveTypeName := FindType(Name) <> TY_UNKNOWN;
End;

Function TypeSize(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx < 0) Or (TypeIdx >= TypeCount) Then
    TypeSize := 0
  Else
    TypeSize := TypeTab[TypeIdx].Size;
End;

Function TypeAlign(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx < 0) Or (TypeIdx >= TypeCount) Then
    TypeAlign := 1
  Else
    TypeAlign := TypeTab[TypeIdx].Align;
End;

Function TypeIsSigned(TypeIdx : Integer) : Boolean;
Begin
  If (TypeIdx < 0) Or (TypeIdx >= TypeCount) Then
    TypeIsSigned := False
  Else
    TypeIsSigned := TypeTab[TypeIdx].IsSigned;
End;

Function TypeRegClass(TypeIdx : Integer) : TRegClass;
Begin
  If (TypeIdx < 0) Or (TypeIdx >= TypeCount) Then
    TypeRegClass := RC_NONE
  Else
    TypeRegClass := TypeTab[TypeIdx].RegClass;
End;

Function AddRawPointerType(BaseType : Integer; IsMut : Boolean) : Integer;
Var
  Name     : TString;
  Existing : Integer;
Begin
  If (BaseType < 0) Or (BaseType >= TypeCount) Then
  Begin
    AddRawPointerType := TY_UNKNOWN;
    Exit;
  End;

  If IsMut Then
    Name := '*mut ' + TypeTab[BaseType].Name
  Else
    Name := '*const ' + TypeTab[BaseType].Name;

  Existing := FindType(Name);
  If Existing <> TY_UNKNOWN Then
  Begin
    AddRawPointerType := Existing;
    Exit;
  End;

  AddRawPointerType := AddType(Name, TYK_PTR, PTR_SIZE, PTR_SIZE, False,
    RC_DWORD, BaseType, IsMut);
End;

Procedure InitTypeTable;
Var
  I, TmpIdx, PtrIdx : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
    ClearTypeRec(TypeTab[I]);

  TmpIdx := AddType('i8', TYK_PRIM, 1, 1, True, RC_BYTE, TY_UNKNOWN, False);
  TmpIdx := AddType('u8', TYK_PRIM, 1, 1, False, RC_BYTE, TY_UNKNOWN, False);
  TmpIdx := AddType('i16', TYK_PRIM, 2, 2, True, RC_WORD, TY_UNKNOWN, False);
  TmpIdx := AddType('u16', TYK_PRIM, 2, 2, False, RC_WORD, TY_UNKNOWN, False);
  TmpIdx := AddType('i32', TYK_PRIM, 4, 4, True, RC_DWORD, TY_UNKNOWN, False);
  TmpIdx := AddType('u32', TYK_PRIM, 4, 4, False, RC_DWORD, TY_UNKNOWN, False);
  TmpIdx := AddType('isize', TYK_PRIM, PTR_SIZE, PTR_SIZE, True, RC_DWORD,
    TY_UNKNOWN, False);
  TmpIdx := AddType('usize', TYK_PRIM, PTR_SIZE, PTR_SIZE, False, RC_DWORD,
    TY_UNKNOWN, False);
  TmpIdx := AddType('bool', TYK_PRIM, 1, 1, False, RC_BYTE, TY_UNKNOWN, False);
  TmpIdx := AddType('char', TYK_PRIM, 4, 4, False, RC_DWORD, TY_UNKNOWN, False);
  TmpIdx := AddType('()', TYK_PRIM, 0, 1, False, RC_NONE, TY_UNKNOWN, False);
  If TmpIdx <> TY_IDX_UNIT Then
    FatalError('indice inattendu pour ()');
  PtrIdx := AddRawPointerType(TY_IDX_I16, False);
  If PtrIdx <> TY_IDX_PTR_I16 Then
    FatalError('indice inattendu pour *const i16');
  PtrIdx := AddRawPointerType(TY_IDX_I16, True);
  If PtrIdx <> TY_IDX_MPTR_I16 Then
    FatalError('indice inattendu pour *mut i16');
End;

Procedure DumpTypeTable;
Var
  I : Integer;
Begin
  If Not Opts.DebugMode Then Exit;
  WriteLn('--- Types Rust connus ---');
  For I := 0 To TypeCount - 1 Do
  Begin
    Write('  [', I, '] ', TypeTab[I].Name,
          ' kind=', TypeKindName(TypeTab[I].Kind),
          ' size=', TypeTab[I].Size,
          ' align=', TypeTab[I].Align,
          ' reg=', RegClassName(TypeTab[I].RegClass));
    If TypeTab[I].IsSigned Then
      Write(' signed')
    Else
      Write(' unsigned');
    If TypeTab[I].Kind = TYK_PTR Then
      Write(' base=', TypeTab[I].BaseType);
    WriteLn;
  End;
End;

Function ExtractExt(Const Path : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ExtractExt := StrLowerCase(Copy(Path, LastDot,
                     Length(Path) - LastDot + 1))
  Else
    ExtractExt := '';
End;

Function ReplaceExt(Const Path, NewExt : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ReplaceExt := Copy(Path, 1, LastDot - 1) + NewExt
  Else
    ReplaceExt := Path + NewExt;
End;

Function ExtractDir(Const Path : TString) : TString;
Var
  I, LastSep : Integer;
Begin
  LastSep := 0;
  For I := 1 To Length(Path) Do
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
  If LastSep > 0 Then
    ExtractDir := Copy(Path, 1, LastSep)
  Else
    ExtractDir := '';
End;

Function ExtractFileName_(Const Path : TString) : TString;
Var
  I, LastSep : Integer;
Begin
  LastSep := 0;
  For I := 1 To Length(Path) Do
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
  If LastSep > 0 Then
    ExtractFileName_ := Copy(Path, LastSep + 1, Length(Path) - LastSep)
  Else
    ExtractFileName_ := Path;
End;

Function RemoveExt(Const Path : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    RemoveExt := Copy(Path, 1, LastDot - 1)
  Else
    RemoveExt := Path;
End;

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('RUSTCW32: FATAL: ', Msg);
  Inc(ErrorCount);
  If SourceOpened Then
  Begin
    Close(SourceF);
    SourceOpened := False;
  End;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('RUSTCW32: warning: ', Msg);
  Inc(WarnCount);
End;

{ ------------------------------------------------------------ }
{ Options, aide et arguments                                   }
{ ------------------------------------------------------------ }

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
  Opts.EmitExe   := True;
  Opts.EmitObj   := False;
  Opts.EmitAsm   := False;
  Opts.NoLink    := False;
  Opts.OptLevel  := OPT_NONE;
End;

Procedure ShowHelp;
Begin
  WriteLn('RUSTCW32 v', RUSTCW32_VERSION, ' (', RUSTCW32_DATE,
          ') - Cette commande permet de lancer le compilateur Rust ',
          'pour l''assembleur du microprocesseur 80386 pour Windows (PE Win32).');
  WriteLn;
  WriteLn('Syntaxe : RUSTCW32 <source.rs> [-o sortie] [options]');
  WriteLn;
  WriteLn('Sortie :');
  WriteLn('  Par defaut     Produire un .EXE PE Windows 32 bits');
  WriteLn('  -obj           Produire seulement un .OBJ COFF');
  WriteLn('  -asm           Produire egalement un .ASM lisible');
  WriteLn('  -o <fichier>   Nom de la sortie principale');
  WriteLn;
  WriteLn('Optimisation :');
  WriteLn('  -O0            Pas d''optimisation (defaut)');
  WriteLn('  -O1            Optimisations de base');
  WriteLn('  -O2            Optimisations avancees');
  WriteLn;
  WriteLn('General :');
  WriteLn('  -v             Mode verbeux');
  WriteLn('  -d             Debug tokens (pour TODO lexer)');
  WriteLn('  -w             Afficher les avertissements');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  RUSTCW32 SAMPLES\RUST\hello.rs');
  WriteLn('  RUSTCW32 SAMPLES\RUST\math.rs -asm -O1');
  WriteLn('  RUSTCW32 SAMPLES\RUST\control.rs -obj -o control.obj');
End;

Procedure UsageError(Const Msg : TString);
Begin
  WriteLn('RUSTCW32: ', Msg);
  WriteLn;
  ShowHelp;
  Halt(EXIT_USAGE);
End;

Procedure ValidateOutputName;
Var
  Ext : TString;
Begin
  Ext := ExtractExt(Opts.OutFile);
  If Opts.EmitObj Then
  Begin
    If Ext = '' Then
      Opts.OutFile := Opts.OutFile + '.obj'
    Else If Ext <> '.obj' Then
      FatalError('avec -obj, la sortie principale doit etre un .OBJ: '
        + Opts.OutFile);
  End
  Else
  Begin
    If Ext = '' Then
      Opts.OutFile := Opts.OutFile + '.exe'
    Else If Ext <> '.exe' Then
      FatalError('par defaut, la sortie principale doit etre un .EXE: '
        + Opts.OutFile);
  End;
End;

Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
  Ext : TString;
Begin
  InitOptions;

  If ParamCount = 0 Then
  Begin
    ShowHelp;
    Halt(EXIT_USAGE);
  End;

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Or
       (Arg = '/h') Or (Arg = '/H') Then
    Begin
      ShowHelp;
      Halt(EXIT_OK);
    End
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg = '-asm' Then
      Opts.EmitAsm := True
    Else If Arg = '-obj' Then
    Begin
      Opts.EmitExe := False;
      Opts.EmitObj := True;
      Opts.NoLink  := True;
    End
    Else If Arg = '-O0' Then
      Opts.OptLevel := OPT_NONE
    Else If Arg = '-O1' Then
      Opts.OptLevel := OPT_BASIC
    Else If Arg = '-O2' Then
      Opts.OptLevel := OPT_ADVANCED
    Else If Arg = '-o' Then
    Begin
      Inc(I);
      If I > ParamCount Then
        UsageError('option -o sans nom de fichier');
      If Opts.OutFile <> '' Then
        FatalError('sortie deja specifiee: ' + Opts.OutFile);
      Opts.OutFile := ParamStr(I);
    End
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
      FatalError('option inconnue: ' + Arg)
    Else
    Begin
      If Opts.SrcFile = '' Then
        Opts.SrcFile := Arg
      Else If Opts.OutFile = '' Then
        Opts.OutFile := Arg
      Else
        FatalError('argument inattendu: ' + Arg);
    End;

    Inc(I);
  End;

  If Opts.SrcFile = '' Then
    UsageError('fichier source manquant');

  Ext := ExtractExt(Opts.SrcFile);
  If Ext <> '.rs' Then
    FatalError('extension source attendue .rs, trouvee: ' + Ext);

  If Opts.OutFile = '' Then
  Begin
    If Opts.EmitObj Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj')
    Else
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe');
  End
  Else
    ValidateOutputName;
End;

Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('RUSTCW32 v', RUSTCW32_VERSION, ' (', RUSTCW32_DATE,
          ') - Rust -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.EmitObj Then
    WriteLn('Format   : OBJ COFF')
  Else
    WriteLn('Format   : EXE PE Win32');
  If Opts.EmitAsm Then
    WriteLn('ASM      : ', ReplaceExt(Opts.OutFile, '.asm'));
  WriteLn('Optim    : -O', IntToStr_(Opts.OptLevel));
  If Opts.NoLink Then
    WriteLn('Link     : desactive');
  WriteLn;
End;

Procedure ShowStats;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('Lignes lues    : ', TotalLines);
  WriteLn('Tokens lus     : ', TokenCount);
  WriteLn('Macros lues    : ', MacroCount);
  WriteLn('Types connus   : ', TypeCount);
  WriteLn('Symboles       : ', SymCount);
  WriteLn('Fonctions      : ', ProcCount);
  WriteLn('Constantes     : ', ConstCount);
  WriteLn('Statics        : ', StaticCount);
  WriteLn('Blocs          : ', BlockCount);
  WriteLn('Instructions   : ', StmtCount);
  WriteLn('Locales        : ', LocalCount);
  WriteLn('Boucles        : ', LoopCount);
  WriteLn('Expressions    : ', ExprCount);
  WriteLn('Instr. ASM     : ', ArithInstrCount);
  WriteLn('Stores         : ', StoreInstrCount);
  WriteLn('Erreurs        : ', ErrorCount);
  WriteLn('Avertissements : ', WarnCount);
End;

{ ============================================================ }
{ LECTURE SOURCE ET DIAGNOSTICS                                }
{ ============================================================ }

Procedure SourceInit;
Begin
  SourceOpened := False;
  SourceFile   := '';
  SourceDir    := '';
  SourceModule := '';
  SourceLine   := '';
  SourceLineNo := 0;
  SourceColNo  := 1;
  SourceEOF    := True;
End;

Procedure SourceOpen(Const FileName : TString);
Var
  Code : Integer;
Begin
  SourceInit;
  SourceFile   := FileName;
  SourceDir    := ExtractDir(FileName);
  SourceModule := RemoveExt(ExtractFileName_(FileName));

  Assign(SourceF, FileName);
  {$I-}
  Reset(SourceF);
  {$I+}
  Code := IOResult;
  If Code <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + FileName);

  SourceOpened := True;
  SourceEOF    := False;
End;

Procedure SourceClose;
Begin
  If SourceOpened Then
  Begin
    Close(SourceF);
    SourceOpened := False;
  End;
End;

Function SourceReadLine : Boolean;
Var
  Code : Integer;
Begin
  If (Not SourceOpened) Or SourceEOF Then
  Begin
    SourceReadLine := False;
    Exit;
  End;

  If EOF(SourceF) Then
  Begin
    SourceEOF := True;
    SourceLine := '';
    SourceColNo := 1;
    SourceReadLine := False;
    Exit;
  End;

  {$I-}
  ReadLn(SourceF, SourceLine);
  {$I+}
  Code := IOResult;
  If Code <> 0 Then
  Begin
    SourceEOF := True;
    SourceReadLine := False;
    FatalError('erreur de lecture dans le fichier source: ' + SourceFile);
  End;

  Inc(SourceLineNo);
  Inc(TotalLines);
  SourceColNo := 1;
  SourceReadLine := True;
End;

Procedure ReportErrorAt(Line, Col : Integer; Const Token, Msg : TString);
Var
  I : Integer;
Begin
  Inc(ErrorCount);
  WriteLn(SourceFile, '(', Line, ',', Col, '): error: ', Msg);
  If Token <> '' Then
    WriteLn('  token: ', Token);
  If (Line = SourceLineNo) And (SourceLine <> '') Then
  Begin
    WriteLn('  ', SourceLine);
    Write('  ');
    For I := 1 To Col - 1 Do
      Write(' ');
    WriteLn('^');
  End;
  If ErrorCount >= MAX_ERRORS Then
  Begin
    WriteLn('RUSTCW32: FATAL: trop d''erreurs (max ',
            MAX_ERRORS, ')');
    SourceClose;
    Halt(EXIT_ERROR);
  End;
End;

Procedure ReportError(Const Msg : TString);
Begin
  ReportErrorAt(SourceLineNo, SourceColNo, '', Msg);
End;

{ ============================================================ }
{ TABLE DES SYMBOLES ET PORTEES                                }
{ ============================================================ }

Function SymCatName(Cat : TSymCat) : TString;
Begin
  Case Cat Of
    SC_GLOBAL : SymCatName := 'global';
    SC_FN     : SymCatName := 'fn';
    SC_PARAM  : SymCatName := 'param';
    SC_LOCAL  : SymCatName := 'local';
    SC_CONST  : SymCatName := 'const';
    SC_STATIC : SymCatName := 'static';
    SC_EXTERN : SymCatName := 'extern';
    SC_LABEL  : SymCatName := 'label';
  Else
    SymCatName := '?';
  End;
End;

Procedure ClearSymRec(Var S : TSymRec);
Begin
  S.Name := '';
  S.MangledName := '';
  S.Cat := SC_GLOBAL;
  S.TypeIdx := TY_UNKNOWN;
  S.ScopeLevel := 0;
  S.Offset := 0;
  S.IsMut := False;
  S.IsDefined := False;
  S.DeclLine := 0;
  S.DeclCol := 0;
End;

Procedure InitSymbolTable;
Var
  I : Integer;
Begin
  SymCount := 0;
  ScopeLevel := 0;
  LabelSerial := 0;
  LoopDepth := 0;
  For I := 0 To MAX_SYM - 1 Do
    ClearSymRec(SymTab[I]);
  For I := 0 To MAX_SCOPE - 1 Do
    ScopeBase[I] := 0;
  For I := 0 To MAX_LOOP_NEST - 1 Do
  Begin
    LoopContinue[I] := '';
    LoopBreak[I] := '';
  End;
  ScopeBase[0] := 0;
End;

Procedure EnterScope;
Begin
  If ScopeLevel >= MAX_SCOPE - 1 Then
    FatalError('profondeur de portee depassee (MAX_SCOPE='
      + IntToStr_(MAX_SCOPE) + ')');
  Inc(ScopeLevel);
  ScopeBase[ScopeLevel] := SymCount;
End;

Procedure LeaveScope;
Var
  I : Integer;
Begin
  If ScopeLevel <= 0 Then
    FatalError('tentative de sortie de la portee globale');
  For I := ScopeBase[ScopeLevel] To SymCount - 1 Do
    ClearSymRec(SymTab[I]);
  SymCount := ScopeBase[ScopeLevel];
  ScopeBase[ScopeLevel] := 0;
  Dec(ScopeLevel);
End;

Function FindSymInScope(Const Name : TString; Level : Integer) : Integer;
Var
  I, First : Integer;
Begin
  FindSymInScope := -1;
  If (Level < 0) Or (Level > ScopeLevel) Then
    Exit;
  First := ScopeBase[Level];
  For I := SymCount - 1 DownTo First Do
    If (SymTab[I].ScopeLevel = Level) And (SymTab[I].Name = Name) Then
    Begin
      FindSymInScope := I;
      Exit;
    End;
End;

Function FindSym(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  FindSym := -1;
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].Name = Name Then
    Begin
      FindSym := I;
      Exit;
    End;
End;

Function AddSym(Const Name : TString; Cat : TSymCat; TypeIdx : Integer;
  IsMut, IsDefined : Boolean; Offset : LongInt; Const MangledName : TString;
  Line, Col : Integer) : Integer;
Var
  Existing : Integer;
Begin
  AddSym := -1;
  If Name = '' Then
  Begin
    ReportErrorAt(Line, Col, '', 'nom de symbole vide');
    Exit;
  End;
  If SymCount >= MAX_SYM Then
    FatalError('table des symboles pleine (MAX_SYM='
      + IntToStr_(MAX_SYM) + ')');

  Existing := FindSymInScope(Name, ScopeLevel);
  If Existing >= 0 Then
  Begin
    ReportErrorAt(Line, Col, Name, 'redeclaration dans la meme portee');
    WriteLn('  declaration precedente: ',
      SymTab[Existing].DeclLine, ',', SymTab[Existing].DeclCol);
    Exit;
  End;

  ClearSymRec(SymTab[SymCount]);
  SymTab[SymCount].Name := Name;
  SymTab[SymCount].Cat := Cat;
  SymTab[SymCount].TypeIdx := TypeIdx;
  SymTab[SymCount].ScopeLevel := ScopeLevel;
  SymTab[SymCount].Offset := Offset;
  SymTab[SymCount].IsMut := IsMut;
  SymTab[SymCount].IsDefined := IsDefined;
  SymTab[SymCount].DeclLine := Line;
  SymTab[SymCount].DeclCol := Col;
  If MangledName <> '' Then
    SymTab[SymCount].MangledName := MangledName
  Else If Cat = SC_FN Then
    SymTab[SymCount].MangledName := RS_FN_PFX + Name
  Else If Cat = SC_STATIC Then
    SymTab[SymCount].MangledName := RS_VAR_PFX + Name
  Else If Cat = SC_EXTERN Then
    SymTab[SymCount].MangledName := RS_EXT_PFX + Name
  Else If Cat = SC_LABEL Then
    SymTab[SymCount].MangledName := RS_LABEL_PFX + Name
  Else
    SymTab[SymCount].MangledName := Name;

  AddSym := SymCount;
  Inc(SymCount);
End;

Function CanAssignToSym(SymIdx : Integer) : Boolean;
Begin
  If (SymIdx < 0) Or (SymIdx >= SymCount) Then
    CanAssignToSym := False
  Else
    CanAssignToSym :=
      ((SymTab[SymIdx].Cat = SC_LOCAL) Or
       (SymTab[SymIdx].Cat = SC_STATIC)) And SymTab[SymIdx].IsMut;
End;

Procedure RequireAssignable(SymIdx, Line, Col : Integer);
Begin
  If (SymIdx < 0) Or (SymIdx >= SymCount) Then
  Begin
    ReportErrorAt(Line, Col, '', 'symbole inconnu pour affectation');
    Exit;
  End;
  If (SymTab[SymIdx].Cat <> SC_LOCAL) And
     (SymTab[SymIdx].Cat <> SC_STATIC) Then
    ReportErrorAt(Line, Col, SymTab[SymIdx].Name,
      'affectation seulement permise vers let mut ou static mut')
  Else If Not CanAssignToSym(SymIdx) Then
    ReportErrorAt(Line, Col, SymTab[SymIdx].Name,
      'affectation vers let/static immuable; utiliser mut');
End;

Function NewLabelName : TString;
Begin
  Inc(LabelSerial);
  NewLabelName := RS_LABEL_PFX + IntToStr_(LabelSerial);
End;

Function AddLabelSymbol(Const BaseName : TString; Line, Col : Integer) : Integer;
Var
  Name : TString;
Begin
  Inc(LabelSerial);
  If BaseName <> '' Then
    Name := RS_LABEL_PFX + BaseName + '_' + IntToStr_(LabelSerial)
  Else
    Name := RS_LABEL_PFX + IntToStr_(LabelSerial);
  AddLabelSymbol := AddSym(Name, SC_LABEL, TY_IDX_UNIT, False, True, 0,
    Name, Line, Col);
End;

Procedure PushLoopLabels(Const ContinueLabel, BreakLabel : TString;
  Line, Col : Integer);
Begin
  If LoopDepth >= MAX_LOOP_NEST Then
  Begin
    ReportErrorAt(Line, Col, '', 'imbrication de boucles trop profonde');
    Exit;
  End;
  LoopContinue[LoopDepth] := ContinueLabel;
  LoopBreak[LoopDepth] := BreakLabel;
  Inc(LoopDepth);
End;

Procedure PopLoopLabels;
Begin
  If LoopDepth <= 0 Then
    Exit;
  Dec(LoopDepth);
  LoopContinue[LoopDepth] := '';
  LoopBreak[LoopDepth] := '';
End;

Function CurrentLoopBreak : TString;
Begin
  If LoopDepth <= 0 Then
    CurrentLoopBreak := ''
  Else
    CurrentLoopBreak := LoopBreak[LoopDepth - 1];
End;

Function CurrentLoopContinue : TString;
Begin
  If LoopDepth <= 0 Then
    CurrentLoopContinue := ''
  Else
    CurrentLoopContinue := LoopContinue[LoopDepth - 1];
End;

Procedure DumpSymbolTable;
Var
  I : Integer;
Begin
  If Not Opts.DebugMode Then Exit;
  WriteLn('--- Symboles connus ---');
  If SymCount = 0 Then
  Begin
    WriteLn('  (aucun)');
    Exit;
  End;
  For I := 0 To SymCount - 1 Do
  Begin
    Write('  [', I, '] ', SymTab[I].Name,
          ' cat=', SymCatName(SymTab[I].Cat),
          ' scope=', SymTab[I].ScopeLevel,
          ' type=', SymTab[I].TypeIdx,
          ' asm=', SymTab[I].MangledName);
    If SymTab[I].IsMut Then
      Write(' mut');
    If SymTab[I].IsDefined Then
      Write(' defined');
    WriteLn;
  End;
End;

{ ============================================================ }
{ SIGNATURES DE FONCTIONS                                      }
{ ============================================================ }

Procedure ClearProcRec(Var P : TProcRec);
Var
  I : Integer;
Begin
  P.Name := '';
  P.MangledName := '';
  P.RetTypeIdx := TY_IDX_UNIT;
  P.ParamCount := 0;
  For I := 0 To MAX_PARAM - 1 Do
  Begin
    P.ParamNames[I] := '';
    P.ParamTypes[I] := TY_UNKNOWN;
  End;
  P.IsPublic := False;
  P.IsExtern := False;
  P.IsMain := False;
  P.SymIdx := -1;
  P.DeclLine := 0;
  P.DeclCol := 0;
End;

Procedure InitProcTable;
Var
  I : Integer;
Begin
  ProcCount := 0;
  MainProcIdx := -1;
  For I := 0 To MAX_PROC - 1 Do
    ClearProcRec(ProcTab[I]);
End;

Function FindProc(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  FindProc := -1;
  For I := 0 To ProcCount - 1 Do
    If ProcTab[I].Name = Name Then
    Begin
      FindProc := I;
      Exit;
    End;
End;

Function AddProc(Const Name : TString; RetTypeIdx : Integer; IsPublic,
  IsExtern : Boolean; SymIdx, Line, Col : Integer) : Integer;
Begin
  AddProc := -1;
  If ProcCount >= MAX_PROC Then
    FatalError('table des fonctions pleine (MAX_PROC='
      + IntToStr_(MAX_PROC) + ')');
  If FindProc(Name) >= 0 Then
  Begin
    ReportErrorAt(Line, Col, Name, 'fonction deja declaree');
    Exit;
  End;

  ClearProcRec(ProcTab[ProcCount]);
  ProcTab[ProcCount].Name := Name;
  If IsExtern Then
    ProcTab[ProcCount].MangledName := RS_EXT_PFX + Name
  Else
    ProcTab[ProcCount].MangledName := RS_FN_PFX + Name;
  ProcTab[ProcCount].RetTypeIdx := RetTypeIdx;
  ProcTab[ProcCount].IsPublic := IsPublic;
  ProcTab[ProcCount].IsExtern := IsExtern;
  ProcTab[ProcCount].IsMain := Name = 'main';
  ProcTab[ProcCount].SymIdx := SymIdx;
  ProcTab[ProcCount].DeclLine := Line;
  ProcTab[ProcCount].DeclCol := Col;
  If ProcTab[ProcCount].IsMain Then
  Begin
    If MainProcIdx >= 0 Then
      ReportErrorAt(Line, Col, Name, 'plusieurs fonctions main');
    MainProcIdx := ProcCount;
  End;
  AddProc := ProcCount;
  Inc(ProcCount);
End;

Procedure AddProcParam(ProcIdx : Integer; Const Name : TString;
  TypeIdx, Line, Col : Integer);
Var
  N : Integer;
Begin
  If (ProcIdx < 0) Or (ProcIdx >= ProcCount) Then Exit;
  N := ProcTab[ProcIdx].ParamCount;
  If N >= MAX_PARAM Then
  Begin
    ReportErrorAt(Line, Col, Name, 'trop de parametres');
    Exit;
  End;
  ProcTab[ProcIdx].ParamNames[N] := Name;
  ProcTab[ProcIdx].ParamTypes[N] := TypeIdx;
  Inc(ProcTab[ProcIdx].ParamCount);
End;

Procedure DumpProcTable;
Var
  I, J : Integer;
Begin
  If Not Opts.DebugMode Then Exit;
  WriteLn('--- Fonctions Rust reconnues ---');
  If ProcCount = 0 Then
  Begin
    WriteLn('  (aucune)');
    Exit;
  End;
  For I := 0 To ProcCount - 1 Do
  Begin
    Write('  [', I, '] ', ProcTab[I].Name,
          ' asm=', ProcTab[I].MangledName,
          ' ret=', ProcTab[I].RetTypeIdx,
          ' params=', ProcTab[I].ParamCount);
    If ProcTab[I].IsPublic Then Write(' pub');
    If ProcTab[I].IsExtern Then Write(' extern');
    If ProcTab[I].IsMain Then Write(' main');
    WriteLn;
    For J := 0 To ProcTab[I].ParamCount - 1 Do
      WriteLn('      param ', J, ': ', ProcTab[I].ParamNames[J],
              ' type=', ProcTab[I].ParamTypes[J]);
  End;
End;

{ ============================================================ }
{ CONSTANTES ET STATICS                                        }
{ ============================================================ }

Procedure ClearConstRec(Var C : TConstRec);
Begin
  C.Name := '';
  C.TypeIdx := TY_UNKNOWN;
  C.IntValue := 0;
  C.HasIntVal := False;
  C.SymIdx := -1;
  C.DeclLine := 0;
  C.DeclCol := 0;
End;

Procedure ClearStaticRec(Var S : TStaticRec);
Begin
  S.Name := '';
  S.MangledName := '';
  S.TypeIdx := TY_UNKNOWN;
  S.IntValue := 0;
  S.HasInit := False;
  S.IsMut := False;
  S.SymIdx := -1;
  S.DeclLine := 0;
  S.DeclCol := 0;
End;

Procedure InitConstStaticTables;
Var
  I : Integer;
Begin
  ConstCount := 0;
  StaticCount := 0;
  For I := 0 To MAX_CONST - 1 Do
    ClearConstRec(ConstTab[I]);
  For I := 0 To MAX_STATIC - 1 Do
    ClearStaticRec(StaticTab[I]);
End;

Function AddConstRec(Const Name : TString; TypeIdx : Integer; IntValue : LongInt;
  HasIntVal : Boolean; SymIdx, Line, Col : Integer) : Integer;
Begin
  AddConstRec := -1;
  If ConstCount >= MAX_CONST Then
    FatalError('table des constantes pleine (MAX_CONST='
      + IntToStr_(MAX_CONST) + ')');
  ClearConstRec(ConstTab[ConstCount]);
  ConstTab[ConstCount].Name := Name;
  ConstTab[ConstCount].TypeIdx := TypeIdx;
  ConstTab[ConstCount].IntValue := IntValue;
  ConstTab[ConstCount].HasIntVal := HasIntVal;
  ConstTab[ConstCount].SymIdx := SymIdx;
  ConstTab[ConstCount].DeclLine := Line;
  ConstTab[ConstCount].DeclCol := Col;
  AddConstRec := ConstCount;
  Inc(ConstCount);
End;

Function AddStaticRec(Const Name : TString; TypeIdx : Integer; IntValue : LongInt;
  HasInit, IsMut : Boolean; SymIdx, Line, Col : Integer) : Integer;
Begin
  AddStaticRec := -1;
  If StaticCount >= MAX_STATIC Then
    FatalError('table des statics pleine (MAX_STATIC='
      + IntToStr_(MAX_STATIC) + ')');
  ClearStaticRec(StaticTab[StaticCount]);
  StaticTab[StaticCount].Name := Name;
  StaticTab[StaticCount].MangledName := RS_VAR_PFX + Name;
  StaticTab[StaticCount].TypeIdx := TypeIdx;
  StaticTab[StaticCount].IntValue := IntValue;
  StaticTab[StaticCount].HasInit := HasInit;
  StaticTab[StaticCount].IsMut := IsMut;
  StaticTab[StaticCount].SymIdx := SymIdx;
  StaticTab[StaticCount].DeclLine := Line;
  StaticTab[StaticCount].DeclCol := Col;
  AddStaticRec := StaticCount;
  Inc(StaticCount);
End;

Procedure DumpConstStaticTables;
Var
  I : Integer;
Begin
  If Not Opts.DebugMode Then Exit;
  WriteLn('--- Constantes Rust reconnues ---');
  If ConstCount = 0 Then
    WriteLn('  (aucune)');
  For I := 0 To ConstCount - 1 Do
  Begin
    Write('  [', I, '] ', ConstTab[I].Name,
          ' type=', ConstTab[I].TypeIdx);
    If ConstTab[I].HasIntVal Then
      Write(' value=', ConstTab[I].IntValue)
    Else
      Write(' value=?');
    WriteLn;
  End;

  WriteLn('--- Statics Rust reconnus ---');
  If StaticCount = 0 Then
    WriteLn('  (aucun)');
  For I := 0 To StaticCount - 1 Do
  Begin
    Write('  [', I, '] ', StaticTab[I].Name,
          ' asm=', StaticTab[I].MangledName,
          ' type=', StaticTab[I].TypeIdx);
    If StaticTab[I].IsMut Then
      Write(' mut');
    If StaticTab[I].HasInit Then
      Write(' data=', StaticTab[I].IntValue)
    Else
      Write(' bss');
    WriteLn;
  End;
End;

{ ============================================================ }
{ BACKEND ARITHMETIQUE 80386                                  }
{ ============================================================ }

Procedure InitBackend;
Var
  I : Integer;
Begin
  AsmTraceCount := 0;
  ArithInstrCount := 0;
  StoreInstrCount := 0;
  For I := 0 To MAX_ASM_TRACE - 1 Do
    AsmTrace[I] := '';
End;

Procedure EmitAsm(Const Line : TString);
Begin
  Inc(ArithInstrCount);
  If AsmTraceCount < MAX_ASM_TRACE Then
  Begin
    AsmTrace[AsmTraceCount] := Line;
    Inc(AsmTraceCount);
  End
  Else If AsmTraceCount = MAX_ASM_TRACE Then
  Begin
    AsmTrace[MAX_ASM_TRACE - 1] := '; trace ASM tronquee';
    Inc(AsmTraceCount);
  End;
End;

Function TypeIsSignedInt(TypeIdx : Integer) : Boolean;
Begin
  TypeIsSignedInt :=
    ((TypeIdx = TY_IDX_I8) Or (TypeIdx = TY_IDX_U8) Or
     (TypeIdx = TY_IDX_I16) Or (TypeIdx = TY_IDX_U16) Or
     (TypeIdx = TY_IDX_I32) Or (TypeIdx = TY_IDX_U32) Or
     (TypeIdx = TY_IDX_ISIZE) Or (TypeIdx = TY_IDX_USIZE)) And
    TypeIsSigned(TypeIdx);
End;

Function TypeAsmWidth(TypeIdx : Integer) : TString;
Begin
  Case TypeRegClass(TypeIdx) Of
    RC_BYTE  : TypeAsmWidth := 'BYTE';
    RC_WORD  : TypeAsmWidth := 'WORD';
    RC_DWORD : TypeAsmWidth := 'DWORD';
  Else
    TypeAsmWidth := 'DWORD';
  End;
End;

Procedure EmitExtendToEax(TypeIdx : Integer);
Begin
  If TypeIdx = TY_UNKNOWN Then
    Exit;
  Case TypeRegClass(TypeIdx) Of
    RC_BYTE:
      If TypeIsSigned(TypeIdx) Then
        EmitAsm('  MOVSX EAX, AL')
      Else
        EmitAsm('  MOVZX EAX, AL');
    RC_WORD:
      If TypeIsSigned(TypeIdx) Then
        EmitAsm('  MOVSX EAX, AX')
      Else
        EmitAsm('  MOVZX EAX, AX');
  End;
End;

Procedure EmitExprLoad(Const E : TExprRec; Const RegName : TString);
Begin
  If E.Kind = EK_LITERAL Then
    EmitAsm('  MOV ' + RegName + ', ' + IntToStr_(E.IntValue))
  Else If E.Kind = EK_VAR Then
    EmitAsm('  ; charger variable dans ' + RegName + ' (' +
      TypeAsmWidth(E.TypeIdx) + ')')
  Else If E.Kind = EK_CALL Then
    EmitAsm('  ; resultat appel deja dans EAX')
  Else
    EmitAsm('  ; valeur intermediaire dans ' + RegName);
End;

Function StackAddr(Offset : LongInt) : TString;
Begin
  If Offset < 0 Then
    StackAddr := '[EBP-' + IntToStr_(-Offset) + ']'
  Else If Offset > 0 Then
    StackAddr := '[EBP+' + IntToStr_(Offset) + ']'
  Else
    StackAddr := '[EBP]';
End;

Function StoreRegForType(TypeIdx : Integer) : TString;
Begin
  Case TypeRegClass(TypeIdx) Of
    RC_BYTE  : StoreRegForType := 'AL';
    RC_WORD  : StoreRegForType := 'AX';
    RC_DWORD : StoreRegForType := 'EAX';
  Else
    StoreRegForType := 'EAX';
  End;
End;

Procedure EmitStoreSym(SymIdx : Integer; Const ValueExpr : TExprRec;
  IsInitialization : Boolean);
Var
  Addr, Prefix : TString;
  TypeIdx : Integer;
Begin
  If (SymIdx < 0) Or (SymIdx >= SymCount) Then
    Exit;

  TypeIdx := SymTab[SymIdx].TypeIdx;
  If TypeIdx = TY_UNKNOWN Then
    TypeIdx := ValueExpr.TypeIdx;
  EmitExprLoad(ValueExpr, 'EAX');
  EmitExtendToEax(ValueExpr.TypeIdx);

  If SymTab[SymIdx].Cat = SC_STATIC Then
    Addr := '[' + SymTab[SymIdx].MangledName + ']'
  Else If (SymTab[SymIdx].Cat = SC_LOCAL) Or
          (SymTab[SymIdx].Cat = SC_PARAM) Then
    Addr := StackAddr(SymTab[SymIdx].Offset)
  Else
    Addr := '[' + SymTab[SymIdx].MangledName + ']';

  If IsInitialization Then
    Prefix := '  ; initialiser '
  Else
    Prefix := '  ; stocker ';
  EmitAsm(Prefix + SymTab[SymIdx].Name);
  EmitAsm('  MOV ' + TypeAsmWidth(TypeIdx) + ' PTR ' + Addr + ', ' +
    StoreRegForType(TypeIdx));
  Inc(StoreInstrCount);
End;

Procedure EmitLabel(Const LabelName : TString);
Begin
  EmitAsm(LabelName + ':');
End;

Procedure EmitJump(Const LabelName : TString);
Begin
  EmitAsm('  JMP ' + LabelName);
End;

Procedure EmitConditionFalseJump(Const CondExpr : TExprRec;
  Const FalseLabel : TString);
Begin
  If (CondExpr.Kind = EK_LITERAL) Or (CondExpr.Kind = EK_VAR) Then
  Begin
    EmitExprLoad(CondExpr, 'EAX');
    EmitExtendToEax(CondExpr.TypeIdx);
  End
  Else If CondExpr.Kind = EK_CALL Then
    EmitAsm('  ; condition: resultat appel deja dans EAX')
  Else
    EmitAsm('  ; condition: resultat expression deja dans EAX');

  EmitAsm('  CMP EAX, 0');
  EmitAsm('  JE ' + FalseLabel);
End;

Procedure EmitUnaryArith(Const Op : TString; Const E : TExprRec);
Begin
  If Op = '-' Then
  Begin
    EmitExprLoad(E, 'EAX');
    EmitExtendToEax(E.TypeIdx);
    EmitAsm('  NEG EAX');
  End
  Else If Op = '!' Then
  Begin
    EmitExprLoad(E, 'EAX');
    EmitExtendToEax(E.TypeIdx);
    EmitAsm('  CMP EAX, 0');
    EmitAsm('  SETE AL');
    EmitAsm('  MOVZX EAX, AL');
  End
  Else If Op = '*' Then
    EmitAsm('  ; dereferencement brut differe au backend pointeurs')
  Else If Op = '&' Then
    EmitAsm('  ; adresse brute differee au backend pointeurs');
End;

Procedure EmitSetcc(Const Op : TString; SignedCmp : Boolean);
Var
  Mn : TString;
Begin
  Mn := 'SETE';
  If Op = '==' Then Mn := 'SETE'
  Else If Op = '!=' Then Mn := 'SETNE'
  Else If SignedCmp Then
  Begin
    If Op = '<' Then Mn := 'SETL'
    Else If Op = '<=' Then Mn := 'SETLE'
    Else If Op = '>' Then Mn := 'SETG'
    Else If Op = '>=' Then Mn := 'SETGE';
  End
  Else
  Begin
    If Op = '<' Then Mn := 'SETB'
    Else If Op = '<=' Then Mn := 'SETBE'
    Else If Op = '>' Then Mn := 'SETA'
    Else If Op = '>=' Then Mn := 'SETAE';
  End;
  EmitAsm('  ' + Mn + ' AL');
  EmitAsm('  MOVZX EAX, AL');
End;

Procedure EmitBinaryArith(Const Op : TString; Const Left, Right : TExprRec;
  ResultType : Integer);
Var
  SignedOp : Boolean;
Begin
  If (Op <> '+') And (Op <> '-') And (Op <> '*') And
     (Op <> '/') And (Op <> '%') And (Op <> '==') And
     (Op <> '!=') And (Op <> '<') And (Op <> '<=') And
     (Op <> '>') And (Op <> '>=') And (Op <> '&&') And
     (Op <> '||') Then
    Exit;

  EmitExprLoad(Left, 'EAX');
  EmitExtendToEax(Left.TypeIdx);
  EmitAsm('  PUSH EAX');
  EmitExprLoad(Right, 'EAX');
  EmitExtendToEax(Right.TypeIdx);
  EmitAsm('  MOV EBX, EAX');
  EmitAsm('  POP EAX');

  SignedOp := TypeIsSignedInt(ResultType) Or TypeIsSignedInt(Left.TypeIdx) Or
    TypeIsSignedInt(Right.TypeIdx);

  If (Op = '-') And (Left.Kind = EK_LITERAL) And Left.IsConst And
     (Left.IntValue = 0) Then
  Begin
    EmitExprLoad(Right, 'EAX');
    EmitExtendToEax(Right.TypeIdx);
    EmitAsm('  NEG EAX');
  End
  Else If Op = '+' Then
    EmitAsm('  ADD EAX, EBX')
  Else If Op = '-' Then
    EmitAsm('  SUB EAX, EBX')
  Else If Op = '*' Then
    EmitAsm('  IMUL EBX')
  Else If (Op = '/') Or (Op = '%') Then
  Begin
    If SignedOp Then
    Begin
      EmitAsm('  CDQ');
      EmitAsm('  IDIV EBX');
    End
    Else
    Begin
      EmitAsm('  XOR EDX, EDX');
      EmitAsm('  DIV EBX');
    End;
    If Op = '%' Then
      EmitAsm('  MOV EAX, EDX');
  End
  Else If (Op = '==') Or (Op = '!=') Or (Op = '<') Or (Op = '<=') Or
          (Op = '>') Or (Op = '>=') Then
  Begin
    EmitAsm('  CMP EAX, EBX');
    EmitSetcc(Op, SignedOp);
  End
  Else If Op = '&&' Then
  Begin
    EmitAsm('  CMP EAX, 0');
    EmitAsm('  SETNE AL');
    EmitAsm('  CMP EBX, 0');
    EmitAsm('  SETNE BL');
    EmitAsm('  AND AL, BL');
    EmitAsm('  MOVZX EAX, AL');
  End
  Else If Op = '||' Then
  Begin
    EmitAsm('  CMP EAX, 0');
    EmitAsm('  SETNE AL');
    EmitAsm('  CMP EBX, 0');
    EmitAsm('  SETNE BL');
    EmitAsm('  OR AL, BL');
    EmitAsm('  MOVZX EAX, AL');
  End;
End;

Procedure DumpAsmTrace;
Var
  I, LastIdx : Integer;
Begin
  If Not Opts.DebugMode Then Exit;
  WriteLn('--- Trace backend 80386 ---');
  If AsmTraceCount = 0 Then
  Begin
    WriteLn('  (aucune instruction backend)');
    Exit;
  End;
  LastIdx := AsmTraceCount - 1;
  If LastIdx >= MAX_ASM_TRACE Then
    LastIdx := MAX_ASM_TRACE - 1;
  For I := 0 To LastIdx Do
    WriteLn(AsmTrace[I]);
End;

{ ============================================================ }
{ EXPRESSIONS                                                  }
{ ============================================================ }

Function TokIs(Kind : TTokenKind; Const Val : TString) : Boolean; Forward;
Procedure ParserNext; Forward;
Function ExpectToken(Kind : TTokenKind; Const Val, What : TString) : Boolean; Forward;

Function ExprKindName(K : TExprKind) : TString;
Begin
  Case K Of
    EK_UNKNOWN : ExprKindName := 'unknown';
    EK_LITERAL : ExprKindName := 'literal';
    EK_VAR     : ExprKindName := 'var';
    EK_CALL    : ExprKindName := 'call';
    EK_UNARY   : ExprKindName := 'unary';
    EK_BINARY  : ExprKindName := 'binary';
  Else
    ExprKindName := '?';
  End;
End;

Function MakeExpr(Kind : TExprKind; TypeIdx : Integer; IsConst : Boolean;
  IntValue : LongInt; IsLValue : Boolean) : TExprRec;
Begin
  MakeExpr.Kind := Kind;
  MakeExpr.TypeIdx := TypeIdx;
  MakeExpr.IsConst := IsConst;
  MakeExpr.IntValue := IntValue;
  MakeExpr.IsLValue := IsLValue;
  Inc(ExprCount);
End;

Function UnknownExpr : TExprRec;
Begin
  UnknownExpr := MakeExpr(EK_UNKNOWN, TY_UNKNOWN, False, 0, False);
End;

Function IsIntegerType(TypeIdx : Integer) : Boolean;
Begin
  IsIntegerType :=
    (TypeIdx = TY_IDX_I8) Or (TypeIdx = TY_IDX_U8) Or
    (TypeIdx = TY_IDX_I16) Or (TypeIdx = TY_IDX_U16) Or
    (TypeIdx = TY_IDX_I32) Or (TypeIdx = TY_IDX_U32) Or
    (TypeIdx = TY_IDX_ISIZE) Or (TypeIdx = TY_IDX_USIZE);
End;

Function ConstValueByName(Const Name : TString; Var Value : LongInt) : Boolean;
Var
  I : Integer;
Begin
  ConstValueByName := False;
  Value := 0;
  For I := 0 To ConstCount - 1 Do
    If (ConstTab[I].Name = Name) And ConstTab[I].HasIntVal Then
    Begin
      Value := ConstTab[I].IntValue;
      ConstValueByName := True;
      Exit;
    End;
End;

Function BinaryResultType(Const Op : TString; Left, Right : TExprRec) : Integer;
Begin
  If (Op = '==') Or (Op = '!=') Or (Op = '<') Or (Op = '<=') Or
     (Op = '>') Or (Op = '>=') Or (Op = '&&') Or (Op = '||') Then
    BinaryResultType := TY_IDX_BOOL
  Else If Left.TypeIdx <> TY_UNKNOWN Then
    BinaryResultType := Left.TypeIdx
  Else
    BinaryResultType := Right.TypeIdx;
End;

Function EvalBinaryConst(Const Op : TString; A, B : LongInt;
  Var V : LongInt) : Boolean;
Begin
  EvalBinaryConst := True;
  V := 0;
  If Op = '+' Then V := A + B
  Else If Op = '-' Then V := A - B
  Else If Op = '*' Then V := A * B
  Else If Op = '/' Then
  Begin
    If B = 0 Then EvalBinaryConst := False
    Else V := A Div B;
  End
  Else If Op = '%' Then
  Begin
    If B = 0 Then EvalBinaryConst := False
    Else V := A Mod B;
  End
  Else If Op = '==' Then V := Ord(A = B)
  Else If Op = '!=' Then V := Ord(A <> B)
  Else If Op = '<' Then V := Ord(A < B)
  Else If Op = '<=' Then V := Ord(A <= B)
  Else If Op = '>' Then V := Ord(A > B)
  Else If Op = '>=' Then V := Ord(A >= B)
  Else If Op = '&&' Then V := Ord((A <> 0) And (B <> 0))
  Else If Op = '||' Then V := Ord((A <> 0) Or (B <> 0))
  Else EvalBinaryConst := False;
End;

Function ParseExpr : TExprRec; Forward;

Function ParsePrimary : TExprRec;
Var
  Name : TString;
  SymIdx, ProcIdx : Integer;
  Val : LongInt;
  R, Arg : TExprRec;
Begin
  If CurToken.Kind = TK_INTEGER Then
  Begin
    R := MakeExpr(EK_LITERAL, TY_IDX_I32, True, CurToken.IntVal, False);
    ParserNext;
    ParsePrimary := R;
    Exit;
  End;

  If CurToken.Kind = TK_CHAR Then
  Begin
    R := MakeExpr(EK_LITERAL, TY_IDX_CHAR, True, CurToken.IntVal, False);
    ParserNext;
    ParsePrimary := R;
    Exit;
  End;

  If CurToken.Kind = TK_STRING Then
  Begin
    R := MakeExpr(EK_LITERAL, TY_IDX_PTR_I16, False, 0, False);
    ParserNext;
    ParsePrimary := R;
    Exit;
  End;

  If TokIs(TK_KEYWORD, 'true') Or TokIs(TK_KEYWORD, 'false') Then
  Begin
    If CurToken.Val = 'true' Then Val := 1 Else Val := 0;
    R := MakeExpr(EK_LITERAL, TY_IDX_BOOL, True, Val, False);
    ParserNext;
    ParsePrimary := R;
    Exit;
  End;

  If TokIs(TK_PUNCT, '(') Then
  Begin
    ParserNext;
    If TokIs(TK_PUNCT, ')') Then
    Begin
      ParserNext;
      ParsePrimary := MakeExpr(EK_LITERAL, TY_IDX_UNIT, True, 0, False);
      Exit;
    End;
    R := ParseExpr;
    ExpectToken(TK_PUNCT, ')', ') apres expression');
    ParsePrimary := R;
    Exit;
  End;

  If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_MACRO) Then
  Begin
    Name := CurToken.Val;
    ParserNext;
    If TokIs(TK_PUNCT, '(') Then
    Begin
      ParserNext;
      If Not (TokIs(TK_PUNCT, ')')) Then
      Begin
        While CurToken.Kind <> TK_EOF Do
        Begin
          Arg := ParseExpr;
          If TokIs(TK_PUNCT, ',') Then
          Begin
            ParserNext;
            Continue;
          End;
          Break;
        End;
      End;
      ExpectToken(TK_PUNCT, ')', ') apres appel');
      ProcIdx := FindProc(Name);
      If (ProcIdx < 0) And (Length(Name) > 0) And (Name[Length(Name)] = '!') Then
        R := MakeExpr(EK_CALL, TY_IDX_UNIT, False, 0, False)
      Else If ProcIdx >= 0 Then
        R := MakeExpr(EK_CALL, ProcTab[ProcIdx].RetTypeIdx, False, 0, False)
      Else
      Begin
        ReportErrorAt(CurToken.Line, CurToken.Col, Name,
          'appel de fonction inconnue');
        R := UnknownExpr;
      End;
      ParsePrimary := R;
      Exit;
    End;

    SymIdx := FindSym(Name);
    If SymIdx >= 0 Then
    Begin
      If ConstValueByName(Name, Val) Then
        R := MakeExpr(EK_VAR, SymTab[SymIdx].TypeIdx, True, Val, True)
      Else
        R := MakeExpr(EK_VAR, SymTab[SymIdx].TypeIdx, False, 0, True);
      ParsePrimary := R;
      Exit;
    End;

    ReportErrorAt(CurToken.Line, CurToken.Col, Name,
      'identificateur inconnu dans expression');
    ParsePrimary := UnknownExpr;
    Exit;
  End;

  ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
    'expression attendue');
  ParserNext;
  ParsePrimary := UnknownExpr;
End;

Function ParseUnary : TExprRec;
Var
  Op : TString;
  E : TExprRec;
Begin
  If TokIs(TK_OP, '-') Or TokIs(TK_OP, '!') Or TokIs(TK_OP, '*') Or
     TokIs(TK_OP, '&') Then
  Begin
    Op := CurToken.Val;
    ParserNext;
    E := ParseUnary;
    If (Op = '-') And E.IsConst Then
      E.IntValue := -E.IntValue;
    If Op = '!' Then
    Begin
      If E.IsConst Then E.IntValue := Ord(E.IntValue = 0);
      E.TypeIdx := TY_IDX_BOOL;
    End;
    EmitUnaryArith(Op, E);
    E.Kind := EK_UNARY;
    E.IsLValue := Op = '*';
    ParseUnary := E;
  End
  Else
    ParseUnary := ParsePrimary;
End;

Function ParseMul : TExprRec;
Var
  L, R, OldL : TExprRec;
  Op : TString;
  V : LongInt;
  IsC : Boolean;
Begin
  L := ParseUnary;
  While TokIs(TK_OP, '*') Or TokIs(TK_OP, '/') Or TokIs(TK_OP, '%') Do
  Begin
    Op := CurToken.Val;
    ParserNext;
    R := ParseUnary;
    IsC := L.IsConst And R.IsConst And EvalBinaryConst(Op, L.IntValue, R.IntValue, V);
    OldL := L;
    L := MakeExpr(EK_BINARY, BinaryResultType(Op, L, R), IsC, V, False);
    EmitBinaryArith(Op, OldL, R, L.TypeIdx);
  End;
  ParseMul := L;
End;

Function ParseAdd : TExprRec;
Var
  L, R, OldL : TExprRec;
  Op : TString;
  V : LongInt;
  IsC : Boolean;
Begin
  L := ParseMul;
  While TokIs(TK_OP, '+') Or TokIs(TK_OP, '-') Do
  Begin
    Op := CurToken.Val;
    ParserNext;
    R := ParseMul;
    IsC := L.IsConst And R.IsConst And EvalBinaryConst(Op, L.IntValue, R.IntValue, V);
    OldL := L;
    L := MakeExpr(EK_BINARY, BinaryResultType(Op, L, R), IsC, V, False);
    EmitBinaryArith(Op, OldL, R, L.TypeIdx);
  End;
  ParseAdd := L;
End;

Function ParseCompare : TExprRec;
Var
  L, R, OldL : TExprRec;
  Op : TString;
  V : LongInt;
  IsC : Boolean;
Begin
  L := ParseAdd;
  While TokIs(TK_OP, '<') Or TokIs(TK_OP, '<=') Or
        TokIs(TK_OP, '>') Or TokIs(TK_OP, '>=') Do
  Begin
    Op := CurToken.Val;
    ParserNext;
    R := ParseAdd;
    IsC := L.IsConst And R.IsConst And EvalBinaryConst(Op, L.IntValue, R.IntValue, V);
    OldL := L;
    L := MakeExpr(EK_BINARY, TY_IDX_BOOL, IsC, V, False);
    EmitBinaryArith(Op, OldL, R, L.TypeIdx);
  End;
  ParseCompare := L;
End;

Function ParseEquality : TExprRec;
Var
  L, R, OldL : TExprRec;
  Op : TString;
  V : LongInt;
  IsC : Boolean;
Begin
  L := ParseCompare;
  While TokIs(TK_OP, '==') Or TokIs(TK_OP, '!=') Do
  Begin
    Op := CurToken.Val;
    ParserNext;
    R := ParseCompare;
    IsC := L.IsConst And R.IsConst And EvalBinaryConst(Op, L.IntValue, R.IntValue, V);
    OldL := L;
    L := MakeExpr(EK_BINARY, TY_IDX_BOOL, IsC, V, False);
    EmitBinaryArith(Op, OldL, R, L.TypeIdx);
  End;
  ParseEquality := L;
End;

Function ParseLogicalAnd : TExprRec;
Var
  L, R, OldL : TExprRec;
  V : LongInt;
  IsC : Boolean;
Begin
  L := ParseEquality;
  While TokIs(TK_OP, '&&') Do
  Begin
    ParserNext;
    R := ParseEquality;
    IsC := L.IsConst And R.IsConst And EvalBinaryConst('&&', L.IntValue, R.IntValue, V);
    OldL := L;
    L := MakeExpr(EK_BINARY, TY_IDX_BOOL, IsC, V, False);
    EmitBinaryArith('&&', OldL, R, L.TypeIdx);
  End;
  ParseLogicalAnd := L;
End;

Function ParseExpr : TExprRec;
Var
  L, R, OldL : TExprRec;
  V : LongInt;
  IsC : Boolean;
Begin
  L := ParseLogicalAnd;
  While TokIs(TK_OP, '||') Do
  Begin
    ParserNext;
    R := ParseLogicalAnd;
    IsC := L.IsConst And R.IsConst And EvalBinaryConst('||', L.IntValue, R.IntValue, V);
    OldL := L;
    L := MakeExpr(EK_BINARY, TY_IDX_BOOL, IsC, V, False);
    EmitBinaryArith('||', OldL, R, L.TypeIdx);
  End;
  ParseExpr := L;
End;

{ ============================================================ }
{ TOKENISEUR RUST                                              }
{ ============================================================ }

Procedure LexInit;
Begin
  CurToken.Kind := TK_EOF;
  CurToken.Val := '';
  CurToken.IntVal := 0;
  CurToken.Line := 0;
  CurToken.Col := 0;
  TokenCount := 0;
  MacroCount := 0;
  If SourceLineNo = 0 Then
    SourceReadLine;
End;

Function LexPeekChar : Char;
Begin
  If SourceLineNo = 0 Then
    SourceReadLine;
  If SourceEOF And (SourceColNo > Length(SourceLine)) Then
    LexPeekChar := #0
  Else If SourceColNo <= Length(SourceLine) Then
    LexPeekChar := SourceLine[SourceColNo]
  Else If EOF(SourceF) Then
    LexPeekChar := #0
  Else
    LexPeekChar := #10;
End;

Function LexPeekChar2 : Char;
Begin
  If SourceLineNo = 0 Then
    SourceReadLine;
  If (SourceColNo + 1) <= Length(SourceLine) Then
    LexPeekChar2 := SourceLine[SourceColNo + 1]
  Else
    LexPeekChar2 := #0;
End;

Function LexNextChar : Char;
Begin
  If SourceLineNo = 0 Then
    SourceReadLine;

  If SourceColNo <= Length(SourceLine) Then
  Begin
    LexNextChar := SourceLine[SourceColNo];
    Inc(SourceColNo);
  End
  Else
  Begin
    If EOF(SourceF) Then
    Begin
      SourceEOF := True;
      LexNextChar := #0;
    End
    Else
    Begin
      SourceReadLine;
      LexNextChar := #10;
    End;
  End;
End;

Function TokenKindName(K : TTokenKind) : TString;
Begin
  Case K Of
    TK_EOF      : TokenKindName := 'EOF';
    TK_IDENT    : TokenKindName := 'IDENT';
    TK_KEYWORD  : TokenKindName := 'KEYWORD';
    TK_INTEGER  : TokenKindName := 'INTEGER';
    TK_STRING   : TokenKindName := 'STRING';
    TK_CHAR     : TokenKindName := 'CHAR';
    TK_LIFETIME : TokenKindName := 'LIFETIME';
    TK_MACRO    : TokenKindName := 'MACRO';
    TK_OP       : TokenKindName := 'OP';
    TK_PUNCT    : TokenKindName := 'PUNCT';
  Else
    TokenKindName := '?';
  End;
End;

Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('[', T.Line, ',', T.Col, '] ', TokenKindName(T.Kind));
  If T.Val <> '' Then
    Write(' ', T.Val);
  If T.Kind = TK_INTEGER Then
    Write(' = ', T.IntVal);
  WriteLn;
End;

Procedure LexMakeToken(Kind : TTokenKind; Const Val : TString;
  IntVal : LongInt; Line, Col : Integer);
Begin
  CurToken.Kind := Kind;
  CurToken.Val := Val;
  CurToken.IntVal := IntVal;
  CurToken.Line := Line;
  CurToken.Col := Col;
  Inc(TokenCount);
  PrintToken(CurToken);
End;

Procedure LexSkipLineComment;
Var
  Ch : Char;
Begin
  Repeat
    Ch := LexNextChar;
  Until (Ch = #0) Or (Ch = #10);
End;

Procedure LexSkipBlockComment(StartLine, StartCol : Integer);
Var
  Ch    : Char;
  Depth : Integer;
Begin
  Depth := 1;
  While Depth > 0 Do
  Begin
    Ch := LexNextChar;
    If Ch = #0 Then
    Begin
      ReportErrorAt(StartLine, StartCol, '/*',
        'commentaire bloc non termine');
      Exit;
    End;
    If (Ch = '/') And (LexPeekChar = '*') Then
    Begin
      LexNextChar;
      Inc(Depth);
    End
    Else If (Ch = '*') And (LexPeekChar = '/') Then
    Begin
      LexNextChar;
      Dec(Depth);
    End;
  End;
End;

Procedure LexSkipWhitespaceAndComments;
Var
  Ch : Char;
  L, C : Integer;
Begin
  Repeat
    Ch := LexPeekChar;
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #10) Or (Ch = #13) Then
      LexNextChar
    Else If (Ch = '/') And (LexPeekChar2 = '/') Then
    Begin
      LexNextChar;
      LexNextChar;
      LexSkipLineComment;
    End
    Else If (Ch = '/') And (LexPeekChar2 = '*') Then
    Begin
      L := SourceLineNo;
      C := SourceColNo;
      LexNextChar;
      LexNextChar;
      LexSkipBlockComment(L, C);
    End
    Else
      Exit;
  Until Ch = #0;
End;

Procedure LexReadIdent(First : Char; Line, Col : Integer);
Var
  S : TString;
Begin
  S := First;
  While IsIdentCont(LexPeekChar) Do
    S := S + LexNextChar;

  If LexPeekChar = '!' Then
  Begin
    If IsSupportedMacro(S) Then
    Begin
      LexNextChar;
      Inc(MacroCount);
      LexMakeToken(TK_MACRO, S + '!', 0, Line, Col);
    End
    Else
    Begin
      ReportErrorAt(Line, Col, S + '!',
        'macro Rust non supportee dans ce sous-ensemble');
      LexNextChar;
      LexMakeToken(TK_MACRO, S + '!', 0, Line, Col);
    End;
  End
  Else If IsRustKeyword(S) Then
    LexMakeToken(TK_KEYWORD, S, 0, Line, Col)
  Else
    LexMakeToken(TK_IDENT, S, 0, Line, Col);
End;

Procedure LexReadLifetime(Line, Col : Integer);
Var
  S : TString;
Begin
  S := '''';
  While IsIdentCont(LexPeekChar) Do
    S := S + LexNextChar;
  LexMakeToken(TK_LIFETIME, S, 0, Line, Col);
End;

Procedure LexReadNumber(First : Char; Line, Col : Integer);
Var
  S     : TString;
  Base  : Integer;
  V     : LongInt;
  Ch    : Char;
  Valid : Boolean;
Begin
  S := First;
  Base := 10;
  V := Ord(First) - Ord('0');

  If (First = '0') And
     ((LexPeekChar = 'x') Or (LexPeekChar = 'X') Or
      (LexPeekChar = 'b') Or (LexPeekChar = 'B') Or
      (LexPeekChar = 'o') Or (LexPeekChar = 'O')) Then
  Begin
    Ch := LexNextChar;
    S := S + Ch;
    V := 0;
    If (Ch = 'x') Or (Ch = 'X') Then Base := 16
    Else If (Ch = 'b') Or (Ch = 'B') Then Base := 2
    Else Base := 8;
  End;

  While True Do
  Begin
    Ch := LexPeekChar;
    If Ch = '_' Then
    Begin
      S := S + LexNextChar;
      Continue;
    End;

    Valid := False;
    If Base = 16 Then
      Valid := IsHexDigit(Ch)
    Else If Base = 10 Then
      Valid := IsDigit(Ch)
    Else If Base = 8 Then
      Valid := (Ch >= '0') And (Ch <= '7')
    Else If Base = 2 Then
      Valid := (Ch = '0') Or (Ch = '1');

    If Not Valid Then Break;

    Ch := LexNextChar;
    S := S + Ch;
    If Base = 16 Then
      V := (V * Base) + HexVal(Ch)
    Else
      V := (V * Base) + (Ord(Ch) - Ord('0'));
  End;

  LexMakeToken(TK_INTEGER, S, V, Line, Col);
End;

Procedure LexReadString(Line, Col : Integer);
Var
  S, Raw : TString;
  Ch     : Char;
Begin
  S := '';
  Raw := '"';
  While True Do
  Begin
    Ch := LexNextChar;
    If (Ch = #0) Or (Ch = #10) Then
    Begin
      ReportErrorAt(Line, Col, Raw, 'chaine non terminee');
      Break;
    End;
    Raw := Raw + Ch;
    If Ch = '"' Then
      Break;
    If Ch = '\' Then
    Begin
      Ch := LexNextChar;
      If Ch = #0 Then
      Begin
        ReportErrorAt(Line, Col, Raw, 'echappement de chaine non termine');
        Break;
      End;
      Raw := Raw + Ch;
      Case Ch Of
        'n' : S := S + #10;
        'r' : S := S + #13;
        't' : S := S + #9;
        '\' : S := S + '\';
        '"' : S := S + '"';
        '''' : S := S + '''';
      Else
        S := S + Ch;
      End;
    End
    Else
      S := S + Ch;
  End;
  LexMakeToken(TK_STRING, S, 0, Line, Col);
End;

Procedure LexReadChar(Line, Col : Integer);
Var
  S  : TString;
  Ch : Char;
  V  : LongInt;
Begin
  S := '''';
  Ch := LexNextChar;
  If (Ch = #0) Or (Ch = #10) Then
  Begin
    ReportErrorAt(Line, Col, S, 'caractere non termine');
    LexMakeToken(TK_CHAR, S, 0, Line, Col);
    Exit;
  End;

  S := S + Ch;
  If Ch = '\' Then
  Begin
    Ch := LexNextChar;
    S := S + Ch;
    Case Ch Of
      'n' : V := 10;
      'r' : V := 13;
      't' : V := 9;
      '0' : V := 0;
    Else
      V := Ord(Ch);
    End;
  End
  Else
    V := Ord(Ch);

  If LexPeekChar = '''' Then
    S := S + LexNextChar
  Else
    ReportErrorAt(Line, Col, S, 'caractere non termine');

  LexMakeToken(TK_CHAR, S, V, Line, Col);
End;

Function IsTwoCharOp(Const S : TString) : Boolean;
Begin
  IsTwoCharOp :=
    (S = '::') Or (S = '->') Or (S = '=>') Or (S = '..') Or
    (S = '==') Or (S = '!=') Or (S = '<=') Or (S = '>=') Or
    (S = '+=') Or (S = '-=') Or (S = '*=') Or (S = '/=') Or
    (S = '%=') Or (S = '&&') Or (S = '||') Or (S = '&=') Or
    (S = '|=') Or (S = '^=') Or (S = '<<') Or (S = '>>');
End;

Procedure LexReadOpOrPunct(First : Char; Line, Col : Integer);
Var
  S : TString;
Begin
  S := First;
  If IsTwoCharOp(S + LexPeekChar) Then
    S := S + LexNextChar;

  If (Length(S) = 1) And
     ((S[1] = ';') Or (S[1] = ',') Or (S[1] = '(') Or
      (S[1] = ')') Or (S[1] = '{') Or (S[1] = '}') Or
      (S[1] = '[') Or (S[1] = ']') Or (S[1] = ':')) Then
    LexMakeToken(TK_PUNCT, S, 0, Line, Col)
  Else
    LexMakeToken(TK_OP, S, 0, Line, Col);
End;

Function LexQuoteStartsLifetime : Boolean;
Var
  P : Integer;
Begin
  LexQuoteStartsLifetime := False;
  P := SourceColNo;
  If (P > Length(SourceLine)) Or (Not IsIdentStart(SourceLine[P])) Then
    Exit;
  While (P <= Length(SourceLine)) And IsIdentCont(SourceLine[P]) Do
    Inc(P);
  If (P <= Length(SourceLine)) And (SourceLine[P] = '''') Then
    LexQuoteStartsLifetime := False
  Else
    LexQuoteStartsLifetime := True;
End;

Procedure LexNextToken;
Var
  Ch : Char;
  L, C : Integer;
Begin
  LexSkipWhitespaceAndComments;
  L := SourceLineNo;
  C := SourceColNo;
  Ch := LexNextChar;

  If Ch = #0 Then
  Begin
    LexMakeToken(TK_EOF, '', 0, L, C);
    Exit;
  End;

  If IsIdentStart(Ch) Then
    LexReadIdent(Ch, L, C)
  Else If IsDigit(Ch) Then
    LexReadNumber(Ch, L, C)
  Else If Ch = '"' Then
    LexReadString(L, C)
  Else If Ch = '''' Then
  Begin
    If LexQuoteStartsLifetime Then
      LexReadLifetime(L, C)
    Else
      LexReadChar(L, C);
  End
  Else
    LexReadOpOrPunct(Ch, L, C);
End;

Procedure LexScanAll;
Begin
  LexInit;
  Repeat
    LexNextToken;
  Until CurToken.Kind = TK_EOF;
End;

Function TokIs(Kind : TTokenKind; Const Val : TString) : Boolean;
Var
  B : Boolean;
Begin
  B := CurToken.Kind = Kind;
  If Val <> '' Then
    B := B And (CurToken.Val = Val);
  TokIs := B;
End;

Function TokIsValue(Const Val : TString) : Boolean;
Begin
  TokIsValue := CurToken.Val = Val;
End;

Procedure ParserNext;
Begin
  LexNextToken;
End;

Function ExpectToken(Kind : TTokenKind; Const Val, What : TString) : Boolean;
Begin
  ExpectToken := False;
  If TokIs(Kind, Val) Then
  Begin
    ExpectToken := True;
    ParserNext;
  End
  Else
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'attendu: ' + What);
End;

Function ParseTypeName : Integer;
Var
  Name    : TString;
  BaseIdx : Integer;
  ResultIdx : Integer;
  IsMut   : Boolean;
  L, C    : Integer;
Begin
  ResultIdx := TY_UNKNOWN;
  L := CurToken.Line;
  C := CurToken.Col;

  If TokIs(TK_PUNCT, '(') Then
  Begin
    ParserNext;
    If ExpectToken(TK_PUNCT, ')', ') pour type unite') Then
      ResultIdx := TY_IDX_UNIT;
    ParseTypeName := ResultIdx;
    Exit;
  End;

  If TokIs(TK_OP, '*') Then
  Begin
    ParserNext;
    IsMut := False;
    If TokIs(TK_KEYWORD, 'const') Then
      ParserNext
    Else If TokIs(TK_KEYWORD, 'mut') Then
    Begin
      IsMut := True;
      ParserNext;
    End
    Else
    Begin
      ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
        'attendu const ou mut apres *');
      Exit;
    End;
    BaseIdx := ParseTypeName;
    If BaseIdx <> TY_UNKNOWN Then
      ResultIdx := AddRawPointerType(BaseIdx, IsMut);
    ParseTypeName := ResultIdx;
    Exit;
  End;

  If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
  Begin
    Name := CurToken.Val;
    ResultIdx := FindType(Name);
    If ResultIdx = TY_UNKNOWN Then
      ReportErrorAt(L, C, Name, 'type inconnu');
    ParserNext;
  End
  Else
    ReportErrorAt(L, C, CurToken.Val, 'nom de type attendu');
  ParseTypeName := ResultIdx;
End;

Procedure SkipBalancedBlock;
Var
  Depth : Integer;
Begin
  If Not (TokIs(TK_PUNCT, '{')) Then
  Begin
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'corps de fonction attendu');
    Exit;
  End;

  Depth := 0;
  Repeat
    If TokIs(TK_PUNCT, '{') Then
      Inc(Depth)
    Else If TokIs(TK_PUNCT, '}') Then
      Dec(Depth);
    ParserNext;
  Until (Depth <= 0) Or (CurToken.Kind = TK_EOF);

  If Depth > 0 Then
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'corps de fonction non termine');
End;

Procedure ParseBlock; Forward;
Procedure SkipUntilSemicolon; Forward;

Procedure SkipExprUntilSemiOrBlockEnd;
Var
  ParDepth, BrDepth : Integer;
Begin
  ParDepth := 0;
  BrDepth := 0;
  While CurToken.Kind <> TK_EOF Do
  Begin
    If TokIs(TK_PUNCT, '(') Then
      Inc(ParDepth)
    Else If TokIs(TK_PUNCT, ')') Then
    Begin
      If ParDepth > 0 Then Dec(ParDepth);
    End
    Else If TokIs(TK_PUNCT, '[') Then
      Inc(BrDepth)
    Else If TokIs(TK_PUNCT, ']') Then
    Begin
      If BrDepth > 0 Then Dec(BrDepth);
    End;

    If (ParDepth = 0) And (BrDepth = 0) And
       (TokIs(TK_PUNCT, ';') Or TokIs(TK_PUNCT, '}')) Then
      Break;
    ParserNext;
  End;
End;

Function SkipExprStatementTail(Var EndedWithBlock : Boolean) : Boolean;
Var
  ParDepth, BrDepth, BraceDepth : Integer;
  SawBlock : Boolean;
Begin
  SkipExprStatementTail := False;
  EndedWithBlock := False;
  ParDepth := 0;
  BrDepth := 0;
  BraceDepth := 0;
  SawBlock := False;

  While CurToken.Kind <> TK_EOF Do
  Begin
    If TokIs(TK_PUNCT, '(') Then
      Inc(ParDepth)
    Else If TokIs(TK_PUNCT, ')') Then
    Begin
      If ParDepth > 0 Then Dec(ParDepth);
    End
    Else If TokIs(TK_PUNCT, '[') Then
      Inc(BrDepth)
    Else If TokIs(TK_PUNCT, ']') Then
    Begin
      If BrDepth > 0 Then Dec(BrDepth);
    End
    Else If TokIs(TK_PUNCT, '{') Then
    Begin
      Inc(BraceDepth);
      SawBlock := True;
    End
    Else If TokIs(TK_PUNCT, '}') Then
    Begin
      If BraceDepth = 0 Then
        Exit;
      Dec(BraceDepth);
      ParserNext;
      If (BraceDepth = 0) And SawBlock And
         (ParDepth = 0) And (BrDepth = 0) Then
      Begin
        If TokIs(TK_KEYWORD, 'else') Then
        Begin
          ParserNext;
          Continue;
        End;
        EndedWithBlock := True;
        Exit;
      End;
      Continue;
    End
    Else If TokIs(TK_PUNCT, ';') And (ParDepth = 0) And
            (BrDepth = 0) And (BraceDepth = 0) Then
    Begin
      ParserNext;
      SkipExprStatementTail := True;
      Exit;
    End;
    ParserNext;
  End;
End;

Procedure ParseLetStmt;
Var
  L, C, TypeIdx, SymIdx : Integer;
  Name : TString;
  IsMut : Boolean;
  InitExpr : TExprRec;
Begin
  L := CurToken.Line;
  C := CurToken.Col;
  ExpectToken(TK_KEYWORD, 'let', 'let');

  IsMut := False;
  If TokIs(TK_KEYWORD, 'mut') Then
  Begin
    IsMut := True;
    ParserNext;
  End;

  If CurToken.Kind <> TK_IDENT Then
  Begin
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'nom de variable locale attendu');
    SkipUntilSemicolon;
    Exit;
  End;
  Name := CurToken.Val;
  ParserNext;

  TypeIdx := TY_UNKNOWN;
  If TokIs(TK_PUNCT, ':') Then
  Begin
    ParserNext;
    TypeIdx := ParseTypeName;
  End;

  SymIdx := AddSym(Name, SC_LOCAL, TypeIdx, IsMut, True,
    -LongInt((LocalCount + 1) * WORD_SIZE), Name, L, C);
  If SymIdx >= 0 Then
    Inc(LocalCount);

  If TokIs(TK_OP, '=') Then
  Begin
    ParserNext;
    InitExpr := ParseExpr;
    If TypeIdx = TY_UNKNOWN Then
      TypeIdx := InitExpr.TypeIdx;
    If SymIdx >= 0 Then
    Begin
      SymTab[SymIdx].TypeIdx := TypeIdx;
      EmitStoreSym(SymIdx, InitExpr, True);
    End;
  End;
  ExpectToken(TK_PUNCT, ';', '; apres let');
End;

Procedure ParseReturnStmt;
Var
  RetExpr : TExprRec;
Begin
  ExpectToken(TK_KEYWORD, 'return', 'return');
  If Not (TokIs(TK_PUNCT, ';')) Then
    RetExpr := ParseExpr;
  ExpectToken(TK_PUNCT, ';', '; apres return');
End;

Procedure ParseUnsafeStmt;
Begin
  ExpectToken(TK_KEYWORD, 'unsafe', 'unsafe');
  If TokIs(TK_PUNCT, '{') Then
    ParseBlock
  Else
  Begin
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'bloc unsafe attendu');
    SkipUntilSemicolon;
  End;
End;

Procedure ParseIfStmt;
Var
  CondExpr : TExprRec;
  FalseLabel, EndLabel : TString;
  HasElse : Boolean;
Begin
  ExpectToken(TK_KEYWORD, 'if', 'if');
  CondExpr := ParseExpr;
  FalseLabel := NewLabelName;
  EndLabel := NewLabelName;
  EmitConditionFalseJump(CondExpr, FalseLabel);

  If TokIs(TK_PUNCT, '{') Then
    ParseBlock
  Else
  Begin
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'bloc if attendu');
    SkipUntilSemicolon;
    Exit;
  End;

  HasElse := TokIs(TK_KEYWORD, 'else');
  If HasElse Then
    EmitJump(EndLabel);
  EmitLabel(FalseLabel);

  If TokIs(TK_KEYWORD, 'else') Then
  Begin
    ParserNext;
    If TokIs(TK_KEYWORD, 'if') Then
      ParseIfStmt
    Else If TokIs(TK_PUNCT, '{') Then
      ParseBlock
    Else
      ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
        'bloc else attendu');
  End;
  If HasElse Then
    EmitLabel(EndLabel);
End;

Procedure ParseWhileStmt;
Var
  CondExpr : TExprRec;
  StartLabel, EndLabel : TString;
  L, C : Integer;
Begin
  L := CurToken.Line;
  C := CurToken.Col;
  ExpectToken(TK_KEYWORD, 'while', 'while');
  StartLabel := NewLabelName;
  EndLabel := NewLabelName;
  Inc(LoopCount);

  EmitLabel(StartLabel);
  CondExpr := ParseExpr;
  EmitConditionFalseJump(CondExpr, EndLabel);

  If TokIs(TK_PUNCT, '{') Then
  Begin
    PushLoopLabels(StartLabel, EndLabel, L, C);
    ParseBlock;
    PopLoopLabels;
    EmitJump(StartLabel);
    EmitLabel(EndLabel);
  End
  Else
  Begin
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'bloc while attendu');
    SkipUntilSemicolon;
    EmitLabel(EndLabel);
  End;
End;

Procedure ParseLoopStmt;
Var
  StartLabel, EndLabel : TString;
  L, C : Integer;
Begin
  L := CurToken.Line;
  C := CurToken.Col;
  ExpectToken(TK_KEYWORD, 'loop', 'loop');
  StartLabel := NewLabelName;
  EndLabel := NewLabelName;
  Inc(LoopCount);

  EmitLabel(StartLabel);
  If TokIs(TK_PUNCT, '{') Then
  Begin
    PushLoopLabels(StartLabel, EndLabel, L, C);
    ParseBlock;
    PopLoopLabels;
    EmitJump(StartLabel);
    EmitLabel(EndLabel);
  End
  Else
  Begin
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'bloc loop attendu');
    SkipUntilSemicolon;
    EmitLabel(EndLabel);
  End;
End;

Procedure ParseBreakStmt;
Var
  Dest : TString;
  L, C : Integer;
Begin
  L := CurToken.Line;
  C := CurToken.Col;
  ExpectToken(TK_KEYWORD, 'break', 'break');
  Dest := CurrentLoopBreak;
  If Dest = '' Then
    ReportErrorAt(L, C, 'break', 'break hors boucle')
  Else
    EmitJump(Dest);
  ExpectToken(TK_PUNCT, ';', '; apres break');
End;

Procedure ParseContinueStmt;
Var
  Dest : TString;
  L, C : Integer;
Begin
  L := CurToken.Line;
  C := CurToken.Col;
  ExpectToken(TK_KEYWORD, 'continue', 'continue');
  Dest := CurrentLoopContinue;
  If Dest = '' Then
    ReportErrorAt(L, C, 'continue', 'continue hors boucle')
  Else
    EmitJump(Dest);
  ExpectToken(TK_PUNCT, ';', '; apres continue');
End;

Procedure ParseExprStmt;
Var
  AssignName : TString;
  AssignLine, AssignCol, SymIdx : Integer;
  HadSemi, HadBlock : Boolean;
  Rhs : TExprRec;
Begin
  If CurToken.Kind = TK_MACRO Then
  Begin
    Rhs := ParseExpr;
    ExpectToken(TK_PUNCT, ';', '; apres appel macro');
    Exit;
  End;

  AssignName := '';
  AssignLine := CurToken.Line;
  AssignCol := CurToken.Col;
  If CurToken.Kind = TK_IDENT Then
    AssignName := CurToken.Val;

  ParserNext;
  If (AssignName <> '') And TokIs(TK_OP, '=') Then
  Begin
    SymIdx := FindSym(AssignName);
    RequireAssignable(SymIdx, AssignLine, AssignCol);
    ParserNext;
    Rhs := ParseExpr;
    If CanAssignToSym(SymIdx) Then
      EmitStoreSym(SymIdx, Rhs, False);
    ExpectToken(TK_PUNCT, ';', '; apres affectation');
    Exit;
  End;

  HadSemi := SkipExprStatementTail(HadBlock);
  If (Not HadSemi) And (Not HadBlock) And (Not (TokIs(TK_PUNCT, '}'))) And
     (CurToken.Kind <> TK_EOF) Then
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      '; apres instruction');
End;

Procedure ParseStatement;
Begin
  Inc(StmtCount);
  If TokIs(TK_KEYWORD, 'let') Then
    ParseLetStmt
  Else If TokIs(TK_KEYWORD, 'return') Then
    ParseReturnStmt
  Else If TokIs(TK_KEYWORD, 'if') Then
    ParseIfStmt
  Else If TokIs(TK_KEYWORD, 'while') Then
    ParseWhileStmt
  Else If TokIs(TK_KEYWORD, 'loop') Then
    ParseLoopStmt
  Else If TokIs(TK_KEYWORD, 'break') Then
    ParseBreakStmt
  Else If TokIs(TK_KEYWORD, 'continue') Then
    ParseContinueStmt
  Else If TokIs(TK_KEYWORD, 'unsafe') Then
    ParseUnsafeStmt
  Else If TokIs(TK_PUNCT, '{') Then
    ParseBlock
  Else If TokIs(TK_PUNCT, ';') Then
    ParserNext
  Else
    ParseExprStmt;
End;

Procedure ParseBlock;
Begin
  If Not (TokIs(TK_PUNCT, '{')) Then
  Begin
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'bloc attendu');
    Exit;
  End;
  Inc(BlockCount);
  ExpectToken(TK_PUNCT, '{', '{');
  EnterScope;
  While (CurToken.Kind <> TK_EOF) And (Not (TokIs(TK_PUNCT, '}'))) Do
    ParseStatement;
  ExpectToken(TK_PUNCT, '}', '}');
  LeaveScope;
End;

Procedure ParseFunctionSignature(IsPublic, IsExtern : Boolean);
Var
  FnLine, FnCol : Integer;
  Name, ParamName : TString;
  FnSym, ProcIdx : Integer;
  RetType, ParamType : Integer;
  ParamOffset : LongInt;
Begin
  FnLine := CurToken.Line;
  FnCol := CurToken.Col;
  If Not (ExpectToken(TK_KEYWORD, 'fn', 'fn')) Then
    Exit;

  If CurToken.Kind <> TK_IDENT Then
  Begin
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'nom de fonction attendu');
    Exit;
  End;
  Name := CurToken.Val;
  ParserNext;

  If Not (ExpectToken(TK_PUNCT, '(', '(')) Then
    Exit;

  RetType := TY_IDX_UNIT;
  If IsExtern Then
    FnSym := AddSym(Name, SC_EXTERN, RetType, False, False, 0,
      RS_EXT_PFX + Name, FnLine, FnCol)
  Else
    FnSym := AddSym(Name, SC_FN, RetType, False, True, 0,
      RS_FN_PFX + Name, FnLine, FnCol);
  ProcIdx := AddProc(Name, RetType, IsPublic, IsExtern, FnSym,
    FnLine, FnCol);

  EnterScope;
  ParamOffset := 8;
  If Not (TokIs(TK_PUNCT, ')')) Then
  Begin
    While CurToken.Kind <> TK_EOF Do
    Begin
      If CurToken.Kind <> TK_IDENT Then
      Begin
        ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
          'nom de parametre attendu');
        Break;
      End;
      ParamName := CurToken.Val;
      ParserNext;
      If Not (ExpectToken(TK_PUNCT, ':', ': apres parametre')) Then
        Break;
      ParamType := ParseTypeName;
      If ProcIdx >= 0 Then
        AddProcParam(ProcIdx, ParamName, ParamType,
          CurToken.Line, CurToken.Col);
      AddSym(ParamName, SC_PARAM, ParamType, False, True,
        ParamOffset, ParamName, FnLine, FnCol);
      Inc(ParamOffset, WORD_SIZE);

      If TokIs(TK_PUNCT, ',') Then
      Begin
        ParserNext;
        If TokIs(TK_PUNCT, ')') Then
          Break;
      End
      Else
        Break;
    End;
  End;
  ExpectToken(TK_PUNCT, ')', ')');

  If TokIs(TK_OP, '->') Then
  Begin
    ParserNext;
    RetType := ParseTypeName;
    If ProcIdx >= 0 Then
      ProcTab[ProcIdx].RetTypeIdx := RetType;
    If FnSym >= 0 Then
      SymTab[FnSym].TypeIdx := RetType;
  End;

  If IsExtern Then
    ExpectToken(TK_PUNCT, ';', '; apres declaration extern')
  Else
    ParseBlock;
  LeaveScope;
End;

Procedure ParseExternBlock;
Begin
  ExpectToken(TK_KEYWORD, 'extern', 'extern');
  If CurToken.Kind = TK_STRING Then
    ParserNext
  Else
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'ABI extern attendue, ex: "C"');
  If Not (ExpectToken(TK_PUNCT, '{', '{ apres extern')) Then
    Exit;
  While (CurToken.Kind <> TK_EOF) And (Not (TokIs(TK_PUNCT, '}'))) Do
  Begin
    If TokIs(TK_KEYWORD, 'fn') Then
      ParseFunctionSignature(False, True)
    Else
    Begin
      ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
        'seules les declarations fn extern sont supportees ici');
      ParserNext;
    End;
  End;
  ExpectToken(TK_PUNCT, '}', '} extern');
End;

Procedure SkipTopLevelItem;
Begin
  While (CurToken.Kind <> TK_EOF) And
        (Not (TokIs(TK_PUNCT, ';'))) And
        (Not (TokIs(TK_PUNCT, '{'))) Do
    ParserNext;
  If TokIs(TK_PUNCT, ';') Then
    ParserNext
  Else If TokIs(TK_PUNCT, '{') Then
    SkipBalancedBlock
  Else If CurToken.Kind <> TK_EOF Then
    ParserNext;
End;

Procedure SkipUntilSemicolon;
Begin
  While (CurToken.Kind <> TK_EOF) And (Not (TokIs(TK_PUNCT, ';'))) Do
    ParserNext;
  If TokIs(TK_PUNCT, ';') Then
    ParserNext;
End;

Function ParseIntegerInitializer(Var Value : LongInt) : Boolean;
Var
  Sign : LongInt;
Begin
  ParseIntegerInitializer := False;
  Value := 0;
  Sign := 1;

  If TokIs(TK_OP, '-') Then
  Begin
    Sign := -1;
    ParserNext;
  End;

  If CurToken.Kind = TK_INTEGER Then
  Begin
    Value := Sign * CurToken.IntVal;
    ParserNext;
    ParseIntegerInitializer := True;
  End;
End;

Procedure ParseConstDecl;
Var
  L, C, SymIdx, TypeIdx : Integer;
  Name : TString;
  V : LongInt;
  HasValue : Boolean;
  E : TExprRec;
Begin
  L := CurToken.Line;
  C := CurToken.Col;
  ExpectToken(TK_KEYWORD, 'const', 'const');

  If CurToken.Kind <> TK_IDENT Then
  Begin
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'nom de constante attendu');
    SkipUntilSemicolon;
    Exit;
  End;
  Name := CurToken.Val;
  ParserNext;

  If Not (ExpectToken(TK_PUNCT, ':', ': apres constante')) Then
  Begin
    SkipUntilSemicolon;
    Exit;
  End;
  TypeIdx := ParseTypeName;

  HasValue := False;
  V := 0;
  If TokIs(TK_OP, '=') Then
  Begin
    ParserNext;
    E := ParseExpr;
    HasValue := E.IsConst;
    V := E.IntValue;
    If Not HasValue Then
      ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
        'initialiseur const constant attendu');
  End
  Else
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'initialiseur const attendu');

  SymIdx := AddSym(Name, SC_CONST, TypeIdx, False, True, 0,
    Name, L, C);
  AddConstRec(Name, TypeIdx, V, HasValue, SymIdx, L, C);
  SkipUntilSemicolon;
End;

Procedure ParseStaticDecl;
Var
  L, C, SymIdx, TypeIdx : Integer;
  Name : TString;
  V : LongInt;
  HasValue, IsMut : Boolean;
  E : TExprRec;
Begin
  L := CurToken.Line;
  C := CurToken.Col;
  ExpectToken(TK_KEYWORD, 'static', 'static');

  IsMut := False;
  If TokIs(TK_KEYWORD, 'mut') Then
  Begin
    IsMut := True;
    ParserNext;
  End;

  If CurToken.Kind <> TK_IDENT Then
  Begin
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'nom de static attendu');
    SkipUntilSemicolon;
    Exit;
  End;
  Name := CurToken.Val;
  ParserNext;

  If Not (ExpectToken(TK_PUNCT, ':', ': apres static')) Then
  Begin
    SkipUntilSemicolon;
    Exit;
  End;
  TypeIdx := ParseTypeName;

  HasValue := False;
  V := 0;
  If TokIs(TK_OP, '=') Then
  Begin
    ParserNext;
    E := ParseExpr;
    HasValue := E.IsConst;
    V := E.IntValue;
    If Not HasValue Then
      ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
        'initialiseur static constant attendu');
  End;

  SymIdx := AddSym(Name, SC_STATIC, TypeIdx, IsMut, True, 0,
    RS_VAR_PFX + Name, L, C);
  AddStaticRec(Name, TypeIdx, V, HasValue, IsMut, SymIdx, L, C);
  SkipUntilSemicolon;
End;

Procedure ParseProgram;
Var
  IsPublic : Boolean;
Begin
  LexInit;
  ParserNext;
  While CurToken.Kind <> TK_EOF Do
  Begin
    IsPublic := False;
    If TokIs(TK_KEYWORD, 'pub') Then
    Begin
      IsPublic := True;
      ParserNext;
    End;

    If TokIs(TK_KEYWORD, 'fn') Then
      ParseFunctionSignature(IsPublic, False)
    Else If TokIs(TK_KEYWORD, 'extern') Then
      ParseExternBlock
    Else If TokIs(TK_KEYWORD, 'const') Then
      ParseConstDecl
    Else If TokIs(TK_KEYWORD, 'static') Then
      ParseStaticDecl
    Else
      SkipTopLevelItem;
  End;

  If MainProcIdx < 0 Then
    ReportErrorAt(1, 1, 'main', 'fonction main manquante');
End;

{ ============================================================ }
{ PROGRAMME PRINCIPAL                                          }
{ ============================================================ }

BEGIN
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  BlockCount := 0;
  StmtCount := 0;
  LocalCount := 0;
  ExprCount := 0;
  LoopCount := 0;
  SourceInit;
  InitBackend;
  InitTypeTable;
  InitSymbolTable;
  InitProcTable;
  InitConstStaticTables;
  ParseArgs;
  ShowBanner;
  DumpTypeTable;
  SourceOpen(Opts.SrcFile);
  ParseProgram;
  SourceClose;
  DumpSymbolTable;
  DumpProcTable;
  DumpConstStaticTables;
  DumpAsmTrace;
  WarnMsg('backend fichier non implemente: TODO 16 et suivantes restent a faire');
  ShowStats;
END.
