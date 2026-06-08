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

  TODO 16 - FOR SUR RANGES ENTIERES [IMPLEMENTE]
            Supporter for i in a..b { ... } comme sucre syntaxique
              compile en initialisation, test, increment et bloc.
            Gerer variable d'iteration locale immuable par defaut.
            Suffisant pour for i in 0..5 dans control.rs.

  TODO 17 - MATCH MINIMAL [IMPLEMENTE]
            Parser match expr { lit => { ... }, _ => { ... } }.
            Generer comparaison sequentielle et branche par defaut.
            Suffisant pour label_of(code) dans control.rs.

  TODO 18 - APPELS DE FONCTIONS ET CONVENTION D'APPEL [IMPLEMENTE]
            Definir convention interne : arguments pousses sur pile,
              retour dans EAX, nettoyage par appelant ou appele selon
              choix documente.
            Generer prologue/epilogue EBP, sauvegarde des registres
              necessaires et acces parametres [EBP+offset].
            Supporter appels add(x, y), mul(z, 2), safe_noop(42).

  TODO 19 - EXTERN "C" ET IMPORTS WIN32/CRT [IMPLEMENTE]
            Parser extern "C" { fn name(params); }.
            Enregistrer symboles externes et relocations COFF.
            Prevoir imports minimaux console/CRT pour puts, ExitProcess,
              WriteConsoleA ou equivalents runtime.

  TODO 20 - UNSAFE ET POINTEURS BRUTS [IMPLEMENTE]
            Parser unsafe { ... } et marquer le contexte unsafe.
            Supporter declarations *const T et *mut T, litteral 0
              comme pointeur nul, affectation locale de pointeur.
            Pour les exemples, aucun dereferencement requis au depart.

  TODO 21 - MACROS RUNTIME : PRINTLN, DEBUG_ASSERT, PANIC [IMPLEMENTE]
            println!("texte") : emettre chaine .rdata et appel runtime
              d'ecriture console avec saut de ligne.
            debug_assert!(x) : verifier x != 0 et appeler panic runtime
              si faux, ou l'ignorer selon option future.
            panic!("texte") : afficher message et terminer avec code
              d'erreur non nul.

  TODO 22 - GENERATEUR ASM MASM 80386 [IMPLEMENTE]
            Produire optionnellement un .ASM MASM lisible quand -asm
              est fourni : .386, .MODEL FLAT, sections .CODE/.DATA,
              PUBLIC/EXTERN, labels et commentaires utiles.
            Garder le backend ASM separe du backend binaire COFF/PE
              pour faciliter le debogage.

  TODO 23 - EMISSION COFF .OBJ [IMPLEMENTE]
            Construire sections .text, .rdata, .data, .bss, table de
              symboles et relocations IMAGE_REL_I386_DIR32/REL32.
            Avec -obj, ecrire uniquement le .OBJ et ne pas lier.
            Verifier que les appels externes restent relocatables.

  TODO 24 - LINKER PE .EXE PAR DEFAUT [IMPLEMENTE]
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

  { Tailles des buffers binaires }
  MAX_BIN_CODE  = {$IFDEF FPC}262144{$ELSE}32768{$ENDIF};
  MAX_BIN_DATA  = {$IFDEF FPC}131072{$ELSE}32768{$ENDIF};
  MAX_BIN_RDATA = {$IFDEF FPC}131072{$ELSE}32768{$ENDIF};
  MAX_ASM_TRACE = {$IFDEF FPC}8192{$ELSE}1024{$ENDIF};

  { Limites backend binaire : labels et patches }
  MAX_BIN_LABEL = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_PATCH_TAB = {$IFDEF FPC}2048{$ELSE}512{$ENDIF};

  { Tailles des buffers PE linker }
  MAX_IMP_BUF   = {$IFDEF FPC}8192{$ELSE}4096{$ENDIF};
  MAX_START_BUF = {$IFDEF FPC}4096{$ELSE}2048{$ENDIF};

  { Registres x86 (ModRM/SIB encoding) }
  REG_EAX = 0;  REG_ECX = 1;  REG_EDX = 2;  REG_EBX = 3;
  REG_ESP = 4;  REG_EBP = 5;  REG_ESI = 6;  REG_EDI = 7;

  { Conditions x86 pour SETcc / Jcc }
  CC_O  = $0;  CC_NO  = $1;  CC_B  = $2;  CC_AE  = $3;
  CC_E  = $4;  CC_NE  = $5;  CC_BE = $6;  CC_A   = $7;
  CC_S  = $8;  CC_NS  = $9;  CC_P  = $A;  CC_NP  = $B;
  CC_L  = $C;  CC_GE  = $D;  CC_LE = $E;  CC_G   = $F;

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

  TImportRec = Record
    Name        : TString;
    MangledName : TString;
    ModuleName  : TString;
    AbiName     : TString;
    ProcIdx     : Integer;
    SymIdx      : Integer;
  End;

  TRelocRec = Record
    SectionName : TString;
    SymbolName  : TString;
    RelocType   : Integer;
    Note        : TString;
  End;

  TStringRec = Record
    LabelName : TString;
    Text      : TString;
    Len       : Integer;
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

  TExprArgArray = Array[0..MAX_PARAM - 1] Of TExprRec;

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
  CurrentProcIdx : Integer;
  CurrentReturnLabel : TString;
  CurrentExternAbi : TString;
  CurrentExternModule : TString;

  { Constantes et statics top-level }
  ConstTab      : Array[0..MAX_CONST - 1] Of TConstRec;
  ConstCount    : Integer;
  StaticTab     : Array[0..MAX_STATIC - 1] Of TStaticRec;
  StaticCount   : Integer;

  { Imports externes et relocations COFF futures }
  ImportTab     : Array[0..MAX_IMPORT - 1] Of TImportRec;
  ImportCount   : Integer;
  RelocTab      : Array[0..MAX_RELOC - 1] Of TRelocRec;
  RelocCount    : Integer;
  StringTab     : Array[0..MAX_STR - 1] Of TStringRec;
  StringCount   : Integer;

  { Statistiques de parsing des blocs }
  BlockCount    : LongInt;
  StmtCount     : LongInt;
  LocalCount    : LongInt;
  ExprCount     : LongInt;
  LoopCount     : LongInt;
  MatchCount    : LongInt;
  CallCount     : LongInt;
  ExternCallCount : LongInt;
  UnsafeDepth   : Integer;
  UnsafeBlockCount : LongInt;
  PtrLocalCount : LongInt;
  RuntimeMacroCount : LongInt;
  PrintlnCount  : LongInt;
  DebugAssertCount : LongInt;
  PanicCount    : LongInt;

  { Backend intermediaire 80386 }
  AsmTrace      : Array[0..MAX_ASM_TRACE - 1] Of TString;
  AsmTraceCount : Integer;
  ArithInstrCount : LongInt;
  StoreInstrCount : LongInt;

  { ---- Buffers binaires (backend COFF / PE) ---- }
  StringRdataOff : Array[0..MAX_STR - 1] Of LongInt;    { offset de chaque chaine dans RdataBuf }
  StaticDataOff  : Array[0..MAX_STATIC - 1] Of LongInt; { offset de chaque static dans DataBuf/BssBuf }

  { ---- Buffers PE linker ---- }
  PeImpBuf      : Array[0..MAX_IMP_BUF - 1] Of Byte;    { import table serialisee }
  PeImpLen      : LongInt;
  PeImpIatVA    : Array[0..MAX_IMPORT - 1] Of LongInt;  { VA absolue de chaque entree IAT }
  PeStartBuf    : Array[0..MAX_START_BUF - 1] Of Byte;  { bloc de demarrage prepend a .text }
  PeStartLen    : LongInt;
  PeThunkVA     : Array[0..MAX_IMPORT - 1] Of LongInt;  { VA absolue de chaque thunk JMP }
  PePrintlnVA   : LongInt;   { VA absolue du stub _RSRT_println }
  PePanicVA     : LongInt;   { VA absolue du stub _RSRT_panic }
  PeEntryVA     : LongInt;   { VA absolue du point d entree _start }

  CodeBuf       : Array[0..MAX_BIN_CODE - 1] Of Byte;
  CodeLen       : LongInt;
  DataBuf       : Array[0..MAX_BIN_DATA - 1] Of Byte;
  DataLen       : LongInt;
  RdataBuf      : Array[0..MAX_BIN_RDATA - 1] Of Byte;
  RdataLen      : LongInt;
  BssLen        : LongInt;

  { Table des labels binaires definis (nom -> offset dans CodeBuf) }
  BinLabelNames : Array[0..MAX_BIN_LABEL - 1] Of TString;
  BinLabelOffs  : Array[0..MAX_BIN_LABEL - 1] Of LongInt;
  BinLabelCount : Integer;

  { Patches a appliquer apres resolution des labels }
  BinPatchLabel : Array[0..MAX_PATCH_TAB - 1] Of TString;
  BinPatchOff   : Array[0..MAX_PATCH_TAB - 1] Of LongInt;  { offset du slot dans CodeBuf }
  BinPatchInstr : Array[0..MAX_PATCH_TAB - 1] Of LongInt;  { offset de l'instruction (pour REL32) }
  BinPatchRel   : Array[0..MAX_PATCH_TAB - 1] Of Boolean;  { True=REL32, False=DIR32 }
  BinPatchCount : Integer;

  { Relocations COFF pour la section .text }
  CoffTextRelVA  : Array[0..MAX_RELOC - 1] Of LongInt;
  CoffTextRelSym : Array[0..MAX_RELOC - 1] Of TString;
  CoffTextRelTy  : Array[0..MAX_RELOC - 1] Of Word;
  CoffTextRelCnt : Integer;

Procedure FatalError(Const Msg : TString); Forward;
Procedure ReportErrorAt(Line, Col : Integer; Const Token, Msg : TString); Forward;

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

Function TypeIsPointer(TypeIdx : Integer) : Boolean;
Begin
  TypeIsPointer := (TypeIdx >= 0) And (TypeIdx < TypeCount) And
    (TypeTab[TypeIdx].Kind = TYK_PTR);
End;

Function TypeIsMutablePointer(TypeIdx : Integer) : Boolean;
Begin
  TypeIsMutablePointer := TypeIsPointer(TypeIdx) And TypeTab[TypeIdx].IsMutPtr;
End;

Function TypeIsIntegerLike(TypeIdx : Integer) : Boolean;
Begin
  TypeIsIntegerLike :=
    (TypeIdx = TY_IDX_I8) Or (TypeIdx = TY_IDX_U8) Or
    (TypeIdx = TY_IDX_I16) Or (TypeIdx = TY_IDX_U16) Or
    (TypeIdx = TY_IDX_I32) Or (TypeIdx = TY_IDX_U32) Or
    (TypeIdx = TY_IDX_ISIZE) Or (TypeIdx = TY_IDX_USIZE);
End;

Function TypesAreAssignable(DstType, SrcType : Integer) : Boolean;
Begin
  If (DstType = TY_UNKNOWN) Or (SrcType = TY_UNKNOWN) Then
    TypesAreAssignable := True
  Else If DstType = SrcType Then
    TypesAreAssignable := True
  Else If TypeIsIntegerLike(DstType) And TypeIsIntegerLike(SrcType) Then
    TypesAreAssignable := True
  Else If TypeIsPointer(DstType) And (SrcType = TY_IDX_I32) Then
    TypesAreAssignable := True
  Else
    TypesAreAssignable := False;
End;

Procedure PrepareAssignmentExpr(DstType : Integer; Var SrcExpr : TExprRec;
  Line, Col : Integer; Const Name : TString);
Begin
  If TypeIsPointer(DstType) And SrcExpr.IsConst And
     (SrcExpr.IntValue = 0) And TypeIsIntegerLike(SrcExpr.TypeIdx) Then
  Begin
    SrcExpr.TypeIdx := DstType;
    Exit;
  End;

  If Not TypesAreAssignable(DstType, SrcExpr.TypeIdx) Then
    ReportErrorAt(Line, Col, Name,
      'types incompatibles dans affectation: ' +
      TypeTab[SrcExpr.TypeIdx].Name + ' vers ' + TypeTab[DstType].Name);
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
  WriteLn('Chaines        : ', StringCount);
  WriteLn('Blocs          : ', BlockCount);
  WriteLn('Instructions   : ', StmtCount);
  WriteLn('Locales        : ', LocalCount);
  WriteLn('Boucles        : ', LoopCount);
  WriteLn('Matchs         : ', MatchCount);
  WriteLn('Appels         : ', CallCount);
  WriteLn('Appels extern  : ', ExternCallCount);
  WriteLn('Blocs unsafe   : ', UnsafeBlockCount);
  WriteLn('Locales ptr    : ', PtrLocalCount);
  WriteLn('Macros runtime : ', RuntimeMacroCount);
  WriteLn('Println        : ', PrintlnCount);
  WriteLn('Debug asserts  : ', DebugAssertCount);
  WriteLn('Panics         : ', PanicCount);
  WriteLn('Imports        : ', ImportCount);
  WriteLn('Relocations    : ', RelocCount);
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
  CurrentProcIdx := -1;
  CurrentReturnLabel := '';
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

Procedure ClearStringRec(Var S : TStringRec);
Begin
  S.LabelName := '';
  S.Text := '';
  S.Len := 0;
End;

Procedure InitConstStaticTables;
Var
  I : Integer;
Begin
  ConstCount := 0;
  StaticCount := 0;
  StringCount := 0;
  For I := 0 To MAX_CONST - 1 Do
    ClearConstRec(ConstTab[I]);
  For I := 0 To MAX_STATIC - 1 Do
    ClearStaticRec(StaticTab[I]);
  For I := 0 To MAX_STR - 1 Do
    ClearStringRec(StringTab[I]);
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

Function AddStringRec(Const Text : TString) : Integer;
Begin
  AddStringRec := -1;
  If StringCount >= MAX_STR Then
    FatalError('table des chaines pleine (MAX_STR=' +
      IntToStr_(MAX_STR) + ')');
  ClearStringRec(StringTab[StringCount]);
  StringTab[StringCount].LabelName := RS_STR_PFX + IntToStr_(StringCount);
  StringTab[StringCount].Text := Text;
  StringTab[StringCount].Len := Length(Text);
  AddStringRec := StringCount;
  Inc(StringCount);
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

  WriteLn('--- Chaines .rdata reconnues ---');
  If StringCount = 0 Then
    WriteLn('  (aucune)');
  For I := 0 To StringCount - 1 Do
    WriteLn('  [', I, '] ', StringTab[I].LabelName,
      ' len=', StringTab[I].Len, ' text="', StringTab[I].Text, '"');
End;

{ ============================================================ }
{ IMPORTS EXTERNES ET RELOCATIONS                              }
{ ============================================================ }

Procedure ClearImportRec(Var R : TImportRec);
Begin
  R.Name := '';
  R.MangledName := '';
  R.ModuleName := '';
  R.AbiName := '';
  R.ProcIdx := -1;
  R.SymIdx := -1;
End;

Procedure ClearRelocRec(Var R : TRelocRec);
Begin
  R.SectionName := '';
  R.SymbolName := '';
  R.RelocType := 0;
  R.Note := '';
End;

Procedure InitImportRelocTables;
Var
  I : Integer;
Begin
  ImportCount := 0;
  RelocCount := 0;
  CurrentExternAbi := '';
  CurrentExternModule := '';
  For I := 0 To MAX_IMPORT - 1 Do
    ClearImportRec(ImportTab[I]);
  For I := 0 To MAX_RELOC - 1 Do
    ClearRelocRec(RelocTab[I]);
End;

Function DefaultImportModule(Const Name, AbiName : TString) : TString;
Begin
  If (Name = 'ExitProcess') Or (Name = 'WriteFile') Or
     (Name = 'GetStdHandle') Then
    DefaultImportModule := 'kernel32.dll'
  Else If (Name = 'puts') Or (Name = 'printf') Or (Name = 'exit') Then
    DefaultImportModule := 'msvcrt.dll'
  Else If AbiName = 'C' Then
    DefaultImportModule := 'msvcrt.dll'
  Else
    DefaultImportModule := 'kernel32.dll';
End;

Function FindImport(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  FindImport := -1;
  For I := 0 To ImportCount - 1 Do
    If ImportTab[I].Name = Name Then
    Begin
      FindImport := I;
      Exit;
    End;
End;

Function AddImportRec(Const Name, MangledName, ModuleName, AbiName : TString;
  ProcIdx, SymIdx : Integer) : Integer;
Var
  Existing : Integer;
Begin
  Existing := FindImport(Name);
  If Existing >= 0 Then
  Begin
    AddImportRec := Existing;
    Exit;
  End;
  If ImportCount >= MAX_IMPORT Then
    FatalError('table des imports pleine (MAX_IMPORT=' +
      IntToStr_(MAX_IMPORT) + ')');
  ClearImportRec(ImportTab[ImportCount]);
  ImportTab[ImportCount].Name := Name;
  ImportTab[ImportCount].MangledName := MangledName;
  ImportTab[ImportCount].ModuleName := ModuleName;
  ImportTab[ImportCount].AbiName := AbiName;
  ImportTab[ImportCount].ProcIdx := ProcIdx;
  ImportTab[ImportCount].SymIdx := SymIdx;
  AddImportRec := ImportCount;
  Inc(ImportCount);
End;

Procedure AddRelocRec(Const SectionName, SymbolName : TString; RelocType : Integer;
  Const Note : TString);
Begin
  If RelocCount >= MAX_RELOC Then
    FatalError('table des relocations pleine (MAX_RELOC=' +
      IntToStr_(MAX_RELOC) + ')');
  ClearRelocRec(RelocTab[RelocCount]);
  RelocTab[RelocCount].SectionName := SectionName;
  RelocTab[RelocCount].SymbolName := SymbolName;
  RelocTab[RelocCount].RelocType := RelocType;
  RelocTab[RelocCount].Note := Note;
  Inc(RelocCount);
End;

Function RelocTypeName(RelocType : Integer) : TString;
Begin
  If RelocType = COFF_RELOC_REL32 Then
    RelocTypeName := 'REL32'
  Else If RelocType = COFF_RELOC_DIR32 Then
    RelocTypeName := 'DIR32'
  Else
    RelocTypeName := IntToStr_(RelocType);
End;

Procedure DumpImportRelocTables;
Var
  I : Integer;
Begin
  If Not Opts.DebugMode Then Exit;
  WriteLn('--- Imports externes ---');
  If ImportCount = 0 Then
    WriteLn('  (aucun)');
  For I := 0 To ImportCount - 1 Do
    WriteLn('  [', I, '] ', ImportTab[I].Name,
      ' asm=', ImportTab[I].MangledName,
      ' module=', ImportTab[I].ModuleName,
      ' abi=', ImportTab[I].AbiName);

  WriteLn('--- Relocations COFF prevues ---');
  If RelocCount = 0 Then
    WriteLn('  (aucune)');
  For I := 0 To RelocCount - 1 Do
    WriteLn('  [', I, '] ', RelocTab[I].SectionName,
      ' ', RelocTypeName(RelocTab[I].RelocType),
      ' ', RelocTab[I].SymbolName,
      ' ', RelocTab[I].Note);
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
  CodeLen := 0;
  DataLen := 0;
  RdataLen := 0;
  BssLen := 0;
  BinLabelCount := 0;
  BinPatchCount := 0;
  CoffTextRelCnt := 0;
  PeImpLen   := 0;
  PeStartLen := 0;
  PePrintlnVA := 0;
  PePanicVA   := 0;
  PeEntryVA   := 0;
  For I := 0 To MAX_IMPORT - 1 Do
  Begin
    PeImpIatVA[I] := 0;
    PeThunkVA[I]  := 0;
  End;
  For I := 0 To MAX_BIN_LABEL - 1 Do
  Begin
    BinLabelNames[I] := '';
    BinLabelOffs[I]  := -1;
  End;
  For I := 0 To MAX_PATCH_TAB - 1 Do
  Begin
    BinPatchLabel[I] := '';
    BinPatchOff[I]   := 0;
    BinPatchInstr[I] := 0;
    BinPatchRel[I]   := False;
  End;
End;

{ ============================================================ }
{ BACKEND BINAIRE x86 / COFF                                   }
{ ============================================================ }

{ ---- Primitives d'emission dans CodeBuf ---- }

Procedure BinB(V : Byte);
Begin
  If CodeLen < MAX_BIN_CODE Then
  Begin
    CodeBuf[CodeLen] := V;
    Inc(CodeLen);
  End;
End;

Procedure BinW(V : Word);
Begin
  BinB(V And $FF);
  BinB((V Shr 8) And $FF);
End;

Procedure BinD(V : LongInt);
Begin
  BinB(LongInt(V) And $FF);
  BinB((LongInt(V) Shr 8) And $FF);
  BinB((LongInt(V) Shr 16) And $FF);
  BinB((LongInt(V) Shr 24) And $FF);
End;

Procedure DataB(V : Byte);
Begin
  If DataLen < MAX_BIN_DATA Then
  Begin
    DataBuf[DataLen] := V;
    Inc(DataLen);
  End;
End;

Procedure DataD(V : LongInt);
Begin
  DataB(LongInt(V) And $FF);
  DataB((LongInt(V) Shr 8) And $FF);
  DataB((LongInt(V) Shr 16) And $FF);
  DataB((LongInt(V) Shr 24) And $FF);
End;

Procedure RdataB(V : Byte);
Begin
  If RdataLen < MAX_BIN_RDATA Then
  Begin
    RdataBuf[RdataLen] := V;
    Inc(RdataLen);
  End;
End;

{ ---- Gestion des labels binaires ---- }

Procedure XDefineLabel(Const Name : TString);
Var
  I : Integer;
Begin
  For I := 0 To BinLabelCount - 1 Do
    If BinLabelNames[I] = Name Then
    Begin
      BinLabelOffs[I] := CodeLen;
      Exit;
    End;
  If BinLabelCount < MAX_BIN_LABEL Then
  Begin
    BinLabelNames[BinLabelCount] := Name;
    BinLabelOffs[BinLabelCount]  := CodeLen;
    Inc(BinLabelCount);
  End;
End;

Function XFindLabel(Const Name : TString) : LongInt;
Var
  I : Integer;
Begin
  XFindLabel := -1;
  For I := 0 To BinLabelCount - 1 Do
    If BinLabelNames[I] = Name Then
    Begin
      XFindLabel := BinLabelOffs[I];
      Exit;
    End;
End;

Procedure XAddPatch(Const Name : TString; PatchOff, InstrOff : LongInt;
  IsRel : Boolean);
Begin
  If BinPatchCount < MAX_PATCH_TAB Then
  Begin
    BinPatchLabel[BinPatchCount] := Name;
    BinPatchOff[BinPatchCount]   := PatchOff;
    BinPatchInstr[BinPatchCount] := InstrOff;
    BinPatchRel[BinPatchCount]   := IsRel;
    Inc(BinPatchCount);
  End;
End;

Procedure XResolvePatches;
Var
  I   : Integer;
  Off : LongInt;
  Rel : LongInt;
  Po  : LongInt;
Begin
  For I := 0 To BinPatchCount - 1 Do
  Begin
    Off := XFindLabel(BinPatchLabel[I]);
    If Off < 0 Then
      Continue;
    Po := BinPatchOff[I];
    If Po + 3 >= MAX_BIN_CODE Then
      Continue;
    If BinPatchRel[I] Then
    Begin
      { REL32: valeur = target - (patch_end) = target - (InstrOff + instrLen) }
      { InstrOff = offset debut instruction, PatchOff = Po = offset du DWORD }
      Rel := Off - (Po + 4);
    End
    Else
      Rel := Off;
    CodeBuf[Po]   := Rel And $FF;
    CodeBuf[Po+1] := (Rel Shr 8) And $FF;
    CodeBuf[Po+2] := (Rel Shr 16) And $FF;
    CodeBuf[Po+3] := (Rel Shr 24) And $FF;
  End;
End;

Procedure XAddTextReloc(SymName : TString; RelocType : Word);
Begin
  If CoffTextRelCnt < MAX_RELOC Then
  Begin
    CoffTextRelVA[CoffTextRelCnt]  := CodeLen;
    CoffTextRelSym[CoffTextRelCnt] := SymName;
    CoffTextRelTy[CoffTextRelCnt]  := RelocType;
    Inc(CoffTextRelCnt);
  End;
End;

{ ---- Encodeurs x86 80386 ---- }

{ Encode ModRM: mod=10 (disp32) ou mod=01 (disp8) + reg/r + rm=EBP(5) }
Procedure XModRM_EBP(RegField : Byte; Disp : LongInt);
Begin
  If (Disp >= -128) And (Disp <= 127) Then
  Begin
    BinB($45 Or (RegField Shl 3)); { mod=01, rm=EBP }
    BinB(Byte(Disp And $FF));
  End
  Else
  Begin
    BinB($85 Or (RegField Shl 3)); { mod=10, rm=EBP }
    BinD(Disp);
  End;
End;

{ PUSH r32 }
Procedure XPushReg(Reg : Byte);
Begin
  BinB($50 Or Reg);
End;

{ POP r32 }
Procedure XPopReg(Reg : Byte);
Begin
  BinB($58 Or Reg);
End;

{ PUSH imm32 }
Procedure XPushImm32(V : LongInt);
Begin
  BinB($68);
  BinD(V);
End;

{ PUSH OFFSET label (DIR32 reloc, placeholder 0) }
Procedure XPushOffsetLabel(Const LabelName : TString);
Begin
  BinB($68);
  XAddTextReloc(LabelName, COFF_RELOC_DIR32);
  BinD(0);
End;

{ CALL rel32 (REL32 reloc, placeholder 0) }
Procedure XCallLabel(Const LabelName : TString);
Var
  InstrOff, PatchOff, Off : LongInt;
Begin
  InstrOff := CodeLen;
  BinB($E8);
  Off := XFindLabel(LabelName);
  If Off >= 0 Then
    BinD(Off - (CodeLen + 4))
  Else
  Begin
    PatchOff := CodeLen;
    BinD(0);
    XAddPatch(LabelName, PatchOff, InstrOff, True);
  End;
End;

{ CALL externe (REL32 reloc COFF) }
Procedure XCallExternal(Const SymName : TString);
Begin
  BinB($E8);
  XAddTextReloc(SymName, COFF_RELOC_REL32);
  BinD(-4);
End;

{ JMP near (E9 + rel32) }
Procedure XJmpNear(Const LabelName : TString);
Var
  InstrOff, PatchOff : LongInt;
  Off : LongInt;
Begin
  InstrOff := CodeLen;
  BinB($E9);
  Off := XFindLabel(LabelName);
  If Off >= 0 Then
    BinD(Off - (CodeLen + 4))
  Else
  Begin
    PatchOff := CodeLen;
    BinD(0);
    XAddPatch(LabelName, PatchOff, InstrOff, True);
  End;
End;

{ Jcc near (0F 8x + rel32) }
Procedure XJccNear(CC : Byte; Const LabelName : TString);
Var
  InstrOff, PatchOff : LongInt;
  Off : LongInt;
Begin
  InstrOff := CodeLen;
  BinB($0F);
  BinB($80 Or CC);
  Off := XFindLabel(LabelName);
  If Off >= 0 Then
    BinD(Off - (CodeLen + 4))
  Else
  Begin
    PatchOff := CodeLen;
    BinD(0);
    XAddPatch(LabelName, PatchOff, InstrOff, True);
  End;
End;

{ RET }
Procedure XRet;
Begin
  BinB($C3);
End;

{ MOV r32, r32 (8B /r) }
Procedure XMovRR(Dst, Src : Byte);
Begin
  BinB($8B);
  BinB($C0 Or (Dst Shl 3) Or Src);
End;

{ MOV r32, imm32 (B8+r) }
Procedure XMovRI(Reg : Byte; V : LongInt);
Begin
  BinB($B8 Or Reg);
  BinD(V);
End;

{ MOV [EBP+disp], r32 (89 ModRM [disp]) }
Procedure XMovEBPdispR(Disp : LongInt; Reg : Byte);
Begin
  BinB($89);
  XModRM_EBP(Reg, Disp);
End;

{ MOV r32, [EBP+disp] (8B ModRM [disp]) }
Procedure XMovREBPdisp(Reg : Byte; Disp : LongInt);
Begin
  BinB($8B);
  XModRM_EBP(Reg, Disp);
End;

{ MOV WORD PTR [EBP+disp], AX (66 89 ModRM) }
Procedure XMovEBPdispAX(Disp : LongInt);
Begin
  BinB($66);
  BinB($89);
  XModRM_EBP(REG_EAX, Disp);
End;

{ MOV BYTE PTR [EBP+disp], AL (88 ModRM) }
Procedure XMovEBPdispAL(Disp : LongInt);
Begin
  BinB($88);
  XModRM_EBP(REG_EAX, Disp);
End;

{ MOV [symbol], EAX — DIR32 reloc (89 05 addr32) }
Procedure XMovStaticEAX(Const SymName : TString);
Begin
  BinB($89);
  BinB($05);
  XAddTextReloc(SymName, COFF_RELOC_DIR32);
  BinD(0);
End;

{ MOV [symbol], AX — 66 89 05 addr32 }
Procedure XMovStaticAX(Const SymName : TString);
Begin
  BinB($66);
  BinB($89);
  BinB($05);
  XAddTextReloc(SymName, COFF_RELOC_DIR32);
  BinD(0);
End;

{ MOV [symbol], AL — 88 05 addr32 }
Procedure XMovStaticAL(Const SymName : TString);
Begin
  BinB($88);
  BinB($05);
  XAddTextReloc(SymName, COFF_RELOC_DIR32);
  BinD(0);
End;

{ MOV EAX, [symbol] — 8B 05 addr32 }
Procedure XMovEAXStatic(Const SymName : TString);
Begin
  BinB($8B);
  BinB($05);
  XAddTextReloc(SymName, COFF_RELOC_DIR32);
  BinD(0);
End;

{ SUB ESP, imm32 (81 EC) }
Procedure XSubESPImm32(V : LongInt);
Begin
  If (V >= 0) And (V <= 127) Then
  Begin
    BinB($83); BinB($EC); BinB(Byte(V));
  End
  Else
  Begin
    BinB($81); BinB($EC); BinD(V);
  End;
End;

{ ADD ESP, imm (83 C4 imm8 ou 81 C4 imm32) }
Procedure XAddESPImm(V : LongInt);
Begin
  If (V >= 0) And (V <= 127) Then
  Begin
    BinB($83); BinB($C4); BinB(Byte(V));
  End
  Else
  Begin
    BinB($81); BinB($C4); BinD(V);
  End;
End;

{ NEG EAX (F7 D8) }
Procedure XNegEAX;
Begin
  BinB($F7); BinB($D8);
End;

{ IMUL EBX (F7 EB) }
Procedure XImulEBX;
Begin
  BinB($F7); BinB($EB);
End;

{ CDQ (99) }
Procedure XCDQ;
Begin
  BinB($99);
End;

{ IDIV EBX (F7 FB) }
Procedure XIdivEBX;
Begin
  BinB($F7); BinB($FB);
End;

{ DIV EBX (F7 F3) }
Procedure XDivEBX;
Begin
  BinB($F7); BinB($F3);
End;

{ XOR r32, r32 (33 /r) }
Procedure XXorRR(Dst, Src : Byte);
Begin
  BinB($33);
  BinB($C0 Or (Dst Shl 3) Or Src);
End;

{ ADD r32, r32 (03 /r) }
Procedure XAddRR(Dst, Src : Byte);
Begin
  BinB($03);
  BinB($C0 Or (Dst Shl 3) Or Src);
End;

{ SUB r32, r32 (2B /r) }
Procedure XSubRR(Dst, Src : Byte);
Begin
  BinB($2B);
  BinB($C0 Or (Dst Shl 3) Or Src);
End;

{ AND r8, r8 (22 /r) }
Procedure XAndR8R8(Dst, Src : Byte);
Begin
  BinB($22);
  BinB($C0 Or (Dst Shl 3) Or Src);
End;

{ OR r8, r8 (0A /r) }
Procedure XOrR8R8(Dst, Src : Byte);
Begin
  BinB($0A);
  BinB($C0 Or (Dst Shl 3) Or Src);
End;

{ CMP r32, imm8 (83 /7) }
Procedure XCmpRImm8(Reg : Byte; V : Byte);
Begin
  BinB($83);
  BinB($F8 Or Reg);
  BinB(V);
End;

{ CMP r32, r32 (3B /r) }
Procedure XCmpRR(Dst, Src : Byte);
Begin
  BinB($3B);
  BinB($C0 Or (Dst Shl 3) Or Src);
End;

{ SETcc r8 (0F 9x /r) }
Procedure XSetccR8(CC : Byte; Reg : Byte);
Begin
  BinB($0F);
  BinB($90 Or CC);
  BinB($C0 Or Reg);
End;

{ MOVZX r32, r8 (0F B6 /r) }
Procedure XMovzxR32R8(Dst, Src : Byte);
Begin
  BinB($0F); BinB($B6);
  BinB($C0 Or (Dst Shl 3) Or Src);
End;

{ MOVSX r32, r8 (0F BE /r) }
Procedure XMovsxR32R8(Dst, Src : Byte);
Begin
  BinB($0F); BinB($BE);
  BinB($C0 Or (Dst Shl 3) Or Src);
End;

{ MOVZX r32, r16 (0F B7 /r) }
Procedure XMovzxR32R16(Dst, Src : Byte);
Begin
  BinB($0F); BinB($B7);
  BinB($C0 Or (Dst Shl 3) Or Src);
End;

{ MOVSX r32, r16 (0F BF /r) }
Procedure XMovsxR32R16(Dst, Src : Byte);
Begin
  BinB($0F); BinB($BF);
  BinB($C0 Or (Dst Shl 3) Or Src);
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
      Begin
        EmitAsm('  MOVSX EAX, AL');
        XMovsxR32R8(REG_EAX, REG_EAX);
      End
      Else
      Begin
        EmitAsm('  MOVZX EAX, AL');
        XMovzxR32R8(REG_EAX, REG_EAX);
      End;
    RC_WORD:
      If TypeIsSigned(TypeIdx) Then
      Begin
        EmitAsm('  MOVSX EAX, AX');
        XMovsxR32R16(REG_EAX, REG_EAX);
      End
      Else
      Begin
        EmitAsm('  MOVZX EAX, AX');
        XMovzxR32R16(REG_EAX, REG_EAX);
      End;
  End;
End;

Procedure EmitExprLoad(Const E : TExprRec; Const RegName : TString);
Begin
  If E.Kind = EK_LITERAL Then
  Begin
    EmitAsm('  MOV ' + RegName + ', ' + IntToStr_(E.IntValue));
    XMovRI(REG_EAX, E.IntValue);
  End
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
  Disp : LongInt;
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

  { binaire : store EAX/AX/AL -> destination }
  If (SymTab[SymIdx].Cat = SC_LOCAL) Or (SymTab[SymIdx].Cat = SC_PARAM) Then
  Begin
    Disp := SymTab[SymIdx].Offset;
    Case TypeRegClass(TypeIdx) Of
      RC_BYTE  : XMovEBPdispAL(Disp);
      RC_WORD  : XMovEBPdispAX(Disp);
    Else
      XMovEBPdispR(Disp, REG_EAX);
    End;
  End
  Else If SymTab[SymIdx].Cat = SC_STATIC Then
  Begin
    Case TypeRegClass(TypeIdx) Of
      RC_BYTE  : XMovStaticAL(SymTab[SymIdx].MangledName);
      RC_WORD  : XMovStaticAX(SymTab[SymIdx].MangledName);
    Else
      XMovStaticEAX(SymTab[SymIdx].MangledName);
    End;
  End;
End;

Procedure EmitLabel(Const LabelName : TString);
Begin
  EmitAsm(LabelName + ':');
  XDefineLabel(LabelName);
End;

Procedure EmitJump(Const LabelName : TString);
Begin
  EmitAsm('  JMP ' + LabelName);
  XJmpNear(LabelName);
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
  XCmpRImm8(REG_EAX, 0);
  XJccNear(CC_E, FalseLabel);
End;

Procedure EmitFunctionPrologue(ProcIdx : Integer; Const ReturnLabel : TString);
Var
  J : Integer;
  Sig : TString;
Begin
  If (ProcIdx < 0) Or (ProcIdx >= ProcCount) Then
    Exit;
  Sig := 'fn ' + ProcTab[ProcIdx].Name + '(';
  For J := 0 To ProcTab[ProcIdx].ParamCount - 1 Do
  Begin
    If J > 0 Then Sig := Sig + ', ';
    Sig := Sig + ProcTab[ProcIdx].ParamNames[J];
    If ProcTab[ProcIdx].ParamTypes[J] <> TY_UNKNOWN Then
      Sig := Sig + ': ' + TypeTab[ProcTab[ProcIdx].ParamTypes[J]].Name;
  End;
  Sig := Sig + ')';
  If ProcTab[ProcIdx].RetTypeIdx <> TY_IDX_UNIT Then
    Sig := Sig + ' -> ' + TypeTab[ProcTab[ProcIdx].RetTypeIdx].Name;
  EmitAsm('');
  EmitAsm('; --- ' + Sig + ' ---');
  EmitAsm(ProcTab[ProcIdx].MangledName + ' PROC');
  EmitAsm('  PUSH EBP');
  EmitAsm('  MOV EBP, ESP');
  EmitAsm('  SUB ESP, ' + IntToStr_(MAX_LOCAL * WORD_SIZE));
  EmitAsm('  PUSH EBX');
  EmitAsm('  ; convention: args sur pile, retour EAX, caller cleanup');
  { binaire }
  XDefineLabel(ProcTab[ProcIdx].MangledName);
  XPushReg(REG_EBP);
  XMovRR(REG_EBP, REG_ESP);
  XSubESPImm32(MAX_LOCAL * WORD_SIZE);
  XPushReg(REG_EBX);
End;

Procedure EmitFunctionEpilogue(ProcIdx : Integer; Const ReturnLabel : TString);
Begin
  If (ProcIdx < 0) Or (ProcIdx >= ProcCount) Then
    Exit;
  EmitLabel(ReturnLabel);
  EmitAsm('  POP EBX');
  EmitAsm('  MOV ESP, EBP');
  EmitAsm('  POP EBP');
  EmitAsm('  RET');
  EmitAsm(ProcTab[ProcIdx].MangledName + ' ENDP');
  { binaire }
  XPopReg(REG_EBX);
  XMovRR(REG_ESP, REG_EBP);
  XPopReg(REG_EBP);
  XRet;
End;

Procedure EmitReturnExpr(Const RetExpr : TExprRec);
Begin
  If RetExpr.TypeIdx <> TY_IDX_UNIT Then
  Begin
    EmitExprLoad(RetExpr, 'EAX');
    EmitExtendToEax(RetExpr.TypeIdx);
  End;
  If (CurrentProcIdx >= 0) And (CurrentReturnLabel <> '') Then
    EmitJump(CurrentReturnLabel);
End;

Procedure EmitCallProc(ProcIdx : Integer; Const Args : TExprArgArray;
  ArgCount : Integer);
Var
  I : Integer;
Begin
  If (ProcIdx < 0) Or (ProcIdx >= ProcCount) Then
    Exit;
  For I := ArgCount - 1 DownTo 0 Do
  Begin
    EmitExprLoad(Args[I], 'EAX');
    EmitExtendToEax(Args[I].TypeIdx);
    EmitAsm('  PUSH EAX');
    XPushReg(REG_EAX);
  End;
  EmitAsm('  CALL ' + ProcTab[ProcIdx].MangledName);
  If ProcTab[ProcIdx].IsExtern Then
  Begin
    AddRelocRec('.text', ProcTab[ProcIdx].MangledName, COFF_RELOC_REL32,
      'CALL extern ' + ProcTab[ProcIdx].Name);
    XCallExternal(ProcTab[ProcIdx].MangledName);
    Inc(ExternCallCount);
  End
  Else
    XCallLabel(ProcTab[ProcIdx].MangledName);
  If ArgCount > 0 Then
  Begin
    EmitAsm('  ADD ESP, ' + IntToStr_(ArgCount * WORD_SIZE));
    XAddESPImm(ArgCount * WORD_SIZE);
  End;
  Inc(CallCount);
End;

Function RuntimeSymbol(Const Name : TString) : TString;
Begin
  RuntimeSymbol := RS_RT_PFX + Name;
End;

Function ExternSymbol(Const Name : TString) : TString;
Begin
  ExternSymbol := RS_EXT_PFX + Name;
End;

Procedure EnsureRuntimeImports;
Begin
  AddImportRec('GetStdHandle', ExternSymbol('GetStdHandle'),
    'kernel32.dll', 'stdcall', -1, -1);
  AddImportRec('WriteFile', ExternSymbol('WriteFile'),
    'kernel32.dll', 'stdcall', -1, -1);
  AddImportRec('ExitProcess', ExternSymbol('ExitProcess'),
    'kernel32.dll', 'stdcall', -1, -1);
End;

Procedure EmitRuntimeCall(Const Name, Note : TString; ArgBytes : Integer);
Var
  SymName : TString;
Begin
  SymName := RuntimeSymbol(Name);
  EmitAsm('  CALL ' + SymName);
  AddRelocRec('.text', SymName, COFF_RELOC_REL32, Note);
  XCallExternal(SymName);
  If ArgBytes > 0 Then
  Begin
    EmitAsm('  ADD ESP, ' + IntToStr_(ArgBytes));
    XAddESPImm(ArgBytes);
  End;
  Inc(CallCount);
End;

Procedure EmitExternalRuntimeCall(Const Name, Note : TString; ArgBytes : Integer);
Var
  SymName : TString;
Begin
  SymName := ExternSymbol(Name);
  AddImportRec(Name, SymName, DefaultImportModule(Name, 'stdcall'),
    'stdcall', -1, -1);
  EmitAsm('  CALL ' + SymName);
  AddRelocRec('.text', SymName, COFF_RELOC_REL32, Note);
  XCallExternal(SymName);
  If ArgBytes > 0 Then
  Begin
    EmitAsm('  ADD ESP, ' + IntToStr_(ArgBytes));
    XAddESPImm(ArgBytes);
  End;
  Inc(CallCount);
  Inc(ExternCallCount);
End;

Procedure EmitPushStringRef(StrIdx : Integer; Const Note : TString);
Begin
  If (StrIdx < 0) Or (StrIdx >= StringCount) Then
    Exit;
  EmitAsm('  PUSH ' + IntToStr_(StringTab[StrIdx].Len));
  EmitAsm('  PUSH OFFSET ' + StringTab[StrIdx].LabelName);
  AddRelocRec('.text', StringTab[StrIdx].LabelName, COFF_RELOC_DIR32, Note);
  XPushImm32(StringTab[StrIdx].Len);
  XPushOffsetLabel(StringTab[StrIdx].LabelName);
End;

Procedure EmitPrintlnString(StrIdx : Integer);
Begin
  EnsureRuntimeImports;
  EmitAsm('  ; println! chaine litterale');
  EmitPushStringRef(StrIdx, 'adresse chaine println!');
  EmitRuntimeCall('println', 'appel runtime println!', 2 * WORD_SIZE);
  Inc(RuntimeMacroCount);
  Inc(PrintlnCount);
End;

Procedure EmitPanicString(StrIdx : Integer);
Begin
  EnsureRuntimeImports;
  EmitAsm('  ; panic! chaine litterale');
  EmitPushStringRef(StrIdx, 'adresse chaine panic!');
  EmitRuntimeCall('panic', 'appel runtime panic!', 2 * WORD_SIZE);
  EmitAsm('  PUSH 1');
  XPushImm32(1);
  EmitExternalRuntimeCall('ExitProcess', 'terminaison apres panic!',
    WORD_SIZE);
  Inc(RuntimeMacroCount);
  Inc(PanicCount);
End;

Procedure EmitDebugAssert(Const CondExpr : TExprRec);
Var
  OkLabel : TString;
  MsgIdx  : Integer;
Begin
  EnsureRuntimeImports;
  OkLabel := NewLabelName;
  EmitAsm('  ; debug_assert!');
  EmitExprLoad(CondExpr, 'EAX');
  EmitExtendToEax(CondExpr.TypeIdx);
  EmitAsm('  CMP EAX, 0');
  EmitAsm('  JNE ' + OkLabel);
  XCmpRImm8(REG_EAX, 0);
  XJccNear(CC_NE, OkLabel);
  MsgIdx := AddStringRec('debug_assert! failed'#13#10);
  EmitPushStringRef(MsgIdx, 'adresse message debug_assert!');
  EmitRuntimeCall('panic', 'appel runtime panic! debug_assert',
    2 * WORD_SIZE);
  EmitAsm('  PUSH 1');
  XPushImm32(1);
  EmitExternalRuntimeCall('ExitProcess', 'terminaison debug_assert!',
    WORD_SIZE);
  EmitLabel(OkLabel);
  Inc(RuntimeMacroCount);
  Inc(DebugAssertCount);
End;

Procedure EmitUnaryArith(Const Op : TString; Const E : TExprRec);
Begin
  If Op = '-' Then
  Begin
    EmitExprLoad(E, 'EAX');
    EmitExtendToEax(E.TypeIdx);
    EmitAsm('  NEG EAX');
    XNegEAX;
  End
  Else If Op = '!' Then
  Begin
    EmitExprLoad(E, 'EAX');
    EmitExtendToEax(E.TypeIdx);
    EmitAsm('  CMP EAX, 0');
    EmitAsm('  SETE AL');
    EmitAsm('  MOVZX EAX, AL');
    XCmpRImm8(REG_EAX, 0);
    XSetccR8(CC_E, REG_EAX);
    XMovzxR32R8(REG_EAX, REG_EAX);
  End
  Else If Op = '*' Then
    EmitAsm('  ; dereferencement brut differe au backend pointeurs')
  Else If Op = '&' Then
    EmitAsm('  ; adresse brute differee au backend pointeurs');
End;

Procedure EmitSetcc(Const Op : TString; SignedCmp : Boolean);
Var
  Mn : TString;
  CC : Byte;
Begin
  Mn := 'SETE'; CC := CC_E;
  If Op = '==' Then Begin Mn := 'SETE';  CC := CC_E;  End
  Else If Op = '!=' Then Begin Mn := 'SETNE'; CC := CC_NE; End
  Else If SignedCmp Then
  Begin
    If Op = '<'  Then Begin Mn := 'SETL';  CC := CC_L;  End
    Else If Op = '<=' Then Begin Mn := 'SETLE'; CC := CC_LE; End
    Else If Op = '>'  Then Begin Mn := 'SETG';  CC := CC_G;  End
    Else If Op = '>=' Then Begin Mn := 'SETGE'; CC := CC_GE; End;
  End
  Else
  Begin
    If Op = '<'  Then Begin Mn := 'SETB';  CC := CC_B;  End
    Else If Op = '<=' Then Begin Mn := 'SETBE'; CC := CC_BE; End
    Else If Op = '>'  Then Begin Mn := 'SETA';  CC := CC_A;  End
    Else If Op = '>=' Then Begin Mn := 'SETAE'; CC := CC_AE; End;
  End;
  EmitAsm('  ' + Mn + ' AL');
  EmitAsm('  MOVZX EAX, AL');
  XSetccR8(CC, REG_EAX);
  XMovzxR32R8(REG_EAX, REG_EAX);
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
  XPushReg(REG_EAX);
  EmitExprLoad(Right, 'EAX');
  EmitExtendToEax(Right.TypeIdx);
  EmitAsm('  MOV EBX, EAX');
  XMovRR(REG_EBX, REG_EAX);
  EmitAsm('  POP EAX');
  XPopReg(REG_EAX);

  SignedOp := TypeIsSignedInt(ResultType) Or TypeIsSignedInt(Left.TypeIdx) Or
    TypeIsSignedInt(Right.TypeIdx);

  If (Op = '-') And (Left.Kind = EK_LITERAL) And Left.IsConst And
     (Left.IntValue = 0) Then
  Begin
    EmitExprLoad(Right, 'EAX');
    EmitExtendToEax(Right.TypeIdx);
    EmitAsm('  NEG EAX');
    XNegEAX;
  End
  Else If Op = '+' Then
  Begin
    EmitAsm('  ADD EAX, EBX');
    XAddRR(REG_EAX, REG_EBX);
  End
  Else If Op = '-' Then
  Begin
    EmitAsm('  SUB EAX, EBX');
    XSubRR(REG_EAX, REG_EBX);
  End
  Else If Op = '*' Then
  Begin
    EmitAsm('  IMUL EBX');
    XImulEBX;
  End
  Else If (Op = '/') Or (Op = '%') Then
  Begin
    If SignedOp Then
    Begin
      EmitAsm('  CDQ');
      EmitAsm('  IDIV EBX');
      XCDQ;
      XIdivEBX;
    End
    Else
    Begin
      EmitAsm('  XOR EDX, EDX');
      EmitAsm('  DIV EBX');
      XXorRR(REG_EDX, REG_EDX);
      XDivEBX;
    End;
    If Op = '%' Then
    Begin
      EmitAsm('  MOV EAX, EDX');
      XMovRR(REG_EAX, REG_EDX);
    End;
  End
  Else If (Op = '==') Or (Op = '!=') Or (Op = '<') Or (Op = '<=') Or
          (Op = '>') Or (Op = '>=') Then
  Begin
    EmitAsm('  CMP EAX, EBX');
    XCmpRR(REG_EAX, REG_EBX);
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
    XCmpRImm8(REG_EAX, 0); XSetccR8(CC_NE, REG_EAX);
    XCmpRImm8(REG_EBX, 0); XSetccR8(CC_NE, REG_EBX);
    XAndR8R8(REG_EAX, REG_EBX);
    XMovzxR32R8(REG_EAX, REG_EAX);
  End
  Else If Op = '||' Then
  Begin
    EmitAsm('  CMP EAX, 0');
    EmitAsm('  SETNE AL');
    EmitAsm('  CMP EBX, 0');
    EmitAsm('  SETNE BL');
    EmitAsm('  OR AL, BL');
    EmitAsm('  MOVZX EAX, AL');
    XCmpRImm8(REG_EAX, 0); XSetccR8(CC_NE, REG_EAX);
    XCmpRImm8(REG_EBX, 0); XSetccR8(CC_NE, REG_EBX);
    XOrR8R8(REG_EAX, REG_EBX);
    XMovzxR32R8(REG_EAX, REG_EAX);
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

Function AsmOutputFileName : TString;
Begin
  AsmOutputFileName := ReplaceExt(Opts.OutFile, '.asm');
End;

Function AsmDataDirective(TypeIdx : Integer) : TString;
Begin
  Case TypeRegClass(TypeIdx) Of
    RC_BYTE  : AsmDataDirective := 'DB';
    RC_WORD  : AsmDataDirective := 'DW';
    RC_DWORD : AsmDataDirective := 'DD';
  Else
    AsmDataDirective := 'DD';
  End;
End;

Procedure WriteAsmStringBytes(Var F : Text; Const TextVal : TString);
Var
  I : Integer;
Begin
  For I := 1 To Length(TextVal) Do
  Begin
    If I > 1 Then
      Write(F, ',');
    Write(F, Ord(TextVal[I]));
  End;
  If Length(TextVal) > 0 Then
    Write(F, ',');
  WriteLn(F, '0');
End;

Procedure EmitAsmFile;
Var
  F : Text;
  Code, I : Integer;
  AsmName, EntryName : TString;
  HasInitData, HasBssData : Boolean;
Begin
  If Not Opts.EmitAsm Then
    Exit;
  If ErrorCount <> 0 Then
  Begin
    WarnMsg('ASM non produit car le parsing contient des erreurs');
    Exit;
  End;

  AsmName := AsmOutputFileName;
  Assign(F, AsmName);
  {$I-}
  Rewrite(F);
  {$I+}
  Code := IOResult;
  If Code <> 0 Then
    FatalError('impossible de creer le fichier ASM: ' + AsmName);

  WriteLn(F, '; Fichier genere par RUSTCW32 v', RUSTCW32_VERSION);
  WriteLn(F, '; Source : ', Opts.SrcFile);
  WriteLn(F, '; Cible  : MASM 80386 / Win32');
  WriteLn(F);
  WriteLn(F, '.386');
  WriteLn(F, '.MODEL FLAT, STDCALL');
  WriteLn(F, 'OPTION CASEMAP:NONE');
  WriteLn(F);

  For I := 0 To ProcCount - 1 Do
    If Not ProcTab[I].IsExtern Then
      WriteLn(F, 'PUBLIC ', ProcTab[I].MangledName);
  For I := 0 To StaticCount - 1 Do
    WriteLn(F, 'PUBLIC ', StaticTab[I].MangledName);
  For I := 0 To ImportCount - 1 Do
    WriteLn(F, 'EXTERN ', ImportTab[I].MangledName,
      ':PROC ; ', ImportTab[I].ModuleName);
  If PrintlnCount > 0 Then
    WriteLn(F, 'EXTERN ', RuntimeSymbol('println'), ':PROC');
  If (PanicCount > 0) Or (DebugAssertCount > 0) Then
    WriteLn(F, 'EXTERN ', RuntimeSymbol('panic'), ':PROC');
  WriteLn(F);

  WriteLn(F, '.CONST');
  If StringCount = 0 Then
    WriteLn(F, '  ; aucune chaine .rdata')
  Else
    For I := 0 To StringCount - 1 Do
    Begin
      Write(F, StringTab[I].LabelName, ' DB ');
      WriteAsmStringBytes(F, StringTab[I].Text);
    End;
  WriteLn(F);

  { Donnees initialisees (.data) }
  WriteLn(F, '.DATA');
  HasInitData := False;
  For I := 0 To StaticCount - 1 Do
    If StaticTab[I].HasInit Then
    Begin
      HasInitData := True;
      Write(F, StaticTab[I].MangledName, ' ',
        AsmDataDirective(StaticTab[I].TypeIdx), ' ');
      WriteLn(F, StaticTab[I].IntValue);
    End;
  If Not HasInitData Then
    WriteLn(F, '  ; aucune donnee initialisee');
  WriteLn(F);

  { Donnees non initialisees / BSS (.data?) }
  WriteLn(F, '.DATA?');
  HasBssData := False;
  For I := 0 To StaticCount - 1 Do
    If Not StaticTab[I].HasInit Then
    Begin
      HasBssData := True;
      WriteLn(F, StaticTab[I].MangledName, ' ',
        AsmDataDirective(StaticTab[I].TypeIdx), ' ?');
    End;
  If Not HasBssData Then
    WriteLn(F, '  ; aucune donnee non initialisee (BSS)');
  WriteLn(F);

  WriteLn(F, '.CODE');
  WriteLn(F, '; --- Code genere depuis le backend intermediaire ---');
  If AsmTraceCount = 0 Then
    WriteLn(F, '  ; aucune instruction backend')
  Else
  Begin
    For I := 0 To AsmTraceCount - 1 Do
      If I < MAX_ASM_TRACE Then
        WriteLn(F, AsmTrace[I]);
    If AsmTraceCount > MAX_ASM_TRACE Then
      WriteLn(F, '  ; trace ASM tronquee');
  End;

  If MainProcIdx >= 0 Then
    EntryName := ProcTab[MainProcIdx].MangledName
  Else
    EntryName := '';
  WriteLn(F);
  If EntryName <> '' Then
    WriteLn(F, 'END ', EntryName)
  Else
    WriteLn(F, 'END');

  Close(F);
  If Opts.Verbose Then
    WriteLn('ASM ecrit     : ', AsmName);
End;

{ ============================================================ }
{ EMISSION COFF .OBJ (TODO 23)                                 }
{ ============================================================ }

Procedure BuildRdataSection;
Var
  I, J : Integer;
Begin
  RdataLen := 0;
  For I := 0 To StringCount - 1 Do
  Begin
    StringRdataOff[I] := RdataLen;
    For J := 1 To Length(StringTab[I].Text) Do
      RdataB(Ord(StringTab[I].Text[J]));
    RdataB(0);
  End;
End;

Procedure BuildDataSection;
Var
  I, K : Integer;
  V    : LongInt;
  Sz   : Integer;
  BssOff : LongInt;
Begin
  DataLen := 0;
  BssLen  := 0;
  BssOff  := 0;
  For I := 0 To StaticCount - 1 Do
  Begin
    Sz := TypeSize(StaticTab[I].TypeIdx);
    If Sz <= 0 Then Sz := 4;
    If StaticTab[I].HasInit Then
    Begin
      StaticDataOff[I] := DataLen;
      V := StaticTab[I].IntValue;
      For K := 0 To Sz - 1 Do
      Begin
        DataB(LongInt(V) And $FF);
        V := LongInt(V) Shr 8;
      End;
    End
    Else
    Begin
      StaticDataOff[I] := BssOff;
      Inc(BssOff, Sz);
      Inc(BssLen, Sz);
    End;
  End;
End;

Function AlignUp(V, A : LongInt) : LongInt;
Begin
  If A <= 1 Then
    AlignUp := V
  Else
    AlignUp := ((V + A - 1) Div A) * A;
End;

Procedure CoffWriteObjFile(Const FileName : TString);
Var
  ObjF         : File;
  Code         : Integer;
  { offsets dans le fichier }
  OffHeaders   : LongInt;
  OffTextData  : LongInt;
  OffRdataData : LongInt;
  OffDataData  : LongInt;
  OffTextReloc : LongInt;
  OffSymTab    : LongInt;
  { tailles alignees }
  CodePad, RdataPad, DataPad : LongInt;
  { table des symboles (en memoire) }
  SymBuf       : Array[0..2047] Of Byte;
  SymBufLen    : Integer;
  { table de chaines COFF }
  CoffStrtab   : Array[0..8191] Of Byte;
  CoffStrtabLen : LongInt;
  { compteurs/indices }
  SymCount_Coff  : Integer;
  { helpers }
  I            : Integer;
  V32          : LongInt;

  { ---- helper: ecriture dans le fichier ---- }
  Procedure WB(B : Byte);
  Begin
    BlockWrite(ObjF, B, 1);
  End;

  Procedure WW(W : Word);
  Begin
    WB(W And $FF);
    WB((W Shr 8) And $FF);
  End;

  Procedure WD(D : LongInt);
  Begin
    WB(LongInt(D) And $FF);
    WB((LongInt(D) Shr 8) And $FF);
    WB((LongInt(D) Shr 16) And $FF);
    WB((LongInt(D) Shr 24) And $FF);
  End;

  Procedure WBytes(Var Buf; Len : LongInt);
  Begin
    If Len > 0 Then
      BlockWrite(ObjF, Buf, Len);
  End;

  Procedure WZeros(N : LongInt);
  Var
    Tmp : Byte;
    K   : LongInt;
  Begin
    Tmp := 0;
    For K := 1 To N Do
      BlockWrite(ObjF, Tmp, 1);
  End;

  { ---- helper: ajouter une chaine a la strtab COFF ---- }
  Function AddStrtab(Const S : TString) : LongInt;
  Var
    K : Integer;
  Begin
    AddStrtab := CoffStrtabLen;
    For K := 1 To Length(S) Do
    Begin
      If CoffStrtabLen < 8190 Then
      Begin
        CoffStrtab[CoffStrtabLen] := Ord(S[K]);
        Inc(CoffStrtabLen);
      End;
    End;
    CoffStrtab[CoffStrtabLen] := 0;
    Inc(CoffStrtabLen);
  End;

  { ---- helper: ecrire un nom de symbole COFF (8 octets) ---- }
  Function WriteSymName(Const S : TString) : LongInt;
  Var
    K : Integer;
    Off : LongInt;
  Begin
    If Length(S) <= 8 Then
    Begin
      For K := 1 To Length(S) Do WB(Ord(S[K]));
      For K := Length(S) + 1 To 8 Do WB(0);
      WriteSymName := 0;
    End
    Else
    Begin
      Off := AddStrtab(S);
      WD(0);
      WD(Off + 4); { strtab offset (apres le size DWORD) }
      WriteSymName := Off;
    End;
  End;

  { ---- helper: ajouter un symbole dans SymBuf ---- }
  Procedure AddSymbol(Const Name : TString; Value : LongInt;
    SecNum : Integer; SymType : Word; StorageClass : Byte;
    NbAux : Byte);
  Var
    K   : Integer;
    Off : LongInt;
  Begin
    If SymBufLen + 18 > High(SymBuf) Then Exit;
    { Name : 8 octets }
    If Length(Name) <= 8 Then
    Begin
      For K := 1 To Length(Name) Do
      Begin
        SymBuf[SymBufLen] := Ord(Name[K]);
        Inc(SymBufLen);
      End;
      For K := Length(Name) + 1 To 8 Do
      Begin
        SymBuf[SymBufLen] := 0;
        Inc(SymBufLen);
      End;
    End
    Else
    Begin
      Off := AddStrtab(Name);
      SymBuf[SymBufLen]   := 0; Inc(SymBufLen);
      SymBuf[SymBufLen]   := 0; Inc(SymBufLen);
      SymBuf[SymBufLen]   := 0; Inc(SymBufLen);
      SymBuf[SymBufLen]   := 0; Inc(SymBufLen);
      Off := Off + 4;
      SymBuf[SymBufLen] := LongInt(Off) And $FF; Inc(SymBufLen);
      SymBuf[SymBufLen] := (LongInt(Off) Shr 8) And $FF; Inc(SymBufLen);
      SymBuf[SymBufLen] := (LongInt(Off) Shr 16) And $FF; Inc(SymBufLen);
      SymBuf[SymBufLen] := (LongInt(Off) Shr 24) And $FF; Inc(SymBufLen);
    End;
    { Value : 4 }
    SymBuf[SymBufLen] := LongInt(Value) And $FF;         Inc(SymBufLen);
    SymBuf[SymBufLen] := (LongInt(Value) Shr 8) And $FF;  Inc(SymBufLen);
    SymBuf[SymBufLen] := (LongInt(Value) Shr 16) And $FF; Inc(SymBufLen);
    SymBuf[SymBufLen] := (LongInt(Value) Shr 24) And $FF; Inc(SymBufLen);
    { SectionNumber : 2 }
    SymBuf[SymBufLen] := SecNum And $FF;         Inc(SymBufLen);
    SymBuf[SymBufLen] := (SecNum Shr 8) And $FF; Inc(SymBufLen);
    { Type : 2 }
    SymBuf[SymBufLen] := SymType And $FF;         Inc(SymBufLen);
    SymBuf[SymBufLen] := (SymType Shr 8) And $FF; Inc(SymBufLen);
    { StorageClass : 1 }
    SymBuf[SymBufLen] := StorageClass; Inc(SymBufLen);
    { NbAux : 1 }
    SymBuf[SymBufLen] := NbAux; Inc(SymBufLen);
    Inc(SymCount_Coff);
  End;

  { ---- helper: ajouter un enregistrement aux (18 zeros) ---- }
  Procedure AddAuxRecord;
  Var K : Integer;
  Begin
    If SymBufLen + 18 > High(SymBuf) Then Exit;
    For K := 0 To 17 Do
    Begin
      SymBuf[SymBufLen] := 0;
      Inc(SymBufLen);
    End;
    Inc(SymCount_Coff);
  End;

  { ---- helper: indice du symbole par nom dans SymBuf ---- }
  { On maintient un tableau parallele nom->index pendant la construction }

  { Retourne l'indice COFF d'un symbole externe par son nom mangle }
  Function FindCoffSymIdx(Const MangledName : TString) : Integer;
  Var K : Integer;
  Begin
    { sections: .text=0, .rdata=2, .data=4, .bss=6 }
    { fonctions internes: 8, 8+1, ... }
    { Pour un appel externe, on cherche dans ImportTab }
    FindCoffSymIdx := 0; { defaut: .text }
    For K := 0 To ImportCount - 1 Do
      If ImportTab[K].MangledName = MangledName Then
      Begin
        { index = 8 + ProcCount_non_extern + K }
        FindCoffSymIdx := 8 + (ProcCount) + K;
        Exit;
      End;
    { runtime symbols }
    For K := 0 To ProcCount - 1 Do
      If ProcTab[K].MangledName = MangledName Then
      Begin
        FindCoffSymIdx := 8 + K;
        Exit;
      End;
  End;

Begin
  { --- 1. Construire les sections de donnees --- }
  BuildRdataSection;
  BuildDataSection;
  XResolvePatches;

  { --- 2. Calculer les offsets --- }
  CodePad  := AlignUp(CodeLen, 4);
  RdataPad := AlignUp(RdataLen, 4);
  DataPad  := AlignUp(DataLen, 4);

  OffHeaders   := 20 + 4 * 40;        { file header + 4 section headers }
  OffTextData  := OffHeaders;
  OffRdataData := OffTextData  + CodePad;
  OffDataData  := OffRdataData + RdataPad;

  { relocations .text juste apres les donnees de toutes les sections }
  OffTextReloc := OffDataData + DataPad;
  { apres les relocations .text, table des symboles }
  OffSymTab    := OffTextReloc + LongInt(CoffTextRelCnt) * 10;

  { --- 3. Construire la table des symboles en memoire --- }
  SymBufLen    := 0;
  SymCount_Coff := 0;
  CoffStrtabLen := 0;

  { sections (symbol + aux chacune) }
  AddSymbol('.text',  0, 1, 0, 3 {C_STAT}, 1); AddAuxRecord;
  AddSymbol('.rdata', 0, 2, 0, 3, 1);           AddAuxRecord;
  AddSymbol('.data',  0, 3, 0, 3, 1);           AddAuxRecord;
  AddSymbol('.bss',   0, 4, 0, 3, 1);           AddAuxRecord;

  { fonctions internes (Section 1 = .text) }
  For I := 0 To ProcCount - 1 Do
  Begin
    If Not ProcTab[I].IsExtern Then
    Begin
      V32 := XFindLabel(ProcTab[I].MangledName);
      If V32 < 0 Then V32 := 0;
      AddSymbol(ProcTab[I].MangledName, V32, 1, $20 {fn}, 2 {C_EXT}, 0);
    End;
  End;

  { symboles externes (imports) }
  For I := 0 To ImportCount - 1 Do
    AddSymbol(ImportTab[I].MangledName, 0, 0 {undefined}, 0, 2, 0);

  { statics dans .data ou .bss }
  For I := 0 To StaticCount - 1 Do
  Begin
    If StaticTab[I].HasInit Then
      AddSymbol(StaticTab[I].MangledName, 0, 3, 0, 2, 0)
    Else
      AddSymbol(StaticTab[I].MangledName, 0, 4, 0, 2, 0);
  End;

  { --- 4. Ouvrir le fichier et ecrire --- }
  Assign(ObjF, FileName);
  {$I-}
  Rewrite(ObjF, 1);
  {$I+}
  Code := IOResult;
  If Code <> 0 Then
  Begin
    FatalError('impossible de creer le fichier OBJ: ' + FileName);
    Exit;
  End;

  { --- 5. COFF File Header (20 octets) --- }
  WW(PE_MACHINE_I386);   { Machine }
  WW(4);                 { NumberOfSections: .text .rdata .data .bss }
  WD(0);                 { TimeDateStamp }
  WD(OffSymTab);         { PointerToSymbolTable }
  WD(SymCount_Coff);     { NumberOfSymbols }
  WW(0);                 { SizeOfOptionalHeader }
  WW(0);                 { Characteristics }

  { --- 6. Section Headers (4 x 40 octets) --- }

  { .text }
  WB(Ord('.')); WB(Ord('t')); WB(Ord('e')); WB(Ord('x'));
  WB(Ord('t')); WB(0); WB(0); WB(0);
  WD(0);              { VirtualSize (0 pour .OBJ) }
  WD(0);              { VirtualAddress }
  WD(CodePad);        { SizeOfRawData }
  WD(OffTextData);    { PointerToRawData }
  WD(OffTextReloc);   { PointerToRelocations }
  WD(0);              { PointerToLinenumbers }
  WW(CoffTextRelCnt); { NumberOfRelocations }
  WW(0);              { NumberOfLinenumbers }
  WD(PE_SCN_TEXT);    { Characteristics }

  { .rdata }
  WB(Ord('.')); WB(Ord('r')); WB(Ord('d')); WB(Ord('a'));
  WB(Ord('t')); WB(Ord('a')); WB(0); WB(0);
  WD(0); WD(0);
  WD(RdataPad);
  WD(OffRdataData);
  WD(0); WD(0); WW(0); WW(0);
  WD(PE_SCN_RDATA);

  { .data }
  WB(Ord('.')); WB(Ord('d')); WB(Ord('a')); WB(Ord('t'));
  WB(Ord('a')); WB(0); WB(0); WB(0);
  WD(0); WD(0);
  WD(DataPad);
  If DataPad > 0 Then
    WD(OffDataData)
  Else
    WD(0);
  WD(0); WD(0); WW(0); WW(0);
  WD(PE_SCN_DATA);

  { .bss }
  WB(Ord('.')); WB(Ord('b')); WB(Ord('s')); WB(Ord('s'));
  WB(0); WB(0); WB(0); WB(0);
  WD(BssLen);
  WD(0);
  WD(0);    { SizeOfRawData = 0 (pas de donnees dans le fichier) }
  WD(0);    { PointerToRawData = 0 }
  WD(0); WD(0); WW(0); WW(0);
  WD(PE_SCN_BSS);

  { --- 7. Section data --- }

  { .text }
  If CodeLen > 0 Then
    WBytes(CodeBuf, CodeLen);
  WZeros(CodePad - CodeLen);

  { .rdata }
  If RdataLen > 0 Then
    WBytes(RdataBuf, RdataLen);
  WZeros(RdataPad - RdataLen);

  { .data }
  If DataLen > 0 Then
    WBytes(DataBuf, DataLen);
  WZeros(DataPad - DataLen);

  { --- 8. Relocations .text --- }
  For I := 0 To CoffTextRelCnt - 1 Do
  Begin
    WD(CoffTextRelVA[I]);
    WD(FindCoffSymIdx(CoffTextRelSym[I]));
    WW(CoffTextRelTy[I]);
  End;

  { --- 9. Table des symboles --- }
  WBytes(SymBuf, SymBufLen);

  { --- 10. Table des chaines --- }
  V32 := CoffStrtabLen + 4; { taille totale incluant le DWORD de taille }
  WD(V32);
  If CoffStrtabLen > 0 Then
    WBytes(CoffStrtab, CoffStrtabLen);

  Close(ObjF);
  If Opts.Verbose Then
    WriteLn('OBJ ecrit     : ', FileName,
            ' (code=', CodeLen, 'o rdata=', RdataLen,
            'o data=', DataLen, 'o bss=', BssLen, 'o)');
End;

Procedure EmitCoffObjFile;
Var
  ObjName : TString;
Begin
  If Not Opts.EmitObj Then Exit;
  If ErrorCount <> 0 Then
  Begin
    WarnMsg('OBJ non produit car le parsing contient des erreurs');
    Exit;
  End;
  ObjName := Opts.OutFile;
  CoffWriteObjFile(ObjName);
End;

{ ============================================================ }
{ LINKER PE .EXE (TODO 24) [IMPLEMENTE]                        }
{ ============================================================ }

Procedure EmitPeExeFile;
Var
  PeF          : File;
  ExeName      : TString;
  Rc, I, K     : Integer;
  TextRva      : LongInt;   { RVA depuis image base }
  RdataRva     : LongInt;
  DataRva      : LongInt;
  BssRva       : LongInt;
  TextVirtSz   : LongInt;
  RdataVirtSz  : LongInt;
  DataVirtSz   : LongInt;
  TextFileOff  : LongInt;
  RdataFileOff : LongInt;
  DataFileOff  : LongInt;
  SizeOfImage  : LongInt;
  EntryRva     : LongInt;   { RVA du point d entree (pour optional header) }
  IatGS, IatWC, IatEP : LongInt; { VAs absolues des entrees IAT cles }
  TmpD         : LongInt;
  TextVA       : LongInt;   { VA absolue = PE_IMG_BASE + TextRva }
  DataVA       : LongInt;
  RdataVA      : LongInt;
  BssVA        : LongInt;

  { ---- sous-procedures : emission dans le fichier PE ---- }

  Procedure PeB(V : Byte);
  Begin
    BlockWrite(PeF, V, 1);
  End;

  Procedure PeW(V : Word);
  Begin
    PeB(Lo(V));
    PeB(Hi(V));
  End;

  Procedure PeD(V : LongInt);
  Begin
    PeB(LongInt(V) And $FF);
    PeB((LongInt(V) Shr 8) And $FF);
    PeB((LongInt(V) Shr 16) And $FF);
    PeB((LongInt(V) Shr 24) And $FF);
  End;

  Procedure PeZeros(N : LongInt);
  Var Z : Byte; J : LongInt;
  Begin
    Z := 0;
    For J := 1 To N Do BlockWrite(PeF, Z, 1);
  End;

  Procedure PeRaw(Var Buf; Len : LongInt);
  Begin
    If Len > 0 Then BlockWrite(PeF, Buf, Len);
  End;

  Procedure PeSection8(Const Name : TString);
  Var J : Integer;
  Begin
    For J := 1 To 8 Do
      If J <= Length(Name) Then PeB(Ord(Name[J]))
      Else PeB(0);
  End;

  Procedure PePad(Cur, Target : LongInt);
  Begin
    If Target > Cur Then PeZeros(Target - Cur);
  End;

  { ---- sous-procedures : remplissage de PeImpBuf ---- }

  Procedure ImpB(V : Byte);
  Begin
    If PeImpLen < MAX_IMP_BUF Then
    Begin
      PeImpBuf[PeImpLen] := V;
      Inc(PeImpLen);
    End;
  End;

  Procedure ImpD(V : LongInt);
  Begin
    ImpB(LongInt(V) And $FF);
    ImpB((LongInt(V) Shr 8) And $FF);
    ImpB((LongInt(V) Shr 16) And $FF);
    ImpB((LongInt(V) Shr 24) And $FF);
  End;

  Procedure ImpStr(Const S : TString);
  Var J : Integer;
  Begin
    For J := 1 To Length(S) Do ImpB(Ord(S[J]));
    ImpB(0);
  End;

  Procedure ImpPatchD(Off : LongInt; V : LongInt);
  Begin
    If Off + 3 < MAX_IMP_BUF Then
    Begin
      PeImpBuf[Off]   := LongInt(V) And $FF;
      PeImpBuf[Off+1] := (LongInt(V) Shr 8) And $FF;
      PeImpBuf[Off+2] := (LongInt(V) Shr 16) And $FF;
      PeImpBuf[Off+3] := (LongInt(V) Shr 24) And $FF;
    End;
  End;

  { ---- sous-procedures : remplissage de PeStartBuf ---- }

  Procedure StB(V : Byte);
  Begin
    If PeStartLen < MAX_START_BUF Then
    Begin
      PeStartBuf[PeStartLen] := V;
      Inc(PeStartLen);
    End;
  End;

  Procedure StD(V : LongInt);
  Begin
    StB(LongInt(V) And $FF);
    StB((LongInt(V) Shr 8) And $FF);
    StB((LongInt(V) Shr 16) And $FF);
    StB((LongInt(V) Shr 24) And $FF);
  End;

  Procedure StPatchD(Off : LongInt; V : LongInt);
  Begin
    If Off + 3 < MAX_START_BUF Then
    Begin
      PeStartBuf[Off]   := LongInt(V) And $FF;
      PeStartBuf[Off+1] := (LongInt(V) Shr 8) And $FF;
      PeStartBuf[Off+2] := (LongInt(V) Shr 16) And $FF;
      PeStartBuf[Off+3] := (LongInt(V) Shr 24) And $FF;
    End;
  End;

  { CALL DWORD PTR [AbsAddr32] = FF 15 addr32 }
  Procedure StCallIat(AbsAddr : LongInt);
  Begin
    StB($FF); StB($15); StD(AbsAddr);
  End;

  { JMP DWORD PTR [AbsAddr32] = FF 25 addr32 }
  Procedure StJmpIat(AbsAddr : LongInt);
  Begin
    StB($FF); StB($25); StD(AbsAddr);
  End;

  { ---- Calcul de l import table ---- }

  Procedure BuildImportTable;
  Var
    N          : Integer;
    DirOff, IatOff, IltOff, HnOff : LongInt;
    HnEntryOff : Array[0..MAX_IMPORT-1] Of LongInt;
    DllNameOff : LongInt;
    IatBaseRva : LongInt;   { RVA de IAT[0] dans l image }
    IltBaseRva : LongInt;
    HnBaseRva  : LongInt;
    DllNameRva : LongInt;
    DataImpRva : LongInt;   { RVA de PeImpBuf[0] = DataRva + DataLen }
    HnRva      : LongInt;
    I, J       : Integer;
  Begin
    PeImpLen := 0;
    N := ImportCount;
    If N = 0 Then Exit;

    { Structure : [Dir 40B][IAT (N+1)*4][ILT (N+1)*4][HN...][DLL name] }
    DirOff := 0;
    IatOff := 40;
    IltOff := IatOff + (N + 1) * 4;
    HnOff  := IltOff + (N + 1) * 4;

    { Reserv les octets fixes : Dir + IAT + ILT (pre-remplis a 0) }
    For J := 0 To HnOff - 1 Do ImpB(0);

    { Hint/Name table }
    For I := 0 To N - 1 Do
    Begin
      HnEntryOff[I] := PeImpLen;
      ImpB(0); ImpB(0);          { Hint = 0 }
      ImpStr(ImportTab[I].Name); { nom + NUL }
      If (PeImpLen And 1) <> 0 Then ImpB(0); { alignement WORD }
    End;

    { DLL name }
    DllNameOff := PeImpLen;
    ImpStr('kernel32.dll');

    { Calcul des RVAs }
    DataImpRva := DataRva + DataLen;  { RVA de PeImpBuf[0] dans l image }
    IatBaseRva := DataImpRva + IatOff;
    IltBaseRva := DataImpRva + IltOff;
    HnBaseRva  := DataImpRva + HnOff;
    DllNameRva := DataImpRva + DllNameOff;

    { Stocker les VAs absolues pour le code }
    For I := 0 To N - 1 Do
      PeImpIatVA[I] := PE_IMG_BASE + IatBaseRva + LongInt(I) * 4;

    { Remplir IAT et ILT avec les RVAs des entrees HN }
    For I := 0 To N - 1 Do
    Begin
      HnRva := DataImpRva + HnEntryOff[I];
      ImpPatchD(IatOff + LongInt(I) * 4, HnRva);
      ImpPatchD(IltOff + LongInt(I) * 4, HnRva);
    End;
    { Terminateurs null deja a 0 }

    { Remplir Import Directory (1 entree + null) }
    ImpPatchD(DirOff +  0, IltBaseRva);  { OriginalFirstThunk }
    ImpPatchD(DirOff +  4, 0);           { TimeDateStamp }
    ImpPatchD(DirOff +  8, 0);           { ForwarderChain }
    ImpPatchD(DirOff + 12, DllNameRva);  { Name }
    ImpPatchD(DirOff + 16, IatBaseRva);  { FirstThunk }
    { [20..39] : null terminator, deja a 0 }
  End;

  { ---- Bloc de demarrage prepend a .text ---- }

  Procedure BuildStartupBlock;
  Var
    N         : Integer;
    I         : Integer;
    PlStart   : LongInt;
    PaStart   : LongInt;
    EntStart  : LongInt;
    MainOff   : LongInt;
    MainVA    : LongInt;
    CallOff   : LongInt;
  Begin
    PeStartLen := 0;
    N := ImportCount;

    { -- Thunks : JMP DWORD PTR [IAT_k] -- }
    For I := 0 To N - 1 Do
    Begin
      PeThunkVA[I] := TextVA + PeStartLen;
      StJmpIat(PeImpIatVA[I]);  { FF 25 addr32 = 6 octets }
    End;

    { Localiser les IAT entries necessaires au runtime }
    IatGS := 0; IatWC := 0; IatEP := 0;
    For I := 0 To N - 1 Do
    Begin
      If ImportTab[I].Name = 'GetStdHandle'  Then IatGS := PeImpIatVA[I];
      If ImportTab[I].Name = 'WriteFile'     Then IatWC := PeImpIatVA[I];
      If ImportTab[I].Name = 'ExitProcess'   Then IatEP := PeImpIatVA[I];
    End;

    { -- _RSRT_println(ptr:DWORD, len:DWORD) -- }
    { Pile au moment de l appel : [EBP+8]=ptr [EBP+12]=len }
    PlStart := PeStartLen;
    PePrintlnVA := TextVA + PlStart;
    StB($55);             { PUSH EBP }
    StB($8B); StB($EC);   { MOV EBP, ESP }
    StB($83); StB($EC); StB($04); { SUB ESP, 4 }
    StB($68); StD(LongInt(-11));  { PUSH -11 (STD_OUTPUT_HANDLE) }
    StCallIat(IatGS);             { CALL [GetStdHandle] }
    StB($6A); StB($00);           { PUSH 0 (lpOverlapped) }
    StB($8D); StB($4D); StB($FC); { LEA ECX,[EBP-4] }
    StB($51);                     { PUSH ECX (lpNumberOfCharsWritten) }
    StB($FF); StB($75); StB($0C); { PUSH DWORD PTR [EBP+12] (len) }
    StB($FF); StB($75); StB($08); { PUSH DWORD PTR [EBP+8]  (ptr) }
    StB($50);                     { PUSH EAX (hFile) }
    StCallIat(IatWC);             { CALL [WriteFile] }
    StB($8B); StB($E5);           { MOV ESP, EBP }
    StB($5D);                     { POP EBP }
    StB($C3);                     { RET }

    { -- _RSRT_panic(ptr:DWORD, len:DWORD) -- }
    PaStart := PeStartLen;
    PePanicVA := TextVA + PaStart;
    StB($55);             { PUSH EBP }
    StB($8B); StB($EC);   { MOV EBP, ESP }
    StB($83); StB($EC); StB($04); { SUB ESP, 4 }
    StB($68); StD(LongInt(-12));  { PUSH -12 (STD_ERROR_HANDLE) }
    StCallIat(IatGS);             { CALL [GetStdHandle] }
    StB($6A); StB($00);           { PUSH 0 }
    StB($8D); StB($4D); StB($FC); { LEA ECX,[EBP-4] }
    StB($51);                     { PUSH ECX }
    StB($FF); StB($75); StB($0C); { PUSH [EBP+12] }
    StB($FF); StB($75); StB($08); { PUSH [EBP+8]  }
    StB($50);                     { PUSH EAX }
    StCallIat(IatWC);             { CALL [WriteFile] }
    StB($6A); StB($01);           { PUSH 1 (exit code) }
    StCallIat(IatEP);             { CALL [ExitProcess] }
    StB($8B); StB($E5);           { MOV ESP, EBP }
    StB($5D);                     { POP EBP }
    StB($C3);                     { RET (unreachable) }

    { -- Point d entree _start -- }
    EntStart := PeStartLen;
    PeEntryVA := TextVA + EntStart;
    EntryRva  := TextRva + EntStart;
    { CALL _RSF_main (REL32) }
    StB($E8);
    CallOff := PeStartLen;
    StD(0);   { placeholder : patch apres }
    { PUSH 0 (code de sortie normal) }
    StB($6A); StB($00);
    { CALL [ExitProcess] }
    StCallIat(IatEP);
    { RET (inaccessible) }
    StB($C3);

    { Patch du CALL _RSF_main }
    MainOff := XFindLabel(RS_FN_PFX + 'main');
    If MainOff < 0 Then MainOff := 0;  { defensif }
    { MainVA = VA du premier octet de _RSF_main dans .text }
    { .text = [PeStartBuf (PeStartLen octets)][CodeBuf (CodeLen octets)] }
    { _RSF_main est a CodeBuf[MainOff], donc VA = TextVA + PeStartLen + MainOff }
    MainVA := TextVA + PeStartLen + MainOff;
    { REL32 = cible - (site + 4) ; site = CALL opcode + 1 = CallOff dans StartBuf }
    { VA du site = TextVA + CallOff }
    TmpD := MainVA - (TextVA + CallOff + 4);
    StPatchD(CallOff, TmpD);
  End;

  { ---- Patching CodeBuf pour PE ---- }

  Procedure PatchCodeBuf;
  Var
    I, J    : Integer;
    SiteOff : LongInt;   { offset dans CodeBuf }
    SiteVA  : LongInt;   { VA absolue du champ 4 octets a patcher }
    Target  : LongInt;   { VA cible ou valeur DIR32 }
    Rel32   : LongInt;
    SymName : TString;
  Begin
    For J := 0 To CoffTextRelCnt - 1 Do
    Begin
      SiteOff := CoffTextRelVA[J];
      { VA du champ = base .text + decalage startup + offset dans CodeBuf }
      SiteVA  := TextVA + PeStartLen + SiteOff;
      SymName := CoffTextRelSym[J];
      Target  := 0;

      If CoffTextRelTy[J] = COFF_RELOC_REL32 Then
      Begin
        { Appel externe ou runtime : chercher le thunk ou le stub }
        For I := 0 To ImportCount - 1 Do
          If ImportTab[I].MangledName = SymName Then
          Begin
            Target := PeThunkVA[I];
            Break;
          End;
        If (Target = 0) And (SymName = RS_RT_PFX + 'println') Then
          Target := PePrintlnVA;
        If (Target = 0) And (SymName = RS_RT_PFX + 'panic') Then
          Target := PePanicVA;
        If Target = 0 Then Continue;
        { REL32 = cible - (fin du champ) }
        Rel32 := Target - (SiteVA + 4);
        CodeBuf[SiteOff]   := LongInt(Rel32) And $FF;
        CodeBuf[SiteOff+1] := (LongInt(Rel32) Shr 8) And $FF;
        CodeBuf[SiteOff+2] := (LongInt(Rel32) Shr 16) And $FF;
        CodeBuf[SiteOff+3] := (LongInt(Rel32) Shr 24) And $FF;
      End
      Else { COFF_RELOC_DIR32 }
      Begin
        { Chaine constante : _RSK_N }
        For I := 0 To StringCount - 1 Do
          If StringTab[I].LabelName = SymName Then
          Begin
            Target := PE_IMG_BASE + RdataRva + StringRdataOff[I];
            Break;
          End;
        { Variable statique : _RSV_xxx }
        If Target = 0 Then
          For I := 0 To StaticCount - 1 Do
            If StaticTab[I].MangledName = SymName Then
            Begin
              If StaticTab[I].HasInit Then
                Target := PE_IMG_BASE + DataRva + StaticDataOff[I]
              Else
                Target := PE_IMG_BASE + BssRva + StaticDataOff[I];
              Break;
            End;
        If Target = 0 Then Continue;
        CodeBuf[SiteOff]   := LongInt(Target) And $FF;
        CodeBuf[SiteOff+1] := (LongInt(Target) Shr 8) And $FF;
        CodeBuf[SiteOff+2] := (LongInt(Target) Shr 16) And $FF;
        CodeBuf[SiteOff+3] := (LongInt(Target) Shr 24) And $FF;
      End;
    End;
  End;

Begin { EmitPeExeFile }
  If Not Opts.EmitExe Then Exit;
  If ErrorCount <> 0 Then
  Begin
    WarnMsg('EXE non produit car le parsing contient des erreurs');
    Exit;
  End;
  ExeName := Opts.OutFile;

  { 1. Garantir les imports runtime }
  EnsureRuntimeImports;

  { 2. Construire les sections de donnees }
  BuildRdataSection;
  BuildDataSection;
  XResolvePatches;   { resoudre les sauts internes dans CodeBuf }

  { 3. Layout des sections : RVAs et VAs }
  TextRva  := PE_SEC_ALIGN;
  { Estimation preliminaire de TextVirtSz pour calculer RdataRva }
  { StartLen approx = N*6 + ~100 octets de stubs + ~20 pour entry }
  TextVirtSz  := LongInt(ImportCount) * 6 + 128 + CodeLen;
  RdataRva    := TextRva + AlignUp(TextVirtSz, PE_SEC_ALIGN);
  RdataVirtSz := RdataLen;
  DataRva     := RdataRva + AlignUp(RdataVirtSz, PE_SEC_ALIGN);

  { 4. Construire l import table (necessite DataRva) }
  BuildImportTable;
  DataVirtSz := DataLen + PeImpLen;
  BssRva     := DataRva + AlignUp(DataVirtSz, PE_SEC_ALIGN);

  { 5. Construire le bloc de demarrage (necessite TextRva et les IATVAs) }
  TextVA   := PE_IMG_BASE + TextRva;
  RdataVA  := PE_IMG_BASE + RdataRva;
  DataVA   := PE_IMG_BASE + DataRva;
  BssVA    := PE_IMG_BASE + BssRva;
  EntryRva := 0;
  BuildStartupBlock;

  { 6. Recalculer TextVirtSz avec la vraie taille du startup }
  TextVirtSz := PeStartLen + CodeLen;
  RdataRva   := TextRva + AlignUp(TextVirtSz, PE_SEC_ALIGN);
  DataRva    := RdataRva + AlignUp(RdataVirtSz, PE_SEC_ALIGN);
  DataVirtSz := DataLen + PeImpLen;
  BssRva     := DataRva + AlignUp(DataVirtSz, PE_SEC_ALIGN);
  RdataVA    := PE_IMG_BASE + RdataRva;
  DataVA     := PE_IMG_BASE + DataRva;
  BssVA      := PE_IMG_BASE + BssRva;

  { Recalculer les VAs IAT et les VAs thunks avec les vrais RVAs }
  { (DataRva peut avoir change si TextVirtSz etait sous-estime) }
  PeImpLen := 0;
  BuildImportTable;    { reconstruit avec les bons RVAs }
  DataVirtSz := DataLen + PeImpLen;
  BssRva     := DataRva + AlignUp(DataVirtSz, PE_SEC_ALIGN);
  BssVA      := PE_IMG_BASE + BssRva;

  PeStartLen := 0;
  EntryRva := 0;
  BuildStartupBlock;   { reconstruit avec les bons PeImpIatVA }

  TextVirtSz := PeStartLen + CodeLen;

  { 7. Patcher CodeBuf pour les relocations PE }
  PatchCodeBuf;

  { 8. Calculs finaux fichier }
  TextFileOff  := $200;
  RdataFileOff := TextFileOff  + AlignUp(TextVirtSz, PE_FILE_ALIGN);
  DataFileOff  := RdataFileOff + AlignUp(RdataVirtSz, PE_FILE_ALIGN);
  { SizeOfImage doit couvrir toutes les sections y compris .bss }
  SizeOfImage := AlignUp(BssRva + AlignUp(BssLen, PE_SEC_ALIGN), PE_SEC_ALIGN);
  If SizeOfImage <= BssRva Then
    SizeOfImage := BssRva + PE_SEC_ALIGN;  { minimum : 1 page pour .bss }

  { 9. Ouvrir et ecrire le fichier PE }
  Assign(PeF, ExeName);
  {$I-} Rewrite(PeF, 1); {$I+}
  Rc := IOResult;
  If Rc <> 0 Then
  Begin
    FatalError('impossible de creer le fichier EXE: ' + ExeName);
    Exit;
  End;

  { ---- En-tete DOS (64 octets) ---- }
  PeW($5A4D);          { e_magic: MZ }
  PeW($0090);          { e_cblp }
  PeW($0003);          { e_cp }
  PeW($0000);          { e_crlc }
  PeW($0004);          { e_cparhdr }
  PeW($0000);          { e_minalloc }
  PeW($FFFF);          { e_maxalloc }
  PeW($0000);          { e_ss }
  PeW($00B8);          { e_sp }
  PeW($0000);          { e_csum }
  PeW($0000);          { e_ip }
  PeW($0000);          { e_cs }
  PeW($0040);          { e_lfarlc }
  PeW($0000);          { e_ovno }
  PeZeros(32);         { e_res[4] + e_oemid + e_oeminfo + e_res2[10] }
  PeD($00000040);      { e_lfanew : signature PE a l offset 0x40 }

  { ---- Signature PE (4 octets) ---- }
  PeD(PE_PE_SIG);

  { ---- COFF File Header (20 octets) ---- }
  PeW(PE_MACHINE_I386);   { Machine }
  PeW(4);                  { NumberOfSections: .text .rdata .data .bss }
  PeD(0);                  { TimeDateStamp }
  PeD(0);                  { PointerToSymbolTable }
  PeD(0);                  { NumberOfSymbols }
  PeW(PE_OPT_SIZE);        { SizeOfOptionalHeader = 224 }
  PeW($0103);              { Characteristics: RELOCS_STRIPPED | EXECUTABLE | 32BIT }

  { ---- Optional Header PE32 (224 octets) ---- }
  { Standard fields }
  PeW(PE_MAGIC_32);
  PeB(1); PeB(0);          { MajorLinkerVersion / MinorLinkerVersion }
  PeD(AlignUp(TextVirtSz, PE_FILE_ALIGN));   { SizeOfCode }
  PeD(AlignUp(RdataVirtSz, PE_FILE_ALIGN)
    + AlignUp(DataVirtSz,  PE_FILE_ALIGN));  { SizeOfInitializedData }
  PeD(AlignUp(BssLen, PE_FILE_ALIGN));       { SizeOfUninitializedData }
  PeD(EntryRva);           { AddressOfEntryPoint (RVA) }
  PeD(TextRva);            { BaseOfCode (RVA) }
  PeD(RdataRva);           { BaseOfData (RVA) }
  { Windows-specific fields }
  PeD(PE_IMG_BASE);        { ImageBase }
  PeD(PE_SEC_ALIGN);       { SectionAlignment }
  PeD(PE_FILE_ALIGN);      { FileAlignment }
  PeW(4); PeW(0);          { MajorOSVersion / MinorOSVersion }
  PeW(0); PeW(0);          { MajorImageVersion / MinorImageVersion }
  PeW(4); PeW(0);          { MajorSubsystemVersion / MinorSubsystemVersion }
  PeD(0);                  { Win32VersionValue }
  PeD(SizeOfImage);        { SizeOfImage }
  PeD($200);               { SizeOfHeaders }
  PeD(0);                  { CheckSum }
  PeW(PE_SUBSYS_CUI);      { Subsystem: console }
  PeW(0);                  { DllCharacteristics }
  PeD($00100000);          { SizeOfStackReserve = 1 MB }
  PeD($00001000);          { SizeOfStackCommit  = 4 KB }
  PeD($00100000);          { SizeOfHeapReserve  = 1 MB }
  PeD($00001000);          { SizeOfHeapCommit   = 4 KB }
  PeD(0);                  { LoaderFlags }
  PeD(16);                 { NumberOfRvaAndSizes }
  { Data Directories (16 x 8 = 128 octets) }
  PeD(0); PeD(0);          { [0] Export }
  PeD(DataRva + DataLen); PeD(40); { [1] Import : RVA de PeImpBuf[0], taille dir }
  PeD(0); PeD(0);          { [2] Resource }
  PeD(0); PeD(0);          { [3] Exception }
  PeD(0); PeD(0);          { [4] Security }
  PeD(0); PeD(0);          { [5] BaseReloc }
  PeD(0); PeD(0);          { [6] Debug }
  PeD(0); PeD(0);          { [7] Architecture }
  PeD(0); PeD(0);          { [8] GlobalPtr }
  PeD(0); PeD(0);          { [9] TLS }
  PeD(0); PeD(0);          { [10] LoadConfig }
  PeD(0); PeD(0);          { [11] BoundImport }
  PeD(DataRva + DataLen + 40); { [12] IAT RVA (apres dir) }
  PeD(LongInt(ImportCount + 1) * 4); { IAT size }
  PeD(0); PeD(0);          { [13] DelayImport }
  PeD(0); PeD(0);          { [14] COMdesc }
  PeD(0); PeD(0);          { [15] Reserved }

  { ---- Section Headers (4 x 40 = 160 octets) ---- }

  { .text }
  PeSection8('.text');
  PeD(TextVirtSz);
  PeD(TextRva);
  PeD(AlignUp(TextVirtSz, PE_FILE_ALIGN));
  PeD(TextFileOff);
  PeD(0); PeD(0); PeW(0); PeW(0);
  PeD(PE_SCN_TEXT);

  { .rdata }
  PeSection8('.rdata');
  PeD(RdataVirtSz);
  PeD(RdataRva);
  PeD(AlignUp(RdataVirtSz, PE_FILE_ALIGN));
  PeD(RdataFileOff);
  PeD(0); PeD(0); PeW(0); PeW(0);
  PeD(PE_SCN_RDATA);

  { .data (statics utilisateur + import table) }
  PeSection8('.data');
  PeD(DataVirtSz);
  PeD(DataRva);
  PeD(AlignUp(DataVirtSz, PE_FILE_ALIGN));
  PeD(DataFileOff);
  PeD(0); PeD(0); PeW(0); PeW(0);
  PeD(PE_SCN_DATA);

  { .bss : VirtualSize = max(BssLen, 4) pour eviter section vide rejetee par le loader }
  PeSection8('.bss');
  If BssLen > 0 Then PeD(BssLen) Else PeD(4);
  PeD(BssRva);
  PeD(0);   { SizeOfRawData = 0 (non-initialise) }
  PeD(0);   { PointerToRawData = 0 }
  PeD(0); PeD(0); PeW(0); PeW(0);
  PeD(PE_SCN_BSS);

  { Rembourrage pour atteindre TextFileOff = 0x200 }
  { Octets emis jusqu ici : 64+4+20+224+4*40 = 472 }
  PePad(472, $200);

  { ---- Donnees des sections ---- }

  { .text = bloc startup + code utilisateur }
  PeRaw(PeStartBuf, PeStartLen);
  PeRaw(CodeBuf, CodeLen);
  PePad(TextVirtSz, AlignUp(TextVirtSz, PE_FILE_ALIGN));

  { .rdata }
  PeRaw(RdataBuf, RdataLen);
  PePad(RdataVirtSz, AlignUp(RdataVirtSz, PE_FILE_ALIGN));

  { .data = statics + import table }
  If DataLen > 0 Then PeRaw(DataBuf, DataLen);
  If PeImpLen > 0 Then PeRaw(PeImpBuf, PeImpLen);
  PePad(DataVirtSz, AlignUp(DataVirtSz, PE_FILE_ALIGN));

  { .bss : pas de donnees de fichier (VirtualSize only) }

  Close(PeF);

  If Opts.Verbose Then
    WriteLn('EXE ecrit     : ', ExeName,
      '  .text=', TextVirtSz, 'o  .rdata=', RdataVirtSz,
      'o  .data=', DataVirtSz, 'o  .bss=', BssLen, 'o');
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
  SymIdx, ProcIdx, ArgCount : Integer;
  Val : LongInt;
  R, Arg : TExprRec;
  Args : TExprArgArray;
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
      ArgCount := 0;
      If Not (TokIs(TK_PUNCT, ')')) Then
      Begin
        While CurToken.Kind <> TK_EOF Do
        Begin
          Arg := ParseExpr;
          If ArgCount < MAX_PARAM Then
          Begin
            Args[ArgCount] := Arg;
            Inc(ArgCount);
          End
          Else
            ReportErrorAt(CurToken.Line, CurToken.Col, Name,
              'trop d''arguments dans appel');
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
      If ProcIdx >= 0 Then
      Begin
        If ArgCount <> ProcTab[ProcIdx].ParamCount Then
          ReportErrorAt(CurToken.Line, CurToken.Col, Name,
            'nombre d''arguments incorrect');
        EmitCallProc(ProcIdx, Args, ArgCount);
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
    PrepareAssignmentExpr(TypeIdx, InitExpr, L, C, Name);
    If SymIdx >= 0 Then
    Begin
      SymTab[SymIdx].TypeIdx := TypeIdx;
      If TypeIsPointer(TypeIdx) Then
        Inc(PtrLocalCount);
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
    RetExpr := ParseExpr
  Else
    RetExpr := MakeExpr(EK_LITERAL, TY_IDX_UNIT, True, 0, False);
  EmitReturnExpr(RetExpr);
  ExpectToken(TK_PUNCT, ';', '; apres return');
End;

Procedure ParseUnsafeStmt;
Var
  OldDepth : Integer;
Begin
  ExpectToken(TK_KEYWORD, 'unsafe', 'unsafe');
  If TokIs(TK_PUNCT, '{') Then
  Begin
    OldDepth := UnsafeDepth;
    Inc(UnsafeDepth);
    Inc(UnsafeBlockCount);
    EmitAsm('  ; debut bloc unsafe depth=' + IntToStr_(UnsafeDepth));
    ParseBlock;
    EmitAsm('  ; fin bloc unsafe depth=' + IntToStr_(UnsafeDepth));
    UnsafeDepth := OldDepth;
  End
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

Procedure ParseForStmt;
Var
  L, C, SymIdx, TypeIdx : Integer;
  IterName : TString;
  StartExpr, EndExpr, IterExpr, OneExpr, IncExpr, CondExpr : TExprRec;
  TestLabel, IncLabel, EndLabel : TString;
  IsC : Boolean;
  V : LongInt;
Begin
  L := CurToken.Line;
  C := CurToken.Col;
  ExpectToken(TK_KEYWORD, 'for', 'for');

  If CurToken.Kind <> TK_IDENT Then
  Begin
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'nom de variable attendu apres for');
    SkipUntilSemicolon;
    Exit;
  End;
  IterName := CurToken.Val;
  ParserNext;

  If Not ExpectToken(TK_KEYWORD, 'in', 'in apres variable for') Then
  Begin
    SkipUntilSemicolon;
    Exit;
  End;

  StartExpr := ParseExpr;
  If Not ExpectToken(TK_OP, '..', '.. dans range for') Then
  Begin
    SkipUntilSemicolon;
    Exit;
  End;
  EndExpr := ParseExpr;

  TypeIdx := StartExpr.TypeIdx;
  If TypeIdx = TY_UNKNOWN Then
    TypeIdx := EndExpr.TypeIdx;
  If TypeIdx = TY_UNKNOWN Then
    TypeIdx := TY_IDX_I32;

  TestLabel := NewLabelName;
  IncLabel := NewLabelName;
  EndLabel := NewLabelName;
  Inc(LoopCount);

  EnterScope;
  SymIdx := AddSym(IterName, SC_LOCAL, TypeIdx, False, True,
    -LongInt((LocalCount + 1) * WORD_SIZE), IterName, L, C);
  If SymIdx >= 0 Then
  Begin
    Inc(LocalCount);
    EmitStoreSym(SymIdx, StartExpr, True);
  End;

  EmitLabel(TestLabel);
  IterExpr := MakeExpr(EK_VAR, TypeIdx, False, 0, True);
  IsC := False;
  V := 0;
  If IterExpr.IsConst And EndExpr.IsConst Then
    IsC := EvalBinaryConst('<', IterExpr.IntValue, EndExpr.IntValue, V);
  CondExpr := MakeExpr(EK_BINARY, TY_IDX_BOOL, IsC, V, False);
  EmitBinaryArith('<', IterExpr, EndExpr, CondExpr.TypeIdx);
  EmitConditionFalseJump(CondExpr, EndLabel);

  If TokIs(TK_PUNCT, '{') Then
  Begin
    PushLoopLabels(IncLabel, EndLabel, L, C);
    ParseBlock;
    PopLoopLabels;
    EmitLabel(IncLabel);
    If SymIdx >= 0 Then
    Begin
      IterExpr := MakeExpr(EK_VAR, TypeIdx, False, 0, True);
      OneExpr := MakeExpr(EK_LITERAL, TypeIdx, True, 1, False);
      IsC := False;
      V := 0;
      IncExpr := MakeExpr(EK_BINARY, TypeIdx, IsC, V, False);
      EmitBinaryArith('+', IterExpr, OneExpr, IncExpr.TypeIdx);
      EmitStoreSym(SymIdx, IncExpr, False);
    End;
    EmitJump(TestLabel);
    EmitLabel(EndLabel);
  End
  Else
  Begin
    ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
      'bloc for attendu');
    SkipUntilSemicolon;
    EmitLabel(EndLabel);
  End;
  LeaveScope;
End;

Procedure ParseMatchStmt;
Var
  MatchExpr, LitExpr, CondExpr : TExprRec;
  EndLabel, NextLabel : TString;
  IsDefault, IsC, SawDefault : Boolean;
  V, ArmLine : LongInt;
Begin
  ExpectToken(TK_KEYWORD, 'match', 'match');
  MatchExpr := ParseExpr;
  If Not ExpectToken(TK_PUNCT, '{', '{ apres match') Then
  Begin
    SkipUntilSemicolon;
    Exit;
  End;

  Inc(MatchCount);
  EndLabel := NewLabelName;
  SawDefault := False;
  ArmLine := CurToken.Line;

  While (CurToken.Kind <> TK_EOF) And Not TokIs(TK_PUNCT, '}') Do
  Begin
    IsDefault := False;
    ArmLine := CurToken.Line;

    If (CurToken.Kind = TK_IDENT) And (CurToken.Val = '_') Then
    Begin
      IsDefault := True;
      SawDefault := True;
      ParserNext;
    End
    Else If CurToken.Kind = TK_INTEGER Then
    Begin
      LitExpr := MakeExpr(EK_LITERAL, MatchExpr.TypeIdx, True,
        CurToken.IntVal, False);
      ParserNext;
    End
    Else
    Begin
      ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
        'arm match attendue: entier ou _');
      SkipUntilSemicolon;
      Break;
    End;

    If Not ExpectToken(TK_OP, '=>', '=> apres arm match') Then
    Begin
      SkipUntilSemicolon;
      Break;
    End;

    If Not IsDefault Then
    Begin
      NextLabel := NewLabelName;
      IsC := False;
      V := 0;
      If MatchExpr.IsConst And LitExpr.IsConst Then
        IsC := EvalBinaryConst('==', MatchExpr.IntValue, LitExpr.IntValue, V);
      CondExpr := MakeExpr(EK_BINARY, TY_IDX_BOOL, IsC, V, False);
      EmitBinaryArith('==', MatchExpr, LitExpr, CondExpr.TypeIdx);
      EmitConditionFalseJump(CondExpr, NextLabel);
    End
    Else
      NextLabel := '';

    If TokIs(TK_PUNCT, '{') Then
      ParseBlock
    Else
    Begin
      ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
        'bloc attendu pour arm match');
      SkipUntilSemicolon;
    End;

    EmitJump(EndLabel);
    If NextLabel <> '' Then
      EmitLabel(NextLabel);

    If TokIs(TK_PUNCT, ',') Then
      ParserNext;
  End;

  If Not SawDefault Then
    WarnMsg('match sans arm _ par defaut a la ligne ' + IntToStr_(ArmLine));
  ExpectToken(TK_PUNCT, '}', '} apres match');
  EmitLabel(EndLabel);
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

