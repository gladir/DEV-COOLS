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
Begin
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
  NameIdx    := CPEnsureUtf8(name);
  DescIdx    := CPEnsureUtf8(desc);
  MaxStack   := 0;
  MaxLocals  := 0;
  CodeSize   := 0;
  ExcCount   := 0;
  LineCount  := 0;
  LabelCount := 0;
  ThrowCount := 0;
  Name       := name;
  Desc       := desc;
  HasCode    := ((flags and ACC_ABSTRACT) = 0) And ((flags and ACC_NATIVE) = 0);
  HasStack   := False;
  HasLocals  := False;
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
 End;
End;

{ --- LeaveMethod : finaliser la methode courante --- }
{ Verifie les labels non resolus, affiche un avertissement si .limit absent. }
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
  { Verifier les labels non resolus }
  For i := 1 to LabelCount do
  Begin
   If Not Labels^[i].Resolved Then
    Warning('.end method : label ''' + Labels^[i].Name + ''' non resolu');
  End;
  { Avertissement si .limit stack/locals absent pour methode avec code }
  If HasCode Then
  Begin
   If Not HasStack Then
    Warning('.method ' + Name + ' : .limit stack non defini, defaut 0');
   If Not HasLocals Then
    Warning('.method ' + Name + ' : .limit locals non defini, defaut 0');
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
   Else
    { Directives non encore implementees (TODO 09+) : sauter la ligne }
    If OptVerbose Then
     WriteLn('  [skip] directive ', CurStr, ' (TODO 09+)');
    SkipToEOL;
   End;  { Case }
  End
  Else
  Begin
   { Token non-directive : labels, instructions, etc. -> sauter la ligne }
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
 End;
 Dispose(MethodTab);
 Dispose(FieldTab);
 Dispose(CPTab);
End;

{ ============================================================================ }
{ Procedure Assemble                                                           }
{ ============================================================================ }

Procedure Assemble;
Var pi: Integer;
Begin
 GlobalInit;
 { Parser les options de la ligne de commande }
 For pi := 2 to ParamCount do
 Begin
  If ParamStr(pi) = '-v' Then OptVerbose := True
  Else If ParamStr(pi) = '-g' Then OptDebug := True;
 End;
 WriteLn(VERSION);
 WriteLn('Fichier source : ', SrcFileName);

 { Ouvrir le fichier source }
 SrcOpen(SrcFileName);

 { Lire le premier token }
 NextToken;

 { Parser les directives de classe et le contenu (TODO 06) }
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

 { Bilan de l'assemblage }
 BilanAssemblage;

 WriteLn;
 WriteLn('(Assemblage non encore implemente - voir TODOs 07 a 25)');

 SrcClose;
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
