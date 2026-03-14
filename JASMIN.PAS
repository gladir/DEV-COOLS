{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Assembleur Jasmin -> fichier .class (Java bytecode)
}

{ ---------------------------------------------------------------------------- }
{  ARCHITECTURE GENERALE                                                       }
{ ---------------------------------------------------------------------------- }
{  1. Lexeur    : SrcGetChar, NextToken -> CurTok / CurStr / CurInt            }
{  2. Parser    : ParseDirective, ParseInstruction                             }
{  3. CodeGen   : BinWriteU1, BinWriteU2, BinWriteU4 (big-endian)             }
{  4. CP        : Constant Pool (CPAddUtf8, CPAddClass, CPAddMethodRef, ...)   }
{  5. Assemble  : fichier .j -> fichier .class                                 }
{ ---------------------------------------------------------------------------- }

{ ---------------------------------------------------------------------------- }
{  TODO 01 [IMPLEMENTE] - Architecture de base, constantes et types internes   }
{  TODO 02 [IMPLEMENTE] - Lexeur : lecture source et tokenisation              }
{  TODO 03 [IMPLEMENTE] - Gestion des erreurs, des avertissements et du bilan }
{  TODO 04 [IMPLEMENTE] - Bassin de constantes (Constant Pool) : structures et gestion }
{  TODO 05 [IMPLEMENTE] - Ecriture binaire du fichier .class (Big-endian)     }
{  TODO 06 [IMPLEMENTE] - Directives de classe (.class, .super, .implements, .source) }
{  TODO 07 [IMPLEMENTE] - Directives de champs (.field avec descripteurs et valeurs) }
{  TODO 08 [IMPLEMENTE] - Directives de methodes (.method, .end method, .limit)}
{  TODO 09 [IMPLEMENTE] - Descripteurs de types JVM : parsing et validation   }
{  TODO 10 [IMPLEMENTE] - Opcodes de chargement et stockage                   }
{  TODO 11 [IMPLEMENTE] - Opcodes arithmetiques et logiques                    }
{  TODO 12 [IMPLEMENTE] - Opcodes de conversion de types                      }
{  TODO 13 [IMPLEMENTE] - Opcodes de controle de flux                         }
{  TODO 14 [IMPLEMENTE] - Opcodes d'invocation de methodes                    }
{  TODO 15 [IMPLEMENTE] - Opcodes de manipulation de la pile et chargement de constantes   }
{  TODO 16 [IMPLEMENTE] - Opcodes de creation d'objets et tableaux            }
{  TODO 17 [IMPLEMENTE] - Opcodes d'acces aux champs                           }
{  TODO 18 [IMPLEMENTE] - Opcodes de comparaison, retour et divers            }
{  TODO 19 [IMPLEMENTE] - Labels, resolution des sauts et calcul des offsets  }
{  TODO 20 [IMPLEMENTE] - Attribut Code : generation binaire                  }
{  TODO 21 [IMPLEMENTE] - Directives de gestion des exceptions (.catch, .throws) }
{  TODO 22 [IMPLEMENTE] - Attributs supplementaires (SourceFile, LineNumberTable, etc.)    }
{  TODO 23 [IMPLEMENTE] - Programme principal : ligne de commande et generation .class     }
{  TODO 24 - Validation et verification du bytecode genere                    }
{  TODO 25 - Exemples SAMPLES/JASMIN/*.j et corrections de bugs              }
{ ---------------------------------------------------------------------------- }

Program JASMIN;

{$A-}
{$I-}

{ ============================================================================ }
{ Architecture de base : constantes, types internes, variables                 }
{ ============================================================================ }

Const

  VERSION = 'Assembleur Jasmin V0.1';

  { ------------------------------------------------------------------ }
  { Types de tokens                                                     }
  { ------------------------------------------------------------------ }
  TK_UNKNOWN     = 0;
  TK_IDENT       = 1;   { identifiant ou mnemonique d'instruction       }
  TK_INTEGER     = 2;   { litteral entier (decimal, hex 0x.., octal)    }
  TK_FLOAT       = 3;   { litteral flottant 1.5 1.5E3                   }
  TK_STRING      = 4;   { litteral chaine "..."                         }
  TK_COLON       = 5;   { :                                             }
  TK_EQUAL       = 6;   { =                                             }
  TK_LPAREN      = 7;   { (                                             }
  TK_RPAREN      = 8;   { )                                             }
  TK_SLASH       = 9;   { /                                             }
  TK_SEMI        = 10;  { ;                                             }
  TK_DOT         = 11;  { .                                             }
  TK_LBRACKET    = 12;  { [                                             }
  TK_RBRACKET    = 13;  { ]                                             }
  TK_MINUS       = 14;  { -                                             }
  TK_PLUS        = 15;  { +                                             }
  TK_EOF         = 16;  { fin de fichier                                }
  TK_NEWLINE     = 17;  { fin de ligne                                  }
  TK_DIRECTIVE   = 18;  { mot commencant par '.' (.class, .method, ...) }
  TK_LABEL       = 19;  { identifiant suivi de ':' (etiquette)          }

  { ------------------------------------------------------------------ }
  { Directives Jasmin                                                   }
  { ------------------------------------------------------------------ }
  DIR_NONE        = 0;
  DIR_CLASS       = 1;   { .class <access> <classname>                  }
  DIR_SUPER       = 2;   { .super <classname>                           }
  DIR_IMPLEMENTS  = 3;   { .implements <interfacename>                  }
  DIR_SOURCE      = 4;   { .source <filename>                           }
  DIR_FIELD       = 5;   { .field <access> <name> <descriptor> [= val]  }
  DIR_METHOD      = 6;   { .method <access> <name><descriptor>          }
  DIR_END         = 7;   { .end method                                  }
  DIR_LIMIT       = 8;   { .limit stack N / .limit locals N             }
  DIR_LINE        = 9;   { .line N                                      }
  DIR_VAR         = 10;  { .var index is name desc from l1 to l2        }
  DIR_THROWS      = 11;  { .throws <classname>                          }
  DIR_CATCH       = 12;  { .catch <class> from <l1> to <l2> using <h>   }
  DIR_INTERFACE   = 13;  { .interface <access> <name>                   }
  DIR_BYTECODE    = 14;  { .bytecode <major>.<minor>                    }
  DIR_ENCLOSING   = 15;  { .enclosing method <class> <method> <desc>    }
  DIR_SIGNATURE   = 16;  { .signature <string>                          }
  DIR_DEPRECATED  = 17;  { .deprecated                                  }
  DIR_ANNOTATION  = 18;  { .annotation / .end annotation                }
  DIR_INNER       = 19;  { .inner class ...                             }
  DIR_STACK       = 20;  { .stack ...                                   }

  { ------------------------------------------------------------------ }
  { Drapeaux d'acces JVM (bit flags)                                    }
  { ------------------------------------------------------------------ }
  ACC_PUBLIC       = $0001;  { public                                   }
  ACC_PRIVATE      = $0002;  { private                                  }
  ACC_PROTECTED    = $0004;  { protected                                }
  ACC_STATIC       = $0008;  { static                                   }
  ACC_FINAL        = $0010;  { final                                    }
  ACC_SYNCHRONIZED = $0020;  { synchronized (methode)                   }
  ACC_SUPER        = $0020;  { super (classe, meme bit que synchronized)}
  ACC_VOLATILE     = $0040;  { volatile (champ)                         }
  ACC_BRIDGE       = $0040;  { bridge (methode)                         }
  ACC_TRANSIENT    = $0080;  { transient (champ)                        }
  ACC_VARARGS      = $0080;  { varargs (methode)                        }
  ACC_NATIVE       = $0100;  { native                                   }
  ACC_INTERFACE    = $0200;  { interface                                 }
  ACC_ABSTRACT     = $0400;  { abstract                                 }
  ACC_STRICT       = $0800;  { strictfp                                 }
  ACC_SYNTHETIC    = $1000;  { synthetic                                }
  ACC_ANNOTATION   = $2000;  { annotation                               }
  ACC_ENUM         = $4000;  { enum                                     }

  { ------------------------------------------------------------------ }
  { Tags du Constant Pool (CONSTANT_xxx)                                }
  { ------------------------------------------------------------------ }
  CP_NONE                = 0;
  CP_UTF8                = 1;   { CONSTANT_Utf8                         }
  CP_INTEGER             = 3;   { CONSTANT_Integer                      }
  CP_FLOAT               = 4;   { CONSTANT_Float                        }
  CP_LONG                = 5;   { CONSTANT_Long  (occupe 2 entrees)     }
  CP_DOUBLE              = 6;   { CONSTANT_Double (occupe 2 entrees)    }
  CP_CLASS               = 7;   { CONSTANT_Class                        }
  CP_STRING              = 8;   { CONSTANT_String                       }
  CP_FIELDREF            = 9;   { CONSTANT_Fieldref                     }
  CP_METHODREF           = 10;  { CONSTANT_Methodref                    }
  CP_INTERFACEMETHODREF  = 11;  { CONSTANT_InterfaceMethodref           }
  CP_NAMEANDTYPE         = 12;  { CONSTANT_NameAndType                  }
  CP_METHODHANDLE        = 15;  { CONSTANT_MethodHandle                 }
  CP_METHODTYPE          = 16;  { CONSTANT_MethodType                   }
  CP_INVOKEDYNAMIC       = 18;  { CONSTANT_InvokeDynamic                }

  { ------------------------------------------------------------------ }
  { Limites des tables (dimensionnement)                                }
  { ------------------------------------------------------------------ }
  MAX_CP       = {$IFDEF FPC}4096{$ELSE}1024{$ENDIF};  { Entrees Constant Pool max          }
  MAX_FIELDS   = {$IFDEF FPC}256{$ELSE}64{$ENDIF};     { Champs max                         }
  MAX_METHODS  = {$IFDEF FPC}256{$ELSE}64{$ENDIF};     { Methodes max                       }
  MAX_CODE     = {$IFDEF FPC}65535{$ELSE}16384{$ENDIF}; { Taille max bytecode par methode    }
  MAX_LABELS   = {$IFDEF FPC}1024{$ELSE}256{$ENDIF};   { Labels max par methode             }
  MAX_EXC      = {$IFDEF FPC}128{$ELSE}32{$ENDIF};     { Exception handlers max par methode }
  MAX_LINES    = {$IFDEF FPC}1024{$ELSE}256{$ENDIF};   { Entrees LineNumberTable max         }
  MAX_FIXUPS   = {$IFDEF FPC}2048{$ELSE}512{$ENDIF};   { Fixups de branches max par methode }
  MAX_IFACES   = 64;     { Interfaces implementees max                  }
  MAX_THROWS   = 32;     { Exceptions declarees (.throws) max           }
  MAX_LOCALS   = 256;    { Variables locales max (.var)                  }
  MAX_INNER    = 64;     { Inner classes max (.inner class)              }

  { ------------------------------------------------------------------ }
  { Constantes magiques Java .class                                     }
  { ------------------------------------------------------------------ }
  CLASS_MAGIC_HI = $CAFE;  { Premiers 2 octets du magic number          }
  CLASS_MAGIC_LO = $BABE;  { Derniers 2 octets du magic number          }
  CLASS_MAJOR_DEFAULT = 49; { Version majeure par defaut (Java 5 / 49.0) }
  CLASS_MINOR_DEFAULT = 0;  { Version mineure par defaut                 }

{ ============================================================================ }
{ Types internes                                                               }
{ ============================================================================ }

Type

  { --- Entree du Constant Pool --- }
  TCPEntry = Record
    Tag     : Integer;       { CP_xxx (0 = entree inutilisee)            }
    StrVal  : String;        { valeur pour CP_UTF8                       }
    IntVal  : LongInt;       { valeur pour CP_INTEGER                    }
    FloatVal: Real;          { valeur pour CP_FLOAT                      }
    Ref1    : Integer;       { premier index reference (class, name, ..) }
    Ref2    : Integer;       { second index reference (type, desc, ..)   }
    HiBytes : LongInt;      { moitie haute pour CP_LONG/CP_DOUBLE       }
    LoBytes : LongInt;      { moitie basse pour CP_LONG/CP_DOUBLE       }
  End;

  { --- Label dans une methode --- }
  TLabelRec = Record
    Name     : String[64];  { nom du label                               }
    Offset   : LongInt;     { position PC (offset dans le bytecode)      }
    Resolved : Boolean;     { True si le label a ete defini              }
  End;

  { --- Gestionnaire d'exception --- }
  TExcHandler = Record
    StartLbl   : String[64];  { label debut de la zone protegee          }
    EndLbl     : String[64];  { label fin de la zone protegee            }
    HandlerLbl : String[64];  { label du gestionnaire                    }
    CatchType  : String;      { nom de la classe d'exception (ou 'all')  }
    StartPC    : Integer;     { offset resolu start                      }
    EndPC      : Integer;     { offset resolu end                        }
    HandlerPC  : Integer;     { offset resolu handler                    }
    CatchIdx   : Integer;     { index CP de la classe (0 si 'all')       }
  End;

  { --- Entree LineNumberTable --- }
  TLineNumRec = Record
    Line   : Integer;   { numero de ligne source                         }
    Offset : Integer;   { offset PC dans le bytecode                     }
  End;

  { --- Fixup de branchement (TODO 13) --- }
  { Enregistre une reference a un label dans le bytecode a patcher.      }
  TFixupRec = Record
    LabelName   : String[64]; { nom du label cible                       }
    PatchOffset : LongInt;    { offset dans le bytecode ou patcher        }
    InstrOffset : LongInt;    { offset de l'instruction (pour calcul rel) }
    Width       : Integer;    { largeur du patch : 2 ou 4 octets          }
  End;

  { --- Entree InnerClasses (TODO 22) --- }
  TInnerClassRec = Record
    InnerClass  : String;     { nom interne de la classe interne          }
    OuterClass  : String;     { nom interne de la classe externe          }
    InnerName   : String;     { nom simple de la classe interne           }
    AccFlags    : Integer;    { drapeaux d'acces de la classe interne     }
  End;

  { --- Buffer de code pour une methode --- }
  TCodeBuf = Array[0..MAX_CODE-1] of Byte;

  { --- Table des labels pour une methode --- }
  TLabelTab = Array[1..MAX_LABELS] of TLabelRec;

  { --- Table des exception handlers pour une methode --- }
  TExcTab = Array[1..MAX_EXC] of TExcHandler;

  { --- Table des numeros de ligne pour une methode --- }
  TLineTab = Array[1..MAX_LINES] of TLineNumRec;

  { --- Table des fixups de branchement pour une methode (TODO 13) --- }
  TFixupTab = Array[1..MAX_FIXUPS] of TFixupRec;

  { --- Pointeurs vers les buffers de methode --- }
  PCodeBuf  = ^TCodeBuf;
  PLabelTab = ^TLabelTab;
  PExcTab   = ^TExcTab;
  PLineTab  = ^TLineTab;
  PFixupTab = ^TFixupTab;

  { --- Entree d'un champ de classe --- }
  TFieldRec = Record
    AccFlags  : Integer;     { drapeaux d'acces (ACC_xxx)                }
    NameIdx   : Integer;     { index CP du nom du champ                  }
    DescIdx   : Integer;     { index CP du descripteur de type           }
    AttrCount : Integer;     { nombre d'attributs                        }
    HasInit   : Boolean;     { True si valeur initiale ConstantValue     }
    InitCPIdx : Integer;     { index CP de la valeur initiale            }
    IsDeprecated : Boolean;  { True si .deprecated (TODO 22)             }
    Signature : String;      { signature generique (TODO 22), '' si aucune }
    Name      : String;      { nom du champ (pour messages d'erreur)     }
    Desc      : String;      { descripteur du champ                      }
  End;

  { --- Entree d'une methode de classe --- }
  TMethodRec = Record
    AccFlags   : Integer;    { drapeaux d'acces (ACC_xxx)                }
    NameIdx    : Integer;    { index CP du nom de la methode             }
    DescIdx    : Integer;    { index CP du descripteur                   }
    MaxStack   : Integer;    { .limit stack                              }
    MaxLocals  : Integer;    { .limit locals                             }
    CodeSize   : LongInt;    { taille du bytecode en octets              }
    Code       : PCodeBuf;   { buffer du bytecode assemble               }
    ExcCount   : Integer;    { nombre d'exception handlers               }
    ExcTab     : PExcTab;    { table des exception handlers              }
    LineCount  : Integer;    { nombre d'entrees LineNumberTable          }
    LineTab    : PLineTab;   { table des numeros de ligne                }
    LabelCount : Integer;    { nombre de labels definis                  }
    Labels     : PLabelTab;  { table des labels                          }
    FixupCount : Integer;    { nombre de fixups de branches (TODO 13)    }
    Fixups     : PFixupTab;  { table des fixups de branches              }
    ThrowCount : Integer;    { nombre de .throws                         }
    ThrowIdx   : Array[1..MAX_THROWS] of Integer; { indices CP des classes }
    Name       : String;     { nom de la methode (pour messages)         }
    Desc       : String;     { descripteur de la methode                 }
    HasCode    : Boolean;    { True si methode non-abstract/non-native   }
    HasStack   : Boolean;    { True si .limit stack defini               }
    HasLocals  : Boolean;    { True si .limit locals defini              }
    IsDeprecated : Boolean;  { True si .deprecated (TODO 22)             }
    Signature  : String;     { signature generique (TODO 22), '' si aucune }
  End;

  { --- Tables principales (tableaux statiques) --- }
  TCPTab     = Array[0..MAX_CP-1] of TCPEntry;
  TFieldTab  = Array[1..MAX_FIELDS] of TFieldRec;
  TMethodTab = Array[1..MAX_METHODS] of TMethodRec;
  TIfaceTab  = Array[1..MAX_IFACES] of Integer;     { indices CP des interfaces }

  { --- Pointeurs pour allocation sur le tas --- }
  PCPTab     = ^TCPTab;
  PFieldTab  = ^TFieldTab;
  PMethodTab = ^TMethodTab;

{ ============================================================================ }
{ Variables globales                                                           }
{ ============================================================================ }

Var

  { --- Fichiers --- }
  SrcFileName   : String;     { nom du fichier source .j                 }
  OutFileName   : String;     { nom du fichier de sortie .class          }
  OutDir        : String;     { repertoire de sortie (-d)                }
  SrcFile       : Text;       { fichier source                           }
  OutFile       : File of Byte; { fichier binaire de sortie              }
  BinPos        : LongInt;    { position courante dans le fichier binaire }
                               { Note : BinPos est synchronisee avec      }
                               { FilePos(OutFile) par les fonctions       }
                               { BinWrite*. BinPatchU2/U4 sauvegardent   }
                               { et restaurent FilePos sans modifier      }
                               { BinPos (car ils ne changent pas la       }
                               { position logique d'ecriture).           }

  { --- Options de ligne de commande --- }
  OptDebug      : Boolean;    { -g : inclure infos de debogage           }
  OptVerbose    : Boolean;    { -v : mode verbeux                        }

  { --- Etat du lexeur --- }
  SrcLine       : String;     { ligne courante du fichier source         }
  SrcLineNum    : Integer;    { numero de la ligne courante              }
  SrcCol        : Integer;    { colonne courante dans SrcLine            }
  SrcEof        : Boolean;    { True si fin de fichier atteinte          }
  CurTok        : Integer;    { type du token courant (TK_xxx)           }
  CurStr        : String;     { texte du token courant                   }
  CurInt        : LongInt;    { valeur si TK_INTEGER                     }
  CurFloat      : Real;       { valeur si TK_FLOAT                       }
  CurDir        : Integer;    { directive si TK_DIRECTIVE (DIR_xxx)       }

  { --- Informations de la classe --- }
  ClassName     : String;     { nom interne de la classe (/ separateur)  }
  SuperName     : String;     { nom de la superclasse                    }
  SourceName    : String;     { nom du fichier source (.source)          }
  ClassAccFlags : Integer;    { drapeaux d'acces de la classe            }
  ClassNameIdx  : Integer;    { index CP de this_class                   }
  SuperNameIdx  : Integer;    { index CP de super_class                  }
  SourceIdx     : Integer;    { index CP de SourceFile                   }

  { --- Attributs supplementaires de classe (TODO 22) --- }
  ClassDeprecated : Boolean;   { True si .deprecated au niveau classe    }
  ClassSignature  : String;    { signature generique de la classe        }
  EnclosingClass  : String;    { classe englobante (.enclosing)          }
  EnclosingMethod : String;    { methode englobante (.enclosing)         }
  EnclosingDesc   : String;    { descripteur methode englobante          }
  InnerTab        : Array[1..MAX_INNER] of TInnerClassRec;
  InnerCount      : Integer;   { nombre d'inner classes                  }

  { --- Version du fichier .class --- }
  ClassMajor    : Integer;    { version majeure (defaut 49)              }
  ClassMinor    : Integer;    { version mineure (defaut 0)               }

  { --- Tables principales (allouees sur le tas) --- }
  CPTab         : PCPTab;     { Constant Pool                            }
  CPCount       : Integer;    { nombre d'entrees dans le CP (1-base)     }

  FieldTab      : PFieldTab;  { table des champs                         }
  FieldCount    : Integer;    { nombre de champs                         }

  MethodTab     : PMethodTab; { table des methodes                       }
  MethodCount   : Integer;    { nombre de methodes                       }

  { --- Interfaces implementees --- }
  IfaceTab      : TIfaceTab;  { indices CP des interfaces                }
  IfaceCount    : Integer;    { nombre d'interfaces                      }

  { --- Methode courante (pendant l'assemblage) --- }
  InMethod      : Boolean;    { True si entre .method et .end method     }
  CurMethod     : Integer;    { index dans MethodTab de la methode       }

  { --- Compteurs et statistiques --- }
  ErrorCount    : Integer;    { nombre d'erreurs                         }
  WarnCount     : Integer;    { nombre d'avertissements                  }

{ ============================================================================ }
{ Utilitaires chaines                                                          }
{ ============================================================================ }

Function IntToStr_(n: LongInt): String;
Var s: String;
Begin
 Str(n, s);
 IntToStr_ := s;
End;

Function IntToHex_(n: LongInt; digits: Integer): String;
Const hexChars: String = '0123456789ABCDEF';
Var s: String; i: Integer;
Begin
 s := '';
 For i := 1 to digits do
 Begin
  s := hexChars[(n and $F) + 1] + s;
  n := n shr 4;
 End;
 IntToHex_ := s;
End;

Function StrToInt_(Const s: String): LongInt;
Var v: LongInt; code: Integer;
Begin
 Val(s, v, code);
 If code <> 0 Then v := 0;
 StrToInt_ := v;
End;

{ --- RealToHiLo : convertir un Real en paire hi/lo IEEE 754 double --- }
{ Utilise type-punning via 'absolute' pour extraire les 8 octets de la  }
{ representation IEEE 754 du Double, puis les regrouper en hi et lo.    }
Procedure RealToHiLo(f: Real; Var hi, lo: LongInt);
Var d: Double; bytes: Array[0..7] of Byte absolute d;
Begin
 d := f;
 { Double est en little-endian sur x86 : bytes[0] = LSB, bytes[7] = MSB }
 { hi = octets 7,6,5,4 (big-endian), lo = octets 3,2,1,0               }
 hi := (LongInt(bytes[7]) shl 24) or (LongInt(bytes[6]) shl 16)
    or (LongInt(bytes[5]) shl 8) or LongInt(bytes[4]);
 lo := (LongInt(bytes[3]) shl 24) or (LongInt(bytes[2]) shl 16)
    or (LongInt(bytes[1]) shl 8) or LongInt(bytes[0]);
End;

Function UpCaseStr(Const s: String): String;
Var i: Integer; r: String;
Begin
 r := s;
 For i := 1 to Length(r) do
  r[i] := UpCase(r[i]);
 UpCaseStr := r;
End;

{ ============================================================================ }
{ Lexeur : lecture source et tokenisation                                      }
{ ============================================================================ }

{ --- Declarations forward --- }
Procedure SrcOpen(Const FileName: String); Forward;
Procedure SrcClose; Forward;
Function  SrcGetChar: Char; Forward;
Procedure SrcUnget; Forward;
Function  SrcPeek: Char; Forward;
Procedure SkipWhitespace; Forward;
Procedure SkipComment; Forward;
Procedure LexIdent; Forward;
Procedure LexNumber(firstCh: Char); Forward;
Procedure LexString; Forward;
Procedure LexDirective; Forward;
Procedure NextToken; Forward;
Procedure Consume; Forward;
Procedure Expect(tok: Integer; Const what: String); Forward;
Procedure ExpectStr(Const s: String); Forward;
Procedure ExpectNewline; Forward;

{ --- Declarations forward TODO 03 : erreurs, avertissements, bilan --- }
Procedure Error(Const msg: String); Forward;
Procedure Warning(Const msg: String); Forward;
Procedure FatalError(Const msg: String); Forward;
Procedure ErrorAt(line: Integer; Const msg: String); Forward;
Procedure SkipToEOL; Forward;
Procedure SkipToDirective; Forward;
Procedure BilanAssemblage; Forward;

{ --- Declarations forward TODO 04 : Bassin de constantes (Constant Pool) --- }
Procedure CPInit; Forward;
Function  CPAddUtf8(Const s: String): Integer; Forward;
Function  CPAddInteger(n: LongInt): Integer; Forward;
Function  CPAddFloat(f: Real): Integer; Forward;
Function  CPAddLong(hi, lo: LongInt): Integer; Forward;
Function  CPAddDouble(hi, lo: LongInt): Integer; Forward;
Function  CPAddClass(Const name: String): Integer; Forward;
Function  CPAddString(Const s: String): Integer; Forward;
Function  CPAddNameAndType(Const name, desc: String): Integer; Forward;
Function  CPAddFieldRef(Const cls, name, desc: String): Integer; Forward;
Function  CPAddMethodRef(Const cls, name, desc: String): Integer; Forward;
Function  CPAddInterfaceMethodRef(Const cls, name, desc: String): Integer; Forward;
Function  CPAddMethodHandle(kind, ref: Integer): Integer; Forward;
Function  CPAddMethodType(Const desc: String): Integer; Forward;
Function  CPAddInvokeDynamic(bootstrap, nat: Integer): Integer; Forward;
Function  CPFind(tag: Integer; Const val: String): Integer; Forward;
Function  CPEnsureUtf8(Const s: String): Integer; Forward;
Function  CPEnsureClass(Const name: String): Integer; Forward;
Function  CPEnsureNameAndType(Const name, desc: String): Integer; Forward;

{ --- Declarations forward TODO 05 : Ecriture binaire du fichier .class --- }
Procedure BinOpen(Const filename: String); Forward;
Procedure BinClose; Forward;
Procedure BinWriteU1(b: Byte); Forward;
Procedure BinWriteU2(w: Integer); Forward;
Procedure BinWriteU4(d: LongInt); Forward;
Procedure BinWriteBytes(Var buf; len: Integer); Forward;
Procedure BinWriteUtf8(Const s: String); Forward;
Procedure BinWriteFloat(f: Real); Forward;
Procedure BinWriteDouble(hi, lo: LongInt); Forward;
Procedure BinWriteLong(hi, lo: LongInt); Forward;
Function  BinGetPos: LongInt; Forward;
Procedure BinPatchU2(pos: LongInt; w: Integer); Forward;
Procedure BinPatchU4(pos: LongInt; d: LongInt); Forward;

{ --- Declarations forward TODO 06 : Directives de classe --- }
Function  ConvertClassName(Const name: String): String; Forward;
Function  ParseAccessFlags: Integer; Forward;
Procedure ParseClassDirective; Forward;
Procedure ParseSuperDirective; Forward;
Procedure ParseImplementsDirective; Forward;
Procedure ParseSourceDirective; Forward;
Procedure ParseInterfaceDirective; Forward;
Procedure ParseBytecodeDirective; Forward;
Procedure ParseDirectives; Forward;

{ --- Declarations forward TODO 07 : Directives de champs --- }
Function  ValidFieldDescriptor(Const desc: String): Boolean; Forward;
Function  AddField(flags: Integer; Const name, desc: String): Integer; Forward;
Procedure ParseFieldInitValue(fIdx: Integer); Forward;
Procedure ParseFieldDirective; Forward;

{ --- Declarations forward TODO 08 : Directives de methodes --- }
Procedure EnterMethod(flags: Integer; Const name, desc: String); Forward;
Procedure LeaveMethod; Forward;
Procedure ParseMethodDirective; Forward;
Procedure ParseEndMethod; Forward;
Procedure ParseLimitDirective; Forward;
Procedure ParseLineDirective; Forward;
Procedure ParseThrowsDirective; Forward;

{ --- Declarations forward TODO 09 : Descripteurs de types JVM --- }
Function  ParseTypeDescriptor(Const desc: String; Var pos: Integer): Boolean; Forward;
Function  DescriptorSlotSize(Const desc: String): Integer; Forward;
Function  ParseMethodDescriptor(Const desc: String): Boolean; Forward;
Function  DescriptorParamSlots(Const desc: String; isStatic: Boolean): Integer; Forward;
Function  DescriptorReturnSlots(Const desc: String): Integer; Forward;
Function  ValidateDescriptor(Const desc: String): Boolean; Forward;
Function  ValidateMethodDescriptor(Const desc: String): Boolean; Forward;
Procedure AutoLocals(mIdx: Integer); Forward;
Procedure AutoStack(mIdx: Integer); Forward;

{ --- Declarations forward TODO 10 : Opcodes de chargement et stockage --- }
Procedure EmitByte(b: Byte); Forward;
Function  ParseInstruction: Boolean; Forward;

{ --- Declarations forward TODO 13 : Opcodes de controle de flux --- }
Procedure RecordFixup(Const lbl: String; patchOff, instrOff: LongInt; w: Integer); Forward;
Procedure EmitBranchPlaceholder(w: Integer); Forward;

{ --- Declarations forward TODO 14 : Opcodes d'invocation de methodes --- }
Function ParseMethodSpec(Const spec: String; Var cls, mname, desc: String): Boolean; Forward;

{ --- Declarations forward TODO 17 : Opcodes d'acces aux champs --- }
Function ParseFieldSpec(Const spec: String; Var cls, fname: String): Boolean; Forward;

{ --- Declarations forward TODO 19 : Labels, resolution des sauts --- }
Function  LabelFind(Const name: String): Integer; Forward;
Procedure LabelAdd(Const name: String); Forward;
Procedure LabelResolve; Forward;

{ --- Declarations forward TODO 20 : Attribut Code : generation binaire --- }
Procedure EmitCodeAttribute(mIdx: Integer); Forward;

{ --- Declarations forward TODO 21 : Directives exceptions (.catch, .throws) --- }
Procedure ParseCatchDirective; Forward;
Procedure EmitExceptionsAttribute(mIdx: Integer); Forward;

{ --- Declarations forward TODO 22 : Attributs supplementaires --- }
Procedure ParseDeprecatedDirective; Forward;
Procedure ParseSignatureDirective; Forward;
Procedure ParseInnerClassDirective; Forward;
Procedure ParseEnclosingMethodDirective; Forward;
Procedure EmitSourceFileAttr; Forward;
Procedure EmitDeprecatedAttr; Forward;
Procedure EmitSignatureAttr(Const sig: String); Forward;
Procedure EmitInnerClassesAttr; Forward;
Procedure EmitEnclosingMethodAttr; Forward;

{ --- Declarations forward TODO 23 : Programme principal et generation .class --- }
Procedure ParseCommandLine; Forward;
Procedure CPEmitAll; Forward;
Procedure EmitFieldInfo(fIdx: Integer); Forward;
Procedure EmitMethodInfo(mIdx: Integer); Forward;

{ ---------- Ouverture et fermeture du fichier source ---------- }

Procedure SrcOpen(Const FileName: String);
Begin
 Assign(SrcFile, FileName);
 Reset(SrcFile);
 If IOResult <> 0 Then
  FatalError('impossible d''ouvrir ' + FileName);
 SrcLine    := '';
 SrcLineNum := 0;
 SrcCol     := 1;
 SrcEof     := False;
End;

Procedure SrcClose;
Begin
 Close(SrcFile);
 If IOResult <> 0 Then { ignorer erreur fermeture };
End;

{ ---------- Lecture ligne par ligne ---------- }

Procedure SrcRefillLine;
Begin
 If EOF(SrcFile) Then
 Begin
  SrcEof  := True;
  SrcLine := '';
  SrcCol  := 1;
  Exit;
 End;
 ReadLn(SrcFile, SrcLine);
 Inc(SrcLineNum);
 SrcCol := 1;
End;

{ ---------- Lecture caractere par caractere ---------- }

Function SrcGetChar: Char;
Var ch: Char;
Begin
 { Charger la premiere ligne si necessaire }
 If (SrcLineNum = 0) And (Not SrcEof) Then
  SrcRefillLine;

 If SrcEof Then
 Begin SrcGetChar := #0; Exit; End;

 If SrcCol > Length(SrcLine) + 1 Then
 Begin
  { On a deja retourne le LF synthetique, charger la ligne suivante }
  If Not EOF(SrcFile) Then SrcRefillLine
  Else Begin SrcEof := True; SrcGetChar := #0; Exit; End;
 End;

 If SrcCol > Length(SrcLine) Then
 Begin
  { Fin de ligne courante -> retourner LF synthetique }
  { Positionner SrcCol au-dela pour que le prochain appel charge  }
  { la ligne suivante, tout en permettant SrcUnget de revenir ici }
  SrcCol := Length(SrcLine) + 2;
  SrcGetChar := #10;
  Exit;
 End;

 ch := SrcLine[SrcCol];
 Inc(SrcCol);
 SrcGetChar := ch;
End;

{ Remet la position d'un caractere en arriere }
Procedure SrcUnget;
Begin
 If SrcCol > 1 Then Dec(SrcCol);
End;

{ Regarde le caractere courant sans avancer }
Function SrcPeek: Char;
Begin
 If SrcEof Then
 Begin SrcPeek := #0; Exit; End;
 If (SrcLineNum = 0) And (Not SrcEof) Then
  SrcRefillLine;
 If SrcEof Then
 Begin SrcPeek := #0; Exit; End;
 If SrcCol > Length(SrcLine) Then
  SrcPeek := #10
 Else
  SrcPeek := SrcLine[SrcCol];
End;

{ ---------- Espaces et commentaires ---------- }

{ Sauter espaces et tabulations (pas les fins de ligne) }
Procedure SkipWhitespace;
Var ch: Char;
Begin
 While Not SrcEof do
 Begin
  ch := SrcPeek;
  If (ch = ' ') Or (ch = #9) Then
   SrcGetChar
  Else
   Exit;
 End;
End;

{ Sauter le commentaire Jasmin : ';' jusqu'en fin de ligne }
Procedure SkipComment;
Var ch: Char;
Begin
 Repeat
  ch := SrcGetChar;
 Until (ch = #10) Or (ch = #0);
End;

{ ---------- LexIdent : identifiant, mnemonique ou label ---------- }

Procedure LexIdent;
Var s: String; ch: Char;
Begin
 s := '';
 Repeat
  ch := SrcGetChar;
  If (ch >= 'A') And (ch <= 'Z') Then s := s + ch
  Else If (ch >= 'a') And (ch <= 'z') Then s := s + ch
  Else If (ch >= '0') And (ch <= '9') Then s := s + ch
  Else If ch = '_' Then s := s + ch
  Else If ch = '$' Then s := s + ch
  Else If ch = '/' Then s := s + ch  { noms de classes JVM : java/lang/Object }
  Else If ch = '<' Then s := s + ch  { <init>, <clinit> }
  Else If ch = '>' Then s := s + ch  { <init>, <clinit> }
  Else If ch = ';' Then s := s + ch  { descripteurs JVM : Ljava/lang/String; }
  Else If ch = '(' Then s := s + ch  { descripteurs de methodes : (II)V }
  Else If ch = ')' Then s := s + ch  { descripteurs de methodes : (II)V }
  Else If ch = '[' Then s := s + ch  { descripteurs de tableaux : [I, [[ }
  Else
  Begin
   { Verifier si c'est un label (suivi de ':') }
   If ch = ':' Then
   Begin
    CurTok := TK_LABEL;
    CurStr := s;
    Exit;
   End;
   SrcUnget;
   Break;
  End;
 Until Length(s) >= 255;
 CurTok := TK_IDENT;
 CurStr := s;
End;

{ ---------- LexNumber : entier/flottant avec prefixes ---------- }

Procedure LexNumber(firstCh: Char);
Var s      : String;
    intVal : LongInt;
    ch     : Char;
    isFloat: Boolean;
    isHex  : Boolean;
    code   : Integer;
    fltVal : Real;
Begin
 s       := '' + firstCh;
 intVal  := Ord(firstCh) - Ord('0');
 isFloat := False;
 isHex   := False;

 { Detecter prefixe hexadecimal 0x ou 0X }
 If firstCh = '0' Then
 Begin
  ch := SrcPeek;
  If (ch = 'x') Or (ch = 'X') Then
  Begin
   SrcGetChar; { consommer le 'x' }
   isHex  := True;
   intVal := 0;
   s      := '0x';
   { Accumuler les chiffres hexadecimaux }
   Repeat
    ch := SrcPeek;
    If ((ch >= '0') And (ch <= '9')) Or
       ((ch >= 'a') And (ch <= 'f')) Or
       ((ch >= 'A') And (ch <= 'F')) Then
    Begin
     SrcGetChar;
     s := s + ch;
     If (ch >= '0') And (ch <= '9') Then
      intVal := intVal * 16 + (Ord(ch) - Ord('0'))
     Else If (ch >= 'a') And (ch <= 'f') Then
      intVal := intVal * 16 + (Ord(ch) - Ord('a') + 10)
     Else
      intVal := intVal * 16 + (Ord(ch) - Ord('A') + 10);
    End
    Else
     Break;
   Until False;
   CurTok   := TK_INTEGER;
   CurStr   := s;
   CurInt   := intVal;
   CurFloat := 0.0;
   { Suffixe L optionnel }
   ch := SrcPeek;
   If (ch = 'L') Or (ch = 'l') Then SrcGetChar;
   Exit;
  End;
 End;

 { Accumuler les chiffres decimaux }
 Repeat
  ch := SrcPeek;
  If (ch >= '0') And (ch <= '9') Then
  Begin
   SrcGetChar;
   s := s + ch;
   intVal := intVal * 10 + (Ord(ch) - Ord('0'));
  End
  Else
   Break;
 Until False;

 { Partie decimale : point suivi de chiffres }
 ch := SrcPeek;
 If ch = '.' Then
 Begin
  SrcGetChar;
  s := s + '.';
  isFloat := True;
  Repeat
   ch := SrcPeek;
   If (ch >= '0') And (ch <= '9') Then
   Begin
    SrcGetChar;
    s := s + ch;
   End
   Else
    Break;
  Until False;
 End;

 { Exposant E ou e }
 ch := SrcPeek;
 If (ch = 'E') Or (ch = 'e') Then
 Begin
  SrcGetChar;
  s := s + ch;
  isFloat := True;
  ch := SrcPeek;
  If (ch = '+') Or (ch = '-') Then
  Begin
   SrcGetChar;
   s := s + ch;
  End;
  Repeat
   ch := SrcPeek;
   If (ch >= '0') And (ch <= '9') Then
   Begin
    SrcGetChar;
    s := s + ch;
   End
   Else
    Break;
  Until False;
 End;

 { Suffixes L, F, D }
 ch := SrcPeek;
 If (ch = 'L') Or (ch = 'l') Then
 Begin SrcGetChar; { long } End
 Else If (ch = 'F') Or (ch = 'f') Then
 Begin SrcGetChar; isFloat := True; End
 Else If (ch = 'D') Or (ch = 'd') Then
 Begin SrcGetChar; isFloat := True; End;

 If isFloat Then
 Begin
  CurTok := TK_FLOAT;
  CurStr := s;
  Val(s, fltVal, code);
  If code <> 0 Then fltVal := 0.0;
  CurFloat := fltVal;
  CurInt   := Round(fltVal);
 End
 Else
 Begin
  CurTok   := TK_INTEGER;
  CurStr   := s;
  CurInt   := intVal;
  CurFloat := 0.0;
 End;
End;

{ ---------- LexString : "..." avec echappement ---------- }

Procedure LexString;
Var s: String; ch: Char;
Begin
 s := '';
 Repeat
  ch := SrcGetChar;
  If ch = '"' Then Break  { fin de la chaine }
  Else If (ch = #10) Or (ch = #0) Then Break  { chaine non fermee }
  Else If ch = '\' Then
  Begin
   { Sequence d'echappement }
   ch := SrcGetChar;
   Case ch of
    'n' : s := s + #10;
    't' : s := s + #9;
    'r' : s := s + #13;
    '\' : s := s + '\';
    '"' : s := s + '"';
    '0' : s := s + #0;
   Else
    s := s + '\' + ch;  { echappement inconnu : garder tel quel }
   End;
  End
  Else
   s := s + ch;
 Until Length(s) >= 255;
 CurTok := TK_STRING;
 CurStr := s;
End;

{ ---------- LexDirective : mot commencant par '.' ---------- }

Function LookupDirective(Const s: String): Integer;
Var u: String;
Begin
 u := UpCaseStr(s);
 LookupDirective := DIR_NONE;
 If      u = '.CLASS'      Then LookupDirective := DIR_CLASS
 Else If u = '.SUPER'      Then LookupDirective := DIR_SUPER
 Else If u = '.IMPLEMENTS' Then LookupDirective := DIR_IMPLEMENTS
 Else If u = '.SOURCE'     Then LookupDirective := DIR_SOURCE
 Else If u = '.FIELD'      Then LookupDirective := DIR_FIELD
 Else If u = '.METHOD'     Then LookupDirective := DIR_METHOD
 Else If u = '.END'        Then LookupDirective := DIR_END
 Else If u = '.LIMIT'      Then LookupDirective := DIR_LIMIT
 Else If u = '.LINE'       Then LookupDirective := DIR_LINE
 Else If u = '.VAR'        Then LookupDirective := DIR_VAR
 Else If u = '.THROWS'     Then LookupDirective := DIR_THROWS
 Else If u = '.CATCH'      Then LookupDirective := DIR_CATCH
 Else If u = '.INTERFACE'  Then LookupDirective := DIR_INTERFACE
 Else If u = '.BYTECODE'   Then LookupDirective := DIR_BYTECODE
 Else If u = '.ENCLOSING'  Then LookupDirective := DIR_ENCLOSING
 Else If u = '.SIGNATURE'  Then LookupDirective := DIR_SIGNATURE
 Else If u = '.DEPRECATED' Then LookupDirective := DIR_DEPRECATED
 Else If u = '.ANNOTATION' Then LookupDirective := DIR_ANNOTATION
 Else If u = '.INNER'      Then LookupDirective := DIR_INNER
 Else If u = '.STACK'      Then LookupDirective := DIR_STACK;
End;

Procedure LexDirective;
Var s: String; ch: Char;
Begin
 s := '.';
 Repeat
  ch := SrcPeek;
  If ((ch >= 'a') And (ch <= 'z')) Or
     ((ch >= 'A') And (ch <= 'Z')) Or
     ((ch >= '0') And (ch <= '9')) Or
     (ch = '_') Then
  Begin
   SrcGetChar;
   s := s + ch;
  End
  Else
   Break;
 Until Length(s) >= 255;
 CurTok := TK_DIRECTIVE;
 CurStr := s;
 CurDir := LookupDirective(s);
End;

{ ---------- NextToken : dispatcher principal ---------- }

Procedure NextToken;
Var ch: Char;
Begin
 CurStr   := '';
 CurInt   := 0;
 CurFloat := 0.0;
 CurDir   := DIR_NONE;

 { Sauter les espaces et tabulations }
 SkipWhitespace;

 { Verifier fin de fichier }
 If SrcEof Then
 Begin
  CurTok := TK_EOF;
  CurStr := '';
  Exit;
 End;

 ch := SrcGetChar;

 { Si on est tombe sur un espace/tab apres un saut de ligne      }
 { (SrcRefillLine peut etre appele dans SrcGetChar quand SrcCol   }
 { depasse Length+1), re-sauter les blancs et relire un caractere }
 If (ch = ' ') Or (ch = #9) Then
 Begin
  SkipWhitespace;
  If SrcEof Then
  Begin CurTok := TK_EOF; CurStr := ''; Exit; End;
  ch := SrcGetChar;
 End;

 { Fin de fichier }
 If ch = #0 Then
 Begin CurTok := TK_EOF; Exit; End;

 { Fin de ligne }
 If ch = #10 Then
 Begin CurTok := TK_NEWLINE; CurStr := #10; Exit; End;
 If ch = #13 Then
 Begin
  If SrcPeek = #10 Then SrcGetChar;
  CurTok := TK_NEWLINE;
  CurStr := #10;
  Exit;
 End;

 { Commentaire Jasmin : ; jusqu'en fin de ligne }
 If ch = ';' Then
 Begin
  SkipComment;
  CurTok := TK_NEWLINE;
  CurStr := #10;
  Exit;
 End;

 { Directive : mot commencant par '.' }
 If ch = '.' Then
 Begin
  { Verifier si c'est une lettre (directive) }
  If ((SrcPeek >= 'a') And (SrcPeek <= 'z')) Or
     ((SrcPeek >= 'A') And (SrcPeek <= 'Z')) Then
  Begin
   LexDirective;
   Exit;
  End;
  { Sinon c'est un point simple }
  CurTok := TK_DOT;
  CurStr := '.';
  Exit;
 End;

 { Chaine : "..." }
 If ch = '"' Then
 Begin LexString; Exit; End;

 { Nombre : commence par un chiffre ou signe negatif suivi de chiffre }
 If (ch >= '0') And (ch <= '9') Then
 Begin LexNumber(ch); Exit; End;

 If (ch = '-') Then
 Begin
  If (SrcPeek >= '0') And (SrcPeek <= '9') Then
  Begin
   { Nombre negatif }
   ch := SrcGetChar;
   LexNumber(ch);
   CurInt   := -CurInt;
   CurFloat := -CurFloat;
   CurStr   := '-' + CurStr;
   Exit;
  End;
  CurTok := TK_MINUS;
  CurStr := '-';
  Exit;
 End;

 { Identifiant : commence par une lettre, _, $, <, (, [, ] }
 { En Jasmin, les descripteurs JVM sont des tokens complets :
   main([Ljava/lang/String;)V, (II)V, Ljava/io/PrintStream; }
 If ((ch >= 'A') And (ch <= 'Z')) Or
    ((ch >= 'a') And (ch <= 'z')) Or
    (ch = '_') Or (ch = '$') Or (ch = '<') Or
    (ch = '(') Or (ch = '[') Then
 Begin
  SrcUnget;
  LexIdent;
  Exit;
 End;

 { Symboles simples }
 Case ch of
  ':': Begin CurTok := TK_COLON;    CurStr := ':'; End;
  '=': Begin CurTok := TK_EQUAL;    CurStr := '='; End;
  '(': Begin CurTok := TK_LPAREN;   CurStr := '('; End;
  ')': Begin CurTok := TK_RPAREN;   CurStr := ')'; End;
  '/': Begin CurTok := TK_SLASH;    CurStr := '/'; End;
  '[': Begin CurTok := TK_LBRACKET; CurStr := '['; End;
  ']': Begin CurTok := TK_RBRACKET; CurStr := ']'; End;
  '+': Begin CurTok := TK_PLUS;     CurStr := '+'; End;
 Else
  Begin
   CurTok := TK_UNKNOWN;
   CurStr := ch;
  End;
 End;
End;

{ ---------- Helpers de parsing ---------- }

Procedure Consume;
Begin
 NextToken;
End;

Procedure Expect(tok: Integer; Const what: String);
Begin
 If CurTok <> tok Then
  Error(what + ' attendu');
 NextToken;
End;

Procedure ExpectStr(Const s: String);
Begin
 If CurStr <> s Then
  Error('"' + s + '" attendu, lu "' + CurStr + '"');
 NextToken;
End;

Procedure ExpectNewline;
Begin
 If (CurTok <> TK_NEWLINE) And (CurTok <> TK_EOF) Then
  Error('fin de ligne attendue');
 If CurTok = TK_NEWLINE Then NextToken;
End;

{ ============================================================================ }
{ Gestion des erreurs, des avertissements et du bilan                          }
{ ============================================================================ }

{ --- Error : erreur non fatale avec fichier:ligne --- }
Procedure Error(Const msg: String);
Begin
 WriteLn(SrcFileName, ':', SrcLineNum, ': erreur: ', msg);
 Inc(ErrorCount);
End;

{ --- Warning : avertissement non bloquant --- }
Procedure Warning(Const msg: String);
Begin
 WriteLn(SrcFileName, ':', SrcLineNum, ': attention: ', msg);
 Inc(WarnCount);
End;

{ --- FatalError : erreur irrecuperable, arret immediat --- }
Procedure FatalError(Const msg: String);
Begin
 WriteLn(SrcFileName, ':', SrcLineNum, ': erreur fatale: ', msg);
 Inc(ErrorCount);
 Halt(1);
End;

{ --- ErrorAt : erreur avec numero de ligne specifique --- }
Procedure ErrorAt(line: Integer; Const msg: String);
Begin
 WriteLn(SrcFileName, ':', line, ': erreur: ', msg);
 Inc(ErrorCount);
End;

{ --- SkipToEOL : consommer jusqu'en fin de ligne pour resynchroniser --- }
Procedure SkipToEOL;
Begin
 While (CurTok <> TK_NEWLINE) And (CurTok <> TK_EOF) do
  NextToken;
 If CurTok = TK_NEWLINE Then NextToken;
End;

{ --- SkipToDirective : consommer jusqu'a la prochaine directive --- }
Procedure SkipToDirective;
Begin
 While (CurTok <> TK_DIRECTIVE) And (CurTok <> TK_EOF) do
  NextToken;
End;

{ --- BilanAssemblage : afficher les statistiques de l'assemblage --- }
Procedure BilanAssemblage;
Var totalCode: LongInt; i: Integer;
Begin
 WriteLn;
 WriteLn('--- Bilan de l''assemblage ---');
 WriteLn('  Fichier source    : ', SrcFileName);
 WriteLn('  Lignes lues       : ', SrcLineNum);
 WriteLn('  Constant Pool     : ', CPCount - 1, ' entree(s)');
 WriteLn('  Champs            : ', FieldCount);
 WriteLn('  Methodes          : ', MethodCount);
 totalCode := 0;
 For i := 1 to MethodCount do
  totalCode := totalCode + MethodTab^[i].CodeSize;
 WriteLn('  Taille bytecode   : ', totalCode, ' octet(s)');
 WriteLn('  Interfaces        : ', IfaceCount);
 WriteLn('  Erreurs           : ', ErrorCount);
 WriteLn('  Avertissements    : ', WarnCount);
 If ErrorCount = 0 Then
  WriteLn('  Resultat          : OK')
 Else
  WriteLn('  Resultat          : ECHEC');
End;

{ ============================================================================ }
{ Bassin de constantes (Constant Pool) : structures et gestion                 }
{ ============================================================================ }

{ --- CPInit : initialiser le bassin (entree 0 = inutilisee) --- }
Procedure CPInit;
Var i: Integer;
Begin
 CPCount := 1;  { entree 0 inutilisee dans la spec JVM }
 For i := 0 to MAX_CP - 1 do
 Begin
  CPTab^[i].Tag      := CP_NONE;
  CPTab^[i].StrVal   := '';
  CPTab^[i].IntVal   := 0;
  CPTab^[i].FloatVal := 0.0;
  CPTab^[i].Ref1     := 0;
  CPTab^[i].Ref2     := 0;
  CPTab^[i].HiBytes  := 0;
  CPTab^[i].LoBytes  := 0;
 End;
End;

{ --- CPFind : rechercher une entree existante (deduplication) --- }
{ Retourne l'index si trouvee, 0 sinon.                           }
{ Pour CP_UTF8 : compare Tag et StrVal.                           }
{ Pour CP_INTEGER : compare Tag et IntVal.                        }
{ Pour CP_FLOAT : compare Tag et FloatVal.                        }
{ Pour CP_CLASS/CP_STRING : compare Tag et Ref1.                  }
{ Pour CP_NAMEANDTYPE : compare Tag, Ref1 et Ref2.               }
{ Pour CP_FIELDREF/CP_METHODREF/CP_INTERFACEMETHODREF :           }
{   compare Tag, Ref1 et Ref2.                                    }
{ Pour CP_LONG/CP_DOUBLE : compare Tag, HiBytes et LoBytes.      }
Function CPFind(tag: Integer; Const val: String): Integer;
Var i: Integer;
Begin
 CPFind := 0;
 For i := 1 to CPCount - 1 do
 Begin
  If CPTab^[i].Tag = tag Then
  Begin
   Case tag of
    CP_UTF8:
     If CPTab^[i].StrVal = val Then Begin CPFind := i; Exit; End;
    CP_INTEGER:
     If CPTab^[i].IntVal = StrToInt_(val) Then Begin CPFind := i; Exit; End;
    CP_FLOAT:
     { Pas de deduplication float par chaine car les conversions }
     { float<->string peuvent perdre en precision                }
     ;
    CP_CLASS, CP_STRING:
     If CPTab^[i].StrVal = val Then Begin CPFind := i; Exit; End;
   End;
  End;
 End;
End;

{ --- CPAddUtf8 : ajouter CONSTANT_Utf8, retourner index --- }
Function CPAddUtf8(Const s: String): Integer;
Begin
 If CPCount >= MAX_CP Then
 Begin
  Error('Constant Pool plein (max ' + IntToStr_(MAX_CP) + ')');
  CPAddUtf8 := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag    := CP_UTF8;
 CPTab^[CPCount].StrVal := s;
 CPAddUtf8 := CPCount;
 Inc(CPCount);
End;

{ --- CPAddInteger : ajouter CONSTANT_Integer --- }
Function CPAddInteger(n: LongInt): Integer;
Begin
 If CPCount >= MAX_CP Then
 Begin
  Error('Constant Pool plein');
  CPAddInteger := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag    := CP_INTEGER;
 CPTab^[CPCount].IntVal := n;
 CPAddInteger := CPCount;
 Inc(CPCount);
End;

{ --- CPAddFloat : ajouter CONSTANT_Float --- }
Function CPAddFloat(f: Real): Integer;
Begin
 If CPCount >= MAX_CP Then
 Begin
  Error('Constant Pool plein');
  CPAddFloat := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag      := CP_FLOAT;
 CPTab^[CPCount].FloatVal := f;
 CPAddFloat := CPCount;
 Inc(CPCount);
End;

{ --- CPAddLong : ajouter CONSTANT_Long (occupe 2 entrees) --- }
Function CPAddLong(hi, lo: LongInt): Integer;
Begin
 If CPCount + 1 >= MAX_CP Then
 Begin
  Error('Constant Pool plein');
  CPAddLong := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag     := CP_LONG;
 CPTab^[CPCount].HiBytes := hi;
 CPTab^[CPCount].LoBytes := lo;
 CPAddLong := CPCount;
 Inc(CPCount);
 { Seconde entree inutilisable (spec JVM 4.4.5) }
 CPTab^[CPCount].Tag := CP_NONE;
 Inc(CPCount);
End;

{ --- CPAddDouble : ajouter CONSTANT_Double (occupe 2 entrees) --- }
Function CPAddDouble(hi, lo: LongInt): Integer;
Begin
 If CPCount + 1 >= MAX_CP Then
 Begin
  Error('Constant Pool plein');
  CPAddDouble := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag     := CP_DOUBLE;
 CPTab^[CPCount].HiBytes := hi;
 CPTab^[CPCount].LoBytes := lo;
 CPAddDouble := CPCount;
 Inc(CPCount);
 { Seconde entree inutilisable (spec JVM 4.4.5) }
 CPTab^[CPCount].Tag := CP_NONE;
 Inc(CPCount);
End;

{ --- CPAddClass : ajouter CONSTANT_Class (ref vers Utf8) --- }
Function CPAddClass(Const name: String): Integer;
Var nameIdx: Integer;
Begin
 nameIdx := CPEnsureUtf8(name);
 If CPCount >= MAX_CP Then
 Begin
  Error('Constant Pool plein');
  CPAddClass := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag    := CP_CLASS;
 CPTab^[CPCount].Ref1   := nameIdx;
 CPTab^[CPCount].StrVal := name;  { garder le nom pour deduplication }
 CPAddClass := CPCount;
 Inc(CPCount);
End;

{ --- CPAddString : ajouter CONSTANT_String (ref vers Utf8) --- }
Function CPAddString(Const s: String): Integer;
Var utf8Idx: Integer;
Begin
 utf8Idx := CPEnsureUtf8(s);
 If CPCount >= MAX_CP Then
 Begin
  Error('Constant Pool plein');
  CPAddString := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag    := CP_STRING;
 CPTab^[CPCount].Ref1   := utf8Idx;
 CPTab^[CPCount].StrVal := s;  { garder la valeur pour deduplication }
 CPAddString := CPCount;
 Inc(CPCount);
End;

{ --- CPAddNameAndType : ajouter CONSTANT_NameAndType --- }
Function CPAddNameAndType(Const name, desc: String): Integer;
Var nameIdx, descIdx: Integer;
Begin
 nameIdx := CPEnsureUtf8(name);
 descIdx := CPEnsureUtf8(desc);
 If CPCount >= MAX_CP Then
 Begin
  Error('Constant Pool plein');
  CPAddNameAndType := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag  := CP_NAMEANDTYPE;
 CPTab^[CPCount].Ref1 := nameIdx;
 CPTab^[CPCount].Ref2 := descIdx;
 CPAddNameAndType := CPCount;
 Inc(CPCount);
End;

{ --- CPAddFieldRef : ajouter CONSTANT_Fieldref --- }
Function CPAddFieldRef(Const cls, name, desc: String): Integer;
Var classIdx, natIdx: Integer;
Begin
 classIdx := CPEnsureClass(cls);
 natIdx   := CPEnsureNameAndType(name, desc);
 If CPCount >= MAX_CP Then
 Begin
  Error('Constant Pool plein');
  CPAddFieldRef := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag  := CP_FIELDREF;
 CPTab^[CPCount].Ref1 := classIdx;
 CPTab^[CPCount].Ref2 := natIdx;
 CPAddFieldRef := CPCount;
 Inc(CPCount);
End;

{ --- CPAddMethodRef : ajouter CONSTANT_Methodref --- }
Function CPAddMethodRef(Const cls, name, desc: String): Integer;
Var classIdx, natIdx: Integer;
Begin
 classIdx := CPEnsureClass(cls);
 natIdx   := CPEnsureNameAndType(name, desc);
 If CPCount >= MAX_CP Then
 Begin
  Error('Constant Pool plein');
  CPAddMethodRef := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag  := CP_METHODREF;
 CPTab^[CPCount].Ref1 := classIdx;
 CPTab^[CPCount].Ref2 := natIdx;
 CPAddMethodRef := CPCount;
 Inc(CPCount);
End;

{ --- CPAddInterfaceMethodRef : ajouter CONSTANT_InterfaceMethodref --- }
Function CPAddInterfaceMethodRef(Const cls, name, desc: String): Integer;
Var classIdx, natIdx: Integer;
Begin
 classIdx := CPEnsureClass(cls);
 natIdx   := CPEnsureNameAndType(name, desc);
 If CPCount >= MAX_CP Then
 Begin
  Error('Constant Pool plein');
  CPAddInterfaceMethodRef := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag  := CP_INTERFACEMETHODREF;
 CPTab^[CPCount].Ref1 := classIdx;
 CPTab^[CPCount].Ref2 := natIdx;
 CPAddInterfaceMethodRef := CPCount;
 Inc(CPCount);
End;

{ --- CPAddMethodHandle : ajouter CONSTANT_MethodHandle --- }
Function CPAddMethodHandle(kind, ref: Integer): Integer;
Begin
 If CPCount >= MAX_CP Then
 Begin
  Error('Constant Pool plein');
  CPAddMethodHandle := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag  := CP_METHODHANDLE;
 CPTab^[CPCount].Ref1 := kind;
 CPTab^[CPCount].Ref2 := ref;
 CPAddMethodHandle := CPCount;
 Inc(CPCount);
End;

{ --- CPAddMethodType : ajouter CONSTANT_MethodType --- }
Function CPAddMethodType(Const desc: String): Integer;
Var descIdx: Integer;
Begin
 descIdx := CPEnsureUtf8(desc);
 If CPCount >= MAX_CP Then
 Begin
  Error('Constant Pool plein');
  CPAddMethodType := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag  := CP_METHODTYPE;
 CPTab^[CPCount].Ref1 := descIdx;
 CPAddMethodType := CPCount;
 Inc(CPCount);
End;

{ --- CPAddInvokeDynamic : ajouter CONSTANT_InvokeDynamic --- }
Function CPAddInvokeDynamic(bootstrap, nat: Integer): Integer;
Begin
 If CPCount >= MAX_CP Then
 Begin
  Error('Constant Pool plein');
  CPAddInvokeDynamic := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag  := CP_INVOKEDYNAMIC;
 CPTab^[CPCount].Ref1 := bootstrap;
 CPTab^[CPCount].Ref2 := nat;
 CPAddInvokeDynamic := CPCount;
 Inc(CPCount);
End;

{ --- CPEnsureUtf8 : ajouter si absent, retourner index --- }
Function CPEnsureUtf8(Const s: String): Integer;
Var idx: Integer;
Begin
 idx := CPFind(CP_UTF8, s);
 If idx <> 0 Then
  CPEnsureUtf8 := idx
 Else
  CPEnsureUtf8 := CPAddUtf8(s);
End;

{ --- CPEnsureClass : ajouter si absent, retourner index --- }
Function CPEnsureClass(Const name: String): Integer;
Var i: Integer;
Begin
 { Chercher une entree CP_CLASS existante avec ce nom }
 For i := 1 to CPCount - 1 do
 Begin
  If (CPTab^[i].Tag = CP_CLASS) And (CPTab^[i].StrVal = name) Then
  Begin
   CPEnsureClass := i;
   Exit;
  End;
 End;
 CPEnsureClass := CPAddClass(name);
End;

{ --- CPEnsureNameAndType : ajouter si absent, retourner index --- }
Function CPEnsureNameAndType(Const name, desc: String): Integer;
Var i: Integer; nameIdx, descIdx: Integer;
Begin
 nameIdx := CPEnsureUtf8(name);
 descIdx := CPEnsureUtf8(desc);
 { Chercher une entree CP_NAMEANDTYPE existante avec memes refs }
 For i := 1 to CPCount - 1 do
 Begin
  If (CPTab^[i].Tag = CP_NAMEANDTYPE) And
     (CPTab^[i].Ref1 = nameIdx) And (CPTab^[i].Ref2 = descIdx) Then
  Begin
   CPEnsureNameAndType := i;
   Exit;
  End;
 End;
 { Pas trouvee, ajouter directement (les Utf8 existent deja) }
 If CPCount >= MAX_CP Then
 Begin
  Error('Constant Pool plein');
  CPEnsureNameAndType := 0;
  Exit;
 End;
 CPTab^[CPCount].Tag  := CP_NAMEANDTYPE;
 CPTab^[CPCount].Ref1 := nameIdx;
 CPTab^[CPCount].Ref2 := descIdx;
 CPEnsureNameAndType := CPCount;
 Inc(CPCount);
End;

{ ============================================================================ }
{ Ecriture binaire du fichier .class (Big-endian)                              }
{ ============================================================================ }

{ --- BinOpen : ouvrir fichier binaire en ecriture --- }
Procedure BinOpen(Const filename: String);
Begin
 Assign(OutFile, filename);
 Rewrite(OutFile);
 If IOResult <> 0 Then
  FatalError('impossible de creer ' + filename);
 BinPos := 0;
End;

{ --- BinClose : fermer fichier binaire --- }
Procedure BinClose;
Begin
 Close(OutFile);
 If IOResult <> 0 Then { ignorer erreur fermeture };
End;

{ --- BinWriteU1 : ecrire 1 octet (unsigned byte) --- }
Procedure BinWriteU1(b: Byte);
Begin
 Write(OutFile, b);
 Inc(BinPos);
End;

{ --- BinWriteU2 : ecrire 2 octets big-endian (unsigned short) --- }
Procedure BinWriteU2(w: Integer);
Var b: Byte;
Begin
 b := Byte((w shr 8) and $FF);
 Write(OutFile, b);
 b := Byte(w and $FF);
 Write(OutFile, b);
 Inc(BinPos, 2);
End;

{ --- BinWriteU4 : ecrire 4 octets big-endian (unsigned int) --- }
Procedure BinWriteU4(d: LongInt);
Var b: Byte;
Begin
 b := Byte((d shr 24) and $FF);
 Write(OutFile, b);
 b := Byte((d shr 16) and $FF);
 Write(OutFile, b);
 b := Byte((d shr 8) and $FF);
 Write(OutFile, b);
 b := Byte(d and $FF);
 Write(OutFile, b);
 Inc(BinPos, 4);
End;

{ --- BinWriteBytes : ecrire un bloc d'octets --- }
Procedure BinWriteBytes(Var buf; len: Integer);
Var p: ^Byte; i: Integer;
Begin
 p := @buf;
 For i := 1 to len do
 Begin
  Write(OutFile, p^);
  Inc(p);
 End;
 Inc(BinPos, len);
End;

{ --- BinWriteUtf8 : ecrire longueur U2 + octets UTF-8 modifie --- }
{ Le format CONSTANT_Utf8 dans le .class utilise un encodage UTF-8   }
{ modifie : longueur sur 2 octets (U2) suivie des octets de la      }
{ chaine. Les caracteres NUL sont encodes en 0xC0 0x80.             }
Procedure BinWriteUtf8(Const s: String);
Var i: Integer; ch: Byte;
Begin
 BinWriteU2(Length(s));
 For i := 1 to Length(s) do
 Begin
  ch := Byte(Ord(s[i]));
  Write(OutFile, ch);
 End;
 Inc(BinPos, Length(s));
End;

{ --- BinWriteFloat : ecrire IEEE 754 single 32 bits big-endian --- }
{ La valeur Real de Turbo Pascal/FPC est convertie en Single 32b.   }
{ On utilise 'absolute' pour acceder aux octets de la representation }
{ IEEE 754 du Single. Cela suppose une plateforme little-endian     }
{ (x86/x86-64) avec representation IEEE 754 standard.               }
Procedure BinWriteFloat(f: Real);
Var s: Single; bytes: Array[0..3] of Byte absolute s;
Begin
 s := f;
 { Single est en little-endian sur x86 -> ecrire en big-endian }
 BinWriteU1(bytes[3]);
 BinWriteU1(bytes[2]);
 BinWriteU1(bytes[1]);
 BinWriteU1(bytes[0]);
End;

{ --- BinWriteDouble : ecrire IEEE 754 double 64 bits big-endian --- }
{ Recoit hi et lo (moities haute et basse de la representation       }
{ 64 bits) et les ecrit en big-endian.                               }
Procedure BinWriteDouble(hi, lo: LongInt);
Begin
 BinWriteU4(hi);
 BinWriteU4(lo);
End;

{ --- BinWriteLong : ecrire entier 64 bits big-endian --- }
{ Recoit hi et lo (moities haute et basse) et les ecrit   }
{ en big-endian (hi puis lo).                              }
Procedure BinWriteLong(hi, lo: LongInt);
Begin
 BinWriteU4(hi);
 BinWriteU4(lo);
End;

{ --- BinGetPos : retourner la position courante dans le fichier --- }
Function BinGetPos: LongInt;
Begin
 BinGetPos := BinPos;
End;

{ --- BinPatchU2 : ecrire U2 a une position precedente (backpatch) --- }
{ Sauve la position courante, se deplace a pos, ecrit U2, revient.     }
Procedure BinPatchU2(pos: LongInt; w: Integer);
Var savePos: LongInt; b: Byte;
Begin
 savePos := FilePos(OutFile);
 Seek(OutFile, pos);
 b := Byte((w shr 8) and $FF);
 Write(OutFile, b);
 b := Byte(w and $FF);
 Write(OutFile, b);
 Seek(OutFile, savePos);
End;

{ --- BinPatchU4 : ecrire U4 a une position precedente (backpatch) --- }
{ Sauve la position courante, se deplace a pos, ecrit U4, revient.     }
Procedure BinPatchU4(pos: LongInt; d: LongInt);
Var savePos: LongInt; b: Byte;
Begin
 savePos := FilePos(OutFile);
 Seek(OutFile, pos);
 b := Byte((d shr 24) and $FF);
 Write(OutFile, b);
 b := Byte((d shr 16) and $FF);
 Write(OutFile, b);
 b := Byte((d shr 8) and $FF);
 Write(OutFile, b);
 b := Byte(d and $FF);
 Write(OutFile, b);
 Seek(OutFile, savePos);
End;

{ ============================================================================ }
{ Directives de classe (.class, .super, .implements, .source)                  }
{ ============================================================================ }

{ --- ConvertClassName : convertir '.' en '/' dans un nom de classe --- }
{ Les fichiers .j acceptent les deux notations, la JVM utilise '/'.    }
Function ConvertClassName(Const name: String): String;
Var i: Integer; r: String;
Begin
 r := name;
 For i := 1 to Length(r) do
  If r[i] = '.' Then r[i] := '/';
 ConvertClassName := r;
End;

{ --- ParseAccessFlags : decoder les mots-cles d'acces en masque de bits --- }
{ Lit les mots-cles comme public, private, static, etc. et retourne         }
{ le masque de bits correspondant. S'arrete au premier token non-flag.       }
Function ParseAccessFlags: Integer;
Var flags: Integer; s: String;
Begin
 flags := 0;
 While CurTok = TK_IDENT do
 Begin
  s := CurStr;
  If s = 'public' Then flags := flags or ACC_PUBLIC
  Else If s = 'private' Then flags := flags or ACC_PRIVATE
  Else If s = 'protected' Then flags := flags or ACC_PROTECTED
  Else If s = 'static' Then flags := flags or ACC_STATIC
  Else If s = 'final' Then flags := flags or ACC_FINAL
  Else If s = 'synchronized' Then flags := flags or ACC_SYNCHRONIZED
  Else If s = 'super' Then flags := flags or ACC_SUPER
  Else If s = 'volatile' Then flags := flags or ACC_VOLATILE
  Else If s = 'bridge' Then flags := flags or ACC_BRIDGE
  Else If s = 'transient' Then flags := flags or ACC_TRANSIENT
  Else If s = 'varargs' Then flags := flags or ACC_VARARGS
  Else If s = 'native' Then flags := flags or ACC_NATIVE
  Else If s = 'interface' Then flags := flags or ACC_INTERFACE
  Else If s = 'abstract' Then flags := flags or ACC_ABSTRACT
  Else If s = 'strictfp' Then flags := flags or ACC_STRICT
  Else If s = 'strict' Then flags := flags or ACC_STRICT
  Else If s = 'synthetic' Then flags := flags or ACC_SYNTHETIC
  Else If s = 'annotation' Then flags := flags or ACC_ANNOTATION
  Else If s = 'enum' Then flags := flags or ACC_ENUM
  Else Break;  { mot-cle non reconnu = fin des drapeaux }
  Consume;
 End;
 ParseAccessFlags := flags;
End;

{ --- ParseClassDirective : .class <access_flags> <classname> --- }
Procedure ParseClassDirective;
Var flags: Integer;
Begin
 flags := ParseAccessFlags;
 { Ajouter ACC_SUPER par defaut si pas interface }
 If (flags and ACC_INTERFACE) = 0 Then
  flags := flags or ACC_SUPER;
 ClassAccFlags := flags;
 If CurTok = TK_IDENT Then
 Begin
  ClassName := ConvertClassName(CurStr);
  Consume;
 End
 Else
  Error('.class : nom de classe attendu');
 If OptVerbose Then
  WriteLn('  .class ', ClassName, ' (flags=$', IntToHex_(ClassAccFlags, 4), ')');
End;

{ --- ParseSuperDirective : .super <classname> --- }
Procedure ParseSuperDirective;
Begin
 If CurTok = TK_IDENT Then
 Begin
  SuperName := ConvertClassName(CurStr);
  Consume;
 End
 Else
  Error('.super : nom de classe attendu');
 If OptVerbose Then
  WriteLn('  .super ', SuperName);
End;

{ --- ParseImplementsDirective : .implements <interfacename> --- }
Procedure ParseImplementsDirective;
Var ifName: String;
Begin
 If CurTok = TK_IDENT Then
 Begin
  ifName := ConvertClassName(CurStr);
  Consume;
  If IfaceCount < MAX_IFACES Then
  Begin
   Inc(IfaceCount);
   IfaceTab[IfaceCount] := CPAddClass(ifName);
  End
  Else
   Error('.implements : trop d''interfaces (max ' + IntToStr_(MAX_IFACES) + ')');
 End
 Else
  Error('.implements : nom d''interface attendu');
 If OptVerbose Then
  WriteLn('  .implements ', ifName);
End;

{ --- ParseSourceDirective : .source <filename> --- }
{ Le nom de fichier peut contenir des '.' (ex: Hello.java),          }
{ mais le lexeur decoupe sur le '.' (TK_DOT/TK_DIRECTIVE).          }
{ On concatene donc les parties ident.ident... jusqu'a EOL/newline.  }
Procedure ParseSourceDirective;
Var n: String;
Begin
 If (CurTok = TK_IDENT) or (CurTok = TK_STRING) Then
 Begin
  n := CurStr;
  Consume;
  { Concatener les suffixes apres un '.' (ex: Hello.java) }
  While (CurTok = TK_DOT) or
        ((CurTok = TK_DIRECTIVE) and (Length(CurStr) > 0) and (CurStr[1] = '.')) do
  Begin
   If CurTok = TK_DOT Then
   Begin
    n := n + '.';
    Consume;
    If CurTok = TK_IDENT Then
    Begin
     n := n + CurStr;
     Consume;
    End;
   End
   Else
   Begin
    { Le lexer a lu '.java' comme une directive inconnue }
    n := n + CurStr;
    Consume;
   End;
  End;
  SourceName := n;
 End
 Else
  Error('.source : nom de fichier attendu');
 If OptVerbose Then
  WriteLn('  .source ', SourceName);
End;

{ --- ParseInterfaceDirective : .interface <access_flags> <name> --- }
{ Equivalent a .class avec ACC_INTERFACE | ACC_ABSTRACT ajoutees.   }
Procedure ParseInterfaceDirective;
Var flags: Integer;
Begin
 flags := ParseAccessFlags;
 flags := flags or ACC_INTERFACE or ACC_ABSTRACT;
 ClassAccFlags := flags;
 If CurTok = TK_IDENT Then
 Begin
  ClassName := ConvertClassName(CurStr);
  Consume;
 End
 Else
  Error('.interface : nom d''interface attendu');
 If OptVerbose Then
  WriteLn('  .interface ', ClassName, ' (flags=$', IntToHex_(ClassAccFlags, 4), ')');
End;

{ --- ParseBytecodeDirective : .bytecode <major>.<minor> --- }
Procedure ParseBytecodeDirective;
Var majStr, minStr: String; p: Integer;
Begin
 If CurTok = TK_IDENT Then
 Begin
  { Le token contient "major.minor" comme un identifiant }
  majStr := CurStr;
  p := Pos('.', majStr);
  If p > 0 Then
  Begin
   minStr := Copy(majStr, p + 1, Length(majStr) - p);
   majStr := Copy(majStr, 1, p - 1);
   ClassMajor := Integer(StrToInt_(majStr));
   ClassMinor := Integer(StrToInt_(minStr));
  End
  Else
  Begin
   ClassMajor := Integer(StrToInt_(majStr));
   Consume;
   { Verifier s'il y a un '.' suivi du mineur }
   If (CurTok = TK_DOT) Then
   Begin
    Consume;
    If CurTok = TK_INTEGER Then
    Begin
     ClassMinor := Integer(CurInt);
     Consume;
    End
    Else
     Error('.bytecode : version mineure attendue apres le point');
   End;
   Exit;  { on a deja consomme }
  End;
  Consume;
 End
 Else If CurTok = TK_INTEGER Then
 Begin
  ClassMajor := Integer(CurInt);
  Consume;
  If CurTok = TK_DOT Then
  Begin
   Consume;
   If CurTok = TK_INTEGER Then
   Begin
    ClassMinor := Integer(CurInt);
    Consume;
   End
   Else
    Error('.bytecode : version mineure attendue');
  End;
 End
 Else If CurTok = TK_FLOAT Then
 Begin
  { Le lexer a pu lire "49.0" comme un float }
  majStr := CurStr;
  p := Pos('.', majStr);
  If p > 0 Then
  Begin
   minStr := Copy(majStr, p + 1, Length(majStr) - p);
   majStr := Copy(majStr, 1, p - 1);
   ClassMajor := Integer(StrToInt_(majStr));
   ClassMinor := Integer(StrToInt_(minStr));
  End
  Else
   ClassMajor := Integer(StrToInt_(majStr));
  Consume;
 End
 Else
  Error('.bytecode : version attendue (ex: 49.0)');
 If OptVerbose Then
  WriteLn('  .bytecode ', ClassMajor, '.', ClassMinor);
End;

{ ============================================================================ }
{ Directives de champs (.field avec descripteurs et valeurs)                    }
{ ============================================================================ }

{ --- ValidFieldDescriptor : valider un descripteur de champ JVM --- }
{ Accepte: B(byte), C(char), D(double), F(float), I(int), J(long),  }
{ S(short), Z(boolean), Lclassname;, [type (tableaux)                }
Function ValidFieldDescriptor(Const desc: String): Boolean;
Var p, len: Integer;
Begin
 ValidFieldDescriptor := False;
 len := Length(desc);
 If len = 0 Then Exit;
 p := 1;
 { Sauter les prefixes de tableau [ }
 While (p <= len) And (desc[p] = '[') do
  Inc(p);
 If p > len Then Exit;  { [ tout seul }
 Case desc[p] of
  'B', 'C', 'D', 'F', 'I', 'J', 'S', 'Z':
   ValidFieldDescriptor := (p = len);
  'L':
  Begin
   { Doit finir par ; et avoir au moins Lx; }
   If desc[len] = ';' Then
    ValidFieldDescriptor := (len - p) >= 2
   Else
    ValidFieldDescriptor := False;
  End;
 Else
  ValidFieldDescriptor := False;
 End;
End;

{ --- AddField : creer une entree dans la table des champs --- }
{ Retourne l'index dans FieldTab, ou 0 en cas d'erreur.        }
Function AddField(flags: Integer; Const name, desc: String): Integer;
Begin
 If FieldCount >= MAX_FIELDS Then
 Begin
  Error('.field : trop de champs (max ' + IntToStr_(MAX_FIELDS) + ')');
  AddField := 0;
  Exit;
 End;
 Inc(FieldCount);
 FieldTab^[FieldCount].AccFlags  := flags;
 FieldTab^[FieldCount].NameIdx   := CPEnsureUtf8(name);
 FieldTab^[FieldCount].DescIdx   := CPEnsureUtf8(desc);
 FieldTab^[FieldCount].AttrCount := 0;
 FieldTab^[FieldCount].HasInit   := False;
 FieldTab^[FieldCount].InitCPIdx := 0;
 FieldTab^[FieldCount].IsDeprecated := False;
 FieldTab^[FieldCount].Signature := '';
 FieldTab^[FieldCount].Name      := name;
 FieldTab^[FieldCount].Desc      := desc;
 AddField := FieldCount;
End;

{ --- ParseFieldInitValue : parser = <value> apres le descripteur --- }
{ Gere les types : entier, flottant, chaine, long (suffixe L).       }
{ L'attribut ConstantValue est ajoute au champ.                       }
Procedure ParseFieldInitValue(fIdx: Integer);
Var cpIdx: Integer; desc: String;
    dhi, dlo: LongInt;
Begin
 { Le token '=' a deja ete consomme par l'appelant }
 desc := FieldTab^[fIdx].Desc;
 cpIdx := 0;
 If CurTok = TK_STRING Then
 Begin
  { Chaine : CONSTANT_String }
  cpIdx := CPAddString(CurStr);
  Consume;
 End
 Else If CurTok = TK_INTEGER Then
 Begin
  If (desc = 'J') Then
  Begin
   { Long : CONSTANT_Long (hi=0, lo=valeur) }
   cpIdx := CPAddLong(0, CurInt);
   Consume;
   { Sauter le suffixe L si present }
   If (CurTok = TK_IDENT) And ((CurStr = 'L') or (CurStr = 'l')) Then
    Consume;
  End
  Else
  Begin
   { Entier : CONSTANT_Integer }
   cpIdx := CPAddInteger(CurInt);
   Consume;
  End;
 End
 Else If CurTok = TK_FLOAT Then
 Begin
  If (desc = 'D') Then
  Begin
   { Double : CONSTANT_Double (IEEE 754 via RealToHiLo) }
   RealToHiLo(CurFloat, dhi, dlo);
   cpIdx := CPAddDouble(dhi, dlo);
   Consume;
  End
  Else
  Begin
   { Float : CONSTANT_Float }
   cpIdx := CPAddFloat(CurFloat);
   Consume;
  End;
 End
 Else If (CurTok = TK_MINUS) Then
 Begin
  { Nombre negatif }
  Consume;
  If CurTok = TK_INTEGER Then
  Begin
   If (desc = 'J') Then
   Begin
    cpIdx := CPAddLong(-1, -CurInt);
    Consume;
    If (CurTok = TK_IDENT) And ((CurStr = 'L') or (CurStr = 'l')) Then
     Consume;
   End
   Else
   Begin
    cpIdx := CPAddInteger(-CurInt);
    Consume;
   End;
  End
  Else If CurTok = TK_FLOAT Then
  Begin
   If (desc = 'D') Then
   Begin
    RealToHiLo(-CurFloat, dhi, dlo);
    cpIdx := CPAddDouble(dhi, dlo);
    Consume;
   End
   Else
   Begin
    cpIdx := CPAddFloat(-CurFloat);
    Consume;
   End;
  End
  Else
   Error('.field : valeur initiale attendue apres ''=''');
 End
 Else
  Error('.field : valeur initiale attendue apres ''=''');
 If cpIdx > 0 Then
 Begin
  FieldTab^[fIdx].HasInit   := True;
  FieldTab^[fIdx].InitCPIdx := cpIdx;
  FieldTab^[fIdx].AttrCount := FieldTab^[fIdx].AttrCount + 1;
 End;
End;

{ --- ParseFieldDirective : .field <access> <name> <descriptor> [= <value>] --- }
{ Parse une declaration de champ et l'ajoute a la table des champs.              }
Procedure ParseFieldDirective;
Var flags, fIdx: Integer;
    fName, fDesc: String;
Begin
 { Decoder les drapeaux d'acces }
 flags := ParseAccessFlags;
 { Lire le nom du champ }
 If CurTok = TK_IDENT Then
 Begin
  fName := CurStr;
  Consume;
 End
 Else
 Begin
  Error('.field : nom de champ attendu');
  Exit;
 End;
 { Lire le descripteur de type }
 If CurTok = TK_IDENT Then
 Begin
  fDesc := CurStr;
  Consume;
 End
 Else
 Begin
  Error('.field : descripteur de type attendu');
  Exit;
 End;
 { Valider le descripteur }
 If Not ValidFieldDescriptor(fDesc) Then
  Warning('.field : descripteur suspect ''' + fDesc + '''');
 { Creer l'entree dans FieldTab }
 fIdx := AddField(flags, fName, fDesc);
 If fIdx = 0 Then Exit;
 { Valeur initiale optionnelle : = <value> }
 If CurTok = TK_EQUAL Then
 Begin
  Consume;
  ParseFieldInitValue(fIdx);
 End;
 If OptVerbose Then
 Begin
  Write('  .field ');
  If (flags and ACC_PUBLIC) <> 0 Then Write('public ');
  If (flags and ACC_PRIVATE) <> 0 Then Write('private ');
  If (flags and ACC_PROTECTED) <> 0 Then Write('protected ');
  If (flags and ACC_STATIC) <> 0 Then Write('static ');
  If (flags and ACC_FINAL) <> 0 Then Write('final ');
  If (flags and ACC_VOLATILE) <> 0 Then Write('volatile ');
  If (flags and ACC_TRANSIENT) <> 0 Then Write('transient ');
  Write(fName, ' ', fDesc);
  If FieldTab^[fIdx].HasInit Then
   Write(' = [CP#', FieldTab^[fIdx].InitCPIdx, ']');
  WriteLn;
 End;
End;

{ ============================================================================ }
{ Directives de methodes (.method, .end method, .limit, .line, .throws)        }
{ ============================================================================ }

{ --- EnterMethod : initialiser l'etat pour une nouvelle methode --- }
{ Alloue les buffers, initialise les compteurs, met InMethod a True. }
Procedure EnterMethod(flags: Integer; Const name, desc: String);
Var mN, mD: String;
Begin
 { Sauvegarder les parametres avant le With (evite conflit TP case-insensitive) }
 mN := name;
 mD := desc;
 If InMethod Then
 Begin
  Error('.method : methode precedente non terminee (.end method manquant)');
  LeaveMethod;
 End;
 If MethodCount >= MAX_METHODS Then
 Begin
  Error('.method : trop de methodes (max ' + IntToStr_(MAX_METHODS) + ')');
  Exit;
 End;
 Inc(MethodCount);
 CurMethod := MethodCount;
 InMethod  := True;
 With MethodTab^[CurMethod] do
 Begin
  AccFlags   := flags;
  NameIdx    := CPEnsureUtf8(mN);
  DescIdx    := CPEnsureUtf8(mD);
  MaxStack   := 0;
  MaxLocals  := 0;
  CodeSize   := 0;
  ExcCount   := 0;
  LineCount  := 0;
  LabelCount := 0;
  FixupCount := 0;
  ThrowCount := 0;
  Name       := mN;
  Desc       := mD;
  HasCode    := ((flags and ACC_ABSTRACT) = 0) And ((flags and ACC_NATIVE) = 0);
  HasStack   := False;
  HasLocals  := False;
  IsDeprecated := False;
  Signature  := '';
  { Allouer les buffers }
  If HasCode Then
  Begin
   New(Code);
   FillChar(Code^, SizeOf(TCodeBuf), 0);
  End
  Else
   Code := Nil;
  New(ExcTab);
  New(LineTab);
  New(Labels);
  New(Fixups);
 End;
End;

{ --- LeaveMethod : finaliser la methode courante --- }
{ Verifie les labels non resolus, calcule auto-locals/auto-stack si absent. }
Procedure LeaveMethod;
Var i: Integer;
Begin
 If Not InMethod Then
 Begin
  Error('.end method : pas dans une methode');
  Exit;
 End;
 With MethodTab^[CurMethod] do
 Begin
  { Resoudre les fixups de branchement (TODO 19) }
  LabelResolve;
  { Verifier les labels non resolus }
  For i := 1 to LabelCount do
  Begin
   If Not Labels^[i].Resolved Then
    Warning('.end method : label ''' + Labels^[i].Name + ''' non resolu');
  End;
  { Calculer auto-locals/auto-stack si .limit absent (TODO 09) }
  If HasCode Then
  Begin
   If Not HasLocals Then
   Begin
    AutoLocals(CurMethod);
    If OptVerbose Then
     WriteLn('    [auto] .limit locals ', MaxLocals, ' (calcule depuis descripteur)');
   End;
   If Not HasStack Then
   Begin
    AutoStack(CurMethod);
    If OptVerbose Then
     WriteLn('    [auto] .limit stack ', MaxStack, ' (estimation minimale)');
   End;
  End;
  { Valider le descripteur de methode (TODO 09) }
  If Not ValidateMethodDescriptor(Desc) Then
   Warning('.method ' + Name + ' : descripteur invalide ''' + Desc + '''');
   { Valider les labels des exception handlers (TODO 21) }
   For i := 1 to ExcCount do
   Begin
    If ExcTab^[i].StartLbl <> '' Then
    Begin
     If LabelFind(ExcTab^[i].StartLbl) = 0 Then
      Warning('.catch : label start ''' + ExcTab^[i].StartLbl + ''' non defini');
    End;
    If ExcTab^[i].EndLbl <> '' Then
    Begin
     If LabelFind(ExcTab^[i].EndLbl) = 0 Then
      Warning('.catch : label end ''' + ExcTab^[i].EndLbl + ''' non defini');
    End;
    If ExcTab^[i].HandlerLbl <> '' Then
    Begin
     If LabelFind(ExcTab^[i].HandlerLbl) = 0 Then
      Warning('.catch : label handler ''' + ExcTab^[i].HandlerLbl + ''' non defini');
    End;
   End;
 End;
 InMethod  := False;
 CurMethod := 0;
End;

{ --- ParseMethodDirective : .method <access> <name><descriptor> --- }
{ Parse une declaration de methode et l'ajoute a la table.            }
Procedure ParseMethodDirective;
Var flags: Integer;
    mName, mDesc, combined: String;
    paren: Integer;
Begin
 { Decoder les drapeaux d'acces }
 flags := ParseAccessFlags;
 { Lire le nom+descripteur }
 { En Jasmin, le nom et le descripteur sont colles : add(II)I }
 { Ou bien pour <init> : <init>()V                            }
 If CurTok = TK_IDENT Then
 Begin
  combined := CurStr;
  Consume;
 End
 Else
 Begin
  Error('.method : nom et descripteur attendus');
  Exit;
 End;
 { Separer le nom du descripteur (chercher la premiere parenthese) }
 paren := Pos('(', combined);
 If paren = 0 Then
 Begin
  { Pas de parenthese : c'est un nom seul (abstract/native sans desc?) }
  mName := combined;
  mDesc := '()V';
  Warning('.method : descripteur manquant pour ' + mName + ', defaut ()V');
 End
 Else
 Begin
  mName := Copy(combined, 1, paren - 1);
  mDesc := Copy(combined, paren, Length(combined) - paren + 1);
 End;
 If mName = '' Then
 Begin
  Error('.method : nom de methode vide');
  Exit;
 End;
 { Entrer dans la methode }
 EnterMethod(flags, mName, mDesc);
 If OptVerbose Then
 Begin
  Write('  .method ');
  If (flags and ACC_PUBLIC) <> 0 Then Write('public ');
  If (flags and ACC_PRIVATE) <> 0 Then Write('private ');
  If (flags and ACC_PROTECTED) <> 0 Then Write('protected ');
  If (flags and ACC_STATIC) <> 0 Then Write('static ');
  If (flags and ACC_FINAL) <> 0 Then Write('final ');
  If (flags and ACC_SYNCHRONIZED) <> 0 Then Write('synchronized ');
  If (flags and ACC_NATIVE) <> 0 Then Write('native ');
  If (flags and ACC_ABSTRACT) <> 0 Then Write('abstract ');
  If (flags and ACC_STRICT) <> 0 Then Write('strictfp ');
  WriteLn(mName, mDesc);
 End;
End;

{ --- ParseEndMethod : .end method --- }
{ Consomme le mot 'method' apres .end, puis finalise la methode.  }
Procedure ParseEndMethod;
Begin
 { Le token .end a deja ete consomme, on attend 'method' }
 If (CurTok = TK_IDENT) And (CurStr = 'method') Then
  Consume
 Else
 Begin
  Error('.end : mot ''method'' attendu');
  Exit;
 End;
 If Not InMethod Then
 Begin
  Error('.end method : pas dans une methode');
  Exit;
 End;
 If OptVerbose Then
  WriteLn('  .end method (', MethodTab^[CurMethod].Name,
          MethodTab^[CurMethod].Desc, ', code=',
          MethodTab^[CurMethod].CodeSize, ' octets, labels=',
          MethodTab^[CurMethod].LabelCount, ', lines=',
          MethodTab^[CurMethod].LineCount, ', throws=',
          MethodTab^[CurMethod].ThrowCount, ')');
 LeaveMethod;
End;

{ --- ParseLimitDirective : .limit stack <N> / .limit locals <N> --- }
{ Definit max_stack ou max_locals pour la methode courante.          }
Procedure ParseLimitDirective;
Var what: String;
Begin
 If Not InMethod Then
 Begin
  Error('.limit : directive valide uniquement dans une methode');
  Exit;
 End;
 { Lire 'stack' ou 'locals' }
 If CurTok = TK_IDENT Then
 Begin
  what := CurStr;
  Consume;
 End
 Else
 Begin
  Error('.limit : ''stack'' ou ''locals'' attendu');
  Exit;
 End;
 { Lire la valeur N }
 If CurTok <> TK_INTEGER Then
 Begin
  Error('.limit ' + what + ' : valeur entiere attendue');
  Exit;
 End;
 If what = 'stack' Then
 Begin
  MethodTab^[CurMethod].MaxStack := CurInt;
  MethodTab^[CurMethod].HasStack := True;
  If OptVerbose Then
   WriteLn('    .limit stack ', CurInt);
  Consume;
 End
 Else If what = 'locals' Then
 Begin
  MethodTab^[CurMethod].MaxLocals := CurInt;
  MethodTab^[CurMethod].HasLocals := True;
  If OptVerbose Then
   WriteLn('    .limit locals ', CurInt);
  Consume;
 End
 Else
  Error('.limit : ''stack'' ou ''locals'' attendu, pas ''' + what + '''');
End;

{ --- ParseLineDirective : .line <N> --- }
{ Ajoute une entree dans la LineNumberTable de la methode courante. }
Procedure ParseLineDirective;
Begin
 If Not InMethod Then
 Begin
  Error('.line : directive valide uniquement dans une methode');
  Exit;
 End;
 If CurTok <> TK_INTEGER Then
 Begin
  Error('.line : numero de ligne attendu');
  Exit;
 End;
 With MethodTab^[CurMethod] do
 Begin
  If LineCount >= MAX_LINES Then
  Begin
   Error('.line : trop d''entrees LineNumberTable (max ' + IntToStr_(MAX_LINES) + ')');
   Consume;
   Exit;
  End;
  Inc(LineCount);
  LineTab^[LineCount].Line   := CurInt;
  LineTab^[LineCount].Offset := CodeSize;  { PC courant }
 End;
 If OptVerbose Then
  WriteLn('    .line ', CurInt);
 Consume;
End;

{ --- ParseThrowsDirective : .throws <classname> --- }
{ Ajoute une exception declaree a la methode courante. }
Procedure ParseThrowsDirective;
Var cn: String;
    classIdx: Integer;
Begin
 If Not InMethod Then
 Begin
  Error('.throws : directive valide uniquement dans une methode');
  Exit;
 End;
 If CurTok = TK_IDENT Then
 Begin
  cn := ConvertClassName(CurStr);
  Consume;
 End
 Else
 Begin
  Error('.throws : nom de classe attendu');
  Exit;
 End;
 With MethodTab^[CurMethod] do
 Begin
  If ThrowCount >= MAX_THROWS Then
  Begin
   Error('.throws : trop d''exceptions declarees (max ' + IntToStr_(MAX_THROWS) + ')');
   Exit;
  End;
  classIdx := CPAddClass(cn);
  Inc(ThrowCount);
  ThrowIdx[ThrowCount] := classIdx;
 End;
 If OptVerbose Then
  WriteLn('    .throws ', cn);
End;

{ --- ParseCatchDirective : .catch <classname> from <l1> to <l2> using <h> --- }
{ Enregistre un exception handler dans la methode courante.                     }
{ Syntaxe : .catch <classname> from <startlbl> to <endlbl> using <handlerlbl>  }
{ Si classname = "all", catch_type = 0 (intercepte toutes les exceptions).     }
Procedure ParseCatchDirective;
Var cn: String;
    startL, endL, handlerL: String;
Begin
 If Not InMethod Then
 Begin
  Error('.catch : directive valide uniquement dans une methode');
  Exit;
 End;
 { Lire le nom de classe ou 'all' }
 If CurTok = TK_IDENT Then
 Begin
  cn := CurStr;
  If UpCaseStr(cn) = 'ALL' Then
   cn := 'all'
  Else
   cn := ConvertClassName(cn);
  Consume;
 End
 Else
 Begin
  Error('.catch : nom de classe ou ''all'' attendu');
  Exit;
 End;
 { Lire 'from' <start_label> }
 If (CurTok <> TK_IDENT) Or (UpCaseStr(CurStr) <> 'FROM') Then
 Begin
  Error('.catch : ''from'' attendu apres le nom de classe');
  Exit;
 End;
 Consume;
 If CurTok <> TK_IDENT Then
 Begin
  Error('.catch : label debut attendu apres ''from''');
  Exit;
 End;
 startL := CurStr;
 Consume;
 { Lire 'to' <end_label> }
 If (CurTok <> TK_IDENT) Or (UpCaseStr(CurStr) <> 'TO') Then
 Begin
  Error('.catch : ''to'' attendu apres le label debut');
  Exit;
 End;
 Consume;
 If CurTok <> TK_IDENT Then
 Begin
  Error('.catch : label fin attendu apres ''to''');
  Exit;
 End;
 endL := CurStr;
 Consume;
 { Lire 'using' <handler_label> }
 If (CurTok <> TK_IDENT) Or (UpCaseStr(CurStr) <> 'USING') Then
 Begin
  Error('.catch : ''using'' attendu apres le label fin');
  Exit;
 End;
 Consume;
 If CurTok <> TK_IDENT Then
 Begin
  Error('.catch : label handler attendu apres ''using''');
  Exit;
 End;
 handlerL := CurStr;
 Consume;
 { Enregistrer dans ExcTab }
 With MethodTab^[CurMethod] do
 Begin
  If ExcCount >= MAX_EXC Then
  Begin
   Error('.catch : trop d''exception handlers (max ' + IntToStr_(MAX_EXC) + ')');
   Exit;
  End;
  Inc(ExcCount);
  With ExcTab^[ExcCount] do
  Begin
   StartLbl   := startL;
   EndLbl     := endL;
   HandlerLbl := handlerL;
   CatchType  := cn;
   StartPC    := 0;
   EndPC      := 0;
   HandlerPC  := 0;
   CatchIdx   := 0;
  End;
 End;
 If OptVerbose Then
  WriteLn('    .catch ', cn, ' from ', startL, ' to ', endL, ' using ', handlerL);
End;

{ --- EmitExceptionsAttribute : ecrire l'attribut Exceptions pour .throws --- }
{ Ecrit l'attribut Exceptions (distinct du Code_attribute) listant les        }
{ classes d'exceptions declarees via .throws.                                  }
Procedure EmitExceptionsAttribute(mIdx: Integer);
Var excAttrIdx: Integer;
    attrLenPos, attrStart: LongInt;
    i: Integer;
Begin
 With MethodTab^[mIdx] do
 Begin
  If ThrowCount = 0 Then Exit;
  excAttrIdx := CPEnsureUtf8('Exceptions');
  { attribute_name_index (U2) }
  BinWriteU2(excAttrIdx);
  { attribute_length (U4) - placeholder }
  attrLenPos := BinGetPos;
  BinWriteU4(0);
  attrStart := BinGetPos;
  { number_of_exceptions (U2) }
  BinWriteU2(ThrowCount);
  { exception_index_table[] (U2 chaque) }
  For i := 1 to ThrowCount do
   BinWriteU2(ThrowIdx[i]);
  { Backpatcher attribute_length }
  BinPatchU4(attrLenPos, BinGetPos - attrStart);
  If OptVerbose Then
   WriteLn('    [exceptions] methode ', Name, Desc,
           ' : ', ThrowCount, ' exception(s) declaree(s)');
 End;
End;

{ ============================================================================ }
{ Attributs supplementaires (TODO 22)                                          }
{ ============================================================================ }

{ --- ParseDeprecatedDirective : .deprecated --- }
{ Marque l'element courant (classe, champ, methode) comme deprecated.         }
Procedure ParseDeprecatedDirective;
Begin
 If InMethod Then
  MethodTab^[CurMethod].IsDeprecated := True
 Else
  ClassDeprecated := True;
 If OptVerbose Then
  WriteLn('  .deprecated');
End;

{ --- ParseSignatureDirective : .signature <string> --- }
{ Enregistre la signature generique pour l'element courant.                   }
Procedure ParseSignatureDirective;
Var sig: String;
Begin
 If CurTok = TK_STRING Then
 Begin
  sig := CurStr;
  Consume;
 End
 Else If CurTok = TK_IDENT Then
 Begin
  sig := CurStr;
  Consume;
 End
 Else
 Begin
  Error('.signature : chaine attendue');
  Exit;
 End;
 If InMethod Then
  MethodTab^[CurMethod].Signature := sig
 Else
  ClassSignature := sig;
 If OptVerbose Then
  WriteLn('  .signature ', sig);
End;

{ --- ParseInnerClassDirective : .inner class <access> <inner> <outer> <name> --- }
{ Enregistre une entree InnerClasses pour la classe courante.                     }
Procedure ParseInnerClassDirective;
Var accFlags: Integer;
    innerCls, outerCls, innerName: String;
Begin
 { Lire le mot-cle 'class' apres '.inner' }
 If (CurTok = TK_IDENT) And (UpCaseStr(CurStr) = 'CLASS') Then
  Consume
 Else
 Begin
  Error('.inner : mot-cle ''class'' attendu');
  Exit;
 End;
 { Decoder les drapeaux d'acces }
 accFlags := ParseAccessFlags;
 { Lire le nom de la classe interne }
 If CurTok = TK_IDENT Then
 Begin
  innerCls := CurStr;
  Consume;
 End
 Else
 Begin
  Error('.inner class : nom de la classe interne attendu');
  Exit;
 End;
 { Lire le nom de la classe externe (ou 'null') }
 If CurTok = TK_IDENT Then
 Begin
  outerCls := CurStr;
  Consume;
 End
 Else
  outerCls := '';
 { Lire le nom simple (ou 'null') }
 If CurTok = TK_IDENT Then
 Begin
  innerName := CurStr;
  Consume;
 End
 Else
  innerName := '';
 { Enregistrer }
 If InnerCount >= MAX_INNER Then
 Begin
  Error('.inner class : trop d''inner classes (max ' + IntToStr_(MAX_INNER) + ')');
  Exit;
 End;
 Inc(InnerCount);
 InnerTab[InnerCount].InnerClass := innerCls;
 If (outerCls = 'null') Or (outerCls = '') Then
  InnerTab[InnerCount].OuterClass := ''
 Else
  InnerTab[InnerCount].OuterClass := outerCls;
 If (innerName = 'null') Or (innerName = '') Then
  InnerTab[InnerCount].InnerName := ''
 Else
  InnerTab[InnerCount].InnerName := innerName;
 InnerTab[InnerCount].AccFlags := accFlags;
 If OptVerbose Then
  WriteLn('  .inner class ', innerCls, ' outer=', outerCls, ' name=', innerName);
End;

{ --- ParseEnclosingMethodDirective : .enclosing method <class> <method> <desc> --- }
{ Enregistre la methode englobante (pour les classes anonymes/locales).              }
Procedure ParseEnclosingMethodDirective;
Var kw: String;
Begin
 { Lire le mot-cle 'method' apres '.enclosing' }
 If (CurTok = TK_IDENT) And (UpCaseStr(CurStr) = 'METHOD') Then
  Consume
 Else
 Begin
  Error('.enclosing : mot-cle ''method'' attendu');
  Exit;
 End;
 { Lire le nom de la classe englobante }
 If CurTok = TK_IDENT Then
 Begin
  EnclosingClass := CurStr;
  Consume;
 End
 Else
 Begin
  Error('.enclosing method : nom de classe attendu');
  Exit;
 End;
 { Lire le nom de la methode englobante (optionnel) }
 If (CurTok = TK_IDENT) Then
 Begin
  kw := CurStr;
  Consume;
  { Separer le nom de la methode et le descripteur }
  { Format: methodName(descriptor) }
  EnclosingMethod := kw;
  { Si le descripteur est colle avec le nom: methodName(args)ret }
  { Chercher la parenthese }
  If Pos('(', kw) > 0 Then
  Begin
   EnclosingMethod := Copy(kw, 1, Pos('(', kw) - 1);
   EnclosingDesc   := Copy(kw, Pos('(', kw), Length(kw) - Pos('(', kw) + 1);
  End
  Else
  Begin
   EnclosingMethod := kw;
   EnclosingDesc   := '';
   { Lire le descripteur s'il suit }
   If CurTok = TK_IDENT Then
   Begin
    EnclosingDesc := CurStr;
    Consume;
   End;
  End;
 End
 Else
 Begin
  EnclosingMethod := '';
  EnclosingDesc   := '';
 End;
 If OptVerbose Then
  WriteLn('  .enclosing method ', EnclosingClass, ' ', EnclosingMethod, EnclosingDesc);
End;

{ --- EmitSourceFileAttr : ecrire l'attribut SourceFile --- }
{ Ecrit l'attribut SourceFile au niveau classe si .source a ete defini.       }
Procedure EmitSourceFileAttr;
Var nameIdx, fileIdx: Integer;
Begin
 If SourceName = '' Then Exit;
 nameIdx := CPEnsureUtf8('SourceFile');
 fileIdx := CPEnsureUtf8(SourceName);
 BinWriteU2(nameIdx);        { attribute_name_index }
 BinWriteU4(2);              { attribute_length = 2 }
 BinWriteU2(fileIdx);        { sourcefile_index }
 If OptVerbose Then
  WriteLn('    [attr] SourceFile = ', SourceName);
End;

{ --- EmitDeprecatedAttr : ecrire l'attribut Deprecated (vide) --- }
{ L'attribut Deprecated n'a pas de contenu (attribute_length = 0).            }
Procedure EmitDeprecatedAttr;
Var nameIdx: Integer;
Begin
 nameIdx := CPEnsureUtf8('Deprecated');
 BinWriteU2(nameIdx);        { attribute_name_index }
 BinWriteU4(0);              { attribute_length = 0 }
 If OptVerbose Then
  WriteLn('    [attr] Deprecated');
End;

{ --- EmitSignatureAttr : ecrire l'attribut Signature --- }
{ L'attribut Signature contient un index CP vers la signature generique.      }
Procedure EmitSignatureAttr(Const sig: String);
Var nameIdx, sigIdx: Integer;
Begin
 If sig = '' Then Exit;
 nameIdx := CPEnsureUtf8('Signature');
 sigIdx  := CPEnsureUtf8(sig);
 BinWriteU2(nameIdx);        { attribute_name_index }
 BinWriteU4(2);              { attribute_length = 2 }
 BinWriteU2(sigIdx);         { signature_index }
 If OptVerbose Then
  WriteLn('    [attr] Signature = ', sig);
End;

{ --- EmitInnerClassesAttr : ecrire l'attribut InnerClasses --- }
{ L'attribut InnerClasses contient une table de classes internes.              }
Procedure EmitInnerClassesAttr;
Var nameIdx, innerIdx, outerIdx, nmIdx: Integer;
    i: Integer;
    attrLenPos, attrStart: LongInt;
Begin
 If InnerCount = 0 Then Exit;
 nameIdx := CPEnsureUtf8('InnerClasses');
 BinWriteU2(nameIdx);                        { attribute_name_index }
 attrLenPos := BinGetPos;
 BinWriteU4(0);                              { attribute_length (placeholder) }
 attrStart := BinGetPos;
 BinWriteU2(InnerCount);                     { number_of_classes }
 For i := 1 to InnerCount do
 Begin
  { inner_class_info_index (U2) }
  If InnerTab[i].InnerClass <> '' Then
   innerIdx := CPEnsureClass(InnerTab[i].InnerClass)
  Else
   innerIdx := 0;
  BinWriteU2(innerIdx);
  { outer_class_info_index (U2) }
  If InnerTab[i].OuterClass <> '' Then
   outerIdx := CPEnsureClass(InnerTab[i].OuterClass)
  Else
   outerIdx := 0;
  BinWriteU2(outerIdx);
  { inner_name_index (U2) }
  If InnerTab[i].InnerName <> '' Then
   nmIdx := CPEnsureUtf8(InnerTab[i].InnerName)
  Else
   nmIdx := 0;
  BinWriteU2(nmIdx);
  { inner_class_access_flags (U2) }
  BinWriteU2(InnerTab[i].AccFlags);
 End;
 { Backpatcher attribute_length }
 BinPatchU4(attrLenPos, BinGetPos - attrStart);
 If OptVerbose Then
  WriteLn('    [attr] InnerClasses : ', InnerCount, ' entree(s)');
End;

{ --- EmitEnclosingMethodAttr : ecrire l'attribut EnclosingMethod --- }
{ Pour les classes anonymes/locales, indique la methode englobante.           }
Procedure EmitEnclosingMethodAttr;
Var nameIdx, clsIdx, natIdx: Integer;
Begin
 If EnclosingClass = '' Then Exit;
 nameIdx := CPEnsureUtf8('EnclosingMethod');
 clsIdx  := CPEnsureClass(EnclosingClass);
 { method_index : NameAndType si methode presente, 0 sinon }
 If EnclosingMethod <> '' Then
  natIdx  := CPAddNameAndType(EnclosingMethod, EnclosingDesc)
 Else
  natIdx := 0;
 BinWriteU2(nameIdx);        { attribute_name_index }
 BinWriteU4(4);              { attribute_length = 4 }
 BinWriteU2(clsIdx);         { class_index }
 BinWriteU2(natIdx);         { method_index (0 si pas de methode) }
 If OptVerbose Then
  WriteLn('    [attr] EnclosingMethod = ', EnclosingClass, '.', EnclosingMethod);
End;

{ --- ParseTypeDescriptor : parser un descripteur de type JVM --- }
{ Avance pos au-dela du type lu. Retourne True si un type valide est lu. }
{ Types: B(byte), C(char), D(double), F(float), I(int), J(long),        }
{ S(short), Z(boolean), V(void), Lclassname;, [type (tableau)           }
Function ParseTypeDescriptor(Const desc: String; Var pos: Integer): Boolean;
Var len: Integer;
Begin
 ParseTypeDescriptor := False;
 len := Length(desc);
 If pos > len Then Exit;
 { Sauter les prefixes de tableau [ }
 While (pos <= len) And (desc[pos] = '[') do
  Inc(pos);
 If pos > len Then Exit;  { [ tout seul }
 Case desc[pos] of
  'B', 'C', 'D', 'F', 'I', 'J', 'S', 'Z', 'V':
  Begin
   Inc(pos);
   ParseTypeDescriptor := True;
  End;
  'L':
  Begin
   Inc(pos); { passer le L }
   { Chercher le ; de fermeture }
   While (pos <= len) And (desc[pos] <> ';') do
    Inc(pos);
   If pos > len Then Exit;  { pas de ; }
   Inc(pos); { passer le ; }
   ParseTypeDescriptor := True;
  End;
 End;
End;

{ --- DescriptorSlotSize : nombre de slots pour un type --- }
{ Retourne 2 pour J(long) et D(double), 1 pour tous les autres. }
{ 0 pour V(void). }
Function DescriptorSlotSize(Const desc: String): Integer;
Var p: Integer;
Begin
 DescriptorSlotSize := 0;
 If Length(desc) = 0 Then Exit;
 p := 1;
 { Sauter les prefixes de tableau [ -> toujours 1 slot (reference) }
 If desc[p] = '[' Then
 Begin
  DescriptorSlotSize := 1;
  Exit;
 End;
 Case desc[p] of
  'J', 'D': DescriptorSlotSize := 2;
  'V':      DescriptorSlotSize := 0;
 Else
  DescriptorSlotSize := 1;
 End;
End;

{ --- ParseMethodDescriptor : valider un descripteur de methode --- }
{ Format: (param_types)return_type                                   }
{ Retourne True si le descripteur est syntaxiquement correct.        }
Function ParseMethodDescriptor(Const desc: String): Boolean;
Var len, pos: Integer;
Begin
 ParseMethodDescriptor := False;
 len := Length(desc);
 If len < 3 Then Exit;  { au minimum ()V }
 If desc[1] <> '(' Then Exit;
 pos := 2;
 { Parser les types des parametres }
 While (pos <= len) And (desc[pos] <> ')') do
 Begin
  If desc[pos] = 'V' Then Exit;  { V interdit comme parametre }
  If Not ParseTypeDescriptor(desc, pos) Then Exit;
 End;
 If pos > len Then Exit;  { pas de ) }
 If desc[pos] <> ')' Then Exit;
 Inc(pos); { passer le ) }
 { Parser le type de retour }
 If pos > len Then Exit;
 If Not ParseTypeDescriptor(desc, pos) Then Exit;
 { Doit etre a la fin }
 ParseMethodDescriptor := (pos = len + 1);
End;

{ --- DescriptorParamSlots : nombre total de slots pour les parametres --- }
{ Compte les slots des types parametres. Ajoute 1 pour this si non-static. }
Function DescriptorParamSlots(Const desc: String; isStatic: Boolean): Integer;
Var len, pos, slots, startP: Integer;
    oneType: String;
Begin
 slots := 0;
 If Not isStatic Then
  slots := 1; { slot 0 = this }
 len := Length(desc);
 If (len < 3) Or (desc[1] <> '(') Then
 Begin
  DescriptorParamSlots := slots;
  Exit;
 End;
 pos := 2;
 While (pos <= len) And (desc[pos] <> ')') do
 Begin
  startP := pos;
  If Not ParseTypeDescriptor(desc, pos) Then Break;
  { Extraire le type pour calculer la taille }
  oneType := Copy(desc, startP, pos - startP);
  slots := slots + DescriptorSlotSize(oneType);
 End;
 DescriptorParamSlots := slots;
End;

{ --- DescriptorReturnSlots : nombre de slots du type de retour --- }
{ 0 pour V, 1 ou 2 selon le type.                                   }
Function DescriptorReturnSlots(Const desc: String): Integer;
Var len, pos: Integer;
    retType: String;
Begin
 DescriptorReturnSlots := 0;
 len := Length(desc);
 pos := 1;
 { Trouver la ) }
 While (pos <= len) And (desc[pos] <> ')') do
  Inc(pos);
 If pos >= len Then Exit;
 Inc(pos); { passer ) }
 retType := Copy(desc, pos, len - pos + 1);
 DescriptorReturnSlots := DescriptorSlotSize(retType);
End;

{ --- ValidateDescriptor : verifier syntaxe correcte d'un descripteur --- }
{ Valide un descripteur de type (pas de methode). Accepte V.              }
Function ValidateDescriptor(Const desc: String): Boolean;
Var pos: Integer;
Begin
 ValidateDescriptor := False;
 If Length(desc) = 0 Then Exit;
 pos := 1;
 If Not ParseTypeDescriptor(desc, pos) Then Exit;
 ValidateDescriptor := (pos = Length(desc) + 1);
End;

{ --- ValidateMethodDescriptor : verifier un descripteur de methode --- }
{ Verifie les parentheses, les types des parametres (V interdit) et le  }
{ type de retour.                                                        }
Function ValidateMethodDescriptor(Const desc: String): Boolean;
Begin
 ValidateMethodDescriptor := ParseMethodDescriptor(desc);
End;

{ --- AutoLocals : calculer max_locals minimum a partir du descripteur --- }
{ Si .limit locals n'est pas defini, calcule le minimum a partir des       }
{ parametres (+ this si methode d'instance).                               }
Procedure AutoLocals(mIdx: Integer);
Var isStatic: Boolean;
    minLocals: Integer;
Begin
 With MethodTab^[mIdx] do
 Begin
  If HasLocals Then Exit; { deja defini par .limit locals }
  isStatic := (AccFlags and ACC_STATIC) <> 0;
  minLocals := DescriptorParamSlots(Desc, isStatic);
  If minLocals > MaxLocals Then
   MaxLocals := minLocals;
 End;
End;

{ --- AutoStack : calculer max_stack minimum --- }
{ Estimation simple : si pas de .limit stack, on met au moins 1           }
{ pour permettre les operations de base. Une analyse de flux precise      }
{ sera implementee plus tard avec les opcodes (TODO 10+).                 }
Procedure AutoStack(mIdx: Integer);
Begin
 With MethodTab^[mIdx] do
 Begin
  If HasStack Then Exit; { deja defini par .limit stack }
  If (HasCode) And (MaxStack = 0) Then
   MaxStack := 1;  { estimation minimale par defaut }
 End;
End;

{ ============================================================================ }
{ Opcodes de chargement et stockage (TODO 10)                                  }
{ ============================================================================ }

{ --- EmitByte : ecrire un octet dans le code buffer de la methode courante --- }
Procedure EmitByte(b: Byte);
Begin
 If Not InMethod Then
 Begin
  Error('instruction hors methode');
  Exit;
 End;
 With MethodTab^[CurMethod] do
 Begin
  If Not HasCode Then
  Begin
   Error('instruction dans methode abstract/native');
   Exit;
  End;
  If CodeSize >= MAX_CODE Then
  Begin
   Error('code buffer plein (max ' + IntToStr_(MAX_CODE) + ' octets)');
   Exit;
  End;
  Code^[CodeSize] := b;
  Inc(CodeSize);
 End;
End;

{ --- RecordFixup : enregistrer un fixup de branchement (TODO 13) --- }
{ Enregistre dans la table des fixups de la methode courante qu'a la   }
{ position patchOff dans le bytecode, il faut patcher w octets (2 ou 4)}
{ avec l'offset relatif vers le label lbl (relatif a instrOff).        }
Procedure RecordFixup(Const lbl: String; patchOff, instrOff: LongInt; w: Integer);
Begin
 If Not InMethod Then Exit;
 With MethodTab^[CurMethod] do
 Begin
  If FixupCount >= MAX_FIXUPS Then
  Begin
   Error('trop de fixups de branches (max ' + IntToStr_(MAX_FIXUPS) + ')');
   Exit;
  End;
  Inc(FixupCount);
  Fixups^[FixupCount].LabelName   := lbl;
  Fixups^[FixupCount].PatchOffset := patchOff;
  Fixups^[FixupCount].InstrOffset := instrOff;
  Fixups^[FixupCount].Width       := w;
 End;
End;

{ --- EmitBranchPlaceholder : emettre des octets placeholder (TODO 13) --- }
{ Emet w octets a zero comme placeholder pour un offset de branchement.    }
Procedure EmitBranchPlaceholder(w: Integer);
Var i: Integer;
Begin
 For i := 1 to w do
  EmitByte(0);
End;

{ ============================================================================ }
{ Labels, resolution des sauts et calcul des offsets (TODO 19)                 }
{ ============================================================================ }

{ --- LabelFind : rechercher un label par nom dans la methode courante --- }
{ Retourne l'index dans Labels (1..LabelCount) ou 0 si non trouve.         }
Function LabelFind(Const name: String): Integer;
Var i: Integer;
    lbl: String;
Begin
 LabelFind := 0;
 If Not InMethod Then Exit;
 lbl := name; { sauvegarder avant With (conflit TP case-insensitive Name) }
 With MethodTab^[CurMethod] do
 Begin
  For i := 1 to LabelCount do
  Begin
   If Labels^[i].Name = lbl Then
   Begin
    LabelFind := i;
    Exit;
   End;
  End;
 End;
End;

{ --- LabelAdd : enregistrer un label a la position PC courante --- }
{ Ajoute le label dans la table. Si le label existe deja comme         }
{ reference non resolue (forward ref), on le resout. Si il est deja    }
{ defini (Resolved=True), c'est un doublon => erreur.                  }
Procedure LabelAdd(Const name: String);
Var idx: Integer;
    lbl: String;
Begin
 lbl := name; { sauvegarder avant With (conflit TP case-insensitive Name) }
 If Not InMethod Then
 Begin
  Warning('label ''' + lbl + ':'' hors methode, ignore');
  Exit;
 End;
 With MethodTab^[CurMethod] do
 Begin
  { Chercher si le label existe deja }
  idx := LabelFind(lbl);
  If idx > 0 Then
  Begin
   If Labels^[idx].Resolved Then
   Begin
    Error('label ''' + lbl + ''' deja defini (doublon)');
    Exit;
   End;
   { Le label existait comme reference forward, on le resout }
   Labels^[idx].Offset   := CodeSize;
   Labels^[idx].Resolved := True;
   If OptVerbose Then
    WriteLn('    [label] ', lbl, ': -> PC=', CodeSize, ' (forward resolved)');
   Exit;
  End;
  { Nouveau label }
  If LabelCount >= MAX_LABELS Then
  Begin
   Error('trop de labels (max ' + IntToStr_(MAX_LABELS) + ')');
   Exit;
  End;
  Inc(LabelCount);
  Labels^[LabelCount].Name     := lbl;
  Labels^[LabelCount].Offset   := CodeSize;
  Labels^[LabelCount].Resolved := True;
  If OptVerbose Then
   WriteLn('    [label] ', lbl, ': -> PC=', CodeSize);
 End;
End;

{ --- LabelResolve : resoudre tous les fixups de branchement --- }
{ Parcourt la table des fixups de la methode courante. Pour chaque   }
{ fixup, recherche le label cible, calcule l'offset relatif           }
{ (label_pc - instr_pc), et patche les octets dans le code buffer.   }
{ Erreur si un label reference n'est pas defini.                      }
Procedure LabelResolve;
Var i, idx, j: Integer;
    relOff: LongInt;
    pOff: LongInt;
Begin
 If Not InMethod Then Exit;
 With MethodTab^[CurMethod] do
 Begin
  For i := 1 to FixupCount do
  Begin
   { Chercher le label cible }
   idx := 0;
   For j := 1 to LabelCount do
   Begin
    If Labels^[j].Name = Fixups^[i].LabelName Then
    Begin
     idx := j;
     Break;
    End;
   End;
   If idx = 0 Then
   Begin
    Error('label ''' + Fixups^[i].LabelName + ''' non defini (reference non resolue)');
    Continue;
   End;
   If Not Labels^[idx].Resolved Then
   Begin
    Error('label ''' + Fixups^[i].LabelName + ''' non resolu');
    Continue;
   End;
   { Calculer l'offset relatif : label_pc - instr_pc }
   relOff := Labels^[idx].Offset - Fixups^[i].InstrOffset;
   pOff   := Fixups^[i].PatchOffset;
   { Patcher le code buffer }
   If Fixups^[i].Width = 2 Then
   Begin
    { Verifier que l'offset tient dans un signe 16 bits }
    If (relOff < -32768) Or (relOff > 32767) Then
     Warning('offset de branchement hors limites 16 bits (' +
             IntToStr_(relOff) + ') pour label ''' +
             Fixups^[i].LabelName + '''');
    If (pOff >= 0) And (pOff + 1 < MAX_CODE) Then
    Begin
     Code^[pOff]     := Byte((relOff shr 8) and $FF);
     Code^[pOff + 1] := Byte(relOff and $FF);
    End;
   End
   Else If Fixups^[i].Width = 4 Then
   Begin
    If (pOff >= 0) And (pOff + 3 < MAX_CODE) Then
    Begin
     Code^[pOff]     := Byte((relOff shr 24) and $FF);
     Code^[pOff + 1] := Byte((relOff shr 16) and $FF);
     Code^[pOff + 2] := Byte((relOff shr 8) and $FF);
     Code^[pOff + 3] := Byte(relOff and $FF);
    End;
   End;
  End;
 End;
End;

{ ============================================================================ }
{ Attribut Code : generation binaire (TODO 20)                                 }
{ ============================================================================ }

{ --- EmitCodeAttribute : ecrire l'attribut Code d'une methode --- }
{ Ecrit dans le fichier binaire l'attribut Code complet pour la methode       }
{ specifiee par son index mIdx. Structure JVM du Code_attribute :             }
{   attribute_name_index (U2, pointe vers "Code" dans le CP)                  }
{   attribute_length (U4, taille excluant les 6 premiers octets)             }
{   max_stack (U2), max_locals (U2)                                           }
{   code_length (U4), code[] (octets du bytecode)                            }
{   exception_table_length (U2)                                               }
{   exception_table[] (start_pc, end_pc, handler_pc, catch_type)             }
{   attributes_count (U2)                                                     }
{   attributes[] (LineNumberTable si .line utilise)                           }
{ L'attribute_length est backpatche apres ecriture complete.                  }

Procedure EmitCodeAttribute(mIdx: Integer);
Var attrLenPos : LongInt;    { position du champ attribute_length           }
    attrStart  : LongInt;    { debut du contenu (apres attribute_length)    }
    codeIdx    : Integer;    { index CP de "Code"                          }
    lineIdx    : Integer;    { index CP de "LineNumberTable"               }
    subAttrCnt : Integer;    { nombre de sous-attributs                    }
    ci         : LongInt;    { index pour parcourir le bytecode            }
    i, j       : Integer;    { indices de boucle                           }
    lblIdx     : Integer;    { index dans la table des labels              }
Begin
 With MethodTab^[mIdx] do
 Begin
  If Not HasCode Then Exit;

  { --- "Code" dans le Constant Pool --- }
  codeIdx := CPEnsureUtf8('Code');

  { --- attribute_name_index (U2) --- }
  BinWriteU2(codeIdx);

  { --- attribute_length (U4) - placeholder, sera backpatche --- }
  attrLenPos := BinGetPos;
  BinWriteU4(0);
  attrStart := BinGetPos;

  { --- max_stack (U2) + max_locals (U2) --- }
  BinWriteU2(MaxStack);
  BinWriteU2(MaxLocals);

  { --- code_length (U4) --- }
  BinWriteU4(CodeSize);

  { --- code[] : octets du bytecode --- }
  If (CodeSize > 0) And (Code <> Nil) Then
  Begin
   For ci := 0 to CodeSize - 1 do
    BinWriteU1(Code^[ci]);
  End;

  { --- exception_table_length (U2) --- }
  BinWriteU2(ExcCount);

  { --- exception_table[] --- }
  { Pour chaque handler : resoudre les labels en offsets PC, puis ecrire  }
  { start_pc (U2), end_pc (U2), handler_pc (U2), catch_type (U2).        }
  For i := 1 to ExcCount do
  Begin
   { Resoudre StartLbl -> StartPC }
   If ExcTab^[i].StartLbl <> '' Then
   Begin
    lblIdx := 0;
    For j := 1 to LabelCount do
     If Labels^[j].Name = ExcTab^[i].StartLbl Then
     Begin lblIdx := j; Break; End;
    If (lblIdx > 0) And Labels^[lblIdx].Resolved Then
     ExcTab^[i].StartPC := Labels^[lblIdx].Offset
    Else
     Error('exception handler: label start ''' +
           ExcTab^[i].StartLbl + ''' non defini');
   End;
   { Resoudre EndLbl -> EndPC }
   If ExcTab^[i].EndLbl <> '' Then
   Begin
    lblIdx := 0;
    For j := 1 to LabelCount do
     If Labels^[j].Name = ExcTab^[i].EndLbl Then
     Begin lblIdx := j; Break; End;
    If (lblIdx > 0) And Labels^[lblIdx].Resolved Then
     ExcTab^[i].EndPC := Labels^[lblIdx].Offset
    Else
     Error('exception handler: label end ''' +
           ExcTab^[i].EndLbl + ''' non defini');
   End;
   { Resoudre HandlerLbl -> HandlerPC }
   If ExcTab^[i].HandlerLbl <> '' Then
   Begin
    lblIdx := 0;
    For j := 1 to LabelCount do
     If Labels^[j].Name = ExcTab^[i].HandlerLbl Then
     Begin lblIdx := j; Break; End;
    If (lblIdx > 0) And Labels^[lblIdx].Resolved Then
     ExcTab^[i].HandlerPC := Labels^[lblIdx].Offset
    Else
     Error('exception handler: label handler ''' +
           ExcTab^[i].HandlerLbl + ''' non defini');
   End;
   { CatchIdx : 0 si 'all', sinon index CP de la classe }
   If (ExcTab^[i].CatchType = '') Or (ExcTab^[i].CatchType = 'all') Then
    ExcTab^[i].CatchIdx := 0
   Else
    ExcTab^[i].CatchIdx := CPEnsureClass(ExcTab^[i].CatchType);

   BinWriteU2(ExcTab^[i].StartPC);
   BinWriteU2(ExcTab^[i].EndPC);
   BinWriteU2(ExcTab^[i].HandlerPC);
   BinWriteU2(ExcTab^[i].CatchIdx);
  End;

  { --- Sous-attributs du Code_attribute --- }
  { Compter les sous-attributs presents }
  subAttrCnt := 0;
  If LineCount > 0 Then Inc(subAttrCnt);  { LineNumberTable }

  { attributes_count (U2) }
  BinWriteU2(subAttrCnt);

  { --- LineNumberTable_attribute (si .line utilise) --- }
  { Structure :                                                             }
  {   attribute_name_index (U2, "LineNumberTable")                         }
  {   attribute_length (U4, = 2 + 4 * line_number_table_length)            }
  {   line_number_table_length (U2)                                        }
  {   line_number_table[] : start_pc (U2), line_number (U2)               }
  If LineCount > 0 Then
  Begin
   lineIdx := CPEnsureUtf8('LineNumberTable');
   BinWriteU2(lineIdx);
   BinWriteU4(2 + 4 * LongInt(LineCount));
   BinWriteU2(LineCount);
   For i := 1 to LineCount do
   Begin
    BinWriteU2(LineTab^[i].Offset);
    BinWriteU2(LineTab^[i].Line);
   End;
  End;

  { --- Backpatcher attribute_length --- }
  BinPatchU4(attrLenPos, BinGetPos - attrStart);

  If OptVerbose Then
   WriteLn('    [code] methode ', Name, Desc,
           ' : ', CodeSize, ' octets, stack=', MaxStack,
           ', locals=', MaxLocals, ', exc=', ExcCount,
           ', lines=', LineCount);
 End;
End;

{ ============================================================================ }
{ Opcodes d'invocation de methodes (TODO 14)                                   }
{ ============================================================================ }

{ --- ParseMethodSpec : decomposer une specification de methode JVM --- }
{ Recoit une specification de la forme classe/nom(descripteur)retour     }
{ et la decompose en : cls (nom de classe), mname (nom de methode),     }
{ desc (descripteur complet incluant parentheses et type retour).       }
{ Retourne True si le parsing a reussi.                                 }
{ Exemple: java/io/PrintStream/println(Ljava/lang/String;)V            }
{          -> cls='java/io/PrintStream' mname='println'                 }
{             desc='(Ljava/lang/String;)V'                              }
Function ParseMethodSpec(Const spec: String; Var cls, mname, desc: String): Boolean;
Var paren, lastSlash, i: Integer;
Begin
 ParseMethodSpec := False;
 cls   := '';
 mname := '';
 desc  := '';
 { Trouver la position de '(' }
 paren := Pos('(', spec);
 If paren = 0 Then
 Begin
  Error('specification de methode invalide : parenthese manquante dans ' + spec);
  Exit;
 End;
 { Le descripteur est tout a partir de '(' }
 desc := Copy(spec, paren, Length(spec) - paren + 1);
 { Trouver le dernier '/' avant '(' pour separer classe et nom }
 lastSlash := 0;
 For i := paren - 1 downto 1 do
 Begin
  If spec[i] = '/' Then
  Begin
   lastSlash := i;
   Break;
  End;
 End;
 If lastSlash = 0 Then
 Begin
  { Pas de '/' : classe vide = methode de la classe en cours d'assemblage }
  cls   := '';
  mname := Copy(spec, 1, paren - 1);
 End
 Else
 Begin
  cls   := Copy(spec, 1, lastSlash - 1);
  mname := Copy(spec, lastSlash + 1, paren - lastSlash - 1);
 End;
 If mname = '' Then
 Begin
  Error('specification de methode invalide : nom de methode vide dans ' + spec);
  Exit;
 End;
 ParseMethodSpec := True;
End;

{ --- ParseFieldSpec : decomposer une specification de champ JVM --- }
{ Recoit une specification de la forme classe/nom                     }
{ et la decompose en : cls (nom de classe), fname (nom de champ).    }
{ Le dernier '/' separe la classe du nom de champ.                    }
{ Retourne True si le parsing a reussi.                               }
{ Exemple: java/lang/System/out                                       }
{          -> cls='java/lang/System' fname='out'                      }
Function ParseFieldSpec(Const spec: String; Var cls, fname: String): Boolean;
Var lastSlash, i: Integer;
Begin
 ParseFieldSpec := False;
 cls   := '';
 fname := '';
 { Trouver le dernier '/' pour separer classe et nom de champ }
 lastSlash := 0;
 For i := Length(spec) downto 1 do
 Begin
  If spec[i] = '/' Then
  Begin
   lastSlash := i;
   Break;
  End;
 End;
 If lastSlash = 0 Then
 Begin
  Error('specification de champ invalide : "/" manquant dans ' + spec);
  Exit;
 End;
 cls   := Copy(spec, 1, lastSlash - 1);
 fname := Copy(spec, lastSlash + 1, Length(spec) - lastSlash);
 If cls = '' Then
 Begin
  Error('specification de champ invalide : nom de classe vide dans ' + spec);
  Exit;
 End;
 If fname = '' Then
 Begin
  Error('specification de champ invalide : nom de champ vide dans ' + spec);
  Exit;
 End;
 ParseFieldSpec := True;
End;

{ --- ParseInstruction : reconnaitre et emettre un mnemonique JVM --- }
{ Lit CurStr (le mnemonique), emet le(s) octet(s) correspondant(s)    }
{ dans le code buffer de la methode courante via EmitByte.             }
{ Retourne True si le mnemonique a ete reconnu et emis.                }
{ TODO 10 : opcodes de chargement/stockage (iload/istore/lload/       }
{ lstore/fload/fstore/dload/dstore/aload/astore + variantes _0-_3,   }
{ iaload..saload, iastore..sastore).                                   }
{ TODO 11 : opcodes arithmetiques et logiques (iadd..dneg, ishl..lxor,}
{ iinc).                                                               }
{ TODO 13 : opcodes de controle de flux (goto, ifeq..ifle,            }
{ if_icmpeq..if_icmple, if_acmpeq/ne, ifnull/nonnull, lcmp, fcmpl/g, }
{ dcmpl/g, tableswitch, lookupswitch, ret, jsr/jsr_w, goto_w).        }
{ TODO 14 : opcodes d'invocation de methodes (invokevirtual,          }
{ invokespecial, invokestatic, invokeinterface, invokedynamic).        }
{ TODO 15 : opcodes de manipulation de la pile (nop, pop, pop2, dup,  }
{ dup_x1, dup_x2, dup2, dup2_x1, dup2_x2, swap) et chargement de    }
{ constantes (aconst_null, iconst_m1..5, lconst_0/1, fconst_0/1/2,   }
{ dconst_0/1, bipush, sipush, ldc, ldc_w, ldc2_w).                    }
{ TODO 18 : opcodes de retour (ireturn..return), athrow,              }
{ monitorenter/monitorexit, wide prefix.                               }
{ Les TODOs suivantes ajouteront d'autres familles d'opcodes.          }
Function ParseInstruction: Boolean;
Var mnem: String;
    opvar: Integer;
    brLabel: String;
    brInstrOff: LongInt;
    swPadding, swLow, swHigh, swCount, swI: LongInt;
    swDefault: String;
    invSpec, invCls, invName, invDesc: String;
    invIdx, invCount: Integer;
    ldcIdx: Integer;
    ldcStr: String;
    dhi, dlo: LongInt;
    objIdx: Integer;
    arrType: Integer;
    fldSpec, fldCls, fldName, fldDesc: String;
    fldIdx: Integer;
    wideOpc: String;
    wideIdx, wideConst: Integer;
Begin
 ParseInstruction := False;
 mnem := CurStr;
 { ---------------------------------------------------------------- }
 { Instructions de chargement depuis les variables locales           }
 { ---------------------------------------------------------------- }
 { iload <var> }
 If mnem = 'iload' Then
 Begin
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('iload : operande entiere attendue'); Exit; End;
  opvar := CurInt;
  Consume;
  If opvar > 255 Then
  Begin Error('iload : index > 255 (utiliser wide)'); Exit; End;
  EmitByte($15); { iload }
  EmitByte(Byte(opvar));
  ParseInstruction := True; Exit;
 End;
 If mnem = 'iload_0' Then Begin Consume; EmitByte($1A); ParseInstruction := True; Exit; End;
 If mnem = 'iload_1' Then Begin Consume; EmitByte($1B); ParseInstruction := True; Exit; End;
 If mnem = 'iload_2' Then Begin Consume; EmitByte($1C); ParseInstruction := True; Exit; End;
 If mnem = 'iload_3' Then Begin Consume; EmitByte($1D); ParseInstruction := True; Exit; End;
 { lload <var> }
 If mnem = 'lload' Then
 Begin
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('lload : operande entiere attendue'); Exit; End;
  opvar := CurInt;
  Consume;
  If opvar > 255 Then
  Begin Error('lload : index > 255'); Exit; End;
  EmitByte($16); { lload }
  EmitByte(Byte(opvar));
  ParseInstruction := True; Exit;
 End;
 If mnem = 'lload_0' Then Begin Consume; EmitByte($1E); ParseInstruction := True; Exit; End;
 If mnem = 'lload_1' Then Begin Consume; EmitByte($1F); ParseInstruction := True; Exit; End;
 If mnem = 'lload_2' Then Begin Consume; EmitByte($20); ParseInstruction := True; Exit; End;
 If mnem = 'lload_3' Then Begin Consume; EmitByte($21); ParseInstruction := True; Exit; End;
 { fload <var> }
 If mnem = 'fload' Then
 Begin
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('fload : operande entiere attendue'); Exit; End;
  opvar := CurInt;
  Consume;
  If opvar > 255 Then
  Begin Error('fload : index > 255'); Exit; End;
  EmitByte($17); { fload }
  EmitByte(Byte(opvar));
  ParseInstruction := True; Exit;
 End;
 If mnem = 'fload_0' Then Begin Consume; EmitByte($22); ParseInstruction := True; Exit; End;
 If mnem = 'fload_1' Then Begin Consume; EmitByte($23); ParseInstruction := True; Exit; End;
 If mnem = 'fload_2' Then Begin Consume; EmitByte($24); ParseInstruction := True; Exit; End;
 If mnem = 'fload_3' Then Begin Consume; EmitByte($25); ParseInstruction := True; Exit; End;
 { dload <var> }
 If mnem = 'dload' Then
 Begin
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('dload : operande entiere attendue'); Exit; End;
  opvar := CurInt;
  Consume;
  If opvar > 255 Then
  Begin Error('dload : index > 255'); Exit; End;
  EmitByte($18); { dload }
  EmitByte(Byte(opvar));
  ParseInstruction := True; Exit;
 End;
 If mnem = 'dload_0' Then Begin Consume; EmitByte($26); ParseInstruction := True; Exit; End;
 If mnem = 'dload_1' Then Begin Consume; EmitByte($27); ParseInstruction := True; Exit; End;
 If mnem = 'dload_2' Then Begin Consume; EmitByte($28); ParseInstruction := True; Exit; End;
 If mnem = 'dload_3' Then Begin Consume; EmitByte($29); ParseInstruction := True; Exit; End;
 { aload <var> }
 If mnem = 'aload' Then
 Begin
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('aload : operande entiere attendue'); Exit; End;
  opvar := CurInt;
  Consume;
  If opvar > 255 Then
  Begin Error('aload : index > 255'); Exit; End;
  EmitByte($19); { aload }
  EmitByte(Byte(opvar));
  ParseInstruction := True; Exit;
 End;
 If mnem = 'aload_0' Then Begin Consume; EmitByte($2A); ParseInstruction := True; Exit; End;
 If mnem = 'aload_1' Then Begin Consume; EmitByte($2B); ParseInstruction := True; Exit; End;
 If mnem = 'aload_2' Then Begin Consume; EmitByte($2C); ParseInstruction := True; Exit; End;
 If mnem = 'aload_3' Then Begin Consume; EmitByte($2D); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Instructions de stockage dans les variables locales               }
 { ---------------------------------------------------------------- }
 { istore <var> }
 If mnem = 'istore' Then
 Begin
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('istore : operande entiere attendue'); Exit; End;
  opvar := CurInt;
  Consume;
  If opvar > 255 Then
  Begin Error('istore : index > 255'); Exit; End;
  EmitByte($36); { istore }
  EmitByte(Byte(opvar));
  ParseInstruction := True; Exit;
 End;
 If mnem = 'istore_0' Then Begin Consume; EmitByte($3B); ParseInstruction := True; Exit; End;
 If mnem = 'istore_1' Then Begin Consume; EmitByte($3C); ParseInstruction := True; Exit; End;
 If mnem = 'istore_2' Then Begin Consume; EmitByte($3D); ParseInstruction := True; Exit; End;
 If mnem = 'istore_3' Then Begin Consume; EmitByte($3E); ParseInstruction := True; Exit; End;
 { lstore <var> }
 If mnem = 'lstore' Then
 Begin
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('lstore : operande entiere attendue'); Exit; End;
  opvar := CurInt;
  Consume;
  If opvar > 255 Then
  Begin Error('lstore : index > 255'); Exit; End;
  EmitByte($37); { lstore }
  EmitByte(Byte(opvar));
  ParseInstruction := True; Exit;
 End;
 If mnem = 'lstore_0' Then Begin Consume; EmitByte($3F); ParseInstruction := True; Exit; End;
 If mnem = 'lstore_1' Then Begin Consume; EmitByte($40); ParseInstruction := True; Exit; End;
 If mnem = 'lstore_2' Then Begin Consume; EmitByte($41); ParseInstruction := True; Exit; End;
 If mnem = 'lstore_3' Then Begin Consume; EmitByte($42); ParseInstruction := True; Exit; End;
 { fstore <var> }
 If mnem = 'fstore' Then
 Begin
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('fstore : operande entiere attendue'); Exit; End;
  opvar := CurInt;
  Consume;
  If opvar > 255 Then
  Begin Error('fstore : index > 255'); Exit; End;
  EmitByte($38); { fstore }
  EmitByte(Byte(opvar));
  ParseInstruction := True; Exit;
 End;
 If mnem = 'fstore_0' Then Begin Consume; EmitByte($43); ParseInstruction := True; Exit; End;
 If mnem = 'fstore_1' Then Begin Consume; EmitByte($44); ParseInstruction := True; Exit; End;
 If mnem = 'fstore_2' Then Begin Consume; EmitByte($45); ParseInstruction := True; Exit; End;
 If mnem = 'fstore_3' Then Begin Consume; EmitByte($46); ParseInstruction := True; Exit; End;
 { dstore <var> }
 If mnem = 'dstore' Then
 Begin
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('dstore : operande entiere attendue'); Exit; End;
  opvar := CurInt;
  Consume;
  If opvar > 255 Then
  Begin Error('dstore : index > 255'); Exit; End;
  EmitByte($39); { dstore }
  EmitByte(Byte(opvar));
  ParseInstruction := True; Exit;
 End;
 If mnem = 'dstore_0' Then Begin Consume; EmitByte($47); ParseInstruction := True; Exit; End;
 If mnem = 'dstore_1' Then Begin Consume; EmitByte($48); ParseInstruction := True; Exit; End;
 If mnem = 'dstore_2' Then Begin Consume; EmitByte($49); ParseInstruction := True; Exit; End;
 If mnem = 'dstore_3' Then Begin Consume; EmitByte($4A); ParseInstruction := True; Exit; End;
 { astore <var> }
 If mnem = 'astore' Then
 Begin
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('astore : operande entiere attendue'); Exit; End;
  opvar := CurInt;
  Consume;
  If opvar > 255 Then
  Begin Error('astore : index > 255'); Exit; End;
  EmitByte($3A); { astore }
  EmitByte(Byte(opvar));
  ParseInstruction := True; Exit;
 End;
 If mnem = 'astore_0' Then Begin Consume; EmitByte($4B); ParseInstruction := True; Exit; End;
 If mnem = 'astore_1' Then Begin Consume; EmitByte($4C); ParseInstruction := True; Exit; End;
 If mnem = 'astore_2' Then Begin Consume; EmitByte($4D); ParseInstruction := True; Exit; End;
 If mnem = 'astore_3' Then Begin Consume; EmitByte($4E); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Instructions de chargement depuis les tableaux                    }
 { ---------------------------------------------------------------- }
 If mnem = 'iaload' Then Begin Consume; EmitByte($2E); ParseInstruction := True; Exit; End;
 If mnem = 'laload' Then Begin Consume; EmitByte($2F); ParseInstruction := True; Exit; End;
 If mnem = 'faload' Then Begin Consume; EmitByte($30); ParseInstruction := True; Exit; End;
 If mnem = 'daload' Then Begin Consume; EmitByte($31); ParseInstruction := True; Exit; End;
 If mnem = 'aaload' Then Begin Consume; EmitByte($32); ParseInstruction := True; Exit; End;
 If mnem = 'baload' Then Begin Consume; EmitByte($33); ParseInstruction := True; Exit; End;
 If mnem = 'caload' Then Begin Consume; EmitByte($34); ParseInstruction := True; Exit; End;
 If mnem = 'saload' Then Begin Consume; EmitByte($35); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Instructions de stockage dans les tableaux                        }
 { ---------------------------------------------------------------- }
 If mnem = 'iastore' Then Begin Consume; EmitByte($4F); ParseInstruction := True; Exit; End;
 If mnem = 'lastore' Then Begin Consume; EmitByte($50); ParseInstruction := True; Exit; End;
 If mnem = 'fastore' Then Begin Consume; EmitByte($51); ParseInstruction := True; Exit; End;
 If mnem = 'dastore' Then Begin Consume; EmitByte($52); ParseInstruction := True; Exit; End;
 If mnem = 'aastore' Then Begin Consume; EmitByte($53); ParseInstruction := True; Exit; End;
 If mnem = 'bastore' Then Begin Consume; EmitByte($54); ParseInstruction := True; Exit; End;
 If mnem = 'castore' Then Begin Consume; EmitByte($55); ParseInstruction := True; Exit; End;
 If mnem = 'sastore' Then Begin Consume; EmitByte($56); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Arithmetique entiere (int) - TODO 11                              }
 { ---------------------------------------------------------------- }
 If mnem = 'iadd' Then Begin Consume; EmitByte($60); ParseInstruction := True; Exit; End;
 If mnem = 'isub' Then Begin Consume; EmitByte($64); ParseInstruction := True; Exit; End;
 If mnem = 'imul' Then Begin Consume; EmitByte($68); ParseInstruction := True; Exit; End;
 If mnem = 'idiv' Then Begin Consume; EmitByte($6C); ParseInstruction := True; Exit; End;
 If mnem = 'irem' Then Begin Consume; EmitByte($70); ParseInstruction := True; Exit; End;
 If mnem = 'ineg' Then Begin Consume; EmitByte($74); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Arithmetique longue (long) - TODO 11                              }
 { ---------------------------------------------------------------- }
 If mnem = 'ladd' Then Begin Consume; EmitByte($61); ParseInstruction := True; Exit; End;
 If mnem = 'lsub' Then Begin Consume; EmitByte($65); ParseInstruction := True; Exit; End;
 If mnem = 'lmul' Then Begin Consume; EmitByte($69); ParseInstruction := True; Exit; End;
 If mnem = 'ldiv' Then Begin Consume; EmitByte($6D); ParseInstruction := True; Exit; End;
 If mnem = 'lrem' Then Begin Consume; EmitByte($71); ParseInstruction := True; Exit; End;
 If mnem = 'lneg' Then Begin Consume; EmitByte($75); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Arithmetique flottante (float) - TODO 11                          }
 { ---------------------------------------------------------------- }
 If mnem = 'fadd' Then Begin Consume; EmitByte($62); ParseInstruction := True; Exit; End;
 If mnem = 'fsub' Then Begin Consume; EmitByte($66); ParseInstruction := True; Exit; End;
 If mnem = 'fmul' Then Begin Consume; EmitByte($6A); ParseInstruction := True; Exit; End;
 If mnem = 'fdiv' Then Begin Consume; EmitByte($6E); ParseInstruction := True; Exit; End;
 If mnem = 'frem' Then Begin Consume; EmitByte($72); ParseInstruction := True; Exit; End;
 If mnem = 'fneg' Then Begin Consume; EmitByte($76); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Arithmetique double (double) - TODO 11                            }
 { ---------------------------------------------------------------- }
 If mnem = 'dadd' Then Begin Consume; EmitByte($63); ParseInstruction := True; Exit; End;
 If mnem = 'dsub' Then Begin Consume; EmitByte($67); ParseInstruction := True; Exit; End;
 If mnem = 'dmul' Then Begin Consume; EmitByte($6B); ParseInstruction := True; Exit; End;
 If mnem = 'ddiv' Then Begin Consume; EmitByte($6F); ParseInstruction := True; Exit; End;
 If mnem = 'drem' Then Begin Consume; EmitByte($73); ParseInstruction := True; Exit; End;
 If mnem = 'dneg' Then Begin Consume; EmitByte($77); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Operations sur les bits (int) - TODO 11                           }
 { ---------------------------------------------------------------- }
 If mnem = 'ishl'  Then Begin Consume; EmitByte($78); ParseInstruction := True; Exit; End;
 If mnem = 'ishr'  Then Begin Consume; EmitByte($7A); ParseInstruction := True; Exit; End;
 If mnem = 'iushr' Then Begin Consume; EmitByte($7C); ParseInstruction := True; Exit; End;
 If mnem = 'iand'  Then Begin Consume; EmitByte($7E); ParseInstruction := True; Exit; End;
 If mnem = 'ior'   Then Begin Consume; EmitByte($80); ParseInstruction := True; Exit; End;
 If mnem = 'ixor'  Then Begin Consume; EmitByte($82); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Operations sur les bits (long) - TODO 11                          }
 { ---------------------------------------------------------------- }
 If mnem = 'lshl'  Then Begin Consume; EmitByte($79); ParseInstruction := True; Exit; End;
 If mnem = 'lshr'  Then Begin Consume; EmitByte($7B); ParseInstruction := True; Exit; End;
 If mnem = 'lushr' Then Begin Consume; EmitByte($7D); ParseInstruction := True; Exit; End;
 If mnem = 'land'  Then Begin Consume; EmitByte($7F); ParseInstruction := True; Exit; End;
 If mnem = 'lor'   Then Begin Consume; EmitByte($81); ParseInstruction := True; Exit; End;
 If mnem = 'lxor'  Then Begin Consume; EmitByte($83); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Increment local - TODO 11                                         }
 { iinc <var> <const> : 3 octets ($84, var, const)                  }
 { ---------------------------------------------------------------- }
 If mnem = 'iinc' Then
 Begin
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('iinc : operande variable entiere attendue'); Exit; End;
  opvar := CurInt;
  Consume;
  If opvar > 255 Then
  Begin Error('iinc : index variable > 255 (utiliser wide)'); Exit; End;
  { Lire la constante d'increment }
  If (CurTok <> TK_INTEGER) And (CurTok <> TK_MINUS) Then
  Begin Error('iinc : constante entiere attendue'); Exit; End;
  If CurTok = TK_MINUS Then
  Begin
   Consume;
   If CurTok <> TK_INTEGER Then
   Begin Error('iinc : constante entiere attendue apres -'); Exit; End;
   CurInt := -CurInt;
  End;
  If (CurInt < -128) or (CurInt > 127) Then
  Begin Error('iinc : constante hors limites (-128..127)'); Exit; End;
  EmitByte($84); { iinc }
  EmitByte(Byte(opvar));
  EmitByte(Byte(CurInt and $FF));
  Consume;
  ParseInstruction := True; Exit;
 End;
 { ---------------------------------------------------------------- }
 { Conversions numeriques int -> long/float/double - TODO 12         }
 { ---------------------------------------------------------------- }
 If mnem = 'i2l' Then Begin Consume; EmitByte($85); ParseInstruction := True; Exit; End;
 If mnem = 'i2f' Then Begin Consume; EmitByte($86); ParseInstruction := True; Exit; End;
 If mnem = 'i2d' Then Begin Consume; EmitByte($87); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Conversions numeriques long -> int/float/double - TODO 12         }
 { ---------------------------------------------------------------- }
 If mnem = 'l2i' Then Begin Consume; EmitByte($88); ParseInstruction := True; Exit; End;
 If mnem = 'l2f' Then Begin Consume; EmitByte($89); ParseInstruction := True; Exit; End;
 If mnem = 'l2d' Then Begin Consume; EmitByte($8A); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Conversions numeriques float -> int/long/double - TODO 12         }
 { ---------------------------------------------------------------- }
 If mnem = 'f2i' Then Begin Consume; EmitByte($8B); ParseInstruction := True; Exit; End;
 If mnem = 'f2l' Then Begin Consume; EmitByte($8C); ParseInstruction := True; Exit; End;
 If mnem = 'f2d' Then Begin Consume; EmitByte($8D); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Conversions numeriques double -> int/long/float - TODO 12         }
 { ---------------------------------------------------------------- }
 If mnem = 'd2i' Then Begin Consume; EmitByte($8E); ParseInstruction := True; Exit; End;
 If mnem = 'd2l' Then Begin Consume; EmitByte($8F); ParseInstruction := True; Exit; End;
 If mnem = 'd2f' Then Begin Consume; EmitByte($90); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Conversions de troncature int -> byte/char/short - TODO 12        }
 { ---------------------------------------------------------------- }
 If mnem = 'i2b' Then Begin Consume; EmitByte($91); ParseInstruction := True; Exit; End;
 If mnem = 'i2c' Then Begin Consume; EmitByte($92); ParseInstruction := True; Exit; End;
 If mnem = 'i2s' Then Begin Consume; EmitByte($93); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { Branchements inconditionnels - TODO 13                           }
 { ---------------------------------------------------------------- }
 { goto <label> : saut inconditionnel 16 bits ($A7) }
 If mnem = 'goto' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('goto : label attendu'); Exit; End;
  brLabel := CurStr;
  Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($A7); { goto }
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 { goto_w <label> : saut inconditionnel 32 bits ($C8) }
 If mnem = 'goto_w' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('goto_w : label attendu'); Exit; End;
  brLabel := CurStr;
  Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($C8); { goto_w }
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 4);
  EmitBranchPlaceholder(4);
  ParseInstruction := True; Exit;
 End;
 { jsr <label> : jump subroutine 16 bits ($A8, deprecie) }
 If mnem = 'jsr' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('jsr : label attendu'); Exit; End;
  brLabel := CurStr;
  Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($A8); { jsr }
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 { jsr_w <label> : jump subroutine 32 bits ($C9, deprecie) }
 If mnem = 'jsr_w' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('jsr_w : label attendu'); Exit; End;
  brLabel := CurStr;
  Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($C9); { jsr_w }
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 4);
  EmitBranchPlaceholder(4);
  ParseInstruction := True; Exit;
 End;
 { ret <var> : retour de subroutine ($A9, deprecie) }
 If mnem = 'ret' Then
 Begin
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('ret : operande entiere attendue'); Exit; End;
  opvar := CurInt;
  Consume;
  If opvar > 255 Then
  Begin Error('ret : index > 255'); Exit; End;
  EmitByte($A9); { ret }
  EmitByte(Byte(opvar));
  ParseInstruction := True; Exit;
 End;
 { ---------------------------------------------------------------- }
 { Branchements conditionnels sur un int - TODO 13                  }
 { ---------------------------------------------------------------- }
 If mnem = 'ifeq' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('ifeq : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($99);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 If mnem = 'ifne' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('ifne : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($9A);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 If mnem = 'iflt' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('iflt : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($9B);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 If mnem = 'ifge' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('ifge : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($9C);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 If mnem = 'ifgt' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('ifgt : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($9D);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 If mnem = 'ifle' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('ifle : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($9E);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 { ---------------------------------------------------------------- }
 { Branchements de comparaison entre deux int - TODO 13             }
 { ---------------------------------------------------------------- }
 If mnem = 'if_icmpeq' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('if_icmpeq : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($9F);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 If mnem = 'if_icmpne' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('if_icmpne : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($A0);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 If mnem = 'if_icmplt' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('if_icmplt : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($A1);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 If mnem = 'if_icmpge' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('if_icmpge : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($A2);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 If mnem = 'if_icmpgt' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('if_icmpgt : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($A3);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 If mnem = 'if_icmple' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('if_icmple : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($A4);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 { ---------------------------------------------------------------- }
 { Branchements de comparaison de references - TODO 13              }
 { ---------------------------------------------------------------- }
 If mnem = 'if_acmpeq' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('if_acmpeq : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($A5);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 If mnem = 'if_acmpne' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('if_acmpne : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($A6);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 If mnem = 'ifnull' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('ifnull : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($C6);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 If mnem = 'ifnonnull' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('ifnonnull : label attendu'); Exit; End;
  brLabel := CurStr; Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($C7);
  RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 2);
  EmitBranchPlaceholder(2);
  ParseInstruction := True; Exit;
 End;
 { ---------------------------------------------------------------- }
 { Comparaisons numeriques - TODO 13                                }
 { ---------------------------------------------------------------- }
 If mnem = 'lcmp' Then Begin Consume; EmitByte($94); ParseInstruction := True; Exit; End;
 If mnem = 'fcmpl' Then Begin Consume; EmitByte($95); ParseInstruction := True; Exit; End;
 If mnem = 'fcmpg' Then Begin Consume; EmitByte($96); ParseInstruction := True; Exit; End;
 If mnem = 'dcmpl' Then Begin Consume; EmitByte($97); ParseInstruction := True; Exit; End;
 If mnem = 'dcmpg' Then Begin Consume; EmitByte($98); ParseInstruction := True; Exit; End;
 { ---------------------------------------------------------------- }
 { tableswitch - TODO 13                                            }
 { Format: tableswitch <low> <high>                                 }
 {           <label1>                                               }
 {           ...                                                    }
 {           <labelN>                                               }
 {           default : <label>                                      }
 { ---------------------------------------------------------------- }
 If mnem = 'tableswitch' Then
 Begin
  Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($AA); { tableswitch }
  { Padding a alignement 4 octets depuis le debut de la methode }
  swPadding := (4 - ((brInstrOff + 1) mod 4)) mod 4;
  For swI := 1 to swPadding do
   EmitByte(0);
  { Lire low }
  If CurTok <> TK_INTEGER Then
  Begin Error('tableswitch : <low> entier attendu'); Exit; End;
  swLow := CurInt;
  Consume;
  { Lire high }
  If CurTok <> TK_INTEGER Then
  Begin Error('tableswitch : <high> entier attendu'); Exit; End;
  swHigh := CurInt;
  Consume;
  If swHigh < swLow Then
  Begin Error('tableswitch : high < low'); Exit; End;
  swCount := swHigh - swLow + 1;
  { Sauter les newlines }
  While CurTok = TK_NEWLINE do Consume;
  { Placeholder pour default offset (4 octets, patche apres) }
  { On reservera le default offset ici, patch plus tard        }
  { Pour le moment on emet 4 octets zero                       }
  RecordFixup('', MethodTab^[CurMethod].CodeSize, brInstrOff, 4);
  EmitBranchPlaceholder(4); { default - sera resolu plus tard }
  { Emettre low et high en big-endian (4 octets chacun) }
  EmitByte(Byte((swLow shr 24) and $FF));
  EmitByte(Byte((swLow shr 16) and $FF));
  EmitByte(Byte((swLow shr 8) and $FF));
  EmitByte(Byte(swLow and $FF));
  EmitByte(Byte((swHigh shr 24) and $FF));
  EmitByte(Byte((swHigh shr 16) and $FF));
  EmitByte(Byte((swHigh shr 8) and $FF));
  EmitByte(Byte(swHigh and $FF));
  { Lire swCount labels (offsets vers les cas) }
  For swI := 1 to swCount do
  Begin
   While CurTok = TK_NEWLINE do Consume;
   If CurTok <> TK_IDENT Then
   Begin Error('tableswitch : label attendu pour cas ' + IntToStr_(swI)); Exit; End;
   brLabel := CurStr;
   Consume;
   RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 4);
   EmitBranchPlaceholder(4);
  End;
  { Lire default : <label> }
  While CurTok = TK_NEWLINE do Consume;
  If CurStr = 'default' Then
  Begin
   Consume;
   { Sauter le ':' s'il est present }
   If CurTok = TK_COLON Then Consume;
   If CurTok <> TK_IDENT Then
   Begin Error('tableswitch : label attendu apres default'); Exit; End;
   swDefault := CurStr;
   Consume;
   { Patcher le fixup du default (le premier enregistre) }
   { On met a jour le label du fixup de default }
   With MethodTab^[CurMethod] do
   Begin
    { Le fixup du default est celui avec LabelName vide }
    For swI := 1 to FixupCount do
    Begin
     If (Fixups^[swI].LabelName = '') And
        (Fixups^[swI].InstrOffset = brInstrOff) Then
     Begin
      Fixups^[swI].LabelName := swDefault;
      Break;
     End;
    End;
   End;
  End
  Else
   Warning('tableswitch : clause default manquante');
  ParseInstruction := True; Exit;
 End;
 { ---------------------------------------------------------------- }
 { lookupswitch - TODO 13                                           }
 { Format: lookupswitch                                             }
 {           <key1> : <label1>                                      }
 {           ...                                                    }
 {           <keyN> : <labelN>                                      }
 {           default : <label>                                      }
 { ---------------------------------------------------------------- }
 If mnem = 'lookupswitch' Then
 Begin
  Consume;
  brInstrOff := MethodTab^[CurMethod].CodeSize;
  EmitByte($AB); { lookupswitch }
  { Padding a alignement 4 octets }
  swPadding := (4 - ((brInstrOff + 1) mod 4)) mod 4;
  For swI := 1 to swPadding do
   EmitByte(0);
  { Placeholder pour default offset (4 octets) }
  RecordFixup('', MethodTab^[CurMethod].CodeSize, brInstrOff, 4);
  EmitBranchPlaceholder(4); { default }
  { Placeholder pour npairs (4 octets) - on le remplira apres }
  { Sauvegarder la position pour patcher npairs               }
  swCount := 0;
  { Position du npairs dans le code }
  { On emet 4 octets zero pour npairs }
  { On ne peut pas facilement patcher in-place dans notre structure, }
  { donc on comptera d'abord les paires puis emettra. Mais cela     }
  { necessite de lire en avance. Pour simplifier, on emet npairs=0  }
  { et on le patchera.                                               }
  { Position dans le code ou npairs est ecrit }
  swLow := MethodTab^[CurMethod].CodeSize; { position pour patcher npairs }
  EmitBranchPlaceholder(4); { npairs placeholder }
  { Lire les paires key:label et default }
  While CurTok = TK_NEWLINE do Consume;
  swCount := 0;
  While (CurTok <> TK_EOF) do
  Begin
   While CurTok = TK_NEWLINE do Consume;
   { Verifier si c'est 'default' }
   If (CurTok = TK_IDENT) And (CurStr = 'default') Then Break;
   { Lire key (entier, possiblement negatif) }
   If (CurTok = TK_MINUS) Then
   Begin
    Consume;
    If CurTok <> TK_INTEGER Then
    Begin Error('lookupswitch : cle entiere attendue'); Exit; End;
    swHigh := -CurInt;
    Consume;
   End
   Else If CurTok = TK_INTEGER Then
   Begin
    swHigh := CurInt;
    Consume;
   End
   Else Break;
   { Sauter le ':' s'il est present }
   If CurTok = TK_COLON Then Consume;
   { Lire label }
   If CurTok <> TK_IDENT Then
   Begin Error('lookupswitch : label attendu pour paire'); Exit; End;
   brLabel := CurStr;
   Consume;
   { Emettre key en big-endian (4 octets) }
   EmitByte(Byte((swHigh shr 24) and $FF));
   EmitByte(Byte((swHigh shr 16) and $FF));
   EmitByte(Byte((swHigh shr 8) and $FF));
   EmitByte(Byte(swHigh and $FF));
   { Emettre placeholder pour offset }
   RecordFixup(brLabel, MethodTab^[CurMethod].CodeSize, brInstrOff, 4);
   EmitBranchPlaceholder(4);
   Inc(swCount);
  End;
  { Patcher npairs dans le code }
  With MethodTab^[CurMethod] do
  Begin
   Code^[swLow]     := Byte((swCount shr 24) and $FF);
   Code^[swLow + 1] := Byte((swCount shr 16) and $FF);
   Code^[swLow + 2] := Byte((swCount shr 8) and $FF);
   Code^[swLow + 3] := Byte(swCount and $FF);
  End;
  { Lire default : <label> }
  If (CurTok = TK_IDENT) And (CurStr = 'default') Then
  Begin
   Consume;
   If CurTok = TK_COLON Then Consume;
   If CurTok <> TK_IDENT Then
   Begin Error('lookupswitch : label attendu apres default'); Exit; End;
   swDefault := CurStr;
   Consume;
   With MethodTab^[CurMethod] do
   Begin
    For swI := 1 to FixupCount do
    Begin
     If (Fixups^[swI].LabelName = '') And
        (Fixups^[swI].InstrOffset = brInstrOff) Then
     Begin
      Fixups^[swI].LabelName := swDefault;
      Break;
     End;
    End;
   End;
  End
  Else
   Warning('lookupswitch : clause default manquante');
  ParseInstruction := True; Exit;
 End;
 { ---------------------------------------------------------------- }
 { Opcodes d'invocation de methodes - TODO 14                       }
 { ---------------------------------------------------------------- }
 { invokevirtual <method_spec> : appel methode d'instance ($B6) }
 If mnem = 'invokevirtual' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('invokevirtual : specification de methode attendue'); Exit; End;
  invSpec := CurStr;
  Consume;
  If Not ParseMethodSpec(invSpec, invCls, invName, invDesc) Then Exit;
  invIdx := CPAddMethodRef(invCls, invName, invDesc);
  EmitByte($B6); { invokevirtual }
  EmitByte(Byte((invIdx shr 8) and $FF));
  EmitByte(Byte(invIdx and $FF));
  ParseInstruction := True; Exit;
 End;
 { invokespecial <method_spec> : appel constructeur/methode privee/super ($B7) }
 If mnem = 'invokespecial' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('invokespecial : specification de methode attendue'); Exit; End;
  invSpec := CurStr;
  Consume;
  If Not ParseMethodSpec(invSpec, invCls, invName, invDesc) Then Exit;
  invIdx := CPAddMethodRef(invCls, invName, invDesc);
  EmitByte($B7); { invokespecial }
  EmitByte(Byte((invIdx shr 8) and $FF));
  EmitByte(Byte(invIdx and $FF));
  ParseInstruction := True; Exit;
 End;
 { invokestatic <method_spec> : appel methode statique ($B8) }
 If mnem = 'invokestatic' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('invokestatic : specification de methode attendue'); Exit; End;
  invSpec := CurStr;
  Consume;
  If Not ParseMethodSpec(invSpec, invCls, invName, invDesc) Then Exit;
  invIdx := CPAddMethodRef(invCls, invName, invDesc);
  EmitByte($B8); { invokestatic }
  EmitByte(Byte((invIdx shr 8) and $FF));
  EmitByte(Byte(invIdx and $FF));
  ParseInstruction := True; Exit;
 End;
 { invokeinterface <method_spec> <count> : appel methode d'interface ($B9) }
 If mnem = 'invokeinterface' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('invokeinterface : specification de methode attendue'); Exit; End;
  invSpec := CurStr;
  Consume;
  If Not ParseMethodSpec(invSpec, invCls, invName, invDesc) Then Exit;
  invIdx := CPAddInterfaceMethodRef(invCls, invName, invDesc);
  { Lire le count (nargs + 1) }
  If CurTok = TK_INTEGER Then
  Begin
   invCount := Integer(CurInt);
   Consume;
  End
  Else
  Begin
   { Calculer automatiquement le count a partir du descripteur }
   invCount := DescriptorParamSlots(invDesc, False);
  End;
  EmitByte($B9); { invokeinterface }
  EmitByte(Byte((invIdx shr 8) and $FF));
  EmitByte(Byte(invIdx and $FF));
  EmitByte(Byte(invCount));
  EmitByte(0); { octet de padding }
  ParseInstruction := True; Exit;
 End;
 { invokedynamic <callsite_spec> : appel dynamique ($BA) }
 If mnem = 'invokedynamic' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('invokedynamic : specification attendue'); Exit; End;
  invSpec := CurStr;
  Consume;
  If Not ParseMethodSpec(invSpec, invCls, invName, invDesc) Then Exit;
  { Creer une entree InvokeDynamic (bootstrap=0, NameAndType) }
  { Note: les bootstrap methods necessitent l'attribut BootstrapMethods }
  { qui n'est pas encore implemente. On emet le bytecode avec bootstrap=0. }
  Warning('invokedynamic : bootstrap methods non encore supportes');
  invIdx := CPAddInvokeDynamic(0, CPEnsureNameAndType(invName, invDesc));
  EmitByte($BA); { invokedynamic }
  EmitByte(Byte((invIdx shr 8) and $FF));
  EmitByte(Byte(invIdx and $FF));
  EmitByte(0); { padding }
  EmitByte(0); { padding }
  ParseInstruction := True; Exit;
 End;
 { ---------------------------------------------------------------- }
 { Opcodes de manipulation de la pile et constantes - TODO 15       }
 { ---------------------------------------------------------------- }
 { nop ($00) : aucune operation }
 If mnem = 'nop' Then
 Begin Consume; EmitByte($00); ParseInstruction := True; Exit; End;
 { pop ($57) : depiler 1 mot }
 If mnem = 'pop' Then
 Begin Consume; EmitByte($57); ParseInstruction := True; Exit; End;
 { pop2 ($58) : depiler 2 mots }
 If mnem = 'pop2' Then
 Begin Consume; EmitByte($58); ParseInstruction := True; Exit; End;
 { dup ($59) : dupliquer le sommet }
 If mnem = 'dup' Then
 Begin Consume; EmitByte($59); ParseInstruction := True; Exit; End;
 { dup_x1 ($5A) : dupliquer le sommet sous le 2e mot }
 If mnem = 'dup_x1' Then
 Begin Consume; EmitByte($5A); ParseInstruction := True; Exit; End;
 { dup_x2 ($5B) : dupliquer le sommet sous le 3e mot }
 If mnem = 'dup_x2' Then
 Begin Consume; EmitByte($5B); ParseInstruction := True; Exit; End;
 { dup2 ($5C) : dupliquer les 2 mots du sommet }
 If mnem = 'dup2' Then
 Begin Consume; EmitByte($5C); ParseInstruction := True; Exit; End;
 { dup2_x1 ($5D) : dupliquer 2 mots sous le 3e }
 If mnem = 'dup2_x1' Then
 Begin Consume; EmitByte($5D); ParseInstruction := True; Exit; End;
 { dup2_x2 ($5E) : dupliquer 2 mots sous le 4e }
 If mnem = 'dup2_x2' Then
 Begin Consume; EmitByte($5E); ParseInstruction := True; Exit; End;
 { swap ($5F) : echanger les 2 mots du sommet }
 If mnem = 'swap' Then
 Begin Consume; EmitByte($5F); ParseInstruction := True; Exit; End;
 { aconst_null ($01) : pousser null }
 If mnem = 'aconst_null' Then
 Begin Consume; EmitByte($01); ParseInstruction := True; Exit; End;
 { iconst_m1 ($02) : pousser -1 }
 If mnem = 'iconst_m1' Then
 Begin Consume; EmitByte($02); ParseInstruction := True; Exit; End;
 { iconst_0 ($03) : pousser 0 }
 If mnem = 'iconst_0' Then
 Begin Consume; EmitByte($03); ParseInstruction := True; Exit; End;
 { iconst_1 ($04) : pousser 1 }
 If mnem = 'iconst_1' Then
 Begin Consume; EmitByte($04); ParseInstruction := True; Exit; End;
 { iconst_2 ($05) : pousser 2 }
 If mnem = 'iconst_2' Then
 Begin Consume; EmitByte($05); ParseInstruction := True; Exit; End;
 { iconst_3 ($06) : pousser 3 }
 If mnem = 'iconst_3' Then
 Begin Consume; EmitByte($06); ParseInstruction := True; Exit; End;
 { iconst_4 ($07) : pousser 4 }
 If mnem = 'iconst_4' Then
 Begin Consume; EmitByte($07); ParseInstruction := True; Exit; End;
 { iconst_5 ($08) : pousser 5 }
 If mnem = 'iconst_5' Then
 Begin Consume; EmitByte($08); ParseInstruction := True; Exit; End;
 { lconst_0 ($09) : pousser long 0 }
 If mnem = 'lconst_0' Then
 Begin Consume; EmitByte($09); ParseInstruction := True; Exit; End;
 { lconst_1 ($0A) : pousser long 1 }
 If mnem = 'lconst_1' Then
 Begin Consume; EmitByte($0A); ParseInstruction := True; Exit; End;
 { fconst_0 ($0B) : pousser float 0.0 }
 If mnem = 'fconst_0' Then
 Begin Consume; EmitByte($0B); ParseInstruction := True; Exit; End;
 { fconst_1 ($0C) : pousser float 1.0 }
 If mnem = 'fconst_1' Then
 Begin Consume; EmitByte($0C); ParseInstruction := True; Exit; End;
 { fconst_2 ($0D) : pousser float 2.0 }
 If mnem = 'fconst_2' Then
 Begin Consume; EmitByte($0D); ParseInstruction := True; Exit; End;
 { dconst_0 ($0E) : pousser double 0.0 }
 If mnem = 'dconst_0' Then
 Begin Consume; EmitByte($0E); ParseInstruction := True; Exit; End;
 { dconst_1 ($0F) : pousser double 1.0 }
 If mnem = 'dconst_1' Then
 Begin Consume; EmitByte($0F); ParseInstruction := True; Exit; End;
 { bipush <byte> ($10) : pousser byte signe -128..127 }
 If mnem = 'bipush' Then
 Begin
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('bipush : operande entiere attendue'); Exit; End;
  opvar := Integer(CurInt);
  Consume;
  If (opvar < -128) or (opvar > 127) Then
  Begin Error('bipush : valeur hors limites -128..127'); Exit; End;
  EmitByte($10); { bipush }
  EmitByte(Byte(opvar and $FF));
  ParseInstruction := True; Exit;
 End;
 { sipush <short> ($11) : pousser short signe -32768..32767 }
 If mnem = 'sipush' Then
 Begin
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('sipush : operande entiere attendue'); Exit; End;
  If (CurInt < -32768) or (CurInt > 32767) Then
  Begin Error('sipush : valeur hors limites -32768..32767'); Consume; Exit; End;
  opvar := Integer(CurInt);
  Consume;
  EmitByte($11); { sipush }
  EmitByte(Byte((opvar shr 8) and $FF));
  EmitByte(Byte(opvar and $FF));
  ParseInstruction := True; Exit;
 End;
 { ldc <constant> ($12) : pousser int/float/string depuis Constant Pool }
 If mnem = 'ldc' Then
 Begin
  Consume;
  If CurTok = TK_INTEGER Then
  Begin
   ldcIdx := CPAddInteger(CurInt);
   Consume;
  End
  Else If CurTok = TK_FLOAT Then
  Begin
   ldcIdx := CPAddFloat(CurFloat);
   Consume;
  End
  Else If CurTok = TK_STRING Then
  Begin
   ldcIdx := CPAddString(CurStr);
   Consume;
  End
  Else If CurTok = TK_IDENT Then
  Begin
   { Reference de classe }
   ldcIdx := CPEnsureClass(CurStr);
   Consume;
  End
  Else
  Begin Error('ldc : constante attendue (entier, flottant, chaine ou classe)'); Exit; End;
  If (ldcIdx < 1) or (ldcIdx > 255) Then
  Begin
   Warning('ldc : index CP > 255, utiliser ldc_w a la place');
   { Emettre quand meme avec ldc_w }
   EmitByte($13); { ldc_w }
   EmitByte(Byte((ldcIdx shr 8) and $FF));
   EmitByte(Byte(ldcIdx and $FF));
  End
  Else
  Begin
   EmitByte($12); { ldc }
   EmitByte(Byte(ldcIdx));
  End;
  ParseInstruction := True; Exit;
 End;
 { ldc_w <constant> ($13) : pousser int/float/string, index large 16 bits }
 If mnem = 'ldc_w' Then
 Begin
  Consume;
  If CurTok = TK_INTEGER Then
  Begin
   ldcIdx := CPAddInteger(CurInt);
   Consume;
  End
  Else If CurTok = TK_FLOAT Then
  Begin
   ldcIdx := CPAddFloat(CurFloat);
   Consume;
  End
  Else If CurTok = TK_STRING Then
  Begin
   ldcIdx := CPAddString(CurStr);
   Consume;
  End
  Else If CurTok = TK_IDENT Then
  Begin
   ldcIdx := CPEnsureClass(CurStr);
   Consume;
  End
  Else
  Begin Error('ldc_w : constante attendue'); Exit; End;
  EmitByte($13); { ldc_w }
  EmitByte(Byte((ldcIdx shr 8) and $FF));
  EmitByte(Byte(ldcIdx and $FF));
  ParseInstruction := True; Exit;
 End;
 { ldc2_w <constant> ($14) : pousser long/double depuis Constant Pool }
 If mnem = 'ldc2_w' Then
 Begin
  Consume;
  If CurTok = TK_INTEGER Then
  Begin
   { Long : on utilise CPAddLong avec hi=0 pour valeurs 32 bits }
   ldcIdx := CPAddLong(0, CurInt);
   Consume;
  End
  Else If CurTok = TK_FLOAT Then
  Begin
   { Double : convertir en IEEE 754 via RealToHiLo }
   RealToHiLo(CurFloat, dhi, dlo);
   ldcIdx := CPAddDouble(dhi, dlo);
   Consume;
  End
  Else
  Begin Error('ldc2_w : constante long ou double attendue'); Exit; End;
  EmitByte($14); { ldc2_w }
  EmitByte(Byte((ldcIdx shr 8) and $FF));
  EmitByte(Byte(ldcIdx and $FF));
  ParseInstruction := True; Exit;
 End;
 { ---------------------------------------------------------------- }
 { Opcodes de creation d'objets et tableaux - TODO 16               }
 { ---------------------------------------------------------------- }
 { new <classname> ($BB) : creer nouvel objet }
 If mnem = 'new' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('new : nom de classe attendu'); Exit; End;
  objIdx := CPEnsureClass(CurStr);
  Consume;
  EmitByte($BB); { new }
  EmitByte(Byte((objIdx shr 8) and $FF));
  EmitByte(Byte(objIdx and $FF));
  ParseInstruction := True; Exit;
 End;
 { newarray <type> ($BC) : creer tableau de type primitif }
 If mnem = 'newarray' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('newarray : type primitif attendu'); Exit; End;
  arrType := 0;
  If CurStr = 'boolean' Then arrType := 4
  Else If CurStr = 'char' Then arrType := 5
  Else If CurStr = 'float' Then arrType := 6
  Else If CurStr = 'double' Then arrType := 7
  Else If CurStr = 'byte' Then arrType := 8
  Else If CurStr = 'short' Then arrType := 9
  Else If CurStr = 'int' Then arrType := 10
  Else If CurStr = 'long' Then arrType := 11;
  If arrType = 0 Then
  Begin Error('newarray : type inconnu "' + CurStr + '"'); Consume; Exit; End;
  Consume;
  EmitByte($BC); { newarray }
  EmitByte(Byte(arrType));
  ParseInstruction := True; Exit;
 End;
 { anewarray <classname> ($BD) : creer tableau de references }
 If mnem = 'anewarray' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('anewarray : nom de classe attendu'); Exit; End;
  objIdx := CPEnsureClass(CurStr);
  Consume;
  EmitByte($BD); { anewarray }
  EmitByte(Byte((objIdx shr 8) and $FF));
  EmitByte(Byte(objIdx and $FF));
  ParseInstruction := True; Exit;
 End;
 { multianewarray <classname> <dimensions> ($C5) : creer tableau multi-dimensionnel }
 If mnem = 'multianewarray' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('multianewarray : nom de classe attendu'); Exit; End;
  objIdx := CPEnsureClass(CurStr);
  Consume;
  If CurTok <> TK_INTEGER Then
  Begin Error('multianewarray : nombre de dimensions attendu'); Exit; End;
  arrType := CurInt;
  Consume;
  If (arrType < 1) or (arrType > 255) Then
  Begin Error('multianewarray : dimensions hors limites 1..255'); Exit; End;
  EmitByte($C5); { multianewarray }
  EmitByte(Byte((objIdx shr 8) and $FF));
  EmitByte(Byte(objIdx and $FF));
  EmitByte(Byte(arrType));
  ParseInstruction := True; Exit;
 End;
 { arraylength ($BE) : obtenir la longueur d'un tableau }
 If mnem = 'arraylength' Then
 Begin Consume; EmitByte($BE); ParseInstruction := True; Exit; End;
 { checkcast <classname> ($C0) : verifier le transtypage }
 If mnem = 'checkcast' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('checkcast : nom de classe attendu'); Exit; End;
  objIdx := CPEnsureClass(CurStr);
  Consume;
  EmitByte($C0); { checkcast }
  EmitByte(Byte((objIdx shr 8) and $FF));
  EmitByte(Byte(objIdx and $FF));
  ParseInstruction := True; Exit;
 End;
 { instanceof <classname> ($C1) : tester le type d'un objet }
 If mnem = 'instanceof' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('instanceof : nom de classe attendu'); Exit; End;
  objIdx := CPEnsureClass(CurStr);
  Consume;
  EmitByte($C1); { instanceof }
  EmitByte(Byte((objIdx shr 8) and $FF));
  EmitByte(Byte(objIdx and $FF));
  ParseInstruction := True; Exit;
 End;
 { ---------------------------------------------------------------- }
 { Opcodes d'acces aux champs - TODO 17                              }
 { ---------------------------------------------------------------- }
 { getstatic <field_spec> <descriptor> ($B2) : charger champ statique }
 If mnem = 'getstatic' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('getstatic : specification de champ attendue'); Exit; End;
  fldSpec := CurStr;
  Consume;
  If Not ParseFieldSpec(fldSpec, fldCls, fldName) Then Exit;
  If CurTok <> TK_IDENT Then
  Begin Error('getstatic : descripteur de champ attendu'); Exit; End;
  fldDesc := CurStr;
  Consume;
  fldIdx := CPAddFieldRef(fldCls, fldName, fldDesc);
  EmitByte($B2); { getstatic }
  EmitByte(Byte((fldIdx shr 8) and $FF));
  EmitByte(Byte(fldIdx and $FF));
  ParseInstruction := True; Exit;
 End;
 { putstatic <field_spec> <descriptor> ($B3) : stocker valeur dans champ statique }
 If mnem = 'putstatic' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('putstatic : specification de champ attendue'); Exit; End;
  fldSpec := CurStr;
  Consume;
  If Not ParseFieldSpec(fldSpec, fldCls, fldName) Then Exit;
  If CurTok <> TK_IDENT Then
  Begin Error('putstatic : descripteur de champ attendu'); Exit; End;
  fldDesc := CurStr;
  Consume;
  fldIdx := CPAddFieldRef(fldCls, fldName, fldDesc);
  EmitByte($B3); { putstatic }
  EmitByte(Byte((fldIdx shr 8) and $FF));
  EmitByte(Byte(fldIdx and $FF));
  ParseInstruction := True; Exit;
 End;
 { getfield <field_spec> <descriptor> ($B4) : charger champ d'instance }
 If mnem = 'getfield' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('getfield : specification de champ attendue'); Exit; End;
  fldSpec := CurStr;
  Consume;
  If Not ParseFieldSpec(fldSpec, fldCls, fldName) Then Exit;
  If CurTok <> TK_IDENT Then
  Begin Error('getfield : descripteur de champ attendu'); Exit; End;
  fldDesc := CurStr;
  Consume;
  fldIdx := CPAddFieldRef(fldCls, fldName, fldDesc);
  EmitByte($B4); { getfield }
  EmitByte(Byte((fldIdx shr 8) and $FF));
  EmitByte(Byte(fldIdx and $FF));
  ParseInstruction := True; Exit;
 End;
 { putfield <field_spec> <descriptor> ($B5) : stocker valeur dans champ d'instance }
 If mnem = 'putfield' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('putfield : specification de champ attendue'); Exit; End;
  fldSpec := CurStr;
  Consume;
  If Not ParseFieldSpec(fldSpec, fldCls, fldName) Then Exit;
  If CurTok <> TK_IDENT Then
  Begin Error('putfield : descripteur de champ attendu'); Exit; End;
  fldDesc := CurStr;
  Consume;
  fldIdx := CPAddFieldRef(fldCls, fldName, fldDesc);
  EmitByte($B5); { putfield }
  EmitByte(Byte((fldIdx shr 8) and $FF));
  EmitByte(Byte(fldIdx and $FF));
  ParseInstruction := True; Exit;
 End;
 { ---------------------------------------------------------------- }
 { Opcodes de retour, exceptions, moniteur et wide - TODO 18        }
 { ---------------------------------------------------------------- }
 { ireturn ($AC) : retourner int }
 If mnem = 'ireturn' Then Begin Consume; EmitByte($AC); ParseInstruction := True; Exit; End;
 { lreturn ($AD) : retourner long }
 If mnem = 'lreturn' Then Begin Consume; EmitByte($AD); ParseInstruction := True; Exit; End;
 { freturn ($AE) : retourner float }
 If mnem = 'freturn' Then Begin Consume; EmitByte($AE); ParseInstruction := True; Exit; End;
 { dreturn ($AF) : retourner double }
 If mnem = 'dreturn' Then Begin Consume; EmitByte($AF); ParseInstruction := True; Exit; End;
 { areturn ($B0) : retourner reference }
 If mnem = 'areturn' Then Begin Consume; EmitByte($B0); ParseInstruction := True; Exit; End;
 { return ($B1) : retourner void }
 If mnem = 'return' Then Begin Consume; EmitByte($B1); ParseInstruction := True; Exit; End;
 { athrow ($BF) : lancer une exception }
 If mnem = 'athrow' Then Begin Consume; EmitByte($BF); ParseInstruction := True; Exit; End;
 { monitorenter ($C2) : acquerir le moniteur d'un objet }
 If mnem = 'monitorenter' Then Begin Consume; EmitByte($C2); ParseInstruction := True; Exit; End;
 { monitorexit ($C3) : relacher le moniteur d'un objet }
 If mnem = 'monitorexit' Then Begin Consume; EmitByte($C3); ParseInstruction := True; Exit; End;
 { wide ($C4) : etendre l'index de variable locale a 16 bits }
 If mnem = 'wide' Then
 Begin
  Consume;
  If CurTok <> TK_IDENT Then
  Begin Error('wide : opcode attendu apres wide'); Exit; End;
  wideOpc := CurStr;
  Consume;
  { wide iinc <index_u2> <const_s2> }
  If wideOpc = 'iinc' Then
  Begin
   If CurTok <> TK_INTEGER Then
   Begin Error('wide iinc : index entier attendu'); Exit; End;
   wideIdx := CurInt;
   Consume;
   If CurTok <> TK_INTEGER Then
   Begin Error('wide iinc : constante entiere attendue'); Exit; End;
   wideConst := CurInt;
   Consume;
   EmitByte($C4); { wide }
   EmitByte($84); { iinc }
   EmitByte(Byte((wideIdx shr 8) and $FF));
   EmitByte(Byte(wideIdx and $FF));
   EmitByte(Byte((wideConst shr 8) and $FF));
   EmitByte(Byte(wideConst and $FF));
   ParseInstruction := True; Exit;
  End;
  { wide <load/store/ret> <index_u2> }
  If CurTok <> TK_INTEGER Then
  Begin Error('wide ' + wideOpc + ' : index entier attendu'); Exit; End;
  wideIdx := CurInt;
  Consume;
  EmitByte($C4); { wide }
  If wideOpc = 'iload' Then EmitByte($15)
  Else If wideOpc = 'lload' Then EmitByte($16)
  Else If wideOpc = 'fload' Then EmitByte($17)
  Else If wideOpc = 'dload' Then EmitByte($18)
  Else If wideOpc = 'aload' Then EmitByte($19)
  Else If wideOpc = 'istore' Then EmitByte($36)
  Else If wideOpc = 'lstore' Then EmitByte($37)
  Else If wideOpc = 'fstore' Then EmitByte($38)
  Else If wideOpc = 'dstore' Then EmitByte($39)
  Else If wideOpc = 'astore' Then EmitByte($3A)
  Else If wideOpc = 'ret' Then EmitByte($A9)
  Else
  Begin Error('wide : opcode non supportable : ' + wideOpc); Exit; End;
  EmitByte(Byte((wideIdx shr 8) and $FF));
  EmitByte(Byte(wideIdx and $FF));
  ParseInstruction := True; Exit;
 End;
End;

{ --- ParseDirectives : dispatcher principal des directives de classe --- }
{ Parcourt les tokens et dispatche les directives connues.                }
{ Les directives non encore implementees sont signalees et sautees.       }
Procedure ParseDirectives;
Begin
 While CurTok <> TK_EOF do
 Begin
  { Sauter les lignes vides }
  If CurTok = TK_NEWLINE Then
  Begin
   Consume;
   Continue;
  End;

  { Dispatcher les directives }
  If CurTok = TK_DIRECTIVE Then
  Begin
   Case CurDir of
    DIR_CLASS:
    Begin
     Consume;
     ParseClassDirective;
     SkipToEOL;
    End;
    DIR_SUPER:
    Begin
     Consume;
     ParseSuperDirective;
     SkipToEOL;
    End;
    DIR_IMPLEMENTS:
    Begin
     Consume;
     ParseImplementsDirective;
     SkipToEOL;
    End;
    DIR_SOURCE:
    Begin
     Consume;
     ParseSourceDirective;
     SkipToEOL;
    End;
    DIR_INTERFACE:
    Begin
     Consume;
     ParseInterfaceDirective;
     SkipToEOL;
    End;
    DIR_BYTECODE:
    Begin
     Consume;
     ParseBytecodeDirective;
     SkipToEOL;
    End;
    DIR_FIELD:
    Begin
     Consume;
     ParseFieldDirective;
     SkipToEOL;
    End;
    DIR_METHOD:
    Begin
     Consume;
     ParseMethodDirective;
     SkipToEOL;
    End;
    DIR_END:
    Begin
     Consume;
     ParseEndMethod;
     SkipToEOL;
    End;
    DIR_LIMIT:
    Begin
     Consume;
     ParseLimitDirective;
     SkipToEOL;
    End;
    DIR_LINE:
    Begin
     Consume;
     ParseLineDirective;
     SkipToEOL;
    End;
    DIR_THROWS:
    Begin
     Consume;
     ParseThrowsDirective;
     SkipToEOL;
    End;
    DIR_CATCH:
    Begin
     Consume;
     ParseCatchDirective;
     SkipToEOL;
    End;
    DIR_DEPRECATED:
    Begin
     Consume;
     ParseDeprecatedDirective;
     SkipToEOL;
    End;
    DIR_SIGNATURE:
    Begin
     Consume;
     ParseSignatureDirective;
     SkipToEOL;
    End;
    DIR_INNER:
    Begin
     Consume;
     ParseInnerClassDirective;
     SkipToEOL;
    End;
    DIR_ENCLOSING:
    Begin
     Consume;
     ParseEnclosingMethodDirective;
     SkipToEOL;
    End;
   Else
    { Directives non encore implementees (TODO 24+) : sauter la ligne }
    If OptVerbose Then
     WriteLn('  [skip] directive ', CurStr, ' (TODO 24+)');
    SkipToEOL;
   End;  { Case }
  End
  Else If InMethod And (CurTok = TK_IDENT) Then
  Begin
   { Essayer de parser une instruction JVM (TODO 10+) }
   If Not ParseInstruction Then
   Begin
    { Mnemonique non reconnu : sauter la ligne }
    If OptVerbose Then
     WriteLn('  [skip] instruction ', CurStr, ' (TODO 24+)');
    SkipToEOL;
   End
   Else
    SkipToEOL;  { consommer le reste de la ligne apres l'instruction }
  End
  Else If InMethod And (CurTok = TK_LABEL) Then
  Begin
   { Label dans une methode : enregistrer a la position PC courante (TODO 19) }
   LabelAdd(CurStr);
   Consume;
   SkipToEOL;
  End
  Else
  Begin
   { Token non-directive hors methode : sauter la ligne }
   SkipToEOL;
  End;
 End;
 { Si on quitte la boucle avec une methode encore ouverte }
 If InMethod Then
 Begin
  Error('fin de fichier dans une methode (manque .end method)');
  LeaveMethod;
 End;
End;

{ ============================================================================ }
{ TODO 23 : Programme principal : ligne de commande et generation .class      }
{ ============================================================================ }

{ --- ParseCommandLine : analyser les options de la ligne de commande --- }
{ Reconnait : fichier.j (obligatoire, premier argument),                      }
{   -o <fichier.class>, -d <repertoire>, -g, -v, -version, -help             }
Procedure ParseCommandLine;
Var i: Integer; arg: String;
Begin
 SrcFileName := '';
 OutFileName := '';
 OutDir      := '';
 OptDebug    := False;
 OptVerbose  := False;
 i := 1;
 While i <= ParamCount do
 Begin
  arg := ParamStr(i);
  If (arg = '-o') And (i < ParamCount) Then
  Begin
   Inc(i);
   OutFileName := ParamStr(i);
  End
  Else If (arg = '-d') And (i < ParamCount) Then
  Begin
   Inc(i);
   OutDir := ParamStr(i);
  End
  Else If arg = '-g' Then
   OptDebug := True
  Else If arg = '-v' Then
   OptVerbose := True
  Else If (arg = '-version') Or (arg = '--version') Then
  Begin
   WriteLn(VERSION);
   Halt;
  End
  Else If (arg = '-help') Or (arg = '--help') Or (arg = '-h') Or
          (arg = '/?') Or (arg = '/h') Or (arg = '/H') Then
  Begin
   WriteLn('JASMIN - ', VERSION);
   WriteLn;
   WriteLn('Syntaxe : JASMIN fichier.j [options]');
   WriteLn;
   WriteLn('  Assemble un fichier source Jasmin (.j) en fichier .class');
   WriteLn('  (bytecode Java) compatible avec la JVM.');
   WriteLn;
   WriteLn('Options :');
   WriteLn('  -o <fichier.class>  Specifier le nom du fichier de sortie');
   WriteLn('  -d <repertoire>     Specifier le repertoire de sortie');
   WriteLn('  -g                  Inclure les informations de debogage');
   WriteLn('  -v                  Mode verbeux');
   WriteLn('  -version            Afficher la version et quitter');
   WriteLn('  -help               Afficher cette aide');
   Halt;
  End
  Else If (arg[1] = '-') Then
   WriteLn('Attention : option inconnue "', arg, '"')
  Else If SrcFileName = '' Then
   SrcFileName := arg;
  Inc(i);
 End;
 If SrcFileName = '' Then
 Begin
  WriteLn('Erreur : aucun fichier source specifie.');
  WriteLn('Tapez JASMIN -help pour l''aide.');
  Halt(1);
 End;
End;

{ --- CPEmitAll : ecrire le Constant Pool en binaire --- }
{ Ecrit constant_pool_count (U2) puis chaque entree du CP.                    }
{ Les entrees CP_LONG et CP_DOUBLE occupent 2 emplacements ; l'entree         }
{ suivante (index+1) est inutilisee (tag=CP_NONE) par convention JVM.         }
Procedure CPEmitAll;
Var i: Integer; len: Integer; j: Integer; b: Byte;
Begin
 { constant_pool_count = CPCount (nombre d'entrees, 1-base, 0 inutilisee) }
 BinWriteU2(CPCount);

 For i := 1 to CPCount - 1 do
 Begin
  Case CPTab^[i].Tag of
   CP_UTF8:
   Begin
    BinWriteU1(1);            { tag = CONSTANT_Utf8 }
    len := Length(CPTab^[i].StrVal);
    BinWriteU2(len);          { length }
    For j := 1 to len do
    Begin
     b := Byte(Ord(CPTab^[i].StrVal[j]));
     BinWriteU1(b);
    End;
   End;
   CP_INTEGER:
   Begin
    BinWriteU1(3);            { tag = CONSTANT_Integer }
    BinWriteU4(CPTab^[i].IntVal);
   End;
   CP_FLOAT:
   Begin
    BinWriteU1(4);            { tag = CONSTANT_Float }
    BinWriteFloat(CPTab^[i].FloatVal);
   End;
   CP_LONG:
   Begin
    BinWriteU1(5);            { tag = CONSTANT_Long }
    BinWriteU4(CPTab^[i].HiBytes);
    BinWriteU4(CPTab^[i].LoBytes);
   End;
   CP_DOUBLE:
   Begin
    BinWriteU1(6);            { tag = CONSTANT_Double }
    BinWriteU4(CPTab^[i].HiBytes);
    BinWriteU4(CPTab^[i].LoBytes);
   End;
   CP_CLASS:
   Begin
    BinWriteU1(7);            { tag = CONSTANT_Class }
    BinWriteU2(CPTab^[i].Ref1);  { name_index }
   End;
   CP_STRING:
   Begin
    BinWriteU1(8);            { tag = CONSTANT_String }
    BinWriteU2(CPTab^[i].Ref1);  { string_index }
   End;
   CP_FIELDREF:
   Begin
    BinWriteU1(9);            { tag = CONSTANT_Fieldref }
    BinWriteU2(CPTab^[i].Ref1);  { class_index }
    BinWriteU2(CPTab^[i].Ref2);  { name_and_type_index }
   End;
   CP_METHODREF:
   Begin
    BinWriteU1(10);           { tag = CONSTANT_Methodref }
    BinWriteU2(CPTab^[i].Ref1);  { class_index }
    BinWriteU2(CPTab^[i].Ref2);  { name_and_type_index }
   End;
   CP_INTERFACEMETHODREF:
   Begin
    BinWriteU1(11);           { tag = CONSTANT_InterfaceMethodref }
    BinWriteU2(CPTab^[i].Ref1);  { class_index }
    BinWriteU2(CPTab^[i].Ref2);  { name_and_type_index }
   End;
   CP_NAMEANDTYPE:
   Begin
    BinWriteU1(12);           { tag = CONSTANT_NameAndType }
    BinWriteU2(CPTab^[i].Ref1);  { name_index }
    BinWriteU2(CPTab^[i].Ref2);  { descriptor_index }
   End;
   CP_METHODHANDLE:
   Begin
    BinWriteU1(15);           { tag = CONSTANT_MethodHandle }
    BinWriteU1(Byte(CPTab^[i].Ref1)); { reference_kind }
    BinWriteU2(CPTab^[i].Ref2);       { reference_index }
   End;
   CP_METHODTYPE:
   Begin
    BinWriteU1(16);           { tag = CONSTANT_MethodType }
    BinWriteU2(CPTab^[i].Ref1);  { descriptor_index }
   End;
   CP_INVOKEDYNAMIC:
   Begin
    BinWriteU1(18);           { tag = CONSTANT_InvokeDynamic }
    BinWriteU2(CPTab^[i].Ref1);  { bootstrap_method_attr_index }
    BinWriteU2(CPTab^[i].Ref2);  { name_and_type_index }
   End;
   CP_NONE:
   Begin
    { Slot vide (seconde moitie d'un LONG ou DOUBLE) - rien a ecrire }
   End;
  Else
   { Tag inconnu, ecrire UTF8 vide par securite }
   BinWriteU1(1);
   BinWriteU2(0);
  End;
 End;
 If OptVerbose Then
  WriteLn('  [bin] Constant Pool : ', CPCount - 1, ' entree(s) ecrite(s)');
End;

{ --- EmitFieldInfo : ecrire une entree field_info --- }
{ Structure JVM :                                                              }
{   access_flags (U2), name_index (U2), descriptor_index (U2),                }
{   attributes_count (U2), attributes[]                                       }
{ Attributs possibles : ConstantValue, Deprecated, Signature                  }
Procedure EmitFieldInfo(fIdx: Integer);
Var attrCnt: Integer;
    cvIdx: Integer;
Begin
 With FieldTab^[fIdx] do
 Begin
  { Compter les attributs }
  attrCnt := 0;
  If HasInit Then Inc(attrCnt);       { ConstantValue }
  If IsDeprecated Then Inc(attrCnt);  { Deprecated }
  If Signature <> '' Then Inc(attrCnt); { Signature }

  { Ecrire field_info }
  BinWriteU2(AccFlags);     { access_flags }
  BinWriteU2(NameIdx);      { name_index }
  BinWriteU2(DescIdx);      { descriptor_index }
  BinWriteU2(attrCnt);      { attributes_count }

  { Attribut ConstantValue }
  If HasInit Then
  Begin
   cvIdx := CPEnsureUtf8('ConstantValue');
   BinWriteU2(cvIdx);       { attribute_name_index }
   BinWriteU4(2);           { attribute_length = 2 }
   BinWriteU2(InitCPIdx);   { constantvalue_index }
  End;

  { Attribut Deprecated }
  If IsDeprecated Then
   EmitDeprecatedAttr;

  { Attribut Signature }
  If Signature <> '' Then
   EmitSignatureAttr(Signature);

  If OptVerbose Then
   WriteLn('  [bin] champ ', Name, ' ', Desc, ' (', attrCnt, ' attr)');
 End;
End;

{ --- EmitMethodInfo : ecrire une entree method_info --- }
{ Structure JVM :                                                              }
{   access_flags (U2), name_index (U2), descriptor_index (U2),                }
{   attributes_count (U2), attributes[]                                       }
{ Attributs possibles : Code, Exceptions, Deprecated, Signature               }
Procedure EmitMethodInfo(mIdx: Integer);
Var attrCnt: Integer;
Begin
 With MethodTab^[mIdx] do
 Begin
  { Compter les attributs }
  attrCnt := 0;
  If HasCode Then Inc(attrCnt);         { Code }
  If ThrowCount > 0 Then Inc(attrCnt);  { Exceptions }
  If IsDeprecated Then Inc(attrCnt);    { Deprecated }
  If Signature <> '' Then Inc(attrCnt); { Signature }

  { Ecrire method_info }
  BinWriteU2(AccFlags);     { access_flags }
  BinWriteU2(NameIdx);      { name_index }
  BinWriteU2(DescIdx);      { descriptor_index }
  BinWriteU2(attrCnt);      { attributes_count }

  { Attribut Code }
  If HasCode Then
   EmitCodeAttribute(mIdx);

  { Attribut Exceptions }
  If ThrowCount > 0 Then
   EmitExceptionsAttribute(mIdx);

  { Attribut Deprecated }
  If IsDeprecated Then
   EmitDeprecatedAttr;

  { Attribut Signature }
  If Signature <> '' Then
   EmitSignatureAttr(Signature);

  If OptVerbose Then
   WriteLn('  [bin] methode ', Name, Desc, ' (', attrCnt, ' attr)');
 End;
End;

{ ============================================================================ }
{ Initialisation globale                                                       }
{ ============================================================================ }

Procedure GlobalInit;
Begin
 OutFileName   := '';
 OutDir        := '';
 OptDebug      := False;
 OptVerbose    := False;
 BinPos        := 0;

 SrcLine       := '';
 SrcLineNum    := 0;
 SrcCol        := 1;
 SrcEof        := False;
 CurTok        := TK_EOF;
 CurStr        := '';
 CurInt        := 0;
 CurFloat      := 0.0;
 CurDir        := DIR_NONE;

 ClassName     := '';
 SuperName     := 'java/lang/Object';
 SourceName    := '';
 ClassAccFlags := ACC_SUPER;
 ClassNameIdx  := 0;
 SuperNameIdx  := 0;
 SourceIdx     := 0;

 { Attributs supplementaires (TODO 22) }
 ClassDeprecated := False;
 ClassSignature  := '';
 EnclosingClass  := '';
 EnclosingMethod := '';
 EnclosingDesc   := '';
 InnerCount      := 0;

 ClassMajor    := CLASS_MAJOR_DEFAULT;
 ClassMinor    := CLASS_MINOR_DEFAULT;

 { Allouer les tables sur le tas }
 New(CPTab);
 New(FieldTab);
 New(MethodTab);

 { Initialiser le Constant Pool via CPInit (TODO 04) }
 CPInit;

 FieldCount  := 0;
 MethodCount := 0;
 IfaceCount  := 0;
 InMethod    := False;
 CurMethod   := 0;
 ErrorCount  := 0;
 WarnCount   := 0;
End;

{ ============================================================================ }
{ Liberation memoire                                                           }
{ ============================================================================ }

Procedure GlobalCleanup;
Var i: Integer;
Begin
 { Liberer les buffers de code et tables des methodes }
 For i := 1 to MethodCount do
 Begin
  If MethodTab^[i].Code <> Nil Then Dispose(MethodTab^[i].Code);
  If MethodTab^[i].ExcTab <> Nil Then Dispose(MethodTab^[i].ExcTab);
  If MethodTab^[i].LineTab <> Nil Then Dispose(MethodTab^[i].LineTab);
  If MethodTab^[i].Labels <> Nil Then Dispose(MethodTab^[i].Labels);
  If MethodTab^[i].Fixups <> Nil Then Dispose(MethodTab^[i].Fixups);
 End;
 Dispose(MethodTab);
 Dispose(FieldTab);
 Dispose(CPTab);
End;

{ ============================================================================ }
{ Procedure Assemble                                                           }
{ ============================================================================ }

Procedure Assemble;
Var classOut     : String;     { nom du fichier .class de sortie            }
    i            : Integer;
    classAttrCnt : Integer;    { nombre d'attributs de classe               }
    slashPos     : Integer;    { position du dernier '/' pour chemin        }
    baseName     : String;     { nom de base (sans extension/chemin)        }
Begin
 GlobalInit;
 ParseCommandLine;
 WriteLn(VERSION);
 WriteLn('Fichier source : ', SrcFileName);

 { Ouvrir le fichier source }
 SrcOpen(SrcFileName);

 { Lire le premier token }
 NextToken;

 { Parser les directives de classe et le contenu }
 ParseDirectives;

 WriteLn;
 WriteLn('Lignes lues   : ', SrcLineNum);
 WriteLn('Erreurs       : ', ErrorCount);

 { Afficher les informations de classe parsees }
 If ClassName <> '' Then
 Begin
  WriteLn;
  WriteLn('Classe        : ', ClassName);
  WriteLn('Super-classe  : ', SuperName);
  If SourceName <> '' Then
   WriteLn('Source        : ', SourceName);
  If IfaceCount > 0 Then
   WriteLn('Interfaces    : ', IfaceCount);
  WriteLn('Version       : ', ClassMajor, '.', ClassMinor);
 End;

 { Bilan de l'assemblage (parsing) }
 BilanAssemblage;

 { Si des erreurs ont ete detectees, ne pas generer le .class }
 If ErrorCount > 0 Then
 Begin
  WriteLn;
  WriteLn('Assemblage abandonne a cause des erreurs.');
  SrcClose;
  GlobalCleanup;
  Exit;
 End;

 { Verifier que la classe est definie }
 If ClassName = '' Then
 Begin
  Error('aucune directive .class trouvee');
  SrcClose;
  GlobalCleanup;
  Exit;
 End;

 { Resoudre les indices CP de la classe et de la superclasse }
 ClassNameIdx := CPAddClass(ClassName);
 SuperNameIdx := CPAddClass(SuperName);

 { --- Determiner le nom du fichier de sortie .class --- }
 If OutFileName <> '' Then
  classOut := OutFileName
 Else
 Begin
  { Extraire le nom simple de la classe (apres le dernier /) }
  baseName := ClassName;
  slashPos := 0;
  For i := 1 to Length(baseName) do
   If baseName[i] = '/' Then slashPos := i;
  If slashPos > 0 Then
   baseName := Copy(baseName, slashPos + 1, Length(baseName) - slashPos);
  classOut := baseName + '.class';
 End;
 { Ajouter le repertoire de sortie si specifie }
 If OutDir <> '' Then
 Begin
  If (OutDir[Length(OutDir)] <> '/') And
     (OutDir[Length(OutDir)] <> '\') Then
   OutDir := OutDir + '/';
  classOut := OutDir + classOut;
 End;

 WriteLn;
 WriteLn('Generation de : ', classOut);

 { --- Pre-enregistrer les noms d'attributs dans le CP --- }
 { Ces chaines sont necessaires pour l'emission binaire des attributs.        }
 { Elles doivent etre dans le CP AVANT qu'il ne soit ecrit dans le fichier.  }
 For i := 1 to MethodCount do
 Begin
  If MethodTab^[i].HasCode Then
  Begin
   CPEnsureUtf8('Code');
   If MethodTab^[i].LineCount > 0 Then
    CPEnsureUtf8('LineNumberTable');
   { Pre-enregistrer les classes des exception handlers }
   For slashPos := 1 to MethodTab^[i].ExcCount do
   Begin
    If (MethodTab^[i].ExcTab^[slashPos].CatchType <> '') And
       (MethodTab^[i].ExcTab^[slashPos].CatchType <> 'all') Then
     CPEnsureClass(MethodTab^[i].ExcTab^[slashPos].CatchType);
   End;
  End;
  If MethodTab^[i].ThrowCount > 0 Then
   CPEnsureUtf8('Exceptions');
  If MethodTab^[i].IsDeprecated Then
   CPEnsureUtf8('Deprecated');
  If MethodTab^[i].Signature <> '' Then
  Begin
   CPEnsureUtf8('Signature');
   CPEnsureUtf8(MethodTab^[i].Signature);
  End;
 End;
 For i := 1 to FieldCount do
 Begin
  If FieldTab^[i].HasInit Then
   CPEnsureUtf8('ConstantValue');
  If FieldTab^[i].IsDeprecated Then
   CPEnsureUtf8('Deprecated');
  If FieldTab^[i].Signature <> '' Then
  Begin
   CPEnsureUtf8('Signature');
   CPEnsureUtf8(FieldTab^[i].Signature);
  End;
 End;
 If SourceName <> '' Then
 Begin
  CPEnsureUtf8('SourceFile');
  CPEnsureUtf8(SourceName);
 End;
 If ClassDeprecated Then
  CPEnsureUtf8('Deprecated');
 If ClassSignature <> '' Then
 Begin
  CPEnsureUtf8('Signature');
  CPEnsureUtf8(ClassSignature);
 End;
 If InnerCount > 0 Then
 Begin
  CPEnsureUtf8('InnerClasses');
  For i := 1 to InnerCount do
  Begin
   If InnerTab[i].InnerClass <> '' Then
    CPEnsureClass(InnerTab[i].InnerClass);
   If InnerTab[i].OuterClass <> '' Then
    CPEnsureClass(InnerTab[i].OuterClass);
   If InnerTab[i].InnerName <> '' Then
    CPEnsureUtf8(InnerTab[i].InnerName);
  End;
 End;
 If EnclosingClass <> '' Then
 Begin
  CPEnsureUtf8('EnclosingMethod');
  CPEnsureClass(EnclosingClass);
  If EnclosingMethod <> '' Then
   CPAddNameAndType(EnclosingMethod, EnclosingDesc);
 End;

 { --- Ouvrir le fichier binaire .class --- }
 BinOpen(classOut);

 { --- 1. Ecrire le magic number (0xCAFEBABE) --- }
 BinWriteU4(LongInt($CAFEBABE));

 { --- 2. Ecrire la version du fichier .class --- }
 BinWriteU2(ClassMinor);      { minor_version }
 BinWriteU2(ClassMajor);      { major_version }

 { --- 3. Ecrire le Constant Pool --- }
 CPEmitAll;

 { --- 4. Ecrire access_flags, this_class, super_class --- }
 BinWriteU2(ClassAccFlags);   { access_flags }
 BinWriteU2(ClassNameIdx);    { this_class }
 BinWriteU2(SuperNameIdx);    { super_class }

 { --- 5. Ecrire la table des interfaces --- }
 BinWriteU2(IfaceCount);      { interfaces_count }
 For i := 1 to IfaceCount do
  BinWriteU2(IfaceTab[i]);    { interfaces[] }

 { --- 6. Ecrire la table des champs --- }
 BinWriteU2(FieldCount);      { fields_count }
 For i := 1 to FieldCount do
  EmitFieldInfo(i);

 { --- 7. Ecrire la table des methodes --- }
 BinWriteU2(MethodCount);     { methods_count }
 For i := 1 to MethodCount do
  EmitMethodInfo(i);

 { --- 8. Ecrire les attributs de classe --- }
 { Compter les attributs de classe }
 classAttrCnt := 0;
 If SourceName <> '' Then Inc(classAttrCnt);        { SourceFile }
 If ClassDeprecated Then Inc(classAttrCnt);          { Deprecated }
 If ClassSignature <> '' Then Inc(classAttrCnt);     { Signature }
 If InnerCount > 0 Then Inc(classAttrCnt);           { InnerClasses }
 If EnclosingClass <> '' Then Inc(classAttrCnt);     { EnclosingMethod }

 BinWriteU2(classAttrCnt);    { attributes_count }

 { SourceFile }
 If SourceName <> '' Then
  EmitSourceFileAttr;
 { Deprecated }
 If ClassDeprecated Then
  EmitDeprecatedAttr;
 { Signature }
 If ClassSignature <> '' Then
  EmitSignatureAttr(ClassSignature);
 { InnerClasses }
 If InnerCount > 0 Then
  EmitInnerClassesAttr;
 { EnclosingMethod }
 If EnclosingClass <> '' Then
  EmitEnclosingMethodAttr;

 { --- 9. Fermer le fichier binaire --- }
 BinClose;

 WriteLn('Fichier genere : ', classOut, ' (', BinPos, ' octets)');

 SrcClose;
 GlobalCleanup;
End;

{ ============================================================================ }
{ Programme principal                                                          }
{ ============================================================================ }

BEGIN
 If ParamCount = 0 Then
 Begin
  WriteLn('JASMIN - ', VERSION);
  WriteLn;
  WriteLn('Syntaxe : JASMIN fichier.j [options]');
  WriteLn;
  WriteLn('  Assemble un fichier source Jasmin (.j) en fichier .class');
  WriteLn('  (bytecode Java) compatible avec la JVM.');
  WriteLn;
  WriteLn('Options :');
  WriteLn('  -o <fichier.class>  Specifier le nom du fichier de sortie');
  WriteLn('  -d <repertoire>     Specifier le repertoire de sortie');
  WriteLn('  -g                  Inclure les informations de debogage');
  WriteLn('  -v                  Mode verbeux');
  WriteLn('  -version            Afficher la version et quitter');
  WriteLn('  -help               Afficher cette aide');
  Halt;
 End;
 Assemble;
END.