Procedure ParseRuntimeMacroStmt;
Var
  MacroName, TextVal : TString;
  L, C, StrIdx : Integer;
  CondExpr : TExprRec;
Begin
  L := CurToken.Line;
  C := CurToken.Col;
  MacroName := CurToken.Val;
  ParserNext;

  If Not ExpectToken(TK_PUNCT, '(', '( apres macro') Then
  Begin
    SkipUntilSemicolon;
    Exit;
  End;

  If MacroName = 'println!' Then
  Begin
    If CurToken.Kind <> TK_STRING Then
    Begin
      ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
        'println! supporte seulement une chaine litterale');
      SkipUntilSemicolon;
      Exit;
    End;
    TextVal := CurToken.Val + #13#10;
    ParserNext;
    If TokIs(TK_PUNCT, ',') Then
      ReportErrorAt(CurToken.Line, CurToken.Col, ',',
        'arguments de format println! non supportes');
    ExpectToken(TK_PUNCT, ')', ') apres println!');
    ExpectToken(TK_PUNCT, ';', '; apres println!');
    StrIdx := AddStringRec(TextVal);
    EmitPrintlnString(StrIdx);
    Exit;
  End;

  If MacroName = 'panic!' Then
  Begin
    If CurToken.Kind <> TK_STRING Then
    Begin
      ReportErrorAt(CurToken.Line, CurToken.Col, CurToken.Val,
        'panic! supporte seulement une chaine litterale');
      SkipUntilSemicolon;
      Exit;
    End;
    TextVal := CurToken.Val + #13#10;
    ParserNext;
    If TokIs(TK_PUNCT, ',') Then
      ReportErrorAt(CurToken.Line, CurToken.Col, ',',
        'arguments de format panic! non supportes');
    ExpectToken(TK_PUNCT, ')', ') apres panic!');
    ExpectToken(TK_PUNCT, ';', '; apres panic!');
    StrIdx := AddStringRec(TextVal);
    EmitPanicString(StrIdx);
    Exit;
  End;

  If MacroName = 'debug_assert!' Then
  Begin
    CondExpr := ParseExpr;
    If TokIs(TK_PUNCT, ',') Then
      ReportErrorAt(CurToken.Line, CurToken.Col, ',',
        'message debug_assert! personnalise non supporte');
    ExpectToken(TK_PUNCT, ')', ') apres debug_assert!');
    ExpectToken(TK_PUNCT, ';', '; apres debug_assert!');
    EmitDebugAssert(CondExpr);
    Exit;
  End;

  ReportErrorAt(L, C, MacroName, 'macro runtime non supportee');
  SkipUntilSemicolon;
