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
{  TODO 05 [IMPLEMENTE] - Lecture des champs (fields) de la classe            }
{  TODO 06 [IMPLEMENTE] - Lecture des methodes et de l'attribut Code         }
{  TODO 07 [IMPLEMENTE] - Decodage du bytecode Java (opcodes JVM)              }
{  TODO 08 [IMPLEMENTE] - Construction du graphe de flux de controle (CFG)    }
{  TODO 09 [IMPLEMENTE] - Detecteur : dereferencement de pointeur null        }
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

  { ------------------------------------------------------------------ }
  { TODO 07 : Opcodes JVM (bytecode Java)                               }
  { ------------------------------------------------------------------ }
  MAX_INSTRUCTIONS = 65535;   { Nombre maximum d'instructions par methode }

  { Opcodes de constantes }
  OP_NOP           = 0;   { Ne fait rien                                  }
  OP_ACONST_NULL   = 1;   { Push null                                     }
  OP_ICONST_M1     = 2;   { Push int -1                                   }
  OP_ICONST_0      = 3;   { Push int 0                                    }
  OP_ICONST_1      = 4;   { Push int 1                                    }
  OP_ICONST_2      = 5;   { Push int 2                                    }
  OP_ICONST_3      = 6;   { Push int 3                                    }
  OP_ICONST_4      = 7;   { Push int 4                                    }
  OP_ICONST_5      = 8;   { Push int 5                                    }
  OP_LCONST_0      = 9;   { Push long 0                                   }
  OP_LCONST_1      = 10;  { Push long 1                                   }
  OP_FCONST_0      = 11;  { Push float 0.0                                }
  OP_FCONST_1      = 12;  { Push float 1.0                                }
  OP_FCONST_2      = 13;  { Push float 2.0                                }
  OP_DCONST_0      = 14;  { Push double 0.0                               }
  OP_DCONST_1      = 15;  { Push double 1.0                               }
  OP_BIPUSH        = 16;  { Push byte signe                               }
  OP_SIPUSH        = 17;  { Push short signe                              }
  OP_LDC           = 18;  { Push item du CP (8-bit index)                 }
  OP_LDC_W         = 19;  { Push item du CP (16-bit index)                }
  OP_LDC2_W        = 20;  { Push long/double du CP (16-bit index)         }

  { Opcodes de chargement de variables locales }
  OP_ILOAD         = 21;  { Load int from local var                       }
  OP_LLOAD         = 22;  { Load long from local var                      }
  OP_FLOAD         = 23;  { Load float from local var                     }
  OP_DLOAD         = 24;  { Load double from local var                    }
  OP_ALOAD         = 25;  { Load ref from local var                       }
  OP_ILOAD_0       = 26;  { Load int from local var 0                     }
  OP_ILOAD_1       = 27;  { Load int from local var 1                     }
  OP_ILOAD_2       = 28;  { Load int from local var 2                     }
  OP_ILOAD_3       = 29;  { Load int from local var 3                     }
  OP_LLOAD_0       = 30;  { Load long from local var 0                    }
  OP_LLOAD_1       = 31;  { Load long from local var 1                    }
  OP_LLOAD_2       = 32;  { Load long from local var 2                    }
  OP_LLOAD_3       = 33;  { Load long from local var 3                    }
  OP_FLOAD_0       = 34;  { Load float from local var 0                   }
  OP_FLOAD_1       = 35;  { Load float from local var 1                   }
  OP_FLOAD_2       = 36;  { Load float from local var 2                   }
  OP_FLOAD_3       = 37;  { Load float from local var 3                   }
  OP_DLOAD_0       = 38;  { Load double from local var 0                  }
  OP_DLOAD_1       = 39;  { Load double from local var 1                  }
  OP_DLOAD_2       = 40;  { Load double from local var 2                  }
  OP_DLOAD_3       = 41;  { Load double from local var 3                  }
  OP_ALOAD_0       = 42;  { Load ref from local var 0 (this)              }
  OP_ALOAD_1       = 43;  { Load ref from local var 1                     }
  OP_ALOAD_2       = 44;  { Load ref from local var 2                     }
  OP_ALOAD_3       = 45;  { Load ref from local var 3                     }

  { Opcodes de chargement depuis tableau }
  OP_IALOAD        = 46;  { Load int from array                           }
  OP_LALOAD        = 47;  { Load long from array                          }
  OP_FALOAD        = 48;  { Load float from array                         }
  OP_DALOAD        = 49;  { Load double from array                        }
  OP_AALOAD        = 50;  { Load ref from array                           }
  OP_BALOAD        = 51;  { Load byte/boolean from array                  }
  OP_CALOAD        = 52;  { Load char from array                          }
  OP_SALOAD        = 53;  { Load short from array                         }

  { Opcodes de stockage dans variables locales }
  OP_ISTORE        = 54;  { Store int to local var                        }
  OP_LSTORE        = 55;  { Store long to local var                       }
  OP_FSTORE        = 56;  { Store float to local var                      }
  OP_DSTORE        = 57;  { Store double to local var                     }
  OP_ASTORE        = 58;  { Store ref to local var                        }
  OP_ISTORE_0      = 59;  { Store int to local var 0                      }
  OP_ISTORE_1      = 60;  { Store int to local var 1                      }
  OP_ISTORE_2      = 61;  { Store int to local var 2                      }
  OP_ISTORE_3      = 62;  { Store int to local var 3                      }
  OP_LSTORE_0      = 63;  { Store long to local var 0                     }
  OP_LSTORE_1      = 64;  { Store long to local var 1                     }
  OP_LSTORE_2      = 65;  { Store long to local var 2                     }
  OP_LSTORE_3      = 66;  { Store long to local var 3                     }
  OP_FSTORE_0      = 67;  { Store float to local var 0                    }
  OP_FSTORE_1      = 68;  { Store float to local var 1                    }
  OP_FSTORE_2      = 69;  { Store float to local var 2                    }
  OP_FSTORE_3      = 70;  { Store float to local var 3                    }
  OP_DSTORE_0      = 71;  { Store double to local var 0                   }
  OP_DSTORE_1      = 72;  { Store double to local var 1                   }
  OP_DSTORE_2      = 73;  { Store double to local var 2                   }
  OP_DSTORE_3      = 74;  { Store double to local var 3                   }
  OP_ASTORE_0      = 75;  { Store ref to local var 0                      }
  OP_ASTORE_1      = 76;  { Store ref to local var 1                      }
  OP_ASTORE_2      = 77;  { Store ref to local var 2                      }
  OP_ASTORE_3      = 78;  { Store ref to local var 3                      }

  { Opcodes de stockage dans tableau }
  OP_IASTORE       = 79;  { Store int to array                            }
  OP_LASTORE       = 80;  { Store long to array                           }
  OP_FASTORE       = 81;  { Store float to array                          }
  OP_DASTORE       = 82;  { Store double to array                         }
  OP_AASTORE       = 83;  { Store ref to array                            }
  OP_BASTORE       = 84;  { Store byte/boolean to array                   }
  OP_CASTORE       = 85;  { Store char to array                           }
  OP_SASTORE       = 86;  { Store short to array                          }

  { Opcodes de manipulation de pile }
  OP_POP           = 87;  { Pop 1 word from stack                         }
  OP_POP2          = 88;  { Pop 2 words from stack                        }
  OP_DUP           = 89;  { Duplicate top of stack                        }
  OP_DUP_X1        = 90;  { Duplicate top, insert 1 deep                  }
  OP_DUP_X2        = 91;  { Duplicate top, insert 2 deep                  }
  OP_DUP2          = 92;  { Duplicate top 2 words                         }
  OP_DUP2_X1       = 93;  { Duplicate top 2, insert 1 deep                }
  OP_DUP2_X2       = 94;  { Duplicate top 2, insert 2 deep                }
  OP_SWAP          = 95;  { Swap top 2 words                              }

  { Opcodes arithmetiques }
  OP_IADD          = 96;  { int add                                       }
  OP_LADD          = 97;  { long add                                      }
  OP_FADD          = 98;  { float add                                     }
  OP_DADD          = 99;  { double add                                    }
  OP_ISUB          = 100; { int subtract                                  }
  OP_LSUB          = 101; { long subtract                                 }
  OP_FSUB          = 102; { float subtract                                }
  OP_DSUB          = 103; { double subtract                               }
  OP_IMUL          = 104; { int multiply                                  }
  OP_LMUL          = 105; { long multiply                                 }
  OP_FMUL          = 106; { float multiply                                }
  OP_DMUL          = 107; { double multiply                               }
  OP_IDIV          = 108; { int divide                                    }
  OP_LDIV          = 109; { long divide                                   }
  OP_FDIV          = 110; { float divide                                  }
  OP_DDIV          = 111; { double divide                                 }
  OP_IREM          = 112; { int remainder                                 }
  OP_LREM          = 113; { long remainder                                }
  OP_FREM          = 114; { float remainder                               }
  OP_DREM          = 115; { double remainder                              }
  OP_INEG          = 116; { int negate                                    }
  OP_LNEG          = 117; { long negate                                   }
  OP_FNEG          = 118; { float negate                                  }
  OP_DNEG          = 119; { double negate                                 }
  OP_ISHL          = 120; { int shift left                                }
  OP_LSHL          = 121; { long shift left                               }
  OP_ISHR          = 122; { int arithmetic shift right                    }
  OP_LSHR          = 123; { long arithmetic shift right                   }
  OP_IUSHR         = 124; { int logical shift right                       }
  OP_LUSHR         = 125; { long logical shift right                      }
  OP_IAND          = 126; { int and                                       }
  OP_LAND          = 127; { long and                                      }
  OP_IOR           = 128; { int or                                        }
  OP_LOR           = 129; { long or                                       }
  OP_IXOR          = 130; { int xor                                       }
  OP_LXOR          = 131; { long xor                                      }
  OP_IINC          = 132; { increment local int var by constant           }

  { Opcodes de conversion }
  OP_I2L           = 133; { int to long                                   }
  OP_I2F           = 134; { int to float                                  }
  OP_I2D           = 135; { int to double                                 }
  OP_L2I           = 136; { long to int                                   }
  OP_L2F           = 137; { long to float                                 }
  OP_L2D           = 138; { long to double                                }
  OP_F2I           = 139; { float to int                                  }
  OP_F2L           = 140; { float to long                                 }
  OP_F2D           = 141; { float to double                               }
  OP_D2I           = 142; { double to int                                 }
  OP_D2L           = 143; { double to long                                }
  OP_D2F           = 144; { double to float                               }
  OP_I2B           = 145; { int to byte                                   }
  OP_I2C           = 146; { int to char                                   }
  OP_I2S           = 147; { int to short                                  }

  { Opcodes de comparaison }
  OP_LCMP          = 148; { long compare                                  }
  OP_FCMPL         = 149; { float compare (NaN -> -1)                     }
  OP_FCMPG         = 150; { float compare (NaN -> 1)                      }
  OP_DCMPL         = 151; { double compare (NaN -> -1)                    }
  OP_DCMPG         = 152; { double compare (NaN -> 1)                     }

  { Opcodes de branchement conditionnel }
  OP_IFEQ          = 153; { if value == 0                                 }
  OP_IFNE          = 154; { if value != 0                                 }
  OP_IFLT          = 155; { if value < 0                                  }
  OP_IFGE          = 156; { if value >= 0                                 }
  OP_IFGT          = 157; { if value > 0                                  }
  OP_IFLE          = 158; { if value <= 0                                 }
  OP_IF_ICMPEQ     = 159; { if int1 == int2                               }
  OP_IF_ICMPNE     = 160; { if int1 != int2                               }
  OP_IF_ICMPLT     = 161; { if int1 < int2                                }
  OP_IF_ICMPGE     = 162; { if int1 >= int2                               }
  OP_IF_ICMPGT     = 163; { if int1 > int2                                }
  OP_IF_ICMPLE     = 164; { if int1 <= int2                               }
  OP_IF_ACMPEQ     = 165; { if ref1 == ref2                               }
  OP_IF_ACMPNE     = 166; { if ref1 != ref2                               }

  { Opcodes de branchement inconditionnel }
  OP_GOTO          = 167; { branch always (16-bit offset)                 }
  OP_JSR           = 168; { jump subroutine (16-bit offset)               }
  OP_RET           = 169; { return from subroutine                        }
  OP_TABLESWITCH   = 170; { switch (table, contiguous)                    }
  OP_LOOKUPSWITCH  = 171; { switch (lookup, sparse)                       }

  { Opcodes de retour }
  OP_IRETURN       = 172; { return int                                    }
  OP_LRETURN       = 173; { return long                                   }
  OP_FRETURN       = 174; { return float                                  }
  OP_DRETURN       = 175; { return double                                 }
  OP_ARETURN       = 176; { return ref                                    }
  OP_RETURN        = 177; { return void                                   }

  { Opcodes d'acces aux champs }
  OP_GETSTATIC     = 178; { get static field                              }
  OP_PUTSTATIC     = 179; { put static field                              }
  OP_GETFIELD      = 180; { get instance field                            }
  OP_PUTFIELD      = 181; { put instance field                            }

  { Opcodes d'invocation de methode }
  OP_INVOKEVIRTUAL   = 182; { invoke virtual method                       }
  OP_INVOKESPECIAL   = 183; { invoke constructor/super/private            }
  OP_INVOKESTATIC    = 184; { invoke static method                        }
  OP_INVOKEINTERFACE = 185; { invoke interface method                     }
  OP_INVOKEDYNAMIC   = 186; { invoke dynamic method                       }

  { Opcodes de creation d'objets/tableaux }
  OP_NEW             = 187; { create new object                           }
  OP_NEWARRAY        = 188; { create new primitive array                  }
  OP_ANEWARRAY       = 189; { create new reference array                  }
  OP_ARRAYLENGTH     = 190; { get array length                            }

  { Opcodes d'exception et types }
  OP_ATHROW          = 191; { throw exception                             }
  OP_CHECKCAST       = 192; { check cast                                  }
  OP_INSTANCEOF      = 193; { instanceof test                             }

  { Opcodes de synchronisation }
  OP_MONITORENTER    = 194; { enter monitor                               }
  OP_MONITOREXIT     = 195; { exit monitor                                }

  { Opcodes speciaux }
  OP_WIDE            = 196; { prefix: extend index to 16 bits             }
  OP_MULTIANEWARRAY  = 197; { create multidimensional array               }
  OP_IFNULL          = 198; { if ref == null                              }
  OP_IFNONNULL       = 199; { if ref != null                              }
  OP_GOTO_W          = 200; { branch always (32-bit offset)               }
  OP_JSR_W           = 201; { jump subroutine (32-bit offset)             }

  { Opcodes reserves }
  OP_BREAKPOINT      = 202; { breakpoint (debug)                          }
  OP_IMPDEP1         = 254; { implementation dependent                    }
  OP_IMPDEP2         = 255; { implementation dependent                    }

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

  { --- TODO 05 : Structure TFieldInfo : informations d'un champ --- }
  TFieldInfo = Record
    AccessFlags   : Word;           { Flags d'acces du champ               }
    Name          : String;         { Nom du champ                         }
    Descriptor    : String;         { Descripteur de type JVM              }
    JavaType      : String;         { Type Java lisible                    }
    IsSynthetic   : Boolean;        { ACC_SYNTHETIC set                    }
    IsStatic      : Boolean;        { ACC_STATIC set                       }
    IsFinal       : Boolean;        { ACC_FINAL set                        }
    IsVolatile    : Boolean;        { ACC_VOLATILE set                     }
    IsTransient   : Boolean;        { ACC_TRANSIENT set                    }
    IsEnum        : Boolean;        { ACC_ENUM set                         }
    IsPublic      : Boolean;        { ACC_PUBLIC set                       }
    IsPrivate     : Boolean;        { ACC_PRIVATE set                      }
    IsProtected   : Boolean;        { ACC_PROTECTED set                    }
    ConstValue    : String;         { Valeur constante si ConstantValue    }
    HasConstValue : Boolean;        { Attribut ConstantValue present       }
    IsDeprecated  : Boolean;        { Attribut Deprecated present          }
    Signature     : String;         { Signature generique                  }
  End;

  { --- TODO 05 : Tableau des champs --- }
  TFieldArray = Array[0..MAX_FIELDS-1] of TFieldInfo;

  { --- TODO 06 : Constantes pour les methodes --- }
Const
  MAX_EXCEPTIONS  = 256;   { Nombre max d'entrees exception_table par methode }
  MAX_LINES       = 4096;  { Nombre max d'entrees LineNumberTable             }
  MAX_LOCALVARS   = 256;   { Nombre max d'entrees LocalVariableTable          }
  MAX_THROWS      = 16;    { Nombre max d'exceptions declarees (throws)       }
  MAX_PARAMS      = 32;    { Nombre max de parametres d'une methode           }
  MAX_CODE_SIZE   = 65535; { Taille max du bytecode d'une methode             }

Type
  { --- TODO 06 : Structure TExceptionEntry : entree de exception_table --- }
  TExceptionEntry = Record
    StartPC   : Word;    { Debut de la zone protegee                       }
    EndPC     : Word;    { Fin de la zone protegee                         }
    HandlerPC : Word;    { Debut du gestionnaire d'exception               }
    CatchType : Word;    { Index CP vers la classe catchee, 0 = finally    }
    CatchName : String;  { Nom de la classe catchee (resolu)               }
  End;
  TExcArray = Array[0..MAX_EXCEPTIONS-1] of TExceptionEntry;

  { --- TODO 06 : Structure TLineEntry : entree de LineNumberTable --- }
  TLineEntry = Record
    StartPC : Word;      { Offset du premier bytecode pour cette ligne     }
    LineNum : Word;      { Numero de ligne dans le fichier source          }
  End;
  TLineArray = Array[0..MAX_LINES-1] of TLineEntry;

  { --- TODO 06 : Structure TLocalVarEntry : entree de LocalVariableTable --- }
  TLocalVarEntry = Record
    StartPC    : Word;   { Debut de la portee de la variable               }
    Length     : Word;   { Longueur de la portee en octets bytecode        }
    Name       : String; { Nom de la variable                              }
    Descriptor : String; { Descripteur de type JVM                         }
    Index      : Word;   { Index de slot dans le tableau des variables     }
  End;
  TLocalVarArray = Array[0..MAX_LOCALVARS-1] of TLocalVarEntry;

  { --- TODO 06 : Structure TMethodInfo : informations d'une methode --- }
  TMethodInfo = Record
    AccessFlags   : Word;             { Flags d'acces de la methode         }
    Name          : String;           { Nom de la methode                   }
    Descriptor    : String;           { Descripteur JVM de la methode       }
    JavaSignature : String;           { Signature Java lisible              }
    MaxStack      : Word;             { Profondeur max de pile              }
    MaxLocals     : Word;             { Nb variables locales max            }
    CodeLen       : LongWord;         { Taille du bytecode en octets        }
    Code          : Pointer;          { Pointeur vers le bytecode           }
    ExcCount      : Word;             { Nb entrees exception_table          }
    ExcTable      : TExcArray;        { Table des exceptions                }
    LineCount     : Word;             { Nb entrees LineNumberTable          }
    LineTable     : TLineArray;       { Table des lignes                    }
    LocalCount    : Word;             { Nb entrees LocalVariableTable       }
    LocalTable    : TLocalVarArray;   { Table des variables locales         }
    ThrowsCount   : Word;             { Nb exceptions declarees (throws)    }
    Throws        : Array[0..MAX_THROWS-1] of String; { Exceptions throws   }
    IsPublic      : Boolean;          { ACC_PUBLIC set                      }
    IsPrivate     : Boolean;          { ACC_PRIVATE set                     }
    IsProtected   : Boolean;          { ACC_PROTECTED set                   }
    IsStatic      : Boolean;          { ACC_STATIC set                      }
    IsFinal       : Boolean;          { ACC_FINAL set                       }
    IsSynchronized: Boolean;          { ACC_SYNCHRONIZED set                }
    IsNative      : Boolean;          { ACC_NATIVE set                      }
    IsAbstract    : Boolean;          { ACC_ABSTRACT set                    }
    IsStrict      : Boolean;          { ACC_STRICT set (strictfp)           }
    IsBridge      : Boolean;          { ACC_BRIDGE set                      }
    IsSynthetic   : Boolean;          { ACC_SYNTHETIC set                   }
    IsVarArgs     : Boolean;          { ACC_VARARGS set                     }
    IsDeprecated  : Boolean;          { Attribut Deprecated present         }
    Signature     : String;           { Signature generique                 }
  End;

  { --- TODO 06 : Tableau des methodes --- }
  TMethodArray = Array[0..MAX_METHODS-1] of TMethodInfo;

  { --- TODO 07 : Structure TInstruction : instruction bytecode decodee --- }
  TInstruction = Record
    PC       : LongWord;   { Position dans le bytecode                      }
    Opcode   : Byte;       { Code operation (0..255)                        }
    Mnemonic : String;     { Mnemonique lisible (iload, invokevirtual, etc) }
    Op1      : LongInt;    { Premier operande (index, offset, constante)    }
    Op2      : LongInt;    { Second operande (pour invokeinterface, iinc)   }
    Op3      : LongInt;    { Troisieme operande (reserve)                   }
    Size     : Integer;    { Taille totale de l'instruction en octets       }
    CpRef    : String;     { Reference CP resolue (nom de methode/champ)    }
    LineNum  : Integer;    { Numero de ligne source associe                 }
  End;
  TInstrArray = Array[0..MAX_INSTRUCTIONS-1] of TInstruction;

  { --- TODO 08 : Constantes pour le CFG --- }
Const
  MAX_CFG_SUCCS  = 4;      { Nombre max de successeurs par noeud             }
  MAX_CFG_PREDS  = 16;     { Nombre max de predecesseurs par noeud           }
  MAX_LEADERS    = 4096;   { Nombre max de tetes de blocs de base            }

  { --- TODO 09 : Constantes pour le detecteur null --- }
  MAX_NULL_STACK  = 64;    { Profondeur max de la pile de valeurs abstraites }
  MAX_NULL_LOCALS = 256;   { Nombre max de variables locales analysees       }
  MAX_NULL_BUGS   = 256;   { Nombre max de bugs null par methode             }

  { Valeurs abstraites pour l'analyse de nullite }
  VAL_UNKNOWN  = 0;        { Valeur inconnue (pas encore analysee)           }
  VAL_NULL     = 1;        { Reference certainement null                     }
  VAL_NONNULL  = 2;        { Reference certainement non-null                 }
  VAL_MAYBE    = 3;        { Peut etre null ou non-null selon le chemin      }

  { Types de bugs de null dereference }
  NP_NONE                        = 0;  { Pas de bug                          }
  NP_NULL_ON_SOME_PATH           = 1;  { Deref possible sur certains chemins }
  NP_NULL_ON_SOME_PATH_EXCEPTION = 2;  { Deref possible via chemin exception }
  NP_ALWAYS_NULL                 = 3;  { Deref toujours null                 }
  NP_NULL_DEREF_ALL_TARGETS      = 4;  { Tous les chemins menent a null deref}
  NP_STORE_INTO_NONNULL_FIELD    = 5;  { Stockage null dans champ non-null   }
  NP_GUARANTEED_DEREF            = 6;  { Deref garanti null                  }

Type
  { --- TODO 08 : Structure TCFGNode : noeud du graphe de flux de controle --- }
  TCFGNode = Record
    ID          : Integer;  { Identifiant unique du noeud (0..N-1)            }
    StartPC     : LongWord; { Premier PC du bloc de base                      }
    EndPC       : LongWord; { Dernier PC du bloc de base                      }
    InstStart   : Integer;  { Index premiere instruction dans Instructions[]  }
    InstEnd     : Integer;  { Index derniere instruction dans Instructions[]  }
    Succs       : Array[0..MAX_CFG_SUCCS-1] of Integer; { Successeurs          }
    SuccCount   : Integer;  { Nombre de successeurs                           }
    Preds       : Array[0..MAX_CFG_PREDS-1] of Integer; { Predecesseurs        }
    PredCount   : Integer;  { Nombre de predecesseurs                         }
    IsEntry     : Boolean;  { True si noeud d'entree (PC=0)                   }
    IsExit      : Boolean;  { True si noeud de sortie (return/athrow)         }
    IsException : Boolean;  { True si debut de gestionnaire d'exception       }
    Visited     : Boolean;  { Pour parcours DFS/BFS                           }
    DomBy       : Integer;  { Dominateur immediat (-1 si aucun/entree)        }
    IsBackEdge  : Boolean;  { True si possede une arete arriere vers lui      }
  End;
  TCFGArray = Array[0..MAX_CFG_NODES-1] of TCFGNode;

  { --- TODO 09 : Structure TNullBugInfo : bug null detecte --- }
  TNullBugInfo = Record
    BugType  : Integer;    { Type de bug (NP_ALWAYS_NULL, etc.)              }
    PC       : LongWord;   { Position dans le bytecode                       }
    LineNum  : Integer;    { Numero de ligne source                          }
    OpType   : String;     { Type d'operation fautive                        }
  End;
  TNullBugArray = Array[0..MAX_NULL_BUGS-1] of TNullBugInfo;

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
  Fields         : TFieldArray;   { TODO 05 : Table des champs          }
  FieldCount     : Word;          { TODO 05 : Nombre de champs          }
  Methods        : TMethodArray;  { TODO 06 : Table des methodes        }
  MethodCount    : Word;          { TODO 06 : Nombre de methodes        }
  Instructions   : ^TInstrArray;  { TODO 07 : Instructions decodees (pointeur) }
  InstrCount     : Word;          { TODO 07 : Nombre d'instructions decodees   }
  CFGNodes       : ^TCFGArray;    { TODO 08 : Noeuds du CFG (pointeur)         }
  CFGNodeCount   : Integer;       { TODO 08 : Nombre de noeuds CFG             }
  CFGUnreachable : Integer;       { TODO 08 : Nombre de blocs inaccessibles    }
  CFGBackEdges   : Integer;       { TODO 08 : Nombre d'aretes arriere (boucles)}
  { --- TODO 09 : Variables du detecteur null --- }
  NullInitialized : Boolean;      { True si module initialise                  }
  NullStack       : Array[0..MAX_NULL_STACK-1] of Byte;  { Pile abstraite      }
  NullStackTop    : Integer;      { Sommet de la pile (index du prochain libre)}
  NullLocals      : Array[0..MAX_NULL_LOCALS-1] of Byte; { Etat vars locales   }
  NullLocalCount  : Integer;      { Nombre de variables locales utilisees      }
  NullBugs        : TNullBugArray;{ Bugs detectes dans la methode courante     }
  NullBugCount    : Integer;      { Nombre de bugs detectes                    }
  NullLabelNum    : Integer;      { Compteur pour generation de labels         }
  NullTotalChecks : Integer;      { Nombre total de verifications effectuees   }
  NullTotalDeref  : Integer;      { Nombre total de dereferences analysees     }
  NullCurrentPC   : LongWord;     { PC de l'instruction courante               }
  NullCurrentLine : Integer;      { Ligne source courante                      }

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

{ --- CPGetMemberRefStr : retourner une chaine formatee pour un membre --- }
Function CPGetMemberRefStr(Idx: Word): String;
Var
  ClassName, Name, Desc: String;
Begin
  CPGetMemberRef(Idx, ClassName, Name, Desc);
  If ClassName <> '' Then
    CPGetMemberRefStr := ClassName + '.' + Name + ':' + Desc
  Else
    CPGetMemberRefStr := '';
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
{ TODO 05 [IMPLEMENTE] - Lecture des champs (fields) de la classe              }
{ ============================================================================ }

{ --- TODO 05 : Initialisation de la table des champs --- }
Procedure InitFields;
Var
  I: Integer;
Begin
  FieldCount := 0;
  For I := 0 to MAX_FIELDS - 1 Do Begin
    Fields[I].AccessFlags   := 0;
    Fields[I].Name          := '';
    Fields[I].Descriptor    := '';
    Fields[I].JavaType      := '';
    Fields[I].IsSynthetic   := False;
    Fields[I].IsStatic      := False;
    Fields[I].IsFinal       := False;
    Fields[I].IsVolatile    := False;
    Fields[I].IsTransient   := False;
    Fields[I].IsEnum        := False;
    Fields[I].IsPublic      := False;
    Fields[I].IsPrivate     := False;
    Fields[I].IsProtected   := False;
    Fields[I].ConstValue    := '';
    Fields[I].HasConstValue := False;
    Fields[I].IsDeprecated  := False;
    Fields[I].Signature     := '';
  End;
End;

{ --- TODO 05 : Decoder un descripteur de type JVM en type Java lisible --- }
{ V->void, I->int, J->long, D->double, F->float, B->byte, C->char, S->short  }
{ Z->boolean, L<nom>;-><nom>, [X->X[]                                         }
Function DecodeTypeDescriptor(Desc: String): String;
Var
  Result_: String;
  P, ArrayDim: Integer;
  ClassEnd: Integer;
Begin
  Result_ := '';
  ArrayDim := 0;
  P := 1;
  
  { Compter les dimensions de tableau }
  While (P <= Length(Desc)) And (Desc[P] = '[') Do Begin
    Inc(ArrayDim);
    Inc(P);
  End;
  
  If P <= Length(Desc) Then Begin
    Case Desc[P] of
      'V': Result_ := 'void';
      'I': Result_ := 'int';
      'J': Result_ := 'long';
      'D': Result_ := 'double';
      'F': Result_ := 'float';
      'B': Result_ := 'byte';
      'C': Result_ := 'char';
      'S': Result_ := 'short';
      'Z': Result_ := 'boolean';
      'L': Begin
        { Classe : Ljava/lang/String; -> String }
        ClassEnd := Pos(';', Desc);
        If ClassEnd > P Then Begin
          Result_ := Copy(Desc, P + 1, ClassEnd - P - 1);
          { Convertir / en . }
          While Pos('/', Result_) > 0 Do
            Result_[Pos('/', Result_)] := '.';
          { Extraire le nom simple (apres le dernier .) }
          While Pos('.', Result_) > 0 Do
            Delete(Result_, 1, Pos('.', Result_));
        End Else
          Result_ := 'Object';
      End;
    Else
      Result_ := 'unknown';
    End;
  End Else
    Result_ := 'unknown';
  
  { Ajouter les dimensions de tableau }
  While ArrayDim > 0 Do Begin
    Result_ := Result_ + '[]';
    Dec(ArrayDim);
  End;
  
  DecodeTypeDescriptor := Result_;
End;

{ --- TODO 05 : Decoder un descripteur complet (avec nom de classe complet) --- }
Function DecodeTypeDescriptorFull(Desc: String): String;
Var
  Result_: String;
  P, ArrayDim: Integer;
  ClassEnd: Integer;
Begin
  Result_ := '';
  ArrayDim := 0;
  P := 1;
  
  { Compter les dimensions de tableau }
  While (P <= Length(Desc)) And (Desc[P] = '[') Do Begin
    Inc(ArrayDim);
    Inc(P);
  End;
  
  If P <= Length(Desc) Then Begin
    Case Desc[P] of
      'V': Result_ := 'void';
      'I': Result_ := 'int';
      'J': Result_ := 'long';
      'D': Result_ := 'double';
      'F': Result_ := 'float';
      'B': Result_ := 'byte';
      'C': Result_ := 'char';
      'S': Result_ := 'short';
      'Z': Result_ := 'boolean';
      'L': Begin
        { Classe : Ljava/lang/String; -> java.lang.String }
        ClassEnd := Pos(';', Desc);
        If ClassEnd > P Then Begin
          Result_ := Copy(Desc, P + 1, ClassEnd - P - 1);
          { Convertir / en . }
          While Pos('/', Result_) > 0 Do
            Result_[Pos('/', Result_)] := '.';
        End Else
          Result_ := 'java.lang.Object';
      End;
    Else
      Result_ := 'unknown';
    End;
  End Else
    Result_ := 'unknown';
  
  { Ajouter les dimensions de tableau }
  While ArrayDim > 0 Do Begin
    Result_ := Result_ + '[]';
    Dec(ArrayDim);
  End;
  
  DecodeTypeDescriptorFull := Result_;
End;

{ --- TODO 05 : Obtenir la valeur constante depuis le Constant Pool --- }
Function GetConstantValue(CpIndex: Word): String;
Var
  Result_: String;
Begin
  Result_ := '';
  If (CpIndex > 0) And (CpIndex < CPCount) And (CP <> Nil) Then Begin
    Case CP^[CpIndex].Tag of
      CP_INTEGER: Str(CP^[CpIndex].IntVal, Result_);
      CP_LONG:    Str(CP^[CpIndex].IntVal, Result_);
      CP_FLOAT:   Str(CP^[CpIndex].FloatVal:0:6, Result_);
      CP_DOUBLE:  Str(CP^[CpIndex].FloatVal:0:12, Result_);
      CP_STRING:  Begin
        If CP^[CpIndex].Ref1 < CPCount Then
          Result_ := '"' + CP^[CP^[CpIndex].Ref1].StrVal + '"';
      End;
    Else
      Result_ := '?';
    End;
  End;
  GetConstantValue := Result_;
End;

{ --- TODO 05 : Lire les attributs d'un champ --- }
Procedure ReadFieldAttributes(Var Field: TFieldInfo);
Var
  AttrCount, I: Word;
  AttrNameIdx: Word;
  AttrLen: LongWord;
  AttrName: String;
  ConstIdx, SigIdx: Word;
Begin
  AttrCount := ReadU2;
  
  For I := 1 to AttrCount Do Begin
    AttrNameIdx := ReadU2;
    AttrLen := ReadU4;
    
    { Resoudre le nom de l'attribut }
    AttrName := CPGetUtf8(AttrNameIdx);
    
    If AttrName = 'ConstantValue' Then Begin
      { Attribut ConstantValue : index U2 vers la valeur }
      ConstIdx := ReadU2;
      Field.ConstValue := GetConstantValue(ConstIdx);
      Field.HasConstValue := True;
    End
    Else If AttrName = 'Deprecated' Then Begin
      { Attribut Deprecated : aucune donnee }
      Field.IsDeprecated := True;
    End
    Else If AttrName = 'Signature' Then Begin
      { Attribut Signature : index U2 vers signature generique }
      SigIdx := ReadU2;
      Field.Signature := CPGetUtf8(SigIdx);
    End
    Else If AttrName = 'Synthetic' Then Begin
      { Attribut Synthetic : aucune donnee }
      Field.IsSynthetic := True;
    End
    Else Begin
      { Attribut inconnu : sauter les donnees }
      SkipAttribute(AttrLen);
    End;
  End;
End;

{ --- TODO 05 : Lire tous les champs de la classe --- }
Procedure ReadFields;
Var
  Count, I: Word;
  AccessFlags: Word;
  NameIdx, DescIdx: Word;
Begin
  Count := ReadU2;
  FieldCount := Count;
  
  If Count > MAX_FIELDS Then Begin
    Warning('Trop de champs (' + IntToStr_(Count) + '), limite = ' + IntToStr_(MAX_FIELDS));
    Count := MAX_FIELDS;
  End;
  
  For I := 0 to Count - 1 Do Begin
    { Lire les informations de base du champ }
    AccessFlags := ReadU2;
    NameIdx := ReadU2;
    DescIdx := ReadU2;
    
    { Stocker dans la structure }
    Fields[I].AccessFlags := AccessFlags;
    Fields[I].Name := CPGetUtf8(NameIdx);
    Fields[I].Descriptor := CPGetUtf8(DescIdx);
    Fields[I].JavaType := DecodeTypeDescriptor(Fields[I].Descriptor);
    
    { Decoder les flags d'acces }
    Fields[I].IsPublic    := (AccessFlags And ACC_PUBLIC) <> 0;
    Fields[I].IsPrivate   := (AccessFlags And ACC_PRIVATE) <> 0;
    Fields[I].IsProtected := (AccessFlags And ACC_PROTECTED) <> 0;
    Fields[I].IsStatic    := (AccessFlags And ACC_STATIC) <> 0;
    Fields[I].IsFinal     := (AccessFlags And ACC_FINAL) <> 0;
    Fields[I].IsVolatile  := (AccessFlags And ACC_VOLATILE) <> 0;
    Fields[I].IsTransient := (AccessFlags And ACC_TRANSIENT) <> 0;
    Fields[I].IsSynthetic := (AccessFlags And ACC_SYNTHETIC) <> 0;
    Fields[I].IsEnum      := (AccessFlags And ACC_ENUM) <> 0;
    
    { Initialiser les attributs }
    Fields[I].ConstValue    := '';
    Fields[I].HasConstValue := False;
    Fields[I].IsDeprecated  := False;
    Fields[I].Signature     := '';
    
    { Lire les attributs du champ }
    ReadFieldAttributes(Fields[I]);
  End;
End;

{ --- TODO 05 : Obtenir le modificateur d'acces d'un champ --- }
Function GetFieldAccessStr(Var Field: TFieldInfo): String;
Var
  S: String;
Begin
  S := '';
  If Field.IsPublic Then S := S + 'public '
  Else If Field.IsPrivate Then S := S + 'private '
  Else If Field.IsProtected Then S := S + 'protected ';
  
  If Field.IsStatic Then S := S + 'static ';
  If Field.IsFinal Then S := S + 'final ';
  If Field.IsVolatile Then S := S + 'volatile ';
  If Field.IsTransient Then S := S + 'transient ';
  
  GetFieldAccessStr := S;
End;

{ --- TODO 05 : Afficher un champ en notation Java --- }
Function FieldToJavaString(Var Field: TFieldInfo): String;
Var
  S: String;
Begin
  S := GetFieldAccessStr(Field) + Field.JavaType + ' ' + Field.Name;
  If Field.HasConstValue Then
    S := S + ' = ' + Field.ConstValue;
  FieldToJavaString := S;
End;

{ --- TODO 05 : Afficher les informations de debug des champs --- }
Procedure DumpFields;
Var
  I: Integer;
  FlagStr: String;
Begin
  WriteLn('=== Fields (', FieldCount, ') ===');
  
  For I := 0 to FieldCount - 1 Do Begin
    WriteLn('Field #', I, ':');
    WriteLn('  Name:       ', Fields[I].Name);
    WriteLn('  Descriptor: ', Fields[I].Descriptor);
    WriteLn('  Type:       ', Fields[I].JavaType);
    
    { Construire la chaine des flags }
    FlagStr := '';
    If Fields[I].IsPublic Then FlagStr := FlagStr + 'public ';
    If Fields[I].IsPrivate Then FlagStr := FlagStr + 'private ';
    If Fields[I].IsProtected Then FlagStr := FlagStr + 'protected ';
    If Fields[I].IsStatic Then FlagStr := FlagStr + 'static ';
    If Fields[I].IsFinal Then FlagStr := FlagStr + 'final ';
    If Fields[I].IsVolatile Then FlagStr := FlagStr + 'volatile ';
    If Fields[I].IsTransient Then FlagStr := FlagStr + 'transient ';
    If Fields[I].IsSynthetic Then FlagStr := FlagStr + 'synthetic ';
    If Fields[I].IsEnum Then FlagStr := FlagStr + 'enum ';
    
    WriteLn('  Flags:      ', FlagStr, '($', HexWord(Fields[I].AccessFlags), ')');
    
    If Fields[I].HasConstValue Then
      WriteLn('  ConstValue: ', Fields[I].ConstValue);
    If Fields[I].IsDeprecated Then
      WriteLn('  Deprecated: true');
    If Fields[I].Signature <> '' Then
      WriteLn('  Signature:  ', Fields[I].Signature);
    
    WriteLn('  Java:       ', FieldToJavaString(Fields[I]));
    WriteLn;
  End;
End;

{ ============================================================================ }
{ TODO 06 [IMPLEMENTE] - Lecture des methodes et de l'attribut Code            }
{ ============================================================================ }

{ Declaration forward pour ReadCodeSubAttributes }
Procedure ReadCodeSubAttributes(Var M: TMethodInfo); Forward;

{ --- TODO 06 : Initialiser une methode --- }
Procedure InitMethod(Var M: TMethodInfo);
Var
  I: Integer;
Begin
  M.AccessFlags := 0;
  M.Name := '';
  M.Descriptor := '';
  M.JavaSignature := '';
  M.MaxStack := 0;
  M.MaxLocals := 0;
  M.CodeLen := 0;
  M.Code := Nil;
  M.ExcCount := 0;
  M.LineCount := 0;
  M.LocalCount := 0;
  M.ThrowsCount := 0;
  For I := 0 to MAX_THROWS - 1 Do
    M.Throws[I] := '';
  M.IsPublic := False;
  M.IsPrivate := False;
  M.IsProtected := False;
  M.IsStatic := False;
  M.IsFinal := False;
  M.IsSynchronized := False;
  M.IsNative := False;
  M.IsAbstract := False;
  M.IsStrict := False;
  M.IsBridge := False;
  M.IsSynthetic := False;
  M.IsVarArgs := False;
  M.IsDeprecated := False;
  M.Signature := '';
End;

{ --- TODO 06 : Parser le descripteur de methode et extraire les types --- }
{ Ex: (ILjava/lang/String;)V -> params=[int,String], retType=void          }
Procedure ParseMethodDescriptor(Desc: String; Var ParamCount: Integer;
                                Var Params: Array of String; Var RetType: String);
Var
  P, Len, ArrayDim: Integer;
  InParams: Boolean;
  TypeStr, ClassName: String;
  EndPos: Integer;
Begin
  ParamCount := 0;
  RetType := '';
  P := 1;
  Len := Length(Desc);
  InParams := False;
  
  While P <= Len Do Begin
    If Desc[P] = '(' Then Begin
      InParams := True;
      Inc(P);
    End
    Else If Desc[P] = ')' Then Begin
      InParams := False;
      Inc(P);
    End
    Else Begin
      { Lire un type }
      ArrayDim := 0;
      While (P <= Len) And (Desc[P] = '[') Do Begin
        Inc(ArrayDim);
        Inc(P);
      End;
      
      If P > Len Then Break;
      
      TypeStr := '';
      Case Desc[P] of
        'V': Begin TypeStr := 'void'; Inc(P); End;
        'I': Begin TypeStr := 'int'; Inc(P); End;
        'J': Begin TypeStr := 'long'; Inc(P); End;
        'D': Begin TypeStr := 'double'; Inc(P); End;
        'F': Begin TypeStr := 'float'; Inc(P); End;
        'B': Begin TypeStr := 'byte'; Inc(P); End;
        'C': Begin TypeStr := 'char'; Inc(P); End;
        'S': Begin TypeStr := 'short'; Inc(P); End;
        'Z': Begin TypeStr := 'boolean'; Inc(P); End;
        'L': Begin
          { Lire le nom de classe jusqu'a ; }
          Inc(P);
          EndPos := P;
          While (EndPos <= Len) And (Desc[EndPos] <> ';') Do
            Inc(EndPos);
          ClassName := Copy(Desc, P, EndPos - P);
          { Convertir / en . et extraire nom simple }
          While Pos('/', ClassName) > 0 Do
            Delete(ClassName, 1, Pos('/', ClassName));
          TypeStr := ClassName;
          P := EndPos + 1;
        End;
      Else
        Inc(P); { Caractere inconnu, on saute }
      End;
      
      { Ajouter les dimensions de tableau }
      While ArrayDim > 0 Do Begin
        TypeStr := TypeStr + '[]';
        Dec(ArrayDim);
      End;
      
      If TypeStr <> '' Then Begin
        If InParams Then Begin
          If ParamCount < MAX_PARAMS Then Begin
            Params[ParamCount] := TypeStr;
            Inc(ParamCount);
          End;
        End
        Else
          RetType := TypeStr;
      End;
    End;
  End;
End;

{ --- TODO 06 : Construire la signature Java lisible d'une methode --- }
Function BuildJavaSignature(Name: String; Desc: String): String;
Var
  ParamCount, I: Integer;
  Params: Array[0..MAX_PARAMS-1] of String;
  RetType, S: String;
Begin
  ParseMethodDescriptor(Desc, ParamCount, Params, RetType);
  S := RetType + ' ' + Name + '(';
  For I := 0 to ParamCount - 1 Do Begin
    If I > 0 Then S := S + ', ';
    S := S + Params[I];
  End;
  S := S + ')';
  BuildJavaSignature := S;
End;

{ --- TODO 06 : Lire les attributs d'une methode --- }
Procedure ReadMethodAttributes(Var M: TMethodInfo);
Var
  AttrCount, I: Word;
  AttrNameIdx: Word;
  AttrLen: LongWord;
  AttrName: String;
  ExcCount, ExcIdx, SigIdx: Word;
Begin
  AttrCount := ReadU2;
  
  For I := 1 to AttrCount Do Begin
    AttrNameIdx := ReadU2;
    AttrLen := ReadU4;
    AttrName := CPGetUtf8(AttrNameIdx);
    
    If AttrName = 'Code' Then Begin
      { Lire MaxStack, MaxLocals, CodeLen, code, exc_table, sub_attrs }
      M.MaxStack := ReadU2;
      M.MaxLocals := ReadU2;
      M.CodeLen := ReadU4;
      
      If M.CodeLen > 0 Then Begin
        If M.CodeLen > MAX_CODE_SIZE Then Begin
          Warning('Code trop grand');
          { Sauter le code }
          SkipAttribute(M.CodeLen);
          M.CodeLen := 0;
          M.Code := Nil;
        End Else Begin
          GetMem(M.Code, M.CodeLen);
          BlockRead(ClassFile, M.Code^, M.CodeLen);
        End;
      End;
      
      { Lire la table des exceptions }
      ExcCount := ReadU2;
      M.ExcCount := ExcCount;
      If ExcCount > MAX_EXCEPTIONS Then ExcCount := MAX_EXCEPTIONS;
      For ExcIdx := 0 to ExcCount - 1 Do Begin
        M.ExcTable[ExcIdx].StartPC := ReadU2;
        M.ExcTable[ExcIdx].EndPC := ReadU2;
        M.ExcTable[ExcIdx].HandlerPC := ReadU2;
        M.ExcTable[ExcIdx].CatchType := ReadU2;
        If M.ExcTable[ExcIdx].CatchType = 0 Then
          M.ExcTable[ExcIdx].CatchName := 'finally'
        Else
          M.ExcTable[ExcIdx].CatchName := CPGetClassName(M.ExcTable[ExcIdx].CatchType);
      End;
      { Sauter exceptions excedentaires }
      If M.ExcCount > MAX_EXCEPTIONS Then Begin
        For ExcIdx := MAX_EXCEPTIONS to M.ExcCount - 1 Do Begin
          ReadU2; ReadU2; ReadU2; ReadU2;
        End;
        M.ExcCount := MAX_EXCEPTIONS;
      End;
      
      { Lire les sous-attributs du Code (LineNumberTable, LocalVariableTable) }
      ReadCodeSubAttributes(M);
    End
    Else If AttrName = 'Exceptions' Then Begin
      { Liste des exceptions throws }
      ExcCount := ReadU2;
      M.ThrowsCount := ExcCount;
      If ExcCount > MAX_THROWS Then ExcCount := MAX_THROWS;
      For ExcIdx := 0 to ExcCount - 1 Do Begin
        SigIdx := ReadU2;
        M.Throws[ExcIdx] := CPGetClassName(SigIdx);
      End;
      { Sauter les exceptions excedentaires }
      If M.ThrowsCount > MAX_THROWS Then Begin
        For ExcIdx := MAX_THROWS to M.ThrowsCount - 1 Do
          ReadU2;
        M.ThrowsCount := MAX_THROWS;
      End;
    End
    Else If AttrName = 'Deprecated' Then
      M.IsDeprecated := True
    Else If AttrName = 'Synthetic' Then
      M.IsSynthetic := True
    Else If AttrName = 'Signature' Then Begin
      SigIdx := ReadU2;
      M.Signature := CPGetUtf8(SigIdx);
    End
    Else
      SkipAttribute(AttrLen);
  End;
End;

{ --- TODO 06 : Lire les sous-attributs de Code (LineNumberTable, etc.) --- }
Procedure ReadCodeSubAttributes(Var M: TMethodInfo);
Var
  SubAttrCount, I: Word;
  SubAttrNameIdx: Word;
  SubAttrLen: LongWord;
  SubAttrName: String;
  TableLen, J: Word;
  NameIdx, DescIdx: Word;
Begin
  SubAttrCount := ReadU2;
  
  For I := 1 to SubAttrCount Do Begin
    SubAttrNameIdx := ReadU2;
    SubAttrLen := ReadU4;
    SubAttrName := CPGetUtf8(SubAttrNameIdx);
    
    If SubAttrName = 'LineNumberTable' Then Begin
      TableLen := ReadU2;
      M.LineCount := TableLen;
      If TableLen > MAX_LINES Then TableLen := MAX_LINES;
      For J := 0 to TableLen - 1 Do Begin
        M.LineTable[J].StartPC := ReadU2;
        M.LineTable[J].LineNum := ReadU2;
      End;
      { Sauter les entrees excedentaires }
      If M.LineCount > MAX_LINES Then Begin
        For J := MAX_LINES to M.LineCount - 1 Do Begin
          ReadU2; ReadU2;
        End;
        M.LineCount := MAX_LINES;
      End;
    End
    Else If SubAttrName = 'LocalVariableTable' Then Begin
      TableLen := ReadU2;
      M.LocalCount := TableLen;
      If TableLen > MAX_LOCALVARS Then TableLen := MAX_LOCALVARS;
      For J := 0 to TableLen - 1 Do Begin
        M.LocalTable[J].StartPC := ReadU2;
        M.LocalTable[J].Length := ReadU2;
        NameIdx := ReadU2;
        DescIdx := ReadU2;
        M.LocalTable[J].Name := CPGetUtf8(NameIdx);
        M.LocalTable[J].Descriptor := CPGetUtf8(DescIdx);
        M.LocalTable[J].Index := ReadU2;
      End;
      { Sauter les entrees excedentaires }
      If M.LocalCount > MAX_LOCALVARS Then Begin
        For J := MAX_LOCALVARS to M.LocalCount - 1 Do Begin
          ReadU2; ReadU2; ReadU2; ReadU2; ReadU2;
        End;
        M.LocalCount := MAX_LOCALVARS;
      End;
    End
    Else
      SkipAttribute(SubAttrLen);
  End;
End;

{ --- TODO 06 : Lire toutes les methodes de la classe --- }
Procedure ReadMethods;
Var
  Count, I: Word;
  AccessFlags: Word;
  NameIdx, DescIdx: Word;
Begin
  Count := ReadU2;
  MethodCount := Count;
  
  If Count > MAX_METHODS Then Begin
    Warning('Trop de methodes (' + IntToStr_(Count) + '), limite = ' + IntToStr_(MAX_METHODS));
    Count := MAX_METHODS;
  End;
  
  For I := 0 to Count - 1 Do Begin
    { Initialiser la methode }
    InitMethod(Methods[I]);
    
    { Lire les informations de base }
    AccessFlags := ReadU2;
    NameIdx := ReadU2;
    DescIdx := ReadU2;
    
    Methods[I].AccessFlags := AccessFlags;
    Methods[I].Name := CPGetUtf8(NameIdx);
    Methods[I].Descriptor := CPGetUtf8(DescIdx);
    Methods[I].JavaSignature := BuildJavaSignature(Methods[I].Name, Methods[I].Descriptor);
    
    { Decoder les flags d'acces }
    Methods[I].IsPublic       := (AccessFlags And ACC_PUBLIC) <> 0;
    Methods[I].IsPrivate      := (AccessFlags And ACC_PRIVATE) <> 0;
    Methods[I].IsProtected    := (AccessFlags And ACC_PROTECTED) <> 0;
    Methods[I].IsStatic       := (AccessFlags And ACC_STATIC) <> 0;
    Methods[I].IsFinal        := (AccessFlags And ACC_FINAL) <> 0;
    Methods[I].IsSynchronized := (AccessFlags And ACC_SYNCHRONIZED) <> 0;
    Methods[I].IsNative       := (AccessFlags And ACC_NATIVE) <> 0;
    Methods[I].IsAbstract     := (AccessFlags And ACC_ABSTRACT) <> 0;
    Methods[I].IsStrict       := (AccessFlags And ACC_STRICT) <> 0;
    Methods[I].IsBridge       := (AccessFlags And $0040) <> 0; { ACC_BRIDGE }
    Methods[I].IsVarArgs      := (AccessFlags And $0080) <> 0; { ACC_VARARGS }
    Methods[I].IsSynthetic    := (AccessFlags And ACC_SYNTHETIC) <> 0;
    
    { Lire les attributs de la methode }
    ReadMethodAttributes(Methods[I]);
  End;
End;

{ --- TODO 06 : Obtenir le numero de ligne pour un PC donne --- }
Function GetLineNumber(Var M: TMethodInfo; PC: Word): Integer;
Var
  I: Integer;
  BestLine, BestPC: Integer;
Begin
  If M.LineCount = 0 Then Begin
    GetLineNumber := -1;
    Exit;
  End;
  
  BestLine := -1;
  BestPC := -1;
  
  { Trouver l'entree avec le plus grand StartPC <= PC }
  For I := 0 to M.LineCount - 1 Do Begin
    If (M.LineTable[I].StartPC <= PC) And
       (Integer(M.LineTable[I].StartPC) > BestPC) Then Begin
      BestPC := M.LineTable[I].StartPC;
      BestLine := M.LineTable[I].LineNum;
    End;
  End;
  
  GetLineNumber := BestLine;
End;

{ --- TODO 06 : Obtenir la chaine des modificateurs d'une methode --- }
Function GetMethodAccessStr(Var M: TMethodInfo): String;
Var
  S: String;
Begin
  S := '';
  If M.IsPublic Then S := S + 'public '
  Else If M.IsPrivate Then S := S + 'private '
  Else If M.IsProtected Then S := S + 'protected ';
  
  If M.IsStatic Then S := S + 'static ';
  If M.IsFinal Then S := S + 'final ';
  If M.IsSynchronized Then S := S + 'synchronized ';
  If M.IsNative Then S := S + 'native ';
  If M.IsAbstract Then S := S + 'abstract ';
  If M.IsStrict Then S := S + 'strictfp ';
  
  GetMethodAccessStr := S;
End;

{ --- TODO 06 : Afficher une methode en notation Java --- }
Function MethodToJavaString(Var M: TMethodInfo): String;
Var
  S: String;
  I: Integer;
Begin
  S := GetMethodAccessStr(M) + M.JavaSignature;
  
  { Ajouter les exceptions throws }
  If M.ThrowsCount > 0 Then Begin
    S := S + ' throws ';
    For I := 0 to M.ThrowsCount - 1 Do Begin
      If I > 0 Then S := S + ', ';
      S := S + M.Throws[I];
    End;
  End;
  
  MethodToJavaString := S;
End;

{ --- TODO 06 : Afficher les informations de debug des methodes --- }
Procedure DumpMethods;
Var
  I, J: Integer;
  FlagStr: String;
Begin
  WriteLn('=== Methods (', MethodCount, ') ===');
  
  For I := 0 to MethodCount - 1 Do Begin
    WriteLn('Method #', I, ':');
    WriteLn('  Name:       ', Methods[I].Name);
    WriteLn('  Descriptor: ', Methods[I].Descriptor);
    WriteLn('  Signature:  ', Methods[I].JavaSignature);
    
    { Construire la chaine des flags }
    FlagStr := '';
    If Methods[I].IsPublic Then FlagStr := FlagStr + 'public ';
    If Methods[I].IsPrivate Then FlagStr := FlagStr + 'private ';
    If Methods[I].IsProtected Then FlagStr := FlagStr + 'protected ';
    If Methods[I].IsStatic Then FlagStr := FlagStr + 'static ';
    If Methods[I].IsFinal Then FlagStr := FlagStr + 'final ';
    If Methods[I].IsSynchronized Then FlagStr := FlagStr + 'synchronized ';
    If Methods[I].IsNative Then FlagStr := FlagStr + 'native ';
    If Methods[I].IsAbstract Then FlagStr := FlagStr + 'abstract ';
    If Methods[I].IsStrict Then FlagStr := FlagStr + 'strictfp ';
    If Methods[I].IsBridge Then FlagStr := FlagStr + 'bridge ';
    If Methods[I].IsVarArgs Then FlagStr := FlagStr + 'varargs ';
    If Methods[I].IsSynthetic Then FlagStr := FlagStr + 'synthetic ';
    
    WriteLn('  Flags:      ', FlagStr, '($', HexWord(Methods[I].AccessFlags), ')');
    
    If Not Methods[I].IsNative And Not Methods[I].IsAbstract Then Begin
      WriteLn('  MaxStack:   ', Methods[I].MaxStack);
      WriteLn('  MaxLocals:  ', Methods[I].MaxLocals);
      WriteLn('  CodeLen:    ', Methods[I].CodeLen, ' bytes');
      WriteLn('  ExcTable:   ', Methods[I].ExcCount, ' entries');
      WriteLn('  LineTable:  ', Methods[I].LineCount, ' entries');
      WriteLn('  LocalVars:  ', Methods[I].LocalCount, ' entries');
    End;
    
    If Methods[I].ThrowsCount > 0 Then Begin
      Write('  Throws:     ');
      For J := 0 to Methods[I].ThrowsCount - 1 Do Begin
        If J > 0 Then Write(', ');
        Write(Methods[I].Throws[J]);
      End;
      WriteLn;
    End;
    
    If Methods[I].IsDeprecated Then
      WriteLn('  Deprecated: true');
    If Methods[I].Signature <> '' Then
      WriteLn('  GenSig:     ', Methods[I].Signature);
    
    WriteLn('  Java:       ', MethodToJavaString(Methods[I]));
    WriteLn;
  End;
End;

{ --- TODO 06 : Liberer la memoire allouee pour le bytecode --- }
Procedure FreeMethods;
Var
  I: Integer;
Begin
  For I := 0 to MethodCount - 1 Do Begin
    If Methods[I].Code <> Nil Then Begin
      FreeMem(Methods[I].Code, Methods[I].CodeLen);
      Methods[I].Code := Nil;
    End;
  End;
  MethodCount := 0;
End;

{ ============================================================================ }
{ TODO 07 [IMPLEMENTE] - Decodage du bytecode Java (opcodes JVM)               }
{ ============================================================================ }

{ --- TODO 07 : Allouer la memoire pour les instructions --- }
Procedure AllocInstructions;
Begin
  If Instructions = Nil Then Begin
    GetMem(Instructions, SizeOf(TInstrArray));
  End;
  InstrCount := 0;
End;

{ --- TODO 07 : Liberer la memoire des instructions --- }
Procedure FreeInstructions;
Begin
  If Instructions <> Nil Then Begin
    FreeMem(Instructions, SizeOf(TInstrArray));
    Instructions := Nil;
  End;
  InstrCount := 0;
End;

{ --- TODO 07 : Retourner le mnemonique textuel d'un opcode --- }
Function GetInstrMnemonic(Op: Byte): String;
Begin
  Case Op Of
    { Constantes }
    OP_NOP:           GetInstrMnemonic := 'nop';
    OP_ACONST_NULL:   GetInstrMnemonic := 'aconst_null';
    OP_ICONST_M1:     GetInstrMnemonic := 'iconst_m1';
    OP_ICONST_0:      GetInstrMnemonic := 'iconst_0';
    OP_ICONST_1:      GetInstrMnemonic := 'iconst_1';
    OP_ICONST_2:      GetInstrMnemonic := 'iconst_2';
    OP_ICONST_3:      GetInstrMnemonic := 'iconst_3';
    OP_ICONST_4:      GetInstrMnemonic := 'iconst_4';
    OP_ICONST_5:      GetInstrMnemonic := 'iconst_5';
    OP_LCONST_0:      GetInstrMnemonic := 'lconst_0';
    OP_LCONST_1:      GetInstrMnemonic := 'lconst_1';
    OP_FCONST_0:      GetInstrMnemonic := 'fconst_0';
    OP_FCONST_1:      GetInstrMnemonic := 'fconst_1';
    OP_FCONST_2:      GetInstrMnemonic := 'fconst_2';
    OP_DCONST_0:      GetInstrMnemonic := 'dconst_0';
    OP_DCONST_1:      GetInstrMnemonic := 'dconst_1';
    OP_BIPUSH:        GetInstrMnemonic := 'bipush';
    OP_SIPUSH:        GetInstrMnemonic := 'sipush';
    OP_LDC:           GetInstrMnemonic := 'ldc';
    OP_LDC_W:         GetInstrMnemonic := 'ldc_w';
    OP_LDC2_W:        GetInstrMnemonic := 'ldc2_w';
    
    { Chargement variables locales }
    OP_ILOAD:         GetInstrMnemonic := 'iload';
    OP_LLOAD:         GetInstrMnemonic := 'lload';
    OP_FLOAD:         GetInstrMnemonic := 'fload';
    OP_DLOAD:         GetInstrMnemonic := 'dload';
    OP_ALOAD:         GetInstrMnemonic := 'aload';
    OP_ILOAD_0:       GetInstrMnemonic := 'iload_0';
    OP_ILOAD_1:       GetInstrMnemonic := 'iload_1';
    OP_ILOAD_2:       GetInstrMnemonic := 'iload_2';
    OP_ILOAD_3:       GetInstrMnemonic := 'iload_3';
    OP_LLOAD_0:       GetInstrMnemonic := 'lload_0';
    OP_LLOAD_1:       GetInstrMnemonic := 'lload_1';
    OP_LLOAD_2:       GetInstrMnemonic := 'lload_2';
    OP_LLOAD_3:       GetInstrMnemonic := 'lload_3';
    OP_FLOAD_0:       GetInstrMnemonic := 'fload_0';
    OP_FLOAD_1:       GetInstrMnemonic := 'fload_1';
    OP_FLOAD_2:       GetInstrMnemonic := 'fload_2';
    OP_FLOAD_3:       GetInstrMnemonic := 'fload_3';
    OP_DLOAD_0:       GetInstrMnemonic := 'dload_0';
    OP_DLOAD_1:       GetInstrMnemonic := 'dload_1';
    OP_DLOAD_2:       GetInstrMnemonic := 'dload_2';
    OP_DLOAD_3:       GetInstrMnemonic := 'dload_3';
    OP_ALOAD_0:       GetInstrMnemonic := 'aload_0';
    OP_ALOAD_1:       GetInstrMnemonic := 'aload_1';
    OP_ALOAD_2:       GetInstrMnemonic := 'aload_2';
    OP_ALOAD_3:       GetInstrMnemonic := 'aload_3';
    
    { Chargement depuis tableau }
    OP_IALOAD:        GetInstrMnemonic := 'iaload';
    OP_LALOAD:        GetInstrMnemonic := 'laload';
    OP_FALOAD:        GetInstrMnemonic := 'faload';
    OP_DALOAD:        GetInstrMnemonic := 'daload';
    OP_AALOAD:        GetInstrMnemonic := 'aaload';
    OP_BALOAD:        GetInstrMnemonic := 'baload';
    OP_CALOAD:        GetInstrMnemonic := 'caload';
    OP_SALOAD:        GetInstrMnemonic := 'saload';
    
    { Stockage variables locales }
    OP_ISTORE:        GetInstrMnemonic := 'istore';
    OP_LSTORE:        GetInstrMnemonic := 'lstore';
    OP_FSTORE:        GetInstrMnemonic := 'fstore';
    OP_DSTORE:        GetInstrMnemonic := 'dstore';
    OP_ASTORE:        GetInstrMnemonic := 'astore';
    OP_ISTORE_0:      GetInstrMnemonic := 'istore_0';
    OP_ISTORE_1:      GetInstrMnemonic := 'istore_1';
    OP_ISTORE_2:      GetInstrMnemonic := 'istore_2';
    OP_ISTORE_3:      GetInstrMnemonic := 'istore_3';
    OP_LSTORE_0:      GetInstrMnemonic := 'lstore_0';
    OP_LSTORE_1:      GetInstrMnemonic := 'lstore_1';
    OP_LSTORE_2:      GetInstrMnemonic := 'lstore_2';
    OP_LSTORE_3:      GetInstrMnemonic := 'lstore_3';
    OP_FSTORE_0:      GetInstrMnemonic := 'fstore_0';
    OP_FSTORE_1:      GetInstrMnemonic := 'fstore_1';
    OP_FSTORE_2:      GetInstrMnemonic := 'fstore_2';
    OP_FSTORE_3:      GetInstrMnemonic := 'fstore_3';
    OP_DSTORE_0:      GetInstrMnemonic := 'dstore_0';
    OP_DSTORE_1:      GetInstrMnemonic := 'dstore_1';
    OP_DSTORE_2:      GetInstrMnemonic := 'dstore_2';
    OP_DSTORE_3:      GetInstrMnemonic := 'dstore_3';
    OP_ASTORE_0:      GetInstrMnemonic := 'astore_0';
    OP_ASTORE_1:      GetInstrMnemonic := 'astore_1';
    OP_ASTORE_2:      GetInstrMnemonic := 'astore_2';
    OP_ASTORE_3:      GetInstrMnemonic := 'astore_3';
    
    { Stockage dans tableau }
    OP_IASTORE:       GetInstrMnemonic := 'iastore';
    OP_LASTORE:       GetInstrMnemonic := 'lastore';
    OP_FASTORE:       GetInstrMnemonic := 'fastore';
    OP_DASTORE:       GetInstrMnemonic := 'dastore';
    OP_AASTORE:       GetInstrMnemonic := 'aastore';
    OP_BASTORE:       GetInstrMnemonic := 'bastore';
    OP_CASTORE:       GetInstrMnemonic := 'castore';
    OP_SASTORE:       GetInstrMnemonic := 'sastore';
    
    { Manipulation de pile }
    OP_POP:           GetInstrMnemonic := 'pop';
    OP_POP2:          GetInstrMnemonic := 'pop2';
    OP_DUP:           GetInstrMnemonic := 'dup';
    OP_DUP_X1:        GetInstrMnemonic := 'dup_x1';
    OP_DUP_X2:        GetInstrMnemonic := 'dup_x2';
    OP_DUP2:          GetInstrMnemonic := 'dup2';
    OP_DUP2_X1:       GetInstrMnemonic := 'dup2_x1';
    OP_DUP2_X2:       GetInstrMnemonic := 'dup2_x2';
    OP_SWAP:          GetInstrMnemonic := 'swap';
    
    { Arithmetique }
    OP_IADD:          GetInstrMnemonic := 'iadd';
    OP_LADD:          GetInstrMnemonic := 'ladd';
    OP_FADD:          GetInstrMnemonic := 'fadd';
    OP_DADD:          GetInstrMnemonic := 'dadd';
    OP_ISUB:          GetInstrMnemonic := 'isub';
    OP_LSUB:          GetInstrMnemonic := 'lsub';
    OP_FSUB:          GetInstrMnemonic := 'fsub';
    OP_DSUB:          GetInstrMnemonic := 'dsub';
    OP_IMUL:          GetInstrMnemonic := 'imul';
    OP_LMUL:          GetInstrMnemonic := 'lmul';
    OP_FMUL:          GetInstrMnemonic := 'fmul';
    OP_DMUL:          GetInstrMnemonic := 'dmul';
    OP_IDIV:          GetInstrMnemonic := 'idiv';
    OP_LDIV:          GetInstrMnemonic := 'ldiv';
    OP_FDIV:          GetInstrMnemonic := 'fdiv';
    OP_DDIV:          GetInstrMnemonic := 'ddiv';
    OP_IREM:          GetInstrMnemonic := 'irem';
    OP_LREM:          GetInstrMnemonic := 'lrem';
    OP_FREM:          GetInstrMnemonic := 'frem';
    OP_DREM:          GetInstrMnemonic := 'drem';
    OP_INEG:          GetInstrMnemonic := 'ineg';
    OP_LNEG:          GetInstrMnemonic := 'lneg';
    OP_FNEG:          GetInstrMnemonic := 'fneg';
    OP_DNEG:          GetInstrMnemonic := 'dneg';
    OP_ISHL:          GetInstrMnemonic := 'ishl';
    OP_LSHL:          GetInstrMnemonic := 'lshl';
    OP_ISHR:          GetInstrMnemonic := 'ishr';
    OP_LSHR:          GetInstrMnemonic := 'lshr';
    OP_IUSHR:         GetInstrMnemonic := 'iushr';
    OP_LUSHR:         GetInstrMnemonic := 'lushr';
    OP_IAND:          GetInstrMnemonic := 'iand';
    OP_LAND:          GetInstrMnemonic := 'land';
    OP_IOR:           GetInstrMnemonic := 'ior';
    OP_LOR:           GetInstrMnemonic := 'lor';
    OP_IXOR:          GetInstrMnemonic := 'ixor';
    OP_LXOR:          GetInstrMnemonic := 'lxor';
    OP_IINC:          GetInstrMnemonic := 'iinc';
    
    { Conversion }
    OP_I2L:           GetInstrMnemonic := 'i2l';
    OP_I2F:           GetInstrMnemonic := 'i2f';
    OP_I2D:           GetInstrMnemonic := 'i2d';
    OP_L2I:           GetInstrMnemonic := 'l2i';
    OP_L2F:           GetInstrMnemonic := 'l2f';
    OP_L2D:           GetInstrMnemonic := 'l2d';
    OP_F2I:           GetInstrMnemonic := 'f2i';
    OP_F2L:           GetInstrMnemonic := 'f2l';
    OP_F2D:           GetInstrMnemonic := 'f2d';
    OP_D2I:           GetInstrMnemonic := 'd2i';
    OP_D2L:           GetInstrMnemonic := 'd2l';
    OP_D2F:           GetInstrMnemonic := 'd2f';
    OP_I2B:           GetInstrMnemonic := 'i2b';
    OP_I2C:           GetInstrMnemonic := 'i2c';
    OP_I2S:           GetInstrMnemonic := 'i2s';
    
    { Comparaison }
    OP_LCMP:          GetInstrMnemonic := 'lcmp';
    OP_FCMPL:         GetInstrMnemonic := 'fcmpl';
    OP_FCMPG:         GetInstrMnemonic := 'fcmpg';
    OP_DCMPL:         GetInstrMnemonic := 'dcmpl';
    OP_DCMPG:         GetInstrMnemonic := 'dcmpg';
    
    { Branchement conditionnel }
    OP_IFEQ:          GetInstrMnemonic := 'ifeq';
    OP_IFNE:          GetInstrMnemonic := 'ifne';
    OP_IFLT:          GetInstrMnemonic := 'iflt';
    OP_IFGE:          GetInstrMnemonic := 'ifge';
    OP_IFGT:          GetInstrMnemonic := 'ifgt';
    OP_IFLE:          GetInstrMnemonic := 'ifle';
    OP_IF_ICMPEQ:     GetInstrMnemonic := 'if_icmpeq';
    OP_IF_ICMPNE:     GetInstrMnemonic := 'if_icmpne';
    OP_IF_ICMPLT:     GetInstrMnemonic := 'if_icmplt';
    OP_IF_ICMPGE:     GetInstrMnemonic := 'if_icmpge';
    OP_IF_ICMPGT:     GetInstrMnemonic := 'if_icmpgt';
    OP_IF_ICMPLE:     GetInstrMnemonic := 'if_icmple';
    OP_IF_ACMPEQ:     GetInstrMnemonic := 'if_acmpeq';
    OP_IF_ACMPNE:     GetInstrMnemonic := 'if_acmpne';
    
    { Branchement inconditionnel }
    OP_GOTO:          GetInstrMnemonic := 'goto';
    OP_JSR:           GetInstrMnemonic := 'jsr';
    OP_RET:           GetInstrMnemonic := 'ret';
    OP_TABLESWITCH:   GetInstrMnemonic := 'tableswitch';
    OP_LOOKUPSWITCH:  GetInstrMnemonic := 'lookupswitch';
    
    { Retour }
    OP_IRETURN:       GetInstrMnemonic := 'ireturn';
    OP_LRETURN:       GetInstrMnemonic := 'lreturn';
    OP_FRETURN:       GetInstrMnemonic := 'freturn';
    OP_DRETURN:       GetInstrMnemonic := 'dreturn';
    OP_ARETURN:       GetInstrMnemonic := 'areturn';
    OP_RETURN:        GetInstrMnemonic := 'return';
    
    { Acces aux champs }
    OP_GETSTATIC:     GetInstrMnemonic := 'getstatic';
    OP_PUTSTATIC:     GetInstrMnemonic := 'putstatic';
    OP_GETFIELD:      GetInstrMnemonic := 'getfield';
    OP_PUTFIELD:      GetInstrMnemonic := 'putfield';
    
    { Invocation de methode }
    OP_INVOKEVIRTUAL:   GetInstrMnemonic := 'invokevirtual';
    OP_INVOKESPECIAL:   GetInstrMnemonic := 'invokespecial';
    OP_INVOKESTATIC:    GetInstrMnemonic := 'invokestatic';
    OP_INVOKEINTERFACE: GetInstrMnemonic := 'invokeinterface';
    OP_INVOKEDYNAMIC:   GetInstrMnemonic := 'invokedynamic';
    
    { Creation d'objets }
    OP_NEW:             GetInstrMnemonic := 'new';
    OP_NEWARRAY:        GetInstrMnemonic := 'newarray';
    OP_ANEWARRAY:       GetInstrMnemonic := 'anewarray';
    OP_ARRAYLENGTH:     GetInstrMnemonic := 'arraylength';
    
    { Exception et types }
    OP_ATHROW:          GetInstrMnemonic := 'athrow';
    OP_CHECKCAST:       GetInstrMnemonic := 'checkcast';
    OP_INSTANCEOF:      GetInstrMnemonic := 'instanceof';
    
    { Synchronisation }
    OP_MONITORENTER:    GetInstrMnemonic := 'monitorenter';
    OP_MONITOREXIT:     GetInstrMnemonic := 'monitorexit';
    
    { Speciaux }
    OP_WIDE:            GetInstrMnemonic := 'wide';
    OP_MULTIANEWARRAY:  GetInstrMnemonic := 'multianewarray';
    OP_IFNULL:          GetInstrMnemonic := 'ifnull';
    OP_IFNONNULL:       GetInstrMnemonic := 'ifnonnull';
    OP_GOTO_W:          GetInstrMnemonic := 'goto_w';
    OP_JSR_W:           GetInstrMnemonic := 'jsr_w';
    
    { Reserves }
    OP_BREAKPOINT:      GetInstrMnemonic := 'breakpoint';
    OP_IMPDEP1:         GetInstrMnemonic := 'impdep1';
    OP_IMPDEP2:         GetInstrMnemonic := 'impdep2';
    
  Else
    GetInstrMnemonic := 'unknown_' + IntToStr_(Op);
  End;
End;

{ --- TODO 07 : Lire un octet du bytecode a une position donnee --- }
Function GetCodeByte(Code: Pointer; Offset: LongWord): Byte;
Type
  TBytePtr = ^Byte;
Var
  P: TBytePtr;
Begin
  P := TBytePtr(PtrUInt(Code) + PtrUInt(Offset));
  GetCodeByte := P^;
End;

{ --- TODO 07 : Lire un short signe du bytecode (big-endian) --- }
Function GetCodeShort(Code: Pointer; Offset: LongWord): SmallInt;
Var
  Hi, Lo: Byte;
Begin
  Hi := GetCodeByte(Code, Offset);
  Lo := GetCodeByte(Code, Offset + 1);
  GetCodeShort := SmallInt(Word(Hi) shl 8 or Word(Lo));
End;

{ --- TODO 07 : Lire un word non signe du bytecode (big-endian) --- }
Function GetCodeWord(Code: Pointer; Offset: LongWord): Word;
Var
  Hi, Lo: Byte;
Begin
  Hi := GetCodeByte(Code, Offset);
  Lo := GetCodeByte(Code, Offset + 1);
  GetCodeWord := Word(Hi) shl 8 or Word(Lo);
End;

{ --- TODO 07 : Lire un int signe du bytecode (big-endian) --- }
Function GetCodeInt(Code: Pointer; Offset: LongWord): LongInt;
Var
  B1, B2, B3, B4: Byte;
Begin
  B1 := GetCodeByte(Code, Offset);
  B2 := GetCodeByte(Code, Offset + 1);
  B3 := GetCodeByte(Code, Offset + 2);
  B4 := GetCodeByte(Code, Offset + 3);
  GetCodeInt := LongInt(LongInt(B1) shl 24 or LongInt(B2) shl 16 or 
                        LongInt(B3) shl 8 or LongInt(B4));
End;

{ --- TODO 07 : Calculer la taille d'une instruction --- }
Function GetInstrSize(Op: Byte; PC: LongWord; Code: Pointer): Integer;
Var
  Padding, LowVal, HighVal, NPairs: LongInt;
  SubOp: Byte;
Begin
  Case Op Of
    { Instructions sans operande (1 octet) }
    OP_NOP, OP_ACONST_NULL, 
    OP_ICONST_M1, OP_ICONST_0, OP_ICONST_1, OP_ICONST_2, OP_ICONST_3, OP_ICONST_4, OP_ICONST_5,
    OP_LCONST_0, OP_LCONST_1,
    OP_FCONST_0, OP_FCONST_1, OP_FCONST_2,
    OP_DCONST_0, OP_DCONST_1,
    OP_ILOAD_0, OP_ILOAD_1, OP_ILOAD_2, OP_ILOAD_3,
    OP_LLOAD_0, OP_LLOAD_1, OP_LLOAD_2, OP_LLOAD_3,
    OP_FLOAD_0, OP_FLOAD_1, OP_FLOAD_2, OP_FLOAD_3,
    OP_DLOAD_0, OP_DLOAD_1, OP_DLOAD_2, OP_DLOAD_3,
    OP_ALOAD_0, OP_ALOAD_1, OP_ALOAD_2, OP_ALOAD_3,
    OP_IALOAD, OP_LALOAD, OP_FALOAD, OP_DALOAD, OP_AALOAD, OP_BALOAD, OP_CALOAD, OP_SALOAD,
    OP_ISTORE_0, OP_ISTORE_1, OP_ISTORE_2, OP_ISTORE_3,
    OP_LSTORE_0, OP_LSTORE_1, OP_LSTORE_2, OP_LSTORE_3,
    OP_FSTORE_0, OP_FSTORE_1, OP_FSTORE_2, OP_FSTORE_3,
    OP_DSTORE_0, OP_DSTORE_1, OP_DSTORE_2, OP_DSTORE_3,
    OP_ASTORE_0, OP_ASTORE_1, OP_ASTORE_2, OP_ASTORE_3,
    OP_IASTORE, OP_LASTORE, OP_FASTORE, OP_DASTORE, OP_AASTORE, OP_BASTORE, OP_CASTORE, OP_SASTORE,
    OP_POP, OP_POP2, OP_DUP, OP_DUP_X1, OP_DUP_X2, OP_DUP2, OP_DUP2_X1, OP_DUP2_X2, OP_SWAP,
    OP_IADD, OP_LADD, OP_FADD, OP_DADD, OP_ISUB, OP_LSUB, OP_FSUB, OP_DSUB,
    OP_IMUL, OP_LMUL, OP_FMUL, OP_DMUL, OP_IDIV, OP_LDIV, OP_FDIV, OP_DDIV,
    OP_IREM, OP_LREM, OP_FREM, OP_DREM, OP_INEG, OP_LNEG, OP_FNEG, OP_DNEG,
    OP_ISHL, OP_LSHL, OP_ISHR, OP_LSHR, OP_IUSHR, OP_LUSHR,
    OP_IAND, OP_LAND, OP_IOR, OP_LOR, OP_IXOR, OP_LXOR,
    OP_I2L, OP_I2F, OP_I2D, OP_L2I, OP_L2F, OP_L2D, OP_F2I, OP_F2L, OP_F2D,
    OP_D2I, OP_D2L, OP_D2F, OP_I2B, OP_I2C, OP_I2S,
    OP_LCMP, OP_FCMPL, OP_FCMPG, OP_DCMPL, OP_DCMPG,
    OP_IRETURN, OP_LRETURN, OP_FRETURN, OP_DRETURN, OP_ARETURN, OP_RETURN,
    OP_ARRAYLENGTH, OP_ATHROW, OP_MONITORENTER, OP_MONITOREXIT:
      GetInstrSize := 1;
    
    { Instructions avec 1 octet d'operande (2 octets total) }
    OP_BIPUSH, OP_LDC, 
    OP_ILOAD, OP_LLOAD, OP_FLOAD, OP_DLOAD, OP_ALOAD,
    OP_ISTORE, OP_LSTORE, OP_FSTORE, OP_DSTORE, OP_ASTORE,
    OP_RET, OP_NEWARRAY:
      GetInstrSize := 2;
    
    { Instructions avec 2 octets d'operande (3 octets total) }
    OP_SIPUSH, OP_LDC_W, OP_LDC2_W, OP_IINC,
    OP_IFEQ, OP_IFNE, OP_IFLT, OP_IFGE, OP_IFGT, OP_IFLE,
    OP_IF_ICMPEQ, OP_IF_ICMPNE, OP_IF_ICMPLT, OP_IF_ICMPGE, OP_IF_ICMPGT, OP_IF_ICMPLE,
    OP_IF_ACMPEQ, OP_IF_ACMPNE,
    OP_GOTO, OP_JSR,
    OP_GETSTATIC, OP_PUTSTATIC, OP_GETFIELD, OP_PUTFIELD,
    OP_INVOKEVIRTUAL, OP_INVOKESPECIAL, OP_INVOKESTATIC,
    OP_NEW, OP_ANEWARRAY, OP_CHECKCAST, OP_INSTANCEOF,
    OP_IFNULL, OP_IFNONNULL:
      GetInstrSize := 3;
    
    { Instructions avec 3+ octets d'operande }
    OP_MULTIANEWARRAY:
      GetInstrSize := 4;
    
    OP_INVOKEINTERFACE, OP_INVOKEDYNAMIC:
      GetInstrSize := 5;
    
    OP_GOTO_W, OP_JSR_W:
      GetInstrSize := 5;
    
    { wide : depend du sous-opcode }
    OP_WIDE: Begin
      SubOp := GetCodeByte(Code, PC + 1);
      If SubOp = OP_IINC Then
        GetInstrSize := 6  { wide iinc index const }
      Else
        GetInstrSize := 4; { wide load/store index }
    End;
    
    { tableswitch : taille variable avec padding }
    OP_TABLESWITCH: Begin
      { Padding pour aligner sur 4 octets }
      Padding := 4 - ((PC + 1) mod 4);
      If Padding = 4 Then Padding := 0;
      { Lire default (4), low (4), high (4) }
      LowVal := GetCodeInt(Code, PC + 1 + Padding + 4);
      HighVal := GetCodeInt(Code, PC + 1 + Padding + 8);
      { Taille = 1 + padding + 12 + (high - low + 1) * 4 }
      GetInstrSize := 1 + Padding + 12 + (HighVal - LowVal + 1) * 4;
    End;
    
    { lookupswitch : taille variable avec padding }
    OP_LOOKUPSWITCH: Begin
      { Padding pour aligner sur 4 octets }
      Padding := 4 - ((PC + 1) mod 4);
      If Padding = 4 Then Padding := 0;
      { Lire default (4), npairs (4) }
      NPairs := GetCodeInt(Code, PC + 1 + Padding + 4);
      { Taille = 1 + padding + 8 + npairs * 8 }
      GetInstrSize := 1 + Padding + 8 + NPairs * 8;
    End;
    
  Else
    { Opcode inconnu : on suppose 1 octet }
    GetInstrSize := 1;
  End;
End;

{ --- TODO 07 : Decoder les instructions d'une methode --- }
Procedure DecodeInstructions(Var M: TMethodInfo);
Var
  PC: LongWord;
  Op, SubOp: Byte;
  Size: Integer;
  Idx: Word;
  Instr: TInstruction;
  Padding, LowVal, HighVal, NPairs, DefOff: LongInt;
Begin
  If Instructions = Nil Then AllocInstructions;
  InstrCount := 0;
  
  If (M.Code = Nil) or (M.CodeLen = 0) Then Exit;
  
  PC := 0;
  While PC < M.CodeLen Do Begin
    If InstrCount >= MAX_INSTRUCTIONS Then Begin
      Warning('Trop d''instructions dans la methode ' + M.Name);
      Exit;
    End;
    
    Op := GetCodeByte(M.Code, PC);
    Size := GetInstrSize(Op, PC, M.Code);
    
    { Initialiser l'instruction }
    Instr.PC := PC;
    Instr.Opcode := Op;
    Instr.Mnemonic := GetInstrMnemonic(Op);
    Instr.Op1 := 0;
    Instr.Op2 := 0;
    Instr.Op3 := 0;
    Instr.Size := Size;
    Instr.CpRef := '';
    Instr.LineNum := GetLineNumber(M, PC);
    
    { Decoder les operandes selon l'opcode }
    Case Op Of
      { Operande byte signe }
      OP_BIPUSH:
        Instr.Op1 := ShortInt(GetCodeByte(M.Code, PC + 1));
      
      { Operande short signe }
      OP_SIPUSH:
        Instr.Op1 := GetCodeShort(M.Code, PC + 1);
      
      { Index CP 8-bit }
      OP_LDC:
        Instr.Op1 := GetCodeByte(M.Code, PC + 1);
      
      { Index CP 16-bit }
      OP_LDC_W, OP_LDC2_W, OP_NEW, OP_ANEWARRAY, OP_CHECKCAST, OP_INSTANCEOF: Begin
        Idx := GetCodeWord(M.Code, PC + 1);
        Instr.Op1 := Idx;
        Instr.CpRef := CPGetClassName(Idx);
      End;
      
      { Index variable locale 8-bit }
      OP_ILOAD, OP_LLOAD, OP_FLOAD, OP_DLOAD, OP_ALOAD,
      OP_ISTORE, OP_LSTORE, OP_FSTORE, OP_DSTORE, OP_ASTORE,
      OP_RET:
        Instr.Op1 := GetCodeByte(M.Code, PC + 1);
      
      { iinc : index + const }
      OP_IINC: Begin
        Instr.Op1 := GetCodeByte(M.Code, PC + 1);      { index }
        Instr.Op2 := ShortInt(GetCodeByte(M.Code, PC + 2)); { const }
      End;
      
      { newarray : type primitif }
      OP_NEWARRAY:
        Instr.Op1 := GetCodeByte(M.Code, PC + 1);
      
      { Branchement conditionnel/inconditionnel 16-bit }
      OP_IFEQ, OP_IFNE, OP_IFLT, OP_IFGE, OP_IFGT, OP_IFLE,
      OP_IF_ICMPEQ, OP_IF_ICMPNE, OP_IF_ICMPLT, OP_IF_ICMPGE, OP_IF_ICMPGT, OP_IF_ICMPLE,
      OP_IF_ACMPEQ, OP_IF_ACMPNE, OP_IFNULL, OP_IFNONNULL,
      OP_GOTO, OP_JSR:
        Instr.Op1 := LongInt(PC) + GetCodeShort(M.Code, PC + 1);
      
      { Branchement 32-bit }
      OP_GOTO_W, OP_JSR_W:
        Instr.Op1 := LongInt(PC) + GetCodeInt(M.Code, PC + 1);
      
      { Acces aux champs }
      OP_GETSTATIC, OP_PUTSTATIC, OP_GETFIELD, OP_PUTFIELD: Begin
        Idx := GetCodeWord(M.Code, PC + 1);
        Instr.Op1 := Idx;
        Instr.CpRef := CPGetMemberRefStr(Idx);
      End;
      
      { Invocation de methode }
      OP_INVOKEVIRTUAL, OP_INVOKESPECIAL, OP_INVOKESTATIC: Begin
        Idx := GetCodeWord(M.Code, PC + 1);
        Instr.Op1 := Idx;
        Instr.CpRef := CPGetMemberRefStr(Idx);
      End;
      
      OP_INVOKEINTERFACE: Begin
        Idx := GetCodeWord(M.Code, PC + 1);
        Instr.Op1 := Idx;
        Instr.Op2 := GetCodeByte(M.Code, PC + 3);  { count }
        Instr.CpRef := CPGetMemberRefStr(Idx);
      End;
      
      OP_INVOKEDYNAMIC: Begin
        Idx := GetCodeWord(M.Code, PC + 1);
        Instr.Op1 := Idx;
        { 2 octets de zeros apres }
      End;
      
      { multianewarray }
      OP_MULTIANEWARRAY: Begin
        Idx := GetCodeWord(M.Code, PC + 1);
        Instr.Op1 := Idx;
        Instr.Op2 := GetCodeByte(M.Code, PC + 3);  { dimensions }
        Instr.CpRef := CPGetClassName(Idx);
      End;
      
      { wide }
      OP_WIDE: Begin
        SubOp := GetCodeByte(M.Code, PC + 1);
        Instr.Mnemonic := 'wide ' + GetInstrMnemonic(SubOp);
        Instr.Op1 := GetCodeWord(M.Code, PC + 2);  { index }
        If SubOp = OP_IINC Then
          Instr.Op2 := GetCodeShort(M.Code, PC + 4); { const }
      End;
      
      { tableswitch }
      OP_TABLESWITCH: Begin
        Padding := 4 - ((PC + 1) mod 4);
        If Padding = 4 Then Padding := 0;
        DefOff := GetCodeInt(M.Code, PC + 1 + Padding);
        LowVal := GetCodeInt(M.Code, PC + 1 + Padding + 4);
        HighVal := GetCodeInt(M.Code, PC + 1 + Padding + 8);
        Instr.Op1 := LowVal;
        Instr.Op2 := HighVal;
        Instr.Op3 := LongInt(PC) + DefOff;
      End;
      
      { lookupswitch }
      OP_LOOKUPSWITCH: Begin
        Padding := 4 - ((PC + 1) mod 4);
        If Padding = 4 Then Padding := 0;
        DefOff := GetCodeInt(M.Code, PC + 1 + Padding);
        NPairs := GetCodeInt(M.Code, PC + 1 + Padding + 4);
        Instr.Op1 := NPairs;
        Instr.Op2 := LongInt(PC) + DefOff;
      End;
    End;
    
    { Ajouter l'instruction au tableau }
    Instructions^[InstrCount] := Instr;
    Inc(InstrCount);
    
    { Avancer au prochain opcode }
    PC := PC + LongWord(Size);
  End;
End;

{ --- TODO 07 : Afficher les instructions decodees --- }
Procedure DumpInstructions;
Var
  I: Integer;
  Instr: TInstruction;
Begin
  WriteLn('=== Instructions decodees (', InstrCount, ') ===');
  For I := 0 to InstrCount - 1 Do Begin
    Instr := Instructions^[I];
    Write(HexWord(Word(Instr.PC)), ': ', Instr.Mnemonic);
    
    Case Instr.Opcode Of
      OP_BIPUSH, OP_SIPUSH,
      OP_ILOAD, OP_LLOAD, OP_FLOAD, OP_DLOAD, OP_ALOAD,
      OP_ISTORE, OP_LSTORE, OP_FSTORE, OP_DSTORE, OP_ASTORE,
      OP_RET, OP_NEWARRAY, OP_LDC:
        Write(' ', Instr.Op1);
      
      OP_IINC:
        Write(' ', Instr.Op1, ' ', Instr.Op2);
      
      OP_IFEQ, OP_IFNE, OP_IFLT, OP_IFGE, OP_IFGT, OP_IFLE,
      OP_IF_ICMPEQ, OP_IF_ICMPNE, OP_IF_ICMPLT, OP_IF_ICMPGE, OP_IF_ICMPGT, OP_IF_ICMPLE,
      OP_IF_ACMPEQ, OP_IF_ACMPNE, OP_IFNULL, OP_IFNONNULL,
      OP_GOTO, OP_JSR, OP_GOTO_W, OP_JSR_W:
        Write(' -> ', HexWord(Word(Instr.Op1)));
      
      OP_LDC_W, OP_LDC2_W, OP_NEW, OP_ANEWARRAY, OP_CHECKCAST, OP_INSTANCEOF,
      OP_GETSTATIC, OP_PUTSTATIC, OP_GETFIELD, OP_PUTFIELD,
      OP_INVOKEVIRTUAL, OP_INVOKESPECIAL, OP_INVOKESTATIC:
        Write(' #', Instr.Op1, ' // ', Instr.CpRef);
      
      OP_INVOKEINTERFACE:
        Write(' #', Instr.Op1, ' ', Instr.Op2, ' // ', Instr.CpRef);
      
      OP_MULTIANEWARRAY:
        Write(' #', Instr.Op1, ' ', Instr.Op2, ' // ', Instr.CpRef);
      
      OP_TABLESWITCH:
        Write(' low=', Instr.Op1, ' high=', Instr.Op2, ' default=', HexWord(Word(Instr.Op3)));
      
      OP_LOOKUPSWITCH:
        Write(' npairs=', Instr.Op1, ' default=', HexWord(Word(Instr.Op2)));
    End;
    
    If Instr.LineNum > 0 Then
      Write(' ; line ', Instr.LineNum);
    
    WriteLn;
  End;
  WriteLn;
End;

{ --- TODO 07 : Verifier si un opcode est un test de null --- }
Function IsNullCheckOpcode(Op: Byte): Boolean;
Begin
  IsNullCheckOpcode := (Op = OP_IFNULL) or (Op = OP_IFNONNULL) or
                       (Op = OP_IF_ACMPEQ) or (Op = OP_IF_ACMPNE);
End;

{ --- TODO 07 : Verifier si un opcode est un branchement --- }
Function IsBranchOpcode(Op: Byte): Boolean;
Begin
  IsBranchOpcode := (Op >= OP_IFEQ) and (Op <= OP_JSR) or
                    (Op = OP_TABLESWITCH) or (Op = OP_LOOKUPSWITCH) or
                    (Op >= OP_IFNULL) and (Op <= OP_JSR_W);
End;

{ --- TODO 07 : Verifier si un opcode termine un bloc de base --- }
Function IsBlockTerminator(Op: Byte): Boolean;
Begin
  IsBlockTerminator := (Op >= OP_IRETURN) and (Op <= OP_RETURN) or
                       (Op = OP_ATHROW) or (Op = OP_GOTO) or (Op = OP_GOTO_W) or
                       (Op = OP_TABLESWITCH) or (Op = OP_LOOKUPSWITCH) or
                       (Op = OP_RET);
End;

{ --- TODO 07 : Verifier si un opcode peut dereference null --- }
Function CanDereferenceNull(Op: Byte): Boolean;
Begin
  CanDereferenceNull := (Op = OP_GETFIELD) or (Op = OP_PUTFIELD) or
                        (Op = OP_INVOKEVIRTUAL) or (Op = OP_INVOKESPECIAL) or
                        (Op = OP_INVOKEINTERFACE) or
                        (Op = OP_ARRAYLENGTH) or (Op = OP_ATHROW) or
                        (Op = OP_MONITORENTER) or (Op = OP_MONITOREXIT) or
                        (Op >= OP_IALOAD) and (Op <= OP_SALOAD) or
                        (Op >= OP_IASTORE) and (Op <= OP_SASTORE);
End;

{ --- TODO 07 : Obtenir le nom du type primitif pour newarray --- }
Function GetArrayTypeName(AType: Byte): String;
Begin
  Case AType Of
    4:  GetArrayTypeName := 'boolean';
    5:  GetArrayTypeName := 'char';
    6:  GetArrayTypeName := 'float';
    7:  GetArrayTypeName := 'double';
    8:  GetArrayTypeName := 'byte';
    9:  GetArrayTypeName := 'short';
    10: GetArrayTypeName := 'int';
    11: GetArrayTypeName := 'long';
  Else
    GetArrayTypeName := 'unknown[' + IntToStr_(AType) + ']';
  End;
End;

{ ============================================================================ }
{ TODO 08 [IMPLEMENTE] - Construction du graphe de flux de controle (CFG)      }
{ ============================================================================ }

{ --- TODO 08 : Initialiser un noeud CFG --- }
Procedure InitCFGNode(Var N: TCFGNode);
Var
  J: Integer;
Begin
  N.ID := -1;
  N.StartPC := 0;
  N.EndPC := 0;
  N.InstStart := -1;
  N.InstEnd := -1;
  For J := 0 to MAX_CFG_SUCCS - 1 Do N.Succs[J] := -1;
  N.SuccCount := 0;
  For J := 0 to MAX_CFG_PREDS - 1 Do N.Preds[J] := -1;
  N.PredCount := 0;
  N.IsEntry := False;
  N.IsExit := False;
  N.IsException := False;
  N.Visited := False;
  N.DomBy := -1;
  N.IsBackEdge := False;
End;

{ --- TODO 08 : Allouer le tableau CFG --- }
Procedure AllocCFG;
Begin
  If CFGNodes = Nil Then Begin
    GetMem(CFGNodes, SizeOf(TCFGArray));
    CFGNodeCount := 0;
    CFGUnreachable := 0;
    CFGBackEdges := 0;
  End;
End;

{ --- TODO 08 : Liberer le tableau CFG --- }
Procedure FreeCFG;
Begin
  If CFGNodes <> Nil Then Begin
    FreeMem(CFGNodes, SizeOf(TCFGArray));
    CFGNodes := Nil;
    CFGNodeCount := 0;
    CFGUnreachable := 0;
    CFGBackEdges := 0;
  End;
End;

{ --- TODO 08 : Ajouter un successeur a un noeud CFG --- }
Procedure AddCFGSuccessor(Var N: TCFGNode; SuccIdx: Integer);
Begin
  If (N.SuccCount < MAX_CFG_SUCCS) and (SuccIdx >= 0) Then Begin
    N.Succs[N.SuccCount] := SuccIdx;
    Inc(N.SuccCount);
  End;
End;

{ --- TODO 08 : Ajouter un predecesseur a un noeud CFG --- }
Procedure AddCFGPredecessor(Var N: TCFGNode; PredIdx: Integer);
Begin
  If (N.PredCount < MAX_CFG_PREDS) and (PredIdx >= 0) Then Begin
    N.Preds[N.PredCount] := PredIdx;
    Inc(N.PredCount);
  End;
End;

{ --- TODO 08 : Verifier si un PC est cible d'un branchement conditionnel --- }
Function IsBranchTarget(PC: LongWord): Boolean;
Var
  I: Integer;
  Op: Byte;
  Target: LongInt;
Begin
  IsBranchTarget := False;
  If Instructions = Nil Then Exit;
  
  For I := 0 to InstrCount - 1 Do Begin
    Op := Instructions^[I].Opcode;
    { Branchements conditionnels et inconditionnels }
    If (Op >= OP_IFEQ) and (Op <= OP_IF_ACMPNE) Then Begin
      Target := LongInt(Instructions^[I].PC) + Instructions^[I].Op1;
      If LongWord(Target) = PC Then Begin
        IsBranchTarget := True;
        Exit;
      End;
    End
    Else If (Op = OP_GOTO) or (Op = OP_GOTO_W) Then Begin
      Target := LongInt(Instructions^[I].PC) + Instructions^[I].Op1;
      If LongWord(Target) = PC Then Begin
        IsBranchTarget := True;
        Exit;
      End;
    End
    Else If (Op = OP_IFNULL) or (Op = OP_IFNONNULL) Then Begin
      Target := LongInt(Instructions^[I].PC) + Instructions^[I].Op1;
      If LongWord(Target) = PC Then Begin
        IsBranchTarget := True;
        Exit;
      End;
    End
    Else If (Op = OP_JSR) or (Op = OP_JSR_W) Then Begin
      Target := LongInt(Instructions^[I].PC) + Instructions^[I].Op1;
      If LongWord(Target) = PC Then Begin
        IsBranchTarget := True;
        Exit;
      End;
    End;
  End;
End;

{ --- TODO 08 : Verifier si un PC est debut de gestionnaire d'exception --- }
Function IsExceptionHandler(Var M: TMethodInfo; PC: LongWord): Boolean;
Var
  E: Integer;
Begin
  IsExceptionHandler := False;
  For E := 0 to M.ExcCount - 1 Do Begin
    If M.ExcTable[E].HandlerPC = PC Then Begin
      IsExceptionHandler := True;
      Exit;
    End;
  End;
End;

{ --- TODO 08 : Verifier si une instruction termine un bloc (terminateur) --- }
Function IsBlockTerminator_(Op: Byte): Boolean;
Begin
  IsBlockTerminator_ := (Op >= OP_IFEQ) and (Op <= OP_IF_ACMPNE)   { cond branches }
                     or (Op = OP_GOTO) or (Op = OP_GOTO_W)        { uncond jumps }
                     or (Op = OP_JSR) or (Op = OP_JSR_W)          { subroutines }
                     or (Op = OP_RET)                              { return from sub }
                     or (Op >= OP_IRETURN) and (Op <= OP_RETURN)  { returns }
                     or (Op = OP_ATHROW)                           { throw }
                     or (Op = OP_TABLESWITCH)                      { switch }
                     or (Op = OP_LOOKUPSWITCH)                     { switch }
                     or (Op = OP_IFNULL) or (Op = OP_IFNONNULL);   { null checks }
End;

{ --- TODO 08 : Verifier si un opcode est un saut inconditionnel --- }
Function IsUnconditionalJump(Op: Byte): Boolean;
Begin
  IsUnconditionalJump := (Op = OP_GOTO) or (Op = OP_GOTO_W)
                      or (Op >= OP_IRETURN) and (Op <= OP_RETURN)
                      or (Op = OP_ATHROW)
                      or (Op = OP_RET);
End;

{ --- TODO 08 : Verifier si un PC est un leader de bloc de base --- }
Function IsBlockLeader(Var M: TMethodInfo; PC: LongWord): Boolean;
Begin
  { PC=0 est toujours le point d'entree }
  If PC = 0 Then Begin
    IsBlockLeader := True;
    Exit;
  End;
  
  { Cible de branchement }
  If IsBranchTarget(PC) Then Begin
    IsBlockLeader := True;
    Exit;
  End;
  
  { Debut de gestionnaire d'exception }
  If IsExceptionHandler(M, PC) Then Begin
    IsBlockLeader := True;
    Exit;
  End;
  
  IsBlockLeader := False;
End;

{ --- TODO 08 : Trouver l'index du noeud CFG contenant un PC --- }
Function FindCFGNodeByPC(PC: LongWord): Integer;
Var
  I: Integer;
Begin
  FindCFGNodeByPC := -1;
  If CFGNodes = Nil Then Exit;
  
  For I := 0 to CFGNodeCount - 1 Do Begin
    If (PC >= CFGNodes^[I].StartPC) and (PC <= CFGNodes^[I].EndPC) Then Begin
      FindCFGNodeByPC := I;
      Exit;
    End;
  End;
End;

{ --- TODO 08 : Trouver l'index du noeud CFG commencant a un PC --- }
Function FindCFGNodeByStartPC(PC: LongWord): Integer;
Var
  I: Integer;
Begin
  FindCFGNodeByStartPC := -1;
  If CFGNodes = Nil Then Exit;
  
  For I := 0 to CFGNodeCount - 1 Do Begin
    If CFGNodes^[I].StartPC = PC Then Begin
      FindCFGNodeByStartPC := I;
      Exit;
    End;
  End;
End;

{ --- TODO 08 : Construire le CFG d'une methode --- }
Procedure BuildCFG(Var M: TMethodInfo);
Var
  I, J, K, NodeIdx: Integer;
  Leaders: Array[0..MAX_LEADERS-1] of LongWord;
  LeaderCount: Integer;
  PC, NextPC: LongWord;
  Op: Byte;
  Target: LongInt;
  SuccIdx: Integer;
  Found: Boolean;
  E: Integer;
  
  Procedure AddLeader(P: LongWord);
  Var
    L: Integer;
    Exists: Boolean;
  Begin
    { Verifier si deja present }
    Exists := False;
    For L := 0 to LeaderCount - 1 Do Begin
      If Leaders[L] = P Then Begin
        Exists := True;
        Break;
      End;
    End;
    If not Exists and (LeaderCount < MAX_LEADERS) Then Begin
      Leaders[LeaderCount] := P;
      Inc(LeaderCount);
    End;
  End;
  
  Procedure SortLeaders;
  Var
    A, B: Integer;
    Tmp: LongWord;
  Begin
    For A := 0 to LeaderCount - 2 Do Begin
      For B := A + 1 to LeaderCount - 1 Do Begin
        If Leaders[B] < Leaders[A] Then Begin
          Tmp := Leaders[A];
          Leaders[A] := Leaders[B];
          Leaders[B] := Tmp;
        End;
      End;
    End;
  End;
  
Begin
  { Initialiser }
  AllocCFG;
  CFGNodeCount := 0;
  CFGUnreachable := 0;
  CFGBackEdges := 0;
  LeaderCount := 0;
  
  If (Instructions = Nil) or (InstrCount = 0) Then Exit;
  
  { ===== PHASE 1 : Identifier tous les leaders de blocs de base ===== }
  
  { PC=0 est toujours un leader (point d'entree) }
  AddLeader(0);
  
  { Parcourir les instructions pour trouver les leaders }
  For I := 0 to InstrCount - 1 Do Begin
    PC := Instructions^[I].PC;
    Op := Instructions^[I].Opcode;
    
    { Si c'est un branchement, la cible est un leader }
    If (Op >= OP_IFEQ) and (Op <= OP_IF_ACMPNE) Then Begin
      Target := LongInt(PC) + Instructions^[I].Op1;
      If Target >= 0 Then AddLeader(LongWord(Target));
      { L'instruction suivante est aussi un leader (fall-through) }
      NextPC := PC + LongWord(Instructions^[I].Size);
      AddLeader(NextPC);
    End
    Else If (Op = OP_GOTO) or (Op = OP_GOTO_W) Then Begin
      Target := LongInt(PC) + Instructions^[I].Op1;
      If Target >= 0 Then AddLeader(LongWord(Target));
      { L'instruction suivante est un leader (meme si inaccessible) }
      NextPC := PC + LongWord(Instructions^[I].Size);
      If (I + 1 < InstrCount) Then AddLeader(NextPC);
    End
    Else If (Op = OP_IFNULL) or (Op = OP_IFNONNULL) Then Begin
      Target := LongInt(PC) + Instructions^[I].Op1;
      If Target >= 0 Then AddLeader(LongWord(Target));
      NextPC := PC + LongWord(Instructions^[I].Size);
      AddLeader(NextPC);
    End
    Else If (Op = OP_JSR) or (Op = OP_JSR_W) Then Begin
      Target := LongInt(PC) + Instructions^[I].Op1;
      If Target >= 0 Then AddLeader(LongWord(Target));
      NextPC := PC + LongWord(Instructions^[I].Size);
      AddLeader(NextPC);
    End
    Else If (Op = OP_TABLESWITCH) or (Op = OP_LOOKUPSWITCH) Then Begin
      { La cible par defaut et l'instruction suivante }
      Target := LongInt(PC) + Instructions^[I].Op1;
      If Target >= 0 Then AddLeader(LongWord(Target));
      NextPC := PC + LongWord(Instructions^[I].Size);
      If (I + 1 < InstrCount) Then AddLeader(NextPC);
    End
    Else If (Op >= OP_IRETURN) and (Op <= OP_RETURN) Then Begin
      { Instruction suivante (si existe) est un leader }
      NextPC := PC + LongWord(Instructions^[I].Size);
      If (I + 1 < InstrCount) Then AddLeader(NextPC);
    End
    Else If (Op = OP_ATHROW) Then Begin
      { Instruction suivante (si existe) est un leader }
      NextPC := PC + LongWord(Instructions^[I].Size);
      If (I + 1 < InstrCount) Then AddLeader(NextPC);
    End;
  End;
  
  { Ajouter les debuts de gestionnaires d'exception }
  For E := 0 to M.ExcCount - 1 Do Begin
    AddLeader(M.ExcTable[E].HandlerPC);
  End;
  
  { Trier les leaders par PC croissant }
  SortLeaders;
  
  { ===== PHASE 2 : Creer les noeuds CFG ===== }
  
  For I := 0 to LeaderCount - 1 Do Begin
    If CFGNodeCount >= MAX_CFG_NODES Then Break;
    
    InitCFGNode(CFGNodes^[CFGNodeCount]);
    CFGNodes^[CFGNodeCount].ID := CFGNodeCount;
    CFGNodes^[CFGNodeCount].StartPC := Leaders[I];
    
    { Trouver le EndPC (debut du prochain bloc - 1, ou fin du code) }
    If I < LeaderCount - 1 Then Begin
      { Trouver la derniere instruction avant le prochain leader }
      For J := InstrCount - 1 downto 0 Do Begin
        If (Instructions^[J].PC >= Leaders[I]) and 
           (Instructions^[J].PC < Leaders[I+1]) Then Begin
          CFGNodes^[CFGNodeCount].EndPC := Instructions^[J].PC;
          Break;
        End;
      End;
    End
    Else Begin
      { Dernier bloc : va jusqu'a la fin du code }
      CFGNodes^[CFGNodeCount].EndPC := Instructions^[InstrCount-1].PC;
    End;
    
    { Trouver InstStart et InstEnd }
    CFGNodes^[CFGNodeCount].InstStart := -1;
    CFGNodes^[CFGNodeCount].InstEnd := -1;
    For J := 0 to InstrCount - 1 Do Begin
      If (Instructions^[J].PC >= CFGNodes^[CFGNodeCount].StartPC) and
         (Instructions^[J].PC <= CFGNodes^[CFGNodeCount].EndPC) Then Begin
        If CFGNodes^[CFGNodeCount].InstStart < 0 Then
          CFGNodes^[CFGNodeCount].InstStart := J;
        CFGNodes^[CFGNodeCount].InstEnd := J;
      End;
    End;
    
    { Marquer si c'est l'entree (PC=0) }
    CFGNodes^[CFGNodeCount].IsEntry := (Leaders[I] = 0);
    
    { Marquer si c'est un gestionnaire d'exception }
    CFGNodes^[CFGNodeCount].IsException := IsExceptionHandler(M, Leaders[I]);
    
    Inc(CFGNodeCount);
  End;
  
  { ===== PHASE 3 : Lier les successeurs ===== }
  
  For I := 0 to CFGNodeCount - 1 Do Begin
    If CFGNodes^[I].InstEnd < 0 Then Continue;
    
    { Obtenir la derniere instruction du bloc }
    J := CFGNodes^[I].InstEnd;
    Op := Instructions^[J].Opcode;
    PC := Instructions^[J].PC;
    
    { Marquer si c'est un bloc de sortie }
    CFGNodes^[I].IsExit := (Op >= OP_IRETURN) and (Op <= OP_RETURN);
    
    { Determiner les successeurs selon le type d'instruction }
    If (Op >= OP_IFEQ) and (Op <= OP_IF_ACMPNE) Then Begin
      { Branchement conditionnel : 2 successeurs }
      { Successeur 1 : cible du branchement }
      Target := LongInt(PC) + Instructions^[J].Op1;
      SuccIdx := FindCFGNodeByStartPC(LongWord(Target));
      If SuccIdx >= 0 Then AddCFGSuccessor(CFGNodes^[I], SuccIdx);
      { Successeur 2 : fall-through }
      NextPC := PC + LongWord(Instructions^[J].Size);
      SuccIdx := FindCFGNodeByStartPC(NextPC);
      If SuccIdx >= 0 Then AddCFGSuccessor(CFGNodes^[I], SuccIdx);
    End
    Else If (Op = OP_IFNULL) or (Op = OP_IFNONNULL) Then Begin
      { Branchement conditionnel null : 2 successeurs }
      Target := LongInt(PC) + Instructions^[J].Op1;
      SuccIdx := FindCFGNodeByStartPC(LongWord(Target));
      If SuccIdx >= 0 Then AddCFGSuccessor(CFGNodes^[I], SuccIdx);
      NextPC := PC + LongWord(Instructions^[J].Size);
      SuccIdx := FindCFGNodeByStartPC(NextPC);
      If SuccIdx >= 0 Then AddCFGSuccessor(CFGNodes^[I], SuccIdx);
    End
    Else If (Op = OP_GOTO) or (Op = OP_GOTO_W) Then Begin
      { Saut inconditionnel : 1 successeur }
      Target := LongInt(PC) + Instructions^[J].Op1;
      SuccIdx := FindCFGNodeByStartPC(LongWord(Target));
      If SuccIdx >= 0 Then AddCFGSuccessor(CFGNodes^[I], SuccIdx);
    End
    Else If (Op = OP_JSR) or (Op = OP_JSR_W) Then Begin
      { Appel de sous-routine : 2 successeurs (routine et retour) }
      Target := LongInt(PC) + Instructions^[J].Op1;
      SuccIdx := FindCFGNodeByStartPC(LongWord(Target));
      If SuccIdx >= 0 Then AddCFGSuccessor(CFGNodes^[I], SuccIdx);
      NextPC := PC + LongWord(Instructions^[J].Size);
      SuccIdx := FindCFGNodeByStartPC(NextPC);
      If SuccIdx >= 0 Then AddCFGSuccessor(CFGNodes^[I], SuccIdx);
    End
    Else If (Op = OP_TABLESWITCH) or (Op = OP_LOOKUPSWITCH) Then Begin
      { Switch : la cible par defaut (Op1) }
      Target := LongInt(PC) + Instructions^[J].Op1;
      SuccIdx := FindCFGNodeByStartPC(LongWord(Target));
      If SuccIdx >= 0 Then AddCFGSuccessor(CFGNodes^[I], SuccIdx);
      { Note: les autres cibles du switch necessiteraient un parsing plus fin }
    End
    Else If (Op >= OP_IRETURN) and (Op <= OP_RETURN) Then Begin
      { Return : pas de successeur (noeud de sortie) }
    End
    Else If (Op = OP_ATHROW) Then Begin
      { Throw : pas de successeur direct (sauf gestionnaires d'exception) }
    End
    Else If (Op = OP_RET) Then Begin
      { Retour de sous-routine : complexe, ignorer pour simplifier }
    End
    Else Begin
      { Instruction normale : fall-through vers le bloc suivant }
      If I < CFGNodeCount - 1 Then Begin
        NextPC := CFGNodes^[I].EndPC + 1;
        { Trouver le bloc suivant }
        For K := 0 to CFGNodeCount - 1 Do Begin
          If (CFGNodes^[K].StartPC > CFGNodes^[I].EndPC) Then Begin
            { Verifier que c'est bien la suite immediate }
            Found := False;
            For NodeIdx := 0 to InstrCount - 1 Do Begin
              If Instructions^[NodeIdx].PC = CFGNodes^[K].StartPC Then Begin
                If NodeIdx > 0 Then Begin
                  If (Instructions^[NodeIdx-1].PC >= CFGNodes^[I].StartPC) and
                     (Instructions^[NodeIdx-1].PC <= CFGNodes^[I].EndPC) Then Begin
                    AddCFGSuccessor(CFGNodes^[I], K);
                    Found := True;
                  End;
                End;
                Break;
              End;
            End;
            If Found Then Break;
          End;
        End;
      End;
    End;
  End;
  
  { ===== PHASE 4 : Calculer les predecesseurs ===== }
  
  For I := 0 to CFGNodeCount - 1 Do Begin
    For J := 0 to CFGNodes^[I].SuccCount - 1 Do Begin
      SuccIdx := CFGNodes^[I].Succs[J];
      If (SuccIdx >= 0) and (SuccIdx < CFGNodeCount) Then Begin
        AddCFGPredecessor(CFGNodes^[SuccIdx], I);
      End;
    End;
  End;
End;

{ --- TODO 08 : Parcours DFS du CFG pour marquer les noeuds visites --- }
Procedure CFGVisitDFS(NodeIdx: Integer);
Var
  I, SuccIdx: Integer;
Begin
  If CFGNodes = Nil Then Exit;
  If (NodeIdx < 0) or (NodeIdx >= CFGNodeCount) Then Exit;
  If CFGNodes^[NodeIdx].Visited Then Exit;
  
  CFGNodes^[NodeIdx].Visited := True;
  
  { Visiter tous les successeurs }
  For I := 0 to CFGNodes^[NodeIdx].SuccCount - 1 Do Begin
    SuccIdx := CFGNodes^[NodeIdx].Succs[I];
    If (SuccIdx >= 0) and (SuccIdx < CFGNodeCount) Then Begin
      CFGVisitDFS(SuccIdx);
    End;
  End;
End;

{ --- TODO 08 : Trouver les blocs inaccessibles --- }
Procedure FindUnreachableBlocks;
Var
  I, EntryNode: Integer;
Begin
  CFGUnreachable := 0;
  If CFGNodes = Nil Then Exit;
  If CFGNodeCount = 0 Then Exit;
  
  { Reinitialiser les flags Visited }
  For I := 0 to CFGNodeCount - 1 Do Begin
    CFGNodes^[I].Visited := False;
  End;
  
  { Trouver le noeud d'entree (IsEntry=True ou premier noeud) }
  EntryNode := -1;
  For I := 0 to CFGNodeCount - 1 Do Begin
    If CFGNodes^[I].IsEntry Then Begin
      EntryNode := I;
      Break;
    End;
  End;
  If EntryNode < 0 Then EntryNode := 0;
  
  { Parcours DFS depuis le noeud d'entree }
  CFGVisitDFS(EntryNode);
  
  { Aussi visiter les gestionnaires d'exception (accessibles par exception) }
  For I := 0 to CFGNodeCount - 1 Do Begin
    If CFGNodes^[I].IsException and not CFGNodes^[I].Visited Then Begin
      CFGVisitDFS(I);
    End;
  End;
  
  { Compter les blocs non visites (code mort) }
  For I := 0 to CFGNodeCount - 1 Do Begin
    If not CFGNodes^[I].Visited Then Begin
      Inc(CFGUnreachable);
    End;
  End;
End;

{ --- TODO 08 : Trouver les aretes arriere (boucles) --- }
Procedure FindBackEdges;
Var
  I, J, SuccIdx: Integer;
  DFSOrder: Array[0..MAX_CFG_NODES-1] of Integer;
  DFSCounter: Integer;
  
  Procedure DFSNumbering(NodeIdx: Integer);
  Var
    K, S: Integer;
  Begin
    If (NodeIdx < 0) or (NodeIdx >= CFGNodeCount) Then Exit;
    If DFSOrder[NodeIdx] >= 0 Then Exit;
    
    DFSOrder[NodeIdx] := DFSCounter;
    Inc(DFSCounter);
    
    For K := 0 to CFGNodes^[NodeIdx].SuccCount - 1 Do Begin
      S := CFGNodes^[NodeIdx].Succs[K];
      If (S >= 0) and (S < CFGNodeCount) Then Begin
        DFSNumbering(S);
      End;
    End;
  End;
  
Begin
  CFGBackEdges := 0;
  If CFGNodes = Nil Then Exit;
  If CFGNodeCount = 0 Then Exit;
  
  { Initialiser le numerotage DFS }
  For I := 0 to CFGNodeCount - 1 Do Begin
    DFSOrder[I] := -1;
    CFGNodes^[I].IsBackEdge := False;
  End;
  
  { Numeroter les noeuds en ordre DFS }
  DFSCounter := 0;
  For I := 0 to CFGNodeCount - 1 Do Begin
    If CFGNodes^[I].IsEntry Then Begin
      DFSNumbering(I);
      Break;
    End;
  End;
  
  { Une arete arriere va d'un noeud vers un noeud visite plus tot }
  For I := 0 to CFGNodeCount - 1 Do Begin
    For J := 0 to CFGNodes^[I].SuccCount - 1 Do Begin
      SuccIdx := CFGNodes^[I].Succs[J];
      If (SuccIdx >= 0) and (SuccIdx < CFGNodeCount) Then Begin
        { Si le successeur a un numero DFS inferieur ou egal, c'est une arete arriere }
        If (DFSOrder[I] >= 0) and (DFSOrder[SuccIdx] >= 0) Then Begin
          If DFSOrder[SuccIdx] <= DFSOrder[I] Then Begin
            CFGNodes^[SuccIdx].IsBackEdge := True;
            Inc(CFGBackEdges);
          End;
        End;
      End;
    End;
  End;
End;

{ --- TODO 08 : Calculer les dominateurs (algorithme iteratif simplifie) --- }
Procedure ComputeDominators;
Var
  I, J, P: Integer;
  Changed: Boolean;
  NewDom: Integer;
  
  Function Intersect(B1, B2: Integer): Integer;
  Var
    Finger1, Finger2: Integer;
  Begin
    Finger1 := B1;
    Finger2 := B2;
    While Finger1 <> Finger2 Do Begin
      While Finger1 > Finger2 Do Begin
        If CFGNodes^[Finger1].DomBy >= 0 Then
          Finger1 := CFGNodes^[Finger1].DomBy
        Else
          Break;
      End;
      While Finger2 > Finger1 Do Begin
        If CFGNodes^[Finger2].DomBy >= 0 Then
          Finger2 := CFGNodes^[Finger2].DomBy
        Else
          Break;
      End;
    End;
    Intersect := Finger1;
  End;
  
Begin
  If CFGNodes = Nil Then Exit;
  If CFGNodeCount = 0 Then Exit;
  
  { Initialiser : le noeud d'entree se domine lui-meme, les autres ont DomBy=-1 }
  For I := 0 to CFGNodeCount - 1 Do Begin
    If CFGNodes^[I].IsEntry Then
      CFGNodes^[I].DomBy := I
    Else
      CFGNodes^[I].DomBy := -1;
  End;
  
  { Iterer jusqu'a convergence }
  Changed := True;
  While Changed Do Begin
    Changed := False;
    
    For I := 0 to CFGNodeCount - 1 Do Begin
      If CFGNodes^[I].IsEntry Then Continue;
      If CFGNodes^[I].PredCount = 0 Then Continue;
      
      { Trouver le premier predecesseur avec un dominateur calcule }
      NewDom := -1;
      For J := 0 to CFGNodes^[I].PredCount - 1 Do Begin
        P := CFGNodes^[I].Preds[J];
        If (P >= 0) and (P < CFGNodeCount) and (CFGNodes^[P].DomBy >= 0) Then Begin
          NewDom := P;
          Break;
        End;
      End;
      
      If NewDom < 0 Then Continue;
      
      { Intersection avec les autres predecesseurs }
      For J := 0 to CFGNodes^[I].PredCount - 1 Do Begin
        P := CFGNodes^[I].Preds[J];
        If (P <> NewDom) and (P >= 0) and (P < CFGNodeCount) Then Begin
          If CFGNodes^[P].DomBy >= 0 Then Begin
            NewDom := Intersect(P, NewDom);
          End;
        End;
      End;
      
      If CFGNodes^[I].DomBy <> NewDom Then Begin
        CFGNodes^[I].DomBy := NewDom;
        Changed := True;
      End;
    End;
  End;
End;

{ --- TODO 08 : Afficher le CFG pour debug --- }
Procedure DumpCFG;
Var
  I, J: Integer;
Begin
  If CFGNodes = Nil Then Begin
    WriteLn('CFG: (non alloue)');
    Exit;
  End;
  
  WriteLn('=== CFG : ', CFGNodeCount, ' noeuds ===');
  WriteLn('Blocs inaccessibles: ', CFGUnreachable);
  WriteLn('Aretes arriere (boucles): ', CFGBackEdges);
  WriteLn;
  
  For I := 0 to CFGNodeCount - 1 Do Begin
    Write('  [', I, '] PC ', CFGNodes^[I].StartPC, '-', CFGNodes^[I].EndPC);
    Write(' Inst[', CFGNodes^[I].InstStart, '-', CFGNodes^[I].InstEnd, ']');
    
    If CFGNodes^[I].IsEntry Then Write(' ENTRY');
    If CFGNodes^[I].IsExit Then Write(' EXIT');
    If CFGNodes^[I].IsException Then Write(' HANDLER');
    If CFGNodes^[I].IsBackEdge Then Write(' LOOP');
    If not CFGNodes^[I].Visited Then Write(' DEAD');
    
    Write(' Succs=[');
    For J := 0 to CFGNodes^[I].SuccCount - 1 Do Begin
      If J > 0 Then Write(',');
      Write(CFGNodes^[I].Succs[J]);
    End;
    Write('] Preds=[');
    For J := 0 to CFGNodes^[I].PredCount - 1 Do Begin
      If J > 0 Then Write(',');
      Write(CFGNodes^[I].Preds[J]);
    End;
    Write(']');
    
    If CFGNodes^[I].DomBy >= 0 Then
      Write(' Dom=', CFGNodes^[I].DomBy);
    
    WriteLn;
  End;
  WriteLn;
End;

{ --- TODO 08 : Accesseurs du module CFG --- }
Function GetCFGNodeCount: Integer;
Begin
  GetCFGNodeCount := CFGNodeCount;
End;

Function GetCFGUnreachableCount: Integer;
Begin
  GetCFGUnreachableCount := CFGUnreachable;
End;

Function GetCFGBackEdgeCount: Integer;
Begin
  GetCFGBackEdgeCount := CFGBackEdges;
End;

Function IsCFGAllocated: Boolean;
Begin
  IsCFGAllocated := (CFGNodes <> Nil);
End;

Function GetCFGNodeStartPC(Idx: Integer): LongWord;
Begin
  If (CFGNodes <> Nil) and (Idx >= 0) and (Idx < CFGNodeCount) Then
    GetCFGNodeStartPC := CFGNodes^[Idx].StartPC
  Else
    GetCFGNodeStartPC := 0;
End;

Function GetCFGNodeEndPC(Idx: Integer): LongWord;
Begin
  If (CFGNodes <> Nil) and (Idx >= 0) and (Idx < CFGNodeCount) Then
    GetCFGNodeEndPC := CFGNodes^[Idx].EndPC
  Else
    GetCFGNodeEndPC := 0;
End;

Function IsCFGNodeEntry(Idx: Integer): Boolean;
Begin
  If (CFGNodes <> Nil) and (Idx >= 0) and (Idx < CFGNodeCount) Then
    IsCFGNodeEntry := CFGNodes^[Idx].IsEntry
  Else
    IsCFGNodeEntry := False;
End;

Function IsCFGNodeExit(Idx: Integer): Boolean;
Begin
  If (CFGNodes <> Nil) and (Idx >= 0) and (Idx < CFGNodeCount) Then
    IsCFGNodeExit := CFGNodes^[Idx].IsExit
  Else
    IsCFGNodeExit := False;
End;

Function IsCFGNodeUnreachable(Idx: Integer): Boolean;
Begin
  If (CFGNodes <> Nil) and (Idx >= 0) and (Idx < CFGNodeCount) Then
    IsCFGNodeUnreachable := not CFGNodes^[Idx].Visited
  Else
    IsCFGNodeUnreachable := True;
End;

Function IsCFGNodeLoop(Idx: Integer): Boolean;
Begin
  If (CFGNodes <> Nil) and (Idx >= 0) and (Idx < CFGNodeCount) Then
    IsCFGNodeLoop := CFGNodes^[Idx].IsBackEdge
  Else
    IsCFGNodeLoop := False;
End;

{ ============================================================================ }
{ TODO 09 [IMPLEMENTE] - Detecteur : dereferencement de pointeur null          }
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
{  - Procedure DetectNullDereferences(MethodIdx: Integer)                       }
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

{ --- TODO 09 : Initialiser le module null detector --- }
Procedure InitNullState;
Var
  I: Integer;
Begin
  NullInitialized := True;
  NullStackTop := 0;
  NullLocalCount := 0;
  NullBugCount := 0;
  NullLabelNum := 0;
  NullTotalChecks := 0;
  NullTotalDeref := 0;
  NullCurrentPC := 0;
  NullCurrentLine := 0;
  
  For I := 0 to MAX_NULL_STACK - 1 Do
    NullStack[I] := VAL_UNKNOWN;
  
  For I := 0 to MAX_NULL_LOCALS - 1 Do
    NullLocals[I] := VAL_UNKNOWN;
  
  For I := 0 to MAX_NULL_BUGS - 1 Do Begin
    NullBugs[I].BugType := NP_NONE;
    NullBugs[I].PC := 0;
    NullBugs[I].LineNum := 0;
    NullBugs[I].OpType := '';
  End;
End;

{ --- TODO 09 : Generer un label unique --- }
Function GenNullLabel: String;
Begin
  Inc(NullLabelNum);
  GenNullLabel := '_NL_' + IntToStr_(NullLabelNum);
End;

{ --- TODO 09 : Convertir un type de valeur en chaine --- }
Function NullTypeName(Val: Integer): String;
Begin
  Case Val of
    VAL_UNKNOWN: NullTypeName := 'UNKNOWN';
    VAL_NULL:    NullTypeName := 'NULL';
    VAL_NONNULL: NullTypeName := 'NONNULL';
    VAL_MAYBE:   NullTypeName := 'MAYBE';
  Else
    NullTypeName := '?';
  End;
End;

{ --- TODO 09 : Convertir un type de bug en chaine --- }
Function NullBugTypeName(BugType: Integer): String;
Begin
  Case BugType of
    NP_NONE:                        NullBugTypeName := 'NP_NONE';
    NP_NULL_ON_SOME_PATH:           NullBugTypeName := 'NP_NULL_ON_SOME_PATH';
    NP_NULL_ON_SOME_PATH_EXCEPTION: NullBugTypeName := 'NP_NULL_ON_SOME_PATH_EXCEPTION';
    NP_ALWAYS_NULL:                 NullBugTypeName := 'NP_ALWAYS_NULL';
    NP_NULL_DEREF_ALL_TARGETS:      NullBugTypeName := 'NP_NULL_DEREF_ALL_TARGETS';
    NP_STORE_INTO_NONNULL_FIELD:    NullBugTypeName := 'NP_STORE_INTO_NONNULL_FIELD';
    NP_GUARANTEED_DEREF:            NullBugTypeName := 'NP_GUARANTEED_DEREF';
  Else
    NullBugTypeName := '?';
  End;
End;

{ --- TODO 09 : Verifier si un opcode dereference potentiellement null --- }
Function IsDerefOpcode(Op: Byte): Boolean;
Begin
  Case Op of
    OP_GETFIELD,        { obj.field - dereference obj }
    OP_PUTFIELD,        { obj.field = x - dereference obj }
    OP_INVOKEVIRTUAL,   { obj.method() - dereference obj }
    OP_INVOKESPECIAL,   { obj.<init>() ou super.method() }
    OP_INVOKEINTERFACE, { iface.method() - dereference iface }
    OP_ARRAYLENGTH,     { arr.length - dereference arr }
    OP_ATHROW,          { throw ex - dereference ex }
    OP_MONITORENTER,    { synchronized(obj) - dereference obj }
    OP_MONITOREXIT,     { fin synchronized - dereference obj }
    OP_IALOAD, OP_LALOAD, OP_FALOAD, OP_DALOAD, OP_AALOAD,
    OP_BALOAD, OP_CALOAD, OP_SALOAD,      { arr[i] - dereference arr }
    OP_IASTORE, OP_LASTORE, OP_FASTORE, OP_DASTORE, OP_AASTORE,
    OP_BASTORE, OP_CASTORE, OP_SASTORE:   { arr[i] = x - dereference arr }
      IsDerefOpcode := True;
  Else
    IsDerefOpcode := False;
  End;
End;

{ --- TODO 09 : Fusionner deux valeurs abstraites --- }
Function MergeNullValues(V1, V2: Byte): Byte;
Begin
  If V1 = V2 Then
    MergeNullValues := V1
  Else If (V1 = VAL_UNKNOWN) Then
    MergeNullValues := V2
  Else If (V2 = VAL_UNKNOWN) Then
    MergeNullValues := V1
  Else
    { NULL ^ NONNULL = MAYBE, etc. }
    MergeNullValues := VAL_MAYBE;
End;

{ --- TODO 09 : Empiler une valeur abstraite --- }
Procedure NullPush(Val: Byte);
Begin
  If NullStackTop < MAX_NULL_STACK Then Begin
    NullStack[NullStackTop] := Val;
    Inc(NullStackTop);
  End;
End;

{ --- TODO 09 : Depiler une valeur abstraite --- }
Function NullPop: Byte;
Begin
  If NullStackTop > 0 Then Begin
    Dec(NullStackTop);
    NullPop := NullStack[NullStackTop];
  End Else
    NullPop := VAL_UNKNOWN;
End;

{ --- TODO 09 : Consulter le sommet sans depiler --- }
Function NullPeek: Byte;
Begin
  If NullStackTop > 0 Then
    NullPeek := NullStack[NullStackTop - 1]
  Else
    NullPeek := VAL_UNKNOWN;
End;

{ --- TODO 09 : Consulter un element a profondeur N --- }
Function NullPeekAt(Depth: Integer): Byte;
Begin
  If (Depth >= 0) and (NullStackTop - 1 - Depth >= 0) Then
    NullPeekAt := NullStack[NullStackTop - 1 - Depth]
  Else
    NullPeekAt := VAL_UNKNOWN;
End;

{ --- TODO 09 : Charger une variable locale --- }
Function NullLoadLocal(Idx: Integer): Byte;
Begin
  If (Idx >= 0) and (Idx < MAX_NULL_LOCALS) Then Begin
    If Idx >= NullLocalCount Then
      NullLocalCount := Idx + 1;
    NullLoadLocal := NullLocals[Idx];
  End Else
    NullLoadLocal := VAL_UNKNOWN;
End;

{ --- TODO 09 : Stocker dans une variable locale --- }
Procedure NullStoreLocal(Idx: Integer; Val: Byte);
Begin
  If (Idx >= 0) and (Idx < MAX_NULL_LOCALS) Then Begin
    If Idx >= NullLocalCount Then
      NullLocalCount := Idx + 1;
    NullLocals[Idx] := Val;
  End;
End;

{ --- TODO 09 : Enregistrer un bug null detecte --- }
Procedure AddNullBug(BugType: Integer; PC: LongWord; LineNum: Integer; OpType: String);
Begin
  If NullBugCount < MAX_NULL_BUGS Then Begin
    NullBugs[NullBugCount].BugType := BugType;
    NullBugs[NullBugCount].PC := PC;
    NullBugs[NullBugCount].LineNum := LineNum;
    NullBugs[NullBugCount].OpType := OpType;
    Inc(NullBugCount);
  End;
End;

{ --- TODO 09 : Analyser une instruction pour null deref --- }
Procedure AnalyzeNullForInstr(Var Instr: TInstruction);
Var
  Op, RefVal: Byte;
  LocalIdx: Integer;
  OpName: String;
Begin
  Op := Instr.Opcode;
  NullCurrentPC := Instr.PC;
  NullCurrentLine := Instr.LineNum;
  Inc(NullTotalChecks);
  
  OpName := Instr.Mnemonic;
  
  { Gestion des constantes et chargements }
  Case Op of
    OP_ACONST_NULL: Begin
      NullPush(VAL_NULL);
    End;
    
    OP_NEW, OP_NEWARRAY, OP_ANEWARRAY, OP_MULTIANEWARRAY: Begin
      { new produit toujours une reference non-null }
      NullPush(VAL_NONNULL);
    End;
    
    OP_LDC, OP_LDC_W: Begin
      { Chargement d'une constante du CP - String non-null }
      NullPush(VAL_NONNULL);
    End;
    
    OP_ALOAD_0: Begin
      { this n'est jamais null (sauf erreur fatale) }
      If NullLoadLocal(0) = VAL_UNKNOWN Then
        NullStoreLocal(0, VAL_NONNULL);
      NullPush(NullLoadLocal(0));
    End;
    
    OP_ALOAD_1: NullPush(NullLoadLocal(1));
    OP_ALOAD_2: NullPush(NullLoadLocal(2));
    OP_ALOAD_3: NullPush(NullLoadLocal(3));
    OP_ALOAD:   NullPush(NullLoadLocal(Instr.Op1));
    
    OP_ASTORE_0: NullStoreLocal(0, NullPop);
    OP_ASTORE_1: NullStoreLocal(1, NullPop);
    OP_ASTORE_2: NullStoreLocal(2, NullPop);
    OP_ASTORE_3: NullStoreLocal(3, NullPop);
    OP_ASTORE:   NullStoreLocal(Instr.Op1, NullPop);
    
    { Instructions de pile }
    OP_DUP: Begin
      RefVal := NullPeek;
      NullPush(RefVal);
    End;
    
    OP_POP: Begin
      NullPop;
    End;
    
    OP_POP2: Begin
      NullPop;
      NullPop;
    End;
    
    OP_SWAP: Begin
      { Echanger les deux sommets }
      If NullStackTop >= 2 Then Begin
        RefVal := NullStack[NullStackTop - 1];
        NullStack[NullStackTop - 1] := NullStack[NullStackTop - 2];
        NullStack[NullStackTop - 2] := RefVal;
      End;
    End;
    
    { Dereferences - verifier la valeur de reference }
    OP_GETFIELD: Begin
      Inc(NullTotalDeref);
      RefVal := NullPop;
      If RefVal = VAL_NULL Then
        AddNullBug(NP_ALWAYS_NULL, Instr.PC, Instr.LineNum, 'getfield')
      Else If RefVal = VAL_MAYBE Then
        AddNullBug(NP_NULL_ON_SOME_PATH, Instr.PC, Instr.LineNum, 'getfield');
      NullPush(VAL_UNKNOWN); { Le champ charge a une valeur inconnue }
    End;
    
    OP_PUTFIELD: Begin
      Inc(NullTotalDeref);
      NullPop; { Valeur a stocker }
      RefVal := NullPop;
      If RefVal = VAL_NULL Then
        AddNullBug(NP_ALWAYS_NULL, Instr.PC, Instr.LineNum, 'putfield')
      Else If RefVal = VAL_MAYBE Then
        AddNullBug(NP_NULL_ON_SOME_PATH, Instr.PC, Instr.LineNum, 'putfield');
    End;
    
    OP_GETSTATIC: Begin
      NullPush(VAL_UNKNOWN); { Valeur du champ statique inconnue }
    End;
    
    OP_PUTSTATIC: Begin
      NullPop;
    End;
    
    OP_INVOKEVIRTUAL, OP_INVOKEINTERFACE: Begin
      Inc(NullTotalDeref);
      { Le recepteur est sous les arguments - simplification: regarder le sommet }
      RefVal := NullPeek;
      If RefVal = VAL_NULL Then
        AddNullBug(NP_ALWAYS_NULL, Instr.PC, Instr.LineNum, 'invoke')
      Else If RefVal = VAL_MAYBE Then
        AddNullBug(NP_NULL_ON_SOME_PATH, Instr.PC, Instr.LineNum, 'invoke');
      { Depiler les arguments + recepteur, empiler resultat }
      { Simplification : vider une partie de la pile }
      If NullStackTop > 0 Then Dec(NullStackTop);
      NullPush(VAL_UNKNOWN);
    End;
    
    OP_INVOKESPECIAL: Begin
      Inc(NullTotalDeref);
      RefVal := NullPeek;
      If RefVal = VAL_NULL Then
        AddNullBug(NP_ALWAYS_NULL, Instr.PC, Instr.LineNum, 'invokespecial')
      Else If RefVal = VAL_MAYBE Then
        AddNullBug(NP_NULL_ON_SOME_PATH, Instr.PC, Instr.LineNum, 'invokespecial');
      If NullStackTop > 0 Then Dec(NullStackTop);
      NullPush(VAL_UNKNOWN);
    End;
    
    OP_INVOKESTATIC: Begin
      { Pas de dereference - mais depiler les arguments }
      If NullStackTop > 0 Then Dec(NullStackTop);
      NullPush(VAL_UNKNOWN);
    End;
    
    OP_ARRAYLENGTH: Begin
      Inc(NullTotalDeref);
      RefVal := NullPop;
      If RefVal = VAL_NULL Then
        AddNullBug(NP_ALWAYS_NULL, Instr.PC, Instr.LineNum, 'arraylength')
      Else If RefVal = VAL_MAYBE Then
        AddNullBug(NP_NULL_ON_SOME_PATH, Instr.PC, Instr.LineNum, 'arraylength');
      NullPush(VAL_NONNULL); { Resultat int, pas de ref }
    End;
    
    OP_ATHROW: Begin
      Inc(NullTotalDeref);
      RefVal := NullPop;
      If RefVal = VAL_NULL Then
        AddNullBug(NP_ALWAYS_NULL, Instr.PC, Instr.LineNum, 'athrow')
      Else If RefVal = VAL_MAYBE Then
        AddNullBug(NP_NULL_ON_SOME_PATH, Instr.PC, Instr.LineNum, 'athrow');
    End;
    
    OP_MONITORENTER, OP_MONITOREXIT: Begin
      Inc(NullTotalDeref);
      RefVal := NullPop;
      If RefVal = VAL_NULL Then
        AddNullBug(NP_ALWAYS_NULL, Instr.PC, Instr.LineNum, 'monitor')
      Else If RefVal = VAL_MAYBE Then
        AddNullBug(NP_NULL_ON_SOME_PATH, Instr.PC, Instr.LineNum, 'monitor');
    End;
    
    OP_AALOAD: Begin
      Inc(NullTotalDeref);
      NullPop; { index }
      RefVal := NullPop; { array ref }
      If RefVal = VAL_NULL Then
        AddNullBug(NP_ALWAYS_NULL, Instr.PC, Instr.LineNum, 'aaload')
      Else If RefVal = VAL_MAYBE Then
        AddNullBug(NP_NULL_ON_SOME_PATH, Instr.PC, Instr.LineNum, 'aaload');
      NullPush(VAL_UNKNOWN); { Element charge, nullite inconnue }
    End;
    
    OP_IALOAD, OP_LALOAD, OP_FALOAD, OP_DALOAD, OP_BALOAD, OP_CALOAD, OP_SALOAD: Begin
      Inc(NullTotalDeref);
      NullPop; { index }
      RefVal := NullPop; { array ref }
      If RefVal = VAL_NULL Then
        AddNullBug(NP_ALWAYS_NULL, Instr.PC, Instr.LineNum, 'xaload')
      Else If RefVal = VAL_MAYBE Then
        AddNullBug(NP_NULL_ON_SOME_PATH, Instr.PC, Instr.LineNum, 'xaload');
      NullPush(VAL_NONNULL); { Primitif, pas de ref }
    End;
    
    OP_AASTORE: Begin
      Inc(NullTotalDeref);
      NullPop; { valeur }
      NullPop; { index }
      RefVal := NullPop; { array ref }
      If RefVal = VAL_NULL Then
        AddNullBug(NP_ALWAYS_NULL, Instr.PC, Instr.LineNum, 'aastore')
      Else If RefVal = VAL_MAYBE Then
        AddNullBug(NP_NULL_ON_SOME_PATH, Instr.PC, Instr.LineNum, 'aastore');
    End;
    
    OP_IASTORE, OP_LASTORE, OP_FASTORE, OP_DASTORE, OP_BASTORE, OP_CASTORE, OP_SASTORE: Begin
      Inc(NullTotalDeref);
      NullPop; { valeur }
      NullPop; { index }
      RefVal := NullPop; { array ref }
      If RefVal = VAL_NULL Then
        AddNullBug(NP_ALWAYS_NULL, Instr.PC, Instr.LineNum, 'xastore')
      Else If RefVal = VAL_MAYBE Then
        AddNullBug(NP_NULL_ON_SOME_PATH, Instr.PC, Instr.LineNum, 'xastore');
    End;
    
    { Branchements conditionnels sur nullite }
    OP_IFNULL: Begin
      RefVal := NullPop;
      { Apres ifnull, si on continue, la ref est non-null }
      { La propagation dans les branches est simplifiee ici }
    End;
    
    OP_IFNONNULL: Begin
      RefVal := NullPop;
      { Apres ifnonnull, si on continue, la ref pourrait etre null }
    End;
    
    OP_IF_ACMPEQ, OP_IF_ACMPNE: Begin
      NullPop;
      NullPop;
    End;
    
    OP_ARETURN: Begin
      NullPop;
    End;
    
    OP_CHECKCAST: Begin
      { Ne change pas la nullite de la reference }
    End;
    
    OP_INSTANCEOF: Begin
      NullPop;
      NullPush(VAL_NONNULL); { Resultat boolean }
    End;
    
    { Autres instructions qui manipulent des primitifs }
    OP_ICONST_M1, OP_ICONST_0, OP_ICONST_1, OP_ICONST_2, 
    OP_ICONST_3, OP_ICONST_4, OP_ICONST_5,
    OP_LCONST_0, OP_LCONST_1, OP_FCONST_0, OP_FCONST_1, OP_FCONST_2,
    OP_DCONST_0, OP_DCONST_1, OP_BIPUSH, OP_SIPUSH: Begin
      { Constantes primitives, pas de ref }
    End;
    
    OP_ILOAD, OP_ILOAD_0, OP_ILOAD_1, OP_ILOAD_2, OP_ILOAD_3,
    OP_LLOAD, OP_LLOAD_0, OP_LLOAD_1, OP_LLOAD_2, OP_LLOAD_3,
    OP_FLOAD, OP_FLOAD_0, OP_FLOAD_1, OP_FLOAD_2, OP_FLOAD_3,
    OP_DLOAD, OP_DLOAD_0, OP_DLOAD_1, OP_DLOAD_2, OP_DLOAD_3: Begin
      { Chargement primitif }
    End;
    
    OP_ISTORE, OP_ISTORE_0, OP_ISTORE_1, OP_ISTORE_2, OP_ISTORE_3,
    OP_LSTORE, OP_LSTORE_0, OP_LSTORE_1, OP_LSTORE_2, OP_LSTORE_3,
    OP_FSTORE, OP_FSTORE_0, OP_FSTORE_1, OP_FSTORE_2, OP_FSTORE_3,
    OP_DSTORE, OP_DSTORE_0, OP_DSTORE_1, OP_DSTORE_2, OP_DSTORE_3: Begin
      { Stockage primitif }
    End;
    
    { Pas de traitement special pour les autres opcodes }
  End;
End;

{ --- TODO 09 : Detecter les dereferences null dans une methode --- }
Procedure DetectNullDereferences(MethodIdx: Integer);
Var
  I: Integer;
  BugTypeName: String;
Begin
  If (MethodIdx < 0) or (MethodIdx >= MethodCount) Then Exit;
  If Instructions = Nil Then Exit;
  If InstrCount = 0 Then Exit;
  
  { Initialiser l'etat pour cette methode }
  InitNullState;
  
  { Marquer this comme non-null pour methodes d'instance }
  If not Methods[MethodIdx].IsStatic Then
    NullStoreLocal(0, VAL_NONNULL);
  
  { Analyser chaque instruction sequentiellement }
  For I := 0 to InstrCount - 1 Do Begin
    AnalyzeNullForInstr(Instructions^[I]);
  End;
  
  { Enregistrer les bugs detectes }
  For I := 0 to NullBugCount - 1 Do Begin
    Case NullBugs[I].BugType of
      NP_ALWAYS_NULL: BugTypeName := 'NP_ALWAYS_NULL';
      NP_NULL_ON_SOME_PATH: BugTypeName := 'NP_NULL_ON_SOME_PATH';
      NP_NULL_ON_SOME_PATH_EXCEPTION: BugTypeName := 'NP_NULL_ON_SOME_PATH_EXCEPTION';
      NP_GUARANTEED_DEREF: BugTypeName := 'NP_GUARANTEED_DEREF';
    Else
      BugTypeName := 'NP_UNKNOWN';
    End;
    
    AddBug(BugTypeName, CAT_CORRECTNESS, SEV_HIGH,
           ClassInfo.ThisClass, Methods[MethodIdx].Name, '',
           NullBugs[I].LineNum,
           'Potential null pointer dereference in ' + NullBugs[I].OpType +
           ' at PC ' + IntToStr_(NullBugs[I].PC));
  End;
End;

{ --- TODO 09 : Afficher l'etat du detecteur null --- }
Procedure DumpNullState;
Var
  I: Integer;
Begin
  WriteLn('=== Null Detector State ===');
  WriteLn('Initialized: ', NullInitialized);
  WriteLn('Stack top: ', NullStackTop);
  WriteLn('Local count: ', NullLocalCount);
  WriteLn('Bug count: ', NullBugCount);
  WriteLn('Total checks: ', NullTotalChecks);
  WriteLn('Total derefs: ', NullTotalDeref);
  WriteLn;
  
  If NullStackTop > 0 Then Begin
    WriteLn('Stack:');
    For I := NullStackTop - 1 downto 0 Do
      WriteLn('  [', I, '] ', NullTypeName(NullStack[I]));
    WriteLn;
  End;
  
  If NullLocalCount > 0 Then Begin
    WriteLn('Locals:');
    For I := 0 to NullLocalCount - 1 Do
      If NullLocals[I] <> VAL_UNKNOWN Then
        WriteLn('  [', I, '] ', NullTypeName(NullLocals[I]));
    WriteLn;
  End;
  
  If NullBugCount > 0 Then Begin
    WriteLn('Bugs:');
    For I := 0 to NullBugCount - 1 Do
      WriteLn('  PC=', NullBugs[I].PC, ' Line=', NullBugs[I].LineNum,
              ' Type=', NullBugTypeName(NullBugs[I].BugType),
              ' Op=', NullBugs[I].OpType);
    WriteLn;
  End;
End;

{ --- TODO 09 : Accesseurs du module null detector --- }
Function IsNullInitialized: Boolean;
Begin
  IsNullInitialized := NullInitialized;
End;

Function GetNullStackTop: Integer;
Begin
  GetNullStackTop := NullStackTop;
End;

Function GetNullLocalCount: Integer;
Begin
  GetNullLocalCount := NullLocalCount;
End;

Function GetNullBugCount: Integer;
Begin
  GetNullBugCount := NullBugCount;
End;

Function GetNullTotalChecks: Integer;
Begin
  GetNullTotalChecks := NullTotalChecks;
End;

Function GetNullTotalDeref: Integer;
Begin
  GetNullTotalDeref := NullTotalDeref;
End;

Function GetNullLabelNum: Integer;
Begin
  GetNullLabelNum := NullLabelNum;
End;

Function GetNullBugType(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < NullBugCount) Then
    GetNullBugType := NullBugs[Idx].BugType
  Else
    GetNullBugType := NP_NONE;
End;

Function GetNullBugPC(Idx: Integer): LongWord;
Begin
  If (Idx >= 0) and (Idx < NullBugCount) Then
    GetNullBugPC := NullBugs[Idx].PC
  Else
    GetNullBugPC := 0;
End;

Function GetNullBugLine(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < NullBugCount) Then
    GetNullBugLine := NullBugs[Idx].LineNum
  Else
    GetNullBugLine := 0;
End;

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
