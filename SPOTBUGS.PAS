{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Clone de SpotBugs - Analyseur statique de bytecode Java (.class)
}

{ ---------------------------------------------------------------------------- }
{  ARCHITECTURE GENERALE                                                       }
{ ---------------------------------------------------------------------------- }
{  1. Lecteur   : ReadClassFile, ParseConstantPool, ParseFields, ParseMethods  }
{  2. Analyseur : AnalyzeBytecode, BuildCFG, RunDetectors                      }
{  3. Detecteurs: NullDeref, ResourceLeak, BadPractice, Performance, Security  }
{  4. Rapport   : EmitTextReport, EmitXmlReport, EmitHtmlReport                }
{  5. Main      : ParseArgs, ScanClassFiles, PrintSummary                      }
{ ---------------------------------------------------------------------------- }

{ ---------------------------------------------------------------------------- }
{  TODO 01 [IMPLEMENTE] - Infrastructure, options et constantes globales      }
{  TODO 02 [IMPLEMENTE] - Lecture et validation de l'en-tete .class           }
{  TODO 03 [IMPLEMENTE] - Decodage du Constant Pool                           }
{  TODO 04 [IMPLEMENTE] - Lecture des flags, this_class, super_class, interfaces }
{  TODO 05 [A FAIRE] - Lecture des champs (fields) de la classe               }
{  TODO 06 [A FAIRE] - Lecture des methodes et de l'attribut Code             }
{  TODO 07 [A FAIRE] - Decodage du bytecode Java (opcodes JVM)                }
{  TODO 08 [A FAIRE] - Construction du graphe de flux de controle (CFG)       }
{  TODO 09 [A FAIRE] - Detecteur : dereferencement de pointeur null           }
{  TODO 10 [A FAIRE] - Detecteur : fuite de ressources (resource leaks)       }
{  TODO 11 [A FAIRE] - Detecteur : boucles infinies et blocs inaccessibles    }
{  TODO 12 [A FAIRE] - Detecteur : mauvaises pratiques (bad practices)        }
{  TODO 13 [A FAIRE] - Detecteur : comparaisons incorrectes d'objets          }
{  TODO 14 [A FAIRE] - Detecteur : problemes de performance                   }
{  TODO 15 [A FAIRE] - Detecteur : vulnerabilites de securite                 }
{  TODO 16 [A FAIRE] - Detecteur : problemes de multi-threading               }
{  TODO 17 [A FAIRE] - Detecteur : exceptions masquees et flux d'erreur       }
{  TODO 18 [A FAIRE] - Detecteur : erreurs logiques et retours incorrects     }
{  TODO 19 [A FAIRE] - Detecteur : problemes d'internationalisation           }
{  TODO 20 [A FAIRE] - Calcul des scores et niveaux de severite               }
{  TODO 21 [A FAIRE] - Generation du rapport texte                            }
{  TODO 22 [A FAIRE] - Generation du rapport XML (format SpotBugs)            }
{  TODO 23 [A FAIRE] - Generation du rapport HTML                             }
{  TODO 24 [A FAIRE] - Filtrage, exclusions et configuration des regles       }
{  TODO 25 [A FAIRE] - Programme principal, balayage recursif et exemples     }
{ ---------------------------------------------------------------------------- }

Program SPOTBUGS;

{$A-}
{$I-}

Uses DOS;

{ ============================================================================ }
{ TODO 01 [IMPLEMENTE] - Infrastructure, options et constantes globales        }
{ ============================================================================ }
{                                                                              }
{  - Constantes de dimensionnement :                                           }
{      MAX_CP_ENTRIES = 65535  (taille maximale du Constant Pool)              }
{      MAX_FIELDS     = 4096   (nombre maximum de champs par classe)           }
{      MAX_METHODS    = 4096   (nombre maximum de methodes par classe)         }
{      MAX_INTERFACES = 256    (nombre maximum d'interfaces implementees)      }
{      MAX_BUGS       = 8192   (nombre maximum de bugs detectes)               }
{      MAX_CFG_NODES  = 65535  (noeuds maximum dans le graphe de controle)     }
{      MAX_STACK_DEPTH = 512   (profondeur maximale de la pile d'analyse)      }
{      MAX_CLASSES    = 4096   (nombre maximum de classes analysees)           }
{      BUFSIZE        = 65536  (taille du tampon de lecture)                   }
{                                                                              }
{  - Niveaux de severite des bugs :                                            }
{      SEV_HIGH   = 1  (bugs critiques, erreurs presque certaines)             }
{      SEV_MEDIUM = 2  (bugs probables, pratiques suspectes)                   }
{      SEV_LOW    = 3  (bugs possibles, avertissements mineurs)                }
{      SEV_INFO   = 4  (informations, suggestions d'amelioration)              }
{                                                                              }
{  - Categories de bugs (codes courts) :                                       }
{      CAT_CORRECTNESS = 1  (erreurs de logique, bugs fonctionnels)            }
{      CAT_BAD_PRACTICE = 2 (violations de bonnes pratiques Java)              }
{      CAT_PERFORMANCE  = 3 (problemes de performance)                         }
{      CAT_SECURITY     = 4 (vulnerabilites de securite)                       }
{      CAT_MT_CORRECTNESS = 5 (erreurs de multi-threading)                     }
{      CAT_INTERNATIONALIZATION = 6 (problemes d'internationalisation)         }
{      CAT_DODGY        = 7 (code suspect ou mal ecrit)                        }
{      CAT_MALICIOUS    = 8 (code potentiellement malveillant)                 }
{                                                                              }
{  - Types de tokens du Constant Pool JVM :                                    }
{      CP_UTF8             =  1                                                }
{      CP_INTEGER          =  3                                                }
{      CP_FLOAT            =  4                                                }
{      CP_LONG             =  5                                                }
{      CP_DOUBLE           =  6                                                }
{      CP_CLASS            =  7                                                }
{      CP_STRING           =  8                                                }
{      CP_FIELDREF         =  9                                                }
{      CP_METHODREF        = 10                                                }
{      CP_INTERFACEMETHODREF = 11                                              }
{      CP_NAMEANDTYPE      = 12                                                }
{      CP_METHODHANDLE     = 15                                                }
{      CP_METHODTYPE       = 16                                                }
{      CP_INVOKEDYNAMIC    = 18                                                }
{                                                                              }
{  - Constantes de flags d'acces :                                             }
{      ACC_PUBLIC       = $0001                                                }
{      ACC_PRIVATE      = $0002                                                }
{      ACC_PROTECTED    = $0004                                                }
{      ACC_STATIC       = $0008                                                }
{      ACC_FINAL        = $0010                                                }
{      ACC_SYNCHRONIZED = $0020                                                }
{      ACC_VOLATILE     = $0040                                                }
{      ACC_TRANSIENT    = $0080                                                }
{      ACC_NATIVE       = $0100                                                }
{      ACC_INTERFACE    = $0200                                                }
{      ACC_ABSTRACT     = $0400                                                }
{      ACC_STRICT       = $0800                                                }
{      ACC_SYNTHETIC    = $1000                                                }
{      ACC_ANNOTATION   = $2000                                                }
{      ACC_ENUM         = $4000                                                }
{                                                                              }
{  - Structure TOptions :                                                       }
{      ClassPath  : array[0..63] of String  (chemins de recherche .class)      }
{      ClassCount : Integer                 (nombre de chemins)                }
{      OutFile    : String                  (fichier de sortie du rapport)      }
{      OutFormat  : Integer                 (TEXT=0 / XML=1 / HTML=2)          }
{      MinSeverity : Integer                (severite minimale a rapporter)     }
{      Verbose    : Boolean                 (mode bavard)                       }
{      Recursive  : Boolean                 (analyser recursivement)            }
{      ShowCount  : Boolean                 (afficher les statistiques)         }
{      ExcludeFile : String                 (fichier de regles d'exclusion)     }
{      IncludeFile : String                 (fichier de regles d'inclusion)     }
{      MaxBugs    : Integer                 (nombre maximum de bugs a reporter) }
{                                                                              }
{  - Structure TBugReport :                                                     }
{      BugType    : String  (identifiant de la regle ex. NP_NULL_ON_SOME_PATH) }
{      Category   : Integer (CAT_*)                                             }
{      Severity   : Integer (SEV_*)                                             }
{      ClassName  : String  (nom de la classe Java concernee)                  }
{      MethodName : String  (nom de la methode concernee)                       }
{      FieldName  : String  (nom du champ concerne, si applicable)             }
{      LineNumber : Integer (numero de ligne source, si disponible)            }
{      Message    : String  (description lisible du bug)                       }
{                                                                              }
{  - Variables globales :                                                       }
{      Opts       : TOptions         (options de la ligne de commande)          }
{      Bugs       : array[TBugReport] (table des bugs detectes)                 }
{      BugCount   : Integer           (nombre de bugs detectes)                 }
{      ClassesScanned : Integer       (nombre de classes analysees)             }
{      TotalMethods   : Integer       (nombre total de methodes analysees)      }
{      ErrorCount     : Integer       (nombre d'erreurs d'analyse)              }
{                                                                              }
{  - Utilitaires :                                                              }
{      ReadU1, ReadU2, ReadU4  : lecture big-endian depuis fichier              }
{      HexByte, HexWord, HexDWord : conversion hexadecimale                    }
{      IntToStr_, StrToInt_, UpCaseStr : utilitaires chaines                   }
{      FileExists_, ChangeExt : utilitaires fichiers                            }
{      FatalError(msg), Error(msg), Warning(msg) : gestion d'erreurs           }
{      AddBug(type, cat, sev, class, method, field, line, msg) : enregistrer   }

Const

  { ------------------------------------------------------------------ }
  { Constantes de dimensionnement                                       }
  { ------------------------------------------------------------------ }
  MAX_CP_ENTRIES  = 65535;  { Taille maximale du Constant Pool          }
  MAX_FIELDS      = 4096;   { Nombre maximum de champs par classe       }
  MAX_METHODS     = 4096;   { Nombre maximum de methodes par classe     }
  MAX_INTERFACES  = 256;    { Nombre maximum d'interfaces implementees  }
  MAX_BUGS        = 8192;   { Nombre maximum de bugs detectes           }
  MAX_CFG_NODES   = 65535;  { Noeuds maximum dans le graphe de controle }
  MAX_STACK_DEPTH = 512;    { Profondeur maximale de la pile d'analyse  }
  MAX_CLASSES     = 4096;   { Nombre maximum de classes analysees       }
  MAX_CLASSPATH   = 64;     { Nombre maximum de chemins de recherche    }
  BUFSIZE         = 65536;  { Taille du tampon de lecture               }

  { ------------------------------------------------------------------ }
  { Niveaux de severite des bugs                                        }
  { ------------------------------------------------------------------ }
  SEV_HIGH   = 1;   { Bugs critiques, erreurs presque certaines         }
  SEV_MEDIUM = 2;   { Bugs probables, pratiques suspectes               }
  SEV_LOW    = 3;   { Bugs possibles, avertissements mineurs            }
  SEV_INFO   = 4;   { Informations, suggestions d'amelioration          }

  { ------------------------------------------------------------------ }
  { Categories de bugs (codes courts)                                   }
  { ------------------------------------------------------------------ }
  CAT_CORRECTNESS         = 1;  { Erreurs de logique, bugs fonctionnels }
  CAT_BAD_PRACTICE        = 2;  { Violations de bonnes pratiques Java   }
  CAT_PERFORMANCE         = 3;  { Problemes de performance              }
  CAT_SECURITY            = 4;  { Vulnerabilites de securite            }
  CAT_MT_CORRECTNESS      = 5;  { Erreurs de multi-threading            }
  CAT_INTERNATIONALIZATION = 6; { Problemes d'internationalisation      }
  CAT_DODGY               = 7;  { Code suspect ou mal ecrit             }
  CAT_MALICIOUS           = 8;  { Code potentiellement malveillant      }

  { ------------------------------------------------------------------ }
  { Formats de sortie du rapport                                        }
  { ------------------------------------------------------------------ }
  OUT_TEXT = 0;    { Format texte simple                                }
  OUT_XML  = 1;    { Format XML (compatible SpotBugs/Jenkins)           }
  OUT_HTML = 2;    { Format HTML autonome                               }

  { ------------------------------------------------------------------ }
  { Types de tokens du Constant Pool JVM                                }
  { ------------------------------------------------------------------ }
  CP_NONE                = 0;   { Entree non utilisee                   }
  CP_UTF8                = 1;   { CONSTANT_Utf8                         }
  CP_INTEGER             = 3;   { CONSTANT_Integer                      }
  CP_FLOAT               = 4;   { CONSTANT_Float                        }
  CP_LONG                = 5;   { CONSTANT_Long (occupe 2 slots)        }
  CP_DOUBLE              = 6;   { CONSTANT_Double (occupe 2 slots)      }
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
  { Constantes de flags d'acces JVM                                     }
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
  ACC_INTERFACE    = $0200;  { interface                                }
  ACC_ABSTRACT     = $0400;  { abstract                                 }
  ACC_STRICT       = $0800;  { strictfp                                 }
  ACC_SYNTHETIC    = $1000;  { synthetic                                }
  ACC_ANNOTATION   = $2000;  { annotation                               }
  ACC_ENUM         = $4000;  { enum                                     }

  { ------------------------------------------------------------------ }
  { Version de l'analyseur                                              }
  { ------------------------------------------------------------------ }
  SPOTBUGS_VERSION = '1.0.0';

  { ------------------------------------------------------------------ }
  { TODO 02 : Constante magique des fichiers .class                     }
  { ------------------------------------------------------------------ }
  { $CAFEBABE = 3405691582 en non-signe = -889275714 en signe (LongInt) }
  CLASS_MAGIC_HI = $CAFE;     { Partie haute de la signature            }
  CLASS_MAGIC_LO = $BABE;     { Partie basse de la signature            }

{ ============================================================================ }
{ Types et structures                                                          }
{ ============================================================================ }

Type

  { --- Structure TOptions : options de ligne de commande --- }
  TOptions = Record
    ClassPath   : Array[0..MAX_CLASSPATH-1] of String; { Chemins de recherche }
    ClassCount  : Integer;   { Nombre de chemins dans ClassPath         }
    OutFile     : String;    { Fichier de sortie du rapport             }
    OutFormat   : Integer;   { Format: OUT_TEXT, OUT_XML, OUT_HTML      }
    MinSeverity : Integer;   { Severite minimale a rapporter            }
    Verbose     : Boolean;   { Mode bavard                              }
    Recursive   : Boolean;   { Analyser recursivement                   }
    ShowCount   : Boolean;   { Afficher les statistiques                }
    ExcludeFile : String;    { Fichier de regles d'exclusion            }
    IncludeFile : String;    { Fichier de regles d'inclusion            }
    MaxBugs     : Integer;   { Nombre maximum de bugs a reporter        }
  End;

  { --- Structure TBugReport : description d'un bug detecte --- }
  TBugReport = Record
    BugType    : String;     { Identifiant de la regle (NP_NULL_ON_SOME_PATH) }
    Category   : Integer;    { Categorie (CAT_*)                        }
    Severity   : Integer;    { Severite (SEV_*)                         }
    ClassName  : String;     { Nom de la classe Java concernee          }
    MethodName : String;     { Nom de la methode concernee              }
    FieldName  : String;     { Nom du champ concerne, si applicable     }
    LineNumber : Integer;    { Numero de ligne source, si disponible    }
    Message    : String;     { Description lisible du bug               }
  End;

  { --- Tableau de bugs --- }
  TBugArray = Array[1..MAX_BUGS] of TBugReport;

  { --- TODO 02 : Structure TClassHeader : en-tete du fichier .class --- }
  TClassHeader = Record
    Magic        : LongInt;    { Doit etre $CAFEBABE                      }
    MinorVersion : Word;       { Version mineure JVM                      }
    MajorVersion : Word;       { Version majeure JVM (ex. 52 = Java 8)    }
    CPCount      : Word;       { Nombre d'entrees dans le Constant Pool+1 }
    AccessFlags  : Word;       { Flags d'acces de la classe               }
    ThisClass    : Word;       { Index CP vers le nom de la classe        }
    SuperClass   : Word;       { Index CP vers la super-classe            }
    InterfaceCount : Word;     { Nombre d'interfaces implementees         }
  End;

  { --- TODO 03 : Structure TCPEntry : entree du Constant Pool --- }
  TCPEntry = Record
    Tag      : Byte;           { Type de l'entree (CP_UTF8, CP_CLASS...) }
    StrVal   : String;         { Valeur Utf8 si Tag=CP_UTF8              }
    IntVal   : LongInt;        { Valeur entiere si Tag=CP_INTEGER        }
    FloatVal : Real;           { Valeur flottante si Tag=CP_FLOAT/DOUBLE }
    Ref1     : Word;           { Premier index de reference              }
    Ref2     : Word;           { Second index de reference               }
    IsDouble : Boolean;        { True si occupe 2 slots (LONG/DOUBLE)    }
  End;

  { --- TODO 03 : Tableau du Constant Pool --- }
  TCPArray = Array[0..MAX_CP_ENTRIES] of TCPEntry;

  { --- TODO 04 : Structure TClassInfo : informations de la classe --- }
  TClassInfo = Record
    AccessFlags    : Word;                        { Flags d'acces de la classe    }
    ThisClass      : String;                      { Nom interne (java/lang/X)     }
    SuperClass     : String;                      { Nom de la super-classe        }
    Interfaces     : Array[0..MAX_INTERFACES-1] of String; { Interfaces }
    InterfaceCount : Integer;                     { Nombre d'interfaces           }
    IsInterface    : Boolean;                     { True si ACC_INTERFACE set     }
    IsAbstract     : Boolean;                     { True si ACC_ABSTRACT set      }
    IsEnum         : Boolean;                     { True si ACC_ENUM set          }
    IsAnnotation   : Boolean;                     { True si ACC_ANNOTATION set    }
    IsFinal        : Boolean;                     { True si ACC_FINAL set         }
    IsPublic       : Boolean;                     { True si ACC_PUBLIC set        }
    IsSynthetic    : Boolean;                     { True si ACC_SYNTHETIC set     }
    SourceFile     : String;                      { Nom du fichier source .java   }
  End;

{ ============================================================================ }
{ Variables globales                                                           }
{ ============================================================================ }

Var
  Opts           : TOptions;      { Options de la ligne de commande     }
  Bugs           : TBugArray;     { Table des bugs detectes             }
  BugCount       : Integer;       { Nombre de bugs detectes             }
  ClassesScanned : Integer;       { Nombre de classes analysees         }
  TotalMethods   : Integer;       { Nombre total de methodes analysees  }
  ErrorCount     : Integer;       { Nombre d'erreurs d'analyse          }
  WarningCount   : Integer;       { Nombre d'avertissements             }
  CurrentFile    : String;        { Fichier .class en cours d'analyse   }
  ClassFile      : File;          { Handle du fichier .class ouvert     }
  ClassFileOpen  : Boolean;       { True si ClassFile est ouvert        }
  ClassHeader    : TClassHeader;  { TODO 02 : En-tete du .class courant }
  CP             : ^TCPArray;     { TODO 03 : Constant Pool (pointeur)  }
  CPCount        : Word;          { TODO 03 : Nombre d'entrees CP       }
  ClassInfo      : TClassInfo;    { TODO 04 : Informations de la classe }

{ ============================================================================ }
{ Utilitaires chaines et conversions                                           }
{ ============================================================================ }

Function IntToStr_(N: LongInt): String;
Var
  S: String;
Begin
  Str(N, S);
  IntToStr_ := S;
End;

Function StrToInt_(S: String): LongInt;
Var
  N: LongInt;
  Code: Integer;
Begin
  Val(S, N, Code);
  If Code <> 0 Then N := 0;
  StrToInt_ := N;
End;

Function UpCaseStr(S: String): String;
Var
  I: Integer;
Begin
  For I := 1 to Length(S) do
    If S[I] in ['a'..'z'] Then
      S[I] := Chr(Ord(S[I]) - 32);
  UpCaseStr := S;
End;

Function LoCaseStr(S: String): String;
Var
  I: Integer;
Begin
  For I := 1 to Length(S) do
    If S[I] in ['A'..'Z'] Then
      S[I] := Chr(Ord(S[I]) + 32);
  LoCaseStr := S;
End;

Function TrimStr(S: String): String;
Begin
  While (Length(S) > 0) and (S[1] = ' ') do
    Delete(S, 1, 1);
  While (Length(S) > 0) and (S[Length(S)] = ' ') do
    Delete(S, Length(S), 1);
  TrimStr := S;
End;

{ ============================================================================ }
{ Conversion hexadecimale                                                      }
{ ============================================================================ }

Function HexDigit(N: Byte): Char;
Begin
  If N < 10 Then
    HexDigit := Chr(Ord('0') + N)
  Else
    HexDigit := Chr(Ord('A') + N - 10);
End;

Function HexByte(B: Byte): String;
Begin
  HexByte := HexDigit(B shr 4) + HexDigit(B and $0F);
End;

Function HexWord(W: Word): String;
Begin
  HexWord := HexByte(Hi(W)) + HexByte(Lo(W));
End;

Function HexDWord(D: LongInt): String;
Begin
  HexDWord := HexWord(D shr 16) + HexWord(D and $FFFF);
End;

{ ============================================================================ }
{ Utilitaires fichiers                                                         }
{ ============================================================================ }

Function FileExists_(FileName: String): Boolean;
Var
  F: File;
Begin
  {$I-}
  Assign(F, FileName);
  Reset(F, 1);
  If IOResult = 0 Then Begin
    Close(F);
    FileExists_ := True;
  End Else
    FileExists_ := False;
  {$I+}
End;

Function ChangeExt(FileName, NewExt: String): String;
Var
  D: DirStr;
  N: NameStr;
  E: ExtStr;
Begin
  FSplit(FileName, D, N, E);
  ChangeExt := D + N + NewExt;
End;

Function ExtractFileName(Path: String): String;
Var
  D: DirStr;
  N: NameStr;
  E: ExtStr;
Begin
  FSplit(Path, D, N, E);
  ExtractFileName := N + E;
End;

Function ExtractFilePath(Path: String): String;
Var
  D: DirStr;
  N: NameStr;
  E: ExtStr;
Begin
  FSplit(Path, D, N, E);
  ExtractFilePath := D;
End;

{ ============================================================================ }
{ Lecture big-endian depuis fichier binaire                                    }
{ ============================================================================ }

Function ReadU1: Byte;
Var
  B: Byte;
Begin
  BlockRead(ClassFile, B, 1);
  ReadU1 := B;
End;

Function ReadU2: Word;
Var
  B1, B2: Byte;
Begin
  BlockRead(ClassFile, B1, 1);
  BlockRead(ClassFile, B2, 1);
  ReadU2 := (Word(B1) shl 8) or Word(B2);
End;

Function ReadU4: LongInt;
Var
  B1, B2, B3, B4: Byte;
Begin
  BlockRead(ClassFile, B1, 1);
  BlockRead(ClassFile, B2, 1);
  BlockRead(ClassFile, B3, 1);
  BlockRead(ClassFile, B4, 1);
  ReadU4 := (LongInt(B1) shl 24) or (LongInt(B2) shl 16) or
            (LongInt(B3) shl 8) or LongInt(B4);
End;

{ ============================================================================ }
{ Gestion des erreurs, avertissements et messages                              }
{ ============================================================================ }

Procedure FatalError(Msg: String);
Begin
  WriteLn('ERREUR FATALE: ', Msg);
  If ClassFileOpen Then Begin
    Close(ClassFile);
    ClassFileOpen := False;
  End;
  Halt(1);
End;

Procedure Error(Msg: String);
Begin
  WriteLn('ERREUR: ', Msg);
  Inc(ErrorCount);
End;

Procedure Warning(Msg: String);
Begin
  If Opts.Verbose Then
    WriteLn('AVERTISSEMENT: ', Msg);
  Inc(WarningCount);
End;

Procedure Info(Msg: String);
Begin
  If Opts.Verbose Then
    WriteLn('INFO: ', Msg);
End;

{ ============================================================================ }
{ Gestion des bugs detectes                                                    }
{ ============================================================================ }

Procedure AddBug(BugType: String; Category, Severity: Integer;
                 ClassName, MethodName, FieldName: String;
                 LineNumber: Integer; Message: String);
Begin
  If BugCount >= MAX_BUGS Then Begin
    Warning('Nombre maximum de bugs atteint (' + IntToStr_(MAX_BUGS) + ')');
    Exit;
  End;
  If Severity > Opts.MinSeverity Then
    Exit;  { Ignorer les bugs de severite trop basse }
  Inc(BugCount);
  Bugs[BugCount].BugType    := BugType;
  Bugs[BugCount].Category   := Category;
  Bugs[BugCount].Severity   := Severity;
  Bugs[BugCount].ClassName  := ClassName;
  Bugs[BugCount].MethodName := MethodName;
  Bugs[BugCount].FieldName  := FieldName;
  Bugs[BugCount].LineNumber := LineNumber;
  Bugs[BugCount].Message    := Message;
End;

Function SeverityToStr(Sev: Integer): String;
Begin
  Case Sev of
    SEV_HIGH:   SeverityToStr := 'HIGH';
    SEV_MEDIUM: SeverityToStr := 'MEDIUM';
    SEV_LOW:    SeverityToStr := 'LOW';
    SEV_INFO:   SeverityToStr := 'INFO';
  Else
    SeverityToStr := 'UNKNOWN';
  End;
End;

Function CategoryToStr(Cat: Integer): String;
Begin
  Case Cat of
    CAT_CORRECTNESS:          CategoryToStr := 'CORRECTNESS';
    CAT_BAD_PRACTICE:         CategoryToStr := 'BAD_PRACTICE';
    CAT_PERFORMANCE:          CategoryToStr := 'PERFORMANCE';
    CAT_SECURITY:             CategoryToStr := 'SECURITY';
    CAT_MT_CORRECTNESS:       CategoryToStr := 'MT_CORRECTNESS';
    CAT_INTERNATIONALIZATION: CategoryToStr := 'I18N';
    CAT_DODGY:                CategoryToStr := 'DODGY_CODE';
    CAT_MALICIOUS:            CategoryToStr := 'MALICIOUS_CODE';
  Else
    CategoryToStr := 'UNKNOWN';
  End;
End;

{ ============================================================================ }
{ Initialisation des variables globales                                        }
{ ============================================================================ }

Procedure InitGlobals;
Var
  I: Integer;
Begin
  { Initialiser les options par defaut }
  Opts.ClassCount  := 0;
  Opts.OutFile     := '';
  Opts.OutFormat   := OUT_TEXT;
  Opts.MinSeverity := SEV_LOW;
  Opts.Verbose     := False;
  Opts.Recursive   := False;
  Opts.ShowCount   := True;
  Opts.ExcludeFile := '';
  Opts.IncludeFile := '';
  Opts.MaxBugs     := MAX_BUGS;
  For I := 0 to MAX_CLASSPATH - 1 do
    Opts.ClassPath[I] := '';

  { Initialiser les compteurs }
  BugCount       := 0;
  ClassesScanned := 0;
  TotalMethods   := 0;
  ErrorCount     := 0;
  WarningCount   := 0;
  CurrentFile    := '';
  ClassFileOpen  := False;

  { Initialiser l'en-tete de classe (TODO 02) }
  ClassHeader.Magic        := 0;
  ClassHeader.MinorVersion := 0;
  ClassHeader.MajorVersion := 0;
  ClassHeader.CPCount      := 0;
  ClassHeader.AccessFlags  := 0;
  ClassHeader.ThisClass    := 0;
  ClassHeader.SuperClass   := 0;
  ClassHeader.InterfaceCount := 0;

  { Initialiser le Constant Pool (TODO 03) }
  CP := Nil;
  CPCount := 0;
End;

{ ============================================================================ }
{ TODO 02 [IMPLEMENTE] - Lecture et validation de l'en-tete .class             }
{ ============================================================================ }

{ --- GetJavaVersion : traduit la version majeure JVM en version Java lisible --- }
Function GetJavaVersion(Major: Word): String;
Begin
  Case Major of
    45: GetJavaVersion := 'Java 1.1';
    46: GetJavaVersion := 'Java 1.2';
    47: GetJavaVersion := 'Java 1.3';
    48: GetJavaVersion := 'Java 1.4';
    49: GetJavaVersion := 'Java 5';
    50: GetJavaVersion := 'Java 6';
    51: GetJavaVersion := 'Java 7';
    52: GetJavaVersion := 'Java 8';
    53: GetJavaVersion := 'Java 9';
    54: GetJavaVersion := 'Java 10';
    55: GetJavaVersion := 'Java 11';
    56: GetJavaVersion := 'Java 12';
    57: GetJavaVersion := 'Java 13';
    58: GetJavaVersion := 'Java 14';
    59: GetJavaVersion := 'Java 15';
    60: GetJavaVersion := 'Java 16';
    61: GetJavaVersion := 'Java 17';
    62: GetJavaVersion := 'Java 18';
    63: GetJavaVersion := 'Java 19';
    64: GetJavaVersion := 'Java 20';
    65: GetJavaVersion := 'Java 21';
    66: GetJavaVersion := 'Java 22';
    67: GetJavaVersion := 'Java 23';
  Else
    If Major > 67 Then
      GetJavaVersion := 'Java ' + IntToStr_(Major - 44) + ' (future)'
    Else
      GetJavaVersion := 'Inconnu (' + IntToStr_(Major) + ')';
  End;
End;

{ --- OpenClassFile : ouvrir un fichier .class et valider la signature --- }
Procedure OpenClassFile(FileName: String);
Var
  Magic: LongInt;
Begin
  { Fermer le fichier precedent si encore ouvert }
  If ClassFileOpen Then Begin
    Close(ClassFile);
    ClassFileOpen := False;
  End;

  { Verifier si le fichier existe }
  If Not FileExists_(FileName) Then
    FatalError('Fichier introuvable: ' + FileName);

  { Ouvrir le fichier en mode binaire }
  CurrentFile := FileName;
  {$I-}
  Assign(ClassFile, FileName);
  Reset(ClassFile, 1);
  {$I+}
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir le fichier: ' + FileName);

  ClassFileOpen := True;

  { Lire et valider le magic number ($CAFEBABE) }
  Magic := ReadU4;
  { Comparer via HexDWord pour eviter les problemes de signe }
  If HexDWord(Magic) <> 'CAFEBABE' Then Begin
    Close(ClassFile);
    ClassFileOpen := False;
    FatalError('Signature invalide: ' + HexDWord(Magic) +
               ' (attendu CAFEBABE) dans ' + FileName);
  End;

  Info('Fichier .class ouvert: ' + FileName);
End;

{ --- ReadClassHeader : lire l'en-tete du fichier .class --- }
Function ReadClassHeader: TClassHeader;
Var
  H: TClassHeader;
Begin
  { Le magic a deja ete lu par OpenClassFile, stocker la valeur lue }
  { On utilise la representation signee negative de $CAFEBABE }
  H.Magic := -889275714;  { = $CAFEBABE interprete comme LongInt signe }

  { Lire les versions (big-endian) }
  H.MinorVersion := ReadU2;
  H.MajorVersion := ReadU2;

  { Verifier la version }
  If (H.MajorVersion < 45) or (H.MajorVersion > 67) Then
    Warning('Version JVM inconnue ou trop recente: ' +
            IntToStr_(H.MajorVersion) + '.' + IntToStr_(H.MinorVersion));

  Info('Version: ' + GetJavaVersion(H.MajorVersion) +
       ' (' + IntToStr_(H.MajorVersion) + '.' +
       IntToStr_(H.MinorVersion) + ')');

  { Lire le nombre d'entrees du Constant Pool }
  H.CPCount := ReadU2;
  If H.CPCount < 1 Then
    Warning('Constant Pool vide ou invalide');
  Info('Constant Pool: ' + IntToStr_(H.CPCount - 1) + ' entrees');

  { Les autres champs seront lus apres le Constant Pool (TODO 03/04) }
  H.AccessFlags    := 0;
  H.ThisClass      := 0;
  H.SuperClass     := 0;
  H.InterfaceCount := 0;

  { Stocker dans la variable globale }
  ClassHeader := H;

  ReadClassHeader := H;
End;

{ --- CloseClassFile : fermer le fichier .class courant --- }
Procedure CloseClassFile;
Begin
  If ClassFileOpen Then Begin
    {$I-}
    Close(ClassFile);
    {$I+}
    If IOResult <> 0 Then
      Warning('Erreur lors de la fermeture du fichier: ' + CurrentFile);
    ClassFileOpen := False;
    Info('Fichier ferme: ' + CurrentFile);
    CurrentFile := '';
  End;
End;

{ ============================================================================ }
{ TODO 03 [IMPLEMENTE] - Decodage du Constant Pool                             }
{ ============================================================================ }

{ --- InitConstantPool : initialiser le Constant Pool --- }
Procedure InitConstantPool;
Begin
  If CP <> Nil Then Begin
    FreeMem(CP, SizeOf(TCPArray));
    CP := Nil;
  End;
  CPCount := 0;
End;

{ --- AllocConstantPool : allouer le Constant Pool --- }
Procedure AllocConstantPool(Count: Word);
Begin
  InitConstantPool;
  GetMem(CP, SizeOf(TCPArray));
  If CP = Nil Then
    FatalError('Memoire insuffisante pour Constant Pool');
  CPCount := Count;
End;

{ --- ParseConstantPool : lire le Constant Pool depuis le fichier .class --- }
Procedure ParseConstantPool(Count: Word);
Var
  I: Word;
  Tag: Byte;
  Len: Word;
  J: Word;
  B: Byte;
  B1, B2, B3, B4: Byte;
  HiInt, LoInt: LongInt;
Begin
  AllocConstantPool(Count);
  
  { Entree 0 non utilisee }
  CP^[0].Tag := CP_NONE;
  CP^[0].StrVal := '';
  CP^[0].IntVal := 0;
  CP^[0].FloatVal := 0;
  CP^[0].Ref1 := 0;
  CP^[0].Ref2 := 0;
  CP^[0].IsDouble := False;
  
  I := 1;
  While I < Count Do Begin
    { Lire le tag }
    Tag := ReadU1;
    CP^[I].Tag := Tag;
    CP^[I].StrVal := '';
    CP^[I].IntVal := 0;
    CP^[I].FloatVal := 0;
    CP^[I].Ref1 := 0;
    CP^[I].Ref2 := 0;
    CP^[I].IsDouble := False;
    
    Case Tag of
      CP_UTF8: Begin
        { Lire longueur U2 puis octets }
        Len := ReadU2;
        CP^[I].StrVal := '';
        For J := 1 to Len Do Begin
          B := ReadU1;
          If Length(CP^[I].StrVal) < 255 Then
            CP^[I].StrVal := CP^[I].StrVal + Chr(B);
        End;
      End;
      
      CP_INTEGER: Begin
        { Lire 4 octets big-endian }
        CP^[I].IntVal := ReadU4;
      End;
      
      CP_FLOAT: Begin
        { Lire 4 octets (IEEE 754 single) }
        B1 := ReadU1; B2 := ReadU1; B3 := ReadU1; B4 := ReadU1;
        { Conversion simplifiee - stocke entier pour l'instant }
        CP^[I].IntVal := (LongInt(B1) shl 24) or (LongInt(B2) shl 16) or
                         (LongInt(B3) shl 8) or LongInt(B4);
        CP^[I].FloatVal := 0; { TODO: conversion IEEE 754 }
      End;
      
      CP_LONG: Begin
        { Lire 8 octets, occupe 2 slots }
        HiInt := ReadU4;
        LoInt := ReadU4;
        CP^[I].IntVal := LoInt; { Partie basse }
        CP^[I].FloatVal := HiInt; { Partie haute dans FloatVal }
        CP^[I].IsDouble := True;
        { Slot suivant non utilise }
        Inc(I);
        If I < Count Then Begin
          CP^[I].Tag := CP_NONE;
          CP^[I].StrVal := '';
          CP^[I].IntVal := 0;
          CP^[I].FloatVal := 0;
          CP^[I].Ref1 := 0;
          CP^[I].Ref2 := 0;
          CP^[I].IsDouble := False;
        End;
      End;
      
      CP_DOUBLE: Begin
        { Lire 8 octets (IEEE 754 double), occupe 2 slots }
        HiInt := ReadU4;
        LoInt := ReadU4;
        CP^[I].IntVal := LoInt;
        CP^[I].FloatVal := HiInt;
        CP^[I].IsDouble := True;
        { Slot suivant non utilise }
        Inc(I);
        If I < Count Then Begin
          CP^[I].Tag := CP_NONE;
          CP^[I].StrVal := '';
          CP^[I].IntVal := 0;
          CP^[I].FloatVal := 0;
          CP^[I].Ref1 := 0;
          CP^[I].Ref2 := 0;
          CP^[I].IsDouble := False;
        End;
      End;
      
      CP_CLASS, CP_STRING, CP_METHODTYPE: Begin
        { Lire 1 index U2 }
        CP^[I].Ref1 := ReadU2;
      End;
      
      CP_FIELDREF, CP_METHODREF, CP_INTERFACEMETHODREF, CP_NAMEANDTYPE: Begin
        { Lire 2 index U2 }
        CP^[I].Ref1 := ReadU2;
        CP^[I].Ref2 := ReadU2;
      End;
      
      CP_METHODHANDLE: Begin
        { Lire 1 octet (kind) + 1 index U2 }
        CP^[I].IntVal := ReadU1; { reference_kind }
        CP^[I].Ref1 := ReadU2;   { reference_index }
      End;
      
      CP_INVOKEDYNAMIC: Begin
        { Lire 2 index U2 (bootstrap_method_attr_index + name_and_type_index) }
        CP^[I].Ref1 := ReadU2;
        CP^[I].Ref2 := ReadU2;
      End;
      
      Else Begin
        Error('Tag Constant Pool inconnu: ' + IntToStr_(Tag) + ' a l''index ' + IntToStr_(I));
      End;
    End;
    
    Inc(I);
  End;
  
  Info('Constant Pool lu: ' + IntToStr_(Count - 1) + ' entrees');
End;

{ --- CPGetUtf8 : retourner la valeur Utf8 d'une entree --- }
Function CPGetUtf8(Idx: Word): String;
Begin
  If (Idx = 0) or (Idx >= CPCount) Then Begin
    Error('Index Constant Pool hors bornes: ' + IntToStr_(Idx));
    CPGetUtf8 := '';
    Exit;
  End;
  If CP^[Idx].Tag <> CP_UTF8 Then Begin
    Error('Entree CP #' + IntToStr_(Idx) + ' n''est pas UTF8 (tag=' + 
          IntToStr_(CP^[Idx].Tag) + ')');
    CPGetUtf8 := '';
    Exit;
  End;
  CPGetUtf8 := CP^[Idx].StrVal;
End;

{ --- CPGetClassName : resoudre CP_CLASS -> nom de classe --- }
Function CPGetClassName(Idx: Word): String;
Begin
  If (Idx = 0) or (Idx >= CPCount) Then Begin
    Error('Index Constant Pool hors bornes: ' + IntToStr_(Idx));
    CPGetClassName := '';
    Exit;
  End;
  If CP^[Idx].Tag <> CP_CLASS Then Begin
    Error('Entree CP #' + IntToStr_(Idx) + ' n''est pas CLASS (tag=' +
          IntToStr_(CP^[Idx].Tag) + ')');
    CPGetClassName := '';
    Exit;
  End;
  CPGetClassName := CPGetUtf8(CP^[Idx].Ref1);
End;

{ --- CPGetNameAndType : resoudre CP_NAMEANDTYPE -> name, descriptor --- }
Procedure CPGetNameAndType(Idx: Word; Var Name, Desc: String);
Begin
  Name := '';
  Desc := '';
  If (Idx = 0) or (Idx >= CPCount) Then Begin
    Error('Index Constant Pool hors bornes: ' + IntToStr_(Idx));
    Exit;
  End;
  If CP^[Idx].Tag <> CP_NAMEANDTYPE Then Begin
    Error('Entree CP #' + IntToStr_(Idx) + ' n''est pas NAMEANDTYPE (tag=' +
          IntToStr_(CP^[Idx].Tag) + ')');
    Exit;
  End;
  Name := CPGetUtf8(CP^[Idx].Ref1);
  Desc := CPGetUtf8(CP^[Idx].Ref2);
End;

{ --- CPGetMemberRef : resoudre FIELDREF/METHODREF/INTERFACEMETHODREF --- }
Procedure CPGetMemberRef(Idx: Word; Var ClassName, Name, Desc: String);
Var
  NTIdx: Word;
Begin
  ClassName := '';
  Name := '';
  Desc := '';
  If (Idx = 0) or (Idx >= CPCount) Then Begin
    Error('Index Constant Pool hors bornes: ' + IntToStr_(Idx));
    Exit;
  End;
  If Not (CP^[Idx].Tag in [CP_FIELDREF, CP_METHODREF, CP_INTERFACEMETHODREF]) Then Begin
    Error('Entree CP #' + IntToStr_(Idx) + ' n''est pas une reference membre (tag=' +
          IntToStr_(CP^[Idx].Tag) + ')');
    Exit;
  End;
  ClassName := CPGetClassName(CP^[Idx].Ref1);
  NTIdx := CP^[Idx].Ref2;
  CPGetNameAndType(NTIdx, Name, Desc);
End;

{ --- CPGetString : resoudre CP_STRING -> valeur chaine --- }
Function CPGetString(Idx: Word): String;
Begin
  If (Idx = 0) or (Idx >= CPCount) Then Begin
    Error('Index Constant Pool hors bornes: ' + IntToStr_(Idx));
    CPGetString := '';
    Exit;
  End;
  If CP^[Idx].Tag <> CP_STRING Then Begin
    Error('Entree CP #' + IntToStr_(Idx) + ' n''est pas STRING (tag=' +
          IntToStr_(CP^[Idx].Tag) + ')');
    CPGetString := '';
    Exit;
  End;
  CPGetString := CPGetUtf8(CP^[Idx].Ref1);
End;

{ --- CPGetInteger : retourner la valeur entiere d'une entree --- }
Function CPGetInteger(Idx: Word): LongInt;
Begin
  If (Idx = 0) or (Idx >= CPCount) Then Begin
    Error('Index Constant Pool hors bornes: ' + IntToStr_(Idx));
    CPGetInteger := 0;
    Exit;
  End;
  If CP^[Idx].Tag <> CP_INTEGER Then Begin
    Error('Entree CP #' + IntToStr_(Idx) + ' n''est pas INTEGER (tag=' +
          IntToStr_(CP^[Idx].Tag) + ')');
    CPGetInteger := 0;
    Exit;
  End;
  CPGetInteger := CP^[Idx].IntVal;
End;

{ --- CPTagName : retourner le nom textuel d'un tag CP --- }
Function CPTagName(Tag: Byte): String;
Begin
  Case Tag of
    CP_NONE:              CPTagName := 'NONE';
    CP_UTF8:              CPTagName := 'Utf8';
    CP_INTEGER:           CPTagName := 'Integer';
    CP_FLOAT:             CPTagName := 'Float';
    CP_LONG:              CPTagName := 'Long';
    CP_DOUBLE:            CPTagName := 'Double';
    CP_CLASS:             CPTagName := 'Class';
    CP_STRING:            CPTagName := 'String';
    CP_FIELDREF:          CPTagName := 'Fieldref';
    CP_METHODREF:         CPTagName := 'Methodref';
    CP_INTERFACEMETHODREF:CPTagName := 'InterfaceMethodref';
    CP_NAMEANDTYPE:       CPTagName := 'NameAndType';
    CP_METHODHANDLE:      CPTagName := 'MethodHandle';
    CP_METHODTYPE:        CPTagName := 'MethodType';
    CP_INVOKEDYNAMIC:     CPTagName := 'InvokeDynamic';
  Else
    CPTagName := 'Unknown(' + IntToStr_(Tag) + ')';
  End;
End;

{ --- DumpConstantPool : afficher le Constant Pool (debug) --- }
Procedure DumpConstantPool;
Var
  I: Word;
  S: String;
Begin
  WriteLn('=== Constant Pool (', CPCount - 1, ' entrees) ===');
  For I := 1 to CPCount - 1 Do Begin
    If CP^[I].Tag <> CP_NONE Then Begin
      Write('#', I:4, ' ', CPTagName(CP^[I].Tag):20);
      Case CP^[I].Tag of
        CP_UTF8:    Write(' "', Copy(CP^[I].StrVal, 1, 40), '"');
        CP_INTEGER: Write(' ', CP^[I].IntVal);
        CP_FLOAT:   Write(' (float)');
        CP_LONG:    Write(' (long)');
        CP_DOUBLE:  Write(' (double)');
        CP_CLASS, CP_STRING, CP_METHODTYPE:
                    Write(' -> #', CP^[I].Ref1);
        CP_FIELDREF, CP_METHODREF, CP_INTERFACEMETHODREF, CP_NAMEANDTYPE:
                    Write(' -> #', CP^[I].Ref1, '.#', CP^[I].Ref2);
        CP_METHODHANDLE:
                    Write(' kind=', CP^[I].IntVal, ' -> #', CP^[I].Ref1);
        CP_INVOKEDYNAMIC:
                    Write(' -> #', CP^[I].Ref1, '.#', CP^[I].Ref2);
      End;
      WriteLn;
    End;
  End;
End;

{ ============================================================================ }
{ TODO 04 [IMPLEMENTE] - Lecture des flags, this_class, super_class, interfaces }
{ ============================================================================ }

{ --- GetSimpleClassName : extraire le nom simple depuis le nom interne --- }
{ Ex.: "java/lang/RuntimeException" -> "RuntimeException"                   }
Function GetSimpleClassName(InternalName: String): String;
Var
  I: Integer;
Begin
  { Chercher le dernier / }
  For I := Length(InternalName) DownTo 1 Do Begin
    If InternalName[I] = '/' Then Begin
      GetSimpleClassName := Copy(InternalName, I + 1, Length(InternalName) - I);
      Exit;
    End;
  End;
  { Pas de / : nom deja simple }
  GetSimpleClassName := InternalName;
End;

{ --- GetPackageName : extraire le paquetage depuis le nom interne --- }
{ Ex.: "com/example/Foo" -> "com.example"                                }
Function GetPackageName(InternalName: String): String;
Var
  I: Integer;
  Pkg: String;
Begin
  Pkg := '';
  { Chercher le dernier / }
  For I := Length(InternalName) DownTo 1 Do Begin
    If InternalName[I] = '/' Then Begin
      Pkg := Copy(InternalName, 1, I - 1);
      Break;
    End;
  End;
  { Convertir / en . }
  For I := 1 to Length(Pkg) Do
    If Pkg[I] = '/' Then Pkg[I] := '.';
  GetPackageName := Pkg;
End;

{ --- InternalToJavaName : convertir nom interne en nom Java --- }
{ Ex.: "java/lang/String" -> "java.lang.String"                   }
Function InternalToJavaName(InternalName: String): String;
Var
  I: Integer;
  S: String;
Begin
  S := InternalName;
  For I := 1 to Length(S) Do
    If S[I] = '/' Then S[I] := '.';
  InternalToJavaName := S;
End;

{ --- InitClassInfo : initialiser la structure ClassInfo --- }
Procedure InitClassInfo;
Var
  I: Integer;
Begin
  ClassInfo.AccessFlags := 0;
  ClassInfo.ThisClass := '';
  ClassInfo.SuperClass := '';
  ClassInfo.InterfaceCount := 0;
  For I := 0 to MAX_INTERFACES - 1 Do
    ClassInfo.Interfaces[I] := '';
  ClassInfo.IsInterface := False;
  ClassInfo.IsAbstract := False;
  ClassInfo.IsEnum := False;
  ClassInfo.IsAnnotation := False;
  ClassInfo.IsFinal := False;
  ClassInfo.IsPublic := False;
  ClassInfo.IsSynthetic := False;
  ClassInfo.SourceFile := '';
End;

{ --- ReadClassInfo : lire les informations de la classe apres le CP --- }
Procedure ReadClassInfo;
Var
  Flags, ThisIdx, SuperIdx, IfCount, IfIdx: Word;
  I: Integer;
Begin
  InitClassInfo;
  
  { Lire AccessFlags (U2) }
  Flags := ReadU2;
  ClassInfo.AccessFlags := Flags;
  
  { Decoder les flags d'acces }
  ClassInfo.IsPublic := (Flags and ACC_PUBLIC) <> 0;
  ClassInfo.IsFinal := (Flags and ACC_FINAL) <> 0;
  ClassInfo.IsInterface := (Flags and ACC_INTERFACE) <> 0;
  ClassInfo.IsAbstract := (Flags and ACC_ABSTRACT) <> 0;
  ClassInfo.IsSynthetic := (Flags and ACC_SYNTHETIC) <> 0;
  ClassInfo.IsAnnotation := (Flags and ACC_ANNOTATION) <> 0;
  ClassInfo.IsEnum := (Flags and ACC_ENUM) <> 0;
  
  { Lire this_class (U2) -> index CP_CLASS }
  ThisIdx := ReadU2;
  If ThisIdx > 0 Then
    ClassInfo.ThisClass := CPGetClassName(ThisIdx)
  Else
    ClassInfo.ThisClass := '';
    
  { Lire super_class (U2) -> index CP_CLASS (0 pour java/lang/Object) }
  SuperIdx := ReadU2;
  If SuperIdx > 0 Then
    ClassInfo.SuperClass := CPGetClassName(SuperIdx)
  Else
    ClassInfo.SuperClass := '';
    
  { Lire interfaces_count (U2) }
  IfCount := ReadU2;
  ClassInfo.InterfaceCount := IfCount;
  
  { Lire chaque interface (U2 -> index CP_CLASS) }
  For I := 0 to IfCount - 1 Do Begin
    If I < MAX_INTERFACES Then Begin
      IfIdx := ReadU2;
      If IfIdx > 0 Then
        ClassInfo.Interfaces[I] := CPGetClassName(IfIdx)
      Else
        ClassInfo.Interfaces[I] := '';
    End Else Begin
      { Trop d'interfaces, lire mais ignorer }
      IfIdx := ReadU2;
    End;
  End;
  
  If Opts.Verbose Then Begin
    Info('Classe: ' + ClassInfo.ThisClass);
    If ClassInfo.SuperClass <> '' Then
      Info('Super: ' + ClassInfo.SuperClass);
    If ClassInfo.InterfaceCount > 0 Then
      Info('Interfaces: ' + IntToStr_(ClassInfo.InterfaceCount));
  End;
End;

{ --- SkipAttribute : sauter un attribut de taille donnee --- }
Procedure SkipAttribute(AttrLen: LongInt);
Var
  I: LongInt;
  B: Byte;
Begin
  For I := 1 to AttrLen Do
    B := ReadU1;
End;

{ --- ReadAttributesClass : lire les attributs de la classe --- }
Procedure ReadAttributesClass(AttrCount: Word);
Var
  I: Word;
  NameIdx: Word;
  AttrLen: LongInt;
  AttrName: String;
  SrcIdx: Word;
Begin
  For I := 1 to AttrCount Do Begin
    { Lire attribute_name_index (U2) et attribute_length (U4) }
    NameIdx := ReadU2;
    AttrLen := ReadU4;
    
    { Recuperer le nom de l'attribut }
    AttrName := CPGetUtf8(NameIdx);
    
    If AttrName = 'SourceFile' Then Begin
      { SourceFile: 2 octets = index UTF8 du nom de fichier }
      SrcIdx := ReadU2;
      ClassInfo.SourceFile := CPGetUtf8(SrcIdx);
      If Opts.Verbose Then
        Info('Source: ' + ClassInfo.SourceFile);
    End
    Else Begin
      { Attribut non gere, sauter les donnees }
      SkipAttribute(AttrLen);
    End;
  End;
End;

{ --- DumpClassInfo : afficher les informations de la classe (debug) --- }
Procedure DumpClassInfo;
Var
  I: Integer;
  FlagStr: String;
Begin
  WriteLn('=== Class Info ===');
  
  { Construire la chaine des flags }
  FlagStr := '';
  If ClassInfo.IsPublic Then FlagStr := FlagStr + 'public ';
  If ClassInfo.IsFinal Then FlagStr := FlagStr + 'final ';
  If ClassInfo.IsAbstract Then FlagStr := FlagStr + 'abstract ';
  If ClassInfo.IsInterface Then FlagStr := FlagStr + 'interface ';
  If ClassInfo.IsEnum Then FlagStr := FlagStr + 'enum ';
  If ClassInfo.IsAnnotation Then FlagStr := FlagStr + '@interface ';
  If ClassInfo.IsSynthetic Then FlagStr := FlagStr + 'synthetic ';
  
  WriteLn('Flags: ', FlagStr, '($', HexWord(ClassInfo.AccessFlags), ')');
  WriteLn('This:  ', ClassInfo.ThisClass);
  WriteLn('       ', InternalToJavaName(ClassInfo.ThisClass));
  WriteLn('Super: ', ClassInfo.SuperClass);
  
  If ClassInfo.InterfaceCount > 0 Then Begin
    WriteLn('Interfaces (', ClassInfo.InterfaceCount, '):');
    For I := 0 to ClassInfo.InterfaceCount - 1 Do
      WriteLn('  ', I + 1, '. ', ClassInfo.Interfaces[I]);
  End;
  
  If ClassInfo.SourceFile <> '' Then
    WriteLn('Source: ', ClassInfo.SourceFile);
End;

{ ============================================================================ }
{ TODO 05 [A FAIRE] - Lecture des champs (fields) de la classe                 }
{ ============================================================================ }
{                                                                              }
{  - Structure TFieldInfo :                                                      }
{      AccessFlags  : Word    (flags d'acces du champ)                          }
{      Name         : String  (nom du champ)                                    }
{      Descriptor   : String  (descripteur de type JVM, ex. I, Ljava/lang/X;)  }
{      IsSynthetic  : Boolean (ACC_SYNTHETIC set)                               }
{      IsStatic     : Boolean (ACC_STATIC set)                                  }
{      IsFinal      : Boolean (ACC_FINAL set)                                   }
{      IsVolatile   : Boolean (ACC_VOLATILE set)                                }
{      IsTransient  : Boolean (ACC_TRANSIENT set)                               }
{      IsEnum       : Boolean (ACC_ENUM set)                                    }
{      ConstValue   : String  (valeur constante si attribut ConstantValue)      }
{      HasConstValue: Boolean (attribut ConstantValue present)                  }
{      LineNumber   : Integer (ligne source si disponible)                      }
{                                                                              }
{  - Procedure ReadFields(Count: Word)                                          }
{      Pour chaque champ, lire AccessFlags, Name (U2->CP), Descriptor (U2->CP) }
{      Decoder les flags ACC_*                                                  }
{      Lire les attributs du champ :                                            }
{        ConstantValue : lire index U2 -> valeur dans le CP                     }
{        Deprecated : marquer le champ comme obsolete                           }
{        Signature : signature generique du champ                               }
{        Synthetic : champ genere par le compilateur                            }
{      Stocker dans la table globale Fields[]                                   }
{                                                                              }
{  - Function DecodeTypeDescriptor(Desc: String): String                        }
{      Traduire un descripteur JVM en type Java lisible                         }
{      V -> void, I -> int, J -> long, D -> double, F -> float                  }
{      B -> byte, C -> char, S -> short, Z -> boolean                           }
{      L<nom>; -> nom Java, [X -> X[], [[X -> X[][]                             }

{ ============================================================================ }
{ TODO 06 [A FAIRE] - Lecture des methodes et de l'attribut Code               }
{ ============================================================================ }
{                                                                              }
{  - Structure TExceptionEntry :                                                 }
{      StartPC   : Word  (debut de la zone protegee)                            }
{      EndPC     : Word  (fin de la zone protegee)                              }
{      HandlerPC : Word  (debut du gestionnaire d'exception)                    }
{      CatchType : Word  (index CP vers la classe catchee, 0 = finally)         }
{                                                                              }
{  - Structure TMethodInfo :                                                     }
{      AccessFlags   : Word                    (flags d'acces)                  }
{      Name          : String                  (nom de la methode)              }
{      Descriptor    : String                  (descripteur de methode)         }
{      MaxStack      : Word                    (profondeur max de pile)         }
{      MaxLocals     : Word                    (nb variables locales max)       }
{      CodeLen       : LongWord                (taille du bytecode en octets)   }
{      Code          : Pointer                 (tampon du bytecode)             }
{      ExcCount      : Word                    (nb entrees exception_table)     }
{      ExcTable      : array[TExceptionEntry]  (table des exceptions)           }
{      LineCount     : Word                    (nb entrees LineNumberTable)     }
{      LineTable     : array of (StartPC, Line) (correspondance PC->ligne)      }
{      LocalCount    : Word                    (nb entrees LocalVariableTable)  }
{      LocalTable    : array of (Start,Length,Name,Desc,Index)                  }
{      IsNative      : Boolean                 (methode native)                 }
{      IsAbstract    : Boolean                 (methode abstraite)              }
{      IsBridge      : Boolean                 (methode pont generique)         }
{      IsSynthetic   : Boolean                 (methode generee)                }
{      IsVarArgs     : Boolean                 (methode variadique)             }
{                                                                              }
{  - Procedure ReadMethods(Count: Word)                                         }
{      Pour chaque methode, lire AccessFlags, Name (U2->CP), Desc (U2->CP)     }
{      Lire les attributs de la methode :                                       }
{        Code : lire MaxStack, MaxLocals, CodeLen, bytecode, exception_table,   }
{               puis sous-attributs LineNumberTable et LocalVariableTable       }
{        Exceptions : lire la liste des exceptions declarees (throws)           }
{        Deprecated, Synthetic, Signature, Bridge, VarArgs                      }
{      Stocker dans la table globale Methods[]                                  }
{                                                                              }
{  - Function GetLineNumber(Method: TMethodInfo; PC: Word): Integer             }
{      Rechercher dans LineTable l'entree la plus proche pour le PC donne       }
{      Retourner -1 si LineNumberTable absente                                  }
{                                                                              }
{  - Function ParseMethodDescriptor(Desc: String;                               }
{      Var ParamTypes: TStringArray; Var RetType: String)                       }
{      Analyser le descripteur de methode JVM                                   }
{      Ex.: (ILjava/lang/String;)V -> params=[int,String], ret=void             }

{ ============================================================================ }
{ TODO 07 [A FAIRE] - Decodage du bytecode Java (opcodes JVM)                  }
{ ============================================================================ }
{                                                                              }
{  - Constantes d'opcodes JVM (selection) :                                     }
{      OP_NOP=0, OP_ACONST_NULL=1, OP_ICONST_M1=2, OP_ICONST_0=3              }
{      OP_ILOAD=21, OP_LLOAD=22, OP_FLOAD=23, OP_DLOAD=24, OP_ALOAD=25        }
{      OP_ISTORE=54, OP_LSTORE=55, OP_FSTORE=56, OP_DSTORE=57, OP_ASTORE=58   }
{      OP_IADD=96, OP_LADD=97, OP_FADD=98, OP_DADD=99                         }
{      OP_IRETURN=172, OP_LRETURN=173, OP_FRETURN=174                          }
{      OP_DRETURN=175, OP_ARETURN=176, OP_RETURN=177                           }
{      OP_GETFIELD=180, OP_PUTFIELD=181, OP_GETSTATIC=178, OP_PUTSTATIC=179   }
{      OP_INVOKEVIRTUAL=182, OP_INVOKESPECIAL=183, OP_INVOKESTATIC=184         }
{      OP_INVOKEINTERFACE=185, OP_INVOKEDYNAMIC=186                            }
{      OP_NEW=187, OP_NEWARRAY=188, OP_ANEWARRAY=189                           }
{      OP_ATHROW=191, OP_CHECKCAST=192, OP_INSTANCEOF=193                      }
{      OP_IFNULL=198, OP_IFNONNULL=199                                         }
{      OP_IFEQ=153, OP_IFNE=154, OP_IFLT=155, OP_IFGE=156, OP_IFGT=157        }
{      OP_IFLE=158, OP_IF_ICMPEQ=159 .. OP_IF_ACMPNE=166                      }
{      OP_GOTO=167, OP_GOTO_W=200, OP_JSR=168, OP_RET=169                     }
{      OP_TABLESWITCH=170, OP_LOOKUPSWITCH=171                                 }
{      OP_WIDE=196, OP_MULTIANEWARRAY=197                                      }
{                                                                              }
{  - Structure TInstruction :                                                    }
{      PC       : LongWord  (position dans le bytecode)                         }
{      Opcode   : Byte      (code operation)                                    }
{      Mnemonic : String    (mnemonique lisible)                                 }
{      Op1      : LongInt   (premier operande)                                  }
{      Op2      : LongInt   (second operande)                                   }
{      Op3      : LongInt   (troisieme operande, pour invokeinterface)          }
{      Size     : Integer   (taille totale de l'instruction en octets)          }
{      CpRef    : String    (reference CP resolue, ex. nom de methode)          }
{      LineNum  : Integer   (numero de ligne source)                            }
{                                                                              }
{  - Procedure DecodeInstructions(Method: TMethodInfo)                          }
{      Parcourir le bytecode de la methode instruction par instruction          }
{      Pour chaque opcode, determiner le nombre et la taille des operandes      }
{      Gerer les cas speciaux : wide, tableswitch, lookupswitch, padding        }
{      Resoudre les references CP via CPGetMemberRef / CPGetClassName            }
{      Stocker la suite d'instructions decodees dans Method.Instructions[]      }
{                                                                              }
{  - Function GetInstrMnemonic(Op: Byte): String                                }
{      Retourner le mnemonique textuel de l'opcode donne                        }
{                                                                              }
{  - Function GetInstrSize(Op: Byte; PC: LongWord; Code: Pointer): Integer      }
{      Calculer la taille de l'instruction a la position PC                     }
{      Tenir compte des alignements tableswitch/lookupswitch et du prefix wide  }

{ ============================================================================ }
{ TODO 08 [A FAIRE] - Construction du graphe de flux de controle (CFG)         }
{ ============================================================================ }
{                                                                              }
{  - Structure TCFGNode :                                                        }
{      ID         : Integer          (identifiant unique du noeud)              }
{      StartPC    : LongWord         (premier PC du bloc de base)               }
{      EndPC      : LongWord         (dernier PC du bloc de base)               }
{      InstStart  : Integer          (index premiere instruction)                }
{      InstEnd    : Integer          (index derniere instruction)                }
{      Succs      : array[0..3] of Integer  (indices des noeuds successeurs)    }
{      SuccCount  : Integer          (nombre de successeurs)                    }
{      Preds      : array[0..15] of Integer (indices des noeuds predecesseurs)  }
{      PredCount  : Integer          (nombre de predecesseurs)                  }
{      IsEntry    : Boolean          (noeud d'entree de la methode)             }
{      IsExit     : Boolean          (noeud de sortie - instruction return)     }
{      IsException: Boolean          (noeud gestionnaire d'exception)           }
{      Visited    : Boolean          (pour les parcours DFS/BFS)                }
{      DomBy      : Integer          (dominateur immediat dans l'arbre dom.)    }
{                                                                              }
{  - Procedure BuildCFG(Method: TMethodInfo)                                    }
{      Identifier les entetes de blocs de base :                                }
{        - instruction en PC=0 (entree de methode)                              }
{        - cibles de tous les branchements (goto, ifeq, jsr, etc.)              }
{        - instructions suivant un branchement inconditionnel                   }
{        - debut de chaque gestionnaire d'exception (exception_table)           }
{      Creer un TCFGNode par bloc de base                                        }
{      Lier les noeuds selon les successeurs determines par les branchements     }
{      Calculer les predecesseurs (liste inverse des successeurs)                }
{                                                                              }
{  - Procedure ComputeDominators(Var Nodes: array of TCFGNode)                  }
{      Calculer l'arbre des dominateurs (algorithme iteratif de Lengauer-Tarjan}
{      simplifie) pour detecter les boucles et code mort                        }
{                                                                              }
{  - Procedure FindUnreachableBlocks(Var Nodes: array of TCFGNode)              }
{      Parcourir en DFS depuis le noeud d'entree                                }
{      Identifier les blocs non atteints (Visited=False apres le parcours)      }
{      Ces blocs correspondent a du code mort (potentiellement suspect)         }
{                                                                              }
{  - Procedure FindBackEdges(Var Nodes: array of TCFGNode)                      }
{      Identifier les aretes arriere dans le CFG (donnent les boucles)          }
{      Une arete arriere va d'un noeud vers un de ses ancetres dans l'arbre DFS }

{ ============================================================================ }
{ TODO 09 [A FAIRE] - Detecteur : dereferencement de pointeur null             }
{ ============================================================================ }
{                                                                              }
{  - Codes de bugs detectes :                                                    }
{      NP_NULL_ON_SOME_PATH         : null deref sur chemin conditionnel        }
{      NP_NULL_ON_SOME_PATH_EXCEPTION : null deref possible via exception       }
{      NP_ALWAYS_NULL               : dereference toujours null                 }
{      NP_NULL_DEREF_ALL_TARGETS     : tous les chemins menent a un null deref  }
{      NP_STORE_INTO_NONNULL_FIELD   : stockage null dans champ non-null        }
{      NP_GUARANTEED_DEREF           : deref garanti null                       }
{                                                                              }
{  - Analyse de valeurs abstraites pour la pile JVM :                           }
{      VAL_UNKNOWN = 0   (valeur inconnue)                                      }
{      VAL_NULL    = 1   (reference nulle certaine)                             }
{      VAL_NONNULL = 2   (reference non-null certaine)                          }
{      VAL_MAYBE   = 3   (null possible selon le chemin)                        }
{                                                                              }
{  - Procedure DetectNullDereferences(Method: TMethodInfo)                      }
{      Simuler l'execution symbolique de la pile JVM :                          }
{        - aconst_null => empiler VAL_NULL                                      }
{        - new, newarray, this => empiler VAL_NONNULL                           }
{        - invokevirtual/invokespecial/invokeinterface sur ref :                }
{          si ref = VAL_NULL -> bug NP_ALWAYS_NULL                              }
{          si ref = VAL_MAYBE -> bug NP_NULL_ON_SOME_PATH                       }
{        - getfield/putfield sur ref null : meme detection                      }
{        - arraylength, athrow sur ref null : meme detection                    }
{        - Propagation inter-blocs avec merge des etats (VAL_NULL ^ VAL_NONNULL }
{          = VAL_MAYBE) via le CFG construit au TODO 08                         }
{      Appeler AddBug pour chaque occurrence detectee                           }
{                                                                              }
{  - Function IsNullCheckOpcode(Op: Byte): Boolean                              }
{      Retourner True si l'opcode est ifnull, ifnonnull, if_acmpeq, if_acmpne  }
{      (ces opcodes testent explicitement la nullite)                           }

{ ============================================================================ }
{ TODO 10 [A FAIRE] - Detecteur : fuite de ressources (resource leaks)         }
{ ============================================================================ }
{                                                                              }
{  - Codes de bugs detectes :                                                    }
{      OBJ_UNSATISFIED_OBLIGATION    : ressource potentiellement non fermee     }
{      OBJ_UNSATISFIED_OBLIGATION_EXCEPTION : ressource non fermee sur exception}
{      OS_OPEN_STREAM                : flux non ferme                           }
{      OS_OPEN_STREAM_EXCEPTION_PATH : flux non ferme sur chemin d'exception    }
{                                                                              }
{  - Classes Java considerees comme ressources (fermeables) :                   }
{      java/io/InputStream, java/io/OutputStream, java/io/Reader,              }
{      java/io/Writer, java/sql/Connection, java/sql/Statement,                }
{      java/sql/ResultSet, java/net/Socket, java/net/ServerSocket              }
{                                                                              }
{  - Procedure DetectResourceLeaks(Method: TMethodInfo)                         }
{      Identifier les invocations new + constructeur des classes ressources     }
{      Verifier que chaque ressource ouverte est fermee (appel .close())        }
{      sur tous les chemins d'execution (y compris les chemins d'exception)     }
{      Detecter les blocs try/finally absents pour les ressources               }
{      Detecter la creation de ressource dans un bloc try sans finally          }
{      Tenir compte des instructions athrow et des gestionnaires d'exception    }
{      depuis l'exception_table de la methode                                   }
{                                                                              }
{  - Function IsCloseableClass(ClassName: String): Boolean                      }
{      Retourner True si le nom de classe correspond a un type ferme-able       }
{      Verifier aussi la hierarchie (sous-classes de Closeable/AutoCloseable)   }
{                                                                              }
{  - Function FindCloseCall(Method: TMethodInfo; VarIdx: Integer;               }
{      StartPC, EndPC: LongWord): Boolean                                       }
{      Rechercher un appel .close() sur la variable locale d'index VarIdx       }
{      entre StartPC et EndPC dans le bytecode                                  }

{ ============================================================================ }
{ TODO 11 [A FAIRE] - Detecteur : boucles infinies et blocs inaccessibles      }
{ ============================================================================ }
{                                                                              }
{  - Codes de bugs detectes :                                                    }
{      IL_INFINITE_LOOP          : boucle infinie sans condition d'arret        }
{      IL_INFINITE_RECURSIVE_LOOP : appel recursif infini sans condition        }
{      DLS_DEAD_LOCAL_STORE       : ecriture dans une variable non relue apres  }
{      UC_USELESS_VOID_METHOD     : methode qui ne fait rien d'utile            }
{      USELESS_CODE               : code inaccessible (unreachable code)        }
{                                                                              }
{  - Procedure DetectInfiniteLoops(Method: TMethodInfo)                         }
{      Pour chaque arete arriere identifiee au TODO 08 :                        }
{        Analyser les blocs composant la boucle                                 }
{        Si la boucle ne contient aucune instruction de branchement vers        }
{        l'exterieur (goto, return, athrow, break) => bug IL_INFINITE_LOOP      }
{        Si la boucle ne lit aucune variable modifiee par une entree externe    }
{        => probablement une boucle infinie                                     }
{                                                                              }
{  - Procedure DetectInfiniteRecursion(Method: TMethodInfo)                     }
{      Rechercher les appels recursifs a la methode elle-meme                   }
{      Si tous les chemins menent a un appel recursif sans condition d'arret    }
{      => bug IL_INFINITE_RECURSIVE_LOOP                                        }
{                                                                              }
{  - Procedure DetectDeadCode(Method: TMethodInfo)                              }
{      Apres la construction du CFG, identifier les blocs non-atteints          }
{      Signaler chaque bloc mort avec le numero de ligne de la premiere          }
{      instruction du bloc (via LineNumberTable)                                 }
{                                                                              }
{  - Procedure DetectDeadLocalStores(Method: TMethodInfo)                       }
{      Construire l'information de vivacite (liveness) des variables locales    }
{      Detecter les stores (istore, astore, etc.) dont la valeur n'est jamais   }
{      relue => bug DLS_DEAD_LOCAL_STORE                                        }

{ ============================================================================ }
{ TODO 12 [A FAIRE] - Detecteur : mauvaises pratiques (bad practices)          }
{ ============================================================================ }
{                                                                              }
{  - Codes de bugs detectes :                                                    }
{      BC_UNCONFIRMED_CAST    : cast sans verification instanceof prealable     }
{      CN_IMPLEMENTS_CLONE_BUT_NOT_CLONEABLE : clone() sans Cloneable          }
{      DE_MIGHT_IGNORE        : exception capturee et ignoree (catch vide)      }
{      EQ_DOESNT_OVERRIDE_EQUALS : sous-classe avec champs mais sans equals()  }
{      FI_PUBLIC_SHOULD_BE_PROTECTED : finalize() public au lieu de protected  }
{      HE_HASHCODE_USE_OBJECT_EQUALS : hashCode() sans equals() ou inversement }
{      RR_NOT_CHECKED          : valeur de retour de read() non verifiee        }
{      SR_NOT_CHECKED          : valeur de retour de skip() non verifiee        }
{                                                                              }
{  - Procedure DetectBadPractices(Method: TMethodInfo)                          }
{      Analyser les invocations de methodes et les instructions checkcast       }
{      Verifier qu'un instanceof precede tout checkcast                         }
{      Detecter les blocs catch avec corps vide (DE_MIGHT_IGNORE)              }
{      Detecter les appels a read()/skip() dont le resultat est pop             }
{                                                                              }
{  - Procedure DetectBadClassPractices(ClassInfo: TClassInfo)                   }
{      Analyser la structure de la classe :                                     }
{        Verifier la coherence equals/hashCode (un seul sans l'autre)           }
{        Verifier que clone() est dans une classe qui implemente Cloneable      }
{        Verifier que finalize() n'est pas public                               }
{        Detecter les sous-classes ajoutant des champs sans redefinir equals()  }

{ ============================================================================ }
{ TODO 13 [A FAIRE] - Detecteur : comparaisons incorrectes d'objets            }
{ ============================================================================ }
{                                                                              }
{  - Codes de bugs detectes :                                                    }
{      EC_UNRELATED_TYPES         : comparaison == entre types sans relation    }
{      ES_COMPARING_STRINGS_WITH_EQ : comparaison String avec == au lieu equals}
{      RC_REF_COMPARISON_BAD_PRACTICE : comparaison == avec wrapper (Integer)  }
{      GC_UNRELATED_TYPES         : appel get/contains avec type incompatible  }
{                                                                              }
{  - Procedure DetectBadComparisons(Method: TMethodInfo)                        }
{      Detecter les instructions if_acmpeq et if_acmpne comparant des strings   }
{      Detecter les comparaisons == appliquees a des types wrapper Java         }
{        (java/lang/Integer, java/lang/Long, java/lang/Double, etc.)           }
{      Analyser les types sur la pile au moment de la comparaison               }
{      Detecter les appels Collection.get(key) avec cle de mauvais type         }
{                                                                              }
{  - Function IsStringType(Desc: String): Boolean                               }
{      Retourner True si le descripteur correspond a java/lang/String           }
{                                                                              }
{  - Function IsWrapperType(ClassName: String): Boolean                         }
{      Retourner True si le nom designe un type wrapper Java                    }
{      (Integer, Long, Short, Byte, Character, Float, Double, Boolean)          }

{ ============================================================================ }
{ TODO 14 [A FAIRE] - Detecteur : problemes de performance                     }
{ ============================================================================ }
{                                                                              }
{  - Codes de bugs detectes :                                                    }
{      SBSC_USE_STRINGBUFFER_CONCATENATION : concat String dans boucle         }
{      DMI_BLOCKING_METHODS_ON_URL : appel methode bloquante sur URL           }
{      ITA_INEFFICIENT_TO_ARRAY    : toArray avec type incorrecte               }
{      URF_UNREAD_FIELD             : champ jamais lu                           }
{      WMI_WRONG_MAP_ITERATOR       : iteration inefficace sur Map              }
{      UPM_UNCALLED_PRIVATE_METHOD  : methode privee jamais appelee             }
{                                                                              }
{  - Procedure DetectPerformanceIssues(Method: TMethodInfo)                     }
{      Detecter les concatenations de String dans les boucles :                 }
{        Chercher les appels String.concat ou StringBuilder.append              }
{        dont la boucle parente (back-edge) n'utilise pas de StringBuilder      }
{      Detecter l'utilisation de entrySet() vs keySet() sur les Map             }
{      Detecter les appels URL.equals() et URL.hashCode() (DNS lookup)          }
{      Detecter toArray(new T[0]) au lieu de toArray(new T[size])               }
{                                                                              }
{  - Procedure DetectUnusedPrivateMembers(ClassInfo, Methods, Fields)           }
{      Calculer l'ensemble des methodes et champs prives                        }
{      Verifier qu'ils sont references dans au moins une methode de la classe   }
{      Signaler ceux qui ne sont jamais utilises                                 }

{ ============================================================================ }
{ TODO 15 [A FAIRE] - Detecteur : vulnerabilites de securite                   }
{ ============================================================================ }
{                                                                              }
{  - Codes de bugs detectes :                                                    }
{      SQL_INJECTION             : construction SQL avec concatenation directe  }
{      XSS_JSP_PRINT             : ecriture dans response sans encodage         }
{      PT_ABSOLUTE_PATH_TRAVERSAL : chemin absolu construit depuis entree user  }
{      HRS_REQUEST_PARAMETER_TO_HTTP_HEADER : injection d'en-tete HTTP          }
{      WEAK_HASH_ALGORITHM       : utilisation de MD5, SHA-1 (casses)           }
{      HARD_CODE_PASSWORD        : mot de passe en dur dans le code             }
{      PREDICTABLE_RANDOM        : utilisation de java.util.Random              }
{      CIPHER_INTEGRITY          : chiffrement sans MAC                         }
{                                                                              }
{  - Procedure DetectSecurityIssues(Method: TMethodInfo)                        }
{      Detecter les appels Statement.execute/executeQuery avec concatenation    }
{      Detecter les appels MessageDigest.getInstance("MD5") ou ("SHA-1")        }
{      Detecter les constantes de chaine ressemblant a des mots de passe        }
{        (nom du champ contient "password", "pwd", "passwd", "secret")         }
{      Detecter new Random() au lieu de SecureRandom                            }
{      Detecter Cipher.getInstance("AES") sans mode d'integrité GCM            }
{      Detecter Runtime.exec() avec argument provenant du reseau               }
{                                                                              }
{  - Function IsSecuritySensitiveName(Name: String): Boolean                    }
{      Retourner True si le nom suggere un secret (password, token, key, etc.) }

{ ============================================================================ }
{ TODO 16 [A FAIRE] - Detecteur : problemes de multi-threading                 }
{ ============================================================================ }
{                                                                              }
{  - Codes de bugs detectes :                                                    }
{      DC_DOUBLECHECK         : double-check locking incorrect                  }
{      ESync_EMPTY_SYNC       : bloc synchronized vide                          }
{      IS_FIELD_NOT_GUARDED    : acces a un champ non protege dans methode sync }
{      IS2_INCONSISTENT_SYNC   : acces inconsistant (parfois sync, parfois non) }
{      JLM_JSR166_LOCK_MONITORENTER : utilisation monitorenter/exit direct      }
{      NN_NAKED_NOTIFY         : notify() sans condition de garde               }
{      NO_NOTIFY_NOT_NOTIFYALL : notify() quand notifyAll() serait preferable   }
{      UG_SYNC_SET_UNSYNC_GET  : setter synchronized mais getter non            }
{      UW_UNCOND_WAIT          : wait() sans boucle de garde                    }
{      WA_AWAIT_NOT_IN_LOOP    : await() sans boucle de garde                   }
{                                                                              }
{  - Procedure DetectConcurrencyIssues(ClassInfo, Methods)                      }
{      Identifier les champs volatiles et synchronized                          }
{      Detecter les acces a des champs non-volatiles dans des methodes          }
{        marquees synchronized sans protection adequate                          }
{      Detecter les doubles tests de null (double-checked locking)              }
{      Detecter les blocs synchronized() vides (corps vide)                     }
{      Detecter les appels wait() hors d'une boucle while                       }
{      Detecter les notify() sans mise a jour d'un etat partage                 }

{ ============================================================================ }
{ TODO 17 [A FAIRE] - Detecteur : exceptions masquees et flux d'erreur         }
{ ============================================================================ }
{                                                                              }
{  - Codes de bugs detectes :                                                    }
{      THROWN_EXCEPTION_IGNORED  : exception capturee et ignoree silencieusement}
{      REC_CATCH_EXCEPTION        : capture de java.lang.Exception trop large  }
{      RCN_REDUNDANT_NULLCHECK_WOULD_HAVE_BEEN_A_NPE : null check apres usage  }
{      FINALLY_NULLIFIES_EXCEPTION : return dans finally masque l'exception     }
{      OVERRIDDEN_EQUALS_NO_SUPER_CALL : equals() ne fait pas super.equals()   }
{                                                                              }
{  - Procedure DetectExceptionHandlingIssues(Method: TMethodInfo)               }
{      Analyser les blocs catch (debut/fin/handler depuis exception_table)      }
{      Detecter les catch(Exception) / catch(Throwable) trop larges             }
{      Detecter les blocs catch dont le corps ne contient que pop + return      }
{        ou pop seul (exception ignoree silencieusement)                        }
{      Detecter les instructions return dans les blocs finally                  }
{        (masque toute exception levee dans le bloc try)                        }
{      Detecter les verifications null apres un dereferencement de la variable  }
{        (l'exception aurait deja ete lancee avant le test)                     }

{ ============================================================================ }
{ TODO 18 [A FAIRE] - Detecteur : erreurs logiques et retours incorrects       }
{ ============================================================================ }
{                                                                              }
{  - Codes de bugs detectes :                                                    }
{      RV_RETURN_VALUE_IGNORED     : valeur de retour ignoree (critique)        }
{      IM_MULTIPLYING_RESULT_OF_IREM : multiplication du resultat de modulo     }
{      INT_BAD_COMPARISON_WITH_NONNEG_VALUE : comparaison < 0 sur valeur >=0   }
{      IC_INIT_CIRCULARITY         : initialisation de constante circulaire      }
{      MF_CLASS_MASKS_FIELD        : variable locale masque un champ de classe  }
{      SA_FIELD_SELF_ASSIGNMENT    : champ assigne a lui-meme                   }
{      SA_LOCAL_SELF_ASSIGNMENT    : variable locale assignee a elle-meme       }
{                                                                              }
{  - Procedure DetectLogicErrors(Method: TMethodInfo)                           }
{      Detecter les self-assignments :                                           }
{        iload x suivi de istore x sans instruction intermediaire               }
{        getfield f suivi de putfield f sur le meme objet                       }
{      Detecter les comparaisons toujours vraies ou toujours fausses :          }
{        valeurs de registres de type int compares avec < 0 quand toujours >=0  }
{      Detecter les multiplications integer pouvant deborder (avant cast long)  }
{      Detecter les variables locales qui masquent des champs d'instance         }

{ ============================================================================ }
{ TODO 19 [A FAIRE] - Detecteur : problemes d'internationalisation             }
{ ============================================================================ }
{                                                                              }
{  - Codes de bugs detectes :                                                    }
{      DM_DEFAULT_ENCODING        : appel String.getBytes() sans charset        }
{      DM_STRING_CTOR             : constructeur new String(String) inutile     }
{      DM_CONVERT_CASE            : toUpperCase()/toLowerCase() sans Locale     }
{      DM_BOXED_PRIMITIVE_FOR_COMPARE : boxing inutile avant comparaison        }
{      DM_FP_NUMBER_CTOR          : new Double(x) au lieu de Double.valueOf(x)  }
{      DM_NUMBER_CTOR             : new Integer(n) au lieu de Integer.valueOf(n)}
{                                                                              }
{  - Procedure DetectI18NIssues(Method: TMethodInfo)                            }
{      Detecter les appels String.getBytes() sans argument (charset manquant)   }
{      Detecter les appels String.toUpperCase()/toLowerCase() sans Locale       }
{      Detecter les appels new String(bytes) sans charset                       }
{      Detecter les constructeurs de types numeriques wrapper au lieu de        }
{        valueOf() pour eviter la creation inutile d'objets                     }
{      Detecter les appels new Integer(n) / new Double(d) etc.                  }
{      Detecter les String.format() sans specification de Locale                }

{ ============================================================================ }
{ TODO 20 [A FAIRE] - Calcul des scores et niveaux de severite                 }
{ ============================================================================ }
{                                                                              }
{  - Formule de score SpotBugs :                                                 }
{      BugRankScore : entier de 1 a 20 (1 = critique, 20 = informatif)         }
{      Priorite     : HIGH (1-4), MEDIUM (5-9), LOW (10-14), INFO (15-20)      }
{                                                                              }
{  - Procedure ComputeBugRank(Var Bug: TBugReport)                              }
{      Calculer le rang du bug selon son type et sa categorie                   }
{      Tenir compte du contexte (methode publique vs privee)                    }
{      Ajuster la priorite selon la confiance de l'analyse                      }
{                                                                              }
{  - Procedure SortBugsByPriority(Var Bugs: array; Count: Integer)              }
{      Trier le tableau de bugs par severite decroissante                       }
{      A priorite egale, trier par categorie puis par classe                    }
{                                                                              }
{  - Procedure ComputeClassScore(ClassName: String; Var Score: Integer)         }
{      Calculer le score global d'une classe (somme ponderee des rangs)         }
{      Normaliser sur une echelle de 0 a 100                                    }
{                                                                              }
{  - Procedure PrintBugStats                                                    }
{      Afficher le nombre de bugs par categorie et par severite                 }
{      Afficher le bilan general (classes, methodes, bugs, erreurs)             }
{      Afficher les classes les plus problematiques                             }

{ ============================================================================ }
{ TODO 21 [A FAIRE] - Generation du rapport texte                              }
{ ============================================================================ }
{                                                                              }
{  - Procedure EmitTextReport(OutFile: String)                                  }
{      Ouvrir le fichier de sortie texte (ou stdout si OutFile='')              }
{      Ecrire l'en-tete avec version de SpotBugs et date d'analyse              }
{      Pour chaque bug trie par priorite :                                       }
{        Afficher la ligne : [PRIORITE] CODE_BUG  Classe.methode(Fichier:Ligne) }
{        Afficher la description lisible du bug                                  }
{      Ecrire le pied de page avec les statistiques globales                     }
{      Fermer le fichier                                                         }
{                                                                              }
{  - Procedure FormatBugLine(Bug: TBugReport): String                           }
{      Produire la ligne de rapport au format court :                            }
{      "[H] NP_NULL_ON_SOME_PATH: com.example.Foo.bar(Foo.java:42)"            }
{                                                                              }
{  - Procedure PrintBugDescription(BugType: String)                             }
{      Afficher la description longue associee au code de bug                    }
{      Utiliser un tableau statique de descriptions pre-enregistrees            }

{ ============================================================================ }
{ TODO 22 [A FAIRE] - Generation du rapport XML (format SpotBugs)              }
{ ============================================================================ }
{                                                                              }
{  - Format XML cible (compatible spotbugs-gui et jenkins-spotbugs-plugin) :    }
{      <?xml version="1.0" encoding="UTF-8"?>                                   }
{      <BugCollection version="4.0.0" sequence="0"                             }
{                     timestamp="..." analysisTimestamp="...">                  }
{        <Project projectName="...">                                            }
{          <SrcDir>src</SrcDir>                                                 }
{          <ClassDir>classes</ClassDir>                                         }
{        </Project>                                                             }
{        <BugInstance type="NP_NULL_ON_SOME_PATH" priority="2" rank="9"        }
{                     abbrev="NP" category="CORRECTNESS">                       }
{          <ShortMessage>...</ShortMessage>                                     }
{          <LongMessage>...</LongMessage>                                       }
{          <Class classname="com.example.Foo" primary="true"/>                  }
{          <Method classname="com.example.Foo" name="bar"                      }
{                  signature="(I)V" isStatic="false" primary="true"/>           }
{          <SourceLine classname="com.example.Foo" start="42" end="42"         }
{                      sourcefile="Foo.java"/>                                  }
{        </BugInstance>                                                         }
{        <FindBugsSummary .../>                                                 }
{        <ClassStats .../>                                                      }
{      </BugCollection>                                                         }
{                                                                              }
{  - Procedure EmitXmlReport(OutFile: String)                                   }
{      Ouvrir le fichier XML                                                    }
{      Ecrire le prologue XML et la balise BugCollection                        }
{      Ecrire la section Project avec les chemins source et classes             }
{      Pour chaque bug, ecrire un element BugInstance avec tous ses attributs   }
{      Ecrire FindBugsSummary (nb bugs par priorite et categorie)               }
{      Ecrire un element ClassStats par classe analysee                         }
{      Fermer les balises et le fichier                                          }
{                                                                              }
{  - Function XmlEscape(S: String): String                                      }
{      Echapper les caracteres speciaux XML (&, <, >, ", ')                     }

{ ============================================================================ }
{ TODO 23 [A FAIRE] - Generation du rapport HTML                               }
{ ============================================================================ }
{                                                                              }
{  - Procedure EmitHtmlReport(OutFile: String)                                  }
{      Generer un rapport HTML autonome avec styles CSS integres                 }
{      Structure HTML :                                                           }
{        <html><head><title>SpotBugs Report</title><style>...</style></head>    }
{        <body>                                                                  }
{          <h1>SpotBugs - Rapport d'analyse</h1>                               }
{          <div class="summary">Statistiques generales</div>                    }
{          <table> Pour chaque categorie de bugs :                               }
{            <tr class="HIGH/MEDIUM/LOW"> colonnes : rang, type, classe,        }
{            methode, ligne, description </tr>                                   }
{          </table>                                                              }
{        </body></html>                                                          }
{      Colorer les lignes selon la priorite (rouge, orange, jaune, vert)        }
{      Inclure un lien vers la documentation SpotBugs par bug type              }
{      Afficher la liste des classes analysees avec leur score                   }
{      Generer des ancres HTML pour chaque section de bugs                       }

{ ============================================================================ }
{ TODO 24 [A FAIRE] - Filtrage, exclusions et configuration des regles         }
{ ============================================================================ }
{                                                                              }
{  - Format du fichier d'exclusion (XML, compatible SpotBugs) :                 }
{      <FindBugsFilter>                                                          }
{        <Match>                                                                 }
{          <Class name="com.example.Foo"/>                                       }
{          <Bug code="NP,BC"/>                                                   }
{        </Match>                                                                }
{        <Match>                                                                 }
{          <Bug pattern="NP_NULL_ON_SOME_PATH"/>                                 }
{          <Class pattern=".*Test"/>                                              }
{        </Match>                                                                }
{      </FindBugsFilter>                                                         }
{                                                                              }
{  - Structure TFilterRule :                                                      }
{      ClassPattern  : String   (expression reguliere sur le nom de classe)     }
{      MethodPattern : String   (expression reguliere sur le nom de methode)    }
{      BugPattern    : String   (expression reguliere sur le code de bug)       }
{      Category      : Integer  (categorie a filtrer, 0 = toutes)               }
{      MinSeverity   : Integer  (severite minimale a filtrer)                   }
{      IsExclude     : Boolean  (True = exclusion, False = inclusion)           }
{                                                                              }
{  - Procedure LoadFilterFile(FileName: String; IsExclude: Boolean)             }
{      Analyser le fichier XML de filtre (mini-parseur XML)                     }
{      Extraire les regles Match avec Class, Bug, Method                        }
{      Compiler les motifs en regles de filtrage                                 }
{                                                                              }
{  - Function IsBugFiltered(Bug: TBugReport): Boolean                           }
{      Verifier si le bug correspond a une regle d'exclusion                    }
{      Verifier qu'il correspond a une regle d'inclusion (si fournie)           }
{      Utiliser une correspondance simple (prefixe, suffixe, joker *)           }
{                                                                              }
{  - Function MatchPattern(Pattern, Value: String): Boolean                     }
{      Correspondance avec jokers (* = toute sequence, ? = un caractere)        }

{ ============================================================================ }
{ TODO 25 [A FAIRE] - Programme principal, balayage recursif et exemples       }
{ ============================================================================ }
{                                                                              }
{  - Procedure ParseArgs                                                        }
{      Analyser ParamStr(1..ParamCount) :                                       }
{        fichier.class ou repertoire (cibles d'analyse)                         }
{        -o <fichier>  : fichier de rapport de sortie                           }
{        -xml          : format de sortie XML (defaut: texte)                   }
{        -html         : format de sortie HTML                                  }
{        -textui       : format de sortie texte (explicite)                     }
{        -effort:min / -effort:default / -effort:max : niveau d'analyse         }
{        -low / -medium / -high : severite minimale a rapporter                 }
{        -exclude <fichier> : fichier de regles d'exclusion                     }
{        -include <fichier> : fichier de regles d'inclusion                     }
{        -recursive    : analyser recursivement les sous-repertoires            }
{        -maxRank <n>  : rang maximum a rapporter (1..20)                       }
{        -version      : afficher la version et quitter                         }
{        -help         : afficher l'aide et quitter                              }
{      Validation : au moins une cible obligatoire                              }
{                                                                              }
{  - Procedure ScanDirectory(DirName: String; Recursive: Boolean)               }
{      Lister tous les fichiers .class dans DirName                             }
{      Pour chaque fichier .class trouve, appeler AnalyzeClass                  }
{      Si Recursive, descendre dans les sous-repertoires                        }
{      Supporter aussi les fichiers .jar (ZIP) en les decompressant en memoire  }
{                                                                              }
{  - Procedure AnalyzeClass(FileName: String)                                   }
{      Orchestrer l'analyse complete d'un fichier .class :                      }
{        1. OpenClassFile, ReadClassHeader (TODO 02)                             }
{        2. ParseConstantPool (TODO 03)                                          }
{        3. ReadClassInfo (TODO 04)                                              }
{        4. ReadFields (TODO 05)                                                 }
{        5. ReadMethods (TODO 06)                                                }
{        6. Pour chaque methode :                                                }
{             a. DecodeInstructions (TODO 07)                                    }
{             b. BuildCFG (TODO 08)                                              }
{             c. Lancer tous les detecteurs (TODOs 09 a 19)                      }
{        7. Lancer DetectBadClassPractices (TODO 12)                             }
{        8. Lancer DetectConcurrencyIssues (TODO 16)                             }
{        9. CloseClassFile                                                       }
{                                                                              }
{  - Procedure PrintHelp                                                        }
{      Afficher l'aide complete en ligne de commande :                          }
{        usage: SPOTBUGS [options] <classes|jars|directories>                   }
{        Options et descriptions detaillees                                     }
{        Exemples d'utilisation                                                  }
{                                                                              }
{  - Fichiers exemples a creer dans SAMPLES\SPOTBUGS\ :                         }
{      Foo.java / Foo.class   : classe avec dereferencement null simple         }
{      Bar.java / Bar.class   : classe avec fuite de ressource (InputStream)    }
{      Baz.java / Baz.class   : classe avec comparaison String par ==           }
{      Loop.java / Loop.class : classe avec boucle potentiellement infinie      }
{      Sql.java  / Sql.class  : classe avec injection SQL par concatenation     }
{      Hash.java / Hash.class : classe avec equals() sans hashCode()            }
{      Sync.java / Sync.class : classe avec bloc synchronized vide              }
{      Cast.java / Cast.class : classe avec cast sans instanceof                 }

Begin
 InitGlobals;
 WriteLn('SPOTBUGS : Cette commande permet d''analyser le bytecode des fichiers .class');
 WriteLn('           pour detecter des bugs potentiels dans le code Java.');
 WriteLn;
 WriteLn('Syntaxe : SPOTBUGS [options] <fichiers.class|repertoire|fichier.jar>');
 WriteLn;
 WriteLn('  -o <fichier>    Fichier de rapport de sortie');
 WriteLn('  -xml            Format de sortie XML (compatible Jenkins)');
 WriteLn('  -html           Format de sortie HTML');
 WriteLn('  -low            Reporter tous les bugs (faible severite et plus)');
 WriteLn('  -medium         Reporter les bugs de severite moyenne et plus');
 WriteLn('  -high           Reporter uniquement les bugs critiques');
 WriteLn('  -exclude <f>    Fichier XML de regles d''exclusion');
 WriteLn('  -include <f>    Fichier XML de regles d''inclusion');
 WriteLn('  -recursive      Analyser recursivement les sous-repertoires');
 WriteLn('  -version        Afficher la version');
 WriteLn('  -help           Afficher cette aide');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn('  SPOTBUGS MyApp.class');
 WriteLn('  SPOTBUGS -xml -o rapport.xml classes/');
 WriteLn('  SPOTBUGS -high -recursive src/');
End.