End;

Procedure ParseExprStmt;
Var
  AssignName : TString;
  AssignLine, AssignCol, SymIdx, ProcIdx, ArgCount : Integer;
  HadSemi, HadBlock : Boolean;
  Rhs, Arg : TExprRec;
  Args : TExprArgArray;
Begin
  If CurToken.Kind = TK_MACRO Then
  Begin
    ParseRuntimeMacroStmt;
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
    If SymIdx >= 0 Then
      PrepareAssignmentExpr(SymTab[SymIdx].TypeIdx, Rhs, AssignLine,
        AssignCol, AssignName);
    If CanAssignToSym(SymIdx) Then
      EmitStoreSym(SymIdx, Rhs, False);
    ExpectToken(TK_PUNCT, ';', '; apres affectation');
    Exit;
  End;

  If (AssignName <> '') And TokIs(TK_PUNCT, '(') Then
  Begin
    ParserNext;
    ArgCount := 0;
    If Not TokIs(TK_PUNCT, ')') Then
    Begin
      While CurToken.Kind <> TK_EOF Do
      Begin
        Arg := ParseExpr;
        If ArgCount < MAX_PARAM Then
        Begin
          Args[ArgCount] := Arg;
          Inc(ArgCount);
        End
        Else
          ReportErrorAt(CurToken.Line, CurToken.Col, AssignName,
            'trop d''arguments dans appel');
        If TokIs(TK_PUNCT, ',') Then
        Begin
          ParserNext;
          Continue;
        End;
        Break;
      End;
    End;
    ExpectToken(TK_PUNCT, ')', ') apres appel');
    ProcIdx := FindProc(AssignName);
    If ProcIdx < 0 Then
      ReportErrorAt(AssignLine, AssignCol, AssignName,
        'appel de fonction inconnue')
    Else
    Begin
      If ArgCount <> ProcTab[ProcIdx].ParamCount Then
        ReportErrorAt(AssignLine, AssignCol, AssignName,
          'nombre d''arguments incorrect');
      EmitCallProc(ProcIdx, Args, ArgCount);
    End;
    ExpectToken(TK_PUNCT, ';', '; apres appel');
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
  Else If TokIs(TK_KEYWORD, 'for') Then
    ParseForStmt
  Else If TokIs(TK_KEYWORD, 'match') Then
    ParseMatchStmt
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
  Begin
    If CurrentExternModule = '' Then
      CurrentExternModule := DefaultImportModule(Name, CurrentExternAbi);
    AddImportRec(Name, ProcTab[ProcIdx].MangledName,
      DefaultImportModule(Name, CurrentExternAbi), CurrentExternAbi,
      ProcIdx, FnSym);
    ExpectToken(TK_PUNCT, ';', '; apres declaration extern')
  End
  Else
  Begin
    CurrentProcIdx := ProcIdx;
    CurrentReturnLabel := NewLabelName;
    EmitFunctionPrologue(ProcIdx, CurrentReturnLabel);
    ParseBlock;
    EmitFunctionEpilogue(ProcIdx, CurrentReturnLabel);
    CurrentProcIdx := -1;
    CurrentReturnLabel := '';
  End;
  LeaveScope;
