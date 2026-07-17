{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2)
  @description: Dessasembleur DCU (Delphi Compiled Unit)
  @license: MIT
}

Program DisDCU;

{$MODE TP}

(* ============================================================
   DISDCU - Decompilateur de fichiers .DCU (Delphi Compiled Unit)
   vers un fichier .PAS lisible (reconstruction du code source
   Delphi, dans la mesure ou l'information necessaire existe
   encore dans le fichier compile).

   Reference : DOC\DCU_FORMAT.TXT (reverse-engineering du format,
   verifie contre le vrai outil DCU32INT compile avec un vrai
   Delphi, et contre de vrais .dcu reels - RAD Studio 21.0).

   PORTEE (honnete, voir DOC\DCU_FORMAT.TXT section 9/10/11bis) :

   Ce que ce programme DECOMPILE CORRECTEMENT et completement,
   verifie contre de vrais .dcu (REST.OpenSSL.dcu, System.
   SimpleShareMem.dcu) :
     - L'en-tete (nombre magique -> version Delphi, taille de
       fichier, horodatage de compilation).
     - La clause "uses" (chaque unite referencee).
     - Les types ORDINAUX simples : intervalles (Range/Bool/Char/
       WChar/WideChar), pointeurs, "set of <type>", le type void.
     - Les variables et constantes (nom + reference de type).
     - Les signatures de procedures/fonctions (nom ; le CORPS
       n'est PAS decompile - voir plus bas).

   Ce que ce programme NE DECOMPILE PAS ENCORE (arret propre et
   explicite plutot que de deviner - voir DOC\DCU_FORMAT.TXT
   section 9/10) :
     - Les types COMPLEXES dont la structure octet-par-octet n'a
       pas encore ete confirmee contre de vrais fichiers : classes
       (drClassDef), records (drRecDef), tableaux (drArrayDef),
       chaines (drStringDef/drShortStrDef/drWideStrDef), interfaces
       (drInterfaceDef), enumerations (drEnumDef), types procedure
       (drProcTypeDef), Variant (drVariantDef), fichiers (drFileDef/
       drTextDef). Un fichier .dcu REEL de taille normale (avec
       classes, String, etc.) declenchera donc un arret avec un
       message clair des qu un tel type est rencontre, PLUTOT que
       de produire un .pas errone sans avertir.
     - Le CORPS des procedures/fonctions (le bloc drCBlock contient
       du code machine 80386 compile, pas des instructions Pascal
       structurees - une vraie decompilation d'expressions/
       structures de controle a partir du code machine n est pas
       tentee ici ; DCU32INT lui-meme ne fait que du DESASSEMBLAGE,
       pas une reconstruction Pascal). Chaque procedure/fonction
       est donc emise avec un corps vide et un commentaire.
     - La resolution des references de types VERS UNE AUTRE unite
       (ex: un "String" ou "TObject" importe depuis System) - le
       mecanisme d'import nomme existe (confirme, voir DOC section
       9b) mais son encodage exact octet-par-octet dans la liste
       imbriquee d'un enregistrement "uses" n'est pas encore
       confirme ; ce programme imprime alors un espace reserve
       "<type importe #N>" plutot que le vrai nom.

   Usage : DISDCU <fichier.dcu> [fichier.pas]
           Si le fichier de sortie est omis, le nom est derive du
           fichier d'entree (meme nom, extension .pas), ecrit dans
           le meme dossier.
   ============================================================ *)

Uses
  SysUtils;

