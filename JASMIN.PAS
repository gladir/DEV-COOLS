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
{  TODO 02 - Lexeur : lecture source et tokenisation                           }
{  TODO 03 - Gestion des erreurs, des avertissements et du bilan              }
{  TODO 04 - Bassin de constantes (Constant Pool) : structures et gestion     }
{  TODO 05 - Ecriture binaire du fichier .class (Big-endian)                  }
{  TODO 06 - Directives de classe (.class, .super, .implements, .source)      }
{  TODO 07 - Directives de champs (.field avec descripteurs et valeurs)       }
{  TODO 08 - Directives de methodes (.method, .end method, .limit)            }
{  TODO 09 - Descripteurs de types JVM : parsing et validation                }
{  TODO 10 - Opcodes de chargement et stockage                                }
{  TODO 11 - Opcodes arithmetiques et logiques                                }
{  TODO 12 - Opcodes de conversion de types                                   }
{  TODO 13 - Opcodes de controle de flux                                      }
{  TODO 14 - Opcodes d'invocation de methodes                                 }
{  TODO 15 - Opcodes de manipulation de la pile et chargement de constantes   }
{  TODO 16 - Opcodes de creation d'objets et tableaux                         }
{  TODO 17 - Opcodes d'acces aux champs                                       }
{  TODO 18 - Opcodes de comparaison, retour et divers                         }
{  TODO 19 - Labels, resolution des sauts et calcul des offsets               }
{  TODO 20 - Attribut Code : generation binaire                               }
{  TODO 21 - Directives de gestion des exceptions (.catch, .throws)           }
{  TODO 22 - Attributs supplementaires (SourceFile, LineNumberTable, etc.)    }
{  TODO 23 - Programme principal : ligne de commande et generation .class     }
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
  MAX_IFACES   = 64;     { Interfaces implementees max                  }
  MAX_THROWS   = 32;     { Exceptions declarees (.throws) max           }
  MAX_LOCALS   = 256;    { Variables locales max (.var)                  }

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
    LongHi  : LongInt;      { moitie haute pour CP_LONG/CP_DOUBLE       }
    LongLo  : LongInt;      { moitie basse pour CP_LONG/CP_DOUBLE       }
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

  { --- Buffer de code pour une methode --- }
  TCodeBuf = Array[0..MAX_CODE-1] of Byte;

  { --- Table des labels pour une methode --- }
  TLabelTab = Array[1..MAX_LABELS] of TLabelRec;

  { --- Table des exception handlers pour une methode --- }
  TExcTab = Array[1..MAX_EXC] of TExcHandler;

  { --- Table des numeros de ligne pour une methode --- }
  TLineTab = Array[1..MAX_LINES] of TLineNumRec;

  { --- Pointeurs vers les buffers de methode --- }
  PCodeBuf  = ^TCodeBuf;
  PLabelTab = ^TLabelTab;
  PExcTab   = ^TExcTab;
  PLineTab  = ^TLineTab;

  { --- Entree d'un champ de classe --- }
  TFieldRec = Record
    AccFlags  : Integer;     { drapeaux d'acces (ACC_xxx)                }
    NameIdx   : Integer;     { index CP du nom du champ                  }
    DescIdx   : Integer;     { index CP du descripteur de type           }
    AttrCount : Integer;     { nombre d'attributs                        }
    HasInit   : Boolean;     { True si valeur initiale ConstantValue     }
    InitCPIdx : Integer;     { index CP de la valeur initiale            }
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
    ThrowCount : Integer;    { nombre de .throws                         }
    ThrowIdx   : Array[1..MAX_THROWS] of Integer; { indices CP des classes }
    Name       : String;     { nom de la methode (pour messages)         }
    Desc       : String;     { descripteur de la methode                 }
    HasCode    : Boolean;    { True si methode non-abstract/non-native   }
    HasStack   : Boolean;    { True si .limit stack defini               }
    HasLocals  : Boolean;    { True si .limit locals defini              }
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

Function StrToInt_(Const s: String): LongInt;
Var v: LongInt; code: Integer;
Begin
 Val(s, v, code);
 If code <> 0 Then v := 0;
 StrToInt_ := v;
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
{ Initialisation globale                                                       }
{ ============================================================================ }

Procedure GlobalInit;
Var i: Integer;
Begin
 OutFileName   := '';
 OutDir        := '';
 OptDebug      := False;
 OptVerbose    := False;

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

 ClassMajor    := CLASS_MAJOR_DEFAULT;
 ClassMinor    := CLASS_MINOR_DEFAULT;

 { Allouer les tables sur le tas }
 New(CPTab);
 New(FieldTab);
 New(MethodTab);

 { Initialiser le Constant Pool (entree 0 inutilisee) }
 CPCount := 1;
 For i := 0 to MAX_CP - 1 do
 Begin
  CPTab^[i].Tag     := CP_NONE;
  CPTab^[i].StrVal  := '';
  CPTab^[i].IntVal  := 0;
  CPTab^[i].FloatVal:= 0.0;
  CPTab^[i].Ref1    := 0;
  CPTab^[i].Ref2    := 0;
  CPTab^[i].LongHi  := 0;
  CPTab^[i].LongLo  := 0;
 End;

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
 End;
 Dispose(MethodTab);
 Dispose(FieldTab);
 Dispose(CPTab);
End;

{ ============================================================================ }
{ Procedure Assemble (stub - sera completee dans les TODOs suivants)           }
{ ============================================================================ }

Procedure Assemble;
Begin
 GlobalInit;
 WriteLn(VERSION);
 WriteLn('Fichier source : ', SrcFileName);
 WriteLn;
 WriteLn('(Assemblage non encore implemente - voir TODOs 02 a 25)');
 GlobalCleanup;
End;

{ ============================================================================ }
{ Programme principal                                                          }
{ ============================================================================ }

BEGIN
 If (ParamCount = 0) or (ParamStr(1) = '/?') or (ParamStr(1) = '--help')
    or (ParamStr(1) = '-h') or (ParamStr(1) = '/h') or
    (ParamStr(1) = '/H') Then
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
 If (ParamStr(1) = '-version') or (ParamStr(1) = '--version') Then
 Begin
  WriteLn(VERSION);
  Halt;
 End;
 SrcFileName := ParamStr(1);
 Assemble;
END.