End;

Procedure ParseExternBlock;
Var
  OldAbi, OldModule : TString;
Begin
  ExpectToken(TK_KEYWORD, 'extern', 'extern');
  OldAbi := CurrentExternAbi;
  OldModule := CurrentExternModule;
  If CurToken.Kind = TK_STRING Then
  Begin
    CurrentExternAbi := CurToken.Val;
    CurrentExternModule := DefaultImportModule('', CurrentExternAbi);
    ParserNext
  End
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
  CurrentExternAbi := OldAbi;
  CurrentExternModule := OldModule;
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
  MatchCount := 0;
  CallCount := 0;
  ExternCallCount := 0;
  UnsafeDepth := 0;
  UnsafeBlockCount := 0;
  PtrLocalCount := 0;
  RuntimeMacroCount := 0;
  PrintlnCount := 0;
  DebugAssertCount := 0;
  PanicCount := 0;
  SourceInit;
  InitBackend;
  InitTypeTable;
  InitSymbolTable;
  InitProcTable;
  InitConstStaticTables;
  InitImportRelocTables;
  ParseArgs;
  ShowBanner;
  DumpTypeTable;
  SourceOpen(Opts.SrcFile);
  ParseProgram;
  SourceClose;
  DumpSymbolTable;
  DumpProcTable;
  DumpConstStaticTables;
  DumpImportRelocTables;
  DumpAsmTrace;
  EmitAsmFile;
  EmitCoffObjFile;
  EmitPeExeFile;
  ShowStats;
END.