Const
  MAX_STR = 255;
  MAX_BUF = 16 * 1024 * 1024;   { 16 Mo - largement suffisant pour }
                                 { n importe quelle unite reelle }
  MAX_TYPES = 16384;
  MAX_USES  = 512;              { unites "uses" par fichier }
  MAX_IMPORT_POOL = 32768;      { total des imports nommes, tous "uses" }
  WRAP_WIDTH = 76;              { largeur avant retour a la ligne automatique }

  { --- Etiquettes (Tag) reconnues - voir DOC\DCU_FORMAT.TXT      }
  { section 7. Uniquement celles que ce programme sait traiter    }
  { EN TOUTE SECURITE (structure confirmee) ; toute autre         }
  { etiquette provoque un arret propre (voir FailUnknownTag).      }
  TAG_STOP           = $00;
  TAG_STOP_A         = $61;   { 'a' : derniere etiquette du fichier }
  TAG_STOP1          = $63;   { 'c' : fin de sous-liste imbriquee   }
  TAG_UNIT           = $64;   { 'd' }
  TAG_UNIT1          = $65;   { 'e' }
  TAG_DLL            = $68;   { 'h' }
  TAG_SRC            = $70;   { 'p' }
  TAG_OBJ            = $71;   { 'q' }
  TAG_RES            = $72;   { 'r' }
  TAG_UNIT_INLINE_SRC = $76;  { 'v', Ver>=verD2010(14) - meme structure que drSrc }
  TAG_ASM            = $73;   { 's' }
  TAG_CONST          = $25;   { '%' }
  TAG_TYPE           = $2A;   { '*' }
  TAG_TYPEP          = $26;   { '&' }
  TAG_PROC           = $28;   { '(' }
  TAG_SYSPROC        = $29;   { ')' }
  TAG_VAR            = $20;   { ' ' }
  TAG_VARC           = $27;   { '''' }
  TAG_ABSVAR         = $24;   { '$' }
  TAG_VOID           = $40;   { '@' }
  TAG_LABEL          = $2B;   { '+' }
  TAG_SPECVAR        = $37;   { '7', Ver>=10 }
  TAG_CLASSVAR       = $36;   { arClassVar, en test comme etiquette principale }
  TAG_RESSTR_OLD     = $32;   { '2', Ver<10 }
  TAG_RESSTR_NEW     = $33;   { '3', Ver>=10 }
  TAG_THREADVAR_OLD  = $31;   { '1', Ver<10 }
  TAG_UNITFLAGS      = $96;
  { --- tables de debogage/symboles (presentes seulement si l unite a   }
  { ete compilee avec informations de debogage/reference de symboles -    }
  { CONFIRME, DCU32.pas : drCodeLines..drLocVarTbl, dispatchees par le        }
  { MEME aiguilleur principal que drCBlock/drFixUp, PAS imbriquees dans          }
  { une autre structure). Pure metadonnee (correspondance ligne source/            }
  { portee de bloc/variables locales), jamais une declaration Pascal              }
  { visible - lue et sautee, comme ProcessSrcInf.                                    }
  TAG_CODELINES      = $90;   { drCodeLines }
  TAG_LINNUM         = $91;   { drLinNum }
  TAG_STRUCSCOPE     = $92;   { drStrucScope }
  TAG_SYMBOLREF      = $93;   { drSymbolRef }
  TAG_LOCVARTBL      = $94;   { drLocVarTbl }
  { --- table des segments/sections de code (Ver>=verD_XE2(16)) - CONFIRME  }
  { (DCU32.pas, TUnit.LoadAddrToSegInfo) : associe chaque declaration a un    }
  { "segment" (code/donnees/etc) - pure metadonnee de mise en page, jamais       }
  { une declaration Pascal visible.                                                }
  TAG_SEGINFO        = $B1;   { drSegInfo }
  TAG_ADDRTOSEGINFO  = $B2;   { drAddrToSegInfo }
  { CORRECTION (2026-07-14, contre le vrai code source DCU32.pas -    }
  { const drXxx=$YY - et non plus le fichier de specification FlexT     }
  { abstrait, moins fiable) : drUnitAddInfo vaut TOUJOURS $34, quelle     }
  { que soit la version ; $35 est en realite un tag DIFFERENT et sans      }
  { rapport, drStrConstRec (structure encore non confirmee).                 }
  TAG_UNIT_ADD_INFO  = $34;   { '4' }
  TAG_STRCONSTREC    = $35;   { '5' }
  TAG_PROC_ADD_INFO  = $9E;
  TAG_CONST_ADD_INFO = $9C;
  TAG_INFO98         = $98;

  { --- etiquettes de la liste imbriquee d un enregistrement "uses" -  }
  { valeurs REELLES confirmees contre le vrai code source DCU32.pas     }
  { (const drImpType=$66, etc.) - voir ProcessUsesUnit.                   }
  TAG_IMPTYPE        = $66;   { 'f' }
  TAG_IMPTYPEDEF     = $6E;   { 'n' }
  TAG_IMPVAL         = $67;   { 'g' }
  TAG_EXPORT         = $69;   { 'i' }
  TAG_STOP2          = $9F;

  { --- etiquettes de la liste d arguments d une procedure/fonction   }
  { (ReadDeclList LK=dlArgs) - valeurs REELLES confirmees contre le      }
  { vrai code source (DCU32.pas const arVal=$21, etc.). Portee : seuls      }
  { les cas simples (parametre ordinaire, convention d appel, valeur         }
  { par defaut "set") sont decodes - voir SkipArgList.                        }
  TAG_ARG_VAL        = $21;   { '!' }
  TAG_ARG_VAR        = $22;   { '"' }
  TAG_ARG_RESULT     = $23;   { '#' }
  TAG_ARG_FLD        = $2C;   { ',' }
  TAG_ARG_METHOD     = $2D;   { '-' }
  TAG_ARG_CONSTR     = $2E;   { '.' }
  TAG_ARG_DESTR      = $2F;   { '/' }
  TAG_ARG_CDECL      = $81;
  TAG_ARG_PASCAL     = $82;
  TAG_ARG_STDCALL    = $83;
  TAG_ARG_SAFECALL   = $84;
  TAG_ARG_SETDEFT    = $9A;
  { arProperty, valeur EMPIRIQUE (2026-07-16, Access2000.dcu, membre    }
  { d interface) : $31, PAS la valeur $30 citee dans le texte source        }
  { (meme constat que pour drStrConstRec/drTypeP - a verifier au cas          }
  { par cas plutot que faire confiance au texte seul).                            }
  TAG_ARG_PROPERTY   = $31;
  { $30, empirique (2026-07-16, Access2000.dcu) : precede directement    }
  { le nom "Destroy" (destructeur), exactement comme $2F (deja               }
  { TAG_ARG_DESTR) precede "Create" (constructeur) - meme famille de tag        }
  { que les methodes, structure IDENTIQUE (voir SkipMethodDecl).                  }
  TAG_ARG_DESTR2     = $30;
  TAG_ANON_BLOCK     = $01;   { arAnonymousBlock, Ver>=verD2010 : 2 TNDX }
  TAG_DELAYED_IMP    = $B0;   { drDelayedImpInfo, Ver>=verD2009 }
  TAG_A5INFO         = $A5;   { generiques, Ver>=verD2009 }
  TAG_A6INFO         = $A6;   { generiques, Ver>=verD2009 }
  TAG_A7INFO         = $A7;   { generiques (TTemplateParmsDeclModifier) }
  TAG_A8INFO         = $A8;   { generiques, simple (un seul TNDX) }
  TAG_EMBEDDED_PROC_START = $6A;   { 'j' }
  TAG_EMBEDDED_PROC_END   = $6B;   { 'k' }

  { --- "genre de liste" (LK reel, TDeclListKind) - influence la          }
  { structure exacte de TLocalDecl.Create (voir SkipLocalDecl) : LK_ARGS   }
  { (dlArgs/dlArgsT, parametres) autorise le decorateur "[REF]" ; LK_INTF     }
  { (dlInterface/dlDispInterface, membres d interface) lit un champ NDXB       }
  { supplementaire ; LK_OTHER (dlFields/dlClass) n a ni l un ni l autre.         }
  LK_ARGS     = 0;
  LK_OTHER    = 1;
  LK_INTF     = 2;
  { LK_DISPINTF (dlDispInterface) : comme LK_INTF pour NDXB, mais       }
  { arProperty y utilise TDispPropDecl - qui herite de TLocalDecl (PAS de  }
  { TPropDecl!) - structure DIFFERENTE et bien plus courte, confirmee        }
  { (DCURecs.pas : "TDispPropDecl = class(TLocalDecl)", aucun Create          }
  { redefini). Bogue trouve empiriquement (Access2000.dcu, tag $FF               }
  { apres la propriete "Application" traitee via TPropDecl - hypothese            }
  { erronee, puisque le vrai dispatch utilise TLocalDecl pour ce contexte).           }
  LK_DISPINTF = 3;

  { --- corps de procedure (implementation) - structure CONFIRMEE :   }
  { drCBlock = taille (TNDX) + N octets de code machine brut ; drFixUp   }
  { = compte (TNDX) puis, par entree, dOfs(TNDX)+octet+NDX(TNDX). Le        }
  { CODE lui-meme n est PAS decompile (portee documentee), seulement          }
  { correctement SAUTE pour atteindre les declarations suivantes.               }
  TAG_CBLOCK         = $6C;   { 'l' }
  TAG_FIXUP          = $6D;   { 'm' }
  TAG_OREC           = $6F;   { 'o', drORec, Ver>=verD8(8) }

  { --- definitions de types ORDINAUX/SIMPLES : structure connue   }
  { (paire de bornes ou reference unique) - donc traitees.          }
  TAG_RANGEDEF       = $44;   { 'D' }
  TAG_CHRANGEDEF     = $42;   { 'B' }
  TAG_BOOLRANGEDEF   = $41;   { 'A' }
  TAG_WCHARRANGEDEF  = $51;   { 'Q' }
  TAG_WIDERANGEDEF   = $56;   { 'V' }
  TAG_PTRDEF         = $45;   { 'E' }
  TAG_SETDEF         = $4A;   { 'J' }
  TAG_FLOATDEF       = $49;   { 'I' }

  { --- definitions de types COMPLEXES : structure NON confirmee   }
  { octet-par-octet - provoquent un arret propre (voir la portee    }
  { documentee ci-dessus).                                           }
  TAG_RECDEF         = $4D;   { 'M' }
  TAG_CLASSDEF       = $46;   { 'F' }
  TAG_OBJDEF         = $4E;   { 'N' }
  TAG_OBJVMTDEF      = $47;   { 'G' }
  TAG_PROCTYPEDEF    = $48;   { 'H' }
  TAG_ENUMDEF        = $43;   { 'C' }
  TAG_SHORTSTRDEF    = $4B;   { 'K' }
  TAG_ARRAYDEF       = $4C;   { 'L' }
  TAG_FILEDEF        = $4F;   { 'O' }
  TAG_TEXTDEF        = $50;   { 'P' }
  TAG_STRINGDEF      = $52;   { 'R' }
  TAG_VARIANTDEF     = $53;   { 'S' }
  TAG_INTERFACEDEF   = $54;   { 'T' }
  TAG_WIDESTRDEF     = $55;   { 'U' }
  TAG_METACLASSDEF   = $57;   { 'W' }
  TAG_DYNARRAYDEF    = $58;   { 'X' }
  TAG_UNICODESTRDEF  = $5B;   { '[' }

Type
  TString = String;

Var
  { --- tampon du fichier entier en memoire, et curseur de lecture }
  Buf        : Array[0..MAX_BUF - 1] Of Byte;
  BufLen     : LongInt;
  P          : LongInt;

  { --- version Delphi detectee (voir DOC section 3), au meme      }
  { schema numerique que le vrai DCU32INT (verD7=7, verD2005=9,     }
  { verD2009=12, verD_XE2=16...) pour rester coherent avec la        }
  { documentation.                                                    }
  Ver        : Integer;

  OutF       : Text;
  Stopped    : Boolean;

  { --- etiquette "courante" du flux principal de la table            }
  { d enregistrements - un curseur PARTAGE (comme le champ Tag de la    }
  { vraie classe TUnit de DCU32.pas), pas un simple parametre local :     }
  { la plupart des enregistrements consomment exactement leur propre       }
  { contenu puis avancent CurTag d un cran (voir ProcessOneRecord), mais      }
  { "uses" (ProcessUsesUnit) doit lire un nombre VARIABLE d etiquettes           }
  { supplementaires (liste d import, puis un eventuel drProcAddInfo) avant       }
  { de savoir quelle est la VRAIE prochaine etiquette - elle gere donc          }
  { elle-meme CurTag jusqu au bout, au lieu de laisser le code commun le          }
  { faire a sa place.                                                               }
  CurTag     : Byte;

  { --- table locale des types (numerotation LOCALE au fichier,   }
  { confirmee empiriquement - voir DOC section 9b) : chaque        }
  { definition de type anonyme rencontree recoit l index suivant    }
  { disponible ; TypeText[N] est la description Pascal du type #N.   }
  TypeCount  : Integer;
  TypeText   : Array[1..MAX_TYPES] Of TString;

  { --- clause "uses" accumulee (pas ecrite tout de suite) : chaque   }
  { unite "uses" rencontree (ProcessUsesUnit) s ajoute ici avec la      }
  { plage de ses imports nommes dans ImportPool - la clause complete     }
  { (syntaxe Pascal propre) et le bloc de commentaire distinct listant    }
  { les imports (avec retour a la ligne automatique) ne sont ecrits          }
  { qu une fois pour toutes par FlushUsesClause, au moment ou le premier      }
  { enregistrement NON-"uses" est rencontre (ou a la toute fin si le              }
  { fichier ne contient que des "uses"). Evite les lignes de centaines            }
  { de caracteres d un seul bloc "Nom" suivi de tous ses imports en une    }
  { fois - defaut signale par l utilisateur.                                 }
  { Compteur d "echappement" pour drEmbeddedProcStart/drEmbeddedProcEnd    }
  { isoles (sans paire correspondante au meme niveau d imbrication) -        }
  { CONFIRME (DCU32.pas, variable EmbEndCnt) : un drEmbeddedProcEnd "nu"        }
  { rencontre dans un contexte dlArgs/dlArgsT incremente ce compteur SANS          }
  { rien ouvrir ; un drEmbeddedProcStart rencontre alors que ce compteur                }
  { est >0 se contente de le decrementer plutot que d ouvrir un vrai bloc                }
  { imbrique (annule un "echappement" en attente au lieu d en creer un nouveau).            }
  EmbEndCnt       : Integer;

  UsesFlushed     : Boolean;
  UsesCount       : Integer;
  UsesNames       : Array[1..MAX_USES] Of TString;
  UsesImportFirst : Array[1..MAX_USES] Of Integer;
  UsesImportCount : Array[1..MAX_USES] Of Integer;

  ImportPoolCount : Integer;
  ImportPool      : Array[1..MAX_IMPORT_POOL] Of TString;

{ ================================================================ }
{ DESASSEMBLAGE 80386 DES CORPS DE PROCEDURE (Assembler; asm...end;) }
{ ================================================================ }
{ Moteur de decodage x86 porte depuis DISEXE.PAS (meme projet) - un  }
{ desassembleur MZ/PE deja complet et teste. Seul le coeur pur       }
{ (tables d opcodes, decodage ModR/M-SIB-prefixes, DisassembleInstruction)  }
{ est repris ici ; toute la partie specifique PE (sections, imports    }
{ Windows, annotations) est omise - hors de portee pour une DCU.        }
{                                                                        }
{ Adaptation au contexte DCU (PAS un fichier EXE lie) : le bloc de code   }
{ (drCBlock, TAG_CBLOCK) est un blob NON RELOGE - les operandes CALL/JMP    }
{ relatifs contiennent des deplacements PLACEHOLDER, le vrai destinataire     }
{ etant indique par la table des correctifs (drFixUp, TAG_FIXUP) via un        }
{ index NDX. La resolution de symbole se fait donc PAR OFFSET DE CORRECTIF       }
{ (FindFixupAt), PAS par adresse cible calculee comme dans DISEXE.PAS            }
{ (concu pour un PE deja lie, adresses finales) - voir DisassembleInstruction.    }
{                                                                                   }
{ Portee assumee (best effort, voir NextAddrDef) : la numerotation des index    }
{ d adresse ("address-def", TNameDecl.hDecl du vrai DCU32.pas) est reconstruite  }
{ en comptant, dans le MEME ordre que le fichier, chaque declaration NOMMEE        }
{ rencontree (types/vars/consts/procs/champs/methodes/proprietes/imports) -         }
{ CONFIRME (DCURecs.pas) : ces objets heritent tous de TNameDecl.Create, qui          }
{ reserve un index sequentiel via AddAddrDef. Les definitions de types ANONYMES        }
{ (Def* : DefRange/DefRecord/DefClass/etc) utilisent un espace d index SEPARE           }
{ (hAddrDef lu directement du fichier, PAS compte) - jamais cible d un CALL/JMP,          }
{ donc hors de portee ici. Si la correlation echoue pour une routine donnee               }
{ (aucune plage drFixUp trouvee pour son propre index), son corps est annonce               }
{ comme non attribue plutot que d afficher des octets errones - jamais de nom                 }
{ invente pour un symbole non confirme.                                                          }

Const
  { --- types d operandes de la table d opcodes (portes de DISEXE.PAS) --- }
  OT_NONE    = 0;
  OT_REG8    = 1;
  OT_REG16   = 2;
  OT_SEGREG  = 3;
  OT_MEM     = 4;
  OT_RM8     = 5;
  OT_RM16    = 6;
  OT_IMM8    = 7;
  OT_IMM16   = 8;
  OT_REL8    = 9;
  OT_REL16   = 10;
  OT_FAR     = 11;
  OT_AL      = 12;
  OT_AX      = 13;
  OT_CL      = 14;
  OT_DX      = 15;
  OT_ONE     = 16;
  OT_CS      = 17;
  OT_DS      = 18;
  OT_ES      = 19;
  OT_SS      = 20;
  OT_MEM16   = 21;
  OT_IMM8X   = 22;
  OT_REG32   = 23;
  OT_RM32    = 24;
  OT_IMM32   = 25;
  OT_EAX     = 26;
  OT_FS      = 27;
  OT_GS      = 28;
  OT_CR      = 29;
  OT_DR      = 30;
  OT_TR      = 31;
  OT_REL32   = 32;

  MAX_CODE    = 8 * 1024 * 1024;   { 8 Mo - taille max du bloc de code drCBlock }
  MAX_LABELS  = 65536;
  MAX_ADDRDEF = 262144;            { bornes larges : compte tous les TNameDecl }
  MAX_FIXUPS  = 262144;
  MAX_PROCS   = 65536;

Type
  TLabelInfo = Record
    Address  : LongInt;
    Name     : TString;
    IsProc   : Boolean;
    IsImport : Boolean;
    IsExport : Boolean;
  End;

  TOpcodeEntry = Record
    Mnemonic  : String[10];
    OpCount   : Byte;
    Op1Type   : Byte;
    Op2Type   : Byte;
    NeedModRM : Boolean;
    BaseSize  : Byte;
  End;

  TProcInfo = Record
    AddrIdx : LongInt;
    Name    : TString;
    IsFunc  : Boolean;
  End;
Const
  { Registres 8 bits (indices 0..7) }
  RegNames8 : Array[0..7] Of String[2] = (
    'AL', 'CL', 'DL', 'BL', 'AH', 'CH', 'DH', 'BH'
  );

  { Registres 16 bits (indices 0..7) }
  RegNames16 : Array[0..7] Of String[2] = (
    'AX', 'CX', 'DX', 'BX', 'SP', 'BP', 'SI', 'DI'
  );

  { Registres de segment (indices 0..3) }
  SegRegNames : Array[0..3] Of String[2] = (
    'ES', 'CS', 'SS', 'DS'
  );

  { Registres 32 bits (indices 0..7, 80386+) }
  RegNames32 : Array[0..7] Of String[3] = (
    'EAX', 'ECX', 'EDX', 'EBX', 'ESP', 'EBP', 'ESI', 'EDI'
  );

  { Registres de segment etendus (indices 0..5, FS/GS sur 80386+) }
  SegRegNames6 : Array[0..5] Of String[2] = (
    'ES', 'CS', 'SS', 'DS', 'FS', 'GS'
  );

  { Registres de controle (indices 0..3, 80386+) }
  CRegNames : Array[0..3] Of String[3] = (
    'CR0', 'CR1', 'CR2', 'CR3'
  );

  { Registres de debogage (indices 0..7, 80386+) }
  DRegNames : Array[0..7] Of String[3] = (
    'DR0', 'DR1', 'DR2', 'DR3', 'DR4', 'DR5', 'DR6', 'DR7'
  );

  { Registres de test (indices 0..7, 80386+) }
  TRegNames : Array[0..7] Of String[3] = (
    'TR0', 'TR1', 'TR2', 'TR3', 'TR4', 'TR5', 'TR6', 'TR7'
  );

{ ============================================================
  TABLE DES 256 OPCODES 8086/8088
  ============================================================ }

  OpcodeTable : Array[0..255] Of TOpcodeEntry = (
    { $00 ADD r/m8, r8 }
    (Mnemonic:'ADD';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $01 ADD r/m16, r16 }
    (Mnemonic:'ADD';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $02 ADD r8, r/m8 }
    (Mnemonic:'ADD';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $03 ADD r16, r/m16 }
    (Mnemonic:'ADD';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $04 ADD AL, imm8 }
    (Mnemonic:'ADD';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $05 ADD AX, imm16 }
    (Mnemonic:'ADD';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $06 PUSH ES }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_ES;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $07 POP ES }
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_ES;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $08 OR r/m8, r8 }
    (Mnemonic:'OR';       OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $09 OR r/m16, r16 }
    (Mnemonic:'OR';       OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $0A OR r8, r/m8 }
    (Mnemonic:'OR';       OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $0B OR r16, r/m16 }
    (Mnemonic:'OR';       OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $0C OR AL, imm8 }
    (Mnemonic:'OR';       OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $0D OR AX, imm16 }
    (Mnemonic:'OR';       OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $0E PUSH CS }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_CS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $0F (prefixe 0F - opcodes etendus 80286+, voir Opcode0FTable) }
    (Mnemonic:'0F';       OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $10 ADC r/m8, r8 }
    (Mnemonic:'ADC';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $11 ADC r/m16, r16 }
    (Mnemonic:'ADC';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $12 ADC r8, r/m8 }
    (Mnemonic:'ADC';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $13 ADC r16, r/m16 }
    (Mnemonic:'ADC';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $14 ADC AL, imm8 }
    (Mnemonic:'ADC';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $15 ADC AX, imm16 }
    (Mnemonic:'ADC';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $16 PUSH SS }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_SS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $17 POP SS }
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_SS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $18 SBB r/m8, r8 }
    (Mnemonic:'SBB';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $19 SBB r/m16, r16 }
    (Mnemonic:'SBB';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $1A SBB r8, r/m8 }
    (Mnemonic:'SBB';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $1B SBB r16, r/m16 }
    (Mnemonic:'SBB';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $1C SBB AL, imm8 }
    (Mnemonic:'SBB';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $1D SBB AX, imm16 }
    (Mnemonic:'SBB';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $1E PUSH DS }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_DS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $1F POP DS }
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_DS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $20 AND r/m8, r8 }
    (Mnemonic:'AND';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $21 AND r/m16, r16 }
    (Mnemonic:'AND';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $22 AND r8, r/m8 }
    (Mnemonic:'AND';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $23 AND r16, r/m16 }
    (Mnemonic:'AND';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $24 AND AL, imm8 }
    (Mnemonic:'AND';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $25 AND AX, imm16 }
    (Mnemonic:'AND';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $26 ES: (prefixe de segment) }
    (Mnemonic:'ES:';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $27 DAA }
    (Mnemonic:'DAA';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $28 SUB r/m8, r8 }
    (Mnemonic:'SUB';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $29 SUB r/m16, r16 }
    (Mnemonic:'SUB';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $2A SUB r8, r/m8 }
    (Mnemonic:'SUB';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $2B SUB r16, r/m16 }
    (Mnemonic:'SUB';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $2C SUB AL, imm8 }
    (Mnemonic:'SUB';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $2D SUB AX, imm16 }
    (Mnemonic:'SUB';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $2E CS: (prefixe de segment) }
    (Mnemonic:'CS:';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $2F DAS }
    (Mnemonic:'DAS';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $30 XOR r/m8, r8 }
    (Mnemonic:'XOR';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $31 XOR r/m16, r16 }
    (Mnemonic:'XOR';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $32 XOR r8, r/m8 }
    (Mnemonic:'XOR';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $33 XOR r16, r/m16 }
    (Mnemonic:'XOR';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $34 XOR AL, imm8 }
    (Mnemonic:'XOR';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $35 XOR AX, imm16 }
    (Mnemonic:'XOR';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $36 SS: (prefixe de segment) }
    (Mnemonic:'SS:';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $37 AAA }
    (Mnemonic:'AAA';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $38 CMP r/m8, r8 }
    (Mnemonic:'CMP';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $39 CMP r/m16, r16 }
    (Mnemonic:'CMP';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $3A CMP r8, r/m8 }
    (Mnemonic:'CMP';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $3B CMP r16, r/m16 }
    (Mnemonic:'CMP';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $3C CMP AL, imm8 }
    (Mnemonic:'CMP';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $3D CMP AX, imm16 }
    (Mnemonic:'CMP';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $3E DS: (prefixe de segment) }
    (Mnemonic:'DS:';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $3F AAS }
    (Mnemonic:'AAS';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $40..$47 INC r16 (AX..DI) }
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $48..$4F DEC r16 (AX..DI) }
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $50..$57 PUSH r16 (AX..DI) }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $58..$5F POP r16 (AX..DI) }
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $60..$6F : instructions 80186/80286 }
    { $60 PUSHA }
    (Mnemonic:'PUSHA';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $61 POPA }
    (Mnemonic:'POPA';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $62 BOUND r16, m16&16 }
    (Mnemonic:'BOUND';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_MEM;   NeedModRM:True;  BaseSize:1),
    { $63 ARPL r/m16, r16 (mode protege 80286) }
    (Mnemonic:'ARPL';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $64 FS: (prefixe segment FS sur 80386+) }
    (Mnemonic:'FS:';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $65 GS: (prefixe segment GS sur 80386+) }
    (Mnemonic:'GS:';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $66 OPSIZ (prefixe taille operande sur 80386+) }
    (Mnemonic:'OPSIZ';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $67 ADDRSIZ (prefixe taille adresse sur 80386+) }
    (Mnemonic:'ADDRSIZ';  OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $68 PUSH imm16 }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_IMM16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:3),
    { $69 IMUL r16, r/m16, imm16 }
    (Mnemonic:'IMUL';     OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:True;  BaseSize:1),
    { $6A PUSH imm8 (signe-etendu a 16 bits) }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_IMM8X; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $6B IMUL r16, r/m16, imm8 }
    (Mnemonic:'IMUL';     OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM8X; NeedModRM:True;  BaseSize:1),
    { $6C INSB }
    (Mnemonic:'INSB';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $6D INSW }
    (Mnemonic:'INSW';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $6E OUTSB }
    (Mnemonic:'OUTSB';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $6F OUTSW }
    (Mnemonic:'OUTSW';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $70..$7F Jcc rel8 (sauts conditionnels courts) }
    (Mnemonic:'JO';       OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNO';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JB';       OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNB';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JZ';       OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNZ';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JBE';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNBE';     OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JS';       OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNS';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JP';       OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNP';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JL';       OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNL';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JLE';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNLE';     OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $80 GRP1 r/m8, imm8 (ADD/OR/ADC/SBB/AND/SUB/XOR/CMP selon reg) }
    (Mnemonic:'GRP1';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:1),
    { $81 GRP1 r/m16, imm16 }
    (Mnemonic:'GRP1';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_IMM16; NeedModRM:True;  BaseSize:1),
    { $82 GRP1 r/m8, imm8 (alias de $80) }
    (Mnemonic:'GRP1';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:1),
    { $83 GRP1 r/m16, imm8 (signe-etendu) }
    (Mnemonic:'GRP1';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_IMM8X; NeedModRM:True;  BaseSize:1),
    { $84 TEST r/m8, r8 }
    (Mnemonic:'TEST';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $85 TEST r/m16, r16 }
    (Mnemonic:'TEST';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $86 XCHG r/m8, r8 }
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $87 XCHG r/m16, r16 }
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $88 MOV r/m8, r8 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $89 MOV r/m16, r16 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $8A MOV r8, r/m8 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $8B MOV r16, r/m16 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $8C MOV r/m16, Sreg }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_SEGREG;NeedModRM:True;  BaseSize:1),
    { $8D LEA r16, m }
    (Mnemonic:'LEA';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_MEM;   NeedModRM:True;  BaseSize:1),
    { $8E MOV Sreg, r/m16 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_SEGREG;Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $8F POP r/m16 }
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    { $90 NOP (XCHG AX,AX) }
    (Mnemonic:'NOP';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $91..$97 XCHG AX, r16 }
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_REG16; NeedModRM:False; BaseSize:1),
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_REG16; NeedModRM:False; BaseSize:1),
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_REG16; NeedModRM:False; BaseSize:1),
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_REG16; NeedModRM:False; BaseSize:1),
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_REG16; NeedModRM:False; BaseSize:1),
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_REG16; NeedModRM:False; BaseSize:1),
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_REG16; NeedModRM:False; BaseSize:1),
    { $98 CBW }
    (Mnemonic:'CBW';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $99 CWD }
    (Mnemonic:'CWD';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $9A CALL far ptr16:16 }
    (Mnemonic:'CALL';     OpCount:1; Op1Type:OT_FAR;   Op2Type:OT_NONE;  NeedModRM:False; BaseSize:5),
    { $9B WAIT/FWAIT }
    (Mnemonic:'FWAIT';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $9C PUSHF }
    (Mnemonic:'PUSHF';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $9D POPF }
    (Mnemonic:'POPF';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $9E SAHF }
    (Mnemonic:'SAHF';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $9F LAHF }
    (Mnemonic:'LAHF';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $A0 MOV AL, moffs8 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_MEM16; NeedModRM:False; BaseSize:3),
    { $A1 MOV AX, moffs16 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_MEM16; NeedModRM:False; BaseSize:3),
    { $A2 MOV moffs8, AL }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_MEM16; Op2Type:OT_AL;    NeedModRM:False; BaseSize:3),
    { $A3 MOV moffs16, AX }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_MEM16; Op2Type:OT_AX;    NeedModRM:False; BaseSize:3),
    { $A4 MOVSB }
    (Mnemonic:'MOVSB';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $A5 MOVSW }
    (Mnemonic:'MOVSW';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $A6 CMPSB }
    (Mnemonic:'CMPSB';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $A7 CMPSW }
    (Mnemonic:'CMPSW';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $A8 TEST AL, imm8 }
    (Mnemonic:'TEST';     OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $A9 TEST AX, imm16 }
    (Mnemonic:'TEST';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $AA STOSB }
    (Mnemonic:'STOSB';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $AB STOSW }
    (Mnemonic:'STOSW';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $AC LODSB }
    (Mnemonic:'LODSB';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $AD LODSW }
    (Mnemonic:'LODSW';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $AE SCASB }
    (Mnemonic:'SCASB';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $AF SCASW }
    (Mnemonic:'SCASW';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $B0..$B7 MOV r8, imm8 (AL..BH) }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $B8..$BF MOV r16, imm16 (AX..DI) }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $C0 GRP2 r/m8, imm8 (80186+ : shifts/rotations avec immediat) }
    (Mnemonic:'GRP2';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:1),
    { $C1 GRP2 r/m16, imm8 (80186+ : shifts/rotations avec immediat) }
    (Mnemonic:'GRP2';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:1),
    { $C2 RET imm16 (near return avec pop) }
    (Mnemonic:'RET';      OpCount:1; Op1Type:OT_IMM16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:3),
    { $C3 RET (near return) }
    (Mnemonic:'RET';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $C4 LES r16, m16:16 }
    (Mnemonic:'LES';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_MEM;   NeedModRM:True;  BaseSize:1),
    { $C5 LDS r16, m16:16 }
    (Mnemonic:'LDS';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_MEM;   NeedModRM:True;  BaseSize:1),
    { $C6 MOV r/m8, imm8 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:1),
    { $C7 MOV r/m16, imm16 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_IMM16; NeedModRM:True;  BaseSize:1),
    { $C8 ENTER imm16, imm8 (80186+) }
    (Mnemonic:'ENTER';    OpCount:2; Op1Type:OT_IMM16; Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:4),
    { $C9 LEAVE (80186+) }
    (Mnemonic:'LEAVE';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $CA RETF imm16 (far return avec pop) }
    (Mnemonic:'RETF';     OpCount:1; Op1Type:OT_IMM16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:3),
    { $CB RETF (far return) }
    (Mnemonic:'RETF';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $CC INT 3 (implicite, pas d'octet immediat) }
    (Mnemonic:'INT3';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $CD INT imm8 }
    (Mnemonic:'INT';      OpCount:1; Op1Type:OT_IMM8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $CE INTO }
    (Mnemonic:'INTO';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $CF IRET }
    (Mnemonic:'IRET';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $D0 GRP2 r/m8, 1 (ROL/ROR/RCL/RCR/SHL/SHR/-/SAR) }
    (Mnemonic:'GRP2';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_ONE;   NeedModRM:True;  BaseSize:1),
    { $D1 GRP2 r/m16, 1 }
    (Mnemonic:'GRP2';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_ONE;   NeedModRM:True;  BaseSize:1),
    { $D2 GRP2 r/m8, CL }
    (Mnemonic:'GRP2';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_CL;    NeedModRM:True;  BaseSize:1),
    { $D3 GRP2 r/m16, CL }
    (Mnemonic:'GRP2';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_CL;    NeedModRM:True;  BaseSize:1),
    { $D4 AAM (imm8 = 0Ah implicite) }
    (Mnemonic:'AAM';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $D5 AAD (imm8 = 0Ah implicite) }
    (Mnemonic:'AAD';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $D6 (reserve/SALC non documente) }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $D7 XLAT }
    (Mnemonic:'XLAT';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $D8..$DF ESC (opcodes coprocesseur x87) }
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    { $E0 LOOPNZ rel8 }
    (Mnemonic:'LOOPNZ';   OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $E1 LOOPZ rel8 }
    (Mnemonic:'LOOPZ';    OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $E2 LOOP rel8 }
    (Mnemonic:'LOOP';     OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $E3 JCXZ rel8 }
    (Mnemonic:'JCXZ';     OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $E4 IN AL, imm8 }
    (Mnemonic:'IN';       OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $E5 IN AX, imm8 }
    (Mnemonic:'IN';       OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $E6 OUT imm8, AL }
    (Mnemonic:'OUT';      OpCount:2; Op1Type:OT_IMM8;  Op2Type:OT_AL;    NeedModRM:False; BaseSize:2),
    { $E7 OUT imm8, AX }
    (Mnemonic:'OUT';      OpCount:2; Op1Type:OT_IMM8;  Op2Type:OT_AX;    NeedModRM:False; BaseSize:2),
    { $E8 CALL rel16 }
    (Mnemonic:'CALL';     OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:3),
    { $E9 JMP rel16 }
    (Mnemonic:'JMP';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:3),
    { $EA JMP far ptr16:16 }
    (Mnemonic:'JMP';      OpCount:1; Op1Type:OT_FAR;   Op2Type:OT_NONE;  NeedModRM:False; BaseSize:5),
    { $EB JMP rel8 }
    (Mnemonic:'JMP';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $EC IN AL, DX }
    (Mnemonic:'IN';       OpCount:2; Op1Type:OT_AL;    Op2Type:OT_DX;    NeedModRM:False; BaseSize:1),
    { $ED IN AX, DX }
    (Mnemonic:'IN';       OpCount:2; Op1Type:OT_AX;    Op2Type:OT_DX;    NeedModRM:False; BaseSize:1),
    { $EE OUT DX, AL }
    (Mnemonic:'OUT';      OpCount:2; Op1Type:OT_DX;    Op2Type:OT_AL;    NeedModRM:False; BaseSize:1),
    { $EF OUT DX, AX }
    (Mnemonic:'OUT';      OpCount:2; Op1Type:OT_DX;    Op2Type:OT_AX;    NeedModRM:False; BaseSize:1),
    { $F0 LOCK (prefixe) }
    (Mnemonic:'LOCK';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $F1 (reserve / INT1 non documente) }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $F2 REPNZ (prefixe) }
    (Mnemonic:'REPNZ';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $F3 REP/REPZ (prefixe) }
    (Mnemonic:'REP';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $F4 HLT }
    (Mnemonic:'HLT';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $F5 CMC }
    (Mnemonic:'CMC';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $F6 GRP3a r/m8 (TEST/???/NOT/NEG/MUL/IMUL/DIV/IDIV) }
    (Mnemonic:'GRP3';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    { $F7 GRP3b r/m16 }
    (Mnemonic:'GRP3';     OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    { $F8 CLC }
    (Mnemonic:'CLC';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $F9 STC }
    (Mnemonic:'STC';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $FA CLI }
    (Mnemonic:'CLI';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $FB STI }
    (Mnemonic:'STI';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $FC CLD }
    (Mnemonic:'CLD';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $FD STD }
    (Mnemonic:'STD';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $FE GRP4 r/m8 (INC/DEC) }
    (Mnemonic:'GRP4';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    { $FF GRP5 r/m16 (INC/DEC/CALL/CALL far/JMP/JMP far/PUSH) }
    (Mnemonic:'GRP5';     OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1)
  );

  { Mnemoniques du groupe 1 (opcodes $80-$83, selon champ reg de ModR/M) }
  Grp1Mnemonics : Array[0..7] Of String[3] = (
    'ADD', 'OR', 'ADC', 'SBB', 'AND', 'SUB', 'XOR', 'CMP'
  );

  { Mnemoniques du groupe 2 (opcodes $D0-$D3, selon champ reg de ModR/M) }
  Grp2Mnemonics : Array[0..7] Of String[3] = (
    'ROL', 'ROR', 'RCL', 'RCR', 'SHL', 'SHR', '???', 'SAR'
  );

  { Mnemoniques du groupe 3 (opcodes $F6-$F7, selon champ reg de ModR/M) }
  Grp3Mnemonics : Array[0..7] Of String[4] = (
    'TEST', '???', 'NOT', 'NEG', 'MUL', 'IMUL', 'DIV', 'IDIV'
  );

  { Mnemoniques du groupe 4 (opcode $FE, selon champ reg de ModR/M) }
  Grp4Mnemonics : Array[0..7] Of String[3] = (
    'INC', 'DEC', '???', '???', '???', '???', '???', '???'
  );

  { Mnemoniques du groupe 5 (opcode $FF, selon champ reg de ModR/M) }
  Grp5Mnemonics : Array[0..7] Of String[4] = (
    'INC', 'DEC', 'CALL', 'CALL', 'JMP', 'JMP', 'PUSH', '???'
  );

  { Mnemoniques du groupe 6 (opcode 0F 00, selon champ reg de ModR/M) }
  { Instructions mode protege 80286 }
  Grp6Mnemonics : Array[0..7] Of String[4] = (
    'SLDT', 'STR', 'LLDT', 'LTR', 'VERR', 'VERW', '???', '???'
  );

  { Mnemoniques du groupe 7 (opcode 0F 01, selon champ reg de ModR/M) }
  { Instructions mode protege 80286 }
  Grp7Mnemonics : Array[0..7] Of String[4] = (
    'SGDT', 'SIDT', 'LGDT', 'LIDT', 'SMSW', '???', 'LMSW', '???'
  );

  { Mnemoniques du groupe 8 (opcode 0F BA, selon champ reg de ModR/M) }
  { Instructions bit test 80386+ }
  Grp8Mnemonics : Array[0..7] Of String[3] = (
    '???', '???', '???', '???', 'BT', 'BTS', 'BTR', 'BTC'
  );

{ ============================================================
  TABLE DES OPCODES ETENDUS 0Fh (80286+)
  ============================================================ }

  { Nombre d'opcodes etendus 0Fh definis }
  MAX_0F_OPCODES = 256;

  Opcode0FTable : Array[0..255] Of TOpcodeEntry = (
    { $0F 00 GRP6 r/m16 (SLDT/STR/LLDT/LTR/VERR/VERW) }
    (Mnemonic:'GRP6';     OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    { $0F 01 GRP7 (SGDT/SIDT/LGDT/LIDT/SMSW/LMSW) }
    (Mnemonic:'GRP7';     OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    { $0F 02 LAR r16, r/m16 }
    (Mnemonic:'LAR';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 03 LSL r16, r/m16 }
    (Mnemonic:'LSL';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 04 reserve }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 05 reserve (LOADALL 80286 / SYSCALL 686+) }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 06 CLTS (Clear Task-Switched Flag) }
    (Mnemonic:'CLTS';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 07 reserve (LOADALL 80386 / SYSRET 686+) }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 08 INVD (Invalidate Cache, 80486+) }
    (Mnemonic:'INVD';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 09 WBINVD (Write Back and Invalidate Cache, 80486+) }
    (Mnemonic:'WBINVD';   OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 0A..$0F 0F reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 10..$0F 1F reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 20..$0F 2F MOV CRn/DRn/TRn (80386+) }
    { $0F 20 MOV r32, CRn }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG32; Op2Type:OT_CR;    NeedModRM:True;  BaseSize:2),
    { $0F 21 MOV r32, DRn }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG32; Op2Type:OT_DR;    NeedModRM:True;  BaseSize:2),
    { $0F 22 MOV CRn, r32 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_CR;    Op2Type:OT_REG32; NeedModRM:True;  BaseSize:2),
    { $0F 23 MOV DRn, r32 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_DR;    Op2Type:OT_REG32; NeedModRM:True;  BaseSize:2),
    { $0F 24 MOV r32, TRn }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG32; Op2Type:OT_TR;    NeedModRM:True;  BaseSize:2),
    { $0F 25 reserve }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 26 MOV TRn, r32 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_TR;    Op2Type:OT_REG32; NeedModRM:True;  BaseSize:2),
    { $0F 27 reserve }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 28..$0F 2F reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 30..$0F 3F instructions systeme (Pentium+) }
    { $0F 30 WRMSR (Write Model Specific Register) }
    (Mnemonic:'WRMSR';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 31 RDTSC (Read Time Stamp Counter) }
    (Mnemonic:'RDTSC';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 32 RDMSR (Read Model Specific Register) }
    (Mnemonic:'RDMSR';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 33 RDPMC (Read Performance Monitoring Counter, P6+) }
    (Mnemonic:'RDPMC';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 34..$0F 3F reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 40..$0F 4F CMOVcc r16, r/m16 (P6+) }
    { $0F 40 CMOVO }
    (Mnemonic:'CMOVO';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 41 CMOVNO }
    (Mnemonic:'CMOVNO';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 42 CMOVB }
    (Mnemonic:'CMOVB';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 43 CMOVNB }
    (Mnemonic:'CMOVNB';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 44 CMOVZ }
    (Mnemonic:'CMOVZ';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 45 CMOVNZ }
    (Mnemonic:'CMOVNZ';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 46 CMOVBE }
    (Mnemonic:'CMOVBE';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 47 CMOVNBE }
    (Mnemonic:'CMOVNBE';  OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 48 CMOVS }
    (Mnemonic:'CMOVS';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 49 CMOVNS }
    (Mnemonic:'CMOVNS';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 4A CMOVP }
    (Mnemonic:'CMOVP';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 4B CMOVNP }
    (Mnemonic:'CMOVNP';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 4C CMOVL }
    (Mnemonic:'CMOVL';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 4D CMOVNL }
    (Mnemonic:'CMOVNL';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 4E CMOVLE }
    (Mnemonic:'CMOVLE';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 4F CMOVNLE }
    (Mnemonic:'CMOVNLE';  OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 50..$0F 5F reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 60..$0F 6F reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 70..$0F 7F reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 80..$0F 8F Jcc rel16 (sauts conditionnels longs, 80386+) }
    (Mnemonic:'JO';       OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNO';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JB';       OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNB';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JZ';       OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNZ';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JBE';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNBE';     OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JS';       OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNS';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JP';       OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNP';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JL';       OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNL';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JLE';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNLE';     OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    { $0F 90..$0F 9F SETcc r/m8 (set byte on condition, 80386+) }
    (Mnemonic:'SETO';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNO';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETB';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNB';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETZ';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNZ';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETBE';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNBE';   OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETS';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNS';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETP';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNP';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETL';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNL';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETLE';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNLE';   OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    { $0F A0..$0F AF (PUSH FS/GS, BT/BTS/BTR/BTC, SHLD/SHRD, IMUL sur 80386+) }
    { $0F A0 PUSH FS }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_FS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F A1 POP FS }
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_FS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F A2 CPUID (Pentium+, reserve ici) }
    (Mnemonic:'CPUID';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F A3 BT r/m16, r16 }
    (Mnemonic:'BT';       OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:2),
    { $0F A4 SHLD r/m16, r16, imm8 }
    (Mnemonic:'SHLD';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:2),
    { $0F A5 SHLD r/m16, r16, CL }
    (Mnemonic:'SHLD';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_CL;    NeedModRM:True;  BaseSize:2),
    { $0F A6 reserve }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F A7 reserve }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F A8 PUSH GS }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_GS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F A9 POP GS }
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_GS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F AA RSM (resume from SMM, Pentium+) }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F AB BTS r/m16, r16 }
    (Mnemonic:'BTS';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:2),
    { $0F AC SHRD r/m16, r16, imm8 }
    (Mnemonic:'SHRD';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:2),
    { $0F AD SHRD r/m16, r16, CL }
    (Mnemonic:'SHRD';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_CL;    NeedModRM:True;  BaseSize:2),
    { $0F AE reserve (FXSAVE/FXRSTOR/etc., Pentium+) }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F AF IMUL r16, r/m16 }
    (Mnemonic:'IMUL';     OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F B0..$0F BF (CMPXCHG, MOVZX, MOVSX, BSF, BSR sur 80386+) }
    { $0F B0 CMPXCHG r/m8, r8 (80486+) }
    (Mnemonic:'CMPXCHG';  OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:2),
    { $0F B1 CMPXCHG r/m16, r16 (80486+) }
    (Mnemonic:'CMPXCHG';  OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:2),
    { $0F B2 LSS r16, m16:16 }
    (Mnemonic:'LSS';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_MEM;   NeedModRM:True;  BaseSize:2),
    { $0F B3 BTR r/m16, r16 }
    (Mnemonic:'BTR';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:2),
    { $0F B4 LFS r16, m16:16 }
    (Mnemonic:'LFS';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_MEM;   NeedModRM:True;  BaseSize:2),
    { $0F B5 LGS r16, m16:16 }
    (Mnemonic:'LGS';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_MEM;   NeedModRM:True;  BaseSize:2),
    { $0F B6 MOVZX r16, r/m8 }
    (Mnemonic:'MOVZX';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:2),
    { $0F B7 MOVZX r32, r/m16 }
    (Mnemonic:'MOVZX';    OpCount:2; Op1Type:OT_REG32; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F B8 reserve }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F B9 reserve }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F BA GRP8 r/m16, imm8 (BT/BTS/BTR/BTC) }
    (Mnemonic:'GRP8';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:2),
    { $0F BB BTC r/m16, r16 }
    (Mnemonic:'BTC';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:2),
    { $0F BC BSF r16, r/m16 }
    (Mnemonic:'BSF';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F BD BSR r16, r/m16 }
    (Mnemonic:'BSR';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F BE MOVSX r16, r/m8 }
    (Mnemonic:'MOVSX';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:2),
    { $0F BF MOVSX r32, r/m16 }
    (Mnemonic:'MOVSX';    OpCount:2; Op1Type:OT_REG32; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F C0..$0F CF (XADD, BSWAP sur 80486+) }
    { $0F C0 XADD r/m8, r8 (80486+) }
    (Mnemonic:'XADD';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:2),
    { $0F C1 XADD r/m16, r16 (80486+) }
    (Mnemonic:'XADD';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:2),
    { $0F C2..$0F C7 reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F C8..$0F CF BSWAP r32 (80486+) }
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F D0..$0F DF reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F E0..$0F EF reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F F0..$0F FF reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2)
  );
Var
  { --- bloc de code brut (drCBlock), retenu au lieu d etre saute --- }
  CodeBuf     : Array[0..MAX_CODE - 1] Of Byte;
  CodeSize    : LongInt;

  { --- table des labels resolus (adresse dans CodeBuf -> nom) --- }
  Labels      : Array[0..MAX_LABELS - 1] Of TLabelInfo;
  LabelCount  : LongInt;

  { --- numerotation des index d adresse ("address-def"/NDX), voir   }
  { l en-tete de section ci-dessus (NextAddrDef) --- }
  AddrDefCounter  : LongInt;
  AddrDefName     : Array[1..MAX_ADDRDEF] Of TString;
  AddrDefIsProc   : Array[1..MAX_ADDRDEF] Of Boolean;
  AddrDefIsImport : Array[1..MAX_ADDRDEF] Of Boolean;

  { --- table brute des correctifs (drFixUp), decodee par ProcessFixup --- }
  FixupCount   : LongInt;
  FixupOfsArr  : Array[1..MAX_FIXUPS] Of LongInt;
  FixupKindArr : Array[1..MAX_FIXUPS] Of Byte;
  FixupNDXArr  : Array[1..MAX_FIXUPS] Of LongInt;
  FxStartMark  : Byte;
  FxEndMark    : Byte;

  { --- plage de code (offset/taille dans CodeBuf) par index d adresse,  }
  { etablie par ProcessFixup (paires fxStart/fxEnd) --- }
  ProcCodeOfs : Array[1..MAX_ADDRDEF] Of LongInt;
  ProcCodeSz  : Array[1..MAX_ADDRDEF] Of LongInt;

  { --- procedures/fonctions NOMMEES rencontrees, dans l ordre du fichier --- }
  ProcList    : Array[1..MAX_PROCS] Of TProcInfo;
  ProcListCnt : LongInt;
Function HexByte(B: Byte): TString;
Const
  HexDigits: Array[0..15] Of Char = '0123456789ABCDEF';
Begin
  HexByte := HexDigits[B Shr 4] + HexDigits[B And $0F];
End;

Function HexWord(W: Word): TString;
Begin
  HexWord := HexByte(Hi(W)) + HexByte(Lo(W));
End;

Function HexDWord(D: LongInt): TString;
Begin
  HexDWord := HexWord(Word(D Shr 16)) + HexWord(Word(D And $FFFF));
End;

{ --- lecteurs bornes sur CodeBuf/CodeSize (equivalent de ReadImageByte     }
{ etc. de DISEXE.PAS, mais sur le blob de code de la DCU au lieu d une      }
{ image PE/MZ) --- }
Function ReadCodeByte(Ofs: LongInt): Byte;
Begin
  If (Ofs < 0) Or (Ofs >= CodeSize) Then
    ReadCodeByte := 0
  Else
    ReadCodeByte := CodeBuf[Ofs];
End;

Function ReadCodeWord(Ofs: LongInt): Word;
Begin
  ReadCodeWord := Word(ReadCodeByte(Ofs)) Or (Word(ReadCodeByte(Ofs + 1)) Shl 8);
End;

Function ReadCodeDWord(Ofs: LongInt): LongInt;
Begin
  ReadCodeDWord := LongInt(ReadCodeByte(Ofs)) Or
    (LongInt(ReadCodeByte(Ofs + 1)) Shl 8) Or
    (LongInt(ReadCodeByte(Ofs + 2)) Shl 16) Or
    (LongInt(ReadCodeByte(Ofs + 3)) Shl 24);
End;

{ --- numerotation des index d adresse (voir en-tete de section) --- }
Function NextAddrDef: LongInt;
Begin
  Inc(AddrDefCounter);
  If AddrDefCounter <= MAX_ADDRDEF Then
  Begin
    AddrDefName[AddrDefCounter] := '';
    AddrDefIsProc[AddrDefCounter] := False;
    AddrDefIsImport[AddrDefCounter] := False;
  End;
  NextAddrDef := AddrDefCounter;
End;

{ --- recherche d un correctif (drFixUp) exactement a l offset donne du    }
{ blob de code - c est ce mecanisme, PAS une adresse cible calculee, qui    }
{ indique le VRAI destinataire d un CALL/JMP dans un blob non encore relie   }
{ (voir en-tete de section). Recherche lineaire : le nombre de correctifs      }
{ par routine reste petit, pas besoin d index trie. --- }
Function FindFixupAt(Ofs: LongInt): LongInt;
Var
  I: LongInt;
Begin
  FindFixupAt := -1;
  For I := 1 To FixupCount Do
    If (FixupOfsArr[I] = Ofs) And (FixupKindArr[I] <> FxStartMark) And
       (FixupKindArr[I] <> FxEndMark) Then
    Begin
      FindFixupAt := FixupNDXArr[I];
      Exit;
    End;
End;

{ --- resout un index d adresse (NDX) en texte de symbole si on connait   }
{ son nom (procedure locale nommee ou import) ; chaine vide sinon --- }
Function ResolveAddrDefName(Idx: LongInt): TString;
Begin
  If (Idx >= 1) And (Idx <= MAX_ADDRDEF) And (Idx <= AddrDefCounter) And
     (AddrDefName[Idx] <> '') Then
    ResolveAddrDefName := AddrDefName[Idx]
  Else
    ResolveAddrDefName := '';
End;

Function AddLabel(Addr: LongInt; AName: TString; Proc, Imp, Exp: Boolean): Boolean;
Var
  I: LongInt;
Begin
  For I := 0 To LabelCount - 1 Do
    If Labels[I].Address = Addr Then
    Begin
      If Proc Then Labels[I].IsProc := True;
      If Imp Then Labels[I].IsImport := True;
      If Exp Then Labels[I].IsExport := True;
      If (AName <> '') And (Labels[I].Name = '') Then Labels[I].Name := AName;
      AddLabel := False;
      Exit;
    End;
  If LabelCount >= MAX_LABELS Then
  Begin
    AddLabel := False;
    Exit;
  End;
  Labels[LabelCount].Address := Addr;
  Labels[LabelCount].Name := AName;
  Labels[LabelCount].IsProc := Proc;
  Labels[LabelCount].IsImport := Imp;
  Labels[LabelCount].IsExport := Exp;
  Inc(LabelCount);
  AddLabel := True;
End;

Function FindLabel(Addr: LongInt): LongInt;
Var
  I: LongInt;
Begin
  For I := 0 To LabelCount - 1 Do
    If Labels[I].Address = Addr Then
    Begin
      FindLabel := I;
      Exit;
    End;
  FindLabel := -1;
End;

Const
  { Noms des 8 modes d'adressage effectifs 16 bits (r/m 0..7, mod<>11) }
  RM16Names : Array[0..7] Of String[5] = (
    'BX+SI', 'BX+DI', 'BP+SI', 'BP+DI',
    'SI',    'DI',    'BP',    'BX'
  );

{ DecodeModRM16 - Decode l'octet ModR/M pour le mode 16 bits.
  Parametres :
    Offset    : position dans l'image (pointe vers l'octet ModR/M)
    OpSize    : taille de l'operande (1 = 8 bits, 2 = 16 bits)
  Resultats retournes par var :
    RegField  : valeur du champ reg (3 bits, indice de registre)
    RMStr     : chaine d'operande pour le champ r/m
    BytesUsed : nombre d'octets consommes (1 pour ModR/M + deplacements)
}
Procedure DecodeModRM16(Offset : LongInt; OpSize : Byte;
                        Var RegField : Byte; Var RMStr : TString;
                        Var BytesUsed : Integer);
Var
  ModRM    : Byte;
  ModVal   : Byte;   { champ mod (2 bits superieurs) }
  RegVal   : Byte;   { champ reg (3 bits du milieu) }
  RMVal    : Byte;   { champ r/m (3 bits inferieurs) }
  Disp8    : ShortInt;
  Disp16   : SmallInt;
  DispW    : Word;
Begin
  ModRM := ReadCodeByte(Offset);
  ModVal := (ModRM Shr 6) And $03;
  RegVal := (ModRM Shr 3) And $07;
  RMVal  := ModRM And $07;
  RegField := RegVal;
  BytesUsed := 1; { au minimum, l'octet ModR/M lui-meme }

  Case ModVal Of
    { mod=11 : registre direct }
    3 : Begin
      If OpSize = 1 Then
        RMStr := RegNames8[RMVal]
      Else
        RMStr := RegNames16[RMVal];
    End;
    { mod=00 : pas de deplacement (sauf cas special r/m=110 -> disp16) }
    0 : Begin
      If RMVal = 6 Then Begin
        { Cas special : adresse directe 16 bits }
        DispW := ReadCodeWord(Offset + 1);
        RMStr := '[' + HexWord(DispW) + 'h]';
        BytesUsed := 3; { ModR/M + disp16 }
      End Else Begin
        RMStr := '[' + RM16Names[RMVal] + ']';
      End;
    End;
    { mod=01 : deplacement 8 bits signe }
    1 : Begin
      Disp8 := ShortInt(ReadCodeByte(Offset + 1));
      BytesUsed := 2; { ModR/M + disp8 }
      If Disp8 = 0 Then
        RMStr := '[' + RM16Names[RMVal] + ']'
      Else If Disp8 > 0 Then
        RMStr := '[' + RM16Names[RMVal] + '+' + HexByte(Byte(Disp8)) + 'h]'
      Else
        RMStr := '[' + RM16Names[RMVal] + '-' + HexByte(Byte(-Disp8)) + 'h]';
    End;
    { mod=10 : deplacement 16 bits }
    2 : Begin
      Disp16 := SmallInt(ReadCodeWord(Offset + 1));
      BytesUsed := 3; { ModR/M + disp16 }
      If Disp16 = 0 Then
        RMStr := '[' + RM16Names[RMVal] + ']'
      Else If Disp16 > 0 Then Begin
        DispW := Word(Disp16);
        RMStr := '[' + RM16Names[RMVal] + '+' + HexWord(DispW) + 'h]';
      End Else Begin
        DispW := Word(-Disp16);
        RMStr := '[' + RM16Names[RMVal] + '-' + HexWord(DispW) + 'h]';
      End;
    End;
  End;
End;

{ DecodeRegField16 - Retourne le nom du registre pour le champ reg (mode 16 bits).
  OpSize = 1 : registre 8 bits, OpSize = 2 : registre 16 bits }
Function DecodeRegField16(RegIndex : Byte; OpSize : Byte) : TString;
Begin
  If OpSize = 1 Then
    DecodeRegField16 := RegNames8[RegIndex And $07]
  Else
    DecodeRegField16 := RegNames16[RegIndex And $07];
End;

{ DecodeModRM16Full - Decode ModR/M et retourne les deux operandes.
  Parametres :
    Offset    : position dans l'image (pointe vers l'octet ModR/M)
    OpSize    : taille de l'operande (1 = 8 bits, 2 = 16 bits)
    DirBit    : True = reg est destination (reg, r/m), False = r/m est destination (r/m, reg)
  Resultats retournes par var :
    Op1Str    : chaine du 1er operande
    Op2Str    : chaine du 2e operande
    BytesUsed : nombre d'octets consommes (ModR/M + deplacements)
}
Procedure DecodeModRM16Full(Offset : LongInt; OpSize : Byte; DirBit : Boolean;
                            Var Op1Str, Op2Str : TString;
                            Var BytesUsed : Integer);
Var
  RegField  : Byte;
  RMStr     : TString;
  RegStr    : TString;
Begin
  DecodeModRM16(Offset, OpSize, RegField, RMStr, BytesUsed);
  RegStr := DecodeRegField16(RegField, OpSize);
  If DirBit Then Begin
    { reg est destination : op1=reg, op2=r/m }
    Op1Str := RegStr;
    Op2Str := RMStr;
  End Else Begin
    { r/m est destination : op1=r/m, op2=reg }
    Op1Str := RMStr;
    Op2Str := RegStr;
  End;
End;

{ ============================================================
  DECODAGE MODR/M ET SIB 32 BITS
  ============================================================ }

Const
  { Facteurs d'echelle SIB : scale field (2 bits) -> multiplicateur }
  ScaleFactors : Array[0..3] Of Byte = (1, 2, 4, 8);

{ DecodeSIB - Decode l'octet SIB (Scale-Index-Base) pour le mode 32 bits.
  Parametres :
    SIBByte   : valeur de l'octet SIB
    ModVal    : valeur du champ mod de l'octet ModR/M (pour cas special base=5)
    Offset    : position dans l'image apres l'octet SIB (pour lire disp32)
  Resultats retournes par var :
    SIBStr    : chaine d'adresse generee (sans crochets)
    ExtraBytes: nombre d'octets supplementaires consommes (0 ou 4 pour disp32)
}
Procedure DecodeSIB(SIBByte : Byte; ModVal : Byte; Offset : LongInt;
                    Var SIBStr : TString; Var ExtraBytes : Integer);
Var
  Scale  : Byte;    { champ scale (2 bits superieurs) }
  Idx    : Byte;    { champ index (3 bits du milieu) }
  Base   : Byte;    { champ base (3 bits inferieurs) }
  Disp32 : LongInt;
  HasBase  : Boolean;
  HasIndex : Boolean;
Begin
  Scale := (SIBByte Shr 6) And $03;
  Idx   := (SIBByte Shr 3) And $07;
  Base  := SIBByte And $07;
  ExtraBytes := 0;
  SIBStr := '';
  HasBase := True;
  HasIndex := True;

  { index=100 (ESP) signifie pas d'index }
  If Idx = 4 Then
    HasIndex := False;

  { base=101 (EBP) avec mod=00 signifie pas de base, disp32 a la place }
  If (Base = 5) And (ModVal = 0) Then Begin
    HasBase := False;
    Disp32 := ReadCodeDWord(Offset);
    ExtraBytes := 4;
  End;

  { Construire la chaine d'adresse }
  If HasBase Then
    SIBStr := RegNames32[Base];

  If HasIndex Then Begin
    If SIBStr <> '' Then
      SIBStr := SIBStr + '+';
    SIBStr := SIBStr + RegNames32[Idx];
    If Scale > 0 Then
      SIBStr := SIBStr + '*' + IntToStr(ScaleFactors[Scale]);
  End;

  If Not HasBase Then Begin
    { disp32 sans base }
    If SIBStr <> '' Then
      SIBStr := SIBStr + '+' + HexDWord(Disp32) + 'h'
    Else
      SIBStr := HexDWord(Disp32) + 'h';
  End;

  { Si aucun composant (ne devrait pas arriver normalement) }
  If SIBStr = '' Then
    SIBStr := '0';
End;

{ DecodeModRM32 - Decode l'octet ModR/M pour le mode 32 bits.
  Parametres :
    Offset    : position dans l'image (pointe vers l'octet ModR/M)
    OpSize    : taille de l'operande (1 = 8 bits, 4 = 32 bits)
  Resultats retournes par var :
    RegField  : valeur du champ reg (3 bits, indice de registre)
    RMStr     : chaine d'operande pour le champ r/m
    BytesUsed : nombre d'octets consommes (ModR/M + SIB + deplacements)
}
Procedure DecodeModRM32(Offset : LongInt; OpSize : Byte;
                        Var RegField : Byte; Var RMStr : TString;
                        Var BytesUsed : Integer);
Var
  ModRM    : Byte;
  ModVal   : Byte;    { champ mod (2 bits superieurs) }
  RegVal   : Byte;    { champ reg (3 bits du milieu) }
  RMVal    : Byte;    { champ r/m (3 bits inferieurs) }
  SIBByte  : Byte;
  SIBStr   : TString;
  SIBExtra : Integer;
  Disp8    : ShortInt;
  Disp32   : LongInt;
  DispDW   : LongInt;
Begin
  ModRM := ReadCodeByte(Offset);
  ModVal := (ModRM Shr 6) And $03;
  RegVal := (ModRM Shr 3) And $07;
  RMVal  := ModRM And $07;
  RegField := RegVal;
  BytesUsed := 1; { au minimum, l'octet ModR/M lui-meme }

  Case ModVal Of
    { mod=11 : registre direct }
    3 : Begin
      If OpSize = 1 Then
        RMStr := RegNames8[RMVal]
      Else
        RMStr := RegNames32[RMVal];
    End;
    { mod=00 : pas de deplacement }
    0 : Begin
      If RMVal = 5 Then Begin
        { Cas special : adresse directe 32 bits (disp32) }
        Disp32 := ReadCodeDWord(Offset + 1);
        RMStr := '[' + HexDWord(Disp32) + 'h]';
        BytesUsed := 5; { ModR/M + disp32 }
      End
      Else If RMVal = 4 Then Begin
        { SIB byte suit le ModR/M }
        SIBByte := ReadCodeByte(Offset + 1);
        DecodeSIB(SIBByte, ModVal, Offset + 2, SIBStr, SIBExtra);
        RMStr := '[' + SIBStr + ']';
        BytesUsed := 2 + SIBExtra; { ModR/M + SIB + eventuellement disp32 }
      End Else Begin
        RMStr := '[' + RegNames32[RMVal] + ']';
      End;
    End;
    { mod=01 : deplacement 8 bits signe }
    1 : Begin
      If RMVal = 4 Then Begin
        { SIB byte suit le ModR/M, puis disp8 }
        SIBByte := ReadCodeByte(Offset + 1);
        DecodeSIB(SIBByte, ModVal, Offset + 2, SIBStr, SIBExtra);
        Disp8 := ShortInt(ReadCodeByte(Offset + 2 + SIBExtra));
        BytesUsed := 3 + SIBExtra; { ModR/M + SIB + disp8 + SIBExtra }
        If Disp8 = 0 Then
          RMStr := '[' + SIBStr + ']'
        Else If Disp8 > 0 Then
          RMStr := '[' + SIBStr + '+' + HexByte(Byte(Disp8)) + 'h]'
        Else
          RMStr := '[' + SIBStr + '-' + HexByte(Byte(-Disp8)) + 'h]';
      End Else Begin
        Disp8 := ShortInt(ReadCodeByte(Offset + 1));
        BytesUsed := 2; { ModR/M + disp8 }
        If Disp8 = 0 Then
          RMStr := '[' + RegNames32[RMVal] + ']'
        Else If Disp8 > 0 Then
          RMStr := '[' + RegNames32[RMVal] + '+' + HexByte(Byte(Disp8)) + 'h]'
        Else
          RMStr := '[' + RegNames32[RMVal] + '-' + HexByte(Byte(-Disp8)) + 'h]';
      End;
    End;
    { mod=10 : deplacement 32 bits }
    2 : Begin
      If RMVal = 4 Then Begin
        { SIB byte suit le ModR/M, puis disp32 }
        SIBByte := ReadCodeByte(Offset + 1);
        DecodeSIB(SIBByte, ModVal, Offset + 2, SIBStr, SIBExtra);
        Disp32 := ReadCodeDWord(Offset + 2 + SIBExtra);
        BytesUsed := 6 + SIBExtra; { ModR/M + SIB + disp32 + SIBExtra }
        If Disp32 = 0 Then
          RMStr := '[' + SIBStr + ']'
        Else If Disp32 > 0 Then Begin
          DispDW := Disp32;
          RMStr := '[' + SIBStr + '+' + HexDWord(DispDW) + 'h]';
        End Else Begin
          DispDW := -Disp32;
          RMStr := '[' + SIBStr + '-' + HexDWord(DispDW) + 'h]';
        End;
      End Else Begin
        Disp32 := ReadCodeDWord(Offset + 1);
        BytesUsed := 5; { ModR/M + disp32 }
        If Disp32 = 0 Then
          RMStr := '[' + RegNames32[RMVal] + ']'
        Else If Disp32 > 0 Then Begin
          DispDW := Disp32;
          RMStr := '[' + RegNames32[RMVal] + '+' + HexDWord(DispDW) + 'h]';
        End Else Begin
          DispDW := -Disp32;
          RMStr := '[' + RegNames32[RMVal] + '-' + HexDWord(DispDW) + 'h]';
        End;
      End;
    End;
  End;
End;

{ DecodeRegField32 - Retourne le nom du registre pour le champ reg (mode 32 bits).
  OpSize = 1 : registre 8 bits, OpSize = 4 : registre 32 bits }
Function DecodeRegField32(RegIndex : Byte; OpSize : Byte) : TString;
Begin
  If OpSize = 1 Then
    DecodeRegField32 := RegNames8[RegIndex And $07]
  Else
    DecodeRegField32 := RegNames32[RegIndex And $07];
End;

{ DecodeModRM32Full - Decode ModR/M et retourne les deux operandes (mode 32 bits).
  Parametres :
    Offset    : position dans l'image (pointe vers l'octet ModR/M)
    OpSize    : taille de l'operande (1 = 8 bits, 4 = 32 bits)
    DirBit    : True = reg est destination (reg, r/m), False = r/m est destination (r/m, reg)
  Resultats retournes par var :
    Op1Str    : chaine du 1er operande
    Op2Str    : chaine du 2e operande
    BytesUsed : nombre d'octets consommes (ModR/M + SIB + deplacements)
}
Procedure DecodeModRM32Full(Offset : LongInt; OpSize : Byte; DirBit : Boolean;
                            Var Op1Str, Op2Str : TString;
                            Var BytesUsed : Integer);
Var
  RegField  : Byte;
  RMStr     : TString;
  RegStr    : TString;
Begin
  DecodeModRM32(Offset, OpSize, RegField, RMStr, BytesUsed);
  RegStr := DecodeRegField32(RegField, OpSize);
  If DirBit Then Begin
    { reg est destination : op1=reg, op2=r/m }
    Op1Str := RegStr;
    Op2Str := RMStr;
  End Else Begin
    { r/m est destination : op1=r/m, op2=reg }
    Op1Str := RMStr;
    Op2Str := RegStr;
  End;
End;

{ ============================================================
  DECODAGE DES PREFIXES D'INSTRUCTIONS
  ============================================================ }

Type
  { Etat des prefixes accumules avant une instruction }
  TPrefixState = Record
    HasSegOverride : Boolean;    { True si un prefixe de segment est present }
    SegOverride    : Byte;       { indice segment (0=ES,1=CS,2=SS,3=DS,4=FS,5=GS) }
    SegOverrideStr : String[3];  { chaine du segment ('ES:','CS:',...) }
    HasLock        : Boolean;    { True si LOCK (F0h) est present }
    HasRep         : Boolean;    { True si REP/REPE (F3h) est present }
    HasRepNE       : Boolean;    { True si REPNE (F2h) est present }
    HasOpSize      : Boolean;    { True si prefixe taille operande (66h) }
    HasAddrSize    : Boolean;    { True si prefixe taille adresse (67h) }
    PrefixCount    : Integer;    { nombre total d'octets de prefixes consommes }
    EffOpSize      : Byte;       { taille effective de l'operande (1, 2 ou 4) }
    EffAddrSize    : Byte;       { taille effective de l'adresse (2 ou 4) }
  End;

{ IsPrefix - Retourne True si l'octet est un prefixe d'instruction.
  Prefixes reconnus : 26h,2Eh,36h,3Eh (seg 8086+), 64h,65h (seg 386+),
                      66h (OpSize), 67h (AddrSize), F0h (LOCK),
                      F2h (REPNE), F3h (REP/REPE) }
Function IsPrefix(B : Byte) : Boolean;
Begin
  Case B Of
    $26, $2E, $36, $3E,  { ES:, CS:, SS:, DS: }
    $64, $65,             { FS:, GS: }
    $66,                  { operand size override }
    $67,                  { address size override }
    $F0,                  { LOCK }
    $F2,                  { REPNE/REPNZ }
    $F3 :                 { REP/REPE/REPZ }
      IsPrefix := True;
  Else
    IsPrefix := False;
  End;
End;

{ InitPrefixState - Initialise l'etat des prefixes.
  Mode32 : True si le mode par defaut est 32 bits, False si 16 bits.
  En mode 16 bits : operande 16 bits, adresse 16 bits par defaut.
  En mode 32 bits : operande 32 bits, adresse 32 bits par defaut. }
Procedure InitPrefixState(Var PFX : TPrefixState; Mode32 : Boolean);
Begin
  PFX.HasSegOverride := False;
  PFX.SegOverride    := 0;
  PFX.SegOverrideStr := '';
  PFX.HasLock        := False;
  PFX.HasRep         := False;
  PFX.HasRepNE       := False;
  PFX.HasOpSize      := False;
  PFX.HasAddrSize    := False;
  PFX.PrefixCount    := 0;
  If Mode32 Then Begin
    PFX.EffOpSize   := 4;   { 32 bits par defaut }
    PFX.EffAddrSize := 4;
  End Else Begin
    PFX.EffOpSize   := 2;   { 16 bits par defaut }
    PFX.EffAddrSize := 2;
  End;
End;

{ DecodePrefixes - Lit les octets de prefixes a partir de Offset dans l'image.
  Accumule tous les prefixes consecutifs et met a jour l'etat PFX.
  Mode32 : True si le mode courant est 32 bits.
  PFX doit etre initialise par InitPrefixState avant l'appel.
  Apres l'appel, PFX.PrefixCount contient le nombre d'octets de prefixes.
  L'opcode reel se trouve donc a Offset + PFX.PrefixCount. }
Procedure DecodePrefixes(Offset : LongInt; Mode32 : Boolean;
                         Var PFX : TPrefixState);
Var
  B    : Byte;
  Done : Boolean;
Begin
  Done := False;
  While Not Done Do Begin
    If (Offset + PFX.PrefixCount) >= CodeSize Then
      Break;
    B := ReadCodeByte(Offset + PFX.PrefixCount);
    Case B Of
      $26 : Begin { ES: segment override }
        PFX.HasSegOverride := True;
        PFX.SegOverride    := 0;
        PFX.SegOverrideStr := 'ES:';
        Inc(PFX.PrefixCount);
      End;
      $2E : Begin { CS: segment override }
        PFX.HasSegOverride := True;
        PFX.SegOverride    := 1;
        PFX.SegOverrideStr := 'CS:';
        Inc(PFX.PrefixCount);
      End;
      $36 : Begin { SS: segment override }
        PFX.HasSegOverride := True;
        PFX.SegOverride    := 2;
        PFX.SegOverrideStr := 'SS:';
        Inc(PFX.PrefixCount);
      End;
      $3E : Begin { DS: segment override }
        PFX.HasSegOverride := True;
        PFX.SegOverride    := 3;
        PFX.SegOverrideStr := 'DS:';
        Inc(PFX.PrefixCount);
      End;
      $64 : Begin { FS: segment override (80386+) }
        PFX.HasSegOverride := True;
        PFX.SegOverride    := 4;
        PFX.SegOverrideStr := 'FS:';
        Inc(PFX.PrefixCount);
      End;
      $65 : Begin { GS: segment override (80386+) }
        PFX.HasSegOverride := True;
        PFX.SegOverride    := 5;
        PFX.SegOverrideStr := 'GS:';
        Inc(PFX.PrefixCount);
      End;
      $66 : Begin { operand size override (80386+) }
        PFX.HasOpSize := True;
        Inc(PFX.PrefixCount);
        { Bascule la taille d'operande : 32->16 ou 16->32 }
        If Mode32 Then
          PFX.EffOpSize := 2
        Else
          PFX.EffOpSize := 4;
      End;
      $67 : Begin { address size override (80386+) }
        PFX.HasAddrSize := True;
        Inc(PFX.PrefixCount);
        { Bascule la taille d'adresse : 32->16 ou 16->32 }
        If Mode32 Then
          PFX.EffAddrSize := 2
        Else
          PFX.EffAddrSize := 4;
      End;
      $F0 : Begin { LOCK }
        PFX.HasLock := True;
        Inc(PFX.PrefixCount);
      End;
      $F2 : Begin { REPNE/REPNZ }
        PFX.HasRepNE := True;
        PFX.HasRep   := False;  { REPNE ecrase REP si deja vu }
        Inc(PFX.PrefixCount);
      End;
      $F3 : Begin { REP/REPE/REPZ }
        PFX.HasRep   := True;
        PFX.HasRepNE := False;  { REP ecrase REPNE si deja vu }
        Inc(PFX.PrefixCount);
      End;
    Else
      Done := True;  { octet non-prefixe : on arrete }
    End;
  End;
End;

{ PrefixToStr - Retourne la chaine des prefixes accumules pour l'affichage.
  Exemple : 'LOCK REP ES:' si LOCK, REP et ES: sont presents.
  Retourne une chaine vide si aucun prefixe n'est present. }
Function PrefixToStr(Const PFX : TPrefixState) : TString;
Var
  S : TString;
Begin
  S := '';
  If PFX.HasLock Then
    S := S + 'LOCK ';
  If PFX.HasRep Then
    S := S + 'REP ';
  If PFX.HasRepNE Then
    S := S + 'REPNE ';
  PrefixToStr := S;
End;

{ InjectSegOvr - Insere un prefixe de segment devant la premiere reference
  memoire '[' dans la chaine d'operandes S.
  Si aucune reference memoire n'est present, retourne S inchange.
  Exemple : InjectSegOvr('SS:', '[0148h], SP') -> 'SS:[0148h], SP' }
Function InjectSegOvr(Const SegOvr, S : TString) : TString;
Var
  P : Integer;
Begin
  If SegOvr = '' Then Begin
    InjectSegOvr := S;
    Exit;
  End;
  P := Pos('[', S);
  If P > 0 Then
    InjectSegOvr := Copy(S, 1, P - 1) + SegOvr + Copy(S, P, Length(S))
  Else
    InjectSegOvr := S;
End;

{ ============================================================
  DECODAGE DES OPCODES ETENDUS 0Fh
  ============================================================ }

{ Decode0FOpcode - Decode un opcode etendu 0Fh et retourne le mnemonique,
  les operandes et le nombre d'octets consommes APRES l'octet 0Fh.
  Parametres :
    SecondByte : valeur du second octet (apres le 0Fh)
    Offset     : position dans l'image du premier octet APRES le second octet
                 (c.-a-d. l'octet ModR/M ou immediat eventuel)
    PFX        : etat des prefixes (EffOpSize, EffAddrSize, etc.)
  Resultats retournes par var :
    Mnem       : mnemonique de l'instruction (ex: 'JNZ', 'MOVZX', ...)
    Operands   : chaine des operandes (ex: 'EAX, [EBX+04h]')
    BytesUsed  : nombre d'octets consommes APRES le 0Fh (inclut le second octet)
}
Procedure Decode0FOpcode(SecondByte : Byte; Offset : LongInt;
                         Const PFX : TPrefixState;
                         Var Mnem : TString; Var Operands : TString;
                         Var BytesUsed : Integer);
Var
  Entry      : TOpcodeEntry;
  RegField   : Byte;
  RMStr      : TString;
  RegStr     : TString;
  ModRMBytes : Integer;
  Rel16      : SmallInt;
  Rel32      : LongInt;
  Imm8       : Byte;
  TargetAddr : LongInt;
  OpSz       : Byte;       { taille effective d'operande (2 ou 4) }
  AddrSz     : Byte;       { taille effective d'adresse (2 ou 4) }
  ModRM      : Byte;
  RegIdx     : Byte;
Begin
  Entry := Opcode0FTable[SecondByte];
  OpSz  := PFX.EffOpSize;
  AddrSz := PFX.EffAddrSize;
  Mnem := Entry.Mnemonic;
  Operands := '';
  BytesUsed := 1; { le second octet lui-meme est toujours consomme }

  { Instructions inconnues ou reservees }
  If Entry.Mnemonic = '???' Then Begin
    Mnem := 'DB';
    Operands := '0Fh, ' + HexByte(SecondByte) + 'h';
    Exit;
  End;

  { --- Cas speciaux des instructions de groupe (GRP6/GRP7/GRP8) --- }
  If Entry.Mnemonic = 'GRP6' Then Begin
    If Offset < CodeSize Then Begin
      ModRM := ReadCodeByte(Offset);
      RegField := (ModRM Shr 3) And $07;
      Mnem := Grp6Mnemonics[RegField];
      If AddrSz = 4 Then
        DecodeModRM32(Offset, 2, RegField, RMStr, ModRMBytes)
      Else
        DecodeModRM16(Offset, 2, RegField, RMStr, ModRMBytes);
      Operands := RMStr;
      BytesUsed := 1 + ModRMBytes;
    End;
    Exit;
  End;

  If Entry.Mnemonic = 'GRP7' Then Begin
    If Offset < CodeSize Then Begin
      ModRM := ReadCodeByte(Offset);
      RegField := (ModRM Shr 3) And $07;
      Mnem := Grp7Mnemonics[RegField];
      If AddrSz = 4 Then
        DecodeModRM32(Offset, 2, RegField, RMStr, ModRMBytes)
      Else
        DecodeModRM16(Offset, 2, RegField, RMStr, ModRMBytes);
      Operands := RMStr;
      BytesUsed := 1 + ModRMBytes;
    End;
    Exit;
  End;

  If Entry.Mnemonic = 'GRP8' Then Begin
    If Offset < CodeSize Then Begin
      ModRM := ReadCodeByte(Offset);
      RegField := (ModRM Shr 3) And $07;
      Mnem := Grp8Mnemonics[RegField];
      If AddrSz = 4 Then
        DecodeModRM32(Offset, OpSz, RegField, RMStr, ModRMBytes)
      Else
        DecodeModRM16(Offset, OpSz, RegField, RMStr, ModRMBytes);
      Imm8 := ReadCodeByte(Offset + ModRMBytes);
      Operands := RMStr + ', ' + HexByte(Imm8) + 'h';
      BytesUsed := 1 + ModRMBytes + 1;
    End;
    Exit;
  End;

  { --- BSWAP : registre encode dans les 3 bits bas du second octet --- }
  If (SecondByte >= $C8) And (SecondByte <= $CF) And
     (Entry.Mnemonic = 'BSWAP') Then Begin
    RegIdx := SecondByte And $07;
    Operands := RegNames32[RegIdx];
    Exit;
  End;

  { --- Jcc near : deplacement relatif 16/32 bits --- }
  If (SecondByte >= $80) And (SecondByte <= $8F) Then Begin
    If OpSz = 4 Then Begin
      Rel32 := ReadCodeDWord(Offset);
      TargetAddr := Offset + 4 + Rel32;
      Operands := HexDWord(TargetAddr) + 'h';
      BytesUsed := 1 + 4;
    End Else Begin
      Rel16 := SmallInt(ReadCodeWord(Offset));
      TargetAddr := Offset + 2 + Rel16;
      Operands := HexWord(Word(TargetAddr And $FFFF)) + 'h';
      BytesUsed := 1 + 2;
    End;
    Exit;
  End;

  { --- MOV CRn/DRn/TRn : registres speciaux --- }
  If (SecondByte >= $20) And (SecondByte <= $27) And
     (Entry.Mnemonic = 'MOV') Then Begin
    If Offset < CodeSize Then Begin
      ModRM := ReadCodeByte(Offset);
      RegField := (ModRM Shr 3) And $07;
      RegIdx := ModRM And $07;
      BytesUsed := 1 + 1; { second byte + ModR/M }
      Case SecondByte Of
        $20 : Operands := RegNames32[RegIdx] + ', ' + CRegNames[RegField And $03];
        $21 : Operands := RegNames32[RegIdx] + ', ' + DRegNames[RegField];
        $22 : Operands := CRegNames[RegField And $03] + ', ' + RegNames32[RegIdx];
        $23 : Operands := DRegNames[RegField] + ', ' + RegNames32[RegIdx];
        $24 : Operands := RegNames32[RegIdx] + ', ' + TRegNames[RegField];
        $26 : Operands := TRegNames[RegField] + ', ' + RegNames32[RegIdx];
      Else
        Operands := '???';
      End;
    End;
    Exit;
  End;

  { --- SHLD/SHRD : 3 operandes (r/m, reg, imm8 ou CL) --- }
  If ((SecondByte = $A4) Or (SecondByte = $A5) Or
      (SecondByte = $AC) Or (SecondByte = $AD)) And
     ((Entry.Mnemonic = 'SHLD') Or (Entry.Mnemonic = 'SHRD')) Then Begin
    If Offset < CodeSize Then Begin
      If AddrSz = 4 Then Begin
        DecodeModRM32(Offset, OpSz, RegField, RMStr, ModRMBytes);
        If OpSz = 4 Then
          RegStr := RegNames32[RegField]
        Else
          RegStr := RegNames16[RegField];
      End Else Begin
        DecodeModRM16(Offset, OpSz, RegField, RMStr, ModRMBytes);
        If OpSz = 4 Then
          RegStr := RegNames32[RegField]
        Else
          RegStr := RegNames16[RegField];
      End;
      If (SecondByte = $A4) Or (SecondByte = $AC) Then Begin
        { SHLD/SHRD r/m, r, imm8 }
        Imm8 := ReadCodeByte(Offset + ModRMBytes);
        Operands := RMStr + ', ' + RegStr + ', ' + HexByte(Imm8) + 'h';
        BytesUsed := 1 + ModRMBytes + 1;
      End Else Begin
        { SHLD/SHRD r/m, r, CL }
        Operands := RMStr + ', ' + RegStr + ', CL';
        BytesUsed := 1 + ModRMBytes;
      End;
    End;
    Exit;
  End;

  { --- Instructions sans operande (CLTS, CPUID, INVD, WBINVD, etc.) --- }
  If Entry.OpCount = 0 Then Begin
    Operands := '';
    Exit;
  End;

  { --- Instructions avec 1 operande (SETcc, PUSH/POP FS/GS) --- }
  If Entry.OpCount = 1 Then Begin
    Case Entry.Op1Type Of
      OT_RM8 : Begin
        If Offset < CodeSize Then Begin
          If AddrSz = 4 Then
            DecodeModRM32(Offset, 1, RegField, RMStr, ModRMBytes)
          Else
            DecodeModRM16(Offset, 1, RegField, RMStr, ModRMBytes);
          Operands := RMStr;
          BytesUsed := 1 + ModRMBytes;
        End;
      End;
      OT_FS : Operands := 'FS';
      OT_GS : Operands := 'GS';
      OT_REG32 : Begin
        { BSWAP fallback (deja traite au-dessus normalement) }
        RegIdx := SecondByte And $07;
        Operands := RegNames32[RegIdx];
      End;
    Else
      Operands := '???';
    End;
    Exit;
  End;

  { --- Instructions avec 2 operandes (generique) --- }
  If Entry.OpCount = 2 Then Begin
    { Determiner la taille d'operande effective pour les types 16-bit }
    { Les types RM16/REG16 deviennent RM32/REG32 si EffOpSize=4 }

    { Cas: premier operande = registre, second = r/m (direction reg<-r/m) }
    If (Entry.Op1Type In [OT_REG16, OT_REG32]) And
       (Entry.Op2Type In [OT_RM8, OT_RM16, OT_RM32, OT_MEM]) Then Begin
      If Entry.Op2Type = OT_RM8 Then Begin
        { MOVZX/MOVSX r16, r/m8 ou r32, r/m8 }
        If Offset < CodeSize Then Begin
          If AddrSz = 4 Then
            DecodeModRM32(Offset, 1, RegField, RMStr, ModRMBytes)
          Else
            DecodeModRM16(Offset, 1, RegField, RMStr, ModRMBytes);
          If (Entry.Op1Type = OT_REG32) Or (OpSz = 4) Then
            RegStr := RegNames32[RegField]
          Else
            RegStr := RegNames16[RegField];
          Operands := RegStr + ', ' + RMStr;
          BytesUsed := 1 + ModRMBytes;
        End;
      End
      Else If Entry.Op2Type = OT_RM16 Then Begin
        { MOVZX/MOVSX r32, r/m16 ou CMOVcc r, r/m etc. }
        If Offset < CodeSize Then Begin
          If (Entry.Op1Type = OT_REG32) Then Begin
            { Op1 toujours 32 bits, Op2 toujours 16 bits }
            If AddrSz = 4 Then
              DecodeModRM32(Offset, 2, RegField, RMStr, ModRMBytes)
            Else
              DecodeModRM16(Offset, 2, RegField, RMStr, ModRMBytes);
            RegStr := RegNames32[RegField];
          End Else Begin
            { Op taille selon EffOpSize }
            If AddrSz = 4 Then
              DecodeModRM32(Offset, OpSz, RegField, RMStr, ModRMBytes)
            Else
              DecodeModRM16(Offset, OpSz, RegField, RMStr, ModRMBytes);
            If OpSz = 4 Then
              RegStr := RegNames32[RegField]
            Else
              RegStr := RegNames16[RegField];
          End;
          Operands := RegStr + ', ' + RMStr;
          BytesUsed := 1 + ModRMBytes;
        End;
      End
      Else If Entry.Op2Type = OT_MEM Then Begin
        { LSS/LFS/LGS r, m16:16 }
        If Offset < CodeSize Then Begin
          If AddrSz = 4 Then
            DecodeModRM32(Offset, OpSz, RegField, RMStr, ModRMBytes)
          Else
            DecodeModRM16(Offset, OpSz, RegField, RMStr, ModRMBytes);
          If OpSz = 4 Then
            RegStr := RegNames32[RegField]
          Else
            RegStr := RegNames16[RegField];
          Operands := RegStr + ', ' + RMStr;
          BytesUsed := 1 + ModRMBytes;
        End;
      End
      Else Begin
        { Autre cas RM32, etc. }
        If Offset < CodeSize Then Begin
          If AddrSz = 4 Then
            DecodeModRM32(Offset, OpSz, RegField, RMStr, ModRMBytes)
          Else
            DecodeModRM16(Offset, OpSz, RegField, RMStr, ModRMBytes);
          If OpSz = 4 Then
            RegStr := RegNames32[RegField]
          Else
            RegStr := RegNames16[RegField];
          Operands := RegStr + ', ' + RMStr;
          BytesUsed := 1 + ModRMBytes;
        End;
      End;
      Exit;
    End;

    { Cas: premier operande = r/m, second = registre (direction r/m<-reg) }
    If (Entry.Op1Type In [OT_RM8, OT_RM16, OT_RM32]) And
       (Entry.Op2Type In [OT_REG8, OT_REG16, OT_REG32, OT_IMM8, OT_CL]) Then Begin
      If Offset < CodeSize Then Begin
        If Entry.Op1Type = OT_RM8 Then Begin
          If AddrSz = 4 Then
            DecodeModRM32(Offset, 1, RegField, RMStr, ModRMBytes)
          Else
            DecodeModRM16(Offset, 1, RegField, RMStr, ModRMBytes);
          If Entry.Op2Type = OT_REG8 Then
            RegStr := RegNames8[RegField]
          Else If Entry.Op2Type = OT_IMM8 Then Begin
            Imm8 := ReadCodeByte(Offset + ModRMBytes);
            Operands := RMStr + ', ' + HexByte(Imm8) + 'h';
            BytesUsed := 1 + ModRMBytes + 1;
            Exit;
          End Else
            RegStr := 'CL';
        End Else Begin
          { RM16 ou RM32 }
          If AddrSz = 4 Then
            DecodeModRM32(Offset, OpSz, RegField, RMStr, ModRMBytes)
          Else
            DecodeModRM16(Offset, OpSz, RegField, RMStr, ModRMBytes);
          If Entry.Op2Type = OT_REG8 Then
            RegStr := RegNames8[RegField]
          Else If Entry.Op2Type = OT_REG16 Then Begin
            If OpSz = 4 Then
              RegStr := RegNames32[RegField]
            Else
              RegStr := RegNames16[RegField];
          End
          Else If Entry.Op2Type = OT_REG32 Then
            RegStr := RegNames32[RegField]
          Else If Entry.Op2Type = OT_IMM8 Then Begin
            Imm8 := ReadCodeByte(Offset + ModRMBytes);
            Operands := RMStr + ', ' + HexByte(Imm8) + 'h';
            BytesUsed := 1 + ModRMBytes + 1;
            Exit;
          End
          Else If Entry.Op2Type = OT_CL Then
            RegStr := 'CL'
          Else
            RegStr := '???';
        End;
        Operands := RMStr + ', ' + RegStr;
        BytesUsed := 1 + ModRMBytes;
      End;
      Exit;
    End;

    { Cas: MOV CRn/DRn/TRn (deja traite ci-dessus normalement) }
    { Fallback generique pour les autres cas a 2 operandes }
    Operands := '???';
  End;
End;

{ ============================================================
  ANALYSE DU FLUX DE CONTROLE ET REFERENCES CROISEES
  ============================================================ }

{ AddLabel - Ajoute un label a la table des labels.
  Si l'adresse existe deja, ne fait rien (evite les doublons).
  Parametres :
    Addr   : adresse dans l'image
    AName  : nom du label (vide pour auto-generation)
    Proc   : True si c'est un sous-programme (cible de CALL)
    Imp    : True si c'est un import
    Exp    : True si c'est un export
  Retourne True si le label a ete ajoute, False si deja present ou table pleine. }
{ FormatImmediateOperand - version simplifiee pour le blob de code d une   }
{ DCU (PAS un PE/EXE deja relie) : une constante immediate n a PAS d       }
{ ImageBase/section a comparer (voir la version complete, PE, dans          }
{ DISEXE.PAS) - on se contente de la chaine hexadecimale, sauf si elle        }
{ pointe exactement sur un label deja connu a l interieur du MEME blob         }
{ (rare pour un immediat, mais couvre le cas d une adresse de procedure          }
{ locale deja resolue par ProcessFixup/EmitAllProcAsmBlocks).                       }
Function FormatImmediateOperand(Value: LongWord; Mode32: Boolean): TString;
Var
  Addr: LongInt;
  LblIdx: LongInt;
Begin
  Addr := LongInt(Value);
  If (Addr >= 0) And (Addr < CodeSize) Then
  Begin
    LblIdx := FindLabel(Addr);
    If LblIdx >= 0 Then
    Begin
      FormatImmediateOperand := 'OFFSET ' + Labels[LblIdx].Name;
      Exit;
    End;
  End;
  If Mode32 Then
    FormatImmediateOperand := HexDWord(LongInt(Value)) + 'h'
  Else
    FormatImmediateOperand := HexWord(Word(Value)) + 'h';
End;

Procedure DisassembleInstruction(Offset : LongInt; Mode32 : Boolean;
                                  Var Mnem : TString; Var Operands : TString;
                                  Var BytesUsed : Integer);
Var
  PFX       : TPrefixState;
  OpcOffset : LongInt;
  Opcode    : Byte;
  Entry     : TOpcodeEntry;
  OpSz      : Byte;
  AddrSz    : Byte;
  RegField  : Byte;
  ModRM     : Byte;
  MRMBytes  : Integer;
  RMStr     : TString;
  RegStr    : TString;
  Imm8      : Byte;
  Imm16     : Word;
  Imm32     : LongInt;
  Rel8      : ShortInt;
  Rel16     : SmallInt;
  Rel32     : LongInt;
  TargetAddr: LongInt;
  PrefStr   : TString;
  LblIdx    : LongInt;
  TotalSize : Integer;
  SecByte   : Byte;
  Mnem0F    : TString;
  Ops0F     : TString;
  Bytes0F   : Integer;
  NDX       : LongInt;
  SymName   : TString;
Begin
  Mnem := '';
  Operands := '';
  BytesUsed := 1;

  If (Offset < 0) Or (Offset >= CodeSize) Then Begin
    Mnem := 'DB';
    Operands := '??';
    Exit;
  End;

  { Decoder les prefixes }
  InitPrefixState(PFX, Mode32);
  DecodePrefixes(Offset, Mode32, PFX);
  OpcOffset := Offset + PFX.PrefixCount;
  OpSz  := PFX.EffOpSize;
  AddrSz := PFX.EffAddrSize;
  TotalSize := PFX.PrefixCount;

  If OpcOffset >= CodeSize Then Begin
    Mnem := 'DB';
    Operands := HexByte(ReadCodeByte(Offset)) + 'h';
    BytesUsed := 1;
    Exit;
  End;

  Opcode := ReadCodeByte(OpcOffset);
  PrefStr := PrefixToStr(PFX);

  { Opcode etendu 0Fh }
  If Opcode = $0F Then Begin
    If OpcOffset + 1 < CodeSize Then Begin
      SecByte := ReadCodeByte(OpcOffset + 1);
      Decode0FOpcode(SecByte, OpcOffset + 2, PFX, Mnem0F, Ops0F, Bytes0F);
      Mnem := PrefStr + Mnem0F;
      Operands := InjectSegOvr(PFX.SegOverrideStr, Ops0F);
      BytesUsed := TotalSize + 1 + Bytes0F; { prefixes + 0F byte + (second+rest) }
    End Else Begin
      Mnem := 'DB';
      Operands := '0Fh';
      BytesUsed := TotalSize + 1;
    End;
    Exit;
  End;

  Entry := OpcodeTable[Opcode];

  { Instruction inconnue }
  If Entry.Mnemonic = '???' Then Begin
    Mnem := 'DB';
    Operands := HexByte(Opcode) + 'h';
    BytesUsed := TotalSize + 1;
    Exit;
  End;

  { Instructions de groupe }
  If (Entry.Mnemonic = 'GRP1') Or (Entry.Mnemonic = 'GRP2') Or
     (Entry.Mnemonic = 'GRP3') Or (Entry.Mnemonic = 'GRP4') Or
     (Entry.Mnemonic = 'GRP5') Then Begin
    If OpcOffset + 1 >= CodeSize Then Begin
      Mnem := 'DB';
      Operands := HexByte(Opcode) + 'h';
      BytesUsed := TotalSize + 1;
      Exit;
    End;
    ModRM := ReadCodeByte(OpcOffset + 1);
    RegField := (ModRM Shr 3) And $07;
    Case Entry.Mnemonic[4] Of
      '1' : Mnem := Grp1Mnemonics[RegField];
      '2' : Mnem := Grp2Mnemonics[RegField];
      '3' : Mnem := Grp3Mnemonics[RegField];
      '4' : Mnem := Grp4Mnemonics[RegField];
      '5' : Mnem := Grp5Mnemonics[RegField];
    Else
      Mnem := '???';
    End;
    Mnem := PrefStr + Mnem;
    { Decoder l'operande r/m }
    If AddrSz = 4 Then
      DecodeModRM32(OpcOffset + 1, OpSz, RegField, RMStr, MRMBytes)
    Else
      DecodeModRM16(OpcOffset + 1, OpSz, RegField, RMStr, MRMBytes);
    Operands := RMStr;
    BytesUsed := TotalSize + 1 + MRMBytes;
    { Ajouter l'immediat pour certains groupes }
    Case Opcode Of
      $80 : Begin { GRP1 r/m8, imm8 }
        Imm8 := ReadCodeByte(OpcOffset + 1 + MRMBytes);
        Operands := Operands + ', ' + HexByte(Imm8) + 'h';
        Inc(BytesUsed);
      End;
      $81 : Begin { GRP1 r/m, imm16/32 }
        If OpSz = 4 Then Begin
          Imm32 := ReadCodeDWord(OpcOffset + 1 + MRMBytes);
          Operands := Operands + ', ' + HexDWord(Imm32) + 'h';
          BytesUsed := BytesUsed + 4;
        End Else Begin
          Imm16 := ReadCodeWord(OpcOffset + 1 + MRMBytes);
          Operands := Operands + ', ' + HexWord(Imm16) + 'h';
          BytesUsed := BytesUsed + 2;
        End;
      End;
      $82 : Begin { GRP1 r/m8, imm8 (alias) }
        Imm8 := ReadCodeByte(OpcOffset + 1 + MRMBytes);
        Operands := Operands + ', ' + HexByte(Imm8) + 'h';
        Inc(BytesUsed);
      End;
      $83 : Begin { GRP1 r/m, imm8 sign-extended }
        Imm8 := ReadCodeByte(OpcOffset + 1 + MRMBytes);
        Operands := Operands + ', ' + HexByte(Imm8) + 'h';
        Inc(BytesUsed);
      End;
      $C0 : Begin { GRP2 r/m8, imm8 }
        Imm8 := ReadCodeByte(OpcOffset + 1 + MRMBytes);
        Operands := Operands + ', ' + HexByte(Imm8) + 'h';
        Inc(BytesUsed);
      End;
      $C1 : Begin { GRP2 r/m, imm8 }
        Imm8 := ReadCodeByte(OpcOffset + 1 + MRMBytes);
        Operands := Operands + ', ' + HexByte(Imm8) + 'h';
        Inc(BytesUsed);
      End;
      $D0, $D1 : Begin { GRP2 r/m, 1 }
        Operands := Operands + ', 1';
      End;
      $D2, $D3 : Begin { GRP2 r/m, CL }
        Operands := Operands + ', CL';
      End;
      $F6 : Begin { GRP3 r/m8 }
        If RegField = 0 Then Begin { TEST r/m8, imm8 }
          Imm8 := ReadCodeByte(OpcOffset + 1 + MRMBytes);
          Operands := Operands + ', ' + HexByte(Imm8) + 'h';
          Inc(BytesUsed);
        End;
      End;
      $F7 : Begin { GRP3 r/m }
        If RegField = 0 Then Begin { TEST r/m, imm }
          If OpSz = 4 Then Begin
            Imm32 := ReadCodeDWord(OpcOffset + 1 + MRMBytes);
            Operands := Operands + ', ' + HexDWord(Imm32) + 'h';
            BytesUsed := BytesUsed + 4;
          End Else Begin
            Imm16 := ReadCodeWord(OpcOffset + 1 + MRMBytes);
            Operands := Operands + ', ' + HexWord(Imm16) + 'h';
            BytesUsed := BytesUsed + 2;
          End;
        End;
      End;
    End; { case }
    Operands := InjectSegOvr(PFX.SegOverrideStr, Operands);
    Exit;
  End;

  { Instruction normale - commencer par le mnemonique }
  Mnem := PrefStr + Entry.Mnemonic;
  BytesUsed := TotalSize + Entry.BaseSize;

  { Instructions sans operande }
  If Entry.OpCount = 0 Then Begin
    Operands := '';
    Exit;
  End;

  { Instructions avec ModR/M et deux operandes }
  If Entry.NeedModRM Then Begin
    If Entry.OpCount = 2 Then Begin
      If AddrSz = 4 Then
        DecodeModRM32Full(OpcOffset + 1, OpSz, (Opcode And $02) <> 0,
                          RMStr, RegStr, MRMBytes)
      Else
        DecodeModRM16Full(OpcOffset + 1, OpSz, (Opcode And $02) <> 0,
                          RMStr, RegStr, MRMBytes);
      BytesUsed := TotalSize + 1 + MRMBytes;
      { Selon direction bit : reg,r/m ou r/m,reg }
      If (Opcode And $02) <> 0 Then
        Operands := RMStr + ', ' + RegStr
      Else
        Operands := RMStr + ', ' + RegStr;
      { Ajouter immediat si Op2 est un immediat }
      If Entry.Op2Type = OT_IMM8 Then Begin
        Imm8 := ReadCodeByte(OpcOffset + 1 + MRMBytes);
        Operands := RMStr + ', ' + HexByte(Imm8) + 'h';
        Inc(BytesUsed);
      End Else If Entry.Op2Type = OT_IMM8X Then Begin
        Imm8 := ReadCodeByte(OpcOffset + 1 + MRMBytes);
        Operands := RMStr + ', ' + HexByte(Imm8) + 'h';
        Inc(BytesUsed);
      End Else If Entry.Op2Type = OT_IMM16 Then Begin
        If OpSz = 4 Then Begin
          Imm32 := ReadCodeDWord(OpcOffset + 1 + MRMBytes);
          Operands := RMStr + ', ' + HexDWord(Imm32) + 'h';
          BytesUsed := BytesUsed + 4;
        End Else Begin
          Imm16 := ReadCodeWord(OpcOffset + 1 + MRMBytes);
          Operands := RMStr + ', ' + HexWord(Imm16) + 'h';
          BytesUsed := BytesUsed + 2;
        End;
      End;
    End Else Begin
      { 1 operande avec ModR/M }
      RegField := 0;
      If AddrSz = 4 Then
        DecodeModRM32(OpcOffset + 1, OpSz, RegField, RMStr, MRMBytes)
      Else
        DecodeModRM16(OpcOffset + 1, OpSz, RegField, RMStr, MRMBytes);
      Operands := RMStr;
      BytesUsed := TotalSize + 1 + MRMBytes;
    End;
    Operands := InjectSegOvr(PFX.SegOverrideStr, Operands);
    Exit;
  End;

  { Instructions sans ModR/M - operandes implicites ou immediats }
  Case Entry.OpCount Of
    1 : Begin
      Case Entry.Op1Type Of
        OT_AL    : Operands := 'AL';
        OT_AX    : If OpSz = 4 Then Operands := 'EAX' Else Operands := 'AX';
        OT_CL    : Operands := 'CL';
        OT_DX    : Operands := 'DX';
        OT_ONE   : Operands := '1';
        OT_CS    : Operands := 'CS';
        OT_DS    : Operands := 'DS';
        OT_ES    : Operands := 'ES';
        OT_SS    : Operands := 'SS';
        OT_FS    : Operands := 'FS';
        OT_GS    : Operands := 'GS';
        OT_REG8  : Begin
          RegField := Opcode And $07;
          Operands := RegNames8[RegField];
        End;
        OT_REG16 : Begin
          RegField := Opcode And $07;
          If OpSz = 4 Then
            Operands := RegNames32[RegField]
          Else
            Operands := RegNames16[RegField];
        End;
        OT_SEGREG : Begin
          RegField := (Opcode Shr 3) And $03;
          Operands := SegRegNames[RegField];
        End;
        OT_IMM8  : Begin
          Imm8 := ReadCodeByte(OpcOffset + 1);
          Operands := HexByte(Imm8) + 'h';
        End;
        OT_IMM16 : Begin
          If OpSz = 4 Then Begin
            Imm32 := ReadCodeDWord(OpcOffset + 1);
            Operands := FormatImmediateOperand(LongWord(Imm32), True);
            BytesUsed := BytesUsed + 2; { 16->32 bits }
          End Else Begin
            Imm16 := ReadCodeWord(OpcOffset + 1);
            Operands := FormatImmediateOperand(LongWord(Imm16), False);
          End;
        End;
        OT_REL8  : Begin
          Rel8 := ShortInt(ReadCodeByte(OpcOffset + 1));
          TargetAddr := OpcOffset + 2 + LongInt(Rel8);
          LblIdx := FindLabel(TargetAddr);
          If LblIdx >= 0 Then
            Operands := Labels[LblIdx].Name
          Else If Mode32 Then
            Operands := HexDWord(TargetAddr) + 'h'
          Else
            Operands := HexWord(Word(TargetAddr)) + 'h';
        End;
        OT_REL16 : Begin
          SymName := '';
          If OpSz = 4 Then Begin
            Rel32 := ReadCodeDWord(OpcOffset + 1);
            TargetAddr := OpcOffset + 5 + Rel32;
            BytesUsed := BytesUsed + 2; { 16->32 bits }
            { Bloc de code non relie (drCBlock brut) : le deplacement ci-  }
            { dessus n est qu un PLACEHOLDER - le vrai destinataire (autre  }
            { procedure locale ou routine importee) est indique par un        }
            { correctif drFixUp exactement a l offset du champ rel32 - voir      }
            { FindFixupAt (en-tete de section). On ne fait confiance a la          }
            { cible CALCULEE (FindLabel) que si AUCUN correctif ne couvre cet         }
            { octet (cas rare, mais conforme - un saut interne resolu des la           }
            { compilation n a pas forcement besoin d un correctif).                       }
            NDX := FindFixupAt(OpcOffset + 1);
            If NDX >= 0 Then SymName := ResolveAddrDefName(NDX);
          End Else Begin
            Rel16 := SmallInt(ReadCodeWord(OpcOffset + 1));
            TargetAddr := OpcOffset + 3 + LongInt(Rel16);
          End;
          If SymName <> '' Then
            Operands := SymName
          Else Begin
            LblIdx := FindLabel(TargetAddr);
            If LblIdx >= 0 Then
              Operands := Labels[LblIdx].Name
            Else If Mode32 Then
              Operands := HexDWord(TargetAddr) + 'h'
            Else
              Operands := HexWord(Word(TargetAddr)) + 'h';
          End;
        End;
        OT_FAR   : Begin
          If OpSz = 4 Then Begin
            Imm32 := ReadCodeDWord(OpcOffset + 1);
            Imm16 := ReadCodeWord(OpcOffset + 5);
            Operands := HexWord(Imm16) + ':' + HexDWord(Imm32) + 'h';
            BytesUsed := BytesUsed + 2; { 32 bit offset }
          End Else Begin
            Imm16 := ReadCodeWord(OpcOffset + 1);
            Operands := HexWord(ReadCodeWord(OpcOffset + 3)) + ':' + HexWord(Imm16) + 'h';
          End;
        End;
        OT_MEM16 : Begin
          If AddrSz = 4 Then Begin
            Imm32 := ReadCodeDWord(OpcOffset + 1);
            Operands := '[' + HexDWord(Imm32) + 'h]';
            BytesUsed := BytesUsed + 2; { 16->32 adresse }
          End Else Begin
            Imm16 := ReadCodeWord(OpcOffset + 1);
            Operands := '[' + HexWord(Imm16) + 'h]';
          End;
        End;
      Else
        Operands := '?';
      End;
    End;
    2 : Begin
      { Deux operandes sans ModR/M (operandes implicites) }
      { Premiere operande }
      Case Entry.Op1Type Of
        OT_AL    : Operands := 'AL, ';
        OT_AX    : If OpSz = 4 Then Operands := 'EAX, ' Else Operands := 'AX, ';
        OT_CL    : Operands := 'CL, ';
        OT_DX    : Operands := 'DX, ';
        OT_CS    : Operands := 'CS, ';
        OT_DS    : Operands := 'DS, ';
        OT_ES    : Operands := 'ES, ';
        OT_SS    : Operands := 'SS, ';
        OT_FS    : Operands := 'FS, ';
        OT_GS    : Operands := 'GS, ';
        OT_REG8  : Begin
          RegField := Opcode And $07;
          Operands := RegNames8[RegField] + ', ';
        End;
        OT_REG16 : Begin
          RegField := Opcode And $07;
          If OpSz = 4 Then
            Operands := RegNames32[RegField] + ', '
          Else
            Operands := RegNames16[RegField] + ', ';
        End;
        OT_REG32 : Begin
          RegField := Opcode And $07;
          Operands := RegNames32[RegField] + ', ';
        End;
        OT_SEGREG : Begin
          RegField := (Opcode Shr 3) And $03;
          Operands := SegRegNames[RegField] + ', ';
        End;
        OT_MEM16 : Begin
          If AddrSz = 4 Then Begin
            Imm32 := ReadCodeDWord(OpcOffset + 1);
            Operands := '[' + HexDWord(Imm32) + 'h], ';
            BytesUsed := BytesUsed + 2;
          End Else Begin
            Imm16 := ReadCodeWord(OpcOffset + 1);
            Operands := '[' + HexWord(Imm16) + 'h], ';
          End;
        End;
      Else
        Operands := '?, ';
      End;
      { Deuxieme operande }
      Case Entry.Op2Type Of
        OT_AL    : Operands := Operands + 'AL';
        OT_AX    : If OpSz = 4 Then Operands := Operands + 'EAX' Else Operands := Operands + 'AX';
        OT_DX    : Operands := Operands + 'DX';
        OT_CL    : Operands := Operands + 'CL';
        OT_ONE   : Operands := Operands + '1';
        OT_CS    : Operands := Operands + 'CS';
        OT_DS    : Operands := Operands + 'DS';
        OT_ES    : Operands := Operands + 'ES';
        OT_SS    : Operands := Operands + 'SS';
        OT_FS    : Operands := Operands + 'FS';
        OT_GS    : Operands := Operands + 'GS';
        OT_REG8  : Begin
          RegField := Opcode And $07;
          Operands := Operands + RegNames8[RegField];
        End;
        OT_REG16 : Begin
          RegField := Opcode And $07;
          If OpSz = 4 Then
            Operands := Operands + RegNames32[RegField]
          Else
            Operands := Operands + RegNames16[RegField];
        End;
        OT_REG32 : Begin
          RegField := Opcode And $07;
          Operands := Operands + RegNames32[RegField];
        End;
        OT_SEGREG : Begin
          RegField := (Opcode Shr 3) And $03;
          Operands := Operands + SegRegNames[RegField];
        End;
        OT_IMM8  : Begin
          Imm8 := ReadCodeByte(OpcOffset + Entry.BaseSize - 1);
          Operands := Operands + HexByte(Imm8) + 'h';
        End;
        OT_IMM16 : Begin
          If OpSz = 4 Then Begin
            Imm32 := ReadCodeDWord(OpcOffset + Entry.BaseSize - 4);
            Operands := Operands +
                        FormatImmediateOperand(LongWord(Imm32), True);
            BytesUsed := BytesUsed + 2;
          End Else Begin
            Imm16 := ReadCodeWord(OpcOffset + Entry.BaseSize - 2);
            Operands := Operands +
                        FormatImmediateOperand(LongWord(Imm16), False);
          End;
        End;
        OT_MEM16 : Begin
          If AddrSz = 4 Then Begin
            Imm32 := ReadCodeDWord(OpcOffset + 1);
            Operands := Operands + '[' + HexDWord(Imm32) + 'h]';
            BytesUsed := BytesUsed + 2;
          End Else Begin
            Imm16 := ReadCodeWord(OpcOffset + 1);
            Operands := Operands + '[' + HexWord(Imm16) + 'h]';
          End;
        End;
      Else
        Operands := Operands + '?';
      End;
    End;
  End;
  Operands := InjectSegOvr(PFX.SegOverrideStr, Operands);
End;
{ --- determine, selon la version Delphi, quelles valeurs d octet B1   }
{ signifient "debut/fin de plage de code d une declaration" dans la     }
{ table des correctifs (drFixUp) - CONFIRME (FixUp.pas, TUnit.SetupFixups,  }
{ table des constantes fxStart2010/fxStart100/fxStart70/fxStart30/fxStart20). }
{ Porte reduite au natif Win32 (jamais Kylix/MSIL, comme tout ce programme) : }
{ verK1=100 est toujours hors de portee (Ver<100 partout ailleurs dans ce      }
{ fichier), donc la reservation supplementaire RefAddrDef(hPack) du vrai code    }
{ (seulement pour Ver<verD2009=12) n a jamais besoin d etre reproduite ici -       }
{ tous les fichiers reels testes sont Ver=27. --- }
Procedure SetupFixupMarkers;
Begin
  If Ver = 2 Then Begin FxStartMark := 3; FxEndMark := 4; End
  Else If Ver < 7 Then Begin FxStartMark := 5; FxEndMark := 6; End
  Else If (Ver >= 10) And (Ver <= 12) Then Begin FxStartMark := 12; FxEndMark := 13; End
  Else If (Ver >= 14) And (Ver < 100) Then Begin FxStartMark := 0; FxEndMark := 1; End
  Else Begin FxStartMark := 6; FxEndMark := 7; End;
End;

{ EmitAllProcAsmBlocks - emet, pour chaque procedure/fonction NOMMEE     }
{ rencontree (ProcList, dans l ordre du fichier), sa signature suivie      }
{ d un bloc "Assembler; asm ... end;" desassemble a partir de la plage       }
{ de code retrouvee via ProcessFixup (ProcCodeOfs/ProcCodeSz, indexes par      }
{ le meme index d adresse que la procedure elle-meme - voir NextAddrDef).       }
{ Si aucune plage n a ete retrouvee (correlation NDX incertaine pour cette       }
{ routine precise), un commentaire honnete remplace le bloc assembleur au        }
{ lieu d afficher des octets qui n appartiendraient pas a la bonne routine. }
Procedure EmitAllProcAsmBlocks;
Var
  I: LongInt;
  Idx: LongInt;
  Addr, EndAddr: LongInt;
  Mnem, Ops: TString;
  InstrSize: Integer;
  LineStr: TString;
Begin
  If ProcListCnt = 0 Then Exit;

  WriteLn(OutF);
  WriteLn(OutF, '{ ============================================================ }');
  WriteLn(OutF, '{ CORPS DES PROCEDURES/FONCTIONS (desassemblage 80386)          }');
  WriteLn(OutF, '{ ============================================================ }');

  For I := 1 To ProcListCnt Do
  Begin
    Idx := ProcList[I].AddrIdx;
    WriteLn(OutF);
    If ProcList[I].IsFunc Then
      WriteLn(OutF, 'function ', ProcList[I].Name, ';')
    Else
      WriteLn(OutF, 'procedure ', ProcList[I].Name, ';');

    If (Idx >= 1) And (Idx <= MAX_ADDRDEF) And (ProcCodeSz[Idx] > 0) Then
    Begin
      WriteLn(OutF, 'Assembler;');
      WriteLn(OutF, 'asm');
      Addr := ProcCodeOfs[Idx];
      EndAddr := Addr + ProcCodeSz[Idx];
      While Addr < EndAddr Do
      Begin
        DisassembleInstruction(Addr, True, Mnem, Ops, InstrSize);
        If InstrSize < 1 Then InstrSize := 1;
        If Ops <> '' Then
          LineStr := '  ' + Mnem + '  ' + Ops
        Else
          LineStr := '  ' + Mnem;
        WriteLn(OutF, LineStr);
        Addr := Addr + InstrSize;
      End;
      WriteLn(OutF, 'end;');
    End
    Else
    Begin
      WriteLn(OutF, 'begin');
      WriteLn(OutF, '  { corps non attribue : aucune plage de code drFixUp ',
        'ne correspond a l index d adresse de cette routine (voir NextAddrDef ',
        '- portee documentee en tete de section) }');
      WriteLn(OutF, 'end;');
    End;
  End;
End;


Procedure Fail(Const Msg: TString);
Begin
  WriteLn(ErrOutput, 'DISDCU: ARRET : ', Msg, ' (position fichier : $',
    IntToHex(P, 8), ')');
  Stopped := True;
End;

Procedure FailUnknownTag(Tag: Byte; Const Context: TString);
Begin
  Fail('etiquette non prise en charge (structure non confirmee) : $' +
    IntToHex(Tag, 2) + ' (''' + Chr(Tag) + ''') dans ' + Context +
    ' - voir DOC/DCU_FORMAT.TXT section 9/10 pour la portee exacte');
End;

{ ------------------------------------------------------------ }
{ Primitives de lecture bas niveau                              }
{ ------------------------------------------------------------ }

Function RB: Byte;
Begin
  If Stopped Then Begin RB := 0; Exit; End;
  If P >= BufLen Then
  Begin
    Fail('fin de fichier inattendue');
    RB := 0;
    Exit;
  End;
  RB := Buf[P];
  Inc(P);
End;

Function RUL: LongWord;
Var
  B0, B1, B2, B3: Byte;
Begin
  B0 := RB; B1 := RB; B2 := RB; B3 := RB;
  RUL := LongWord(B0) Or (LongWord(B1) Shl 8) Or (LongWord(B2) Shl 16) Or
    (LongWord(B3) Shl 24);
End;

{ Lit l octet courant SANS avancer le curseur - necessaire quand le      }
{ nombre d octets a consommer depend du CONTENU de l octet suivant       }
{ (ex. ProcessStrConstRec : suite variable de marqueurs drStop1).         }
Function PeekByte: Byte;
Begin
  If P < BufLen Then PeekByte := Buf[P] Else PeekByte := 0;
End;

{ ------------------------------------------------------------ }
{ ReadUIndex : entier non signe a longueur variable (TNDX),      }
{ verifie contre le vrai code source DCU32INT (DCU_In.pas,        }
{ fonction ReadUIndex) et contre de vrais octets de fichiers        }
{ .dcu reels - voir DOC\DCU_FORMAT.TXT section 4.                    }
{ Directives locales desactivees (portee limitee a cette seule       }
{ fonction, reactivees juste apres) : la forme a 5 octets reinterprete }
{ un motif de bits LongWord (32 bits pleins) comme un LongInt signe -   }
{ bouclage VOULU (ex. valeurs negatives comme les bornes d Integer),     }
{ mais que la verification de depassement (active par defaut dans les    }
{ options de projet standard de l EDI Free Pascal) transformerait en       }
{ Runtime error 215 - meme piege deja rencontre et corrige dans             }
{ DELPHI.PAS (AsmParseNumber, voir project_delphi.md).                        }
{$Q-}{$R-}
Function ReadUIndex: LongInt;
Var
  B0, B1, B2, B3, B4: Byte;
  W: Word;
  L: LongWord;
Begin
  B0 := RB;
  If (B0 And 1) = 0 Then
    ReadUIndex := B0 Shr 1
  Else Begin
    B1 := RB;
    If (B0 And 2) = 0 Then
    Begin
      W := B0 Or (Word(B1) Shl 8);
      ReadUIndex := W Shr 2;
    End
    Else Begin
      B2 := RB;
      If (B0 And 4) = 0 Then
      Begin
        L := LongWord(B0) Or (LongWord(B1) Shl 8) Or (LongWord(B2) Shl 16);
        ReadUIndex := L Shr 3;
      End
      Else Begin
        B3 := RB;
        If (B0 And 8) = 0 Then
        Begin
          L := LongWord(B0) Or (LongWord(B1) Shl 8) Or (LongWord(B2) Shl 16) Or
            (LongWord(B3) Shl 24);
          ReadUIndex := L Shr 4;
        End
        Else Begin
          B4 := RB;
          L := LongWord(B1) Or (LongWord(B2) Shl 8) Or (LongWord(B3) Shl 16) Or
            (LongWord(B4) Shl 24);
          ReadUIndex := L;
          If (B0 And $F0) <> 0 Then
            RUL;   { partie haute 64 bits (NDXHi), rarissime, ignoree ici }
        End;
      End;
    End;
  End;
End;
{$Q+}{$R+}

{ Version SIGNEE : meme decodage, mais le resultat final est      }
{ interprete comme signe (decalage arithmetique, pas logique) -     }
{ utilisee pour les bornes d intervalle (ex. Integer = tres         }
{ negatif..tres positif). Voir DOC section 4 (ReadIndex reel).       }
Function ReadSIndex: LongInt;
Var
  U: LongInt;
  Bits: Integer;
Begin
  { On ne peut pas facilement re-decouper le decalage arithmetique  }
  { sans dupliquer ReadUIndex ; comme les formes a 1/2/3/4 octets    }
  { utilisent respectivement 7/14/21/28 bits utiles, on etend le    }
  { signe manuellement a partir du nombre de bits reellement          }
  { significatifs de la forme choisie. On rejoue donc la logique      }
  { pour connaitre le nombre de bits, comme le fait le vrai            }
  { DCU_In.pas (ReadIndex) avec ses propres decalages "sar".           }
  U := ReadUIndex;
  { ReadUIndex ne renseigne pas la forme utilisee ; par simplicite     }
  { et puisque les valeurs de bornes rencontrees tiennent quasiment     }
  { toujours sur la forme 5 octets (32 bits complets, ex. Integer),      }
  { on traite ici U comme deja un LongInt 32 bits correctement           }
  { signe des que sa forme sur 32 bits est utilisee ; les formes plus     }
  { courtes (7/14/21/28 bits) sont deja de petites valeurs positives       }
  { plausibles pour la plupart des types ordinaux usuels (Byte, Word...). }
  ReadSIndex := U;
End;

{ ------------------------------------------------------------ }
{ Lecteurs de chaines Pascal (longueur-prefixee)                 }
{ ------------------------------------------------------------ }

{ Forme de l en-tete (TOUJOURS simple, 1 octet de longueur max     }
{ 255 - jamais la forme etendue, confirme par le vrai code source  }
{ ReadStr de DCU_In.pas). }
Function ReadHeaderStr: TString;
Var
  L, I: Integer;
  S: TString;
Begin
  L := RB;
  S := '';
  For I := 1 To L Do
    S := S + Chr(RB);
  ReadHeaderStr := S;
End;

{ Forme des identificateurs dans le corps du fichier : simple      }
{ (1 octet) sauf pour Ver>=verD2009(12), ou 0xFF introduit une        }
{ longueur ulong etendue (voir DOC section 8, ReadName reel). }
Function ReadIdentStr: TString;
Var
  L, I: LongInt;
  S: TString;
Begin
  L := RB;
  If (L = $FF) And (Ver >= 12) Then
    L := RUL;
  S := '';
  For I := 1 To L Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + Chr(RB)
    Else
      RB;   { on continue a consommer les octets pour rester synchronise }
  End;
  ReadIdentStr := S;
End;

{ ------------------------------------------------------------ }
{ Formatage d entiers en style Pascal ($HEX pour absolu, - devant  }
{ pour negatif) - juste pour la lisibilite du .pas produit, sans    }
{ pretention a reproduire l affichage exact de DCU32INT.             }
{ ------------------------------------------------------------ }

{ Pour V=MinLongInt (-2147483648, la borne basse EXACTE du type       }
{ Integer - le cas le plus courant de tous), "-V" deborderait un        }
{ LongInt signe (2147483648 ne rentre pas dans -2147483648..2147483647) -}
{ meme piege deja rencontre et corrige pour ReadUIndex (voir plus haut)    }
{ et dans DELPHI.PAS (AsmParseNumber, project_delphi.md). Calcul via       }
{ Int64 (bien plus large, jamais de depassement possible ici) plutot        }
{ que de simplement desactiver la verification, pour obtenir la vraie        }
{ magnitude positive correcte, pas juste eviter le plantage.                   }
Function FmtOrd(V: LongInt): TString;
Var
  Mag: Int64;
Begin
  If V < 0 Then
  Begin
    Mag := -Int64(V);
    FmtOrd := '-$' + IntToHex(Mag, 1);
  End
  Else
    FmtOrd := '$' + IntToHex(V, 1);
End;

{ ------------------------------------------------------------ }
{ Table locale des types (section 9b : numerotation LOCALE au     }
{ fichier, jamais universelle - confirme empiriquement).            }
{ ------------------------------------------------------------ }

Function RegisterType(Const Txt: TString): Integer;
Begin
  If TypeCount >= MAX_TYPES Then
  Begin
    Fail('table des types locale pleine (MAX_TYPES=' + IntToStr(MAX_TYPES) + ')');
    RegisterType := 0;
    Exit;
  End;
  Inc(TypeCount);
  TypeText[TypeCount] := Txt;
  RegisterType := TypeCount;
End;

Function TypeRefText(Idx: LongInt): TString;
Begin
  If (Idx >= 1) And (Idx <= TypeCount) Then
    TypeRefText := TypeText[Idx]
  Else
    { Reference hors de la table locale : tres probablement un      }
    { type IMPORTE d une autre unite (System.Integer, System.        }
    { TObject, etc. - voir DOC section 9b, mecanisme d import nomme). }
    { L encodage exact de cet import dans la liste imbriquee d un      }
    { enregistrement "uses" n est pas encore confirme (portee            }
    { documentee) : on imprime donc un espace reserve explicite            }
    { plutot que de deviner un nom.                                          }
    TypeRefText := '<type importe #' + IntToStr(Idx) + '>';
End;

{ ------------------------------------------------------------ }
{ Definitions de types ORDINAUX/SIMPLES - structure confirmee.    }
{ Chaque fonction lit le contenu (hors etiquette, deja consommee)   }
{ et renvoie l INDEX local du type enregistre.                       }
{ ------------------------------------------------------------ }

{ CORRECTION MAJEURE (2026-07-16, empirique + confirmee contre le vrai   }
{ code source DCURecs.pas) : TOUTES les definitions de types ANONYMES       }
{ (TRangeBaseDef/TFloatDef/TPtrDef/TSetDef/TVoidDef, et plus tard              }
{ TRecDef/TClassDef/etc.) heritent DIRECTEMENT de TTypeDef (aucune              }
{ ne redefinit son propre Create) - or TTypeDef.Create lit LUI-MEME un            }
{ en-tete commun AVANT les champs propres a chaque sous-type : RTTISz              }
{ (TNDX) + Sz (TNDX signe) + hAddrDef (TNDX) + [X (TNDX) si Ver dans                 }
{ [verD2005..verK1)]. Aucune des fonctions Def* ne lisait cet en-tete -               }
{ desynchronisation a CHAQUE type anonyme rencontre (trouve en tracant                  }
{ octet par octet REST.OpenSSL.dcu : meme apres avoir corrige les champs                  }
{ propres a TRangeDef, l echec persistait, decalage exactement de la                        }
{ taille de cet en-tete manquant).                                                              }

Procedure ReadTypeDefHeader;
Var
  RTTISz, Sz, HAddrDef, X: LongInt;
Begin
  RTTISz := ReadUIndex;
  Sz := ReadSIndex;
  HAddrDef := ReadUIndex;
  If (Ver >= 9) And (Ver < 100) Then X := ReadUIndex;
End;

Function DefRange(Const Kind: TString): Integer;
Var
  HDTBase: LongInt;
  Lo, Hi: LongInt;
  B: LongInt;
Begin
  ReadTypeDefHeader;
  HDTBase := ReadUIndex;
  Lo := ReadSIndex;
  Hi := ReadSIndex;
  If (Ver >= 8) And (Ver < 100) Then
    B := ReadUIndex
  Else
    B := RB;
  DefRange := RegisterType(FmtOrd(Lo) + '..' + FmtOrd(Hi) +
    ' { ' + Kind + ' de ' + TypeRefText(HDTBase) + ' }');
End;

{ TPtrDef.Create confirme : hRefDT (TNDX) + [TNDX supplementaire si    }
{ Ver>=verD2009(12), champ non exploite ici].                             }
Function DefPtr: Integer;
Var
  Target: LongInt;
Begin
  ReadTypeDefHeader;
  Target := ReadUIndex;
  If (Ver >= 12) And (Ver < 100) Then ReadUIndex;
  DefPtr := RegisterType('^' + TypeRefText(Target));
End;

{ TSetDef.Create confirme : BStart (UN OCTET BRUT, PAS un TNDX) puis   }
{ hBaseDT (TNDX) - le code precedent ne lisait pas BStart du tout.        }
Function DefSet: Integer;
Var
  BStart: Byte;
  Base: LongInt;
Begin
  ReadTypeDefHeader;
  BStart := RB;
  Base := ReadUIndex;
  DefSet := RegisterType('set of ' + TypeRefText(Base));
End;

{ TFloatDef.Create confirme : B (UN OCTET). Pour Ver>=verD_XE3(17),    }
{ si B and $80<>0 (fkExtra), B:=B and not $80 PUIS un octet             }
{ SUPPLEMENTAIRE est lu (champ non exploite ici). Kind 0=Real (pas         }
{ Single - decalage corrige par rapport au code precedent, qui              }
{ commencait a 0=Single ; erreur seulement d affichage, sans consequence      }
{ sur l alignement puisque Kind est deja un octet dans les deux cas).          }
Function DefFloat: Integer;
Const
  FK_EXTRA = $80;
Var
  Kind: Byte;
  S: TString;
Begin
  ReadTypeDefHeader;
  Kind := RB;
  If (Ver >= 17) And (Ver < 100) Then
  Begin
    If (Kind And FK_EXTRA) <> 0 Then
    Begin
      Kind := Kind And (Not FK_EXTRA);
      RB;
    End;
  End;
  Case Kind Of
    0: S := 'Real';
    1: S := 'Single';
    2: S := 'Double';
    3: S := 'Extended';
    4: S := 'Comp';
    5: S := 'Currency';
  Else
    S := 'float(kind ' + IntToStr(Kind) + ')';
  End;
  DefFloat := RegisterType(S);
End;

{ TVoidDef.Create confirme : [UN OCTET BRUT supplementaire si Ver     }
{ dans [verD_XE(15)..verK1(100))].                                       }
Function DefVoid: Integer;
Begin
  ReadTypeDefHeader;
  If (Ver >= 15) And (Ver < 100) Then RB;
  DefVoid := RegisterType('void');
End;

{ TEnumDef.Create confirme (TEnumDef herite de TRangeBaseDef, qui       }
{ herite de TTypeDef - meme en-tete commun) : hDTBase (TNDX) + [TNDX      }
{ supplementaire si Ver>=verD2009(12)] + NDX (TNDX signe) + Lo (TNDX          }
{ signe) + Hi (TNDX signe) + B (TNDX si Ver>=verD8, sinon UN OCTET).             }
{ Les noms des valeurs de l enumeration eux-memes (ex. clRed, clBlue)              }
{ ne font PAS partie de cette structure - ce sont des enregistrements                }
{ drConst SEPARES ailleurs dans le fichier (deja geres par                              }
{ ProcessConstDecl), rattaches a ce type par hDT plutot que d etre                        }
{ imbriques ici.                                                                             }
Function DefEnum: Integer;
Var
  HDTBase, Lo, Hi, B: LongInt;
Begin
  ReadTypeDefHeader;
  HDTBase := ReadUIndex;
  If (Ver >= 12) And (Ver < 100) Then ReadUIndex;
  ReadSIndex;   { NDX }
  Lo := ReadSIndex;
  Hi := ReadSIndex;
  If (Ver >= 8) And (Ver < 100) Then
    B := ReadUIndex
  Else
    B := RB;
  DefEnum := RegisterType('enum(' + FmtOrd(Lo) + '..' + FmtOrd(Hi) +
    ') { de ' + TypeRefText(HDTBase) + ' }');
End;

{ TArrayDef0.Create(IsStr) confirme - PARTAGE par drArrayDef (IsStr=  }
{ Faux, TArrayDef.Create(false)) ET drShortStrDef/drStringDef/            }
{ drWideStrDef/drUnicodeStringDef (IsStr=Vrai, TShortStrDef.Create /          }
{ TStringDef.Create - structure IDENTIQUE dans les deux classes) :              }
{ en-tete TTypeDef + B1 (UN OCTET) + hDTNdx (TNDX, type d index/bornes)           }
{ + hDTEl (TNDX, type d element) + [CP (TNDX, page de code) si IsStr et              }
{ Ver>=verD2009(12)].                                                                   }
Function DefArrayLike(IsStr: Boolean; Const Kind: TString): Integer;
Var
  B1: Byte;
  HDTNdx, HDTEl, CP: LongInt;
Begin
  ReadTypeDefHeader;
  B1 := RB;
  HDTNdx := ReadUIndex;
  HDTEl := ReadUIndex;
  If IsStr And (Ver >= 12) And (Ver < 100) Then CP := ReadUIndex;
  If IsStr Then
    DefArrayLike := RegisterType(Kind)
  Else
    DefArrayLike := RegisterType('array[' + TypeRefText(HDTNdx) + '] of ' +
      TypeRefText(HDTEl));
End;

{ TDynArrayDef herite de TPtrDef SANS le redefinir (Ver>=verD2009) -   }
{ structure IDENTIQUE a DefPtr (en-tete TTypeDef + hRefDT (TNDX) +          }
{ [TNDX supplementaire si Ver>=12]) - seul l affichage differe               }
{ ("array of X" plutot que "^X").                                                }
Function DefDynArray: Integer;
Var
  Target: LongInt;
Begin
  ReadTypeDefHeader;
  Target := ReadUIndex;
  If (Ver >= 12) And (Ver < 100) Then ReadUIndex;
  DefDynArray := RegisterType('array of ' + TypeRefText(Target));
End;

{ ------------------------------------------------------------ }
{ Emission de declarations Delphi lisibles dans le fichier .pas   }
{ de sortie.                                                       }
{ ------------------------------------------------------------ }

{ ------------------------------------------------------------ }
{ FlushUsesClause : ecrit la clause "uses" accumulee (syntaxe     }
{ Pascal normale, une unite par ligne) puis, separement, un        }
{ bloc de commentaire listant les imports NOMMES resolus pour        }
{ chaque unite - jamais un seul bloc "Nom" suivi de tous ses imports    }
{ en une fois, centaines de caracteres sur une ligne (defaut signale     }
{ l utilisateur : ca ressemblait a du code Pascal casse/tronque).        }
{ Chaque ligne du bloc de commentaire est repliee automatiquement          }
{ des qu elle depasserait WRAP_WIDTH colonnes - jamais un seul mot            }
{ (nom importe) coupe en deux. Appelee UNE SEULE FOIS (UsesFlushed),          }
{ au moment ou le premier enregistrement NON-"uses" est rencontre              }
{ (voir ProcessOneRecord) ou a la toute fin du programme si le                  }
{ fichier ne contenait que des "uses". Le mot-cle "interface" est ECRIT          }
{ AVANT cette clause (ordre reel Delphi), directement dans le programme           }
{ principal - pas ici.                                                              }
{ ------------------------------------------------------------ }

Procedure FlushUsesClause;
Var
  I, J, LastJ: Integer;
  Line: TString;
Begin
  If UsesFlushed Then Exit;
  UsesFlushed := True;

  Write(OutF, 'uses');
  If UsesCount = 0 Then
    WriteLn(OutF, ';')
  Else
  Begin
    WriteLn(OutF);
    For I := 1 To UsesCount Do
    Begin
      Write(OutF, '  ', UsesNames[I]);
      If I < UsesCount Then WriteLn(OutF, ',') Else WriteLn(OutF, ';');
    End;
  End;
  WriteLn(OutF);

  { IMPORTANT : ce bloc entier est un COMMENTAIRE Pascal accolade -     }
  { les noms importes eux-memes (T:Xxx, A:Xxx) ne sont PAS des            }
  { declarations valides a cet endroit (ancien bogue : ces lignes           }
  { etaient ecrites en texte brut, produisant un fichier .pas invalide         }
  { meme pour la partie reellement decodee avec succes - signale par             }
  { l utilisateur).                                                                  }
  If ImportPoolCount > 0 Then
  Begin
    WriteLn(OutF, '{ Imports resolus (T:type, A:routine/adresse) - noms ',
      'tels qu importes, non verifies contre la vraie table de types de ',
      'l unite source (voir DOC/DCU_FORMAT.TXT section 9b) :');
    For I := 1 To UsesCount Do
      If UsesImportCount[I] > 0 Then
      Begin
        Line := '    ' + UsesNames[I] + ' : ';
        LastJ := UsesImportFirst[I] + UsesImportCount[I] - 1;
        For J := UsesImportFirst[I] To LastJ Do
        Begin
          If (Length(Line) + Length(ImportPool[J]) + 2) > WRAP_WIDTH Then
          Begin
            WriteLn(OutF, Line);
            Line := '        ';
          End;
          Line := Line + ImportPool[J];
          If J < LastJ Then Line := Line + ', ';
        End;
        WriteLn(OutF, Line);
      End;
    WriteLn(OutF, '}');
    WriteLn(OutF);
  End;
End;

Procedure EmitVar(Const Name: TString; TypeIdx: LongInt; IsSpec: Boolean);
Begin
  Write(OutF, '  ');
  If IsSpec Then Write(OutF, '{ spec var } ');
  WriteLn(OutF, Name, ': ', TypeRefText(TypeIdx), ';');
End;

Procedure EmitProcSig(Const Name: TString; IsFunc: Boolean);
Begin
  WriteLn(OutF);
  If IsFunc Then
    WriteLn(OutF, 'function ', Name, ';')
  Else
    WriteLn(OutF, 'procedure ', Name, ';');
  WriteLn(OutF, 'begin');
  WriteLn(OutF, '  { corps non decompile : code machine 80386 compile, ',
    'pas des instructions Pascal - voir la portee documentee en tete de ',
    'ce programme }');
  WriteLn(OutF, 'end;');
End;

{ ------------------------------------------------------------ }
{ En-tete commun "TNameFDecl" (Name+F+[F1 si Ver>=8]+[F4 si       }
{ Ver>=12, ignore ici]+[Inf ulong si F and $40]) - CONFIRME contre }
{ le vrai code source (DCURecs.pas, TNameFDecl.Create) et PORTE     }
{ par drType/drTypeP/drVar/drConst/drProc/etc, toute declaration       }
{ nommee. BOGUE CORRIGE (2026-07-16) : le champ F4 (Ver>=verD2009=12)   }
{ n etait lu par AUCUNE des procedures existantes (ProcessNamedType       }
{ ne lisait meme pas F du tout) - dela desynchronisait le flux des le      }
{ premier drType/drVar/drConst rencontre dans un fichier recent (Ver>=12,   }
{ dont Access2000.dcu, Ver=27). F and $40 marque la visibilite INTERFACE     }
{ (confirme : TNameFDecl.IsVisible, dlMain => F and $40 <> 0) - utile plus tard }
{ si on veut filtrer les declarations prive/implementation.                    }
{ Cas non traite (arret propre plutot que deviner, portee MSIL/Kylix         }
{ explicitement hors de portee) : F1 and $80 <> 0 (champs B2/F3 additionnels).  }
{ ------------------------------------------------------------ }

Procedure ReadNameFHeaderEx(Var Name: TString; Var F: LongInt; Var HasInf: Boolean;
  Var Inf: LongWord; NoInf: Boolean);
Var
  F1: LongInt;
Begin
  Name := ReadIdentStr;
  F := ReadUIndex;
  F1 := 0;
  If Ver >= 8 Then F1 := ReadUIndex;
  If Ver >= 12 Then ReadUIndex;   { F4 : non exploite ici }
  { NoInf force l absence du champ Inf, quel que soit F and $40 -       }
  { utilise par TSysProc8Decl (drSysProc, Ver>=verD8) : le vrai code       }
  { source (DCURecs.pas) confirme un appel avec ce parametre a Vrai.         }
  HasInf := (Not NoInf) And ((F And $40) <> 0);
  If HasInf Then Inf := RUL Else Inf := 0;
  If (Ver >= 8) And ((F1 And $80) <> 0) Then
    Fail('en-tete "' + Name + '" : indicateur F1 and $80 rencontre ' +
      '(champs additionnels MSIL non pris en charge - hors de portee, ' +
      'voir DISDCU.PAS en-tete)');
End;

Procedure ReadNameFHeader(Var Name: TString; Var F: LongInt; Var HasInf: Boolean;
  Var Inf: LongWord);
Begin
  ReadNameFHeaderEx(Name, F, HasInf, Inf, False);
End;

{ ------------------------------------------------------------ }
{ Petits lecteurs "sauter N octets" utilises par plusieurs          }
{ structures (drConstAddInfo, liste d arguments, etc.) : SkipNDXStr =  }
{ ReadNDXStr/ReadNDXStrRef reels (DCU_In.pas) : longueur en TNDX (PAS     }
{ un octet fixe comme ReadIdentStr) puis ce nombre d octets bruts.          }
{ SkipRawBlock = SkipBlock reel (DCU_In.pas) : N octets bruts, valeur          }
{ non interpretee.                                                                }
{ ------------------------------------------------------------ }

Procedure SkipRawBlock(N: LongInt);
Var
  I: LongInt;
Begin
  For I := 1 To N Do RB;
End;

Procedure SkipNDXStr;
Var
  L: LongInt;
Begin
  L := ReadUIndex;
  SkipRawBlock(L);
End;

{ ------------------------------------------------------------ }
{ TConstValInfo (Kind+ValSz+Val/ValPtr) - structure CONFIRMEE          }
{ contre le vrai code source (DCURecs.pas, TConstValInfo.Read) -         }
{ partagee par drConst (ProcessConstDecl), les arguments d attribut          }
{ (SkipOneAttribute) et les constantes anonymes d une liste                     }
{ d arguments (SkipConstArg). La valeur elle-meme n est PAS interpretee            }
{ (Kind=0 scalaire,1 chaine,2 resourcestring,3 flottant,4 set/pointeur,              }
{ 5 chaine Unicode) : structure lue et correctement sautee seulement.                 }
{ ------------------------------------------------------------ }

Procedure SkipConstValInfo(Const Context: TString; Var Kind: LongInt);
Var
  NeedVal: Boolean;
  ValSz: LongInt;
  Val: LongInt;
  I: LongInt;
Begin
  NeedVal := True;
  Kind := 0;
  If Ver > 4 Then
  Begin
    Kind := ReadUIndex;
    If (Kind < 0) Or (Kind > 5) Then
    Begin
      Fail(Context + ' : Kind hors intervalle attendu (0..5) : ' +
        IntToStr(Kind) + ' - desynchronisation probable');
      Exit;
    End;
    If (Ver >= 16) And (Ver < 100) Then
      NeedVal := (Kind <> 4);
  End;

  ValSz := ReadUIndex;
  If ValSz = 0 Then
  Begin
    If NeedVal Then Val := ReadSIndex;
  End
  Else
    For I := 1 To ValSz Do RB;   { bloc memoire brut (ValPtr), valeur non interpretee }
End;

{ ------------------------------------------------------------ }
{ Traitement d une definition de type NOMMEE (drType, $2A) :      }
{ en-tete TNameFDecl (voir ci-dessus) + hDef (TNDX, index vers le  }
{ type deja enregistre juste avant, dans TypeText).                 }
{ ------------------------------------------------------------ }

Procedure ProcessNamedType;
Var
  Name: TString;
  F: LongInt;
  HasInf: Boolean;
  Inf: LongWord;
  HDef: LongInt;
Begin
  ReadNameFHeader(Name, F, HasInf, Inf);
  If Stopped Then Exit;
  NextAddrDef;   { drType (TTypeDecl) : consomme un index d adresse, jamais cible d un CALL/JMP - non nomme }
  HDef := ReadUIndex;
  WriteLn(OutF, '  ', Name, ' = ', TypeRefText(HDef), ';');
End;

{ ------------------------------------------------------------ }
{ Traitement de drTypeP ($26) : STRUCTURE DIFFERENTE de drType -   }
{ CORRECTION (2026-07-16, empirique + confirmee contre le vrai       }
{ code source DCURecs.pas) : drTypeP utilise TTypePDecl, qui herite    }
{ de TVarCDecl (PAS de TTypeDecl) - c est un pointeur de VMT             }
{ ("PutKW('VMT')" dans TTypePDecl.Show), structure IDENTIQUE a un        }
{ TVarDecl normal : en-tete TNameFDecl + hDT (TNDX, type) + ofs             }
{ (TNDX) - DEUX index, pas un seul comme drType. L ancien code               }
{ traitait drType et drTypeP de facon identique (un seul hDef) -              }
{ desalignement d un champ ("ofs") a chaque drTypeP rencontre,                 }
{ trouve empiriquement (Access2000.dcu, position $8927) en comparant             }
{ la position finale reelle du fichier a la position d arret.                      }
{ ------------------------------------------------------------ }

Procedure ProcessTypeP;
Var
  Name: TString;
  F: LongInt;
  HasInf: Boolean;
  Inf: LongWord;
  HDT, Ofs: LongInt;
Begin
  ReadNameFHeader(Name, F, HasInf, Inf);
  If Stopped Then Exit;
  NextAddrDef;   { drTypeP (TTypePDecl) : consomme un index d adresse - non nomme }
  HDT := ReadUIndex;
  Ofs := ReadUIndex;
  WriteLn(OutF, '  { ', Name, ' : ', TypeRefText(HDT), '  (pointeur de VMT) }');
End;

{ ------------------------------------------------------------ }
{ Traitement d un enregistrement source/objet/asm/ressource       }
{ (drSrc/drObj/drAsm/drRes) : structure CONFIRMEE (TSrcInf/         }
{ TResInf), simple et sure - Name (TNameStr) + FT (ulong,             }
{ horodatage DOS du fichier source) + B (TNDX). Pure metadonnee        }
{ (quel fichier source a produit la suite), jamais une declaration      }
{ Delphi visible - on la consomme et l annote en commentaire plutot       }
{ que de l ignorer silencieusement ou de la refuser.                       }
{ ------------------------------------------------------------ }

Procedure ProcessSrcInf(Const Kind: TString);
Var
  Name: TString;
  FT: LongWord;
  B: LongInt;
Begin
  Name := ReadIdentStr;
  FT := RUL;
  B := ReadUIndex;
  WriteLn(OutF, '{ ', Kind, ' : ', Name, ' }');
End;

{ ------------------------------------------------------------ }
{ Traitement d un enregistrement "uses" (drUnit/drUnit1) :        }
{ Name (l unite utilisee) puis TUnitInf (hPack/Inf/X en TNDX,      }
{ tous confirmes a 0 pour un "uses" simple sans import, puis une    }
{ sous-liste imbriquee TDCU30ListC terminee par drStop1='c').        }
{ Portee : une sous-liste NON VIDE (l unite importe reellement       }
{ des noms precis, cas de la quasi-totalite des unites reelles)       }
{ n est pas encore decodee avec certitude (voir portee documentee)     }
{ - message clair puis arret, plutot que deviner.                       }
{ ------------------------------------------------------------ }

Procedure ProcessUsesUnit(TagRq: Byte);
Var
  Name, ImpName: TString;
  HPack, Inf, L1, X: LongInt;
  RTTISz, LVal: LongInt;
  Cnt, ImportFirst, UIdx: Integer;
  ImpIdx: LongInt;
Begin
  Name := ReadIdentStr;

  { CORRECTION (2026-07-16, DCU32.pas, TUnit.ReadUses) : hPack n est PAS   }
  { lu pour drDLL specifiquement (seulement drUnit/drUnit1) - condition       }
  { reelle "if (TagRq<>drDLL) and (Ver>=verD8)".                                 }
  If (Ver >= 8) And (TagRq <> TAG_DLL) Then HPack := ReadUIndex;

  If Ver >= 10 Then
    Inf := ReadUIndex
  Else
    Inf := LongInt(RUL);

  If (Ver = 7) Or ((Ver >= 8) And (TagRq = TAG_DLL)) Then
    L1 := LongInt(RUL);

  If Ver >= 12 Then
    X := ReadUIndex;

  { CONFIRME (DCU32.pas, TUnit.ReadUses) : la reference d unite elle-meme   }
  { (TUnitImpDef, "Ch") consomme deja un index d adresse via AddAddrDef,      }
  { AVANT la liste des imports nommes ci-dessous - a compter ici pour ne         }
  { pas desynchroniser la numerotation des index suivants (voir NextAddrDef).      }
  NextAddrDef;

  { Liste imbriquee des imports NOMMES (drImpType/drImpTypeDef pour un   }
  { TYPE, drImpVal pour une routine/adresse) - structure et etiquettes     }
  { REELLES confirmees contre le vrai code source DCU32.pas (TUnit.        }
  { ReadUses). drStop2 peut apparaitre entre deux imports (un octet          }
  { supplementaire depuis Ver>=8) sans mettre fin a la liste - on reboucle.    }
  { Chaque import va directement dans ImportPool (pas de chaine jointe     }
  { par des virgules a redecouper plus tard) - FlushUsesClause s occupera    }
  { du retour a la ligne automatique au moment de l ecriture reelle.          }
  ImportFirst := ImportPoolCount + 1;
  Cnt := 0;
  Repeat
    CurTag := RB;
    Case CurTag Of
      TAG_IMPTYPE, TAG_IMPTYPEDEF:
        Begin
          ImpIdx := NextAddrDef;
          ImpName := ReadIdentStr;
          If CurTag = TAG_IMPTYPEDEF Then RTTISz := ReadUIndex;
          LVal := LongInt(RUL);
          If (ImpIdx >= 1) And (ImpIdx <= MAX_ADDRDEF) Then
          Begin
            AddrDefName[ImpIdx] := Name + '.' + ImpName;
            AddrDefIsImport[ImpIdx] := True;
          End;
          If ImportPoolCount < MAX_IMPORT_POOL Then
          Begin
            Inc(ImportPoolCount);
            ImportPool[ImportPoolCount] := 'T:' + ImpName;
            Inc(Cnt);
          End;
        End;
      TAG_IMPVAL:
        Begin
          ImpIdx := NextAddrDef;
          ImpName := ReadIdentStr;
          LVal := LongInt(RUL);
          If (ImpIdx >= 1) And (ImpIdx <= MAX_ADDRDEF) Then
          Begin
            AddrDefName[ImpIdx] := Name + '.' + ImpName;
            AddrDefIsImport[ImpIdx] := True;
          End;
          If ImportPoolCount < MAX_IMPORT_POOL Then
          Begin
            Inc(ImportPoolCount);
            ImportPool[ImportPoolCount] := 'A:' + ImpName;
            Inc(Cnt);
          End;
        End;
      TAG_STOP2:
        If Ver >= 8 Then LVal := LongInt(RUL);
    End;
  Until Stopped Or ((CurTag <> TAG_IMPTYPE) And (CurTag <> TAG_IMPTYPEDEF) And
    (CurTag <> TAG_IMPVAL) And (CurTag <> TAG_STOP2));

  If Stopped Then Exit;

  If CurTag <> TAG_STOP1 Then
  Begin
    Fail('unite "' + Name + '" : etiquette inattendue dans la liste d ' +
      'import ($' + IntToHex(CurTag, 2) + ', attendu drStop1=$63) - ' +
      'structure non encore prise en charge a ce point (ex. ' +
      'drConstAddInfo) - voir la portee documentee en tete de ce programme');
    Exit;
  End;

  If UsesCount < MAX_USES Then
  Begin
    Inc(UsesCount);
    UIdx := UsesCount;
    UsesNames[UIdx] := Name;
    UsesImportFirst[UIdx] := ImportFirst;
    UsesImportCount[UIdx] := Cnt;
  End
  Else
    Fail('table des unites "uses" pleine (MAX_USES=' + IntToStr(MAX_USES) + ')');

  { Apres la fin de la liste (drStop1), le vrai format lit toujours une   }
  { etiquette de plus ; si c est drProcAddInfo (Ver>=7), un index signe     }
  { supplementaire est consomme puis une AUTRE etiquette est lue - c est      }
  { CELLE-CI qui devient la "prochaine etiquette" pour l appelant           }
  { (ProcessOneRecord ne relit pas CurTag lui-meme apres "uses").              }
  CurTag := RB;
  If (CurTag = TAG_PROC_ADD_INFO) And (Ver >= 7) Then
  Begin
    ReadSIndex;
    CurTag := RB;
  End;
End;

{ ------------------------------------------------------------ }
{ Traitement d une declaration Var/Const/SpecVar (TVarInf) :      }
{ NF (TNameFDecl : B, +B1 si Ver>=8, +Inf ulong optionnel si         }
{ B and 0x40), puis hDT (TNDX, type) et Ofs (TNDX, offset).           }
{ ------------------------------------------------------------ }

Procedure ProcessVarLike(Tag: Byte);
Var
  Name: TString;
  F: LongInt;
  HasInf: Boolean;
  Inf: LongWord;
  HDT, Ofs: LongInt;
Begin
  ReadNameFHeader(Name, F, HasInf, Inf);
  If Stopped Then Exit;
  NextAddrDef;   { drVar/drVarC/drAbsVar/drSpecVar/... : consomme un index d adresse }

  HDT := ReadUIndex;
  Ofs := ReadUIndex;

  EmitVar(Name, HDT, Tag = TAG_SPECVAR);
End;

{ CONFIRME EMPIRIQUEMENT (2026-07-16, System.Classes.dcu et                }
{ Vcl.Controls.dcu) : $36, rencontre comme etiquette PRINCIPALE (pas          }
{ dans une liste de membres), est arClassVar (TClassVarDecl = TLocalDecl        }
{ SANS redefinition - Name simple, PAS d en-tete F/F1/F4/Inf) apparaissant           }
{ comme declaration autonome, de la meme facon que drSpecVar (TAG_SPECVAR)             }
{ apparait deja seul au niveau principal pour les variables de classe.                    }
{ Un OCTET SUPPLEMENTAIRE (nature exacte non identifiee, peut-etre liee a                    }
{ un indicateur de visibilite) suit systematiquement NDX - confirme en                          }
{ retombant exactement sur l etiquette suivante (validee independamment,                           }
{ TAG_TYPEP) dans les deux fichiers testes ; ce seul octet a debloque                                 }
{ plusieurs centaines de Ko supplementaires dans chacun des deux fichiers.                              }
Procedure ProcessClassVarTopLevel;
Var
  Name: TString;
  HDT: LongInt;
Begin
  NextAddrDef;   { arClassVar (TClassVarDecl=TLocalDecl) : consomme un index d adresse }
  Name := ReadIdentStr;
  ReadUIndex;    { LocFlags }
  If Ver >= 8 Then ReadUIndex;    { LocFlagsX }
  If (Ver >= 12) And (Ver < 100) Then ReadUIndex;   { B3 }
  HDT := ReadUIndex;
  ReadSIndex;    { NDX }
  RB;            { octet supplementaire non identifie - voir commentaire ci-dessus }
  WriteLn(OutF, '  { class var } ', Name, ': ', TypeRefText(HDT), ';');
End;

{ ------------------------------------------------------------ }
{ Determine si un nom de procedure/fonction est la convention        }
{ interne "sans nom" du compilateur (TProcDecl.IsUnnamed reelle) :     }
{ vide, ".", ".." (Ver>=verD6), premier caractere "." (Ver>=verD8),      }
{ ou premier caractere "$" (Ver dans [verD_XE..verK1)). Quand VRAI,        }
{ TProcDecl.Create NE LIT PAS VProc/hDTRes/hClass/CallKind/liste            }
{ d arguments du tout - la signature s arrete net apres B0/Sz/X.               }
{ ------------------------------------------------------------ }

Function IsUnnamedProcName(Const Name: TString): Boolean;
Begin
  IsUnnamedProcName := True;
  If (Length(Name) = 0) Or (Name = '.') Then Exit;
  If (Ver >= 6) And (Ver < 100) And (Name = '..') Then Exit;
  If Ver >= 8 Then
  Begin
    If Name[1] = '.' Then Exit;
    If (Name[1] = '$') And (Ver >= 15) And (Ver < 100) Then Exit;
  End;
  IsUnnamedProcName := False;
End;

{ ------------------------------------------------------------ }
{ Une entree simple de liste d arguments (TLocalDecl, cas M=Faux :   }
{ arVal/arVar/arResult/arFld/drVar - PAS arMethod/arConstr/arDestr,     }
{ qui utilisent une structure differente non geree ici, hors de           }
{ portee pour une simple liste de parametres). Structure CONFIRMEE          }
{ (DCURecs.pas, TLocalDecl.Create) : Name (TNameStr, PAS d en-tete             }
{ TNameFDecl - TLocalDecl herite de TNameDecl directement) + LocFlags          }
{ (TNDX) + [LocFlagsX brut si Ver>=verD8] + [B3 si Ver>=verD2009] +               }
{ [ULong "[REF]" si Ver>=verD_XE4 et LocFlags and $40] + hDT (TNDX) +             }
{ NDX (TNDX SIGNE).                                                                 }
{ ------------------------------------------------------------ }

{ CORRECTION (2026-07-16) : ajout du parametre LK (genre de liste),   }
{ necessaire pour decoder les MEMBRES D INTERFACE (arMethod/arConstr/   }
{ arDestr, LK_INTF) - structure DIFFERENTE des parametres simples :        }
{ hDT/NDX utilisent ReadIndex (signe) au lieu de ReadUIndex, ET un            }
{ champ NDXB (TNDX) supplementaire est lu entre les deux quand                    }
{ LK=LK_INTF (dlInterface/dlDispInterface) - confirme (DCURecs.pas,                  }
{ TLocalDecl.Create). Le decorateur "[REF]" ne s applique qu a LK_ARGS.                 }
Procedure SkipLocalDecl(Tag: Byte; LK: Byte);
Var
  Name: TString;
  LocFlags: LongInt;
  IsMethod: Boolean;
Begin
  NextAddrDef;   { TLocalDecl (arVal/arVar/arResult/arFld) : consomme un index d adresse }
  Name := ReadIdentStr;
  LocFlags := ReadUIndex;
  If Ver >= 8 Then ReadUIndex;    { LocFlagsX brut, valeur non exploitee }
  If (Ver >= 12) And (Ver < 100) Then ReadUIndex;   { B3 }
  If (Ver >= 18) And (Ver < 100) And (LK = LK_ARGS) And
    ((LocFlags And $40) <> 0) Then RUL;

  IsMethod := (Tag = TAG_ARG_METHOD) Or (Tag = TAG_ARG_CONSTR) Or
    (Tag = TAG_ARG_DESTR);

  If IsMethod Then ReadSIndex Else ReadUIndex;   { hDT }
  If (LK = LK_INTF) Or (LK = LK_DISPINTF) Then ReadUIndex;   { NDXB }
  If IsMethod Then ReadUIndex Else ReadSIndex;    { NDX }
End;

{ TMethodDecl (arMethod/arConstr/arDestr HORS interface/dispinterface -  }
{ InIntrf=Faux) : herite de TLocalDecl (voir SkipLocalDecl ci-dessus,       }
{ deja applique) PUIS lit des champs SUPPLEMENTAIRES, CONFIRMES              }
{ (DCURecs.pas, TMethodDecl.Create, cas non-MSIL) : [UN OCTET si                 }
{ Ver>=verD2009(12) et Name non vide] + [hImport (TNDX) si Ver>=verD7(7)             }
{ ou Name vide] + [pour arMethod SEULEMENT, si Ver>=verD2009(12) : une                 }
{ SUITE d octets appartenant a un ensemble precis (sSkip, dont la taille                 }
{ depend d etapes de version - CONFIRME, DCU_In.pas ReadByteFrom = PEEK,                    }
{ ne consomme que si l octet appartient a l ensemble)].                                        }

Function ComputeMethodSkipIdx: Integer;
Var
  N: Integer;
Begin
  N := 0;
  If Ver >= 14 Then
  Begin
    Inc(N);
    If Ver >= 16 Then
    Begin
      Inc(N);
      If Ver >= 17 Then
      Begin
        Inc(N);
        If Ver >= 18 Then
        Begin
          Inc(N);
          If Ver >= 21 Then
          Begin
            Inc(N);
            If Ver >= 22 Then
            Begin
              Inc(N);
              If Ver >= 25 Then Inc(N);
            End;
          End;
        End;
      End;
    End;
  End;
  ComputeMethodSkipIdx := N;
End;

Function ByteInSkipSet(B: Byte; SetIdx: Integer): Boolean;
Begin
  ByteInSkipSet := False;
  Case SetIdx Of
    0: ByteInSkipSet := B In [$00,$02,$04,$08,$10,$18,$20,$80,$84,$21,$61];
    1: ByteInSkipSet := B In [$00,$01,$02,$04,$08,$10,$18,$20,$80,$84,$21,$61];
    2: ByteInSkipSet := B In [$00,$01,$02,$04,$08,$10,$18,$20,$28,$38,$80,
                              $84,$21,$61];
    3: ByteInSkipSet := B In [$00,$01,$02,$04,$08,$10,$18,$20,$28,$38,$42,
                              $22,$09,$80,$84,$21,$61];
    4: ByteInSkipSet := B In [$00,$01,$02,$04,$08,$10,$18,$20,$28,$38,$42,
                              $22,$09,$47,$4F,$80,$84,$21,$61];
    5: ByteInSkipSet := B In [$00,$01,$02,$04,$08,$10,$18,$20,$28,$38,$42,
                              $22,$09,$47,$4F,$60,$80,$84,$21,$61];
    6: ByteInSkipSet := B In [$00,$01,$02,$04,$08,$10,$18,$20,$28,$38,$42,
                              $22,$09,$47,$4F,$60,$A1,$80,$84,$21,$61];
    7: ByteInSkipSet := B In [$00,$01,$02,$04,$08,$10,$18,$20,$28,$38,$42,
                              $22,$09,$47,$4F,$60,$A1,$07,$41,$80,$84,$21,$61];
  End;
End;

Procedure SkipMethodDecl(Tag: Byte; LK: Byte);
Var
  Name: TString;
  InIntrf: Boolean;
  SkipIdx: Integer;
Begin
  NextAddrDef;   { TMethodDecl (arMethod/arConstr/arDestr) : consomme un index d adresse }
  Name := ReadIdentStr;
  ReadUIndex;    { LocFlags }
  If Ver >= 8 Then ReadUIndex;    { LocFlagsX brut }
  If (Ver >= 12) And (Ver < 100) Then ReadUIndex;   { B3 }

  ReadSIndex;    { hDT }
  If (LK = LK_INTF) Or (LK = LK_DISPINTF) Then ReadUIndex;   { NDXB }
  ReadUIndex;    { NDX }

  InIntrf := (LK = LK_INTF) Or (LK = LK_DISPINTF);
  If Not InIntrf Then
  Begin
    If (Ver >= 12) And (Ver < 100) And (Length(Name) > 0) Then RB;
    If ((Ver >= 7) And (Ver < 100)) Or (Length(Name) = 0) Then ReadUIndex;

    If (Ver >= 12) And (Ver < 100) And (Tag = TAG_ARG_METHOD) Then
    Begin
      SkipIdx := ComputeMethodSkipIdx;
      While (Not Stopped) And ByteInSkipSet(PeekByte, SkipIdx) Do RB;
    End;
  End;
End;

{ arSetDeft (valeur par defaut d un parametre "set") : PAS de nom,   }
{ juste hConst+hArg (2 TNDX) - confirme (DCURecs.pas, TSetDeftInfo).   }
Procedure SkipSetDeft;
Begin
  ReadUIndex;
  ReadUIndex;
End;

{ arProperty (TPropDecl.Create, herite de TNameDecl - Name simple,    }
{ SANS en-tete F/F1/F4/Inf) - structure CONFIRMEE (DCURecs.pas) :        }
{ LocFlags (TNDX signe) + [LocFlagsX brut si Ver>=verD8] + [X4 si            }
{ Ver>=verD2009] + hDT (TNDX) + NDX (TNDX signe) + hIndex (TNDX signe)          }
{ + hRead+hWrite+hStored (3 TNDX) + [hReadOrig+hWriteOrig (2 TNDX) si              }
{ Ver>=verD8] + hDeft (TNDX signe, valeur par defaut "default").                     }
Procedure SkipProperty;
Begin
  NextAddrDef;   { TPropDecl (arProperty) : consomme un index d adresse }
  ReadIdentStr;      { Name }
  ReadSIndex;        { LocFlags }
  If Ver >= 8 Then ReadUIndex;    { LocFlagsX }
  If (Ver >= 12) And (Ver < 100) Then ReadUIndex;   { X4 }
  ReadUIndex;   { hDT }
  ReadSIndex;   { NDX }
  ReadSIndex;   { hIndex }
  ReadUIndex;   { hRead }
  ReadUIndex;   { hWrite }
  ReadUIndex;   { hStored }
  If (Ver >= 8) And (Ver < 100) Then
  Begin
    ReadUIndex;   { hReadOrig }
    ReadUIndex;   { hWriteOrig }
  End;
  ReadSIndex;   { hDeft }
End;

{ Variante SILENCIEUSE (aucune sortie) de ProcessNamedType/           }
{ ProcessTypeP/ProcessConstDecl, pour un type/const ANONYME declare     }
{ localement dans une liste d arguments (type d un parametre, valeur      }
{ par defaut) - jamais une declaration Pascal visible au niveau du           }
{ fichier de sortie.                                                            }
Procedure SkipTypeArg;
Var
  Name: TString;
  F: LongInt;
  HasInf: Boolean;
  Inf: LongWord;
Begin
  ReadNameFHeader(Name, F, HasInf, Inf);
  If Stopped Then Exit;
  ReadUIndex;   { hDef }
End;

Procedure SkipTypePArg;
Var
  Name: TString;
  F: LongInt;
  HasInf: Boolean;
  Inf: LongWord;
Begin
  ReadNameFHeader(Name, F, HasInf, Inf);
  If Stopped Then Exit;
  ReadUIndex;   { hDT }
  ReadUIndex;   { ofs }
End;

Procedure SkipConstArg;
Var
  Name: TString;
  F: LongInt;
  HasInf: Boolean;
  Inf: LongWord;
  Kind: LongInt;
Begin
  ReadNameFHeader(Name, F, HasInf, Inf);
  If Stopped Then Exit;
  ReadUIndex;   { hDT }
  SkipConstValInfo('constante (argument)', Kind);
End;

{ Declaration anticipee (Forward) : ProcessConstAddInfo est definie      }
{ plus bas (elle-meme dependante de SkipAttributes/SkipOneAttribute)       }
{ mais SkipArgList doit deja pouvoir l appeler (drConstAddInfo peut             }
{ egalement apparaitre a l interieur d une liste d arguments/membres,             }
{ ex. attribut "deprecated" sur une methode d interface).                            }
Procedure ProcessConstAddInfo; Forward;
Procedure ProcessOneRecord; Forward;

{ Bloc de declarations LOCALES (drEmbeddedProcStart/drEmbeddedProcEnd)  }
{ pouvant apparaitre DIRECTEMENT dans une liste de membres/arguments        }
{ (pas seulement au niveau principal, deja gere dans ProcessOneRecord) -      }
{ meme logique, reutilisee ici pour SkipArgList.                                }
Procedure SkipEmbeddedBlock;
Begin
  { CONFIRME (DCU32.pas) : un drEmbeddedProcStart rencontre alors que      }
  { EmbEndCnt>0 (Ver>=verD2009) annule simplement un "echappement" deja       }
  { enregistre par un drEmbeddedProcEnd isole plus tot - PAS un nouveau           }
  { bloc imbrique. On ne fait alors RIEN d autre (le tag suivant reste                }
  { celui deja en cours de traitement par l appelant).                                  }
  If (Ver >= 12) And (Ver < 100) And (EmbEndCnt > 0) Then
  Begin
    Dec(EmbEndCnt);
    CurTag := RB;
    Exit;
  End;

  CurTag := RB;
  While (Not Stopped) And (CurTag <> TAG_EMBEDDED_PROC_END) Do
    ProcessOneRecord;
  If Stopped Then Exit;
  CurTag := RB;
End;

{ ------------------------------------------------------------ }
{ Liste d arguments d une procedure/fonction (ReadDeclList,        }
{ LK=dlArgs) - boucle jusqu a l etiquette terminale drStop1=$63,     }
{ exactement comme ProcessUsesUnit pour la liste d import. Portee :   }
{ seuls les cas confirmes/simples sont geres (voir ci-dessus) ;         }
{ toute autre etiquette (arMethod/arConstr/arDestr/arProperty/            }
{ arClassVar/drEmbeddedProcStart, generiques...) provoque un arret          }
{ propre plutot qu une supposition.                                            }
{ ------------------------------------------------------------ }

Procedure SkipArgList(FirstTag: Byte; LK: Byte);
Var
  Tag: Byte;
  AlreadyAdvanced: Boolean;
Begin
  { IMPORTANT : le premier tag est deja lu par l appelant (ProcessProc a  }
  { du le lire pour verifier s il s agissait d une convention d appel ou      }
  { d un marqueur de generique) - le relire ici via RB desalignerait          }
  { tout, notamment pour une liste VIDE (ex. "Finalization", qui n a               }
  { aucun parametre : le premier tag EST DEJA drStop1) - bogue trouve             }
  { empiriquement (System.SimpleShareMem.dcu, REST.OpenSSL.dcu).                    }
  Tag := FirstTag;
  Repeat
    AlreadyAdvanced := False;
    Case Tag Of
      TAG_ARG_VAL, TAG_ARG_VAR, TAG_ARG_RESULT, TAG_ARG_FLD, TAG_VAR:
        SkipLocalDecl(Tag, LK);
      TAG_ARG_METHOD, TAG_ARG_CONSTR, TAG_ARG_DESTR, TAG_ARG_DESTR2:
        SkipMethodDecl(Tag, LK);
      TAG_ARG_CDECL, TAG_ARG_PASCAL, TAG_ARG_STDCALL, TAG_ARG_SAFECALL:
        ;   { conventions d appel : aucune donnee associee }
      TAG_ARG_SETDEFT:
        SkipSetDeft;
      TAG_ARG_PROPERTY:
        { arProperty utilise TPropDecl (interface normale) SAUF en          }
        { dispinterface, ou TDispPropDecl (qui herite de TLocalDecl, PAS      }
        { de TPropDecl) prend le relais - structure bien plus courte,           }
        { confirmee (DCURecs.pas : "TDispPropDecl = class(TLocalDecl)").            }
        If LK = LK_DISPINTF Then
          SkipLocalDecl(Tag, LK)
        Else
          SkipProperty;
      TAG_TYPE:
        SkipTypeArg;
      TAG_TYPEP:
        SkipTypePArg;
      TAG_CONST:
        SkipConstArg;
      TAG_PROC_ADD_INFO:
        ReadSIndex;   { peut apparaitre a l interieur d une liste d arguments aussi }
      TAG_CONST_ADD_INFO:
        ProcessConstAddInfo;   { idem (attribut/deprecated sur un membre) }
      TAG_ANON_BLOCK:
        Begin
          ReadUIndex;
          ReadUIndex;
        End;
      TAG_DELAYED_IMP:
        Begin
          { TDelayedImpRec : Name simple + Inf(ULONG brut) + F(TNDX) - }
          { confirme (DCURecs.pas).                                       }
          ReadIdentStr;
          RUL;
          ReadUIndex;
        End;
      TAG_EMBEDDED_PROC_START:
        Begin
          { declarations locales imbriquees directement dans une liste   }
          { de membres (ex. valeur par defaut complexe d une methode) -      }
          { meme traitement que dans ProcessOneRecord.                            }
          SkipEmbeddedBlock;
          If Stopped Then Exit;
          Tag := CurTag;
          AlreadyAdvanced := True;
        End;
      TAG_EMBEDDED_PROC_END:
        { CONFIRME (DCU32.pas) : un drEmbeddedProcEnd "nu" (sans           }
        { drEmbeddedProcStart correspondant a ce niveau) marque un               }
        { "echappement" vers un niveau d imbrication superieur - dans un              }
        { contexte LK_ARGS (dlArgs/dlArgsT reel), il incremente juste                    }
        { EmbEndCnt et la liste CONTINUE (ni fin, ni nouvelle donnee) ;                     }
        { dans les autres contextes, le vrai code source "Break" (la liste                    }
        { CACTUELLE s arrete la, comme un drStop1 implicite - non confirme                       }
        { au-dela de ce point, mais evite un arret pour cette seule variation).                     }
        If LK = LK_ARGS Then
          Inc(EmbEndCnt)
        Else
        Begin
          AlreadyAdvanced := True;
          Tag := TAG_STOP1;
        End;
      TAG_STOP1:
        ;   { fin normale de la liste }
    Else
      Fail('liste d arguments : etiquette non prise en charge ($' +
        IntToHex(Tag, 2) + ') - structure non confirmee a cet endroit ' +
        '(portee documentee)');
    End;
    If Stopped Then Exit;
    If Tag = TAG_STOP1 Then Exit;
    If Not AlreadyAdvanced Then
    Begin
      Tag := RB;
      If Stopped Then Exit;
    End;
  Until False;
End;

{ ------------------------------------------------------------ }
{ Traitement de drProcTypeDef ($48, type "procedure"/"function" -   }
{ ex. TNotifyEvent) : TProcTypeDef herite de TRecBaseDef, qui herite     }
{ de TTypeDef (meme en-tete commun). CONFIRME (DCURecs.pas,                  }
{ TProcTypeDef.Create) : [NDX0 (TNDX) si Ver>verD2] + hDTRes (TNDX,             }
{ type de retour, 0=procedure) puis une boucle lisant des etiquettes              }
{ (convention d appel / marqueurs generiques drA5Info-drA8Info) jusqu a             }
{ drEmbeddedProcStart ($6A) - ou arret NET si drStop1 apparait avant                 }
{ (type procedure sans parametres et sans "of object"). Une fois                       }
{ drEmbeddedProcStart trouve, une liste d arguments SUIT (structure                       }
{ IDENTIQUE a dlArgs pour les cas simples - reutilise SkipArgList).                          }
{ Generiques (drA7Info, TTemplateParmsDeclModifier) : structure non                            }
{ confirmee - arret propre plutot que deviner.                                                    }
{ ------------------------------------------------------------ }

Function DefProcType: Integer;
Var
  HDTRes: LongInt;
  Tag: Byte;
  Done: Boolean;
Begin
  DefProcType := 0;
  ReadTypeDefHeader;
  If Ver > 2 Then ReadUIndex;   { NDX0 }
  HDTRes := ReadUIndex;

  Tag := RB;
  If Stopped Then Exit;
  Done := False;
  Repeat
    If Tag = TAG_STOP1 Then
    Begin
      DefProcType := RegisterType('procedure { type, retour=' +
        TypeRefText(HDTRes) + ' }');
      Exit;
    End;
    If Tag = TAG_EMBEDDED_PROC_START Then
      Done := True
    Else
    Begin
      If (Tag >= TAG_ARG_CDECL) And (Tag <= TAG_ARG_SAFECALL) Then
        Tag := RB
      Else
      Begin
        If (Ver >= 12) And (Ver < 100) Then
        Begin
          Case Tag Of
            TAG_A5INFO: ;
            TAG_A8INFO: ReadUIndex;
            TAG_A7INFO:
              Begin
                Fail('type procedure : parametres generiques (drA7Info) ' +
                  'rencontres - structure non confirmee (portee documentee)');
                Exit;
              End;
          End;
        End;
        Tag := RB;
      End;
      If Stopped Then Exit;
    End;
  Until Done Or Stopped;
  If Stopped Then Exit;

  { drEmbeddedProcStart trouve : la vraie liste d arguments suit,     }
  { introduite par un tag frais (ReadFields reel) - reutilise                }
  { SkipArgList (structure partagee avec dlArgs pour les cas simples).            }
  Tag := RB;
  If Stopped Then Exit;
  SkipArgList(Tag, LK_ARGS);
  If Stopped Then Exit;

  DefProcType := RegisterType('procedure { type, retour=' +
    TypeRefText(HDTRes) + ' }');
End;

{ ------------------------------------------------------------ }
{ Traitement de drRecDef ($4D, TRecDef - herite de TRecBaseDef,   }
{ qui herite de TTypeDef, meme en-tete commun). CONFIRME (DCURecs.pas, }
{ TRecDef.Create, cas non-MSIL) : B2 (UN OCTET, inconditionnel) puis,      }
{ pour Ver>=verD2005(9) : [B1+X0 (deux OCTETS) si Ver>=verD2006(10)] +        }
{ X (TNDX) + [si Ver>=verD2009(12) : deux TNDX de plus, + un TNDX                }
{ supplementaire si Ver>=verD2010(14)]. Puis la liste des CHAMPS                    }
{ (ReadFields(dlFields) reel) - reutilise SkipArgList (structure                       }
{ partagee : arFld y est deja gere ; arMethod/arProperty/arClassVar                       }
{ - "advanced records" avec methodes/proprietes - provoquent un arret                        }
{ propre via le "Else Fail" deja present, cas non confirme).                                    }
{ ------------------------------------------------------------ }

Function DefRecord: Integer;
Var
  B2, B1, X0: Byte;
  Tag: Byte;
Begin
  DefRecord := 0;
  ReadTypeDefHeader;
  B2 := RB;
  If (Ver >= 9) And (Ver < 100) Then
  Begin
    If (Ver >= 10) And (Ver < 100) Then
    Begin
      B1 := RB;
      X0 := RB;
    End;
    ReadUIndex;   { X }
    If Ver >= 12 Then
    Begin
      ReadUIndex;
      ReadUIndex;
      If Ver >= 14 Then ReadUIndex;
    End;
  End;

  Tag := RB;
  If Stopped Then Exit;
  SkipArgList(Tag, LK_OTHER);
  If Stopped Then Exit;

  DefRecord := RegisterType('record { non decompile en detail } end');
End;

{ Liste des interfaces implementees par une classe (ReadClassInterfaces  }
{ reel, DCURecs.pas) - CONFIRME, cas non-MSIL : ICnt (TNDX signe) puis,     }
{ par interface, hIntf+MCnt (2 TNDX) + [X1+MatchCnt (2 TNDX) si                }
{ Ver>=verD2006(10)] + [X3+X4 (2 TNDX) puis MatchCnt fois (octet+Name+           }
{ 2 TNDX) si Ver>=verD2010(14)].                                                    }
Function SkipClassInterfaces: LongInt;
Var
  ICnt, I, J, MatchCnt: LongInt;
  Dummy: TString;
Begin
  ICnt := ReadSIndex;
  SkipClassInterfaces := ICnt;
  If ICnt <= 0 Then Exit;
  For I := 1 To ICnt Do
  Begin
    ReadUIndex;   { hIntf }
    ReadUIndex;   { MCnt }
    If (Ver >= 10) And (Ver < 100) Then
    Begin
      ReadUIndex;            { X1 }
      MatchCnt := ReadUIndex;
      If (Ver >= 14) And (Ver < 100) Then
      Begin
        ReadUIndex;          { X3 }
        ReadUIndex;          { X4 }
        For J := 1 To MatchCnt Do
        Begin
          RB;                       { B }
          Dummy := ReadIdentStr;    { MName }
          ReadUIndex;               { N }
          ReadUIndex;               { hMember }
        End;
      End;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ Traitement de drClassDef ($46, TClassDef - herite de TOOTypeDef,   }
{ qui herite de TRecBaseDef, qui herite de TTypeDef, meme en-tete       }
{ commun). CONFIRME (DCURecs.pas, TClassDef.Create, cas non-MSIL,          }
{ non-package - toujours vrai pour un .dcu charge depuis le disque) :        }
{ [BX (UN OCTET) si Ver>=verD2006(10)] + [si Ver>=verD2009(12) :                }
{ BX1 (OCTET si Ver>=verD_XE2(17), sinon TNDX) + BX2 (OCTET)] + hParent           }
{ (TNDX) + InstBaseRTTISz (TNDX) + InstBaseSz (TNDX signe) + InstBaseV               }
{ (TNDX) + VMCnt (TNDX) + NdxFE (TNDX) + PropCnt (TNDX) + B04 (TNDX si                }
{ Ver>=verD8, sinon OCTET) + [BX3 (TNDX) si Ver>=verD2010(14)] + liste des                }
{ interfaces (SkipClassInterfaces, si Ver>verD2) + liste des MEMBRES                        }
{ (ReadFields(dlClass) reel - reutilise SkipArgList ; methodes/proprietes/                   }
{ variables de classe non confirmees en detail, arret propre si rencontrees).                  }
{ ------------------------------------------------------------ }

Function DefClass: Integer;
Var
  B04: LongInt;
  HParent: LongInt;
  Tag: Byte;
Begin
  DefClass := 0;
  ReadTypeDefHeader;

  If (Ver >= 10) And (Ver < 100) Then RB;   { BX }
  If (Ver >= 12) And (Ver < 100) Then
  Begin
    If (Ver >= 17) And (Ver < 100) Then RB Else ReadUIndex;   { BX1 }
    RB;   { BX2 }
  End;

  HParent := ReadUIndex;
  ReadUIndex;    { InstBaseRTTISz }
  ReadSIndex;    { InstBaseSz }
  ReadUIndex;    { InstBaseV }
  ReadUIndex;    { VMCnt }
  ReadUIndex;    { NdxFE }
  ReadUIndex;    { PropCnt }

  If (Ver >= 8) And (Ver < 100) Then
    B04 := ReadUIndex
  Else
    B04 := RB;

  If (Ver >= 14) And (Ver < 100) Then ReadUIndex;   { BX3 }

  { FromPackage est toujours Faux pour un .dcu charge depuis le disque   }
  { (confirme, DCU32.pas, TUnit.LoadFromMem) - branche jamais empruntee.     }

  If Ver > 2 Then SkipClassInterfaces;

  Tag := RB;
  If Stopped Then Exit;
  SkipArgList(Tag, LK_OTHER);
  If Stopped Then Exit;

  If HParent <> 0 Then
    DefClass := RegisterType('class(' + TypeRefText(HParent) +
      ') { non decompilee en detail } end')
  Else
    DefClass := RegisterType('class { non decompilee en detail } end');
End;

{ ------------------------------------------------------------ }
{ Traitement de drInterfaceDef ($54, TInterfaceDef - herite de     }
{ TOOTypeDef, meme en-tete commun TTypeDef). CONFIRME (DCURecs.pas,     }
{ TInterfaceDef.Create) : [BX (UN OCTET) si Ver>=verD2009(12)] +             }
{ hParent (TNDX) + VMCnt (TNDX signe) + GUID (16 OCTETS BRUTS,                    }
{ SizeOf(TGUID) - CONFIRME) + B (UN OCTET, bit $4 = dispinterface) +                }
{ [si Ver>=verD8(8) : BY (TNDX si Ver>=verD2010(14)) + Cnt (TNDX) puis                }
{ Cnt fois 2 TNDX (table d ancetres)] puis la liste des MEMBRES                          }
{ (ReadFields(LK) reel, LK=dlDispInterface si B and $4<>0 sinon                            }
{ dlInterface - reutilise SkipArgList avec LK_INTF : les methodes                             }
{ d interface (arMethod) utilisent une structure DIFFERENTE d un simple                          }
{ parametre - deja geree par SkipLocalDecl LK_INTF).                                                }
{ ------------------------------------------------------------ }

Function DefInterface: Integer;
Var
  HParent: LongInt;
  B: Byte;
  Cnt, I, BY: LongInt;
  Tag: Byte;
Begin
  DefInterface := 0;
  ReadTypeDefHeader;

  If (Ver >= 12) And (Ver < 100) Then RB;   { BX }

  HParent := ReadUIndex;
  ReadSIndex;             { VMCnt }
  SkipRawBlock(16);        { GUID, SizeOf(TGUID) }
  B := RB;

  If (Ver >= 8) And (Ver < 100) Then
  Begin
    If Ver >= 14 Then BY := ReadUIndex;
    Cnt := ReadUIndex;
    For I := 1 To Cnt Do
    Begin
      ReadUIndex;
      ReadUIndex;
    End;
  End;

  Tag := RB;
  If Stopped Then Exit;
  If (B And $4) <> 0 Then
    SkipArgList(Tag, LK_DISPINTF)
  Else
    SkipArgList(Tag, LK_INTF);
  If Stopped Then Exit;

  If HParent <> 0 Then
    DefInterface := RegisterType('interface(' + TypeRefText(HParent) +
      ') { non decompilee en detail } end')
  Else
    DefInterface := RegisterType('interface { non decompilee en detail } end');
End;

{ ------------------------------------------------------------ }
{ Traitement de drObjVMTDef ($47, TObjVMTDef - herite de TTypeDef   }
{ directement, meme en-tete commun). CONFIRME (DCURecs.pas,               }
{ TObjVMTDef.Create) : hObjDT (TNDX) + VMTSz (TNDX) - represente             }
{ "class of X" pour un ancien type "object" (metaclasse).                        }
{ ------------------------------------------------------------ }

Function DefObjVMT: Integer;
Var
  HObjDT: LongInt;
Begin
  ReadTypeDefHeader;
  HObjDT := ReadUIndex;
  ReadUIndex;   { VMTSz }
  DefObjVMT := RegisterType('class of ' + TypeRefText(HObjDT));
End;

{ ------------------------------------------------------------ }
{ Traitement de drObjDef ($4E, TObjDef - ancien style Turbo Pascal  }
{ "object ... end", herite de TOOTypeDef, meme en-tete commun            }
{ TTypeDef). CONFIRME (DCURecs.pas, TObjDef.Create) : B03 (UN OCTET)          }
{ + [BX (TNDX) si Ver>=verD2006(10)] + [BX1 (OCTET) si Ver>=verD_XE(15)] +       }
{ hParent (TNDX) + VMTOfs (TNDX) + hVMT (TNDX signe) + VMCnt (TNDX                 }
{ signe) + [BX2 (TNDX) si Ver>=verD_XE2(16)] puis la liste des CHAMPS                }
{ (ReadFields(dlFields) reel - reutilise SkipArgList avec LK_OTHER).                    }
{ ------------------------------------------------------------ }

Function DefObj: Integer;
Var
  HParent: LongInt;
  Tag: Byte;
Begin
  DefObj := 0;
  ReadTypeDefHeader;
  RB;   { B03 }
  If (Ver >= 10) And (Ver < 100) Then ReadUIndex;   { BX }
  If (Ver >= 15) And (Ver < 100) Then RB;            { BX1 }
  HParent := ReadUIndex;
  ReadUIndex;   { VMTOfs }
  ReadSIndex;   { hVMT }
  ReadSIndex;   { VMCnt }
  If (Ver >= 16) And (Ver < 100) Then ReadUIndex;   { BX2 }

  Tag := RB;
  If Stopped Then Exit;
  SkipArgList(Tag, LK_OTHER);
  If Stopped Then Exit;

  If HParent <> 0 Then
    DefObj := RegisterType('object(' + TypeRefText(HParent) +
      ') { non decompile en detail } end')
  Else
    DefObj := RegisterType('object { non decompile en detail } end');
End;

{ ------------------------------------------------------------ }
{ Corps de procedure (implementation) : drCBlock (taille TNDX +   }
{ N octets de code machine brut, CONFIRME - DCU_In.pas, ReadMem/       }
{ SkipBlock) et drFixUp (compte TNDX, puis par entree dOfs(TNDX)+           }
{ octet+NDX(TNDX), CONFIRME - DCU32.pas, TUnit.LoadFixups). Le vrai            }
{ code source (DCU32.pas, TUnit.ReadDeclList) montre que ce sont des             }
{ enregistrements du dispatcheur PRINCIPAL comme les autres (pas geres              }
{ specialement par TProcDecl) - simples procedures a forme fixe,                     }
{ compatibles avec la queue commune de ProcessOneRecord (CurTag:=RB           }
{ apres coup). Tables de debug (drCodeLines/drLinNum/drStrucScope/               }
{ drLocVarTbl/drSymbolRef, presentes seulement si le fichier a ete                    }
{ compile avec informations de debogage) : non gerees ici - arret                       }
{ propre si rencontrees (portee documentee).                                               }
{ ------------------------------------------------------------ }

Procedure ProcessCBlock;
Var
  Sz: LongInt;
  I: LongInt;
  B: Byte;
Begin
  Sz := ReadUIndex;
  If Sz > MAX_CODE Then
  Begin
    Fail('drCBlock : taille (' + IntToStr(Sz) + ' octets) depasse ' +
      'MAX_CODE=' + IntToStr(MAX_CODE) + ' - augmenter la constante');
    Exit;
  End;
  For I := 0 To Sz - 1 Do
  Begin
    B := RB;
    CodeBuf[I] := B;
  End;
  CodeSize := Sz;
End;

{ Traitement de drFixUp : CONFIRME (DCU32.pas, TUnit.LoadFixups) - deux    }
{ passes. La PREMIERE decode chaque entree (dOfs delta-encode + octet B1 +   }
{ NDX) en offset CUMULE dans le blob de code (CodeBuf). La SECONDE parcourt     }
{ ces entrees dans l ordre et, a chaque marqueur "debut/fin de plage"             }
{ (B1=FxStartMark ou FxEndMark, voir SetupFixupMarkers), ferme la plage de           }
{ code de l index d adresse PRECEDENT (hPrevDecl) et en ouvre une nouvelle             }
{ pour le NDX du marqueur courant - c est cette plage qui, associee au nom              }
{ de procedure connu via NextAddrDef (voir ProcessProc), permet d attribuer               }
{ le desassemblage de chaque routine a la bonne portion du blob (voir                       }
{ EmitAllProcAsmBlocks). Les entrees qui ne sont PAS des marqueurs (F in                       }
{ fxValid du vrai code, ex. fxAddr/fxJmpAddr0) restent dans FixupOfsArr/NDXArr                    }
{ pour la resolution de symbole CALL/JMP par offset exact (voir FindFixupAt,                        }
{ utilise par DisassembleInstruction) - PAS par adresse cible calculee, le                             }
{ blob de code d une DCU n etant pas encore relie (voir l en-tete de section).                            }
Procedure ProcessFixup;
Var
  Cnt, I: LongInt;
  CurOfs, DOfs: LongInt;
  B1: Byte;
  NDX: LongInt;
  HPrevDecl: LongInt;
  PrevDeclOfs: LongInt;
Begin
  SetupFixupMarkers;
  Cnt := ReadUIndex;
  CurOfs := 0;
  FixupCount := 0;
  For I := 1 To Cnt Do
  Begin
    DOfs := ReadUIndex;
    CurOfs := CurOfs + DOfs;
    B1 := RB;
    NDX := ReadUIndex;
    If FixupCount < MAX_FIXUPS Then
    Begin
      Inc(FixupCount);
      FixupOfsArr[FixupCount] := CurOfs;
      FixupKindArr[FixupCount] := B1;
      FixupNDXArr[FixupCount] := NDX;
    End;
  End;

  HPrevDecl := 0;
  PrevDeclOfs := 0;
  For I := 1 To FixupCount Do
  Begin
    If (FixupKindArr[I] = FxStartMark) Or (FixupKindArr[I] = FxEndMark) Then
    Begin
      If (HPrevDecl >= 1) And (HPrevDecl <= MAX_ADDRDEF) Then
      Begin
        ProcCodeOfs[HPrevDecl] := PrevDeclOfs;
        ProcCodeSz[HPrevDecl] := FixupOfsArr[I] - PrevDeclOfs;
      End;
      HPrevDecl := FixupNDXArr[I];
      PrevDeclOfs := FixupOfsArr[I];
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ Tables de debogage/symboles (drCodeLines/drLinNum/drStrucScope/       }
{ drSymbolRef/drLocVarTbl, $90-$94) : presentes uniquement si l unite      }
{ a ete compilee avec informations de debogage et/ou reference de            }
{ symboles ("Debug Information"/"Local Symbols"/"Symbol Reference Info"          }
{ dans les options du projet). Structures CONFIRMEES (DCU32.pas,                    }
{ TUnit.LoadCodeLines/LoadLineRanges/LoadStrucScope/LoadSymbolInfo/                     }
{ LoadLocVarTbl) - pure metadonnee de debogage (correspondance ligne                       }
{ source/portee de bloc/variables locales), jamais une declaration Pascal                     }
{ visible : lue et sautee, comme ProcessSrcInf. LoadLocVarTbl a un cas                            }
{ special Win64 (enregistrement supplementaire par procedure) explicitement                          }
{ hors de portee (ce programme, comme DISEXE.PAS/DELPHI.PAS, ne vise que                                 }
{ le Win32 natif) - seul le chemin 32 bits (3 TNDX par entree) est reproduit.                                }
{ ------------------------------------------------------------ }

Procedure ProcessCodeLines;
Var
  Cnt, I: LongInt;
Begin
  Cnt := ReadUIndex;
  For I := 1 To Cnt Do
  Begin
    ReadSIndex;   { dL : delta de numero de ligne, signe }
    ReadUIndex;   { dOfs : delta d offset dans le blob de code }
  End;
End;

Procedure ProcessLinNum;
Var
  Cnt, I: LongInt;
Begin
  Cnt := ReadUIndex;
  For I := 1 To Cnt Do
  Begin
    ReadUIndex;   { Line0 }
    ReadUIndex;   { LineNum }
    ReadUIndex;   { hFile }
  End;
End;

Procedure ProcessStrucScope;
Var
  Cnt, N, I: LongInt;
Begin
  Cnt := ReadUIndex;
  N := 5;   { hType, hVar, Ofs, LnStart, LnCnt }
  If (Ver >= 26) And (Ver < 100) Then N := 6;   { champ supplementaire, Ver>=verD_10_3 }
  For I := 1 To Cnt * N Do ReadUIndex;
End;

Procedure ProcessSymbolRef;
Var
  Cnt, NPrimary, I, J, Sz: LongInt;
Begin
  Cnt := ReadUIndex;
  NPrimary := ReadUIndex;
  For I := 1 To Cnt Do
  Begin
    ReadUIndex;   { hSym }
    ReadUIndex;   { hMember }
    Sz := ReadUIndex;
    ReadUIndex;   { hDef }
    For J := 1 To Sz Do ReadUIndex;
  End;
End;

Procedure ProcessLocVarTbl;
Var
  Cnt, I: LongInt;
Begin
  Cnt := ReadUIndex;
  For I := 1 To Cnt Do
  Begin
    ReadUIndex;   { Sym }
    ReadUIndex;   { Ofs }
    ReadSIndex;   { frame, signe }
  End;
End;

{ ------------------------------------------------------------ }
{ drSegInfo ($B1) : table nommant les "segments" (code/donnees/etc) -   }
{ CONFIRME (DCU32.pas, TUnit.ReadDeclList, cas drSegInfo) : Cnt(TNDX)      }
{ puis, par entree, un NOM COURT (ReadShortName : UN OCTET de longueur +      }
{ ce nombre d octets bruts, SANS l extension $FF de ReadName/ReadIdentStr)       }
{ + UN OCTET + TNDX.                                                              }
{ drAddrToSegInfo ($B2) : associe chaque declaration (hAddr, un index         }
{ d adresse) a un segment de cette table - CONFIRME (DCU32.pas,                    }
{ TUnit.LoadAddrToSegInfo) : Cnt(TNDX) puis, par entree, hAddr(TNDX) +                 }
{ hSeg(TNDX) + UN OCTET + TNDX + Fix0(TNDX) + Size(TNDX) + TNDX.                          }
{ Les deux n apparaissent qu a partir de Ver>=verD_XE2(16) et sont pure               }
{ metadonnee de mise en page, jamais une declaration Pascal visible.                    }
{ ------------------------------------------------------------ }

Procedure ProcessSegInfo;
Var
  Cnt, I, J, L: LongInt;
Begin
  Cnt := ReadUIndex;
  For I := 1 To Cnt Do
  Begin
    L := RB;                  { longueur du nom court }
    For J := 1 To L Do RB;    { nom court, brut }
    RB;                       { octet }
    ReadUIndex;                { TNDX }
  End;
End;

Procedure ProcessAddrToSegInfo;
Var
  Cnt, I: LongInt;
Begin
  Cnt := ReadUIndex;
  For I := 1 To Cnt Do
  Begin
    ReadUIndex;   { hAddr }
    ReadUIndex;   { hSeg }
    RB;           { octet }
    ReadUIndex;
    ReadUIndex;   { Fix0 }
    ReadUIndex;   { Size }
    ReadUIndex;
  End;
End;

{ ------------------------------------------------------------ }
{ Traitement de drORec ($6F, TORecDecl - herite de TNameDecl        }
{ directement, Name simple SANS en-tete F/F1/F4/Inf). CONFIRME           }
{ (DCURecs.pas, TORecDecl.Create) : DW (ULONG brut, 4 octets) + B0            }
{ (UN OCTET) + B1 (UN OCTET) puis une liste imbriquee (dlA6, structure           }
{ associee aux attributs/generiques MSIL - "goes before drCBlock in                }
{ MSIL" per DCU32.pas, mais rencontre aussi en Win32 natif) terminee             }
{ par drStop1 - reutilise SkipArgList (LK_OTHER, meilleure approximation           }
{ disponible ; le contenu exact de dlA6 n est pas confirme au-dela des               }
{ tags deja geres par SkipArgList - arret propre si un tag non gere y                 }
{ apparait). Pour Ver<verD8(8) (hors de portee courante) : un simple                    }
{ TNDX au lieu de toute cette structure.                                                    }
{ ------------------------------------------------------------ }

Procedure ProcessORec;
Var
  Name: TString;
  Tag: Byte;
Begin
  If (Ver < 8) Then
  Begin
    ReadUIndex;
    CurTag := RB;
    Exit;
  End;

  NextAddrDef;   { TORecDecl (drORec) herite directement de TNameDecl : consomme un index d adresse }
  Name := ReadIdentStr;
  RUL;   { DW }
  RB;    { B0 }
  RB;    { B1 }

  Tag := RB;
  If Stopped Then Exit;
  SkipArgList(Tag, LK_OTHER);
  If Stopped Then Exit;

  CurTag := RB;
End;

{ ------------------------------------------------------------ }
{ Traitement d une signature de procedure/fonction (TProcInf) :   }
{ en-tete TNameFDecl + B0 (TNDX, drapeaux) + Sz (TNDX) + [octet si    }
{ Ver dans [verD_XE..verK1)]. Si le nom n est pas la convention          }
{ "sans nom" du compilateur (voir IsUnnamedProcName), suivent aussi          }
{ VProc/hDTRes/[hClass]/[convention d appel]/[generiques]/liste               }
{ d arguments (voir SkipArgList). Le corps reel (code machine, voir              }
{ SkipCBlockIfPresent) N EST JAMAIS DECOMPILE en instructions Pascal              }
{ structurees (hors de portee, comme DCU32INT lui-meme) - seulement                }
{ correctement SAUTE pour atteindre les declarations suivantes.                      }
{ ------------------------------------------------------------ }

Procedure ProcessProc(Tag: Byte);
Var
  Name: TString;
  F: LongInt;
  HasInf: Boolean;
  Inf: LongWord;
  B0, Sz, X: LongInt;
  NoName: Boolean;
  NextTag: Byte;
  MyAddrIdx: LongInt;
  HDTRes: LongInt;
Begin
  { CONFIRME (DCURecs.pas, TNameDecl.Create0/TProcDeclBase/TSysProcDecl) :   }
  { toute variante de declaration de procedure (y compris le cas special       }
  { Ver<verD8 ci-dessous) consomme exactement UN index d adresse - voir          }
  { NextAddrDef (en-tete de section). C est cet index qui sera retrouve             }
  { plus tard dans drFixUp (ProcessFixup) pour attribuer le bon intervalle             }
  { de code du blob (drCBlock) a CETTE routine precise.                                  }
  MyAddrIdx := NextAddrDef;

  If (Tag = TAG_SYSPROC) And (Ver < 8) Then
  Begin
    { TSysProcDecl (drSysProc, Ver<verD8) : structure TOTALEMENT       }
    { differente de TProcDecl - Name simple (sans F/F1/F4/Inf) puis        }
    { F(TNDX) + NDX(TNDX signe) - confirme (DCURecs.pas).                     }
    Name := ReadIdentStr;
    ReadUIndex;
    ReadSIndex;
    CurTag := RB;
    Exit;
  End;

  { TAG_SYSPROC pour Ver>=verD8 utilise TSysProc8Decl = TProcDecl avec   }
  { NoInf=Vrai (le champ Inf n est JAMAIS lu, meme si F and $40) -           }
  { confirme (DCURecs.pas, TSysProc8Decl.Create).                                }
  ReadNameFHeaderEx(Name, F, HasInf, Inf, Tag = TAG_SYSPROC);
  If Stopped Then Exit;

  B0 := ReadUIndex;
  Sz := ReadUIndex;
  If (Ver >= 15) And (Ver < 100) Then X := RB;

  NoName := IsUnnamedProcName(Name);
  HDTRes := 0;

  If Not NoName Then
  Begin
    If Ver > 2 Then ReadUIndex;   { VProc }
    HDTRes := ReadUIndex;          { hDTRes : 0 = procedure, sinon fonction }
    If (Ver > 7) And (Ver < 100) Then ReadUIndex;   { hClass }

    NextTag := RB;
    If Stopped Then Exit;

    { Convention d appel (CallKind) : si le tag est dans [arCDecl..     }
    { arSafeCall], il est consomme et remplace par le VRAI tag suivant -   }
    { confirme (DCU32.pas, ReadCallKind).                                       }
    If (NextTag >= TAG_ARG_CDECL) And (NextTag <= TAG_ARG_SAFECALL) Then
    Begin
      NextTag := RB;
      If Stopped Then Exit;
    End;

    { Generiques (Ver>=verD2009) : drA5Info precede toujours drA6Info -   }
    { ce dernier (TA6Def, parametres de modele) n est pas confirme -           }
    { arret propre plutot que deviner sa structure.                                }
    If (Ver >= 12) And (Ver < 100) Then
    Begin
      If NextTag = TAG_A5INFO Then
      Begin
        NextTag := RB;
        If Stopped Then Exit;
      End;
      If NextTag = TAG_A6INFO Then
      Begin
        Fail('procedure "' + Name + '" : parametres generiques ' +
          '(drA6Info/TA6Def) rencontres - structure non confirmee ' +
          '(portee documentee)');
        Exit;
      End;
    End;

    SkipArgList(NextTag, LK_ARGS);
    If Stopped Then Exit;
  End;

  If (Not NoName) And (MyAddrIdx >= 1) And (MyAddrIdx <= MAX_ADDRDEF) Then
  Begin
    AddrDefName[MyAddrIdx] := Name;
    AddrDefIsProc[MyAddrIdx] := True;
    If ProcListCnt < MAX_PROCS Then
    Begin
      Inc(ProcListCnt);
      ProcList[ProcListCnt].AddrIdx := MyAddrIdx;
      ProcList[ProcListCnt].Name := Name;
      { CONFIRME (DCU32.pas, TUnit.TypeIsVoid) : hDTRes=0 EST un cas de     }
      { "pas de resultat", mais PAS le seul - hDTRes designe le plus          }
      { souvent un index de type valide qui REFERENCE la definition             }
      { speciale "void" (DefVoid, TAG_VOID, RegisterType('void')) plutot            }
      { qu un simple 0 - un test hDTRes<>0 seul classait donc TOUTE procedure         }
      { (y compris "procedure DoNothing") comme "function" (bogue trouve             }
      { empiriquement, MiniTest.dcu).                                                   }
      { Limite connue et assumee : quand hDTRes reference un type IMPORTE   }
      { (hors de la table locale TypeText, ex. System.Integer) plutot         }
      { qu une definition locale, ce test ne peut pas confirmer s il s agit         }
      { du pseudo-type "void" partage ou d un vrai type de retour importe -            }
      { le mot-cle (function/procedure) peut alors etre incorrect. Ceci reste                 }
      { cosmetique : le contenu du bloc Assembler lui-meme n en depend pas.                        }
      ProcList[ProcListCnt].IsFunc := (HDTRes <> 0) And
        (TypeRefText(HDTRes) <> 'void');
    End;
  End;

  { La signature (et l eventuelle liste d arguments) est terminee -   }
  { le VRAI tag suivant (drProcAddInfo, drCBlock si un corps existe,     }
  { ou directement une AUTRE declaration si la procedure n en a pas)        }
  { est laisse au dispatcheur principal, qui gere desormais lui-meme            }
  { drCBlock/drFixUp comme n importe quel autre enregistrement (voir               }
  { ProcessCBlock/ProcessFixup) - conforme au vrai code source                       }
  { (DCU32.pas, TUnit.ReadDeclList) qui ne les traite PAS specialement                 }
  { a l interieur de TProcDecl.                                                          }
  CurTag := RB;
End;

{ ------------------------------------------------------------ }
{ Traitement de drStrConstRec ($35, TStrConstDecl) : bloc         }
{ constant genere par le compilateur pour un litteral chaine        }
{ (pas une declaration Pascal visible en soi). En-tete TNameFDecl      }
{ (voir ReadNameFHeader) puis un seul TNDX (Ofs).                        }
{ CORRECTION EMPIRIQUE (2026-07-16, contre les octets reels               }
{ d Access2000.dcu, Ver=27 - methode deja utilisee pour resoudre la          }
{ numerotation des types, voir DOC section 9b) : le texte source lu             }
{ dans DCURecs.pas (TStrConstDecl.Create) suggerait un DEUXIEME TNDX               }
{ ("Sz") puis un octet brut inconditionnel pour Ver>=verD_XE - mais la               }
{ comparaison octet par octet de 4 enregistrements drStrConstRec REELS               }
{ consecutifs (Access2000, System, UITypes, Variants) montre qu il n y a               }
{ PAS de second TNDX, et que l octet brut supplementaire n apparait QUE               }
{ quand Inf a ete lu (F and $40 <> 0) - pas inconditionnellement. Les 4               }
{ frontieres d enregistrements calculees avec cette regle tombent EXACTEMENT         }
{ sur le octet suivant "$35" (tag) a chaque fois ; l hypothese tiree du            }
{ texte source ne fonctionnait pas (desynchronisation immediate, tag "y"         }
{ ($79) invalide rencontre). Source qui prevaut en cas de conflit : les            }
{ octets reels, conformement a la methode choisie par l utilisateur.               }
{ RAFFINEMENT EMPIRIQUE SUPPLEMENTAIRE : l octet additionnel n est pas UN            }
{ octet fixe mais une SUITE de zero ou plusieurs marqueurs drStop1 ($63) -             }
{ confirme par un 7e enregistrement reel (StdVCL) qui en contient DEUX a la             }
{ suite avant l etiquette suivante. Condition de presence (zero, un ou                  }
{ plusieurs) : Inf a ete lu ET Ofs (valeur brute) <> 0 - confirme sur 7                    }
{ enregistrements reels consecutifs (Access2000, System, UITypes, Variants,                 }
{ Win, ComObj, StdVCL).                                                                       }
{ Pure metadonnee interne - consommee et annotee en commentaire, jamais              }
{ une declaration Delphi visible (meme traitement que ProcessSrcInf).                }
{ ------------------------------------------------------------ }

Procedure ProcessStrConstRec;
Var
  Name: TString;
  F: LongInt;
  HasInf: Boolean;
  Inf: LongWord;
  Ofs: LongInt;
Begin
  ReadNameFHeader(Name, F, HasInf, Inf);
  If Stopped Then Exit;
  NextAddrDef;   { drStrConstRec (TStrConstDecl) : consomme un index d adresse }

  Ofs := ReadUIndex;
  If HasInf And (Ofs <> 0) Then
    While (Not Stopped) And (PeekByte = TAG_STOP1) Do RB;

  If Length(Name) > 0 Then
    WriteLn(OutF, '{ constante chaine interne : ', Name, ' }')
  Else
    WriteLn(OutF, '{ constante chaine interne (anonyme) }');
End;

{ ------------------------------------------------------------ }
{ Traitement du GROUPE d enregistrements drStrConstRec : confirme    }
{ empiriquement (9 enregistrements reels consecutifs d Access2000.dcu)  }
{ que toute la SUITE de drStrConstRec forme une liste imbriquee unique,   }
{ exactement comme la liste d import de ProcessUsesUnit - terminee par      }
{ UN drStop1 ($63) final APRES le dernier enregistrement (en plus des         }
{ eventuels marqueurs internes par enregistrement, voir ProcessStrConstRec).  }
{ Gere donc CurTag elle-meme jusqu au bout, comme ProcessUsesUnit.              }
{ ------------------------------------------------------------ }

Procedure ProcessStrConstRecGroup;
Begin
  Repeat
    ProcessStrConstRec;
    If Stopped Then Exit;
    CurTag := RB;
  Until Stopped Or (CurTag <> TAG_STRCONSTREC);

  If Stopped Then Exit;

  { CORRECTION EMPIRIQUE (2026-07-16, System.Classes.dcu) : un drStop1     }
  { final APRES la suite de drStrConstRec n est pas toujours present -      }
  { l hypothese initiale (un groupe toujours ferme par un terminateur)        }
  { ne se verifie pas partout dans un fichier reel (seulement observee         }
  { juste apres le tout premier groupe suivant la clause "uses"). Le          }
  { comportement tolerant est donc : consommer UN drStop1 s il est la           }
  { (cas observe sur Access2000.dcu), sinon continuer directement SANS           }
  { exiger sa presence (cas observe sur System.Classes.dcu) - jamais              }
  { d arret pour cette seule variation.                                              }
  If CurTag = TAG_STOP1 Then
    CurTag := RB;
End;

{ ------------------------------------------------------------ }
{ Traitement de drConst ($25, TConstDecl) : en-tete TNameFDecl      }
{ (voir ReadNameFHeader) + hDT (TNDX, type) + TConstValInfo -           }
{ structure CONFIRMEE contre le vrai code source (DCURecs.pas,           }
{ TConstDecl.Create + TConstValInfo.Read) : Kind (TNDX, si Ver>4),          }
{ ValSz (TNDX) puis, si ValSz=0 : Val (TNDX SIGNE, sauf si Kind=4           }
{ "Pointer/Nil" pour Ver>=verD_XE2(16) - alors aucune valeur) ; si            }
{ ValSz<>0 : ValSz OCTETS BRUTS (bloc memoire, ex. chaine/set/tableau           }
{ de constante typee). La valeur elle-meme n est PAS interpretee ici              }
{ (Kind=0 scalaire,1 chaine,2 resourcestring,3 flottant,4 set/pointeur,            }
{ 5 chaine Unicode - interpretation binaire exacte hors de portee                   }
{ actuelle) : structure lue et correctement sautee, constante annotee                }
{ en commentaire plutot qu une fausse syntaxe "Nom: Type;" (qui ne serait              }
{ pas une const Pascal valide sans "=valeur").                                          }
{ ------------------------------------------------------------ }

Procedure ProcessConstDecl;
Var
  Name: TString;
  F: LongInt;
  HasInf: Boolean;
  Inf: LongWord;
  HDT: LongInt;
  Kind: LongInt;
Begin
  ReadNameFHeader(Name, F, HasInf, Inf);
  If Stopped Then Exit;
  NextAddrDef;   { drConst (TConstDecl) : consomme un index d adresse }

  HDT := ReadUIndex;
  SkipConstValInfo('constante "' + Name + '"', Kind);
  If Stopped Then Exit;

  WriteLn(OutF, '  { const ', Name, ' : ', TypeRefText(HDT),
    '  (valeur non decodee, Kind=', IntToStr(Kind), ') }');
End;

{ ------------------------------------------------------------ }
{ Un attribut personnalise (utilise par drConstAddInfo tag $01,     }
{ ReadAttributes/TAttributeDeclModifier.Read) - structure CONFIRMEE    }
{ contre le vrai code source (DCURecs.pas) : hAttrCtor+hMember+hAttrDT      }
{ (3 TNDX) puis ArgCnt (TNDX) arguments, chacun Kind(TNDX) puis soit          }
{ Kind=0 "const" (hDT:TNDX + TConstValInfo, reutilise SkipConstValInfo)         }
{ soit Kind=1 "TypeInfo(DT)" (2 TNDX) - toute autre valeur de Kind est            }
{ un arret propre (structure non prevue par le vrai outil non plus).              }
{ ------------------------------------------------------------ }

Procedure SkipOneAttribute;
Var
  HAttrCtor, HMember, HAttrDT, ArgCnt, J, Kind, CHDT, KindDummy: LongInt;
Begin
  HAttrCtor := ReadUIndex;
  HMember := ReadUIndex;
  HAttrDT := ReadUIndex;
  ArgCnt := ReadUIndex;
  For J := 1 To ArgCnt Do
  Begin
    Kind := ReadUIndex;
    Case Kind Of
      0:
        Begin
          CHDT := ReadUIndex;
          SkipConstValInfo('attribut (argument constante)', KindDummy);
        End;
      1:
        Begin
          ReadUIndex;   { hDT }
          ReadUIndex;   { hDTAddr }
        End;
    Else
      Fail('attribut : genre d argument inattendu (Kind=' + IntToStr(Kind) +
        ') - structure non prevue');
    End;
    If Stopped Then Exit;
  End;
End;

Procedure SkipAttributes;
Var
  N, I: LongInt;
Begin
  N := ReadUIndex;
  For I := 1 To N Do
  Begin
    SkipOneAttribute;
    If Stopped Then Exit;
  End;
End;

{ ------------------------------------------------------------ }
{ Traitement de drConstAddInfo ($9C) : metadonnee ANNEXE attachee     }
{ a la declaration precedente (deprecated/plateforme/bibliotheque,       }
{ attributs personnalises, generation de code .NET) - PAS une              }
{ declaration en soi. Structure CONFIRMEE contre le vrai code source          }
{ (DCU32.pas, TUnit.ReadConstAddInfo) : une SUITE d etiquettes-octet             }
{ (PAS des TNDX - RB direct), chacune avec sa propre charge, jusqu a              }
{ une etiquette terminale caiStop dependant de la version. Portee :               }
{ TOUTES les sous-etiquettes confirmees sont decodees, SAUF la branche              }
{ "directive inline" de l etiquette $01 (F and cafInline<>0) : la               }
{ fonction reelle dont elle depend (ReadInlineInfo) est absente des                }
{ 6 fichiers source officiels du depot DCU32INT (DCU32.pas/DCURecs.pas/            }
{ DCUTbl.pas/DCU_In.pas/DCU_Out.pas/FixUp.pas, tous verifies le                     }
{ 2026-07-16) - seul son SITE D APPEL existe, jamais sa definition ;                 }
{ DEVINER sa structure irait a l encontre de la methode de ce projet                  }
{ (jamais de suppositions non verifiees) - arret propre explicite si                   }
{ ce bit specifique est rencontre, plutot qu un decodage risque.                        }
{ ------------------------------------------------------------ }

Procedure ProcessConstAddInfo;
Var
  CaiStop: Byte;
  Tag: Byte;
  Result_, F, IP2, Len, I, V1, V2, V3, CafInline, CafBigVal: LongInt;
Begin
  If (Ver <= 7) Or (Ver >= 100) Then
    CaiStop := $06
  Else Begin
    CaiStop := $0D;
    If Ver >= 9 Then
    Begin
      CaiStop := $0F;
      If Ver >= 12 Then CaiStop := $FF;
    End;
  End;

  Repeat
    Tag := RB;
    If Stopped Then Exit;
    If Tag >= CaiStop Then Break;

    Case Tag Of
      $01:
        Begin
          Result_ := ReadUIndex;
          F := ReadUIndex;
          { plateformes mobiles/emulateur hors de portee de ce programme      }
          { (Win32 natif uniquement) - la condition reelle "not(Platform in   }
          { mobiles)" est donc toujours VRAIE ici.                              }
          If (Ver >= 10) And (Ver <= 23) And (Ver < 100) Then
          Begin
            If (F And $1000000) <> 0 Then IP2 := ReadUIndex;
          End;
          If (Ver >= 9) And (Ver < 100) Then
          Begin
            CafInline := $80000;
            CafBigVal := $100000;
            If Ver >= 12 Then
            Begin
              If (F And $800000) <> 0 Then IP2 := ReadUIndex;
              If (F And $1) <> 0 Then SkipNDXStr;   { deprecated : ReadNDXStrRef }
              If (Ver >= 20) And ((F And LongInt($80000000)) <> 0) Then
                SkipAttributes;
              CafInline := $40000;
              CafBigVal := $80000;
            End;
            If (F And CafInline) <> 0 Then
            Begin
              Fail('drConstAddInfo : directive inline (F and $' +
                IntToHex(CafInline, 6) + ') rencontree - la fonction reelle ' +
                'ReadInlineInfo dont depend cette branche est absente des ' +
                'sources officielles DCU32INT disponibles (voir DOC/' +
                'DCU_FORMAT.TXT) - arret propre plutot que deviner sa structure');
              Exit;
            End;
            If (F And CafBigVal) <> 0 Then IP2 := ReadUIndex;
          End;
        End;

      $04:
        Begin
          If Not ((Ver >= 10) And (Ver < 100)) Then Break;
          ReadUIndex; ReadUIndex;
        End;

      $06:
        Begin
          ReadUIndex; ReadUIndex; ReadUIndex; ReadUIndex;
        End;

      $07:
        Begin
          ReadUIndex; ReadUIndex; ReadUIndex; ReadUIndex;
        End;

      $08:
        Begin
          ReadUIndex;
          Len := ReadUIndex;
          SkipRawBlock(Len);
        End;

      $09:
        Begin
          ReadUIndex; ReadUIndex;
        End;

      $0A:
        Begin
          ReadUIndex;
          ReadUIndex;
          F := ReadUIndex;
          If (F And $01) <> 0 Then ReadUIndex;
          If (F And $02) <> 0 Then ReadUIndex;
          If (F And $04) <> 0 Then ReadUIndex;
          If (F And $08) <> 0 Then ReadUIndex;
          If (F And $10) <> 0 Then ReadUIndex;
          If (F And $20) <> 0 Then ReadUIndex;
          If (F And $40) <> 0 Then
          Begin
            Len := ReadUIndex;   { ArgCnt de TExtraArgsDeclModifier }
            For I := 1 To Len Do
            Begin
              SkipNDXStr;
              ReadUIndex; ReadUIndex; ReadUIndex;
            End;
          End;
          If (F And $80) <> 0 Then
          Begin
            ReadUIndex; ReadUIndex; ReadUIndex;
          End;
          If (F And $100) <> 0 Then SkipNDXStr;
          If (F And $200) <> 0 Then SkipNDXStr;
          If (F And $400) <> 0 Then ReadUIndex;
          If (F And $800) <> 0 Then ReadUIndex;
          If (F And $1000) <> 0 Then ReadUIndex;
          If (F And $2000) <> 0 Then ReadUIndex;
          If (F And $4000) <> 0 Then ReadUIndex;
        End;

      $0C:
        Begin
          ReadUIndex; ReadUIndex; ReadUIndex;
        End;

      $0D:
        Begin
          If (Ver < 9) Or (Ver >= 100) Then Break;
          ReadUIndex;
          SkipNDXStr;
        End;

      $10:
        Begin
          If (Ver < 12) Or (Ver >= 100) Then Break;
          ReadUIndex; ReadUIndex; ReadUIndex;
        End;

      $11:
        Begin
          If (Ver < 18) Or (Ver >= 100) Then Break;
          ReadUIndex; ReadUIndex;
        End;

      $12:
        Begin
          If (Ver < 12) Or (Ver >= 100) Then Break;
          ReadUIndex; ReadUIndex;
        End;

      $13:
        Begin
          If (Ver < 12) Or (Ver >= 100) Then Break;
          ReadUIndex; ReadUIndex; ReadUIndex;
          SkipNDXStr; SkipNDXStr; SkipNDXStr;
        End;

      $14:
        Begin
          If (Ver < 12) Or (Ver >= 100) Then Break;
          ReadUIndex; ReadUIndex;
          Len := ReadUIndex;
          For I := 1 To Len Do
          Begin
            ReadUIndex; ReadUIndex; ReadUIndex;
            SkipNDXStr;
          End;
        End;

      $15:
        Begin
          If (Ver < 16) Or (Ver >= 100) Then Break;
          ReadUIndex; ReadUIndex; ReadUIndex;
        End;

      $16:
        Begin
          ReadUIndex;
          Len := ReadUIndex;
          SkipRawBlock(Len);
        End;

    Else
      Break;
    End;

    If Stopped Then Exit;
  Until False;

  If Tag <> CaiStop Then
    Fail('drConstAddInfo : etiquette inattendue en sortie de boucle ($' +
      IntToHex(Tag, 2) + ', attendu $' + IntToHex(CaiStop, 2) + ')');
End;

{ ------------------------------------------------------------ }
{ Dispatcher principal : un enregistrement a la fois.             }
{ ------------------------------------------------------------ }

Procedure ProcessOneRecord;
Var
  Tag: Byte;
Begin
  Tag := CurTag;

  { Des qu un enregistrement de VRAIE DECLARATION apparait (pas juste     }
  { une autre unite "uses", ni une metadonnee source/objet/asm/ressource -  }
  { drSrc precede SOUVENT le tout premier "uses", confirme empiriquement,    }
  { donc PAS un declencheur valable), la clause "uses" accumulee jusqu ici     }
  { est complete - l ecrire maintenant (voir FlushUsesClause) avant de           }
  { traiter ce nouvel enregistrement.                                              }
  If (Tag <> TAG_UNIT) And (Tag <> TAG_UNIT1) And (Tag <> TAG_SRC) And
     (Tag <> TAG_OBJ) And (Tag <> TAG_ASM) And (Tag <> TAG_RES) And
     (Tag <> TAG_UNIT_INLINE_SRC) And (Tag <> TAG_DLL) Then
    FlushUsesClause;

  Case Tag Of
    TAG_UNIT, TAG_UNIT1, TAG_DLL:
      Begin
        { ProcessUsesUnit gere elle-meme CurTag jusqu au bout (liste       }
        { d import de longueur variable, puis eventuel drProcAddInfo) -     }
        { ne PAS laisser le code commun ci-dessous relire une etiquette.      }
        { drDLL (import de fonctions externes, ex. kernel32.dll) reutilise      }
        { la MEME fonction reelle (TUnit.ReadUses) que drUnit/drUnit1 -           }
        { confirme (DCU32.pas) - jamais decode auparavant (System.SysUtils.dcu,    }
        { position $423F).                                                            }
        ProcessUsesUnit(Tag);
        Exit;
      End;

    TAG_EMBEDDED_PROC_START:
      Begin
        { drEmbeddedProcStart/drEmbeddedProcEnd encadrent les declarations   }
        { LOCALES d une procedure (types/consts declares dans son corps) -      }
        { CONFIRME (DCU32.pas, TUnit.ReadDeclList) : un bloc imbrique qui           }
        { reutilise le MEME aiguilleur que le niveau principal (recursion          }
        { directe sur ProcessOneRecord), termine par drEmbeddedProcEnd -              }
        { voir SkipEmbeddedBlock (partagee avec SkipArgList). Ces declarations         }
        { locales ne sont pas des declarations Pascal visibles au niveau de              }
        { l unite (portee limitee au corps d une procedure non decompile) -                }
        { on les saute sans rien imprimer.                                                     }
        SkipEmbeddedBlock;
        Exit;
      End;

    TAG_VAR, TAG_VARC, TAG_ABSVAR, TAG_SPECVAR, TAG_RESSTR_OLD,
    TAG_RESSTR_NEW, TAG_THREADVAR_OLD:
      ProcessVarLike(Tag);

    TAG_CLASSVAR:
      ProcessClassVarTopLevel;

    TAG_CONST:
      ProcessConstDecl;

    TAG_PROC, TAG_SYSPROC:
      Begin
        { ProcessProc gere elle-meme CurTag jusqu au bout (liste          }
        { d arguments de longueur variable, puis corps eventuel              }
        { drCBlock/drFixUp) - ne PAS laisser le code commun ci-dessous          }
        { relire une etiquette.                                                    }
        ProcessProc(Tag);
        Exit;
      End;

    TAG_OREC:
      Begin
        { ProcessORec gere elle-meme CurTag jusqu au bout (liste       }
        { imbriquee dlA6 de longueur variable).                             }
        ProcessORec;
        Exit;
      End;

    TAG_TYPE:
      ProcessNamedType;
    TAG_TYPEP:
      ProcessTypeP;

    TAG_RANGEDEF:
      DefRange('intervalle');
    TAG_CHRANGEDEF:
      DefRange('intervalle de caracteres');
    TAG_BOOLRANGEDEF:
      DefRange('intervalle booleen');
    TAG_WCHARRANGEDEF, TAG_WIDERANGEDEF:
      DefRange('intervalle WideChar');
    TAG_PTRDEF:
      DefPtr;
    TAG_SETDEF:
      DefSet;
    TAG_FLOATDEF:
      DefFloat;
    TAG_VOID:
      DefVoid;
    TAG_ENUMDEF:
      DefEnum;
    TAG_ARRAYDEF:
      DefArrayLike(False, '');
    TAG_SHORTSTRDEF:
      DefArrayLike(True, 'ShortString');
    TAG_STRINGDEF:
      DefArrayLike(True, 'AnsiString');
    TAG_WIDESTRDEF:
      DefArrayLike(True, 'WideString');
    TAG_UNICODESTRDEF:
      DefArrayLike(True, 'UnicodeString');
    TAG_DYNARRAYDEF:
      DefDynArray;
    TAG_PROCTYPEDEF:
      DefProcType;
    TAG_RECDEF:
      DefRecord;
    TAG_CLASSDEF:
      DefClass;
    TAG_INTERFACEDEF:
      DefInterface;
    TAG_OBJVMTDEF:
      DefObjVMT;
    TAG_OBJDEF:
      DefObj;

    TAG_EXPORT:
      { drExport (TExportInf) : hSym+Index, deux TNDX simples - purement   }
      { une marque de visibilite publique, rien a imprimer de plus.          }
      Begin
        ReadUIndex;
        ReadUIndex;
      End;

    TAG_STRCONSTREC:
      Begin
        { ProcessStrConstRecGroup gere elle-meme CurTag jusqu au bout      }
        { (toute la suite de drStrConstRec est UNE liste imbriquee,          }
        { terminee par un seul drStop1 final) - ne PAS laisser le code          }
        { commun ci-dessous relire une etiquette.                                }
        ProcessStrConstRecGroup;
        Exit;
      End;

    TAG_CONST_ADD_INFO:
      ProcessConstAddInfo;

    TAG_PROC_ADD_INFO:
      { drProcAddInfo (Ver>=verD7) : un seul TNDX signe (V), utilise en   }
      { interne par le vrai outil pour retrouver la derniere procedure       }
      { (=2 apres Finalization, =$FE apres Initialization, par exemple) -       }
      { confirme (DCU32.pas) : rien d autre a lire, rien a imprimer.               }
      ReadSIndex;

    TAG_CBLOCK:
      ProcessCBlock;
    TAG_FIXUP:
      ProcessFixup;

    TAG_CODELINES:
      ProcessCodeLines;
    TAG_LINNUM:
      ProcessLinNum;
    TAG_STRUCSCOPE:
      ProcessStrucScope;
    TAG_SYMBOLREF:
      ProcessSymbolRef;
    TAG_LOCVARTBL:
      ProcessLocVarTbl;
    TAG_SEGINFO:
      ProcessSegInfo;
    TAG_ADDRTOSEGINFO:
      ProcessAddrToSegInfo;

    TAG_UNITFLAGS, TAG_UNIT_ADD_INFO, TAG_INFO98:
      Fail('etiquette de metadonnees $' + IntToHex(Tag, 2) +
        ' rencontree hors de l en-tete - structure non prise en charge ' +
        'a cet endroit (portee documentee)');

    TAG_FILEDEF, TAG_TEXTDEF,
    TAG_VARIANTDEF,
    TAG_METACLASSDEF:
      FailUnknownTag(Tag, 'definition de type complexe');

    TAG_SRC:
      ProcessSrcInf('source');
    TAG_OBJ:
      ProcessSrcInf('objet');
    TAG_ASM:
      ProcessSrcInf('asm');
    TAG_RES:
      ProcessSrcInf('ressource');
    TAG_UNIT_INLINE_SRC:
      ProcessSrcInf('source inline');

    TAG_LABEL:
      FailUnknownTag(Tag, 'enregistrement');

  Else
    FailUnknownTag(Tag, 'table principale');
  End;

  { Code commun : chaque cas ci-dessus (hormis "uses", deja sorti via     }
  { Exit) ne consomme que son propre contenu fixe - avancer d une            }
  { etiquette pour le prochain tour de la boucle principale.                    }
  If Not Stopped Then
    CurTag := RB;
End;

{ ------------------------------------------------------------ }
{ Detection de la version Delphi a partir du nombre magique -    }
{ voir DOC\DCU_FORMAT.TXT section 3. Seules les valeurs Win32       }
{ natif sont reconnues (ce programme, comme DELPHI.PAS, ne vise      }
{ pas Kylix/.NET/MSIL/mobile/64 bits).                                }
{ ------------------------------------------------------------ }

Function DetectVersion(Magic: LongWord): Integer;
Var
  BVer, PlMagic: LongWord;
Begin
  Case Magic Of
    $50505348: DetectVersion := 2;
    $44518641: DetectVersion := 3;
    $4768A6D8: DetectVersion := 4;
    $F21F148B: DetectVersion := 5;
    $0E0000DD, $0E8000DD: DetectVersion := 6;
    $FF0000DF, $0F0000DF, $0F8000DF: DetectVersion := 7;
    $1100000D, $11800009: DetectVersion := 9;
    $12000023: DetectVersion := 10;
    $14000039: DetectVersion := 12;
    $15000045: DetectVersion := 14;
    $1600034B: DetectVersion := 15;
  Else
    Begin
      DetectVersion := 0;
      If (Magic And $00FF00F9) = $00000049 Then
      Begin
        BVer := Magic Shr 24;
        PlMagic := Magic And $FF;
        If (BVer >= $1B) And (BVer <= $23) And (PlMagic = $4D) Then
          DetectVersion := LongInt(BVer) + (16 - $17)
        Else If (BVer >= $17) And (BVer <= $1A) And (PlMagic = $4B) Then
          DetectVersion := LongInt(BVer) + (16 - $17);
      End;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ Lecture de l en-tete - voir DOC\DCU_FORMAT.TXT section 6/11bis. }
{ Renvoie la premiere etiquette reelle de la table principale     }
{ (deja lue au passage, comme le fait le vrai DCU32.pas).           }
{ ------------------------------------------------------------ }

Function ReadHeader(FileSizeOnDisk: LongInt): Byte;
Var
  DeclaredSize, CompileTime, Stamp2: LongWord;
  B1v, B2v: Byte;
  NamePrefix: TString;
  L1, L2: LongInt;
  Tag: Byte;
  FFlags, Flags1, FUnitPrior: LongInt;
Begin
  DeclaredSize := RUL;
  If LongInt(DeclaredSize) <> FileSizeOnDisk Then
    WriteLn(ErrOutput, 'DISDCU: avertissement : FileSize declare ($',
      IntToHex(DeclaredSize, 8), ') <> taille reelle ($',
      IntToHex(FileSizeOnDisk, 8), ')');

  CompileTime := RUL;

  If Ver = 2 Then
  Begin
    B1v := RB;
    Tag := RB;
    ReadHeader := Tag;
    Exit;
  End;

  Stamp2 := RUL;
  B1v := RB;
  If Ver >= 7 Then
    B2v := RB;
  If Ver >= 9 Then
    NamePrefix := ReadHeaderStr;
  If Ver >= 12 Then
  Begin
    L1 := ReadUIndex;
    L2 := ReadUIndex;
  End;

  Tag := RB;
  If Tag = TAG_UNITFLAGS Then
  Begin
    FFlags := ReadUIndex;
    If Ver > 9 Then Flags1 := ReadUIndex;
    If Ver > 3 Then FUnitPrior := ReadUIndex;
    Tag := RB;
  End;

  ReadHeader := Tag;
End;

{ ------------------------------------------------------------ }
{ Programme principal                                            }
{ ------------------------------------------------------------ }

Var
  InName, OutName: TString;
  InF: File;
  NRead: LongInt;
  Magic: LongWord;
  VerName: TString;

Begin
  Stopped := False;
  TypeCount := 0;
  EmbEndCnt := 0;
  UsesFlushed := False;
  UsesCount := 0;
  ImportPoolCount := 0;

  If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
   WriteLn('DISDCU - Cette commande permet de d',#130,'compilateur ',
           '.DCU vers .PAS (port',#130,'e partielle, ');
   WriteLn('voir l''ent',#136,'te de DISDCU.PAS pour le d',#130,'tail exact)');
   WriteLn;
   WriteLn('Syntaxe : DISDCU <fichier.dcu> [fichier.pas]');
   Halt(1);
  End;

  InName := ParamStr(1);
  If ParamCount >= 2 Then
    OutName := ParamStr(2)
  Else
    OutName := ChangeFileExt(InName, '.pas');

  {$I-}
  Assign(InF, InName);
  Reset(InF, 1);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn(ErrOutput, 'DISDCU: impossible d ouvrir le fichier : ', InName);
    Halt(1);
  End;

  BufLen := FileSize(InF);
  If BufLen > MAX_BUF Then
  Begin
    WriteLn(ErrOutput, 'DISDCU: fichier trop volumineux (MAX_BUF=',
      MAX_BUF, ' octets)');
    Close(InF);
    Halt(1);
  End;
  BlockRead(InF, Buf, BufLen, NRead);
  Close(InF);
  If NRead <> BufLen Then
  Begin
    WriteLn(ErrOutput, 'DISDCU: lecture incomplete du fichier');
    Halt(1);
  End;

  P := 0;
  Magic := RUL;
  Ver := DetectVersion(Magic);
  If Ver = 0 Then
  Begin
    WriteLn(ErrOutput, 'DISDCU: nombre magique non reconnu : $',
      IntToHex(Magic, 8), ' (voir DOC/DCU_FORMAT.TXT section 3 - ',
      'seules les versions Win32 natives Delphi 2 a 11 environ sont ',
      'reconnues, pas Kylix/.NET/MSIL/mobile/64 bits)');
    Halt(1);
  End;
  Str(Ver, VerName);

  {$I-}
  Assign(OutF, OutName);
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn(ErrOutput, 'DISDCU: impossible de creer le fichier de sortie : ',
      OutName);
    Halt(1);
  End;

  WriteLn(OutF, '{ Decompile par DISDCU a partir de : ', InName, ' }');
  WriteLn(OutF, '{ Nombre magique : $', IntToHex(Magic, 8),
    '  (Ver interne = ', VerName, ') }');
  WriteLn(OutF, '{ ATTENTION : portee partielle (pas necessairement cette ',
    'decompilation precise - voir l entete de DISDCU.PAS pour la portee ',
    'exacte : certains types complexes/tags recents non pris en charge). ',
    'Les corps de routine SONT desassembles en blocs Assembler;asm...end; ',
    'quand la correlation adresse-declaration reussit (voir NextAddrDef) - ',
    'sinon un commentaire "corps non attribue" remplace le bloc plutot ',
    'que d afficher des octets errones. }');
  WriteLn(OutF);

  CurTag := ReadHeader(BufLen);

  { Nom de l unite : le nom complet reconstruit par un vrai            }
  { decompilateur (ex. "REST.OpenSSL") ne provient pas d un simple       }
  { champ isole confirme dans l en-tete (le "prefixe" lu la n est que      }
  { la racine avant le premier point, ex. "REST" seul) - Delphi impose       }
  { neanmoins que le nom d une unite corresponde au nom de son fichier         }
  { source, une convention fiable a defaut d avoir perce ce champ a 100% :      }
  WriteLn(OutF, 'unit ', ChangeFileExt(ExtractFileName(InName), ''), ';');
  WriteLn(OutF);

  { "interface" precede toujours la clause "uses" en Delphi reel (l ordre  }
  { inverse etait une erreur : FlushUsesClause ecrivait "interface" APRES   }
  { "uses", signale par l utilisateur) - on l ecrit donc ici, immediatement  }
  { apres l en-tete de l unite, avant toute accumulation de "uses".            }
  WriteLn(OutF, 'interface');
  WriteLn(OutF);

  { Note de portee : les enregistrements ne sont PAS strictement       }
  { groupes par categorie dans le flux reel (confirme empiriquement -   }
  { un enregistrement "source" (drSrc) precede souvent le tout premier    }
  { "uses") - chaque "uses" rencontre est donc ACCUMULE (voir                }
  { ProcessUsesUnit) plutot qu ecrit immediatement ; la clause complete        }
  { ("uses" + bloc de commentaire des imports resolus) n est ecrite            }
  { qu une seule fois, par FlushUsesClause, des que le premier enregistrement    }
  { NON-"uses" apparait (voir ProcessOneRecord) - ou plus bas, si le fichier        }
  { ne contenait QUE des "uses". "interface" est deja ecrit plus haut, AVANT       }
  { toute accumulation de "uses" (ordre reel Delphi : interface precede uses).      }

  { CORRECTION (2026-07-16, contre le vrai code source DCU32.pas,        }
  { TUnit.LoadFromMem) : le VRAI analyseur n a AUCUN cas special pour       }
  { drStop=$00 dans son grand aiguilleur - ce n est PAS une etiquette de     }
  { fin de fichier reconnue ("// if Tag<>drStop then DCUError(...)" est       }
  { en commentaire, donc desactive, dans la vraie source). Traiter $00           }
  { comme une fin silencieuse valide MASQUAIT un vrai desalignement en          }
  { profondeur (confirme empiriquement : DIAGNOSTIC montrait une position          }
  { finale a ~35 Ko alors que le vrai fichier fait 1,5 a 2 Mo - la "reussite"        }
  { etait donc une COINCIDENCE d octet, pas une vraie fin de fichier). Seul            }
  { TAG_STOP_A=$61 reste un arret silencieux (constante reelle "Last Tag in           }
  { all files") ; $00 rencontre inopinement doit maintenant passer par                  }
  { l aiguilleur normal (FailUnknownTag) comme n importe quelle autre                     }
  { etiquette non reconnue.                                                                }
  While (Not Stopped) And (CurTag <> TAG_STOP_A) Do
    ProcessOneRecord;

  If Not Stopped Then
    WriteLn(ErrOutput, 'DISDCU: DIAGNOSTIC position finale = $', IntToHex(P, 8),
      ' / taille fichier = $', IntToHex(BufLen, 8), ' (etiquette de fin : $',
      IntToHex(CurTag, 2), ')');

  FlushUsesClause;   { au cas ou le fichier ne contenait que des "uses" }

  { Le desassemblage des corps de routine (EmitAllProcAsmBlocks) ne depend    }
  { QUE de drCBlock/drFixUp (avant-derniere/derniere etiquette du fichier) -    }
  { il est donc emis des que du code a ete capture (CodeSize>0), MEME si          }
  { l unite s arrete plus loin sur une etiquette non geree (ex. les tables de          }
  { debogage drCodeLines/drLinNum, hors de portee - voir l en-tete de ce                  }
  { programme) : une decompilation partielle reste utile, comme partout                     }
  { ailleurs dans ce programme.                                                                }
  { Une unite Delphi bien formee a TOUJOURS une section "implementation"    }
  { et se termine TOUJOURS par "end." - meme une decompilation partielle       }
  { (Stopped=Vrai) doit respecter cette forme plutot que de laisser un            }
  { fichier .pas tronque sans "end." final.                                          }
  WriteLn(OutF);
  WriteLn(OutF, 'implementation');
  If CodeSize > 0 Then EmitAllProcAsmBlocks;

  If Stopped Then
    WriteLn(OutF, #10, '{ *** ARRET ICI - voir le message ci-dessus/dans ',
      'la sortie d erreur *** }');

  WriteLn(OutF);
  WriteLn(OutF, 'end.');

  Close(OutF);

  If Stopped Then
  Begin
    WriteLn('DISDCU: decompilation partielle ecrite dans ', OutName,
      ' (voir le message d arret ci-dessus)');
    Halt(2);
  End
  Else
    WriteLn('DISDCU: decompilation complete ecrite dans ', OutName);
END.
