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
{  TODO 10 [IMPLEMENTE] - Detecteur : fuite de ressources (resource leaks)    }
{  TODO 11 [IMPLEMENTE] - Detecteur : boucles infinies et blocs inaccessibles }
{  TODO 12 [IMPLEMENTE] - Detecteur : mauvaises pratiques (bad practices)     }
{  TODO 13 [IMPLEMENTE] - Detecteur : comparaisons incorrectes d'objets       }
{  TODO 14 [IMPLEMENTE] - Detecteur : problemes de performance                }
{  TODO 15 [A FAIRE] - Detecteur : vulnerabilites de securite                 }
{  TODO 16 [IMPLEMENTE] - Detecteur : problemes de multi-threading            }
{  TODO 17 [IMPLEMENTE] - Detecteur : exceptions masquees et flux d'erreur    }
{  TODO 18 [IMPLEMENTE] - Detecteur : erreurs logiques et retours incorrects   }
{  TODO 19 [IMPLEMENTE] - Detecteur : problemes d'internationalisation        }
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

  { --- TODO 10 : Constantes pour le detecteur de fuites de ressources --- }
  MAX_RES_TRACKED    = 64;   { Nombre max de ressources trackees par methode }
  MAX_RES_BUGS       = 64;   { Nombre max de bugs resource leak par methode  }
  MAX_RES_CLASSES    = 16;   { Nombre de classes ressources connues          }

  { Types de bugs de fuite de ressource }
  RL_NONE                       = 0;  { Pas de bug                            }
  RL_UNSATISFIED_OBLIGATION     = 1;  { Ressource potentiellement non fermee  }
  RL_UNSATISFIED_OBLIG_EXCEPT   = 2;  { Ressource non fermee sur exception    }
  RL_OPEN_STREAM                = 3;  { Flux non ferme                        }
  RL_OPEN_STREAM_EXCEPTION      = 4;  { Flux non ferme sur chemin exception   }

  { Etat d'une ressource trackee }
  RS_UNKNOWN = 0;  { Etat inconnu                                           }
  RS_OPEN    = 1;  { Ressource ouverte (apres new/constructeur)              }
  RS_CLOSED  = 2;  { Ressource fermee (apres appel close())                  }
  RS_MAYBE   = 3;  { Peut etre ouverte ou fermee selon le chemin             }

  { --- TODO 11 : Constantes pour le detecteur de boucles infinies --- }
  MAX_LOOP_BUGS      = 64;   { Nombre max de bugs loop detectes par methode   }
  MAX_DEAD_STORES    = 128;  { Nombre max de dead stores detectes             }
  MAX_LOOP_BLOCKS    = 64;   { Nombre max de blocs dans une boucle            }

  { Types de bugs de boucles infinies et code mort }
  LP_NONE                       = 0;  { Pas de bug                            }
  IL_INFINITE_LOOP              = 1;  { Boucle infinie sans condition arret   }
  IL_INFINITE_RECURSIVE_LOOP    = 2;  { Appel recursif infini                 }
  DLS_DEAD_LOCAL_STORE          = 3;  { Ecriture jamais relue                 }
  UC_USELESS_VOID_METHOD        = 4;  { Methode vide inutile                  }
  USELESS_CODE                  = 5;  { Code inaccessible                     }
  IL_CONTAINER_MODIFIED         = 6;  { Boucle avec modification container    }

  { --- TODO 12 : Constantes pour le detecteur de mauvaises pratiques --- }
  MAX_BP_BUGS      = 64;   { Nombre max de bugs bad practices par methode    }
  MAX_BP_CASTS     = 64;   { Nombre max de checkcast a tracker                }

  { Types de bugs de mauvaises pratiques }
  BP_NONE                               = 0;  { Pas de bug                    }
  BC_UNCONFIRMED_CAST                   = 1;  { Cast sans instanceof prealable}
  CN_IMPLEMENTS_CLONE_BUT_NOT_CLONEABLE = 2;  { clone() sans Cloneable        }
  DE_MIGHT_IGNORE                       = 3;  { Exception ignoree (catch vide)}
  EQ_DOESNT_OVERRIDE_EQUALS             = 4;  { Sous-classe sans equals()     }
  FI_PUBLIC_SHOULD_BE_PROTECTED         = 5;  { finalize() public             }
  HE_HASHCODE_USE_OBJECT_EQUALS         = 6;  { hashCode sans equals          }
  HE_EQUALS_USE_OBJECT_HASHCODE         = 7;  { equals sans hashCode          }
  RR_NOT_CHECKED                        = 8;  { read() retour non verifie     }
  SR_NOT_CHECKED                        = 9;  { skip() retour non verifie     }

  { --- TODO 13 : Constantes pour le detecteur de comparaisons incorrectes --- }
  MAX_BC_BUGS         = 64;   { Nombre max de bugs comparaison par methode     }
  MAX_BC_STACK_TYPES  = 64;   { Nombre max de types trackes sur la pile        }

  { Types de bugs de comparaisons incorrectes }
  BC_NONE                               = 0;  { Pas de bug                    }
  EC_UNRELATED_TYPES                    = 1;  { == entre types sans relation  }
  ES_COMPARING_STRINGS_WITH_EQ          = 2;  { String compare avec ==        }
  RC_REF_COMPARISON_BAD_PRACTICE        = 3;  { == avec wrapper (Integer etc) }
  GC_UNRELATED_TYPES                    = 4;  { get/contains avec mauvais type}
  EC_ARRAY_AND_NONARRAY                 = 5;  { Array compare avec non-array  }
  EC_BAD_ARRAY_COMPARE                  = 6;  { Tableaux compares avec ==     }
  RC_REF_COMPARISON_BAD_PRACTICE_BOOLEAN = 7; { Boolean compare avec ==       }

  { Types de pile pour l'analyse de types }
  ST_UNKNOWN     = 0;  { Type inconnu                                         }
  ST_NULL        = 1;  { Valeur null                                          }
  ST_INT         = 2;  { Valeur entiere (int, short, byte, char)              }
  ST_LONG        = 3;  { Valeur long                                          }
  ST_FLOAT       = 4;  { Valeur float                                         }
  ST_DOUBLE      = 5;  { Valeur double                                        }
  ST_REF         = 6;  { Reference objet quelconque                           }
  ST_STRING      = 7;  { Reference java/lang/String                           }
  ST_WRAPPER     = 8;  { Reference type wrapper (Integer, Long, etc.)         }
  ST_ARRAY       = 9;  { Reference tableau                                    }
  ST_COLLECTION  = 10; { Reference Collection (List, Set, Map)                }

  { --- TODO 14 : Constantes pour le detecteur de problemes de performance --- }
  MAX_PF_BUGS        = 64;   { Nombre max de bugs performance par methode       }
  MAX_PF_MEMBERS     = 128;  { Nombre max de membres prives trackes             }
  MAX_PF_CONCAT_LOOP = 32;   { Nombre max de concat en boucle trackes           }

  { Types de bugs de performance }
  PF_NONE                           = 0;  { Pas de bug                        }
  SBSC_USE_STRINGBUFFER_CONCATENATION = 1; { concat String dans boucle        }
  DMI_BLOCKING_METHODS_ON_URL       = 2;  { appel bloquant sur URL            }
  ITA_INEFFICIENT_TO_ARRAY          = 3;  { toArray(new T[0]) inefficace      }
  URF_UNREAD_FIELD                  = 4;  { champ prive jamais lu             }
  WMI_WRONG_MAP_ITERATOR            = 5;  { keySet() au lieu de entrySet()    }
  UPM_UNCALLED_PRIVATE_METHOD       = 6;  { methode privee jamais appelee     }
  UWF_UNWRITTEN_FIELD               = 7;  { champ prive jamais ecrit          }

  { --- TODO 16 : Constantes pour le detecteur de problemes de multi-threading --- }
  MAX_MT_BUGS        = 64;   { Nombre max de bugs concurrence par methode       }
  MAX_MT_FIELDS      = 128;  { Nombre max de champs trackes pour acces           }
  MAX_MT_SYNC_DEPTH  = 16;   { Profondeur max d'imbrication synchronized        }

  { Types de bugs de multi-threading }
  MT_NONE                           = 0;  { Pas de bug                        }
  DC_DOUBLECHECK                    = 1;  { double-check locking incorrect    }
  ESYNC_EMPTY_SYNC                  = 2;  { bloc synchronized vide            }
  IS_FIELD_NOT_GUARDED              = 3;  { champ non protege en methode sync }
  IS2_INCONSISTENT_SYNC             = 4;  { acces sync et non-sync au meme champ }
  JLM_JSR166_LOCK_MONITORENTER      = 5;  { monitorenter/exit direct          }
  NN_NAKED_NOTIFY                   = 6;  { notify() sans mise a jour d'etat  }
  NO_NOTIFY_NOT_NOTIFYALL           = 7;  { notify() au lieu de notifyAll()   }
  UG_SYNC_SET_UNSYNC_GET            = 8;  { setter sync mais getter non       }
  UW_UNCOND_WAIT                    = 9;  { wait() sans boucle de garde       }
  WA_AWAIT_NOT_IN_LOOP              = 10; { await() sans boucle de garde      }

  { Etats de synchronisation pour l'analyse }
  SYNC_NONE        = 0;  { Pas dans un bloc synchronized                       }
  SYNC_METHOD      = 1;  { Dans une methode synchronized                       }
  SYNC_BLOCK       = 2;  { Dans un bloc synchronized                           }

  { --- TODO 17 : Constantes pour le detecteur d'exceptions masquees --- }
  MAX_EX_BUGS        = 64;   { Nombre max de bugs exception par methode          }
  MAX_EX_CATCH_INFO  = 32;   { Nombre max de catch blocks trackes                 }
  MAX_EX_FINALLY_INFO = 16;  { Nombre max de finally blocks trackes               }

  { Types de bugs d'exceptions masquees - prefixe EXH_ pour eviter conflit }
  EXH_NONE                               = 0;  { Pas de bug                         }
  EXH_THROWN_IGNORED                     = 1;  { exception capturee et ignoree      }
  EXH_CATCH_EXCEPTION                    = 2;  { catch(Exception) trop large        }
  EXH_REDUNDANT_NULLCHECK                = 3;  { null check apres dereferencement   }
  EXH_FINALLY_RETURN                     = 4;  { return dans finally masque except  }
  EXH_NO_SUPER_EQUALS                    = 5;  { equals() sans super.equals()       }
  EXH_CATCH_THROWABLE                    = 6;  { catch(Throwable) trop large        }
  EXH_POP_ONLY                           = 7;  { catch vide (pop seul)              }
  EXH_DROPPED                            = 8;  { exception capturee mais non relancee }

  { Etats de bloc pour l'analyse }
  BLOCK_NONE       = 0;  { Pas dans un bloc try/catch/finally                   }
  BLOCK_TRY        = 1;  { Dans un bloc try                                     }
  BLOCK_CATCH      = 2;  { Dans un bloc catch                                   }
  BLOCK_FINALLY    = 3;  { Dans un bloc finally                                 }

  { --- TODO 18 : Constantes pour le detecteur d'erreurs logiques --- }
  MAX_LE_BUGS        = 64;   { Nombre max de bugs logiques par methode          }
  MAX_LE_SHADOWS     = 32;   { Nombre max de variables masquant des champs      }
  MAX_LE_SELF_ASSIGN = 16;   { Nombre max de self-assignments trackes           }

  { Types de bugs d'erreurs logiques - prefixe LE_ }
  LE_NONE                             = 0;  { Pas de bug                        }
  RV_RETURN_VALUE_IGNORED             = 1;  { valeur de retour ignoree          }
  IM_MULTIPLYING_RESULT_OF_IREM       = 2;  { mult. resultat de modulo          }
  INT_BAD_COMPARISON_WITH_NONNEG_VALUE = 3; { comparaison < 0 sur valeur >=0    }
  IC_INIT_CIRCULARITY                 = 4;  { init. constante circulaire        }
  MF_CLASS_MASKS_FIELD                = 5;  { locale masque champ de classe     }
  SA_FIELD_SELF_ASSIGNMENT            = 6;  { champ assigne a lui-meme          }
  SA_LOCAL_SELF_ASSIGNMENT            = 7;  { locale assignee a elle-meme       }
  SA_FIELD_DOUBLE_ASSIGNMENT          = 8;  { champ assigne 2 fois de suite     }

  { Categories de retours ignores }
  RV_CAT_NONE         = 0;  { Pas de categorie                                  }
  RV_CAT_STRING       = 1;  { Methode String retournant nouvelle String         }
  RV_CAT_STREAM       = 2;  { Methode Stream retournant valeur                  }
  RV_CAT_COLLECTION   = 3;  { Methode Collection retournant booleen             }
  RV_CAT_BUILDER      = 4;  { Methode StringBuilder/StringBuffer                }

  { --- TODO 19 : Constantes pour le detecteur d'internationalisation --- }
  MAX_I18N_BUGS       = 64;   { Nombre max de bugs i18n par methode             }
  MAX_I18N_CALLS      = 32;   { Nombre max d'appels i18n trackes                }

  { Types de bugs d'internationalisation - prefixe IN_ }
  IN_NONE                        = 0;  { Pas de bug                            }
  DM_DEFAULT_ENCODING            = 1;  { String.getBytes() sans charset        }
  DM_STRING_CTOR                 = 2;  { new String(String) inutile            }
  DM_CONVERT_CASE                = 3;  { toUpperCase/toLowerCase sans Locale   }
  DM_BOXED_PRIMITIVE_FOR_COMPARE = 4;  { boxing inutile avant comparaison      }
  DM_FP_NUMBER_CTOR              = 5;  { new Double(x) au lieu valueOf(x)      }
  DM_NUMBER_CTOR                 = 6;  { new Integer(n) au lieu valueOf(n)     }
  DM_STRING_FORMAT_NO_LOCALE     = 7;  { String.format sans Locale             }
  DM_NEW_STRING_BYTES_NO_CHARSET = 8;  { new String(bytes) sans charset        }

  { Categories d'appels I18N }
  IC_CAT_NONE         = 0;  { Pas de categorie                                  }
  IC_CAT_GETBYTES     = 1;  { Appel String.getBytes()                           }
  IC_CAT_CASE_CONV    = 2;  { Appel toUpperCase/toLowerCase                     }
  IC_CAT_NEW_STRING   = 3;  { Appel new String(bytes)                           }
  IC_CAT_BOXING       = 4;  { Appel constructeur wrapper (Integer, Double...)   }
  IC_CAT_FORMAT       = 5;  { Appel String.format                               }

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

  { --- TODO 10 : Structure TResourceInfo : ressource trackee --- }
  TResourceInfo = Record
    VarIdx     : Integer;    { Index de la variable locale contenant la ressource }
    ClassName  : String;     { Nom complet de la classe ressource                  }
    OpenPC     : LongWord;   { PC ou la ressource a ete ouverte                    }
    ClosePC    : LongWord;   { PC ou la ressource a ete fermee (0 si non fermee)   }
    State      : Byte;       { Etat courant (RS_OPEN, RS_CLOSED, RS_MAYBE)         }
    LineNum    : Integer;    { Numero de ligne source de l'ouverture               }
    InTryBlock : Boolean;    { True si ouvert dans un bloc try                     }
    HasFinally : Boolean;    { True si try possede un bloc finally                 }
  End;
  TResourceArray = Array[0..MAX_RES_TRACKED-1] of TResourceInfo;

  { --- TODO 10 : Structure TResLeakBug : bug resource leak detecte --- }
  TResLeakBug = Record
    BugType    : Integer;    { Type de bug (RL_OPEN_STREAM, etc.)                  }
    PC         : LongWord;   { Position dans le bytecode                           }
    LineNum    : Integer;    { Numero de ligne source                              }
    ClassName  : String;     { Classe de la ressource                              }
    VarIdx     : Integer;    { Index de la variable locale                         }
  End;
  TResLeakBugArray = Array[0..MAX_RES_BUGS-1] of TResLeakBug;

  { --- TODO 11 : Structure TLoopBugInfo : bug boucle/code mort detecte --- }
  TLoopBugInfo = Record
    BugType     : Integer;    { Type de bug (IL_INFINITE_LOOP, etc.)          }
    PC          : LongWord;   { Position dans le bytecode                     }
    LineNum     : Integer;    { Numero de ligne source                        }
    BlockID     : Integer;    { ID du bloc CFG concerne                       }
    VarIdx      : Integer;    { Index variable locale (pour DLS)              }
    MethodName  : String;     { Nom de la methode (pour recursion)            }
  End;
  TLoopBugArray = Array[0..MAX_LOOP_BUGS-1] of TLoopBugInfo;

  { --- TODO 11 : Structure TDeadStoreInfo : dead local store detecte --- }
  TDeadStoreInfo = Record
    VarIdx      : Integer;    { Index de la variable locale                   }
    StorePC     : LongWord;   { PC de l'instruction store                     }
    LineNum     : Integer;    { Numero de ligne source                        }
    IsRead      : Boolean;    { True si la variable est relue apres           }
  End;
  TDeadStoreArray = Array[0..MAX_DEAD_STORES-1] of TDeadStoreInfo;

  { --- TODO 12 : Structure TBadPracticeBug : bug mauvaise pratique detecte --- }
  TBadPracticeBug = Record
    BugType     : Integer;    { Type de bug (BC_UNCONFIRMED_CAST, etc.)     }
    PC          : LongWord;   { Position dans le bytecode                   }
    LineNum     : Integer;    { Numero de ligne source                      }
    ClassName   : String;     { Nom de classe concernee                     }
    MethodName  : String;     { Nom de methode concernee                    }
    TypeName    : String;     { Type cible (pour cast) ou info supplementaire }
  End;
  TBadPracticeBugArray = Array[0..MAX_BP_BUGS-1] of TBadPracticeBug;

  { --- TODO 12 : Structure TCheckcastInfo : info checkcast a tracker --- }
  TCheckcastInfo = Record
    PC          : LongWord;   { PC de l'instruction checkcast               }
    TargetType  : String;     { Type cible du cast                          }
    HasPriorInstanceof : Boolean; { True si instanceof precede ce cast      }
  End;
  TCheckcastArray = Array[0..MAX_BP_CASTS-1] of TCheckcastInfo;

  { --- TODO 13 : Structure TBadCompBug : bug comparaison incorrecte detecte --- }
  TBadCompBug = Record
    BugType     : Integer;    { Type de bug (EC_UNRELATED_TYPES, etc.)     }
    PC          : LongWord;   { Position dans le bytecode                  }
    LineNum     : Integer;    { Numero de ligne source                     }
    ClassName   : String;     { Nom de classe concernee                    }
    MethodName  : String;     { Nom de methode concernee                   }
    Type1       : String;     { Premier type compare                       }
    Type2       : String;     { Deuxieme type compare                      }
  End;
  TBadCompBugArray = Array[0..MAX_BC_BUGS-1] of TBadCompBug;

  { --- TODO 13 : Structure TStackTypeInfo : info type sur la pile --- }
  TStackTypeInfo = Record
    StackType   : Integer;    { Type (ST_UNKNOWN, ST_STRING, etc.)         }
    TypeName    : String;     { Nom du type complet (java/lang/String)     }
    SourcePC    : LongWord;   { PC ou ce type a ete pousse sur la pile     }
    IsNew       : Boolean;    { True si resultat d'un new                  }
  End;
  TStackTypeArray = Array[0..MAX_BC_STACK_TYPES-1] of TStackTypeInfo;

  { --- TODO 14 : Structure TPerfBug : bug de performance detecte --- }
  TPerfBug = Record
    BugType     : Integer;    { Type de bug (SBSC_*, DMI_*, etc.)          }
    PC          : LongWord;   { Position dans le bytecode                  }
    LineNum     : Integer;    { Numero de ligne source                     }
    ClassName   : String;     { Nom de classe concernee                    }
    MethodName  : String;     { Nom de methode concernee                   }
    MemberName  : String;     { Nom du champ/methode problematique         }
    Details     : String;     { Details supplementaires                    }
  End;
  TPerfBugArray = Array[0..MAX_PF_BUGS-1] of TPerfBug;

  { --- TODO 14 : Structure TPrivateMember : membre prive a tracker --- }
  TPrivateMember = Record
    MemberType  : Byte;       { 0=champ, 1=methode                         }
    Name        : String;     { Nom du membre                              }
    Descriptor  : String;     { Descripteur du membre                      }
    DeclLine    : Integer;    { Ligne de declaration                       }
    IsRead      : Boolean;    { True si le champ est lu                    }
    IsWritten   : Boolean;    { True si le champ est ecrit                 }
    IsCalled    : Boolean;    { True si la methode est appelee             }
    FieldIdx    : Integer;    { Index dans Fields[] ou -1                  }
    MethodIdx   : Integer;    { Index dans Methods[] ou -1                 }
  End;
  TPrivateMemberArray = Array[0..MAX_PF_MEMBERS-1] of TPrivateMember;

  { --- TODO 14 : Structure TConcatInLoop : concat String dans une boucle --- }
  TConcatInLoop = Record
    PC          : LongWord;   { PC de la concatenation                     }
    LineNum     : Integer;    { Ligne source                               }
    LoopStart   : LongWord;   { PC de debut de la boucle                   }
    LoopEnd     : LongWord;   { PC de fin de la boucle                     }
  End;
  TConcatInLoopArray = Array[0..MAX_PF_CONCAT_LOOP-1] of TConcatInLoop;

  { --- TODO 16 : Structure TConcurrencyBug : bug de concurrence detecte --- }
  TConcurrencyBug = Record
    BugType     : Integer;    { Type de bug (DC_DOUBLECHECK, etc.)       }
    PC          : LongWord;   { Position dans le bytecode                }
    LineNum     : Integer;    { Numero de ligne source                   }
    ClassName   : String;     { Nom de classe concernee                  }
    MethodName  : String;     { Nom de methode concernee                 }
    FieldName   : String;     { Nom du champ concerne (si applicable)    }
    Details     : String;     { Details supplementaires                  }
  End;
  TConcurrencyBugArray = Array[0..MAX_MT_BUGS-1] of TConcurrencyBug;

  { --- TODO 16 : Structure TFieldAccessInfo : acces a un champ tracke --- }
  TFieldAccessInfo = Record
    FieldIdx    : Integer;    { Index dans Fields[] ou -1                }
    FieldName   : String;     { Nom du champ                             }
    IsVolatile  : Boolean;    { True si le champ est volatile            }
    ReadInSync  : Boolean;    { True si lu dans methode/bloc sync        }
    WriteInSync : Boolean;    { True si ecrit dans methode/bloc sync     }
    ReadNotSync : Boolean;    { True si lu hors synchronisation          }
    WriteNotSync : Boolean;   { True si ecrit hors synchronisation       }
    GetterSync  : Boolean;    { True si getter est synchronized          }
    SetterSync  : Boolean;    { True si setter est synchronized          }
    GetterIdx   : Integer;    { Index de la methode getter ou -1         }
    SetterIdx   : Integer;    { Index de la methode setter ou -1         }
  End;
  TFieldAccessArray = Array[0..MAX_MT_FIELDS-1] of TFieldAccessInfo;

  { --- TODO 17 : Structure TExHandlingBug : bug exception masquee detecte --- }
  TExHandlingBug = Record
    BugType     : Integer;    { Type de bug (THROWN_EXCEPTION_IGNORED, etc.) }
    PC          : LongWord;   { Position dans le bytecode                    }
    LineNum     : Integer;    { Numero de ligne source                       }
    ClassName   : String;     { Nom de classe concernee                      }
    MethodName  : String;     { Nom de methode concernee                     }
    CatchType   : String;     { Type capture (Exception, Throwable, etc.)    }
    Details     : String;     { Details supplementaires                      }
  End;
  TExHandlingBugArray = Array[0..MAX_EX_BUGS-1] of TExHandlingBug;

  { --- TODO 17 : Structure TExCatchInfo : info bloc catch a tracker --- }
  TExCatchInfo = Record
    StartPC     : LongWord;   { PC de debut du bloc try                      }
    EndPC       : LongWord;   { PC de fin du bloc try                        }
    HandlerPC   : LongWord;   { PC du handler (debut du catch)               }
    CatchType   : String;     { Type capture (Exception, Throwable, etc.)    }
    HandlerLen  : Integer;    { Longueur du bloc catch en instructions       }
    IsPopOnly   : Boolean;    { True si le catch ne fait que pop             }
    IsPopReturn : Boolean;    { True si catch fait pop + return              }
    IsTooWide   : Boolean;    { True si catch(Exception/Throwable)           }
    ExcTableIdx : Integer;    { Index dans exception_table                   }
  End;
  TExCatchInfoArray = Array[0..MAX_EX_CATCH_INFO-1] of TExCatchInfo;

  { --- TODO 17 : Structure TExFinallyInfo : info bloc finally a tracker --- }
  TExFinallyInfo = Record
    StartPC     : LongWord;   { PC de debut du finally                       }
    EndPC       : LongWord;   { PC de fin du finally                         }
    HasReturn   : Boolean;    { True si contient un return                   }
    ReturnPC    : LongWord;   { PC de l'instruction return                   }
    ExcTableIdx : Integer;    { Index dans exception_table (catch any)       }
  End;
  TExFinallyInfoArray = Array[0..MAX_EX_FINALLY_INFO-1] of TExFinallyInfo;

  { --- TODO 18 : Structure TLogicBug : bug logique detecte --- }
  TLogicBug = Record
    BugType     : Integer;    { Type de bug (SA_FIELD_SELF_ASSIGNMENT, etc.) }
    PC          : LongWord;   { Position dans le bytecode                    }
    LineNum     : Integer;    { Numero de ligne source                       }
    ClassName   : String;     { Nom de classe concernee                      }
    MethodName  : String;     { Nom de methode concernee                     }
    VarName     : String;     { Nom variable/champ concerne                  }
    Details     : String;     { Details supplementaires                      }
  End;
  TLogicBugArray = Array[0..MAX_LE_BUGS-1] of TLogicBug;

  { --- TODO 18 : Structure TLocalShadow : variable locale masquant un champ --- }
  TLocalShadow = Record
    LocalIdx    : Integer;    { Index de la variable locale                  }
    LocalName   : String;     { Nom de la variable locale                    }
    FieldIdx    : Integer;    { Index du champ masque dans Fields[]          }
    FieldName   : String;     { Nom du champ masque                          }
    DeclPC      : LongWord;   { PC de declaration de la variable locale      }
    LineNum     : Integer;    { Ligne source de la declaration               }
  End;
  TLocalShadowArray = Array[0..MAX_LE_SHADOWS-1] of TLocalShadow;

  { --- TODO 18 : Structure TSelfAssignInfo : info self-assignment tracke --- }
  TSelfAssignInfo = Record
    VarIdx      : Integer;    { Index variable locale ou -1 pour champ       }
    FieldRef    : Integer;    { Index CP du champ ou -1 pour locale          }
    VarName     : String;     { Nom de la variable/champ                     }
    LoadPC      : LongWord;   { PC de l'instruction load                     }
    StorePC     : LongWord;   { PC de l'instruction store                    }
    IsField     : Boolean;    { True si c'est un champ, False si locale      }
  End;
  TSelfAssignInfoArray = Array[0..MAX_LE_SELF_ASSIGN-1] of TSelfAssignInfo;

  { --- TODO 19 : Structure TI18NBug : bug d'internationalisation detecte --- }
  TI18NBug = Record
    BugType     : Integer;    { Type de bug (DM_DEFAULT_ENCODING, etc.)    }
    PC          : LongWord;   { Position dans le bytecode                  }
    LineNum     : Integer;    { Numero de ligne source                     }
    ClassName   : String;     { Nom de classe concernee                    }
    MethodName  : String;     { Nom de methode concernee                   }
    CallName    : String;     { Nom de l'appel problematique               }
    Details     : String;     { Details supplementaires                    }
  End;
  TI18NBugArray = Array[0..MAX_I18N_BUGS-1] of TI18NBug;

  { --- TODO 19 : Structure TI18NCallInfo : appel i18n tracke --- }
  TI18NCallInfo = Record
    CallType    : Integer;    { Type d'appel (IC_CAT_GETBYTES, etc.)       }
    PC          : LongWord;   { PC de l'instruction invoke                 }
    LineNum     : Integer;    { Numero de ligne source                     }
    ClassName   : String;     { Classe sur laquelle l'appel est fait       }
    MethodName  : String;     { Nom de la methode appelee                  }
    Descriptor  : String;     { Descripteur de la methode                  }
    HasLocale   : Boolean;    { True si argument Locale present            }
    HasCharset  : Boolean;    { True si argument Charset present           }
  End;
  TI18NCallInfoArray = Array[0..MAX_I18N_CALLS-1] of TI18NCallInfo;

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
  { --- TODO 10 : Variables du detecteur de fuites de ressources --- }
  ResLeakInitialized : Boolean;   { True si module initialise                  }
  Resources       : TResourceArray; { Table des ressources trackees            }
  ResourceCount   : Integer;      { Nombre de ressources trackees              }
  ResLeakBugs     : TResLeakBugArray; { Bugs detectes dans la methode courante }
  ResLeakBugCount : Integer;      { Nombre de bugs detectes                    }
  ResLabelNum     : Integer;      { Compteur pour generation de labels         }
  ResTotalOpens   : Integer;      { Nombre total de ressources ouvertes        }
  ResTotalCloses  : Integer;      { Nombre total de fermetures detectees       }
  ResTotalLeaks   : Integer;      { Nombre total de fuites detectees           }
  ResCurrentPC    : LongWord;     { PC de l'instruction courante               }
  ResCurrentLine  : Integer;      { Ligne source courante                      }
  { --- TODO 11 : Variables du detecteur de boucles infinies et code mort --- }
  LoopInitialized  : Boolean;     { True si module initialise                  }
  LoopBugs         : TLoopBugArray; { Bugs detectes dans la methode courante   }
  LoopBugCount     : Integer;     { Nombre de bugs detectes                    }
  DeadStores       : TDeadStoreArray; { Table des dead stores detectes         }
  DeadStoreCount   : Integer;     { Nombre de dead stores detectes             }
  LoopLabelNum     : Integer;     { Compteur pour generation de labels         }
  LoopTotalInfinite : Integer;    { Nombre total de boucles infinies detectees }
  LoopTotalRecursive : Integer;   { Nombre total de recursions infinies        }
  LoopTotalDead    : Integer;     { Nombre total de code mort detecte          }
  LoopTotalDeadStores : Integer;  { Nombre total de dead stores detectes       }
  LoopCurrentPC    : LongWord;    { PC de l'instruction courante               }
  LoopCurrentLine  : Integer;     { Ligne source courante                      }
  { --- TODO 12 : Variables du detecteur de mauvaises pratiques --- }
  BPInitialized    : Boolean;     { True si module initialise                  }
  BPBugs           : TBadPracticeBugArray; { Bugs detectes dans la methode     }
  BPBugCount       : Integer;     { Nombre de bugs detectes                    }
  BPCasts          : TCheckcastArray; { Table des checkcast a tracker          }
  BPCastCount      : Integer;     { Nombre de checkcast trackes                }
  BPLabelNum       : Integer;     { Compteur pour generation de labels         }
  BPTotalCasts     : Integer;     { Nombre total de checkcast analyses         }
  BPTotalUnchecked : Integer;     { Nombre total de casts sans instanceof      }
  BPTotalIgnored   : Integer;     { Nombre total d'exceptions ignorees         }
  BPTotalRetNotChecked : Integer; { Nombre total de read/skip non verifies     }
  BPCurrentPC      : LongWord;    { PC de l'instruction courante               }
  BPCurrentLine    : Integer;     { Ligne source courante                      }
  BPHasClone       : Boolean;     { True si la classe a une methode clone()    }
  BPHasEquals      : Boolean;     { True si la classe a une methode equals()   }
  BPHasHashCode    : Boolean;     { True si la classe a une methode hashCode() }
  BPHasFinalize    : Boolean;     { True si la classe a une methode finalize() }
  BPFinalizePublic : Boolean;     { True si finalize() est public              }
  BPImplementsCloneable : Boolean; { True si la classe implemente Cloneable    }
  { --- TODO 13 : Variables du detecteur de comparaisons incorrectes --- }
  BCInitialized    : Boolean;     { True si module initialise                  }
  BCBugs           : TBadCompBugArray; { Bugs detectes dans la methode         }
  BCBugCount       : Integer;     { Nombre de bugs detectes                    }
  BCStackTypes     : TStackTypeArray; { Types trackes sur la pile               }
  BCStackTypeTop   : Integer;     { Sommet de la pile de types                 }
  BCLabelNum       : Integer;     { Compteur pour generation de labels         }
  BCTotalCompares  : Integer;     { Nombre total de comparaisons analysees     }
  BCTotalBadString : Integer;     { Nombre total de comparaisons String ==     }
  BCTotalBadWrapper : Integer;    { Nombre total de comparaisons wrapper ==    }
  BCTotalUnrelated : Integer;     { Nombre total de types non-relies           }
  BCTotalBadCollection : Integer; { Nombre total de get/contains mauvais type  }
  BCCurrentPC      : LongWord;    { PC de l'instruction courante               }
  BCCurrentLine    : Integer;     { Ligne source courante                      }
  { --- TODO 14 : Variables du detecteur de problemes de performance --- }
  PFInitialized    : Boolean;     { True si module initialise                  }
  PFBugs           : TPerfBugArray; { Bugs detectes dans la methode            }
  PFBugCount       : Integer;     { Nombre de bugs detectes                    }
  PFPrivateMembers : TPrivateMemberArray; { Membres prives trackes             }
  PFMemberCount    : Integer;     { Nombre de membres prives                   }
  PFConcatLoops    : TConcatInLoopArray; { Concat String en boucle trackes     }
  PFConcatLoopCount : Integer;    { Nombre de concat en boucle                 }
  PFLabelNum       : Integer;     { Compteur pour generation de labels         }
  PFTotalConcatLoop : Integer;    { Nombre total de concat en boucle           }
  PFTotalURLBlocking : Integer;   { Nombre total d'appels bloquants URL        }
  PFTotalBadToArray : Integer;    { Nombre total de toArray inefficaces        }
  PFTotalUnreadFields : Integer;  { Nombre total de champs non lus             }
  PFTotalUnwrittenFields : Integer; { Nombre total de champs non ecrits        }
  PFTotalWrongMapIter : Integer;  { Nombre total d'iterations Map inefficaces  }
  PFTotalUncalledMethods : Integer; { Nombre total de methodes privees non appelees }
  PFCurrentPC      : LongWord;    { PC de l'instruction courante               }
  PFCurrentLine    : Integer;     { Ligne source courante                      }
  { --- TODO 16 : Variables du detecteur de problemes de multi-threading --- }
  MTInitialized    : Boolean;     { True si module initialise                  }
  MTBugs           : TConcurrencyBugArray; { Bugs detectes dans la methode     }
  MTBugCount       : Integer;     { Nombre de bugs detectes                    }
  MTFieldAccesses  : TFieldAccessArray; { Acces aux champs trackes             }
  MTFieldCount     : Integer;     { Nombre de champs trackes                   }
  MTSyncDepth      : Integer;     { Profondeur imbrication synchronized        }
  MTLabelNum       : Integer;     { Compteur pour generation de labels         }
  MTTotalEmptySync : Integer;     { Nombre total de blocs sync vides           }
  MTTotalWaitNoLoop : Integer;    { Nombre total de wait() sans boucle         }
  MTTotalNakedNotify : Integer;   { Nombre total de notify() nus               }
  MTTotalDoubleCheck : Integer;   { Nombre total de double-check locking       }
  MTTotalInconsistentSync : Integer; { Nombre total d'acces inconsistants      }
  MTTotalSyncSetUnsyncGet : Integer; { Nombre total de setter sync / getter non }
  MTCurrentPC      : LongWord;    { PC de l'instruction courante               }
  MTCurrentLine    : Integer;     { Ligne source courante                      }
  MTInSyncMethod   : Boolean;     { True si dans une methode synchronized      }
  MTInSyncBlock    : Boolean;     { True si dans un bloc synchronized          }
  { --- TODO 17 : Variables du detecteur d'exceptions masquees --- }
  EXInitialized    : Boolean;     { True si module initialise                  }
  EXBugs           : TExHandlingBugArray; { Bugs detectes dans la methode      }
  EXBugCount       : Integer;     { Nombre de bugs detectes                    }
  EXCatchInfos     : TExCatchInfoArray; { Info blocs catch trackes             }
  EXCatchCount     : Integer;     { Nombre de blocs catch trackes              }
  EXFinallyInfos   : TExFinallyInfoArray; { Info blocs finally trackes         }
  EXFinallyCount   : Integer;     { Nombre de blocs finally trackes            }
  EXLabelNum       : Integer;     { Compteur pour generation de labels         }
  EXTotalIgnored   : Integer;     { Nombre total d'exceptions ignorees         }
  EXTotalTooWide   : Integer;     { Nombre total de catch trop larges          }
  EXTotalFinallyReturn : Integer; { Nombre total de return dans finally        }
  EXTotalRedundantNull : Integer; { Nombre total de null check redondants      }
  EXTotalPopOnly   : Integer;     { Nombre total de catch pop only             }
  EXTotalNoSuperEquals : Integer; { Nombre total de equals sans super          }
  EXCurrentPC      : LongWord;    { PC de l'instruction courante               }
  EXCurrentLine    : Integer;     { Ligne source courante                      }
  EXInTryBlock     : Boolean;     { True si dans un bloc try                   }
  EXInCatchBlock   : Boolean;     { True si dans un bloc catch                 }
  EXInFinallyBlock : Boolean;     { True si dans un bloc finally               }
  { --- TODO 18 : Variables du detecteur d'erreurs logiques --- }
  LEInitialized    : Boolean;     { True si module initialise                  }
  LEBugs           : TLogicBugArray; { Bugs detectes dans la methode           }
  LEBugCount       : Integer;     { Nombre de bugs detectes                    }
  LEShadows        : TLocalShadowArray; { Variables locales masquant champs    }
  LEShadowCount    : Integer;     { Nombre de shadows trackes                  }
  LESelfAssigns    : TSelfAssignInfoArray; { Self-assignments trackes          }
  LESelfCount      : Integer;     { Nombre de self-assigns trackes             }
  LELabelNum       : Integer;     { Compteur pour generation de labels         }
  LETotalSelfField : Integer;     { Nombre total self-assign champs            }
  LETotalSelfLocal : Integer;     { Nombre total self-assign locales           }
  LETotalRetIgnored : Integer;    { Nombre total retours ignores               }
  LETotalBadCompare : Integer;    { Nombre total comparaisons invalides        }
  LETotalOverflow  : Integer;     { Nombre total debordements potentiels       }
  LETotalMasking   : Integer;     { Nombre total masquages de champs           }
  LECurrentPC      : LongWord;    { PC de l'instruction courante               }
  LECurrentLine    : Integer;     { Ligne source courante                      }
  LELastLoadVar    : Integer;     { Dernier index variable chargee             }
  LELastLoadField  : Integer;     { Dernier index CP champ charge              }
  LELastLoadPC     : LongWord;    { PC du dernier load                         }
  { --- TODO 19 : Variables du detecteur d'internationalisation --- }
  I18NInitialized  : Boolean;     { True si module initialise                  }
  I18NBugs         : TI18NBugArray; { Bugs detectes dans la methode            }
  I18NBugCount     : Integer;     { Nombre de bugs detectes                    }
  I18NCalls        : TI18NCallInfoArray; { Appels i18n trackes                 }
  I18NCallCount    : Integer;     { Nombre d'appels trackes                    }
  I18NLabelNum     : Integer;     { Compteur pour generation de labels         }
  I18NTotalGetBytes : Integer;    { Nombre total getBytes sans charset         }
  I18NTotalCaseConv : Integer;    { Nombre total case conv sans Locale         }
  I18NTotalNewString : Integer;   { Nombre total new String sans charset       }
  I18NTotalBoxing  : Integer;     { Nombre total boxing inutile                }
  I18NTotalFormat  : Integer;     { Nombre total format sans Locale            }
  I18NTotalStringCtor : Integer;  { Nombre total new String(String) inutile    }
  I18NCurrentPC    : LongWord;    { PC de l'instruction courante               }
  I18NCurrentLine  : Integer;     { Ligne source courante                      }

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
{ TODO 10 [IMPLEMENTE] - Detecteur : fuite de ressources (resource leaks)      }
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

{ --- TODO 10 : Initialiser le module resource leak detector --- }
Procedure InitResLeakState;
Var
  I: Integer;
Begin
  ResLeakInitialized := True;
  ResourceCount := 0;
  ResLeakBugCount := 0;
  ResLabelNum := 0;
  ResTotalOpens := 0;
  ResTotalCloses := 0;
  ResTotalLeaks := 0;
  ResCurrentPC := 0;
  ResCurrentLine := 0;
  
  For I := 0 to MAX_RES_TRACKED - 1 Do Begin
    Resources[I].VarIdx := -1;
    Resources[I].ClassName := '';
    Resources[I].OpenPC := 0;
    Resources[I].ClosePC := 0;
    Resources[I].State := RS_UNKNOWN;
    Resources[I].LineNum := 0;
    Resources[I].InTryBlock := False;
    Resources[I].HasFinally := False;
  End;
  
  For I := 0 to MAX_RES_BUGS - 1 Do Begin
    ResLeakBugs[I].BugType := RL_NONE;
    ResLeakBugs[I].PC := 0;
    ResLeakBugs[I].LineNum := 0;
    ResLeakBugs[I].ClassName := '';
    ResLeakBugs[I].VarIdx := -1;
  End;
End;

{ --- TODO 10 : Generer un label unique --- }
Function GenResLabel: String;
Begin
  Inc(ResLabelNum);
  GenResLabel := '_RL_' + IntToStr_(ResLabelNum);
End;

{ --- TODO 10 : Convertir un type de bug en chaine --- }
Function ResLeakBugTypeName(BugType: Integer): String;
Begin
  Case BugType of
    RL_NONE:                     ResLeakBugTypeName := 'RL_NONE';
    RL_UNSATISFIED_OBLIGATION:   ResLeakBugTypeName := 'OBJ_UNSATISFIED_OBLIGATION';
    RL_UNSATISFIED_OBLIG_EXCEPT: ResLeakBugTypeName := 'OBJ_UNSATISFIED_OBLIGATION_EXCEPTION';
    RL_OPEN_STREAM:              ResLeakBugTypeName := 'OS_OPEN_STREAM';
    RL_OPEN_STREAM_EXCEPTION:    ResLeakBugTypeName := 'OS_OPEN_STREAM_EXCEPTION_PATH';
  Else
    ResLeakBugTypeName := 'RL_UNKNOWN';
  End;
End;

{ --- TODO 10 : Convertir un etat de ressource en chaine --- }
Function ResStateName(State: Byte): String;
Begin
  Case State of
    RS_UNKNOWN: ResStateName := 'UNKNOWN';
    RS_OPEN:    ResStateName := 'OPEN';
    RS_CLOSED:  ResStateName := 'CLOSED';
    RS_MAYBE:   ResStateName := 'MAYBE';
  Else
    ResStateName := '?';
  End;
End;

{ --- TODO 10 : Verifier si une classe est une ressource Closeable --- }
Function IsCloseableClass(ClassName: String): Boolean;
Begin
  IsCloseableClass := False;
  
  { Classes du package java/io }
  If (ClassName = 'java/io/InputStream') or
     (ClassName = 'java/io/FileInputStream') or
     (ClassName = 'java/io/BufferedInputStream') or
     (ClassName = 'java/io/DataInputStream') or
     (ClassName = 'java/io/ObjectInputStream') or
     (ClassName = 'java/io/ByteArrayInputStream') Then
    IsCloseableClass := True
  Else If (ClassName = 'java/io/OutputStream') or
          (ClassName = 'java/io/FileOutputStream') or
          (ClassName = 'java/io/BufferedOutputStream') or
          (ClassName = 'java/io/DataOutputStream') or
          (ClassName = 'java/io/ObjectOutputStream') or
          (ClassName = 'java/io/ByteArrayOutputStream') or
          (ClassName = 'java/io/PrintStream') Then
    IsCloseableClass := True
  Else If (ClassName = 'java/io/Reader') or
          (ClassName = 'java/io/FileReader') or
          (ClassName = 'java/io/BufferedReader') or
          (ClassName = 'java/io/InputStreamReader') or
          (ClassName = 'java/io/StringReader') Then
    IsCloseableClass := True
  Else If (ClassName = 'java/io/Writer') or
          (ClassName = 'java/io/FileWriter') or
          (ClassName = 'java/io/BufferedWriter') or
          (ClassName = 'java/io/OutputStreamWriter') or
          (ClassName = 'java/io/PrintWriter') or
          (ClassName = 'java/io/StringWriter') Then
    IsCloseableClass := True
  { Classes du package java/sql }
  Else If (ClassName = 'java/sql/Connection') or
          (ClassName = 'java/sql/Statement') or
          (ClassName = 'java/sql/PreparedStatement') or
          (ClassName = 'java/sql/CallableStatement') or
          (ClassName = 'java/sql/ResultSet') Then
    IsCloseableClass := True
  { Classes du package java/net }
  Else If (ClassName = 'java/net/Socket') or
          (ClassName = 'java/net/ServerSocket') or
          (ClassName = 'java/net/DatagramSocket') or
          (ClassName = 'java/net/URLConnection') Then
    IsCloseableClass := True
  { Interfaces Closeable et AutoCloseable }
  Else If (ClassName = 'java/io/Closeable') or
          (ClassName = 'java/lang/AutoCloseable') Then
    IsCloseableClass := True;
End;

{ --- TODO 10 : Verifier si une methode est close() --- }
Function IsCloseMethod(MethodName, Descriptor: String): Boolean;
Begin
  IsCloseMethod := (MethodName = 'close') and (Descriptor = '()V');
End;

{ --- TODO 10 : Extraire le nom de classe d'un descripteur de methode CP --- }
Function ExtractClassFromMethodRef(CpIdx: Word): String;
Var
  ClassIdx, NatIdx: Word;
Begin
  ExtractClassFromMethodRef := '';
  If (CpIdx > 0) and (CpIdx < CPCount) Then Begin
    If (CP^[CpIdx].Tag = CP_METHODREF) or 
       (CP^[CpIdx].Tag = CP_INTERFACEMETHODREF) Then Begin
      ClassIdx := CP^[CpIdx].Ref1;
      NatIdx := CP^[CpIdx].Ref2;
      If (ClassIdx > 0) and (ClassIdx < CPCount) Then Begin
        If CP^[ClassIdx].Tag = CP_CLASS Then Begin
          ExtractClassFromMethodRef := CPGetUtf8(CP^[ClassIdx].Ref1);
        End;
      End;
    End;
  End;
End;

{ --- TODO 10 : Extraire le nom de methode d'un NameAndType CP --- }
Function ExtractMethodNameFromRef(CpIdx: Word): String;
Var
  NatIdx, NameIdx: Word;
Begin
  ExtractMethodNameFromRef := '';
  If (CpIdx > 0) and (CpIdx < CPCount) Then Begin
    If (CP^[CpIdx].Tag = CP_METHODREF) or 
       (CP^[CpIdx].Tag = CP_INTERFACEMETHODREF) Then Begin
      NatIdx := CP^[CpIdx].Ref2;
      If (NatIdx > 0) and (NatIdx < CPCount) Then Begin
        If CP^[NatIdx].Tag = CP_NAMEANDTYPE Then Begin
          NameIdx := CP^[NatIdx].Ref1;
          ExtractMethodNameFromRef := CPGetUtf8(NameIdx);
        End;
      End;
    End;
  End;
End;

{ --- TODO 10 : Extraire le descripteur d'un NameAndType CP --- }
Function ExtractMethodDescFromRef(CpIdx: Word): String;
Var
  NatIdx, DescIdx: Word;
Begin
  ExtractMethodDescFromRef := '';
  If (CpIdx > 0) and (CpIdx < CPCount) Then Begin
    If (CP^[CpIdx].Tag = CP_METHODREF) or 
       (CP^[CpIdx].Tag = CP_INTERFACEMETHODREF) Then Begin
      NatIdx := CP^[CpIdx].Ref2;
      If (NatIdx > 0) and (NatIdx < CPCount) Then Begin
        If CP^[NatIdx].Tag = CP_NAMEANDTYPE Then Begin
          DescIdx := CP^[NatIdx].Ref2;
          ExtractMethodDescFromRef := CPGetUtf8(DescIdx);
        End;
      End;
    End;
  End;
End;

{ --- TODO 10 : Tracker l'ouverture d'une ressource --- }
Procedure TrackResourceOpen(VarIdx: Integer; ClassName: String; PC: LongWord; LineNum: Integer);
Begin
  If ResourceCount < MAX_RES_TRACKED Then Begin
    Resources[ResourceCount].VarIdx := VarIdx;
    Resources[ResourceCount].ClassName := ClassName;
    Resources[ResourceCount].OpenPC := PC;
    Resources[ResourceCount].ClosePC := 0;
    Resources[ResourceCount].State := RS_OPEN;
    Resources[ResourceCount].LineNum := LineNum;
    Resources[ResourceCount].InTryBlock := False;
    Resources[ResourceCount].HasFinally := False;
    Inc(ResourceCount);
    Inc(ResTotalOpens);
  End;
End;

{ --- TODO 10 : Tracker la fermeture d'une ressource --- }
Function TrackResourceClose(VarIdx: Integer; PC: LongWord): Boolean;
Var
  I: Integer;
Begin
  TrackResourceClose := False;
  { Chercher la ressource par index de variable locale }
  For I := 0 to ResourceCount - 1 Do Begin
    If (Resources[I].VarIdx = VarIdx) and (Resources[I].State = RS_OPEN) Then Begin
      Resources[I].ClosePC := PC;
      Resources[I].State := RS_CLOSED;
      Inc(ResTotalCloses);
      TrackResourceClose := True;
      Exit;
    End;
  End;
End;

{ --- TODO 10 : Enregistrer un bug de fuite de ressource --- }
Procedure AddResLeakBug(BugType: Integer; PC: LongWord; LineNum: Integer; 
                        ClassName: String; VarIdx: Integer);
Begin
  If ResLeakBugCount < MAX_RES_BUGS Then Begin
    ResLeakBugs[ResLeakBugCount].BugType := BugType;
    ResLeakBugs[ResLeakBugCount].PC := PC;
    ResLeakBugs[ResLeakBugCount].LineNum := LineNum;
    ResLeakBugs[ResLeakBugCount].ClassName := ClassName;
    ResLeakBugs[ResLeakBugCount].VarIdx := VarIdx;
    Inc(ResLeakBugCount);
    Inc(ResTotalLeaks);
  End;
End;

{ --- TODO 10 : Chercher un appel close() dans le bytecode --- }
Function FindCloseCall(MethIdx: Integer; VarIdx: Integer; 
                       StartPC, EndPC: LongWord): Boolean;
Var
  I: Integer;
  Op: Byte;
  CpIdx: Word;
  MName, MDesc: String;
  LoadedVar: Integer;
Begin
  FindCloseCall := False;
  LoadedVar := -1;
  
  If Instructions = Nil Then Exit;
  If InstrCount = 0 Then Exit;
  
  For I := 0 to InstrCount - 1 Do Begin
    If (Instructions^[I].PC >= StartPC) and (Instructions^[I].PC <= EndPC) Then Begin
      Op := Instructions^[I].Opcode;
      
      { Tracker les aload pour savoir quelle variable est chargee }
      If (Op >= OP_ALOAD_0) and (Op <= OP_ALOAD_3) Then
        LoadedVar := Op - OP_ALOAD_0
      Else If Op = OP_ALOAD Then
        LoadedVar := Instructions^[I].Op1
      Else If (Op = OP_INVOKEVIRTUAL) or (Op = OP_INVOKEINTERFACE) Then Begin
        { Verifier si c'est un appel a close() }
        CpIdx := Word(Instructions^[I].Op1);
        MName := ExtractMethodNameFromRef(CpIdx);
        MDesc := ExtractMethodDescFromRef(CpIdx);
        
        If IsCloseMethod(MName, MDesc) and (LoadedVar = VarIdx) Then Begin
          FindCloseCall := True;
          Exit;
        End;
      End;
    End;
  End;
End;

{ --- TODO 10 : Verifier si un PC est dans une table d'exception (finally) --- }
Function IsInExceptionHandler(MethIdx: Integer; PC: LongWord): Boolean;
Var
  I: Integer;
Begin
  IsInExceptionHandler := False;
  
  If (MethIdx < 0) or (MethIdx >= MethodCount) Then Exit;
  
  For I := 0 to Methods[MethIdx].ExcCount - 1 Do Begin
    If (PC >= Methods[MethIdx].ExcTable[I].StartPC) and 
       (PC < Methods[MethIdx].ExcTable[I].EndPC) Then Begin
      IsInExceptionHandler := True;
      Exit;
    End;
  End;
End;

{ --- TODO 10 : Verifier si une ressource a un finally handler --- }
Function HasFinallyHandler(MethIdx: Integer; OpenPC: LongWord): Boolean;
Var
  I: Integer;
Begin
  HasFinallyHandler := False;
  
  If (MethIdx < 0) or (MethIdx >= MethodCount) Then Exit;
  
  For I := 0 to Methods[MethIdx].ExcCount - 1 Do Begin
    { Un finally handler a catch_type = 0 }
    If (Methods[MethIdx].ExcTable[I].CatchType = 0) and
       (OpenPC >= Methods[MethIdx].ExcTable[I].StartPC) and
       (OpenPC < Methods[MethIdx].ExcTable[I].EndPC) Then Begin
      HasFinallyHandler := True;
      Exit;
    End;
  End;
End;

{ --- TODO 10 : Analyser une instruction pour les fuites de ressources --- }
Procedure AnalyzeInstrForResourceLeak(MethIdx, InstrIdx: Integer);
Var
  Op: Byte;
  CpIdx: Word;
  ClassName, MName, MDesc: String;
  StoreIdx: Integer;
  PrevOp: Byte;
  PC: LongWord;
  LineNum: Integer;
Begin
  If Instructions = Nil Then Exit;
  If (InstrIdx < 0) or (InstrIdx >= InstrCount) Then Exit;
  
  Op := Instructions^[InstrIdx].Opcode;
  PC := Instructions^[InstrIdx].PC;
  LineNum := Instructions^[InstrIdx].LineNum;
  
  ResCurrentPC := PC;
  ResCurrentLine := LineNum;
  
  { Detecter new <classe ressource> }
  If Op = OP_NEW Then Begin
    CpIdx := Word(Instructions^[InstrIdx].Op1);
    If (CpIdx > 0) and (CpIdx < CPCount) Then Begin
      If CP^[CpIdx].Tag = CP_CLASS Then Begin
        ClassName := CPGetUtf8(CP^[CpIdx].Ref1);
        If IsCloseableClass(ClassName) Then Begin
          { Chercher l'instruction astore suivante pour obtenir l'index de variable }
          If (InstrIdx + 1 < InstrCount) Then Begin
            { Peut etre un DUP + INVOKESPECIAL + ASTORE }
            { Pour simplifier, on suppose que la variable sera stockee plus loin }
          End;
        End;
      End;
    End;
  End
  
  { Detecter invokespecial (constructeur) sur classe ressource }
  Else If Op = OP_INVOKESPECIAL Then Begin
    CpIdx := Word(Instructions^[InstrIdx].Op1);
    MName := ExtractMethodNameFromRef(CpIdx);
    MDesc := ExtractMethodDescFromRef(CpIdx);
    ClassName := ExtractClassFromMethodRef(CpIdx);
    
    If (MName = '<init>') and IsCloseableClass(ClassName) Then Begin
      { Chercher l'astore suivant }
      If (InstrIdx + 1 < InstrCount) Then Begin
        PrevOp := Instructions^[InstrIdx + 1].Opcode;
        If (PrevOp >= OP_ASTORE_0) and (PrevOp <= OP_ASTORE_3) Then Begin
          StoreIdx := PrevOp - OP_ASTORE_0;
          TrackResourceOpen(StoreIdx, ClassName, PC, LineNum);
        End
        Else If PrevOp = OP_ASTORE Then Begin
          StoreIdx := Instructions^[InstrIdx + 1].Op1;
          TrackResourceOpen(StoreIdx, ClassName, PC, LineNum);
        End;
      End;
    End;
  End
  
  { Detecter invokevirtual/invokeinterface close() }
  Else If (Op = OP_INVOKEVIRTUAL) or (Op = OP_INVOKEINTERFACE) Then Begin
    CpIdx := Word(Instructions^[InstrIdx].Op1);
    MName := ExtractMethodNameFromRef(CpIdx);
    MDesc := ExtractMethodDescFromRef(CpIdx);
    
    If IsCloseMethod(MName, MDesc) Then Begin
      { Chercher l'aload precedent pour identifier la variable }
      If InstrIdx > 0 Then Begin
        PrevOp := Instructions^[InstrIdx - 1].Opcode;
        If (PrevOp >= OP_ALOAD_0) and (PrevOp <= OP_ALOAD_3) Then Begin
          StoreIdx := PrevOp - OP_ALOAD_0;
          TrackResourceClose(StoreIdx, PC);
        End
        Else If PrevOp = OP_ALOAD Then Begin
          StoreIdx := Instructions^[InstrIdx - 1].Op1;
          TrackResourceClose(StoreIdx, PC);
        End;
      End;
    End;
  End;
End;

{ --- TODO 10 : Detecter les fuites de ressources dans une methode --- }
Procedure DetectResourceLeaks(MethIdx: Integer);
Var
  I, J: Integer;
  HasClose: Boolean;
  BugType: Integer;
Begin
  If (MethIdx < 0) or (MethIdx >= MethodCount) Then Exit;
  If Methods[MethIdx].CodeLen = 0 Then Exit;
  If Instructions = Nil Then Exit;
  If InstrCount = 0 Then Exit;
  
  { Reinitialiser le tracking des ressources pour cette methode }
  ResourceCount := 0;
  ResLeakBugCount := 0;
  
  { Passe 1 : Analyser toutes les instructions }
  For I := 0 to InstrCount - 1 Do Begin
    AnalyzeInstrForResourceLeak(MethIdx, I);
  End;
  
  { Passe 2 : Verifier que toutes les ressources ouvertes sont fermees }
  For I := 0 to ResourceCount - 1 Do Begin
    If Resources[I].State = RS_OPEN Then Begin
      { Chercher si close() est appele quelque part apres l'ouverture }
      HasClose := FindCloseCall(MethIdx, Resources[I].VarIdx, 
                                Resources[I].OpenPC, Methods[MethIdx].CodeLen);
      
      If Not HasClose Then Begin
        { Verifier si c'est dans un bloc try avec finally }
        If HasFinallyHandler(MethIdx, Resources[I].OpenPC) Then
          BugType := RL_UNSATISFIED_OBLIG_EXCEPT
        Else
          BugType := RL_OPEN_STREAM;
        
        AddResLeakBug(BugType, Resources[I].OpenPC, Resources[I].LineNum,
                      Resources[I].ClassName, Resources[I].VarIdx);
        
        { Ajouter aussi au rapport global }
        AddBug(ResLeakBugTypeName(BugType), CAT_CORRECTNESS, SEV_MEDIUM,
               InternalToJavaName(ClassInfo.ThisClass), 
               Methods[MethIdx].Name, '',
               Resources[I].LineNum,
               'Resource ' + Resources[I].ClassName + ' may not be closed');
      End;
    End;
  End;
End;

{ --- TODO 10 : Afficher l'etat du detecteur de ressources --- }
Procedure DumpResLeakState;
Var
  I: Integer;
Begin
  WriteLn;
  WriteLn('=== Resource Leak Detector State ===');
  WriteLn('Initialized    : ', ResLeakInitialized);
  WriteLn('Resources tracked: ', ResourceCount);
  WriteLn('Bugs detected  : ', ResLeakBugCount);
  WriteLn('Total opens    : ', ResTotalOpens);
  WriteLn('Total closes   : ', ResTotalCloses);
  WriteLn('Total leaks    : ', ResTotalLeaks);
  WriteLn('Current PC     : ', ResCurrentPC);
  WriteLn('Current Line   : ', ResCurrentLine);
  WriteLn;
  
  If ResourceCount > 0 Then Begin
    WriteLn('--- Tracked Resources ---');
    For I := 0 to ResourceCount - 1 Do Begin
      WriteLn('  [', I, '] VarIdx=', Resources[I].VarIdx,
              ' Class=', Resources[I].ClassName,
              ' State=', ResStateName(Resources[I].State),
              ' OpenPC=', Resources[I].OpenPC,
              ' ClosePC=', Resources[I].ClosePC);
    End;
    WriteLn;
  End;
  
  If ResLeakBugCount > 0 Then Begin
    WriteLn('--- Resource Leak Bugs ---');
    For I := 0 to ResLeakBugCount - 1 Do Begin
      WriteLn('  [', I, '] ', ResLeakBugTypeName(ResLeakBugs[I].BugType),
              ' PC=', ResLeakBugs[I].PC,
              ' Line=', ResLeakBugs[I].LineNum,
              ' Class=', ResLeakBugs[I].ClassName);
    End;
  End;
End;

{ --- TODO 10 : Accesseurs du module resource leak detector --- }
Function IsResLeakInitialized: Boolean;
Begin
  IsResLeakInitialized := ResLeakInitialized;
End;

Function GetResourceCount: Integer;
Begin
  GetResourceCount := ResourceCount;
End;

Function GetResLeakBugCount: Integer;
Begin
  GetResLeakBugCount := ResLeakBugCount;
End;

Function GetResTotalOpens: Integer;
Begin
  GetResTotalOpens := ResTotalOpens;
End;

Function GetResTotalCloses: Integer;
Begin
  GetResTotalCloses := ResTotalCloses;
End;

Function GetResTotalLeaks: Integer;
Begin
  GetResTotalLeaks := ResTotalLeaks;
End;

Function GetResLabelNum: Integer;
Begin
  GetResLabelNum := ResLabelNum;
End;

Function GetResLeakBugType(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < ResLeakBugCount) Then
    GetResLeakBugType := ResLeakBugs[Idx].BugType
  Else
    GetResLeakBugType := RL_NONE;
End;

Function GetResLeakBugPC(Idx: Integer): LongWord;
Begin
  If (Idx >= 0) and (Idx < ResLeakBugCount) Then
    GetResLeakBugPC := ResLeakBugs[Idx].PC
  Else
    GetResLeakBugPC := 0;
End;

Function GetResLeakBugLine(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < ResLeakBugCount) Then
    GetResLeakBugLine := ResLeakBugs[Idx].LineNum
  Else
    GetResLeakBugLine := 0;
End;

{ ============================================================================ }
{ TODO 11 [IMPLEMENTE] - Detecteur : boucles infinies et blocs inaccessibles   }
{ ============================================================================ }

{ --- TODO 11 : Initialisation du detecteur de boucles infinies --- }
Procedure InitLoopState;
Var
  I: Integer;
Begin
  LoopInitialized := True;
  LoopBugCount := 0;
  DeadStoreCount := 0;
  LoopLabelNum := 0;
  LoopTotalInfinite := 0;
  LoopTotalRecursive := 0;
  LoopTotalDead := 0;
  LoopTotalDeadStores := 0;
  LoopCurrentPC := 0;
  LoopCurrentLine := 0;
  
  { Reinitialiser la table des bugs }
  For I := 0 to MAX_LOOP_BUGS - 1 Do Begin
    LoopBugs[I].BugType := LP_NONE;
    LoopBugs[I].PC := 0;
    LoopBugs[I].LineNum := 0;
    LoopBugs[I].BlockID := -1;
    LoopBugs[I].VarIdx := -1;
    LoopBugs[I].MethodName := '';
  End;
  
  { Reinitialiser la table des dead stores }
  For I := 0 to MAX_DEAD_STORES - 1 Do Begin
    DeadStores[I].VarIdx := -1;
    DeadStores[I].StorePC := 0;
    DeadStores[I].LineNum := 0;
    DeadStores[I].IsRead := False;
  End;
End;

{ --- TODO 11 : Generation d'un label unique pour le module loop --- }
Function GenLoopLabel: String;
Begin
  Inc(LoopLabelNum);
  GenLoopLabel := '_LOOP_' + IntToStr_(LoopLabelNum);
End;

{ --- TODO 11 : Nom du type de bug loop en chaine --- }
Function LoopBugTypeName(BugType: Integer): String;
Begin
  Case BugType of
    LP_NONE                   : LoopBugTypeName := 'NONE';
    IL_INFINITE_LOOP          : LoopBugTypeName := 'IL_INFINITE_LOOP';
    IL_INFINITE_RECURSIVE_LOOP: LoopBugTypeName := 'IL_INFINITE_RECURSIVE_LOOP';
    DLS_DEAD_LOCAL_STORE      : LoopBugTypeName := 'DLS_DEAD_LOCAL_STORE';
    UC_USELESS_VOID_METHOD    : LoopBugTypeName := 'UC_USELESS_VOID_METHOD';
    USELESS_CODE              : LoopBugTypeName := 'USELESS_CODE';
    IL_CONTAINER_MODIFIED     : LoopBugTypeName := 'IL_CONTAINER_MODIFIED';
  Else
    LoopBugTypeName := 'UNKNOWN';
  End;
End;

{ --- TODO 11 : Ajouter un bug de boucle/code mort --- }
Procedure AddLoopBug(BugType: Integer; PC: LongWord; LineNum, BlockID, VarIdx: Integer;
                     MethodName: String);
Begin
  If LoopBugCount < MAX_LOOP_BUGS Then Begin
    LoopBugs[LoopBugCount].BugType := BugType;
    LoopBugs[LoopBugCount].PC := PC;
    LoopBugs[LoopBugCount].LineNum := LineNum;
    LoopBugs[LoopBugCount].BlockID := BlockID;
    LoopBugs[LoopBugCount].VarIdx := VarIdx;
    LoopBugs[LoopBugCount].MethodName := MethodName;
    Inc(LoopBugCount);
    
    { Incrementer le compteur approprie }
    Case BugType of
      IL_INFINITE_LOOP, IL_CONTAINER_MODIFIED:
        Inc(LoopTotalInfinite);
      IL_INFINITE_RECURSIVE_LOOP:
        Inc(LoopTotalRecursive);
      USELESS_CODE, UC_USELESS_VOID_METHOD:
        Inc(LoopTotalDead);
      DLS_DEAD_LOCAL_STORE:
        Inc(LoopTotalDeadStores);
    End;
  End;
End;

{ --- TODO 11 : Ajouter un dead store --- }
Procedure AddDeadStore(VarIdx: Integer; StorePC: LongWord; LineNum: Integer);
Begin
  If DeadStoreCount < MAX_DEAD_STORES Then Begin
    DeadStores[DeadStoreCount].VarIdx := VarIdx;
    DeadStores[DeadStoreCount].StorePC := StorePC;
    DeadStores[DeadStoreCount].LineNum := LineNum;
    DeadStores[DeadStoreCount].IsRead := False;
    Inc(DeadStoreCount);
  End;
End;

{ --- TODO 11 : Marquer une variable comme lue --- }
Procedure MarkVariableRead(VarIdx: Integer);
Var
  I: Integer;
Begin
  For I := 0 to DeadStoreCount - 1 Do Begin
    If DeadStores[I].VarIdx = VarIdx Then Begin
      DeadStores[I].IsRead := True;
    End;
  End;
End;

{ --- TODO 11 : Verifier si une instruction est un store --- }
Function IsStoreOpcode(Opcode: Byte): Boolean;
Begin
  IsStoreOpcode := (Opcode = OP_ISTORE) or (Opcode = OP_LSTORE) or
                   (Opcode = OP_FSTORE) or (Opcode = OP_DSTORE) or
                   (Opcode = OP_ASTORE) or
                   ((Opcode >= OP_ISTORE_0) and (Opcode <= OP_ASTORE_3));
End;

{ --- TODO 11 : Verifier si une instruction est un load --- }
Function IsLoadOpcode(Opcode: Byte): Boolean;
Begin
  IsLoadOpcode := (Opcode = OP_ILOAD) or (Opcode = OP_LLOAD) or
                  (Opcode = OP_FLOAD) or (Opcode = OP_DLOAD) or
                  (Opcode = OP_ALOAD) or
                  ((Opcode >= OP_ILOAD_0) and (Opcode <= OP_ALOAD_3));
End;

{ --- TODO 11 : Extraire l'index de variable d'un store --- }
Function GetStoreVarIdx(Opcode: Byte; Op1: Integer): Integer;
Begin
  Case Opcode of
    OP_ISTORE, OP_LSTORE, OP_FSTORE, OP_DSTORE, OP_ASTORE:
      GetStoreVarIdx := Op1;
    OP_ISTORE_0, OP_LSTORE_0, OP_FSTORE_0, OP_DSTORE_0, OP_ASTORE_0:
      GetStoreVarIdx := 0;
    OP_ISTORE_1, OP_LSTORE_1, OP_FSTORE_1, OP_DSTORE_1, OP_ASTORE_1:
      GetStoreVarIdx := 1;
    OP_ISTORE_2, OP_LSTORE_2, OP_FSTORE_2, OP_DSTORE_2, OP_ASTORE_2:
      GetStoreVarIdx := 2;
    OP_ISTORE_3, OP_LSTORE_3, OP_FSTORE_3, OP_DSTORE_3, OP_ASTORE_3:
      GetStoreVarIdx := 3;
  Else
    GetStoreVarIdx := -1;
  End;
End;

{ --- TODO 11 : Extraire l'index de variable d'un load --- }
Function GetLoadVarIdx(Opcode: Byte; Op1: Integer): Integer;
Begin
  Case Opcode of
    OP_ILOAD, OP_LLOAD, OP_FLOAD, OP_DLOAD, OP_ALOAD:
      GetLoadVarIdx := Op1;
    OP_ILOAD_0, OP_LLOAD_0, OP_FLOAD_0, OP_DLOAD_0, OP_ALOAD_0:
      GetLoadVarIdx := 0;
    OP_ILOAD_1, OP_LLOAD_1, OP_FLOAD_1, OP_DLOAD_1, OP_ALOAD_1:
      GetLoadVarIdx := 1;
    OP_ILOAD_2, OP_LLOAD_2, OP_FLOAD_2, OP_DLOAD_2, OP_ALOAD_2:
      GetLoadVarIdx := 2;
    OP_ILOAD_3, OP_LLOAD_3, OP_FLOAD_3, OP_DLOAD_3, OP_ALOAD_3:
      GetLoadVarIdx := 3;
  Else
    GetLoadVarIdx := -1;
  End;
End;

{ --- TODO 11 : Verifier si un bloc fait partie d'une boucle --- }
Function IsBlockInLoop(BlockID: Integer): Boolean;
Begin
  If (BlockID >= 0) and (BlockID < CFGNodeCount) and (CFGNodes <> Nil) Then
    IsBlockInLoop := CFGNodes^[BlockID].IsBackEdge
  Else
    IsBlockInLoop := False;
End;

{ --- TODO 11 : Verifier si un bloc a une sortie vers l'exterieur --- }
Function HasExitFromBlock(BlockID: Integer): Boolean;
Var
  InstIdx: Integer;
  Opcode: Byte;
Begin
  HasExitFromBlock := False;
  If (BlockID < 0) or (BlockID >= CFGNodeCount) or (CFGNodes = Nil) Then Exit;
  If Instructions = Nil Then Exit;
  
  { Parcourir les instructions du bloc }
  For InstIdx := CFGNodes^[BlockID].InstStart to CFGNodes^[BlockID].InstEnd Do Begin
    If (InstIdx >= 0) and (InstIdx < InstrCount) Then Begin
      Opcode := Instructions^[InstIdx].Opcode;
      { return ou throw = sortie }
      If (Opcode = OP_IRETURN) or (Opcode = OP_LRETURN) or
         (Opcode = OP_FRETURN) or (Opcode = OP_DRETURN) or
         (Opcode = OP_ARETURN) or (Opcode = OP_RETURN) or
         (Opcode = OP_ATHROW) Then Begin
        HasExitFromBlock := True;
        Exit;
      End;
    End;
  End;
End;

{ --- TODO 11 : Detecter les boucles infinies dans une methode --- }
Procedure DetectInfiniteLoops(MethIdx: Integer);
Var
  BlockID, SuccID: Integer;
  HasExit: Boolean;
  J: Integer;
  StartPC: LongWord;
  LineNum: Integer;
Begin
  If (CFGNodes = Nil) or (CFGNodeCount <= 0) Then Exit;
  If (MethIdx < 0) or (MethIdx >= MethodCount) Then Exit;
  
  { Parcourir tous les blocs avec arete arriere (tetes de boucle) }
  For BlockID := 0 to CFGNodeCount - 1 Do Begin
    If CFGNodes^[BlockID].IsBackEdge Then Begin
      { Ce bloc est une tete de boucle - verifier s'il y a une sortie }
      HasExit := False;
      
      { Verifier les successeurs du bloc }
      For J := 0 to CFGNodes^[BlockID].SuccCount - 1 Do Begin
        SuccID := CFGNodes^[BlockID].Succs[J];
        { Si un successeur sort de la boucle ou a un return/throw }
        If HasExitFromBlock(SuccID) Then Begin
          HasExit := True;
        End;
      End;
      
      { Verifier le bloc lui-meme }
      If HasExitFromBlock(BlockID) Then Begin
        HasExit := True;
      End;
      
      { Si pas de sortie detectee, signaler une boucle potentiellement infinie }
      If not HasExit and (CFGNodes^[BlockID].SuccCount > 0) Then Begin
        StartPC := CFGNodes^[BlockID].StartPC;
        LineNum := GetLineNumber(Methods[MethIdx], Word(StartPC));
        AddLoopBug(IL_INFINITE_LOOP, StartPC, LineNum, BlockID, -1,
                   Methods[MethIdx].Name);
      End;
    End;
  End;
End;

{ --- TODO 11 : Detecter les appels recursifs infinis --- }
Procedure DetectInfiniteRecursion(MethIdx: Integer);
Var
  InstIdx: Integer;
  Opcode: Byte;
  CpIdx: Word;
  CalledMethod, CalledClass: String;
  MethodName, ClassName: String;
  HasCondition: Boolean;
  PC: LongWord;
  LineNum: Integer;
Begin
  If (Instructions = Nil) or (InstrCount <= 0) Then Exit;
  If (MethIdx < 0) or (MethIdx >= MethodCount) Then Exit;
  
  MethodName := Methods[MethIdx].Name;
  ClassName := ClassInfo.ThisClass;
  HasCondition := False;
  
  { Parcourir les instructions pour trouver les appels recursifs }
  For InstIdx := 0 to InstrCount - 1 Do Begin
    Opcode := Instructions^[InstIdx].Opcode;
    
    { Detecter les conditions (if*) }
    If IsBranchOpcode(Opcode) Then Begin
      HasCondition := True;
    End;
    
    { Detecter les appels de methode }
    If (Opcode = OP_INVOKEVIRTUAL) or (Opcode = OP_INVOKESPECIAL) or
       (Opcode = OP_INVOKESTATIC) or (Opcode = OP_INVOKEINTERFACE) Then Begin
      CpIdx := Word(Instructions^[InstIdx].Op1);
      CalledMethod := ExtractMethodNameFromRef(CpIdx);
      CalledClass := ExtractClassFromMethodRef(CpIdx);
      
      { Appel recursif ? }
      If (CalledMethod = MethodName) and (CalledClass = ClassName) Then Begin
        { Si pas de condition avant cet appel, c'est suspect }
        If not HasCondition Then Begin
          PC := Instructions^[InstIdx].PC;
          LineNum := GetLineNumber(Methods[MethIdx], Word(PC));
          AddLoopBug(IL_INFINITE_RECURSIVE_LOOP, PC, LineNum, -1, -1, MethodName);
        End;
      End;
    End;
  End;
End;

{ --- TODO 11 : Detecter le code mort (unreachable) --- }
Procedure DetectDeadCode(MethIdx: Integer);
Var
  BlockID: Integer;
  StartPC: LongWord;
  LineNum: Integer;
Begin
  If (CFGNodes = Nil) or (CFGNodeCount <= 0) Then Exit;
  If (MethIdx < 0) or (MethIdx >= MethodCount) Then Exit;
  
  { Parcourir tous les blocs pour trouver ceux non visites }
  For BlockID := 0 to CFGNodeCount - 1 Do Begin
    { Un bloc non visite et non-entree est du code mort }
    If not CFGNodes^[BlockID].Visited and not CFGNodes^[BlockID].IsEntry and
       not CFGNodes^[BlockID].IsException Then Begin
      StartPC := CFGNodes^[BlockID].StartPC;
      LineNum := GetLineNumber(Methods[MethIdx], Word(StartPC));
      
      { Ne pas signaler si c'est un bloc vide }
      If CFGNodes^[BlockID].InstStart <= CFGNodes^[BlockID].InstEnd Then Begin
        AddLoopBug(USELESS_CODE, StartPC, LineNum, BlockID, -1,
                   Methods[MethIdx].Name);
      End;
    End;
  End;
End;

{ --- TODO 11 : Detecter les dead local stores --- }
Procedure DetectDeadLocalStores(MethIdx: Integer);
Var
  InstIdx: Integer;
  Opcode: Byte;
  VarIdx: Integer;
  I: Integer;
Begin
  If (Instructions = Nil) or (InstrCount <= 0) Then Exit;
  If (MethIdx < 0) or (MethIdx >= MethodCount) Then Exit;
  
  { Reinitialiser les dead stores }
  DeadStoreCount := 0;
  
  { Premiere passe : collecter tous les stores }
  For InstIdx := 0 to InstrCount - 1 Do Begin
    Opcode := Instructions^[InstIdx].Opcode;
    If IsStoreOpcode(Opcode) Then Begin
      VarIdx := GetStoreVarIdx(Opcode, Instructions^[InstIdx].Op1);
      If VarIdx >= 0 Then Begin
        AddDeadStore(VarIdx, Instructions^[InstIdx].PC,
                     GetLineNumber(Methods[MethIdx], Word(Instructions^[InstIdx].PC)));
      End;
    End;
  End;
  
  { Deuxieme passe : marquer les variables lues }
  For InstIdx := 0 to InstrCount - 1 Do Begin
    Opcode := Instructions^[InstIdx].Opcode;
    If IsLoadOpcode(Opcode) Then Begin
      VarIdx := GetLoadVarIdx(Opcode, Instructions^[InstIdx].Op1);
      If VarIdx >= 0 Then Begin
        MarkVariableRead(VarIdx);
      End;
    End;
  End;
  
  { Troisieme passe : signaler les stores non lus }
  For I := 0 to DeadStoreCount - 1 Do Begin
    If not DeadStores[I].IsRead Then Begin
      { Ne pas signaler les parametres (variables 0..N selon signature) }
      If DeadStores[I].VarIdx > 0 Then Begin
        AddLoopBug(DLS_DEAD_LOCAL_STORE, DeadStores[I].StorePC,
                   DeadStores[I].LineNum, -1, DeadStores[I].VarIdx,
                   Methods[MethIdx].Name);
      End;
    End;
  End;
End;

{ --- TODO 11 : Detecter les methodes void inutiles --- }
Procedure DetectUselessVoidMethods(MethIdx: Integer);
Var
  HasUsefulCode: Boolean;
  InstIdx: Integer;
  Opcode: Byte;
Begin
  If (Instructions = Nil) or (InstrCount <= 0) Then Exit;
  If (MethIdx < 0) or (MethIdx >= MethodCount) Then Exit;
  
  { Verifier si methode void }
  If Pos(')V', Methods[MethIdx].Descriptor) = 0 Then Exit;
  
  { Verifier si la methode ne contient que aload_0 + return }
  HasUsefulCode := False;
  For InstIdx := 0 to InstrCount - 1 Do Begin
    Opcode := Instructions^[InstIdx].Opcode;
    
    { Ignorer aload_0 (this) et return }
    If (Opcode <> OP_ALOAD_0) and (Opcode <> OP_RETURN) and
       (Opcode <> OP_NOP) Then Begin
      HasUsefulCode := True;
    End;
  End;
  
  { Si methode vide (juste return), signaler }
  If not HasUsefulCode and (InstrCount <= 2) Then Begin
    AddLoopBug(UC_USELESS_VOID_METHOD, 0, 
               GetLineNumber(Methods[MethIdx], 0), -1, -1, Methods[MethIdx].Name);
  End;
End;

{ --- TODO 11 : Analyser une methode pour tous les bugs loop/dead --- }
Procedure AnalyzeMethodForLoopBugs(MethIdx: Integer);
Begin
  If (MethIdx < 0) or (MethIdx >= MethodCount) Then Exit;
  
  { Reinitialiser l'etat pour cette methode }
  InitLoopState;
  
  { Decoder les instructions si pas deja fait }
  If (Instructions = Nil) or (InstrCount = 0) Then Begin
    AllocInstructions;
    DecodeInstructions(Methods[MethIdx]);
  End;
  
  { Lancer tous les detecteurs }
  DetectInfiniteLoops(MethIdx);
  DetectInfiniteRecursion(MethIdx);
  DetectDeadCode(MethIdx);
  DetectDeadLocalStores(MethIdx);
  DetectUselessVoidMethods(MethIdx);
End;

{ --- TODO 11 : Afficher l'etat du detecteur loop --- }
Procedure DumpLoopState;
Var
  I: Integer;
Begin
  WriteLn;
  WriteLn('=== Loop/Dead Code Detector State ===');
  WriteLn('Initialized      : ', LoopInitialized);
  WriteLn('Bugs detected    : ', LoopBugCount);
  WriteLn('Dead stores      : ', DeadStoreCount);
  WriteLn('Total infinite   : ', LoopTotalInfinite);
  WriteLn('Total recursive  : ', LoopTotalRecursive);
  WriteLn('Total dead code  : ', LoopTotalDead);
  WriteLn('Total dead stores: ', LoopTotalDeadStores);
  WriteLn('Current PC       : ', LoopCurrentPC);
  WriteLn('Current Line     : ', LoopCurrentLine);
  WriteLn;
  
  If LoopBugCount > 0 Then Begin
    WriteLn('--- Loop/Dead Code Bugs ---');
    For I := 0 to LoopBugCount - 1 Do Begin
      WriteLn('  [', I, '] ', LoopBugTypeName(LoopBugs[I].BugType),
              ' PC=', LoopBugs[I].PC,
              ' Line=', LoopBugs[I].LineNum,
              ' Method=', LoopBugs[I].MethodName);
    End;
    WriteLn;
  End;
  
  If DeadStoreCount > 0 Then Begin
    WriteLn('--- Dead Stores ---');
    For I := 0 to DeadStoreCount - 1 Do Begin
      WriteLn('  [', I, '] VarIdx=', DeadStores[I].VarIdx,
              ' PC=', DeadStores[I].StorePC,
              ' Line=', DeadStores[I].LineNum,
              ' Read=', DeadStores[I].IsRead);
    End;
  End;
End;

{ --- TODO 11 : Accesseurs du module loop detector --- }
Function IsLoopInitialized: Boolean;
Begin
  IsLoopInitialized := LoopInitialized;
End;

Function GetLoopBugCount: Integer;
Begin
  GetLoopBugCount := LoopBugCount;
End;

Function GetDeadStoreCount: Integer;
Begin
  GetDeadStoreCount := DeadStoreCount;
End;

Function GetLoopTotalInfinite: Integer;
Begin
  GetLoopTotalInfinite := LoopTotalInfinite;
End;

Function GetLoopTotalRecursive: Integer;
Begin
  GetLoopTotalRecursive := LoopTotalRecursive;
End;

Function GetLoopTotalDead: Integer;
Begin
  GetLoopTotalDead := LoopTotalDead;
End;

Function GetLoopTotalDeadStores: Integer;
Begin
  GetLoopTotalDeadStores := LoopTotalDeadStores;
End;

Function GetLoopLabelNum: Integer;
Begin
  GetLoopLabelNum := LoopLabelNum;
End;

Function GetLoopBugType(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < LoopBugCount) Then
    GetLoopBugType := LoopBugs[Idx].BugType
  Else
    GetLoopBugType := LP_NONE;
End;

Function GetLoopBugPC(Idx: Integer): LongWord;
Begin
  If (Idx >= 0) and (Idx < LoopBugCount) Then
    GetLoopBugPC := LoopBugs[Idx].PC
  Else
    GetLoopBugPC := 0;
End;

Function GetLoopBugLine(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < LoopBugCount) Then
    GetLoopBugLine := LoopBugs[Idx].LineNum
  Else
    GetLoopBugLine := 0;
End;

{ ============================================================================ }
{ TODO 12 [IMPLEMENTE] - Detecteur : mauvaises pratiques (bad practices)       }
{ ============================================================================ }

{ --- TODO 12 : Initialisation du detecteur de mauvaises pratiques --- }
Procedure InitBadPracticesState;
Var
  I: Integer;
Begin
  BPInitialized := True;
  BPBugCount := 0;
  BPCastCount := 0;
  BPLabelNum := 0;
  BPTotalCasts := 0;
  BPTotalUnchecked := 0;
  BPTotalIgnored := 0;
  BPTotalRetNotChecked := 0;
  BPCurrentPC := 0;
  BPCurrentLine := 0;
  BPHasClone := False;
  BPHasEquals := False;
  BPHasHashCode := False;
  BPHasFinalize := False;
  BPFinalizePublic := False;
  BPImplementsCloneable := False;
  
  { Reinitialiser la table des bugs }
  For I := 0 to MAX_BP_BUGS - 1 Do Begin
    BPBugs[I].BugType := BP_NONE;
    BPBugs[I].PC := 0;
    BPBugs[I].LineNum := 0;
    BPBugs[I].ClassName := '';
    BPBugs[I].MethodName := '';
    BPBugs[I].TypeName := '';
  End;
  
  { Reinitialiser la table des checkcast }
  For I := 0 to MAX_BP_CASTS - 1 Do Begin
    BPCasts[I].PC := 0;
    BPCasts[I].TargetType := '';
    BPCasts[I].HasPriorInstanceof := False;
  End;
End;

{ --- TODO 12 : Generation d'un label unique pour le module BP --- }
Function GenBPLabel: String;
Begin
  Inc(BPLabelNum);
  GenBPLabel := '_BP_' + IntToStr_(BPLabelNum);
End;

{ --- TODO 12 : Nom du type de bug BP en chaine --- }
Function BPBugTypeName(BugType: Integer): String;
Begin
  Case BugType of
    BP_NONE                               : BPBugTypeName := 'NONE';
    BC_UNCONFIRMED_CAST                   : BPBugTypeName := 'BC_UNCONFIRMED_CAST';
    CN_IMPLEMENTS_CLONE_BUT_NOT_CLONEABLE : BPBugTypeName := 'CN_IMPLEMENTS_CLONE_BUT_NOT_CLONEABLE';
    DE_MIGHT_IGNORE                       : BPBugTypeName := 'DE_MIGHT_IGNORE';
    EQ_DOESNT_OVERRIDE_EQUALS             : BPBugTypeName := 'EQ_DOESNT_OVERRIDE_EQUALS';
    FI_PUBLIC_SHOULD_BE_PROTECTED         : BPBugTypeName := 'FI_PUBLIC_SHOULD_BE_PROTECTED';
    HE_HASHCODE_USE_OBJECT_EQUALS         : BPBugTypeName := 'HE_HASHCODE_USE_OBJECT_EQUALS';
    HE_EQUALS_USE_OBJECT_HASHCODE         : BPBugTypeName := 'HE_EQUALS_USE_OBJECT_HASHCODE';
    RR_NOT_CHECKED                        : BPBugTypeName := 'RR_NOT_CHECKED';
    SR_NOT_CHECKED                        : BPBugTypeName := 'SR_NOT_CHECKED';
  Else
    BPBugTypeName := 'UNKNOWN';
  End;
End;

{ --- TODO 12 : Ajouter un bug bad practice detecte --- }
Procedure AddBadPracticeBug(BugType: Integer; PC: LongWord; LineNum: Integer;
                             ClassName, MethodName, TypeName: String);
Begin
  If BPBugCount < MAX_BP_BUGS Then Begin
    BPBugs[BPBugCount].BugType := BugType;
    BPBugs[BPBugCount].PC := PC;
    BPBugs[BPBugCount].LineNum := LineNum;
    BPBugs[BPBugCount].ClassName := ClassName;
    BPBugs[BPBugCount].MethodName := MethodName;
    BPBugs[BPBugCount].TypeName := TypeName;
    Inc(BPBugCount);
  End;
End;

{ --- TODO 12 : Verifier si une methode est read() d'InputStream --- }
Function IsReadMethod(ClassName, MethodName, Descriptor: String): Boolean;
Begin
  { Detecter les appels a read() sur InputStream et ses sous-classes }
  IsReadMethod := False;
  If MethodName = 'read' Then Begin
    If (Pos('InputStream', ClassName) > 0) or
       (Pos('Reader', ClassName) > 0) Then Begin
      { read() retourne un int (I) }
      If (Pos(')I', Descriptor) > 0) Then
        IsReadMethod := True;
    End;
  End;
End;

{ --- TODO 12 : Verifier si une methode est skip() d'InputStream --- }
Function IsSkipMethod(ClassName, MethodName, Descriptor: String): Boolean;
Begin
  { Detecter les appels a skip() sur InputStream et ses sous-classes }
  IsSkipMethod := False;
  If MethodName = 'skip' Then Begin
    If (Pos('InputStream', ClassName) > 0) or
       (Pos('Reader', ClassName) > 0) Then Begin
      { skip(long) retourne un long (J) }
      If (Pos(')J', Descriptor) > 0) Then
        IsSkipMethod := True;
    End;
  End;
End;

{ --- TODO 12 : Tracker un checkcast pour verification instanceof --- }
Procedure TrackCheckcast(PC: LongWord; TargetType: String);
Begin
  If BPCastCount < MAX_BP_CASTS Then Begin
    BPCasts[BPCastCount].PC := PC;
    BPCasts[BPCastCount].TargetType := TargetType;
    BPCasts[BPCastCount].HasPriorInstanceof := False;
    Inc(BPCastCount);
    Inc(BPTotalCasts);
  End;
End;

{ --- TODO 12 : Marquer un instanceof pour le type donne --- }
Procedure MarkInstanceofSeen(TargetType: String);
Var
  I: Integer;
Begin
  { Marquer tous les checkcast du meme type comme ayant un instanceof prealable }
  For I := 0 to BPCastCount - 1 Do Begin
    If BPCasts[I].TargetType = TargetType Then
      BPCasts[I].HasPriorInstanceof := True;
  End;
End;

{ --- TODO 12 : Verifier si un bloc catch est vide (exception ignoree) --- }
Function IsCatchBlockEmpty(StartPC, EndPC: LongWord): Boolean;
Var
  I: Integer;
  CodeLen: LongWord;
  HasCode: Boolean;
Begin
  { Un catch block vide contient seulement astore (store exception) et
    eventuellement aload + athrow, ou juste un return/goto }
  IsCatchBlockEmpty := False;
  
  If (Instructions = Nil) or (InstrCount = 0) Then Exit;
  
  CodeLen := EndPC - StartPC;
  HasCode := False;
  
  For I := 0 to InstrCount - 1 Do Begin
    If (Instructions^[I].PC >= StartPC) and (Instructions^[I].PC < EndPC) Then Begin
      { Verifier si c'est une instruction significative }
      Case Instructions^[I].Opcode of
        OP_ASTORE, OP_ASTORE_0, OP_ASTORE_1, OP_ASTORE_2, OP_ASTORE_3,
        OP_POP, OP_POP2, OP_RETURN, OP_GOTO, OP_GOTO_W:
          ; { Ces instructions sont acceptables dans un catch vide }
      Else
        HasCode := True; { Instruction significative trouvee }
      End;
    End;
  End;
  
  { Si tres peu de code et pas d'instruction significative, le catch est vide }
  If (CodeLen <= 5) and (not HasCode) Then
    IsCatchBlockEmpty := True;
End;

{ --- TODO 12 : Verifier si la classe a une methode clone() --- }
Function HasCloneMethod: Boolean;
Var
  I: Integer;
Begin
  HasCloneMethod := False;
  For I := 0 to MethodCount - 1 Do Begin
    If (Methods[I].Name = 'clone') and
       (Methods[I].Descriptor = '()Ljava/lang/Object;') Then Begin
      HasCloneMethod := True;
      Exit;
    End;
  End;
End;

{ --- TODO 12 : Verifier si la classe a une methode equals(Object) --- }
Function HasEqualsMethod: Boolean;
Var
  I: Integer;
Begin
  HasEqualsMethod := False;
  For I := 0 to MethodCount - 1 Do Begin
    If (Methods[I].Name = 'equals') and
       (Methods[I].Descriptor = '(Ljava/lang/Object;)Z') Then Begin
      HasEqualsMethod := True;
      Exit;
    End;
  End;
End;

{ --- TODO 12 : Verifier si la classe a une methode hashCode() --- }
Function HasHashCodeMethod: Boolean;
Var
  I: Integer;
Begin
  HasHashCodeMethod := False;
  For I := 0 to MethodCount - 1 Do Begin
    If (Methods[I].Name = 'hashCode') and
       (Methods[I].Descriptor = '()I') Then Begin
      HasHashCodeMethod := True;
      Exit;
    End;
  End;
End;

{ --- TODO 12 : Verifier si la classe a une methode finalize() et si elle est public --- }
Function HasFinalizeMethod(Var IsPublic: Boolean): Boolean;
Var
  I: Integer;
Begin
  HasFinalizeMethod := False;
  IsPublic := False;
  For I := 0 to MethodCount - 1 Do Begin
    If (Methods[I].Name = 'finalize') and
       (Methods[I].Descriptor = '()V') Then Begin
      HasFinalizeMethod := True;
      IsPublic := Methods[I].IsPublic;
      Exit;
    End;
  End;
End;

{ --- TODO 12 : Verifier si la classe implemente Cloneable --- }
Function ImplementsCloneable: Boolean;
Var
  I: Integer;
Begin
  ImplementsCloneable := False;
  For I := 0 to ClassInfo.InterfaceCount - 1 Do Begin
    If Pos('Cloneable', ClassInfo.Interfaces[I]) > 0 Then Begin
      ImplementsCloneable := True;
      Exit;
    End;
  End;
End;

{ --- TODO 12 : Detecter les mauvaises pratiques dans une methode --- }
Procedure DetectBadPractices(MethIdx: Integer);
Var
  I, J, K: Integer;
  Inst: TInstruction;
  CpIdx: Word;
  ClassName, MethodName, Descriptor: String;
  TargetType: String;
  LineNum: Integer;
  FoundInstanceof: Boolean;
  PrevOpcode: Byte;
Begin
  If (Instructions = Nil) or (InstrCount = 0) Then Exit;
  If (MethIdx < 0) or (MethIdx >= MethodCount) Then Exit;
  
  { Reinitialiser les checkcast trackes pour cette methode }
  BPCastCount := 0;
  
  { Premiere passe : collecter tous les instanceof }
  For I := 0 to InstrCount - 1 Do Begin
    Inst := Instructions^[I];
    If Inst.Opcode = OP_INSTANCEOF Then Begin
      { Extraire le type cible de l'instanceof }
      CpIdx := Inst.Op1;
      If (CpIdx > 0) and (CpIdx < CPCount) Then Begin
        TargetType := CPGetClassName(CpIdx);
        MarkInstanceofSeen(TargetType);
      End;
    End;
  End;
  
  { Deuxieme passe : analyser les instructions }
  PrevOpcode := OP_NOP;
  For I := 0 to InstrCount - 1 Do Begin
    Inst := Instructions^[I];
    BPCurrentPC := Inst.PC;
    LineNum := GetLineNumber(Methods[MethIdx], Inst.PC);
    BPCurrentLine := LineNum;
    
    Case Inst.Opcode of
      OP_CHECKCAST: Begin
        { Verifier si un instanceof precede ce checkcast }
        CpIdx := Inst.Op1;
        If (CpIdx > 0) and (CpIdx < CPCount) Then Begin
          TargetType := CPGetClassName(CpIdx);
          
          { Chercher si un instanceof pour ce type a ete vu avant }
          FoundInstanceof := False;
          For J := 0 to I - 1 Do Begin
            If Instructions^[J].Opcode = OP_INSTANCEOF Then Begin
              K := Instructions^[J].Op1;
              If (K > 0) and (K < CPCount) Then Begin
                If CPGetClassName(K) = TargetType Then Begin
                  FoundInstanceof := True;
                  Break;
                End;
              End;
            End;
          End;
          
          If not FoundInstanceof Then Begin
            { Cast sans instanceof prealable = bug potentiel }
            AddBadPracticeBug(BC_UNCONFIRMED_CAST, Inst.PC, LineNum,
                              ClassInfo.ThisClass,
                              Methods[MethIdx].Name, TargetType);
            Inc(BPTotalUnchecked);
          End;
        End;
      End;
      
      OP_INVOKEVIRTUAL, OP_INVOKEINTERFACE: Begin
        { Verifier les appels a read() ou skip() }
        CpIdx := Inst.Op1;
        If (CpIdx > 0) and (CpIdx < CPCount) Then Begin
          ClassName := '';
          MethodName := '';
          Descriptor := '';
          CPGetMemberRef(CpIdx, ClassName, MethodName, Descriptor);
          
          { Detecter read() dont le retour n'est pas verifie }
          If IsReadMethod(ClassName, MethodName, Descriptor) Then Begin
            { Verifier si l'instruction suivante est pop (ignore le resultat) }
            If (I + 1 < InstrCount) Then Begin
              If (Instructions^[I + 1].Opcode = OP_POP) or
                 (Instructions^[I + 1].Opcode = OP_POP2) Then Begin
                AddBadPracticeBug(RR_NOT_CHECKED, Inst.PC, LineNum,
                                  ClassName, MethodName, '');
                Inc(BPTotalRetNotChecked);
              End;
            End;
          End;
          
          { Detecter skip() dont le retour n'est pas verifie }
          If IsSkipMethod(ClassName, MethodName, Descriptor) Then Begin
            If (I + 1 < InstrCount) Then Begin
              If (Instructions^[I + 1].Opcode = OP_POP) or
                 (Instructions^[I + 1].Opcode = OP_POP2) Then Begin
                AddBadPracticeBug(SR_NOT_CHECKED, Inst.PC, LineNum,
                                  ClassName, MethodName, '');
                Inc(BPTotalRetNotChecked);
              End;
            End;
          End;
        End;
      End;
    End;
    
    PrevOpcode := Inst.Opcode;
  End;
  
  { Analyser les blocs catch pour les exceptions ignorees }
  For I := 0 to Methods[MethIdx].ExcCount - 1 Do Begin
    If IsCatchBlockEmpty(Methods[MethIdx].ExcTable[I].HandlerPC,
                         Methods[MethIdx].ExcTable[I].HandlerPC + 5) Then Begin
      LineNum := GetLineNumber(Methods[MethIdx], Methods[MethIdx].ExcTable[I].HandlerPC);
      AddBadPracticeBug(DE_MIGHT_IGNORE, Methods[MethIdx].ExcTable[I].HandlerPC,
                        LineNum, ClassInfo.ThisClass,
                        Methods[MethIdx].Name,
                        Methods[MethIdx].ExcTable[I].CatchName);
      Inc(BPTotalIgnored);
    End;
  End;
End;

{ --- TODO 12 : Detecter les mauvaises pratiques au niveau de la classe --- }
Procedure DetectBadClassPractices;
Var
  FinalizeIsPublic: Boolean;
Begin
  { Analyser la structure de la classe }
  BPHasClone := HasCloneMethod;
  BPHasEquals := HasEqualsMethod;
  BPHasHashCode := HasHashCodeMethod;
  BPHasFinalize := HasFinalizeMethod(FinalizeIsPublic);
  BPFinalizePublic := FinalizeIsPublic;
  BPImplementsCloneable := ImplementsCloneable;
  
  { Verifier clone() sans Cloneable }
  If BPHasClone and (not BPImplementsCloneable) Then Begin
    AddBadPracticeBug(CN_IMPLEMENTS_CLONE_BUT_NOT_CLONEABLE, 0, 0,
                      ClassInfo.ThisClass, 'clone', '');
  End;
  
  { Verifier equals() sans hashCode() }
  If BPHasEquals and (not BPHasHashCode) Then Begin
    AddBadPracticeBug(HE_EQUALS_USE_OBJECT_HASHCODE, 0, 0,
                      ClassInfo.ThisClass, 'equals', '');
  End;
  
  { Verifier hashCode() sans equals() }
  If BPHasHashCode and (not BPHasEquals) Then Begin
    AddBadPracticeBug(HE_HASHCODE_USE_OBJECT_EQUALS, 0, 0,
                      ClassInfo.ThisClass, 'hashCode', '');
  End;
  
  { Verifier finalize() public }
  If BPHasFinalize and BPFinalizePublic Then Begin
    AddBadPracticeBug(FI_PUBLIC_SHOULD_BE_PROTECTED, 0, 0,
                      ClassInfo.ThisClass, 'finalize', '');
  End;
  
  { Verifier sous-classe avec champs supplementaires sans equals() }
  { Note: cette detection complete necessite d'analyser la super-classe }
  { Pour l'instant, on detecte seulement les classes avec champs et super != Object }
  If (FieldCount > 0) and (not BPHasEquals) Then Begin
    If ClassInfo.SuperClass <> '' Then Begin
      If ClassInfo.SuperClass <> 'java/lang/Object' Then Begin
        { La classe a des champs et herite d'autre chose qu'Object }
        { Si elle n'a pas equals(), c'est potentiellement un probleme }
        AddBadPracticeBug(EQ_DOESNT_OVERRIDE_EQUALS, 0, 0,
                          ClassInfo.ThisClass, '', '');
      End;
    End;
  End;
End;

{ --- TODO 12 : Analyser une methode pour les mauvaises pratiques --- }
Procedure AnalyzeMethodForBadPractices(MethIdx: Integer);
Begin
  If not BPInitialized Then
    InitBadPracticesState;
    
  If (MethIdx < 0) or (MethIdx >= MethodCount) Then Exit;
  
  { Decoder les instructions si pas deja fait }
  If (Instructions = Nil) or (InstrCount = 0) Then Begin
    If Methods[MethIdx].CodeLen > 0 Then Begin
      AllocInstructions;
      DecodeInstructions(Methods[MethIdx]);
    End;
  End;
  
  { Detecter les mauvaises pratiques dans cette methode }
  DetectBadPractices(MethIdx);
End;

{ --- TODO 12 : Dump de l'etat du module bad practices --- }
Procedure DumpBadPracticesState;
Var
  I: Integer;
Begin
  WriteLn('=== Bad Practices State ===');
  WriteLn('Initialized: ', BPInitialized);
  WriteLn('Bug Count: ', BPBugCount);
  WriteLn('Cast Count: ', BPCastCount);
  WriteLn('Total Casts: ', BPTotalCasts);
  WriteLn('Total Unchecked: ', BPTotalUnchecked);
  WriteLn('Total Ignored: ', BPTotalIgnored);
  WriteLn('Total Ret Not Checked: ', BPTotalRetNotChecked);
  WriteLn('Has Clone: ', BPHasClone);
  WriteLn('Has Equals: ', BPHasEquals);
  WriteLn('Has HashCode: ', BPHasHashCode);
  WriteLn('Has Finalize: ', BPHasFinalize);
  WriteLn('Finalize Public: ', BPFinalizePublic);
  WriteLn('Implements Cloneable: ', BPImplementsCloneable);
  
  If BPBugCount > 0 Then Begin
    WriteLn('--- Bugs ---');
    For I := 0 to BPBugCount - 1 Do Begin
      WriteLn('  [', I, '] Type=', BPBugTypeName(BPBugs[I].BugType),
              ' PC=', BPBugs[I].PC, ' Line=', BPBugs[I].LineNum,
              ' Class=', BPBugs[I].ClassName,
              ' Method=', BPBugs[I].MethodName,
              ' Info=', BPBugs[I].TypeName);
    End;
  End;
End;

{ --- TODO 12 : Accesseurs du module bad practices --- }
Function IsBPInitialized: Boolean;
Begin
  IsBPInitialized := BPInitialized;
End;

Function GetBPBugCount: Integer;
Begin
  GetBPBugCount := BPBugCount;
End;

Function GetBPCastCount: Integer;
Begin
  GetBPCastCount := BPCastCount;
End;

Function GetBPTotalCasts: Integer;
Begin
  GetBPTotalCasts := BPTotalCasts;
End;

Function GetBPTotalUnchecked: Integer;
Begin
  GetBPTotalUnchecked := BPTotalUnchecked;
End;

Function GetBPTotalIgnored: Integer;
Begin
  GetBPTotalIgnored := BPTotalIgnored;
End;

Function GetBPTotalRetNotChecked: Integer;
Begin
  GetBPTotalRetNotChecked := BPTotalRetNotChecked;
End;

Function GetBPLabelNum: Integer;
Begin
  GetBPLabelNum := BPLabelNum;
End;

Function GetBPBugType(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < BPBugCount) Then
    GetBPBugType := BPBugs[Idx].BugType
  Else
    GetBPBugType := BP_NONE;
End;

Function GetBPBugPC(Idx: Integer): LongWord;
Begin
  If (Idx >= 0) and (Idx < BPBugCount) Then
    GetBPBugPC := BPBugs[Idx].PC
  Else
    GetBPBugPC := 0;
End;

Function GetBPBugLine(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < BPBugCount) Then
    GetBPBugLine := BPBugs[Idx].LineNum
  Else
    GetBPBugLine := 0;
End;

{ ============================================================================ }
{ TODO 13 [IMPLEMENTE] - Detecteur : comparaisons incorrectes d'objets          }
{ ============================================================================ }

{ --- TODO 13 : Initialiser l'etat du module comparaisons incorrectes --- }
Procedure InitBadCompState;
Var
  I: Integer;
Begin
  BCInitialized := True;
  BCBugCount := 0;
  BCStackTypeTop := 0;
  BCLabelNum := 0;
  BCTotalCompares := 0;
  BCTotalBadString := 0;
  BCTotalBadWrapper := 0;
  BCTotalUnrelated := 0;
  BCTotalBadCollection := 0;
  BCCurrentPC := 0;
  BCCurrentLine := 0;
  
  For I := 0 to MAX_BC_BUGS - 1 Do Begin
    BCBugs[I].BugType := BC_NONE;
    BCBugs[I].PC := 0;
    BCBugs[I].LineNum := 0;
    BCBugs[I].ClassName := '';
    BCBugs[I].MethodName := '';
    BCBugs[I].Type1 := '';
    BCBugs[I].Type2 := '';
  End;
  
  For I := 0 to MAX_BC_STACK_TYPES - 1 Do Begin
    BCStackTypes[I].StackType := ST_UNKNOWN;
    BCStackTypes[I].TypeName := '';
    BCStackTypes[I].SourcePC := 0;
    BCStackTypes[I].IsNew := False;
  End;
End;

{ --- TODO 13 : Generer un label unique pour le module --- }
Function GenBCLabel: String;
Begin
  Inc(BCLabelNum);
  GenBCLabel := '_BC_' + IntToStr_(BCLabelNum);
End;

{ --- TODO 13 : Convertir un type de bug en chaine --- }
Function BCBugTypeName(BugType: Integer): String;
Begin
  Case BugType of
    BC_NONE:                           BCBugTypeName := 'BC_NONE';
    EC_UNRELATED_TYPES:                BCBugTypeName := 'EC_UNRELATED_TYPES';
    ES_COMPARING_STRINGS_WITH_EQ:      BCBugTypeName := 'ES_COMPARING_STRINGS_WITH_EQ';
    RC_REF_COMPARISON_BAD_PRACTICE:    BCBugTypeName := 'RC_REF_COMPARISON_BAD_PRACTICE';
    GC_UNRELATED_TYPES:                BCBugTypeName := 'GC_UNRELATED_TYPES';
    EC_ARRAY_AND_NONARRAY:             BCBugTypeName := 'EC_ARRAY_AND_NONARRAY';
    EC_BAD_ARRAY_COMPARE:              BCBugTypeName := 'EC_BAD_ARRAY_COMPARE';
    RC_REF_COMPARISON_BAD_PRACTICE_BOOLEAN: BCBugTypeName := 'RC_REF_COMPARISON_BAD_PRACTICE_BOOLEAN';
  Else
    BCBugTypeName := 'UNKNOWN_BC_BUG';
  End;
End;

{ --- TODO 13 : Convertir un type de pile en chaine --- }
Function BCStackTypeName(StackType: Integer): String;
Begin
  Case StackType of
    ST_UNKNOWN:    BCStackTypeName := 'UNKNOWN';
    ST_NULL:       BCStackTypeName := 'NULL';
    ST_INT:        BCStackTypeName := 'INT';
    ST_LONG:       BCStackTypeName := 'LONG';
    ST_FLOAT:      BCStackTypeName := 'FLOAT';
    ST_DOUBLE:     BCStackTypeName := 'DOUBLE';
    ST_REF:        BCStackTypeName := 'REF';
    ST_STRING:     BCStackTypeName := 'STRING';
    ST_WRAPPER:    BCStackTypeName := 'WRAPPER';
    ST_ARRAY:      BCStackTypeName := 'ARRAY';
    ST_COLLECTION: BCStackTypeName := 'COLLECTION';
  Else
    BCStackTypeName := 'INVALID';
  End;
End;

{ --- TODO 13 : Verifier si le descripteur est un type String --- }
Function IsStringType(Desc: String): Boolean;
Var
  D: String;
Begin
  D := Desc;
  { Enlever le L et le ; si present }
  If (Length(D) > 0) and (D[1] = 'L') Then
    Delete(D, 1, 1);
  If (Length(D) > 0) and (D[Length(D)] = ';') Then
    Delete(D, Length(D), 1);
  
  { Comparer avec les formes possibles de String }
  IsStringType := (D = 'java/lang/String') or
                  (D = 'Ljava/lang/String;') or
                  (D = 'Ljava/lang/String') or
                  (Desc = 'Ljava/lang/String;');
End;

{ --- TODO 13 : Verifier si le nom de classe est un type wrapper Java --- }
Function IsWrapperType(ClassName: String): Boolean;
Var
  C: String;
Begin
  C := ClassName;
  { Enlever le L et le ; si present }
  If (Length(C) > 0) and (C[1] = 'L') Then
    Delete(C, 1, 1);
  If (Length(C) > 0) and (C[Length(C)] = ';') Then
    Delete(C, Length(C), 1);
  
  IsWrapperType := (C = 'java/lang/Integer') or
                   (C = 'java/lang/Long') or
                   (C = 'java/lang/Short') or
                   (C = 'java/lang/Byte') or
                   (C = 'java/lang/Character') or
                   (C = 'java/lang/Float') or
                   (C = 'java/lang/Double') or
                   (C = 'java/lang/Boolean');
End;

{ --- TODO 13 : Verifier si le nom de classe est un type Collection --- }
Function IsCollectionType(ClassName: String): Boolean;
Var
  C: String;
Begin
  C := ClassName;
  { Enlever le L et le ; si present }
  If (Length(C) > 0) and (C[1] = 'L') Then
    Delete(C, 1, 1);
  If (Length(C) > 0) and (C[Length(C)] = ';') Then
    Delete(C, Length(C), 1);
  
  IsCollectionType := (Pos('java/util/List', C) > 0) or
                      (Pos('java/util/Set', C) > 0) or
                      (Pos('java/util/Map', C) > 0) or
                      (Pos('java/util/Collection', C) > 0) or
                      (Pos('java/util/ArrayList', C) > 0) or
                      (Pos('java/util/HashMap', C) > 0) or
                      (Pos('java/util/HashSet', C) > 0) or
                      (Pos('java/util/LinkedList', C) > 0) or
                      (Pos('java/util/TreeMap', C) > 0) or
                      (Pos('java/util/TreeSet', C) > 0);
End;

{ --- TODO 13 : Verifier si le nom est une methode de recherche Collection --- }
Function IsCollectionGetMethod(MethodName: String): Boolean;
Begin
  IsCollectionGetMethod := (MethodName = 'get') or
                           (MethodName = 'contains') or
                           (MethodName = 'containsKey') or
                           (MethodName = 'containsValue') or
                           (MethodName = 'indexOf') or
                           (MethodName = 'lastIndexOf') or
                           (MethodName = 'remove');
End;

{ --- TODO 13 : Determiner le type de pile d'un descripteur --- }
Function DescriptorToStackType(Desc: String): Integer;
Begin
  If Length(Desc) = 0 Then Begin
    DescriptorToStackType := ST_UNKNOWN;
    Exit;
  End;
  
  Case Desc[1] of
    'B', 'C', 'I', 'S', 'Z': DescriptorToStackType := ST_INT;
    'J': DescriptorToStackType := ST_LONG;
    'F': DescriptorToStackType := ST_FLOAT;
    'D': DescriptorToStackType := ST_DOUBLE;
    '[': DescriptorToStackType := ST_ARRAY;
    'L': Begin
      If IsStringType(Desc) Then
        DescriptorToStackType := ST_STRING
      Else If IsWrapperType(Desc) Then
        DescriptorToStackType := ST_WRAPPER
      Else If IsCollectionType(Desc) Then
        DescriptorToStackType := ST_COLLECTION
      Else
        DescriptorToStackType := ST_REF;
    End;
  Else
    DescriptorToStackType := ST_UNKNOWN;
  End;
End;

{ --- TODO 13 : Pousser un type sur la pile de types --- }
Procedure BCPushType(StackType: Integer; TypeName: String; PC: LongWord; IsNew: Boolean);
Begin
  If BCStackTypeTop < MAX_BC_STACK_TYPES Then Begin
    BCStackTypes[BCStackTypeTop].StackType := StackType;
    BCStackTypes[BCStackTypeTop].TypeName := TypeName;
    BCStackTypes[BCStackTypeTop].SourcePC := PC;
    BCStackTypes[BCStackTypeTop].IsNew := IsNew;
    Inc(BCStackTypeTop);
  End;
End;

{ --- TODO 13 : Depiler un type de la pile de types --- }
Function BCPopType: TStackTypeInfo;
Var
  Empty: TStackTypeInfo;
Begin
  If BCStackTypeTop > 0 Then Begin
    Dec(BCStackTypeTop);
    BCPopType := BCStackTypes[BCStackTypeTop];
  End Else Begin
    Empty.StackType := ST_UNKNOWN;
    Empty.TypeName := '';
    Empty.SourcePC := 0;
    Empty.IsNew := False;
    BCPopType := Empty;
  End;
End;

{ --- TODO 13 : Vider la pile de types --- }
Procedure BCClearStack;
Begin
  BCStackTypeTop := 0;
End;

{ --- TODO 13 : Ajouter un bug de comparaison incorrecte --- }
Procedure AddBadCompBug(BugType: Integer; PC: LongWord; LineNum: Integer;
                         AClassName, AMethodName, Type1, Type2: String);
Begin
  If BCBugCount < MAX_BC_BUGS Then Begin
    BCBugs[BCBugCount].BugType := BugType;
    BCBugs[BCBugCount].PC := PC;
    BCBugs[BCBugCount].LineNum := LineNum;
    BCBugs[BCBugCount].ClassName := AClassName;
    BCBugs[BCBugCount].MethodName := AMethodName;
    BCBugs[BCBugCount].Type1 := Type1;
    BCBugs[BCBugCount].Type2 := Type2;
    Inc(BCBugCount);
  End;
End;

{ --- TODO 13 : Verifier si deux types sont relies (compatibles) --- }
Function AreTypesRelated(Type1, Type2: String): Boolean;
Var
  T1, T2: String;
Begin
  { Nettoyer les types }
  T1 := Type1;
  T2 := Type2;
  If (Length(T1) > 0) and (T1[1] = 'L') Then Delete(T1, 1, 1);
  If (Length(T1) > 0) and (T1[Length(T1)] = ';') Then Delete(T1, Length(T1), 1);
  If (Length(T2) > 0) and (T2[1] = 'L') Then Delete(T2, 1, 1);
  If (Length(T2) > 0) and (T2[Length(T2)] = ';') Then Delete(T2, Length(T2), 1);
  
  { Meme type = relies }
  If T1 = T2 Then Begin
    AreTypesRelated := True;
    Exit;
  End;
  
  { Object est relie a tout }
  If (T1 = 'java/lang/Object') or (T2 = 'java/lang/Object') Then Begin
    AreTypesRelated := True;
    Exit;
  End;
  
  { Si l'un est vide ou inconnu }
  If (T1 = '') or (T2 = '') Then Begin
    AreTypesRelated := True;  { On ne sait pas, donc on presume relie }
    Exit;
  End;
  
  { Cas simples de types non-relies (heuristique) }
  { String vs autres types specifiques }
  If (T1 = 'java/lang/String') and IsWrapperType(T2) Then Begin
    AreTypesRelated := False;
    Exit;
  End;
  If (T2 = 'java/lang/String') and IsWrapperType(T1) Then Begin
    AreTypesRelated := False;
    Exit;
  End;
  
  { Par defaut, on presume relies (analyse simplifiee) }
  AreTypesRelated := True;
End;

{ --- TODO 13 : Detecter les comparaisons incorrectes dans une methode --- }
Procedure DetectBadComparisons(MethIdx: Integer);
Var
  I: Integer;
  Inst: TInstruction;
  LineNum: Integer;
  CpIdx: Integer;
  ClassName, MethodName, Descriptor: String;
  Type1Info, Type2Info: TStackTypeInfo;
  ReturnType: String;
  Pos1: Integer;
Begin
  If not BCInitialized Then
    InitBadCompState;
    
  If (MethIdx < 0) or (MethIdx >= MethodCount) Then Exit;
  If Instructions = Nil Then Exit;
  If InstrCount = 0 Then Exit;
  
  { Reinitialiser la pile de types pour cette methode }
  BCClearStack;
  
  { Parcourir les instructions }
  For I := 0 to InstrCount - 1 Do Begin
    Inst := Instructions^[I];
    BCCurrentPC := Inst.PC;
    LineNum := GetLineNumber(Methods[MethIdx], Inst.PC);
    BCCurrentLine := LineNum;
    
    Case Inst.Opcode of
      { Instructions qui poussent null }
      OP_ACONST_NULL: Begin
        BCPushType(ST_NULL, '', Inst.PC, False);
      End;
      
      { Instructions new }
      OP_NEW: Begin
        CpIdx := Inst.Op1;
        If (CpIdx > 0) and (CpIdx < CPCount) Then Begin
          ClassName := CPGetClassName(CpIdx);
          If IsStringType(ClassName) Then
            BCPushType(ST_STRING, ClassName, Inst.PC, True)
          Else If IsWrapperType(ClassName) Then
            BCPushType(ST_WRAPPER, ClassName, Inst.PC, True)
          Else If IsCollectionType(ClassName) Then
            BCPushType(ST_COLLECTION, ClassName, Inst.PC, True)
          Else
            BCPushType(ST_REF, ClassName, Inst.PC, True);
        End;
      End;
      
      { Instructions de chargement de constante String }
      OP_LDC, OP_LDC_W: Begin
        CpIdx := Inst.Op1;
        If (CpIdx > 0) and (CpIdx < CPCount) Then Begin
          { Verifier si c'est une constante String }
          If CP^[CpIdx].Tag = CP_STRING Then
            BCPushType(ST_STRING, 'java/lang/String', Inst.PC, False)
          Else
            BCPushType(ST_UNKNOWN, '', Inst.PC, False);
        End;
      End;
      
      { Instructions de chargement de variables locales (references) }
      OP_ALOAD, OP_ALOAD_0, OP_ALOAD_1, OP_ALOAD_2, OP_ALOAD_3: Begin
        { Sans analyse de flux de donnees, on ne connait pas le type }
        BCPushType(ST_REF, '', Inst.PC, False);
      End;
      
      { Instructions d'appel de methode }
      OP_INVOKEVIRTUAL, OP_INVOKEINTERFACE, OP_INVOKESPECIAL, OP_INVOKESTATIC: Begin
        CpIdx := Inst.Op1;
        If (CpIdx > 0) and (CpIdx < CPCount) Then Begin
          ClassName := '';
          MethodName := '';
          Descriptor := '';
          CPGetMemberRef(CpIdx, ClassName, MethodName, Descriptor);
          
          { Analyser le type de retour du descripteur }
          Pos1 := Pos(')', Descriptor);
          If Pos1 > 0 Then Begin
            ReturnType := Copy(Descriptor, Pos1 + 1, Length(Descriptor) - Pos1);
            If ReturnType <> 'V' Then Begin
              { La methode retourne quelque chose }
              If IsStringType(ReturnType) Then
                BCPushType(ST_STRING, 'java/lang/String', Inst.PC, False)
              Else If IsWrapperType(ReturnType) Then
                BCPushType(ST_WRAPPER, ReturnType, Inst.PC, False)
              Else If IsCollectionType(ReturnType) Then
                BCPushType(ST_COLLECTION, ReturnType, Inst.PC, False)
              Else If (ReturnType[1] = '[') Then
                BCPushType(ST_ARRAY, ReturnType, Inst.PC, False)
              Else If (ReturnType[1] = 'L') Then
                BCPushType(ST_REF, ReturnType, Inst.PC, False);
            End;
          End;
          
          { Detecter les appels get/contains avec mauvais type }
          If IsCollectionType(ClassName) and IsCollectionGetMethod(MethodName) Then Begin
            { Verifier si l'argument est du bon type }
            { Pour une analyse precise, il faudrait traquer les generiques }
            { Ici, on fait une heuristique simple }
            Inc(BCTotalCompares);
          End;
        End;
      End;
      
      { Instructions getfield et getstatic }
      OP_GETFIELD, OP_GETSTATIC: Begin
        CpIdx := Inst.Op1;
        If (CpIdx > 0) and (CpIdx < CPCount) Then Begin
          ClassName := '';
          MethodName := '';  { En fait c'est le nom du champ }
          Descriptor := '';
          CPGetMemberRef(CpIdx, ClassName, MethodName, Descriptor);
          
          If IsStringType(Descriptor) Then
            BCPushType(ST_STRING, Descriptor, Inst.PC, False)
          Else If IsWrapperType(Descriptor) Then
            BCPushType(ST_WRAPPER, Descriptor, Inst.PC, False)
          Else If IsCollectionType(Descriptor) Then
            BCPushType(ST_COLLECTION, Descriptor, Inst.PC, False)
          Else If (Length(Descriptor) > 0) and (Descriptor[1] = '[') Then
            BCPushType(ST_ARRAY, Descriptor, Inst.PC, False)
          Else If (Length(Descriptor) > 0) and (Descriptor[1] = 'L') Then
            BCPushType(ST_REF, Descriptor, Inst.PC, False);
        End;
      End;
      
      { Instructions de chargement de tableau (aaload pousse une reference) }
      OP_AALOAD: Begin
        { Pop index, pop arrayref, push element }
        BCPopType;  { index }
        BCPopType;  { arrayref }
        BCPushType(ST_REF, '', Inst.PC, False);  { element }
      End;
      
      { Instructions de comparaison de references if_acmpeq / if_acmpne }
      OP_IF_ACMPEQ, OP_IF_ACMPNE: Begin
        Inc(BCTotalCompares);
        
        { Depiler les deux types compares }
        Type2Info := BCPopType;
        Type1Info := BCPopType;
        
        { Verifier si on compare des Strings avec == }
        If (Type1Info.StackType = ST_STRING) or (Type2Info.StackType = ST_STRING) Then Begin
          { Comparaison de String avec == }
          AddBadCompBug(ES_COMPARING_STRINGS_WITH_EQ, Inst.PC, LineNum,
                        ClassInfo.ThisClass, Methods[MethIdx].Name,
                        Type1Info.TypeName, Type2Info.TypeName);
          Inc(BCTotalBadString);
        End
        
        { Verifier si on compare des wrappers avec == }
        Else If (Type1Info.StackType = ST_WRAPPER) or (Type2Info.StackType = ST_WRAPPER) Then Begin
          { Comparaison de wrapper avec == }
          { Si les deux sont des wrappers du meme type mais pas new, c'est un bug }
          AddBadCompBug(RC_REF_COMPARISON_BAD_PRACTICE, Inst.PC, LineNum,
                        ClassInfo.ThisClass, Methods[MethIdx].Name,
                        Type1Info.TypeName, Type2Info.TypeName);
          Inc(BCTotalBadWrapper);
        End
        
        { Verifier si on compare array avec non-array }
        Else If ((Type1Info.StackType = ST_ARRAY) and (Type2Info.StackType <> ST_ARRAY) and
                 (Type2Info.StackType <> ST_NULL) and (Type2Info.StackType <> ST_UNKNOWN)) or
                ((Type2Info.StackType = ST_ARRAY) and (Type1Info.StackType <> ST_ARRAY) and
                 (Type1Info.StackType <> ST_NULL) and (Type1Info.StackType <> ST_UNKNOWN)) Then Begin
          AddBadCompBug(EC_ARRAY_AND_NONARRAY, Inst.PC, LineNum,
                        ClassInfo.ThisClass, Methods[MethIdx].Name,
                        Type1Info.TypeName, Type2Info.TypeName);
          Inc(BCTotalUnrelated);
        End
        
        { Verifier si on compare deux arrays avec == }
        Else If (Type1Info.StackType = ST_ARRAY) and (Type2Info.StackType = ST_ARRAY) Then Begin
          AddBadCompBug(EC_BAD_ARRAY_COMPARE, Inst.PC, LineNum,
                        ClassInfo.ThisClass, Methods[MethIdx].Name,
                        Type1Info.TypeName, Type2Info.TypeName);
          Inc(BCTotalUnrelated);
        End
        
        { Verifier si les types sont non-relies }
        Else If (Type1Info.StackType = ST_REF) and (Type2Info.StackType = ST_REF) Then Begin
          If not AreTypesRelated(Type1Info.TypeName, Type2Info.TypeName) Then Begin
            AddBadCompBug(EC_UNRELATED_TYPES, Inst.PC, LineNum,
                          ClassInfo.ThisClass, Methods[MethIdx].Name,
                          Type1Info.TypeName, Type2Info.TypeName);
            Inc(BCTotalUnrelated);
          End;
        End;
      End;
      
      { Pop simple - depile un element }
      OP_POP: Begin
        BCPopType;
      End;
      
      { Pop2 - depile deux elements (ou un long/double) }
      OP_POP2: Begin
        BCPopType;
        BCPopType;
      End;
      
      { Dup - duplique le sommet }
      OP_DUP: Begin
        If BCStackTypeTop > 0 Then Begin
          Type1Info := BCStackTypes[BCStackTypeTop - 1];
          BCPushType(Type1Info.StackType, Type1Info.TypeName, Type1Info.SourcePC, Type1Info.IsNew);
        End;
      End;
      
      { Swap - echange les deux sommets }
      OP_SWAP: Begin
        If BCStackTypeTop >= 2 Then Begin
          Type1Info := BCStackTypes[BCStackTypeTop - 1];
          Type2Info := BCStackTypes[BCStackTypeTop - 2];
          BCStackTypes[BCStackTypeTop - 1] := Type2Info;
          BCStackTypes[BCStackTypeTop - 2] := Type1Info;
        End;
      End;
      
      { Instructions de stockage (astore) - depilent }
      OP_ASTORE, OP_ASTORE_0, OP_ASTORE_1, OP_ASTORE_2, OP_ASTORE_3: Begin
        BCPopType;
      End;
      
      { Instructions de stockage tableau (aastore) }
      OP_AASTORE: Begin
        BCPopType;  { value }
        BCPopType;  { index }
        BCPopType;  { arrayref }
      End;
      
      { Instructions de saut conditionnel - peuvent bifurquer }
      OP_IFEQ, OP_IFNE, OP_IFLT, OP_IFGE, OP_IFGT, OP_IFLE,
      OP_IF_ICMPEQ, OP_IF_ICMPNE, OP_IF_ICMPLT, OP_IF_ICMPGE,
      OP_IF_ICMPGT, OP_IF_ICMPLE: Begin
        { Ces instructions comparent des entiers, pas des references }
        { On ne detecte pas de bugs ici, mais on nettoie la pile }
        If (Inst.Opcode >= OP_IF_ICMPEQ) and (Inst.Opcode <= OP_IF_ICMPLE) Then Begin
          BCPopType;
          BCPopType;
        End Else Begin
          BCPopType;
        End;
      End;
      
      { Instructions ifnull/ifnonnull }
      OP_IFNULL, OP_IFNONNULL: Begin
        BCPopType;
      End;
      
      { Return - on peut vider la pile }
      OP_RETURN, OP_ARETURN, OP_IRETURN, OP_LRETURN, OP_FRETURN, OP_DRETURN: Begin
        BCClearStack;
      End;
      
      { Athrow - on peut vider la pile }
      OP_ATHROW: Begin
        BCClearStack;
      End;
    End;
  End;
End;

{ --- TODO 13 : Analyser une methode pour les comparaisons incorrectes --- }
Procedure AnalyzeMethodForBadComparisons(MethIdx: Integer);
Begin
  If not BCInitialized Then
    InitBadCompState;
    
  If (MethIdx < 0) or (MethIdx >= MethodCount) Then Exit;
  
  { Decoder les instructions si pas deja fait }
  If (Instructions = Nil) or (InstrCount = 0) Then Begin
    If Methods[MethIdx].CodeLen > 0 Then Begin
      AllocInstructions;
      DecodeInstructions(Methods[MethIdx]);
    End;
  End;
  
  { Detecter les comparaisons incorrectes }
  DetectBadComparisons(MethIdx);
End;

{ --- TODO 13 : Dump de l'etat du module comparaisons incorrectes --- }
Procedure DumpBadCompState;
Var
  I: Integer;
Begin
  WriteLn('=== Bad Comparisons State ===');
  WriteLn('Initialized: ', BCInitialized);
  WriteLn('Bug Count: ', BCBugCount);
  WriteLn('Stack Type Top: ', BCStackTypeTop);
  WriteLn('Label Num: ', BCLabelNum);
  WriteLn('Total Compares: ', BCTotalCompares);
  WriteLn('Total Bad String: ', BCTotalBadString);
  WriteLn('Total Bad Wrapper: ', BCTotalBadWrapper);
  WriteLn('Total Unrelated: ', BCTotalUnrelated);
  WriteLn('Total Bad Collection: ', BCTotalBadCollection);
  
  If BCBugCount > 0 Then Begin
    WriteLn('--- Bugs ---');
    For I := 0 to BCBugCount - 1 Do Begin
      WriteLn('  [', I, '] Type=', BCBugTypeName(BCBugs[I].BugType),
              ' PC=', BCBugs[I].PC, ' Line=', BCBugs[I].LineNum,
              ' Class=', BCBugs[I].ClassName,
              ' Method=', BCBugs[I].MethodName,
              ' Type1=', BCBugs[I].Type1,
              ' Type2=', BCBugs[I].Type2);
    End;
  End;
End;

{ --- TODO 13 : Accesseurs du module comparaisons incorrectes --- }
Function IsBCInitialized: Boolean;
Begin
  IsBCInitialized := BCInitialized;
End;

Function GetBCBugCount: Integer;
Begin
  GetBCBugCount := BCBugCount;
End;

Function GetBCStackTypeTop: Integer;
Begin
  GetBCStackTypeTop := BCStackTypeTop;
End;

Function GetBCTotalCompares: Integer;
Begin
  GetBCTotalCompares := BCTotalCompares;
End;

Function GetBCTotalBadString: Integer;
Begin
  GetBCTotalBadString := BCTotalBadString;
End;

Function GetBCTotalBadWrapper: Integer;
Begin
  GetBCTotalBadWrapper := BCTotalBadWrapper;
End;

Function GetBCTotalUnrelated: Integer;
Begin
  GetBCTotalUnrelated := BCTotalUnrelated;
End;

Function GetBCTotalBadCollection: Integer;
Begin
  GetBCTotalBadCollection := BCTotalBadCollection;
End;

Function GetBCLabelNum: Integer;
Begin
  GetBCLabelNum := BCLabelNum;
End;

Function GetBCBugType(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < BCBugCount) Then
    GetBCBugType := BCBugs[Idx].BugType
  Else
    GetBCBugType := BC_NONE;
End;

Function GetBCBugPC(Idx: Integer): LongWord;
Begin
  If (Idx >= 0) and (Idx < BCBugCount) Then
    GetBCBugPC := BCBugs[Idx].PC
  Else
    GetBCBugPC := 0;
End;

Function GetBCBugLine(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < BCBugCount) Then
    GetBCBugLine := BCBugs[Idx].LineNum
  Else
    GetBCBugLine := 0;
End;

{ ============================================================================ }
{ TODO 14 [IMPLEMENTE] - Detecteur : problemes de performance                  }
{ ============================================================================ }

{ --- TODO 14 : Initialisation du module performance --- }
Procedure InitPerfState;
Var
  I: Integer;
Begin
  PFInitialized := True;
  PFBugCount := 0;
  PFMemberCount := 0;
  PFConcatLoopCount := 0;
  PFLabelNum := 0;
  PFTotalConcatLoop := 0;
  PFTotalURLBlocking := 0;
  PFTotalBadToArray := 0;
  PFTotalUnreadFields := 0;
  PFTotalUnwrittenFields := 0;
  PFTotalWrongMapIter := 0;
  PFTotalUncalledMethods := 0;
  PFCurrentPC := 0;
  PFCurrentLine := 0;
  
  For I := 0 to MAX_PF_BUGS - 1 Do Begin
    PFBugs[I].BugType := PF_NONE;
    PFBugs[I].PC := 0;
    PFBugs[I].LineNum := 0;
    PFBugs[I].ClassName := '';
    PFBugs[I].MethodName := '';
    PFBugs[I].MemberName := '';
    PFBugs[I].Details := '';
  End;
  
  For I := 0 to MAX_PF_MEMBERS - 1 Do Begin
    PFPrivateMembers[I].MemberType := 0;
    PFPrivateMembers[I].Name := '';
    PFPrivateMembers[I].Descriptor := '';
    PFPrivateMembers[I].DeclLine := 0;
    PFPrivateMembers[I].IsRead := False;
    PFPrivateMembers[I].IsWritten := False;
    PFPrivateMembers[I].IsCalled := False;
    PFPrivateMembers[I].FieldIdx := -1;
    PFPrivateMembers[I].MethodIdx := -1;
  End;
  
  For I := 0 to MAX_PF_CONCAT_LOOP - 1 Do Begin
    PFConcatLoops[I].PC := 0;
    PFConcatLoops[I].LineNum := 0;
    PFConcatLoops[I].LoopStart := 0;
    PFConcatLoops[I].LoopEnd := 0;
  End;
End;

{ --- TODO 14 : Generation d'un label unique pour le module --- }
Function GenPFLabel: String;
Begin
  Inc(PFLabelNum);
  GenPFLabel := '_PF_' + IntToStr_(PFLabelNum);
End;

{ --- TODO 14 : Conversion du type de bug en chaine --- }
Function PFBugTypeName(BugType: Integer): String;
Begin
  Case BugType of
    PF_NONE:                           PFBugTypeName := 'PF_NONE';
    SBSC_USE_STRINGBUFFER_CONCATENATION: PFBugTypeName := 'SBSC_USE_STRINGBUFFER_CONCATENATION';
    DMI_BLOCKING_METHODS_ON_URL:       PFBugTypeName := 'DMI_BLOCKING_METHODS_ON_URL';
    ITA_INEFFICIENT_TO_ARRAY:          PFBugTypeName := 'ITA_INEFFICIENT_TO_ARRAY';
    URF_UNREAD_FIELD:                  PFBugTypeName := 'URF_UNREAD_FIELD';
    WMI_WRONG_MAP_ITERATOR:            PFBugTypeName := 'WMI_WRONG_MAP_ITERATOR';
    UPM_UNCALLED_PRIVATE_METHOD:       PFBugTypeName := 'UPM_UNCALLED_PRIVATE_METHOD';
    UWF_UNWRITTEN_FIELD:               PFBugTypeName := 'UWF_UNWRITTEN_FIELD';
  Else
    PFBugTypeName := 'UNKNOWN';
  End;
End;

{ --- TODO 14 : Detecter si un type est StringBuilder ou StringBuffer --- }
Function IsStringBuilderType(ClassName: String): Boolean;
Begin
  IsStringBuilderType := (ClassName = 'java/lang/StringBuilder') or
                         (ClassName = 'java/lang/StringBuffer') or
                         (Pos('StringBuilder', ClassName) > 0) or
                         (Pos('StringBuffer', ClassName) > 0);
End;

{ --- TODO 14 : Detecter si un type est java.net.URL --- }
Function IsURLType(ClassName: String): Boolean;
Begin
  IsURLType := (ClassName = 'java/net/URL') or
               (ClassName = 'Ljava/net/URL;') or
               (Pos('java/net/URL', ClassName) > 0);
End;

{ --- TODO 14 : Detecter si un type est Map --- }
Function IsMapType(ClassName: String): Boolean;
Begin
  IsMapType := (ClassName = 'java/util/Map') or
               (ClassName = 'java/util/HashMap') or
               (ClassName = 'java/util/TreeMap') or
               (ClassName = 'java/util/LinkedHashMap') or
               (ClassName = 'java/util/Hashtable') or
               (ClassName = 'java/util/ConcurrentHashMap') or
               (ClassName = 'java/util/WeakHashMap') or
               (ClassName = 'java/util/IdentityHashMap') or
               (Pos('Map', ClassName) > 0);
End;

{ --- TODO 14 : Detecter si une methode est une methode bloquante de URL --- }
Function IsURLBlockingMethod(MethodName: String): Boolean;
Begin
  IsURLBlockingMethod := (MethodName = 'equals') or
                         (MethodName = 'hashCode') or
                         (MethodName = 'getHost') or
                         (MethodName = 'openConnection') or
                         (MethodName = 'openStream');
End;

{ --- TODO 14 : Detecter si une methode est keySet sur Map --- }
Function IsMapKeySetMethod(MethodName: String): Boolean;
Begin
  IsMapKeySetMethod := (MethodName = 'keySet');
End;

{ --- TODO 14 : Ajouter un bug de performance --- }
Procedure AddPerfBug(BugType: Integer; PC: LongWord; LineNum: Integer;
                     ClassName, MethodName, MemberName, Details: String);
Begin
  If PFBugCount >= MAX_PF_BUGS Then Exit;
  
  PFBugs[PFBugCount].BugType := BugType;
  PFBugs[PFBugCount].PC := PC;
  PFBugs[PFBugCount].LineNum := LineNum;
  PFBugs[PFBugCount].ClassName := ClassName;
  PFBugs[PFBugCount].MethodName := MethodName;
  PFBugs[PFBugCount].MemberName := MemberName;
  PFBugs[PFBugCount].Details := Details;
  Inc(PFBugCount);
  
  Case BugType of
    SBSC_USE_STRINGBUFFER_CONCATENATION: Inc(PFTotalConcatLoop);
    DMI_BLOCKING_METHODS_ON_URL:         Inc(PFTotalURLBlocking);
    ITA_INEFFICIENT_TO_ARRAY:            Inc(PFTotalBadToArray);
    URF_UNREAD_FIELD:                    Inc(PFTotalUnreadFields);
    WMI_WRONG_MAP_ITERATOR:              Inc(PFTotalWrongMapIter);
    UPM_UNCALLED_PRIVATE_METHOD:         Inc(PFTotalUncalledMethods);
    UWF_UNWRITTEN_FIELD:                 Inc(PFTotalUnwrittenFields);
  End;
End;

{ --- TODO 14 : Collecter les membres prives de la classe --- }
Procedure CollectPrivateMembers;
Var
  I: Integer;
  AccessFlags: Word;
Begin
  PFMemberCount := 0;
  
  { Collecter les champs prives }
  For I := 0 to FieldCount - 1 Do Begin
    If PFMemberCount >= MAX_PF_MEMBERS Then Break;
    AccessFlags := Fields[I].AccessFlags;
    If (AccessFlags and $0002) <> 0 Then Begin { ACC_PRIVATE }
      PFPrivateMembers[PFMemberCount].MemberType := 0; { champ }
      PFPrivateMembers[PFMemberCount].Name := Fields[I].Name;
      PFPrivateMembers[PFMemberCount].Descriptor := Fields[I].Descriptor;
      PFPrivateMembers[PFMemberCount].DeclLine := 0;
      PFPrivateMembers[PFMemberCount].IsRead := False;
      PFPrivateMembers[PFMemberCount].IsWritten := False;
      PFPrivateMembers[PFMemberCount].IsCalled := False;
      PFPrivateMembers[PFMemberCount].FieldIdx := I;
      PFPrivateMembers[PFMemberCount].MethodIdx := -1;
      Inc(PFMemberCount);
    End;
  End;
  
  { Collecter les methodes privees }
  For I := 0 to MethodCount - 1 Do Begin
    If PFMemberCount >= MAX_PF_MEMBERS Then Break;
    AccessFlags := Methods[I].AccessFlags;
    If (AccessFlags and $0002) <> 0 Then Begin { ACC_PRIVATE }
      { Exclure <init> et <clinit> }
      If (Methods[I].Name <> '<init>') and (Methods[I].Name <> '<clinit>') Then Begin
        PFPrivateMembers[PFMemberCount].MemberType := 1; { methode }
        PFPrivateMembers[PFMemberCount].Name := Methods[I].Name;
        PFPrivateMembers[PFMemberCount].Descriptor := Methods[I].Descriptor;
        PFPrivateMembers[PFMemberCount].DeclLine := 0;
        PFPrivateMembers[PFMemberCount].IsRead := False;
        PFPrivateMembers[PFMemberCount].IsWritten := False;
        PFPrivateMembers[PFMemberCount].IsCalled := False;
        PFPrivateMembers[PFMemberCount].FieldIdx := -1;
        PFPrivateMembers[PFMemberCount].MethodIdx := I;
        Inc(PFMemberCount);
      End;
    End;
  End;
End;

{ --- TODO 14 : Marquer un membre prive comme utilise --- }
Procedure MarkMemberUsed(Name, Descriptor: String; IsRead, IsWrite, IsCall: Boolean);
Var
  I: Integer;
Begin
  For I := 0 to PFMemberCount - 1 Do Begin
    If (PFPrivateMembers[I].Name = Name) and 
       (PFPrivateMembers[I].Descriptor = Descriptor) Then Begin
      If IsRead Then PFPrivateMembers[I].IsRead := True;
      If IsWrite Then PFPrivateMembers[I].IsWritten := True;
      If IsCall Then PFPrivateMembers[I].IsCalled := True;
      Exit;
    End;
  End;
End;

{ --- TODO 14 : Verifier si un PC est dans une boucle (back-edge) --- }
Function IsInLoop(PC: LongWord): Boolean;
Var
  I: Integer;
Begin
  IsInLoop := False;
  If CFGNodes = nil Then Exit;
  
  For I := 0 to CFGNodeCount - 1 Do Begin
    If CFGNodes^[I].IsBackEdge Then Begin
      If (PC >= CFGNodes^[I].StartPC) and (PC <= CFGNodes^[I].EndPC) Then Begin
        IsInLoop := True;
        Exit;
      End;
    End;
  End;
End;

{ --- TODO 14 : Detecter les concatenations de String dans une boucle --- }
Procedure DetectStringConcatInLoop(MethIdx: Integer);
Var
  I: Integer;
  Op: Word;
  CPIdx: Word;
  ClassName, MethodName, Descriptor: String;
  PC: LongWord;
  LineNum: Integer;
Begin
  If Instructions = nil Then Exit;
  If InstrCount = 0 Then Exit;
  
  For I := 0 to InstrCount - 1 Do Begin
    Op := Instructions^[I].Opcode;
    PC := Instructions^[I].PC;
    LineNum := GetLineNumber(Methods[MethIdx], Word(PC));
    
    { Chercher invokevirtual String.concat ou StringBuilder.append }
    If (Op = OP_INVOKEVIRTUAL) or (Op = OP_INVOKEINTERFACE) Then Begin
      CPIdx := Instructions^[I].Op1;
      If (CPIdx > 0) and (CPIdx < CPCount) Then Begin
        ClassName := '';
        MethodName := '';
        Descriptor := '';
        CPGetMemberRef(CPIdx, ClassName, MethodName, Descriptor);
        
        { String.concat dans une boucle }
        If (ClassName = 'java/lang/String') and (MethodName = 'concat') Then Begin
          If IsInLoop(PC) Then Begin
            AddPerfBug(SBSC_USE_STRINGBUFFER_CONCATENATION, PC, LineNum,
                      ClassInfo.ThisClass, Methods[MethIdx].Name,
                      'String.concat', 'String concatenation in loop');
          End;
        End;
        
        { + operateur sur String (via StringBuilder) sans reutilisation }
        If IsStringBuilderType(ClassName) and (MethodName = 'append') Then Begin
          If IsInLoop(PC) Then Begin
            { Verifier si on cree un nouveau StringBuilder a chaque iteration }
            { Heuristique : si new StringBuilder est proche, c'est probablement dans la boucle }
            If (I > 0) and (I < InstrCount) Then Begin
              If (Instructions^[I-1].Opcode = OP_NEW) or
                 ((I > 1) and (Instructions^[I-2].Opcode = OP_NEW)) Then Begin
                AddPerfBug(SBSC_USE_STRINGBUFFER_CONCATENATION, PC, LineNum,
                          ClassInfo.ThisClass, Methods[MethIdx].Name,
                          'StringBuilder.append', 'StringBuilder created in loop');
              End;
            End;
          End;
        End;
      End;
    End;
  End;
End;

{ --- TODO 14 : Detecter les appels bloquants sur URL --- }
Procedure DetectURLBlockingCalls(MethIdx: Integer);
Var
  I: Integer;
  Op: Word;
  CPIdx: Word;
  ClassName, MethodName, Descriptor: String;
  PC: LongWord;
  LineNum: Integer;
Begin
  If Instructions = nil Then Exit;
  If InstrCount = 0 Then Exit;
  
  For I := 0 to InstrCount - 1 Do Begin
    Op := Instructions^[I].Opcode;
    PC := Instructions^[I].PC;
    LineNum := GetLineNumber(Methods[MethIdx], Word(PC));
    
    If (Op = OP_INVOKEVIRTUAL) or (Op = OP_INVOKEINTERFACE) Then Begin
      CPIdx := Instructions^[I].Op1;
      If (CPIdx > 0) and (CPIdx < CPCount) Then Begin
        ClassName := '';
        MethodName := '';
        Descriptor := '';
        CPGetMemberRef(CPIdx, ClassName, MethodName, Descriptor);
        
        If IsURLType(ClassName) and IsURLBlockingMethod(MethodName) Then Begin
          AddPerfBug(DMI_BLOCKING_METHODS_ON_URL, PC, LineNum,
                    ClassInfo.ThisClass, Methods[MethIdx].Name,
                    MethodName, 'URL.' + MethodName + ' may perform DNS lookup');
        End;
      End;
    End;
  End;
End;

{ --- TODO 14 : Detecter toArray inefficace --- }
Procedure DetectInefficientToArray(MethIdx: Integer);
Var
  I: Integer;
  Op: Word;
  CPIdx: Word;
  ClassName, MethodName, Descriptor: String;
  PC: LongWord;
  LineNum: Integer;
  PrevOp: Word;
Begin
  If Instructions = nil Then Exit;
  If InstrCount = 0 Then Exit;
  
  For I := 0 to InstrCount - 1 Do Begin
    Op := Instructions^[I].Opcode;
    PC := Instructions^[I].PC;
    LineNum := GetLineNumber(Methods[MethIdx], Word(PC));
    
    If (Op = OP_INVOKEINTERFACE) or (Op = OP_INVOKEVIRTUAL) Then Begin
      CPIdx := Instructions^[I].Op1;
      If (CPIdx > 0) and (CPIdx < CPCount) Then Begin
        ClassName := '';
        MethodName := '';
        Descriptor := '';
        CPGetMemberRef(CPIdx, ClassName, MethodName, Descriptor);
        
        { Collection.toArray(T[]) }
        If (MethodName = 'toArray') and (Pos('Collection', ClassName) > 0) Then Begin
          { Verifier si l'argument est new T[0] }
          If I >= 2 Then Begin
            PrevOp := Instructions^[I-1].Opcode;
            If PrevOp = OP_ANEWARRAY Then Begin
              { Verifier si la taille est 0 (iconst_0 avant anewarray) }
              If Instructions^[I-2].Opcode = OP_ICONST_0 Then Begin
                AddPerfBug(ITA_INEFFICIENT_TO_ARRAY, PC, LineNum,
                          ClassInfo.ThisClass, Methods[MethIdx].Name,
                          'toArray', 'Use toArray(new T[collection.size()]) instead');
              End;
            End;
          End;
        End;
      End;
    End;
  End;
End;

{ --- TODO 14 : Detecter l'utilisation de keySet() au lieu de entrySet() --- }
Procedure DetectWrongMapIterator(MethIdx: Integer);
Var
  I, J: Integer;
  Op: Word;
  CPIdx: Word;
  ClassName, MethodName, Descriptor: String;
  PC: LongWord;
  LineNum: Integer;
  HasKeySet: Boolean;
  HasGet: Boolean;
  KeySetPC: LongWord;
  KeySetLine: Integer;
Begin
  If Instructions = nil Then Exit;
  If InstrCount = 0 Then Exit;
  
  HasKeySet := False;
  HasGet := False;
  KeySetPC := 0;
  KeySetLine := 0;
  
  { Premiere passe : chercher keySet() }
  For I := 0 to InstrCount - 1 Do Begin
    Op := Instructions^[I].Opcode;
    
    If (Op = OP_INVOKEINTERFACE) or (Op = OP_INVOKEVIRTUAL) Then Begin
      CPIdx := Instructions^[I].Op1;
      If (CPIdx > 0) and (CPIdx < CPCount) Then Begin
        ClassName := '';
        MethodName := '';
        Descriptor := '';
        CPGetMemberRef(CPIdx, ClassName, MethodName, Descriptor);
        
        If IsMapType(ClassName) and IsMapKeySetMethod(MethodName) Then Begin
          HasKeySet := True;
          KeySetPC := Instructions^[I].PC;
          KeySetLine := GetLineNumber(Methods[MethIdx], Word(KeySetPC));
          
          { Chercher un get() apres keySet() dans la meme methode }
          For J := I + 1 to InstrCount - 1 Do Begin
            If (Instructions^[J].Opcode = OP_INVOKEINTERFACE) or
               (Instructions^[J].Opcode = OP_INVOKEVIRTUAL) Then Begin
              CPIdx := Instructions^[J].Op1;
              If (CPIdx > 0) and (CPIdx < CPCount) Then Begin
                ClassName := '';
                MethodName := '';
                Descriptor := '';
                CPGetMemberRef(CPIdx, ClassName, MethodName, Descriptor);
                If IsMapType(ClassName) and (MethodName = 'get') Then Begin
                  HasGet := True;
                  Break;
                End;
              End;
            End;
          End;
          
          If HasGet Then Begin
            AddPerfBug(WMI_WRONG_MAP_ITERATOR, KeySetPC, KeySetLine,
                      ClassInfo.ThisClass, Methods[MethIdx].Name,
                      'keySet', 'Use entrySet() instead of keySet() + get()');
          End;
          
          Break; { Une seule detection par methode }
        End;
      End;
    End;
  End;
End;

{ --- TODO 14 : Scanner les references aux membres prives dans une methode --- }
Procedure ScanMemberReferences(MethIdx: Integer);
Var
  I: Integer;
  Op: Word;
  CPIdx: Word;
  ClassName, MemberName, MemberDesc: String;
Begin
  If Instructions = nil Then Exit;
  If InstrCount = 0 Then Exit;
  
  For I := 0 to InstrCount - 1 Do Begin
    Op := Instructions^[I].Opcode;
    CPIdx := Instructions^[I].Op1;
    
    If (CPIdx = 0) or (CPIdx >= CPCount) Then Continue;
    
    Case Op of
      OP_GETFIELD, OP_GETSTATIC: Begin
        ClassName := '';
        MemberName := '';
        MemberDesc := '';
        CPGetMemberRef(CPIdx, ClassName, MemberName, MemberDesc);
        MarkMemberUsed(MemberName, MemberDesc, True, False, False);
      End;
      OP_PUTFIELD, OP_PUTSTATIC: Begin
        ClassName := '';
        MemberName := '';
        MemberDesc := '';
        CPGetMemberRef(CPIdx, ClassName, MemberName, MemberDesc);
        MarkMemberUsed(MemberName, MemberDesc, False, True, False);
      End;
      OP_INVOKEVIRTUAL, OP_INVOKESPECIAL, OP_INVOKESTATIC, OP_INVOKEINTERFACE: Begin
        ClassName := '';
        MemberName := '';
        MemberDesc := '';
        CPGetMemberRef(CPIdx, ClassName, MemberName, MemberDesc);
        MarkMemberUsed(MemberName, MemberDesc, False, False, True);
      End;
    End;
  End;
End;

{ --- TODO 14 : Detecter les membres prives non utilises --- }
Procedure DetectUnusedPrivateMembers;
Var
  I, J: Integer;
Begin
  { Collecter tous les membres prives }
  CollectPrivateMembers;
  
  { Scanner toutes les methodes pour les references }
  For I := 0 to MethodCount - 1 Do Begin
    If Methods[I].Code <> nil Then Begin
      DecodeInstructions(Methods[I]);
      ScanMemberReferences(I);
    End;
  End;
  
  { Signaler les membres non utilises }
  For I := 0 to PFMemberCount - 1 Do Begin
    If PFPrivateMembers[I].MemberType = 0 Then Begin
      { Champ prive }
      If (not PFPrivateMembers[I].IsRead) and (not PFPrivateMembers[I].IsWritten) Then Begin
        { Champ jamais utilise - signaler les deux }
        AddPerfBug(URF_UNREAD_FIELD, 0, PFPrivateMembers[I].DeclLine,
                  ClassInfo.ThisClass, '',
                  PFPrivateMembers[I].Name, 'Private field never read');
        AddPerfBug(UWF_UNWRITTEN_FIELD, 0, PFPrivateMembers[I].DeclLine,
                  ClassInfo.ThisClass, '',
                  PFPrivateMembers[I].Name, 'Private field never written');
      End
      Else If not PFPrivateMembers[I].IsRead Then Begin
        AddPerfBug(URF_UNREAD_FIELD, 0, PFPrivateMembers[I].DeclLine,
                  ClassInfo.ThisClass, '',
                  PFPrivateMembers[I].Name, 'Private field never read');
      End
      Else If not PFPrivateMembers[I].IsWritten Then Begin
        AddPerfBug(UWF_UNWRITTEN_FIELD, 0, PFPrivateMembers[I].DeclLine,
                  ClassInfo.ThisClass, '',
                  PFPrivateMembers[I].Name, 'Private field never written');
      End;
    End
    Else Begin
      { Methode privee }
      If not PFPrivateMembers[I].IsCalled Then Begin
        AddPerfBug(UPM_UNCALLED_PRIVATE_METHOD, 0, PFPrivateMembers[I].DeclLine,
                  ClassInfo.ThisClass, PFPrivateMembers[I].Name,
                  PFPrivateMembers[I].Name, 'Private method never called');
      End;
    End;
  End;
End;

{ --- TODO 14 : Detecter tous les problemes de performance dans une methode --- }
Procedure DetectPerformanceIssues(MethIdx: Integer);
Begin
  If not PFInitialized Then InitPerfState;
  If MethIdx < 0 Then Exit;
  If MethIdx >= MethodCount Then Exit;
  If Methods[MethIdx].Code = nil Then Exit;
  
  { Decoder les instructions }
  DecodeInstructions(Methods[MethIdx]);
  
  { Detecter les concatenations de String dans les boucles }
  DetectStringConcatInLoop(MethIdx);
  
  { Detecter les appels bloquants sur URL }
  DetectURLBlockingCalls(MethIdx);
  
  { Detecter toArray inefficace }
  DetectInefficientToArray(MethIdx);
  
  { Detecter l'utilisation de keySet() au lieu de entrySet() }
  DetectWrongMapIterator(MethIdx);
End;

{ --- TODO 14 : Analyser une methode pour les problemes de performance --- }
Procedure AnalyzeMethodForPerformance(MethIdx: Integer);
Begin
  If not PFInitialized Then InitPerfState;
  DetectPerformanceIssues(MethIdx);
End;

{ --- TODO 14 : Analyser toute la classe pour les problemes de performance --- }
Procedure AnalyzeClassForPerformance;
Var
  I: Integer;
Begin
  If not PFInitialized Then InitPerfState;
  
  { Analyser chaque methode }
  For I := 0 to MethodCount - 1 Do Begin
    AnalyzeMethodForPerformance(I);
  End;
  
  { Detecter les membres prives non utilises (analyse au niveau classe) }
  DetectUnusedPrivateMembers;
End;

{ --- TODO 14 : Dump de l'etat du module performance --- }
Procedure DumpPerfState;
Var
  I: Integer;
Begin
  WriteLn('=== Performance State ===');
  WriteLn('Initialized: ', PFInitialized);
  WriteLn('Bug Count: ', PFBugCount);
  WriteLn('Member Count: ', PFMemberCount);
  WriteLn('Concat Loop Count: ', PFConcatLoopCount);
  WriteLn('Label Num: ', PFLabelNum);
  WriteLn('Total Concat in Loop: ', PFTotalConcatLoop);
  WriteLn('Total URL Blocking: ', PFTotalURLBlocking);
  WriteLn('Total Bad toArray: ', PFTotalBadToArray);
  WriteLn('Total Unread Fields: ', PFTotalUnreadFields);
  WriteLn('Total Unwritten Fields: ', PFTotalUnwrittenFields);
  WriteLn('Total Wrong Map Iter: ', PFTotalWrongMapIter);
  WriteLn('Total Uncalled Methods: ', PFTotalUncalledMethods);
  
  If PFBugCount > 0 Then Begin
    WriteLn('--- Performance Bugs ---');
    For I := 0 to PFBugCount - 1 Do Begin
      WriteLn('  [', I, '] Type=', PFBugTypeName(PFBugs[I].BugType),
              ' PC=', PFBugs[I].PC, ' Line=', PFBugs[I].LineNum,
              ' Class=', PFBugs[I].ClassName,
              ' Method=', PFBugs[I].MethodName,
              ' Member=', PFBugs[I].MemberName,
              ' Details=', PFBugs[I].Details);
    End;
  End;
  
  If PFMemberCount > 0 Then Begin
    WriteLn('--- Private Members ---');
    For I := 0 to PFMemberCount - 1 Do Begin
      WriteLn('  [', I, '] Type=', PFPrivateMembers[I].MemberType,
              ' Name=', PFPrivateMembers[I].Name,
              ' Read=', PFPrivateMembers[I].IsRead,
              ' Written=', PFPrivateMembers[I].IsWritten,
              ' Called=', PFPrivateMembers[I].IsCalled);
    End;
  End;
End;

{ --- TODO 14 : Accesseurs du module performance --- }
Function IsPFInitialized: Boolean;
Begin
  IsPFInitialized := PFInitialized;
End;

Function GetPFBugCount: Integer;
Begin
  GetPFBugCount := PFBugCount;
End;

Function GetPFMemberCount: Integer;
Begin
  GetPFMemberCount := PFMemberCount;
End;

Function GetPFLabelNum: Integer;
Begin
  GetPFLabelNum := PFLabelNum;
End;

Function GetPFTotalConcatLoop: Integer;
Begin
  GetPFTotalConcatLoop := PFTotalConcatLoop;
End;

Function GetPFTotalURLBlocking: Integer;
Begin
  GetPFTotalURLBlocking := PFTotalURLBlocking;
End;

Function GetPFTotalBadToArray: Integer;
Begin
  GetPFTotalBadToArray := PFTotalBadToArray;
End;

Function GetPFTotalUnreadFields: Integer;
Begin
  GetPFTotalUnreadFields := PFTotalUnreadFields;
End;

Function GetPFTotalWrongMapIter: Integer;
Begin
  GetPFTotalWrongMapIter := PFTotalWrongMapIter;
End;

Function GetPFTotalUncalledMethods: Integer;
Begin
  GetPFTotalUncalledMethods := PFTotalUncalledMethods;
End;

Function GetPFBugType(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < PFBugCount) Then
    GetPFBugType := PFBugs[Idx].BugType
  Else
    GetPFBugType := PF_NONE;
End;

Function GetPFBugPC(Idx: Integer): LongWord;
Begin
  If (Idx >= 0) and (Idx < PFBugCount) Then
    GetPFBugPC := PFBugs[Idx].PC
  Else
    GetPFBugPC := 0;
End;

Function GetPFBugLine(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < PFBugCount) Then
    GetPFBugLine := PFBugs[Idx].LineNum
  Else
    GetPFBugLine := 0;
End;

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
{ TODO 16 [IMPLEMENTE] - Detecteur : problemes de multi-threading             }
{ ============================================================================ }

{ --- TODO 16 : Initialisation du module multi-threading --- }
Procedure InitConcurrencyState;
Var
  I: Integer;
Begin
  MTInitialized := True;
  MTBugCount := 0;
  MTFieldCount := 0;
  MTSyncDepth := 0;
  MTLabelNum := 0;
  MTTotalEmptySync := 0;
  MTTotalWaitNoLoop := 0;
  MTTotalNakedNotify := 0;
  MTTotalDoubleCheck := 0;
  MTTotalInconsistentSync := 0;
  MTTotalSyncSetUnsyncGet := 0;
  MTCurrentPC := 0;
  MTCurrentLine := 0;
  MTInSyncMethod := False;
  MTInSyncBlock := False;
  
  For I := 0 to MAX_MT_BUGS - 1 Do Begin
    MTBugs[I].BugType := MT_NONE;
    MTBugs[I].PC := 0;
    MTBugs[I].LineNum := 0;
    MTBugs[I].ClassName := '';
    MTBugs[I].MethodName := '';
    MTBugs[I].FieldName := '';
    MTBugs[I].Details := '';
  End;
  
  For I := 0 to MAX_MT_FIELDS - 1 Do Begin
    MTFieldAccesses[I].FieldIdx := -1;
    MTFieldAccesses[I].FieldName := '';
    MTFieldAccesses[I].IsVolatile := False;
    MTFieldAccesses[I].ReadInSync := False;
    MTFieldAccesses[I].WriteInSync := False;
    MTFieldAccesses[I].ReadNotSync := False;
    MTFieldAccesses[I].WriteNotSync := False;
    MTFieldAccesses[I].GetterSync := False;
    MTFieldAccesses[I].SetterSync := False;
    MTFieldAccesses[I].GetterIdx := -1;
    MTFieldAccesses[I].SetterIdx := -1;
  End;
End;

{ --- TODO 16 : Generation d'un label unique pour le module --- }
Function GenMTLabel: String;
Begin
  Inc(MTLabelNum);
  GenMTLabel := '_MT_' + IntToStr_(MTLabelNum);
End;

{ --- TODO 16 : Conversion du type de bug en chaine --- }
Function MTBugTypeName(BugType: Integer): String;
Begin
  Case BugType of
    MT_NONE:                      MTBugTypeName := 'MT_NONE';
    DC_DOUBLECHECK:               MTBugTypeName := 'DC_DOUBLECHECK';
    ESYNC_EMPTY_SYNC:             MTBugTypeName := 'ESync_EMPTY_SYNC';
    IS_FIELD_NOT_GUARDED:         MTBugTypeName := 'IS_FIELD_NOT_GUARDED';
    IS2_INCONSISTENT_SYNC:        MTBugTypeName := 'IS2_INCONSISTENT_SYNC';
    JLM_JSR166_LOCK_MONITORENTER: MTBugTypeName := 'JLM_JSR166_LOCK_MONITORENTER';
    NN_NAKED_NOTIFY:              MTBugTypeName := 'NN_NAKED_NOTIFY';
    NO_NOTIFY_NOT_NOTIFYALL:      MTBugTypeName := 'NO_NOTIFY_NOT_NOTIFYALL';
    UG_SYNC_SET_UNSYNC_GET:       MTBugTypeName := 'UG_SYNC_SET_UNSYNC_GET';
    UW_UNCOND_WAIT:               MTBugTypeName := 'UW_UNCOND_WAIT';
    WA_AWAIT_NOT_IN_LOOP:         MTBugTypeName := 'WA_AWAIT_NOT_IN_LOOP';
  Else
    MTBugTypeName := 'UNKNOWN';
  End;
End;

{ --- TODO 16 : Detecter si une methode est synchronized --- }
Function IsSynchronizedMethod(MethodIdx: Integer): Boolean;
Const
  ACC_SYNCHRONIZED = $0020;
Begin
  If (MethodIdx >= 0) and (MethodIdx < MethodCount) Then
    IsSynchronizedMethod := (Methods[MethodIdx].AccessFlags and ACC_SYNCHRONIZED) <> 0
  Else
    IsSynchronizedMethod := False;
End;

{ --- TODO 16 : Detecter si un champ est volatile --- }
Function IsVolatileField(FieldIdx: Integer): Boolean;
Begin
  If (FieldIdx >= 0) and (FieldIdx < FieldCount) Then
    IsVolatileField := Fields[FieldIdx].IsVolatile
  Else
    IsVolatileField := False;
End;

{ --- TODO 16 : Detecter si un nom de methode est un getter --- }
Function IsGetterMethod(MethodName: String): Boolean;
Begin
  IsGetterMethod := (Pos('get', LoCaseStr(MethodName)) = 1) or
                    (Pos('is', LoCaseStr(MethodName)) = 1) or
                    (Pos('has', LoCaseStr(MethodName)) = 1);
End;

{ --- TODO 16 : Detecter si un nom de methode est un setter --- }
Function IsSetterMethod(MethodName: String): Boolean;
Begin
  IsSetterMethod := (Pos('set', LoCaseStr(MethodName)) = 1);
End;

{ --- TODO 16 : Detecter si c'est un appel wait() --- }
Function IsWaitMethod(MethodName, Descriptor: String): Boolean;
Begin
  IsWaitMethod := (MethodName = 'wait') and
                  ((Descriptor = '()V') or 
                   (Descriptor = '(J)V') or 
                   (Descriptor = '(JI)V'));
End;

{ --- TODO 16 : Detecter si c'est un appel notify() --- }
Function IsNotifyMethod(MethodName, Descriptor: String): Boolean;
Begin
  IsNotifyMethod := (MethodName = 'notify') and (Descriptor = '()V');
End;

{ --- TODO 16 : Detecter si c'est un appel notifyAll() --- }
Function IsNotifyAllMethod(MethodName, Descriptor: String): Boolean;
Begin
  IsNotifyAllMethod := (MethodName = 'notifyAll') and (Descriptor = '()V');
End;

{ --- TODO 16 : Detecter si c'est un appel await() sur Condition --- }
Function IsAwaitMethod(ClassName, MethodName: String): Boolean;
Begin
  IsAwaitMethod := ((Pos('Condition', ClassName) > 0) or
                    (Pos('Lock', ClassName) > 0)) and
                   ((MethodName = 'await') or
                    (MethodName = 'awaitNanos') or
                    (MethodName = 'awaitUntil') or
                    (MethodName = 'awaitUninterruptibly'));
End;

{ --- TODO 16 : Trouver ou ajouter un champ dans la table d'acces --- }
Function FindOrAddFieldAccess(FieldName: String; FieldIdx: Integer): Integer;
Var
  I: Integer;
Begin
  { Chercher un champ existant }
  For I := 0 to MTFieldCount - 1 Do Begin
    If MTFieldAccesses[I].FieldName = FieldName Then Begin
      FindOrAddFieldAccess := I;
      Exit;
    End;
  End;
  
  { Ajouter un nouveau champ }
  If MTFieldCount < MAX_MT_FIELDS Then Begin
    MTFieldAccesses[MTFieldCount].FieldIdx := FieldIdx;
    MTFieldAccesses[MTFieldCount].FieldName := FieldName;
    MTFieldAccesses[MTFieldCount].IsVolatile := IsVolatileField(FieldIdx);
    MTFieldAccesses[MTFieldCount].ReadInSync := False;
    MTFieldAccesses[MTFieldCount].WriteInSync := False;
    MTFieldAccesses[MTFieldCount].ReadNotSync := False;
    MTFieldAccesses[MTFieldCount].WriteNotSync := False;
    MTFieldAccesses[MTFieldCount].GetterSync := False;
    MTFieldAccesses[MTFieldCount].SetterSync := False;
    MTFieldAccesses[MTFieldCount].GetterIdx := -1;
    MTFieldAccesses[MTFieldCount].SetterIdx := -1;
    FindOrAddFieldAccess := MTFieldCount;
    Inc(MTFieldCount);
  End Else
    FindOrAddFieldAccess := -1;
End;

{ --- TODO 16 : Ajouter un bug de concurrence --- }
Procedure AddConcurrencyBug(BugType: Integer; PC: LongWord; LineNum: Integer;
                           ClassName, MethodName, FieldName, Details: String);
Begin
  If MTBugCount >= MAX_MT_BUGS Then Exit;
  
  MTBugs[MTBugCount].BugType := BugType;
  MTBugs[MTBugCount].PC := PC;
  MTBugs[MTBugCount].LineNum := LineNum;
  MTBugs[MTBugCount].ClassName := ClassName;
  MTBugs[MTBugCount].MethodName := MethodName;
  MTBugs[MTBugCount].FieldName := FieldName;
  MTBugs[MTBugCount].Details := Details;
  
  Inc(MTBugCount);
  
  { Mettre a jour les compteurs globaux }
  Case BugType of
    ESYNC_EMPTY_SYNC:        Inc(MTTotalEmptySync);
    UW_UNCOND_WAIT:          Inc(MTTotalWaitNoLoop);
    WA_AWAIT_NOT_IN_LOOP:    Inc(MTTotalWaitNoLoop);
    NN_NAKED_NOTIFY:         Inc(MTTotalNakedNotify);
    NO_NOTIFY_NOT_NOTIFYALL: Inc(MTTotalNakedNotify);
    DC_DOUBLECHECK:          Inc(MTTotalDoubleCheck);
    IS2_INCONSISTENT_SYNC:   Inc(MTTotalInconsistentSync);
    UG_SYNC_SET_UNSYNC_GET:  Inc(MTTotalSyncSetUnsyncGet);
  End;
End;

{ --- TODO 16 : Detecter les blocs synchronized vides --- }
Procedure DetectEmptySyncBlock(MethodIdx: Integer);
Var
  I: Integer;
  MonitorEnterPC: LongWord;
  FoundMonitorEnter: Boolean;
  EmptyCount: Integer;
  LineNum: Integer;
Begin
  If Instructions = Nil Then Exit;
  If InstrCount = 0 Then Exit;
  If (MethodIdx < 0) or (MethodIdx >= MethodCount) Then Exit;
  
  FoundMonitorEnter := False;
  MonitorEnterPC := 0;
  EmptyCount := 0;
  
  For I := 0 to InstrCount - 1 Do Begin
    If Instructions^[I].Opcode = OP_MONITORENTER Then Begin
      FoundMonitorEnter := True;
      MonitorEnterPC := Instructions^[I].PC;
      EmptyCount := 0;
    End
    Else If FoundMonitorEnter Then Begin
      If Instructions^[I].Opcode = OP_MONITOREXIT Then Begin
        { Verifier si le bloc est vide ou presque vide }
        If EmptyCount <= 1 Then Begin
          LineNum := GetLineNumber(Methods[MethodIdx], Word(MonitorEnterPC));
          AddConcurrencyBug(ESYNC_EMPTY_SYNC, MonitorEnterPC, LineNum,
            InternalToJavaName(ClassInfo.ThisClass),
            Methods[MethodIdx].Name, '',
            'Bloc synchronized vide ou quasi-vide');
        End;
        FoundMonitorEnter := False;
      End
      Else Begin
        { Compter les instructions significatives (ignorer aload, astore, dup) }
        If Not (Instructions^[I].Opcode in [OP_ALOAD_0, OP_ALOAD_1, 
                OP_ALOAD_2, OP_ALOAD_3, OP_ALOAD,
                OP_ASTORE_0, OP_ASTORE_1, OP_ASTORE_2, OP_ASTORE_3, OP_ASTORE,
                OP_DUP, OP_POP, OP_NOP]) Then
          Inc(EmptyCount);
      End;
    End;
  End;
End;

{ --- TODO 16 : Detecter wait() sans boucle de garde --- }
Procedure DetectWaitNotInLoop(MethodIdx: Integer);
Var
  I, J: Integer;
  InLoop: Boolean;
  CPIdx: Word;
  ClassName, MethodName, Descriptor: String;
  LineNum: Integer;
Begin
  If Instructions = Nil Then Exit;
  If InstrCount = 0 Then Exit;
  If (MethodIdx < 0) or (MethodIdx >= MethodCount) Then Exit;
  
  For I := 0 to InstrCount - 1 Do Begin
    { Detecter invokevirtual Object.wait() }
    If (Instructions^[I].Opcode = OP_INVOKEVIRTUAL) Then Begin
      CPIdx := Instructions^[I].Op1;
      If (CPIdx > 0) and (CPIdx < CPCount) Then Begin
        ClassName := '';
        MethodName := '';
        Descriptor := '';
        CPGetMemberRef(CPIdx, ClassName, MethodName, Descriptor);
        
        { Verifier si c'est un appel a wait() }
        If IsWaitMethod(MethodName, Descriptor) Then Begin
          { Verifier si on est dans une boucle (chercher un goto en arriere) }
          InLoop := False;
          For J := I + 1 to InstrCount - 1 Do Begin
            If (Instructions^[J].Opcode in [OP_GOTO, OP_GOTO_W]) Then Begin
              { Verifier si c'est un saut en arriere }
              If Instructions^[J].Op1 < 0 Then Begin
                { Le saut doit etre avant l'instruction wait }
                If LongInt(Instructions^[J].PC) + Instructions^[J].Op1 <= LongInt(Instructions^[I].PC) Then
                  InLoop := True;
              End;
            End;
            If Instructions^[J].Opcode in [OP_IRETURN, OP_LRETURN, OP_FRETURN,
                OP_DRETURN, OP_ARETURN, OP_RETURN, OP_ATHROW] Then
              Break;
          End;
          
          { Aussi verifier les sauts conditionnels en arriere avant le wait }
          For J := I - 1 downto 0 Do Begin
            If (Instructions^[J].Opcode in [OP_IFEQ, OP_IFNE, OP_IFLT, OP_IFGE,
                OP_IFGT, OP_IFLE, OP_IF_ICMPEQ, OP_IF_ICMPNE, OP_IF_ICMPLT,
                OP_IF_ICMPGE, OP_IF_ICMPGT, OP_IF_ICMPLE, OP_IF_ACMPEQ,
                OP_IF_ACMPNE, OP_IFNULL, OP_IFNONNULL]) Then Begin
              { Verifier si c'est un saut apres le wait }
              If LongInt(Instructions^[J].PC) + Instructions^[J].Op1 > LongInt(Instructions^[I].PC) Then
                InLoop := True;
            End;
          End;
          
          If Not InLoop Then Begin
            LineNum := GetLineNumber(Methods[MethodIdx], Word(Instructions^[I].PC));
            AddConcurrencyBug(UW_UNCOND_WAIT, Instructions^[I].PC, LineNum,
              InternalToJavaName(ClassInfo.ThisClass),
              Methods[MethodIdx].Name, '',
              'wait() appele sans boucle de garde (while)');
          End;
        End;
      End;
    End;
  End;
End;

{ --- TODO 16 : Detecter await() sans boucle de garde --- }
Procedure DetectAwaitNotInLoop(MethodIdx: Integer);
Var
  I, J: Integer;
  InLoop: Boolean;
  CPIdx: Word;
  ClassName, MethodName, Descriptor: String;
  LineNum: Integer;
Begin
  If Instructions = Nil Then Exit;
  If InstrCount = 0 Then Exit;
  If (MethodIdx < 0) or (MethodIdx >= MethodCount) Then Exit;
  
  For I := 0 to InstrCount - 1 Do Begin
    { Detecter invokeinterface/invokevirtual Condition.await() }
    If (Instructions^[I].Opcode in [OP_INVOKEVIRTUAL, OP_INVOKEINTERFACE]) Then Begin
      CPIdx := Instructions^[I].Op1;
      If (CPIdx > 0) and (CPIdx < CPCount) Then Begin
        ClassName := '';
        MethodName := '';
        Descriptor := '';
        CPGetMemberRef(CPIdx, ClassName, MethodName, Descriptor);
        
        If IsAwaitMethod(ClassName, MethodName) Then Begin
          { Verifier si on est dans une boucle }
          InLoop := False;
          For J := I + 1 to InstrCount - 1 Do Begin
            If (Instructions^[J].Opcode in [OP_GOTO, OP_GOTO_W]) Then Begin
              If Instructions^[J].Op1 < 0 Then Begin
                If LongInt(Instructions^[J].PC) + Instructions^[J].Op1 <= LongInt(Instructions^[I].PC) Then
                  InLoop := True;
              End;
            End;
            If Instructions^[J].Opcode in [OP_IRETURN, OP_LRETURN, OP_FRETURN,
                OP_DRETURN, OP_ARETURN, OP_RETURN, OP_ATHROW] Then
              Break;
          End;
          
          If Not InLoop Then Begin
            LineNum := GetLineNumber(Methods[MethodIdx], Word(Instructions^[I].PC));
            AddConcurrencyBug(WA_AWAIT_NOT_IN_LOOP, Instructions^[I].PC, LineNum,
              InternalToJavaName(ClassInfo.ThisClass),
              Methods[MethodIdx].Name, '',
              'await() appele sans boucle de garde (while)');
          End;
        End;
      End;
    End;
  End;
End;

{ --- TODO 16 : Detecter notify() sans mise a jour d'etat --- }
Procedure DetectNakedNotify(MethodIdx: Integer);
Var
  I, J: Integer;
  HasFieldWrite: Boolean;
  CPIdx: Word;
  ClassName, MethodName, Descriptor: String;
  LineNum: Integer;
Begin
  If Instructions = Nil Then Exit;
  If InstrCount = 0 Then Exit;
  If (MethodIdx < 0) or (MethodIdx >= MethodCount) Then Exit;
  
  For I := 0 to InstrCount - 1 Do Begin
    { Detecter invokevirtual Object.notify() ou notifyAll() }
    If (Instructions^[I].Opcode = OP_INVOKEVIRTUAL) Then Begin
      CPIdx := Instructions^[I].Op1;
      If (CPIdx > 0) and (CPIdx < CPCount) Then Begin
        ClassName := '';
        MethodName := '';
        Descriptor := '';
        CPGetMemberRef(CPIdx, ClassName, MethodName, Descriptor);
        
        If IsNotifyMethod(MethodName, Descriptor) Then Begin
          { Verifier si un champ a ete ecrit avant le notify }
          HasFieldWrite := False;
          For J := I - 1 downto 0 Do Begin
            If Instructions^[J].Opcode in [OP_PUTFIELD, OP_PUTSTATIC] Then Begin
              HasFieldWrite := True;
              Break;
            End;
            { Arreter si on sort d'un bloc sync ou trouve un autre notify/wait }
            If Instructions^[J].Opcode in [OP_MONITORENTER, OP_MONITOREXIT] Then
              Break;
          End;
          
          If Not HasFieldWrite Then Begin
            LineNum := GetLineNumber(Methods[MethodIdx], Word(Instructions^[I].PC));
            AddConcurrencyBug(NN_NAKED_NOTIFY, Instructions^[I].PC, LineNum,
              InternalToJavaName(ClassInfo.ThisClass),
              Methods[MethodIdx].Name, '',
              'notify() appele sans mise a jour d''un etat partage');
          End;
          
          { Suggerer notifyAll() au lieu de notify() }
          LineNum := GetLineNumber(Methods[MethodIdx], Word(Instructions^[I].PC));
          AddConcurrencyBug(NO_NOTIFY_NOT_NOTIFYALL, Instructions^[I].PC, LineNum,
            InternalToJavaName(ClassInfo.ThisClass),
            Methods[MethodIdx].Name, '',
            'notify() utilise - notifyAll() serait plus sur');
        End;
      End;
    End;
  End;
End;

{ --- TODO 16 : Detecter double-checked locking incorrect --- }
Procedure DetectDoubleCheckedLocking(MethodIdx: Integer);
Var
  I: Integer;
  NullCheckPC: LongWord;
  NullCheckCpIdx: Word;
  FoundMonitor: Boolean;
  SecondNullCheck: Boolean;
  ClassName, FieldName, Descriptor: String;
  LineNum: Integer;
Begin
  If Instructions = Nil Then Exit;
  If InstrCount = 0 Then Exit;
  If (MethodIdx < 0) or (MethodIdx >= MethodCount) Then Exit;
  
  { Pattern typique de double-checked locking:
    1. if (field == null)        // Premier test
    2.   synchronized(this)      // monitorenter
    3.     if (field == null)    // Deuxieme test
    4.       field = new ...     // Initialisation
    5.   end synchronized        // monitorexit
  }
  
  NullCheckPC := 0;
  NullCheckCpIdx := 0;
  FoundMonitor := False;
  SecondNullCheck := False;
  
  For I := 0 to InstrCount - 1 Do Begin
    { Detecter getfield suivi de ifnull/ifnonnull }
    If Instructions^[I].Opcode in [OP_GETFIELD, OP_GETSTATIC] Then Begin
      If (I + 1 < InstrCount) Then Begin
        If Instructions^[I + 1].Opcode in [OP_IFNULL, OP_IFNONNULL] Then Begin
          If Not FoundMonitor Then Begin
            { Premier test de null }
            NullCheckPC := Instructions^[I].PC;
            NullCheckCpIdx := Instructions^[I].Op1;
          End Else Begin
            { Deuxieme test de null apres monitorenter }
            If Instructions^[I].Op1 = NullCheckCpIdx Then Begin
              SecondNullCheck := True;
              { Verifier si le champ est volatile }
              { Si non volatile, c'est un double-check locking incorrect }
              { Pour simplifier, on rapporte un warning }
              ClassName := '';
              FieldName := '';
              Descriptor := '';
              If (NullCheckCpIdx > 0) and (NullCheckCpIdx < CPCount) Then
                CPGetMemberRef(NullCheckCpIdx, ClassName, FieldName, Descriptor);
              LineNum := GetLineNumber(Methods[MethodIdx], Word(NullCheckPC));
              AddConcurrencyBug(DC_DOUBLECHECK, NullCheckPC, LineNum,
                InternalToJavaName(ClassInfo.ThisClass),
                Methods[MethodIdx].Name, FieldName,
                'Double-checked locking detecte - verifier si le champ est volatile');
              Inc(MTTotalDoubleCheck);
            End;
          End;
        End;
      End;
    End
    Else If Instructions^[I].Opcode = OP_MONITORENTER Then Begin
      If NullCheckCpIdx > 0 Then
        FoundMonitor := True;
    End
    Else If Instructions^[I].Opcode = OP_MONITOREXIT Then Begin
      { Reset apres fin du bloc synchronized }
      If SecondNullCheck Then Begin
        NullCheckPC := 0;
        NullCheckCpIdx := 0;
        FoundMonitor := False;
        SecondNullCheck := False;
      End;
    End;
  End;
End;

{ --- TODO 16 : Tracker les acces aux champs pour detecter inconsistances --- }
Procedure TrackFieldAccess(MethodIdx: Integer; IsInSync: Boolean);
Var
  I: Integer;
  FieldIdx: Integer;
  CPIdx: Word;
  ClassName, FieldName, Descriptor: String;
  AccessIdx: Integer;
Begin
  If Instructions = Nil Then Exit;
  If InstrCount = 0 Then Exit;
  If (MethodIdx < 0) or (MethodIdx >= MethodCount) Then Exit;
  
  For I := 0 to InstrCount - 1 Do Begin
    If Instructions^[I].Opcode in [OP_GETFIELD, OP_GETSTATIC] Then Begin
      CPIdx := Instructions^[I].Op1;
      If (CPIdx > 0) and (CPIdx < CPCount) Then Begin
        ClassName := '';
        FieldName := '';
        Descriptor := '';
        CPGetMemberRef(CPIdx, ClassName, FieldName, Descriptor);
        FieldIdx := -1; { TODO: trouver l'index dans Fields[] }
        AccessIdx := FindOrAddFieldAccess(FieldName, FieldIdx);
        If AccessIdx >= 0 Then Begin
          If IsInSync Then
            MTFieldAccesses[AccessIdx].ReadInSync := True
          Else
            MTFieldAccesses[AccessIdx].ReadNotSync := True;
        End;
      End;
    End
    Else If Instructions^[I].Opcode in [OP_PUTFIELD, OP_PUTSTATIC] Then Begin
      CPIdx := Instructions^[I].Op1;
      If (CPIdx > 0) and (CPIdx < CPCount) Then Begin
        ClassName := '';
        FieldName := '';
        Descriptor := '';
        CPGetMemberRef(CPIdx, ClassName, FieldName, Descriptor);
        FieldIdx := -1;
        AccessIdx := FindOrAddFieldAccess(FieldName, FieldIdx);
        If AccessIdx >= 0 Then Begin
          If IsInSync Then
            MTFieldAccesses[AccessIdx].WriteInSync := True
          Else
            MTFieldAccesses[AccessIdx].WriteNotSync := True;
        End;
      End;
    End;
  End;
End;

{ --- TODO 16 : Detecter acces inconsistants aux champs --- }
Procedure DetectInconsistentSync(MethodIdx: Integer);
Var
  I: Integer;
Begin
  { Apres avoir analyse toutes les methodes, verifier les inconsistances }
  For I := 0 to MTFieldCount - 1 Do Begin
    { Verifier si un champ est accede parfois en sync, parfois non }
    If (MTFieldAccesses[I].ReadInSync or MTFieldAccesses[I].WriteInSync) and
       (MTFieldAccesses[I].ReadNotSync or MTFieldAccesses[I].WriteNotSync) and
       (Not MTFieldAccesses[I].IsVolatile) Then Begin
      AddConcurrencyBug(IS2_INCONSISTENT_SYNC, 0, 0,
        InternalToJavaName(ClassInfo.ThisClass),
        '', MTFieldAccesses[I].FieldName,
        'Champ accede avec et sans synchronisation');
    End;
    
    { Verifier setter sync mais getter non sync }
    If MTFieldAccesses[I].SetterSync and (Not MTFieldAccesses[I].GetterSync) Then Begin
      AddConcurrencyBug(UG_SYNC_SET_UNSYNC_GET, 0, 0,
        InternalToJavaName(ClassInfo.ThisClass),
        '', MTFieldAccesses[I].FieldName,
        'Setter synchronized mais getter non synchronized');
    End;
  End;
End;

{ --- TODO 16 : Detecter utilisation directe de monitorenter --- }
Procedure DetectDirectMonitorUse(MethodIdx: Integer);
Var
  I: Integer;
Begin
  If Instructions = Nil Then Exit;
  If InstrCount = 0 Then Exit;
  
  For I := 0 to InstrCount - 1 Do Begin
    { Detecter monitorenter/monitorexit explicites (sans synchronized) }
    { Dans une classe utilisant JSR166 (Lock), c'est suspect }
    If Instructions^[I].Opcode = OP_MONITORENTER Then Begin
      { Verifier si la classe utilise aussi des Lock JSR166 }
      { Pour simplifier, on ne rapporte que si on detecte Lock.lock() }
      { TODO: analyse plus fine }
    End;
  End;
End;

{ --- TODO 16 : Analyser une methode pour les problemes de concurrence --- }
Procedure AnalyzeMethodForConcurrency(MethodIdx: Integer);
Var
  IsSync: Boolean;
Begin
  If (MethodIdx < 0) or (MethodIdx >= MethodCount) Then Exit;
  If Methods[MethodIdx].CodeLen = 0 Then Exit;
  
  IsSync := IsSynchronizedMethod(MethodIdx);
  MTInSyncMethod := IsSync;
  
  { Decoder les instructions si pas deja fait }
  DecodeInstructions(Methods[MethodIdx]);
  
  { Tracker les acces aux champs }
  TrackFieldAccess(MethodIdx, IsSync);
  
  { Detecter les blocs synchronized vides }
  DetectEmptySyncBlock(MethodIdx);
  
  { Detecter wait() sans boucle }
  DetectWaitNotInLoop(MethodIdx);
  
  { Detecter await() sans boucle }
  DetectAwaitNotInLoop(MethodIdx);
  
  { Detecter notify() nu }
  DetectNakedNotify(MethodIdx);
  
  { Detecter double-checked locking }
  DetectDoubleCheckedLocking(MethodIdx);
  
  { Detecter utilisation directe de monitor }
  DetectDirectMonitorUse(MethodIdx);
End;

{ --- TODO 16 : Point d'entree : detecter les problemes de concurrence --- }
Procedure DetectConcurrencyIssues;
Var
  I: Integer;
Begin
  InitConcurrencyState;
  
  { Analyser toutes les methodes }
  For I := 0 to MethodCount - 1 Do Begin
    AnalyzeMethodForConcurrency(I);
  End;
  
  { Detecter les inconsistances entre methodes }
  DetectInconsistentSync(-1);
End;

{ --- TODO 16 : Afficher l'etat du module de concurrence --- }
Procedure DumpConcurrencyState;
Var
  I: Integer;
Begin
  WriteLn('=== Etat du module de detection de concurrence ===');
  WriteLn('Initialise         : ', MTInitialized);
  WriteLn('Bugs detectes      : ', MTBugCount);
  WriteLn('Champs trackes     : ', MTFieldCount);
  WriteLn('Total sync vides   : ', MTTotalEmptySync);
  WriteLn('Total wait no loop : ', MTTotalWaitNoLoop);
  WriteLn('Total naked notify : ', MTTotalNakedNotify);
  WriteLn('Total double-check : ', MTTotalDoubleCheck);
  WriteLn('Total inconsistent : ', MTTotalInconsistentSync);
  WriteLn('Total sync/unsync  : ', MTTotalSyncSetUnsyncGet);
  WriteLn;
  
  If MTBugCount > 0 Then Begin
    WriteLn('--- Bugs de concurrence detectes ---');
    For I := 0 to MTBugCount - 1 Do Begin
      WriteLn(I + 1, '. ', MTBugTypeName(MTBugs[I].BugType));
      WriteLn('   Classe  : ', MTBugs[I].ClassName);
      WriteLn('   Methode : ', MTBugs[I].MethodName);
      If MTBugs[I].FieldName <> '' Then
        WriteLn('   Champ   : ', MTBugs[I].FieldName);
      WriteLn('   Ligne   : ', MTBugs[I].LineNum);
      WriteLn('   Details : ', MTBugs[I].Details);
      WriteLn;
    End;
  End;
End;

{ --- TODO 16 : Accesseurs pour le module de concurrence --- }
Function GetMTInitialized: Boolean;
Begin
  GetMTInitialized := MTInitialized;
End;

Function GetMTBugCount: Integer;
Begin
  GetMTBugCount := MTBugCount;
End;

Function GetMTFieldCount: Integer;
Begin
  GetMTFieldCount := MTFieldCount;
End;

Function GetMTTotalEmptySync: Integer;
Begin
  GetMTTotalEmptySync := MTTotalEmptySync;
End;

Function GetMTTotalWaitNoLoop: Integer;
Begin
  GetMTTotalWaitNoLoop := MTTotalWaitNoLoop;
End;

Function GetMTTotalNakedNotify: Integer;
Begin
  GetMTTotalNakedNotify := MTTotalNakedNotify;
End;

Function GetMTTotalDoubleCheck: Integer;
Begin
  GetMTTotalDoubleCheck := MTTotalDoubleCheck;
End;

Function GetMTTotalInconsistentSync: Integer;
Begin
  GetMTTotalInconsistentSync := MTTotalInconsistentSync;
End;

Function GetMTTotalSyncSetUnsyncGet: Integer;
Begin
  GetMTTotalSyncSetUnsyncGet := MTTotalSyncSetUnsyncGet;
End;

Function GetMTBugType(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < MTBugCount) Then
    GetMTBugType := MTBugs[Idx].BugType
  Else
    GetMTBugType := MT_NONE;
End;

Function GetMTBugPC(Idx: Integer): LongWord;
Begin
  If (Idx >= 0) and (Idx < MTBugCount) Then
    GetMTBugPC := MTBugs[Idx].PC
  Else
    GetMTBugPC := 0;
End;

Function GetMTBugLine(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < MTBugCount) Then
    GetMTBugLine := MTBugs[Idx].LineNum
  Else
    GetMTBugLine := 0;
End;

{ ============================================================================ }
{ TODO 17 [IMPLEMENTE] - Detecteur : exceptions masquees et flux d'erreur      }
{ ============================================================================ }

{ --- TODO 17 : Initialisation du module exceptions masquees --- }
Procedure InitExHandlingState;
Var
  I: Integer;
Begin
  EXInitialized := True;
  EXBugCount := 0;
  EXCatchCount := 0;
  EXFinallyCount := 0;
  EXLabelNum := 0;
  EXTotalIgnored := 0;
  EXTotalTooWide := 0;
  EXTotalFinallyReturn := 0;
  EXTotalRedundantNull := 0;
  EXTotalPopOnly := 0;
  EXTotalNoSuperEquals := 0;
  EXCurrentPC := 0;
  EXCurrentLine := 0;
  EXInTryBlock := False;
  EXInCatchBlock := False;
  EXInFinallyBlock := False;
  
  For I := 0 to MAX_EX_BUGS - 1 Do Begin
    EXBugs[I].BugType := EXH_NONE;
    EXBugs[I].PC := 0;
    EXBugs[I].LineNum := 0;
    EXBugs[I].ClassName := '';
    EXBugs[I].MethodName := '';
    EXBugs[I].CatchType := '';
    EXBugs[I].Details := '';
  End;
  
  For I := 0 to MAX_EX_CATCH_INFO - 1 Do Begin
    EXCatchInfos[I].StartPC := 0;
    EXCatchInfos[I].EndPC := 0;
    EXCatchInfos[I].HandlerPC := 0;
    EXCatchInfos[I].CatchType := '';
    EXCatchInfos[I].HandlerLen := 0;
    EXCatchInfos[I].IsPopOnly := False;
    EXCatchInfos[I].IsPopReturn := False;
    EXCatchInfos[I].IsTooWide := False;
    EXCatchInfos[I].ExcTableIdx := -1;
  End;
  
  For I := 0 to MAX_EX_FINALLY_INFO - 1 Do Begin
    EXFinallyInfos[I].StartPC := 0;
    EXFinallyInfos[I].EndPC := 0;
    EXFinallyInfos[I].HasReturn := False;
    EXFinallyInfos[I].ReturnPC := 0;
    EXFinallyInfos[I].ExcTableIdx := -1;
  End;
End;

{ --- TODO 17 : Generation d'un label unique pour le module --- }
Function GenEXLabel: String;
Begin
  Inc(EXLabelNum);
  GenEXLabel := '_EX_' + IntToStr_(EXLabelNum);
End;

{ --- TODO 17 : Conversion du type de bug en chaine --- }
Function EXBugTypeName(BugType: Integer): String;
Begin
  Case BugType of
    EXH_NONE:                              EXBugTypeName := 'EXH_NONE';
    EXH_THROWN_IGNORED:                    EXBugTypeName := 'THROWN_EXCEPTION_IGNORED';
    EXH_CATCH_EXCEPTION:                   EXBugTypeName := 'REC_CATCH_EXCEPTION';
    EXH_REDUNDANT_NULLCHECK:               EXBugTypeName := 'RCN_REDUNDANT_NULLCHECK';
    EXH_FINALLY_RETURN:                    EXBugTypeName := 'FINALLY_NULLIFIES_EXCEPTION';
    EXH_NO_SUPER_EQUALS:                   EXBugTypeName := 'OVERRIDDEN_EQUALS_NO_SUPER_CALL';
    EXH_CATCH_THROWABLE:                   EXBugTypeName := 'REC_CATCH_THROWABLE';
    EXH_POP_ONLY:                          EXBugTypeName := 'DE_MIGHT_IGNORE';
    EXH_DROPPED:                           EXBugTypeName := 'DE_MIGHT_DROP';
  Else
    EXBugTypeName := 'UNKNOWN';
  End;
End;

{ --- TODO 17 : Detecter si un type est java.lang.Exception --- }
Function IsCatchException(TypeName: String): Boolean;
Begin
  IsCatchException := (TypeName = 'java/lang/Exception') or
                      (TypeName = 'Exception') or
                      (Pos('Exception', TypeName) = Length(TypeName) - 8);
End;

{ --- TODO 17 : Detecter si un type est java.lang.Throwable --- }
Function IsCatchThrowable(TypeName: String): Boolean;
Begin
  IsCatchThrowable := (TypeName = 'java/lang/Throwable') or
                      (TypeName = 'Throwable');
End;

{ --- TODO 17 : Detecter si c'est un catch all (finally interne) --- }
Function IsCatchAll(TypeName: String): Boolean;
Begin
  IsCatchAll := (TypeName = '') or (TypeName = 'any');
End;

{ --- TODO 17 : Detecter si un catch est trop large --- }
Function IsTooWideCatch(TypeName: String): Boolean;
Begin
  IsTooWideCatch := IsCatchException(TypeName) or IsCatchThrowable(TypeName);
End;

{ --- TODO 17 : Detecter si c'est une methode equals --- }
Function IsEqualsMethod(MethodName, Descriptor: String): Boolean;
Begin
  IsEqualsMethod := (MethodName = 'equals') and 
                    (Descriptor = '(Ljava/lang/Object;)Z');
End;

{ --- TODO 17 : Detecter si un opcode est un return --- }
Function IsReturnOpcode(Opcode: Integer): Boolean;
Begin
  IsReturnOpcode := (Opcode = OP_IRETURN) or (Opcode = OP_LRETURN) or
                    (Opcode = OP_FRETURN) or (Opcode = OP_DRETURN) or
                    (Opcode = OP_ARETURN) or (Opcode = OP_RETURN);
End;

{ --- TODO 17 : Detecter si un opcode est pop --- }
Function IsPopOpcode(Opcode: Integer): Boolean;
Begin
  IsPopOpcode := (Opcode = OP_POP) or (Opcode = OP_POP2);
End;

{ --- TODO 17 : Detecter si un opcode est astore --- }
Function IsAstoreOpcode(Opcode: Integer): Boolean;
Begin
  IsAstoreOpcode := (Opcode = OP_ASTORE) or (Opcode = OP_ASTORE_0) or
                    (Opcode = OP_ASTORE_1) or (Opcode = OP_ASTORE_2) or
                    (Opcode = OP_ASTORE_3);
End;

{ --- TODO 17 : Detecter si c'est un appel invokespecial super.equals --- }
Function IsSuperEqualsCall(MethodIdx: Integer; InstrIdx: Integer): Boolean;
Var
  CpIdx: Word;
  ClassIdx, NatIdx, NameIdx, DescIdx: Word;
  MemberClass, MemberName, MemberDesc: String;
  CurrentClass: String;
Begin
  IsSuperEqualsCall := False;
  If (InstrIdx < 0) or (InstrIdx >= InstrCount) Then Exit;
  If Instructions^[InstrIdx].Opcode <> OP_INVOKESPECIAL Then Exit;
  
  { Op1 contient l'index dans le constant pool }
  CpIdx := Instructions^[InstrIdx].Op1;
  If (CpIdx > 0) and (CpIdx < CPCount) Then Begin
    MemberClass := '';
    MemberName := '';
    MemberDesc := '';
    { Extraire classe et nom de methode du constant pool }
    If CP^[CpIdx].Tag = CP_METHODREF Then Begin
      { Ref1 = class_index, Ref2 = name_and_type_index }
      ClassIdx := CP^[CpIdx].Ref1;
      NatIdx := CP^[CpIdx].Ref2;
      
      { Obtenir le nom de classe }
      If (ClassIdx > 0) and (ClassIdx < CPCount) Then Begin
        If CP^[ClassIdx].Tag = CP_CLASS Then Begin
          { Ref1 = name_index }
          NameIdx := CP^[ClassIdx].Ref1;
          If (NameIdx > 0) and (NameIdx < CPCount) Then Begin
            If CP^[NameIdx].Tag = CP_UTF8 Then
              MemberClass := CP^[NameIdx].StrVal;
          End;
        End;
      End;
      
      { Obtenir le nom et descripteur de methode }
      If (NatIdx > 0) and (NatIdx < CPCount) Then Begin
        If CP^[NatIdx].Tag = CP_NAMEANDTYPE Then Begin
          { Ref1 = name_index, Ref2 = descriptor_index }
          NameIdx := CP^[NatIdx].Ref1;
          DescIdx := CP^[NatIdx].Ref2;
          
          If (NameIdx > 0) and (NameIdx < CPCount) Then Begin
            If CP^[NameIdx].Tag = CP_UTF8 Then
              MemberName := CP^[NameIdx].StrVal;
          End;
          
          If (DescIdx > 0) and (DescIdx < CPCount) Then Begin
            If CP^[DescIdx].Tag = CP_UTF8 Then
              MemberDesc := CP^[DescIdx].StrVal;
          End;
        End;
      End;
    End;
    
    { Verifier que c'est super.equals() }
    CurrentClass := ClassInfo.ThisClass;
    If (MemberClass <> '') and (MemberClass <> CurrentClass) and
       (MemberName = 'equals') and (MemberDesc = '(Ljava/lang/Object;)Z') Then Begin
      IsSuperEqualsCall := True;
    End;
  End;
End;

{ --- TODO 17 : Ajouter un bug d'exception masquee --- }
Procedure AddExHandlingBug(BugType: Integer; PC: LongWord; LineNum: Integer;
                           CatchType, Details: String);
Begin
  If EXBugCount >= MAX_EX_BUGS Then Exit;
  
  EXBugs[EXBugCount].BugType := BugType;
  EXBugs[EXBugCount].PC := PC;
  EXBugs[EXBugCount].LineNum := LineNum;
  EXBugs[EXBugCount].ClassName := ClassInfo.ThisClass;
  If (MethodCount > 0) and (EXCurrentLine >= 0) Then Begin
    { Utiliser le nom de la methode courante si disponible }
    EXBugs[EXBugCount].MethodName := '<current>';
  End Else Begin
    EXBugs[EXBugCount].MethodName := '';
  End;
  EXBugs[EXBugCount].CatchType := CatchType;
  EXBugs[EXBugCount].Details := Details;
  
  Inc(EXBugCount);
  
  { Incrementer les compteurs selon le type }
  Case BugType of
    EXH_THROWN_IGNORED: Inc(EXTotalIgnored);
    EXH_CATCH_EXCEPTION: Inc(EXTotalTooWide);
    EXH_CATCH_THROWABLE: Inc(EXTotalTooWide);
    EXH_REDUNDANT_NULLCHECK: Inc(EXTotalRedundantNull);
    EXH_FINALLY_RETURN: Inc(EXTotalFinallyReturn);
    EXH_POP_ONLY: Inc(EXTotalPopOnly);
    EXH_NO_SUPER_EQUALS: Inc(EXTotalNoSuperEquals);
  End;
End;

{ --- TODO 17 : Analyser un bloc catch pour determiner s'il ignore l'exception --- }
Procedure AnalyzeCatchBlock(MethodIdx: Integer; HandlerPC: LongWord; 
                            CatchType: String; ExcIdx: Integer);
Var
  I, StartInstr, InstrLen: Integer;
  PC: LongWord;
  Opcode1, Opcode2: Integer;
  IsPopOnly, IsPopReturn: Boolean;
  LineNum: Integer;
Begin
  If (Instructions = nil) or (InstrCount = 0) Then Exit;
  
  { Trouver l'instruction au HandlerPC }
  StartInstr := -1;
  For I := 0 to InstrCount - 1 Do Begin
    If Instructions^[I].PC = HandlerPC Then Begin
      StartInstr := I;
      Break;
    End;
  End;
  
  If StartInstr < 0 Then Exit;
  
  LineNum := GetLineNumber(Methods[MethodIdx], HandlerPC);
  IsPopOnly := False;
  IsPopReturn := False;
  
  { Compter les instructions dans le catch handler }
  { Un catch minimal est : astore (stocker exception) ou pop (ignorer) }
  { suivi d'autres instructions ou return }
  
  InstrLen := 0;
  I := StartInstr;
  While (I < InstrCount) and (InstrLen < 10) Do Begin
    PC := Instructions^[I].PC;
    
    { Sortir si on atteint un autre handler ou une branche arriere }
    If (InstrLen > 0) and (IsBranchOpcode(Instructions^[I].Opcode) or 
        IsReturnOpcode(Instructions^[I].Opcode) or
        (Instructions^[I].Opcode = OP_ATHROW)) Then Begin
      Break;
    End;
    
    Inc(InstrLen);
    Inc(I);
  End;
  
  { Detecter les patterns de catch ignore }
  If (StartInstr < InstrCount) Then Begin
    Opcode1 := Instructions^[StartInstr].Opcode;
    
    { Pattern 1: pop seul ou pop + goto/return }
    If IsPopOpcode(Opcode1) Then Begin
      If (InstrLen = 1) Then Begin
        IsPopOnly := True;
      End Else If (InstrLen = 2) and (StartInstr + 1 < InstrCount) Then Begin
        Opcode2 := Instructions^[StartInstr + 1].Opcode;
        If IsReturnOpcode(Opcode2) or (Opcode2 = OP_GOTO) Then Begin
          IsPopReturn := True;
        End;
      End;
    End;
    
    { Pattern 2: astore suivi uniquement de return }
    If IsAstoreOpcode(Opcode1) and (InstrLen = 2) and 
       (StartInstr + 1 < InstrCount) Then Begin
      Opcode2 := Instructions^[StartInstr + 1].Opcode;
      If IsReturnOpcode(Opcode2) Then Begin
        IsPopReturn := True;
      End;
    End;
  End;
  
  { Enregistrer le catch block }
  If EXCatchCount < MAX_EX_CATCH_INFO Then Begin
    EXCatchInfos[EXCatchCount].StartPC := 0; { sera rempli depuis exc table }
    EXCatchInfos[EXCatchCount].EndPC := 0;
    EXCatchInfos[EXCatchCount].HandlerPC := HandlerPC;
    EXCatchInfos[EXCatchCount].CatchType := CatchType;
    EXCatchInfos[EXCatchCount].HandlerLen := InstrLen;
    EXCatchInfos[EXCatchCount].IsPopOnly := IsPopOnly;
    EXCatchInfos[EXCatchCount].IsPopReturn := IsPopReturn;
    EXCatchInfos[EXCatchCount].IsTooWide := IsTooWideCatch(CatchType);
    EXCatchInfos[EXCatchCount].ExcTableIdx := ExcIdx;
    Inc(EXCatchCount);
  End;
  
  { Reporter les bugs detectes }
  If IsPopOnly Then Begin
    AddExHandlingBug(EXH_POP_ONLY, HandlerPC, LineNum, CatchType,
                     'Exception capturee mais corps catch ne contient que pop');
  End Else If IsPopReturn Then Begin
    AddExHandlingBug(EXH_THROWN_IGNORED, HandlerPC, LineNum, CatchType,
                     'Exception capturee et ignoree silencieusement');
  End;
  
  { Reporter catch trop large }
  If IsCatchThrowable(CatchType) Then Begin
    AddExHandlingBug(EXH_CATCH_THROWABLE, HandlerPC, LineNum, CatchType,
                     'catch(Throwable) capture toutes les erreurs y compris Error');
  End Else If IsCatchException(CatchType) and not IsCatchAll(CatchType) Then Begin
    AddExHandlingBug(EXH_CATCH_EXCEPTION, HandlerPC, LineNum, CatchType,
                     'catch(Exception) est trop large, capturer des exceptions specifiques');
  End;
End;

{ --- TODO 17 : Analyser les blocs finally pour detecter return --- }
Procedure AnalyzeFinallyBlock(MethodIdx: Integer; HandlerPC: LongWord; 
                              ExcIdx: Integer);
Var
  I, StartInstr: Integer;
  PC, ReturnPC: LongWord;
  HasReturn: Boolean;
  LineNum: Integer;
  EndPC: LongWord;
Begin
  If (Instructions = nil) or (InstrCount = 0) Then Exit;
  
  { Trouver l'instruction au HandlerPC }
  StartInstr := -1;
  For I := 0 to InstrCount - 1 Do Begin
    If Instructions^[I].PC = HandlerPC Then Begin
      StartInstr := I;
      Break;
    End;
  End;
  
  If StartInstr < 0 Then Exit;
  
  HasReturn := False;
  ReturnPC := 0;
  EndPC := HandlerPC;
  
  { Scanner le bloc finally pour trouver un return }
  I := StartInstr;
  While I < InstrCount Do Begin
    PC := Instructions^[I].PC;
    EndPC := PC;
    
    If IsReturnOpcode(Instructions^[I].Opcode) Then Begin
      HasReturn := True;
      ReturnPC := PC;
      Break;
    End;
    
    { Sortir si on atteint athrow (fin normale du finally) }
    If Instructions^[I].Opcode = OP_ATHROW Then Break;
    
    Inc(I);
  End;
  
  { Enregistrer le finally block }
  If EXFinallyCount < MAX_EX_FINALLY_INFO Then Begin
    EXFinallyInfos[EXFinallyCount].StartPC := HandlerPC;
    EXFinallyInfos[EXFinallyCount].EndPC := EndPC;
    EXFinallyInfos[EXFinallyCount].HasReturn := HasReturn;
    EXFinallyInfos[EXFinallyCount].ReturnPC := ReturnPC;
    EXFinallyInfos[EXFinallyCount].ExcTableIdx := ExcIdx;
    Inc(EXFinallyCount);
  End;
  
  { Reporter le bug si return dans finally }
  If HasReturn Then Begin
    LineNum := GetLineNumber(Methods[MethodIdx], ReturnPC);
    AddExHandlingBug(EXH_FINALLY_RETURN, ReturnPC, LineNum, '',
                     'return dans finally masque toute exception du try');
  End;
End;

{ --- TODO 17 : Detecter equals() sans appel super.equals() --- }
Procedure DetectEqualsNoSuper(MethodIdx: Integer);
Var
  I: Integer;
  HasSuperEquals: Boolean;
  LineNum: Integer;
  CurrentClass: String;
Begin
  If (MethodIdx < 0) or (MethodIdx >= MethodCount) Then Exit;
  If (Instructions = nil) or (InstrCount = 0) Then Exit;
  
  { Verifier que c'est bien une methode equals }
  If not IsEqualsMethod(Methods[MethodIdx].Name, Methods[MethodIdx].Descriptor) Then
    Exit;
    
  { Verifier que ce n'est pas la classe Object elle-meme }
  CurrentClass := ClassInfo.ThisClass;
  If (CurrentClass = 'java/lang/Object') or (CurrentClass = 'Object') Then Exit;
  If Pos('java/lang/Object', CurrentClass) > 0 Then Exit;
  
  { Chercher un appel super.equals() }
  HasSuperEquals := False;
  For I := 0 to InstrCount - 1 Do Begin
    If IsSuperEqualsCall(MethodIdx, I) Then Begin
      HasSuperEquals := True;
      Break;
    End;
  End;
  
  { Reporter si pas d'appel super.equals() }
  If not HasSuperEquals Then Begin
    LineNum := GetLineNumber(Methods[MethodIdx], 0);
    AddExHandlingBug(EXH_NO_SUPER_EQUALS, 0, LineNum, '',
                     'equals() ne fait pas appel a super.equals()');
  End;
End;

{ --- TODO 17 : Detecter les null check redondants apres dereferencement --- }
Procedure DetectRedundantNullCheck(MethodIdx: Integer);
Var
  I: Integer;
  VarUsed: Array[0..63] of Boolean;  { Variables dereferencees }
  VarDerefPC: Array[0..63] of LongWord;
  VarIdx: Integer;
  PC: LongWord;
  LineNum: Integer;
Begin
  If (Instructions = nil) or (InstrCount = 0) Then Exit;
  
  { Initialiser }
  For I := 0 to 63 Do Begin
    VarUsed[I] := False;
    VarDerefPC[I] := 0;
  End;
  
  { Scanner les instructions }
  For I := 0 to InstrCount - 1 Do Begin
    PC := Instructions^[I].PC;
    
    { Detecter un dereferencement (getfield, invokevirtual apres aload) }
    If (I > 0) and ((Instructions^[I].Opcode = OP_GETFIELD) or
        (Instructions^[I].Opcode = OP_INVOKEVIRTUAL) or
        (Instructions^[I].Opcode = OP_INVOKEINTERFACE)) Then Begin
      { L'instruction precedente devrait avoir charge une reference }
      If (Instructions^[I-1].Opcode >= OP_ALOAD_0) and 
         (Instructions^[I-1].Opcode <= OP_ALOAD_3) Then Begin
        VarIdx := Instructions^[I-1].Opcode - OP_ALOAD_0;
        If (VarIdx >= 0) and (VarIdx < 64) Then Begin
          If not VarUsed[VarIdx] Then Begin
            VarUsed[VarIdx] := True;
            VarDerefPC[VarIdx] := PC;
          End;
        End;
      End Else If Instructions^[I-1].Opcode = OP_ALOAD Then Begin
        VarIdx := Instructions^[I-1].Op1;
        If (VarIdx >= 0) and (VarIdx < 64) Then Begin
          If not VarUsed[VarIdx] Then Begin
            VarUsed[VarIdx] := True;
            VarDerefPC[VarIdx] := PC;
          End;
        End;
      End;
    End;
    
    { Detecter un null check (ifnull, ifnonnull, ou comparaison avec aconst_null) }
    If (Instructions^[I].Opcode = OP_IFNULL) or 
       (Instructions^[I].Opcode = OP_IFNONNULL) Then Begin
      { Verifier si la variable a deja ete dereferencee }
      If (I > 0) Then Begin
        If (Instructions^[I-1].Opcode >= OP_ALOAD_0) and 
           (Instructions^[I-1].Opcode <= OP_ALOAD_3) Then Begin
          VarIdx := Instructions^[I-1].Opcode - OP_ALOAD_0;
          If (VarIdx >= 0) and (VarIdx < 64) and VarUsed[VarIdx] Then Begin
            LineNum := GetLineNumber(Methods[MethodIdx], PC);
            AddExHandlingBug(EXH_REDUNDANT_NULLCHECK, PC, LineNum, '',
                           'Verification null apres dereferencement de la variable ' + IntToStr_(VarIdx));
          End;
        End Else If Instructions^[I-1].Opcode = OP_ALOAD Then Begin
          VarIdx := Instructions^[I-1].Op1;
          If (VarIdx >= 0) and (VarIdx < 64) and VarUsed[VarIdx] Then Begin
            LineNum := GetLineNumber(Methods[MethodIdx], PC);
            AddExHandlingBug(EXH_REDUNDANT_NULLCHECK, PC, LineNum, '',
                           'Verification null apres dereferencement de la variable ' + IntToStr_(VarIdx));
          End;
        End;
      End;
    End;
  End;
End;

{ --- TODO 17 : Detecter les problemes de gestion d'exception dans une methode --- }
Procedure DetectExceptionHandlingIssues(MethodIdx: Integer);
Var
  I: Integer;
  CatchType: String;
Begin
  If (MethodIdx < 0) or (MethodIdx >= MethodCount) Then Exit;
  
  { Reinitialiser les compteurs locaux }
  EXCatchCount := 0;
  EXFinallyCount := 0;
  
  { Analyser la table d'exceptions de la methode }
  For I := 0 to Methods[MethodIdx].ExcCount - 1 Do Begin
    CatchType := Methods[MethodIdx].ExcTable[I].CatchName;
    
    { Detecter si c'est un finally (catch all) }
    If IsCatchAll(CatchType) Then Begin
      AnalyzeFinallyBlock(MethodIdx, Methods[MethodIdx].ExcTable[I].HandlerPC, I);
    End Else Begin
      AnalyzeCatchBlock(MethodIdx, Methods[MethodIdx].ExcTable[I].HandlerPC, 
                        CatchType, I);
    End;
  End;
  
  { Detecter equals() sans super.equals() }
  DetectEqualsNoSuper(MethodIdx);
  
  { Detecter les null check redondants }
  DetectRedundantNullCheck(MethodIdx);
End;

{ --- TODO 17 : Analyser une methode pour les problemes d'exception --- }
Procedure AnalyzeMethodForExceptions(MethodIdx: Integer);
Var
  OldPC: LongWord;
  OldLine: Integer;
Begin
  If (MethodIdx < 0) or (MethodIdx >= MethodCount) Then Exit;
  If Methods[MethodIdx].CodeLen = 0 Then Exit; { Methode abstraite ou native }
  
  { Sauvegarder l'etat courant }
  OldPC := EXCurrentPC;
  OldLine := EXCurrentLine;
  
  { Decoder les instructions si pas deja fait }
  If (Instructions = nil) or (InstrCount = 0) Then Begin
    AllocInstructions;
    DecodeInstructions(Methods[MethodIdx]);
  End;
  
  { Mettre a jour le nom de methode dans les bugs }
  { Lancer la detection }
  DetectExceptionHandlingIssues(MethodIdx);
  
  { Restaurer l'etat }
  EXCurrentPC := OldPC;
  EXCurrentLine := OldLine;
End;

{ --- TODO 17 : Analyser toutes les methodes d'une classe --- }
Procedure DetectAllExceptionIssues;
Var
  I: Integer;
Begin
  InitExHandlingState;
  
  { Analyser toutes les methodes }
  For I := 0 to MethodCount - 1 Do Begin
    AnalyzeMethodForExceptions(I);
  End;
End;

{ --- TODO 17 : Afficher l'etat du module d'exceptions masquees --- }
Procedure DumpExHandlingState;
Var
  I: Integer;
Begin
  WriteLn('=== Etat du module de detection d''exceptions masquees ===');
  WriteLn('Initialise         : ', EXInitialized);
  WriteLn('Bugs detectes      : ', EXBugCount);
  WriteLn('Catch blocks       : ', EXCatchCount);
  WriteLn('Finally blocks     : ', EXFinallyCount);
  WriteLn('Total ignores      : ', EXTotalIgnored);
  WriteLn('Total trop larges  : ', EXTotalTooWide);
  WriteLn('Total finally ret  : ', EXTotalFinallyReturn);
  WriteLn('Total null redond  : ', EXTotalRedundantNull);
  WriteLn('Total pop only     : ', EXTotalPopOnly);
  WriteLn('Total no super eq  : ', EXTotalNoSuperEquals);
  WriteLn;
  
  If EXBugCount > 0 Then Begin
    WriteLn('--- Bugs d''exceptions detectes ---');
    For I := 0 to EXBugCount - 1 Do Begin
      WriteLn(I + 1, '. ', EXBugTypeName(EXBugs[I].BugType));
      WriteLn('   Classe  : ', EXBugs[I].ClassName);
      WriteLn('   Methode : ', EXBugs[I].MethodName);
      If EXBugs[I].CatchType <> '' Then
        WriteLn('   Catch   : ', EXBugs[I].CatchType);
      WriteLn('   Ligne   : ', EXBugs[I].LineNum);
      WriteLn('   Details : ', EXBugs[I].Details);
      WriteLn;
    End;
  End;
End;

{ --- TODO 17 : Accesseurs pour le module d'exceptions masquees --- }
Function GetEXInitialized: Boolean;
Begin
  GetEXInitialized := EXInitialized;
End;

Function GetEXBugCount: Integer;
Begin
  GetEXBugCount := EXBugCount;
End;

Function GetEXCatchCount: Integer;
Begin
  GetEXCatchCount := EXCatchCount;
End;

Function GetEXFinallyCount: Integer;
Begin
  GetEXFinallyCount := EXFinallyCount;
End;

Function GetEXTotalIgnored: Integer;
Begin
  GetEXTotalIgnored := EXTotalIgnored;
End;

Function GetEXTotalTooWide: Integer;
Begin
  GetEXTotalTooWide := EXTotalTooWide;
End;

Function GetEXTotalFinallyReturn: Integer;
Begin
  GetEXTotalFinallyReturn := EXTotalFinallyReturn;
End;

Function GetEXTotalRedundantNull: Integer;
Begin
  GetEXTotalRedundantNull := EXTotalRedundantNull;
End;

Function GetEXTotalPopOnly: Integer;
Begin
  GetEXTotalPopOnly := EXTotalPopOnly;
End;

Function GetEXTotalNoSuperEquals: Integer;
Begin
  GetEXTotalNoSuperEquals := EXTotalNoSuperEquals;
End;

Function GetEXBugType(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < EXBugCount) Then
    GetEXBugType := EXBugs[Idx].BugType
  Else
    GetEXBugType := EXH_NONE;
End;

Function GetEXBugPC(Idx: Integer): LongWord;
Begin
  If (Idx >= 0) and (Idx < EXBugCount) Then
    GetEXBugPC := EXBugs[Idx].PC
  Else
    GetEXBugPC := 0;
End;

Function GetEXBugLine(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < EXBugCount) Then
    GetEXBugLine := EXBugs[Idx].LineNum
  Else
    GetEXBugLine := 0;
End;

{ ============================================================================ }
{ TODO 18 [IMPLEMENTE] - Detecteur : erreurs logiques et retours incorrects    }
{ ============================================================================ }

{ --- TODO 18 : Initialisation du module erreurs logiques --- }
Procedure InitLogicState;
Var
  I: Integer;
Begin
  LEInitialized := True;
  LEBugCount := 0;
  LEShadowCount := 0;
  LESelfCount := 0;
  LELabelNum := 0;
  LETotalSelfField := 0;
  LETotalSelfLocal := 0;
  LETotalRetIgnored := 0;
  LETotalBadCompare := 0;
  LETotalOverflow := 0;
  LETotalMasking := 0;
  LECurrentPC := 0;
  LECurrentLine := 0;
  LELastLoadVar := -1;
  LELastLoadField := -1;
  LELastLoadPC := 0;
  For I := 0 to MAX_LE_BUGS - 1 Do
  Begin
    LEBugs[I].BugType := LE_NONE;
    LEBugs[I].PC := 0;
    LEBugs[I].LineNum := 0;
    LEBugs[I].ClassName := '';
    LEBugs[I].MethodName := '';
    LEBugs[I].VarName := '';
    LEBugs[I].Details := '';
  End;
  For I := 0 to MAX_LE_SHADOWS - 1 Do
  Begin
    LEShadows[I].LocalIdx := -1;
    LEShadows[I].LocalName := '';
    LEShadows[I].FieldIdx := -1;
    LEShadows[I].FieldName := '';
    LEShadows[I].DeclPC := 0;
    LEShadows[I].LineNum := 0;
  End;
  For I := 0 to MAX_LE_SELF_ASSIGN - 1 Do
  Begin
    LESelfAssigns[I].VarIdx := -1;
    LESelfAssigns[I].FieldRef := -1;
    LESelfAssigns[I].VarName := '';
    LESelfAssigns[I].LoadPC := 0;
    LESelfAssigns[I].StorePC := 0;
    LESelfAssigns[I].IsField := False;
  End;
End;

{ --- TODO 18 : Generation d'un label unique pour le module --- }
Function GenLELabel: String;
Begin
  Inc(LELabelNum);
  GenLELabel := 'LE_' + IntToStr_(LELabelNum);
End;

{ --- TODO 18 : Conversion du type de bug en chaine --- }
Function LEBugTypeName(BugType: Integer): String;
Begin
  Case BugType of
    LE_NONE                             : LEBugTypeName := 'LE_NONE';
    RV_RETURN_VALUE_IGNORED             : LEBugTypeName := 'RV_RETURN_VALUE_IGNORED';
    IM_MULTIPLYING_RESULT_OF_IREM       : LEBugTypeName := 'IM_MULTIPLYING_RESULT_OF_IREM';
    INT_BAD_COMPARISON_WITH_NONNEG_VALUE : LEBugTypeName := 'INT_BAD_COMPARISON_WITH_NONNEG_VALUE';
    IC_INIT_CIRCULARITY                 : LEBugTypeName := 'IC_INIT_CIRCULARITY';
    MF_CLASS_MASKS_FIELD                : LEBugTypeName := 'MF_CLASS_MASKS_FIELD';
    SA_FIELD_SELF_ASSIGNMENT            : LEBugTypeName := 'SA_FIELD_SELF_ASSIGNMENT';
    SA_LOCAL_SELF_ASSIGNMENT            : LEBugTypeName := 'SA_LOCAL_SELF_ASSIGNMENT';
    SA_FIELD_DOUBLE_ASSIGNMENT          : LEBugTypeName := 'SA_FIELD_DOUBLE_ASSIGNMENT';
  Else
    LEBugTypeName := 'LE_UNKNOWN';
  End;
End;

{ --- TODO 18 : Detecter si un opcode est un load de variable locale --- }
Function IsLocalLoadOpcode(Op: Byte): Boolean;
Begin
  Case Op of
    OP_ILOAD, OP_LLOAD, OP_FLOAD, OP_DLOAD, OP_ALOAD,
    OP_ILOAD_0, OP_ILOAD_1, OP_ILOAD_2, OP_ILOAD_3,
    OP_LLOAD_0, OP_LLOAD_1, OP_LLOAD_2, OP_LLOAD_3,
    OP_FLOAD_0, OP_FLOAD_1, OP_FLOAD_2, OP_FLOAD_3,
    OP_DLOAD_0, OP_DLOAD_1, OP_DLOAD_2, OP_DLOAD_3,
    OP_ALOAD_0, OP_ALOAD_1, OP_ALOAD_2, OP_ALOAD_3:
      IsLocalLoadOpcode := True;
  Else
    IsLocalLoadOpcode := False;
  End;
End;

{ --- TODO 18 : Detecter si un opcode est un store de variable locale --- }
Function IsLocalStoreOpcode(Op: Byte): Boolean;
Begin
  Case Op of
    OP_ISTORE, OP_LSTORE, OP_FSTORE, OP_DSTORE, OP_ASTORE,
    OP_ISTORE_0, OP_ISTORE_1, OP_ISTORE_2, OP_ISTORE_3,
    OP_LSTORE_0, OP_LSTORE_1, OP_LSTORE_2, OP_LSTORE_3,
    OP_FSTORE_0, OP_FSTORE_1, OP_FSTORE_2, OP_FSTORE_3,
    OP_DSTORE_0, OP_DSTORE_1, OP_DSTORE_2, OP_DSTORE_3,
    OP_ASTORE_0, OP_ASTORE_1, OP_ASTORE_2, OP_ASTORE_3:
      IsLocalStoreOpcode := True;
  Else
    IsLocalStoreOpcode := False;
  End;
End;

{ --- TODO 18 : Extraire l'index de variable locale d'un opcode load --- }
Function GetLoadVarIndex(Op: Byte; Operand: Integer): Integer;
Begin
  Case Op of
    OP_ILOAD, OP_LLOAD, OP_FLOAD, OP_DLOAD, OP_ALOAD:
      GetLoadVarIndex := Operand;
    OP_ILOAD_0, OP_LLOAD_0, OP_FLOAD_0, OP_DLOAD_0, OP_ALOAD_0:
      GetLoadVarIndex := 0;
    OP_ILOAD_1, OP_LLOAD_1, OP_FLOAD_1, OP_DLOAD_1, OP_ALOAD_1:
      GetLoadVarIndex := 1;
    OP_ILOAD_2, OP_LLOAD_2, OP_FLOAD_2, OP_DLOAD_2, OP_ALOAD_2:
      GetLoadVarIndex := 2;
    OP_ILOAD_3, OP_LLOAD_3, OP_FLOAD_3, OP_DLOAD_3, OP_ALOAD_3:
      GetLoadVarIndex := 3;
  Else
    GetLoadVarIndex := -1;
  End;
End;

{ --- TODO 18 : Extraire l'index de variable locale d'un opcode store --- }
Function GetStoreVarIndex(Op: Byte; Operand: Integer): Integer;
Begin
  Case Op of
    OP_ISTORE, OP_LSTORE, OP_FSTORE, OP_DSTORE, OP_ASTORE:
      GetStoreVarIndex := Operand;
    OP_ISTORE_0, OP_LSTORE_0, OP_FSTORE_0, OP_DSTORE_0, OP_ASTORE_0:
      GetStoreVarIndex := 0;
    OP_ISTORE_1, OP_LSTORE_1, OP_FSTORE_1, OP_DSTORE_1, OP_ASTORE_1:
      GetStoreVarIndex := 1;
    OP_ISTORE_2, OP_LSTORE_2, OP_FSTORE_2, OP_DSTORE_2, OP_ASTORE_2:
      GetStoreVarIndex := 2;
    OP_ISTORE_3, OP_LSTORE_3, OP_FSTORE_3, OP_DSTORE_3, OP_ASTORE_3:
      GetStoreVarIndex := 3;
  Else
    GetStoreVarIndex := -1;
  End;
End;

{ --- TODO 18 : Detecter si un opcode est getfield --- }
Function IsGetFieldOpcode(Op: Byte): Boolean;
Begin
  IsGetFieldOpcode := (Op = OP_GETFIELD);
End;

{ --- TODO 18 : Detecter si un opcode est putfield --- }
Function IsPutFieldOpcode(Op: Byte): Boolean;
Begin
  IsPutFieldOpcode := (Op = OP_PUTFIELD);
End;

{ --- TODO 18 : Detecter si un opcode est irem (modulo) --- }
Function IsModuloOpcode(Op: Byte): Boolean;
Begin
  IsModuloOpcode := (Op = OP_IREM) or (Op = OP_LREM);
End;

{ --- TODO 18 : Detecter si un opcode est une multiplication --- }
Function IsMulOpcode(Op: Byte): Boolean;
Begin
  IsMulOpcode := (Op = OP_IMUL) or (Op = OP_LMUL);
End;

{ --- TODO 18 : Detecter si un opcode est une comparaison iflt/ifge --- }
Function IsCompareNegOpcode(Op: Byte): Boolean;
Begin
  Case Op of
    OP_IFLT, OP_IFGE, OP_IFLE, OP_IFGT:
      IsCompareNegOpcode := True;
  Else
    IsCompareNegOpcode := False;
  End;
End;

{ --- TODO 18 : Detecter si c'est un appel retournant une valeur ignorable --- }
Function IsReturnValueMethod(ClassName, MethodName: String): Boolean;
Begin
  IsReturnValueMethod := False;
  { Methodes String qui retournent une nouvelle String }
  If (ClassName = 'java/lang/String') Then
  Begin
    If (MethodName = 'trim') or (MethodName = 'toLowerCase') or
       (MethodName = 'toUpperCase') or (MethodName = 'replace') or
       (MethodName = 'replaceAll') or (MethodName = 'replaceFirst') or
       (MethodName = 'substring') or (MethodName = 'concat') Then
      IsReturnValueMethod := True;
  End;
  { Methodes StringBuilder/StringBuffer qui retournent this }
  If (ClassName = 'java/lang/StringBuilder') or
     (ClassName = 'java/lang/StringBuffer') Then
  Begin
    If (MethodName = 'append') or (MethodName = 'insert') or
       (MethodName = 'delete') or (MethodName = 'reverse') Then
      IsReturnValueMethod := True;
  End;
  { Methodes Collection }
  If (Pos('Collection', ClassName) > 0) or (Pos('List', ClassName) > 0) or
     (Pos('Set', ClassName) > 0) or (Pos('Map', ClassName) > 0) Then
  Begin
    If (MethodName = 'add') or (MethodName = 'remove') or
       (MethodName = 'contains') Then
      IsReturnValueMethod := True;
  End;
End;

{ --- TODO 18 : Ajouter un bug logique --- }
Procedure AddLogicBug(BugType: Integer; PC: LongWord; LineNum: Integer;
                      ClassName, MethodName, VarName, Details: String);
Begin
  If LEBugCount >= MAX_LE_BUGS Then Exit;
  LEBugs[LEBugCount].BugType := BugType;
  LEBugs[LEBugCount].PC := PC;
  LEBugs[LEBugCount].LineNum := LineNum;
  LEBugs[LEBugCount].ClassName := ClassName;
  LEBugs[LEBugCount].MethodName := MethodName;
  LEBugs[LEBugCount].VarName := VarName;
  LEBugs[LEBugCount].Details := Details;
  Inc(LEBugCount);
  { Mettre a jour les compteurs }
  Case BugType of
    SA_FIELD_SELF_ASSIGNMENT, SA_FIELD_DOUBLE_ASSIGNMENT:
      Inc(LETotalSelfField);
    SA_LOCAL_SELF_ASSIGNMENT:
      Inc(LETotalSelfLocal);
    RV_RETURN_VALUE_IGNORED:
      Inc(LETotalRetIgnored);
    INT_BAD_COMPARISON_WITH_NONNEG_VALUE:
      Inc(LETotalBadCompare);
    IM_MULTIPLYING_RESULT_OF_IREM:
      Inc(LETotalOverflow);
    MF_CLASS_MASKS_FIELD:
      Inc(LETotalMasking);
  End;
End;

{ --- TODO 18 : Trouver un champ par son nom --- }
Function FindFieldByName(Name: String): Integer;
Var
  I: Integer;
Begin
  FindFieldByName := -1;
  For I := 0 to FieldCount - 1 Do
  Begin
    If Fields[I].Name = Name Then
    Begin
      FindFieldByName := I;
      Exit;
    End;
  End;
End;

{ --- TODO 18 : Ajouter un masquage de champ --- }
Procedure AddShadow(LocalIdx: Integer; LocalName: String;
                    FieldIdx: Integer; FieldName: String;
                    DeclPC: LongWord; LineNum: Integer);
Begin
  If LEShadowCount >= MAX_LE_SHADOWS Then Exit;
  LEShadows[LEShadowCount].LocalIdx := LocalIdx;
  LEShadows[LEShadowCount].LocalName := LocalName;
  LEShadows[LEShadowCount].FieldIdx := FieldIdx;
  LEShadows[LEShadowCount].FieldName := FieldName;
  LEShadows[LEShadowCount].DeclPC := DeclPC;
  LEShadows[LEShadowCount].LineNum := LineNum;
  Inc(LEShadowCount);
End;

{ --- TODO 18 : Detecter les self-assignments de variables locales --- }
Procedure DetectLocalSelfAssignment(Var M: TMethodInfo);
Var
  I, J: Integer;
  LoadIdx, StoreIdx: Integer;
  LoadPC: LongWord;
  VarName: String;
  LineNum: Integer;
Begin
  If InstrCount < 2 Then Exit;
  If Instructions = Nil Then Exit;
  For I := 0 to InstrCount - 2 Do
  Begin
    { Pattern: xload N suivi de xstore N }
    If IsLocalLoadOpcode(Instructions^[I].Opcode) and
       IsLocalStoreOpcode(Instructions^[I+1].Opcode) Then
    Begin
      LoadIdx := GetLoadVarIndex(Instructions^[I].Opcode, Instructions^[I].Op1);
      StoreIdx := GetStoreVarIndex(Instructions^[I+1].Opcode, Instructions^[I+1].Op1);
      If (LoadIdx >= 0) and (LoadIdx = StoreIdx) Then
      Begin
        LoadPC := Instructions^[I].PC;
        LineNum := GetLineNumber(M, LoadPC);
        { Trouver le nom de la variable si possible }
        VarName := 'local_' + IntToStr_(LoadIdx);
        If M.LocalCount > 0 Then
        Begin
          For J := 0 to M.LocalCount - 1 Do
          Begin
            If (M.LocalTable[J].Index = LoadIdx) and (M.LocalTable[J].Name <> '') Then
            Begin
              VarName := M.LocalTable[J].Name;
              Break;
            End;
          End;
        End;
        AddLogicBug(SA_LOCAL_SELF_ASSIGNMENT, LoadPC, LineNum,
                   InternalToJavaName(ClassInfo.ThisClass),
                   M.Name, VarName,
                   'Variable locale assignee a elle-meme');
      End;
    End;
  End;
End;

{ --- TODO 18 : Detecter les self-assignments de champs --- }
Procedure DetectFieldSelfAssignment(Var M: TMethodInfo);
Var
  I: Integer;
  GetFieldRef, PutFieldRef: LongInt;
  LoadPC: LongWord;
  FieldName: String;
  LineNum: Integer;
Begin
  If InstrCount < 3 Then Exit;
  If Instructions = Nil Then Exit;
  For I := 0 to InstrCount - 3 Do
  Begin
    { Pattern: aload_0, getfield F, putfield F }
    If (Instructions^[I].Opcode = OP_ALOAD_0) and
       (Instructions^[I+1].Opcode = OP_GETFIELD) and
       (Instructions^[I+2].Opcode = OP_PUTFIELD) Then
    Begin
      GetFieldRef := Instructions^[I+1].Op1;
      PutFieldRef := Instructions^[I+2].Op1;
      If GetFieldRef = PutFieldRef Then
      Begin
        LoadPC := Instructions^[I].PC;
        LineNum := GetLineNumber(M, LoadPC);
        FieldName := Instructions^[I+1].CpRef;
        AddLogicBug(SA_FIELD_SELF_ASSIGNMENT, LoadPC, LineNum,
                   InternalToJavaName(ClassInfo.ThisClass),
                   M.Name, FieldName,
                   'Champ assigne a lui-meme (this.f = this.f)');
      End;
    End;
    { Pattern plus simple: aload_0, getfield F, aload_0, putfield F }
    If (I < InstrCount - 4) Then
    Begin
      If (Instructions^[I].Opcode = OP_ALOAD_0) and
         (Instructions^[I+1].Opcode = OP_GETFIELD) and
         (Instructions^[I+2].Opcode = OP_ALOAD_0) and
         (Instructions^[I+3].Opcode = OP_PUTFIELD) Then
      Begin
        GetFieldRef := Instructions^[I+1].Op1;
        PutFieldRef := Instructions^[I+3].Op1;
        If GetFieldRef = PutFieldRef Then
        Begin
          LoadPC := Instructions^[I].PC;
          LineNum := GetLineNumber(M, LoadPC);
          FieldName := Instructions^[I+1].CpRef;
          AddLogicBug(SA_FIELD_SELF_ASSIGNMENT, LoadPC, LineNum,
                     InternalToJavaName(ClassInfo.ThisClass),
                     M.Name, FieldName,
                     'Champ assigne a lui-meme (this.f = this.f)');
        End;
      End;
    End;
  End;
End;

{ --- TODO 18 : Detecter multiplication apres modulo (debordement) --- }
Procedure DetectOverflowAfterModulo(Var M: TMethodInfo);
Var
  I: Integer;
  ModuloPC: LongWord;
  LineNum: Integer;
Begin
  If InstrCount < 2 Then Exit;
  If Instructions = Nil Then Exit;
  For I := 0 to InstrCount - 2 Do
  Begin
    { Pattern: irem/lrem suivi de imul/lmul }
    If IsModuloOpcode(Instructions^[I].Opcode) and
       IsMulOpcode(Instructions^[I+1].Opcode) Then
    Begin
      ModuloPC := Instructions^[I].PC;
      LineNum := GetLineNumber(M, ModuloPC);
      AddLogicBug(IM_MULTIPLYING_RESULT_OF_IREM, ModuloPC, LineNum,
                 InternalToJavaName(ClassInfo.ThisClass),
                 M.Name, '',
                 'Multiplication du resultat de modulo peut deborder');
    End;
  End;
End;

{ --- TODO 18 : Detecter valeur de retour ignoree --- }
Procedure DetectReturnValueIgnored(Var M: TMethodInfo);
Var
  I: Integer;
  CallPC: LongWord;
  LineNum: Integer;
  CpIdx: Word;
  ClassName, MethodName, Desc: String;
Begin
  If InstrCount < 2 Then Exit;
  If Instructions = Nil Then Exit;
  For I := 0 to InstrCount - 2 Do
  Begin
    { Pattern: invokevirtual/invokeinterface suivi de pop }
    If ((Instructions^[I].Opcode = OP_INVOKEVIRTUAL) or
        (Instructions^[I].Opcode = OP_INVOKEINTERFACE)) and
       (Instructions^[I+1].Opcode = OP_POP) Then
    Begin
      CpIdx := Word(Instructions^[I].Op1);
      CPGetMemberRef(CpIdx, ClassName, MethodName, Desc);
      If IsReturnValueMethod(ClassName, MethodName) Then
      Begin
        CallPC := Instructions^[I].PC;
        LineNum := GetLineNumber(M, CallPC);
        AddLogicBug(RV_RETURN_VALUE_IGNORED, CallPC, LineNum,
                   InternalToJavaName(ClassInfo.ThisClass),
                   M.Name, MethodName,
                   'Valeur de retour de ' + MethodName + ' ignoree');
      End;
    End;
  End;
End;

{ --- TODO 18 : Detecter comparaisons avec valeurs non-negatives --- }
Procedure DetectBadNonNegComparison(Var M: TMethodInfo);
Var
  I: Integer;
  CompPC: LongWord;
  LineNum: Integer;
  PrevOp: Byte;
Begin
  If InstrCount < 2 Then Exit;
  If Instructions = Nil Then Exit;
  For I := 1 to InstrCount - 1 Do
  Begin
    { Pattern: arraylength ou similaire suivi de iflt (toujours false) }
    If IsCompareNegOpcode(Instructions^[I].Opcode) Then
    Begin
      PrevOp := Instructions^[I-1].Opcode;
      { arraylength retourne toujours >= 0 }
      If (PrevOp = OP_ARRAYLENGTH) Then
      Begin
        If (Instructions^[I].Opcode = OP_IFLT) Then
        Begin
          CompPC := Instructions^[I].PC;
          LineNum := GetLineNumber(M, CompPC);
          AddLogicBug(INT_BAD_COMPARISON_WITH_NONNEG_VALUE, CompPC, LineNum,
                     InternalToJavaName(ClassInfo.ThisClass),
                     M.Name, '',
                     'Comparaison < 0 sur longueur de tableau (toujours false)');
        End;
      End;
      { iushr retourne toujours >= 0 pour valeurs non-negatives }
      If (PrevOp = OP_IUSHR) or (PrevOp = OP_LUSHR) Then
      Begin
        If (Instructions^[I].Opcode = OP_IFLT) Then
        Begin
          CompPC := Instructions^[I].PC;
          LineNum := GetLineNumber(M, CompPC);
          AddLogicBug(INT_BAD_COMPARISON_WITH_NONNEG_VALUE, CompPC, LineNum,
                     InternalToJavaName(ClassInfo.ThisClass),
                     M.Name, '',
                     'Comparaison < 0 sur resultat de decalage non-signe');
        End;
      End;
    End;
  End;
End;

{ --- TODO 18 : Detecter variables locales masquant des champs --- }
Procedure DetectFieldMasking(Var M: TMethodInfo);
Var
  I: Integer;
  LocalName: String;
  FieldIdx: Integer;
  DeclPC: LongWord;
  LineNum: Integer;
Begin
  { Parcourir les variables locales de la methode }
  If M.LocalCount = 0 Then Exit;
  For I := 0 to M.LocalCount - 1 Do
  Begin
    LocalName := M.LocalTable[I].Name;
    If LocalName = '' Then Continue;
    If LocalName = 'this' Then Continue;  { Ignorer 'this' }
    { Verifier si ce nom correspond a un champ de la classe }
    FieldIdx := FindFieldByName(LocalName);
    If FieldIdx >= 0 Then
    Begin
      { La variable locale masque un champ }
      DeclPC := M.LocalTable[I].StartPC;
      LineNum := GetLineNumber(M, DeclPC);
      AddShadow(I, LocalName, FieldIdx, Fields[FieldIdx].Name,
                DeclPC, LineNum);
      AddLogicBug(MF_CLASS_MASKS_FIELD, DeclPC, LineNum,
                 InternalToJavaName(ClassInfo.ThisClass),
                 M.Name, LocalName,
                 'Variable locale "' + LocalName + '" masque le champ de meme nom');
    End;
  End;
End;

{ --- TODO 18 : Detecter double assignation d'un champ --- }
Procedure DetectFieldDoubleAssignment(Var M: TMethodInfo);
Var
  I: Integer;
  FirstPutRef, SecondPutRef: LongInt;
  PutPC: LongWord;
  LineNum: Integer;
  FieldName: String;
Begin
  If InstrCount < 4 Then Exit;
  If Instructions = Nil Then Exit;
  For I := 0 to InstrCount - 4 Do
  Begin
    { Pattern: ..., putfield F, ..., putfield F }
    If (Instructions^[I].Opcode = OP_PUTFIELD) and
       (Instructions^[I+2].Opcode = OP_PUTFIELD) Then
    Begin
      FirstPutRef := Instructions^[I].Op1;
      SecondPutRef := Instructions^[I+2].Op1;
      If FirstPutRef = SecondPutRef Then
      Begin
        PutPC := Instructions^[I+2].PC;
        LineNum := GetLineNumber(M, PutPC);
        FieldName := Instructions^[I].CpRef;
        AddLogicBug(SA_FIELD_DOUBLE_ASSIGNMENT, PutPC, LineNum,
                   InternalToJavaName(ClassInfo.ThisClass),
                   M.Name, FieldName,
                   'Champ "' + FieldName + '" assigne deux fois de suite');
      End;
    End;
  End;
End;

{ --- TODO 18 : Detecter les erreurs logiques dans une methode --- }
Procedure DetectLogicErrors(Var M: TMethodInfo);
Begin
  If Not LEInitialized Then InitLogicState;
  { Decoder les instructions si pas deja fait }
  If InstrCount = 0 Then
  Begin
    DecodeInstructions(M);
  End;
  { Detecter les differents types d'erreurs }
  DetectLocalSelfAssignment(M);
  DetectFieldSelfAssignment(M);
  DetectOverflowAfterModulo(M);
  DetectReturnValueIgnored(M);
  DetectBadNonNegComparison(M);
  DetectFieldMasking(M);
  DetectFieldDoubleAssignment(M);
End;

{ --- TODO 18 : Analyser une methode pour les erreurs logiques --- }
Procedure AnalyzeMethodForLogicErrors(MethIdx: Integer);
Begin
  If (MethIdx < 0) or (MethIdx >= MethodCount) Then Exit;
  If Methods[MethIdx].CodeLen = 0 Then Exit;  { Methode abstraite ou native }
  If Not LEInitialized Then InitLogicState;
  { Reinitialiser pour cette methode }
  LEBugCount := 0;
  LEShadowCount := 0;
  LESelfCount := 0;
  LELastLoadVar := -1;
  LELastLoadField := -1;
  LELastLoadPC := 0;
  DetectLogicErrors(Methods[MethIdx]);
End;

{ --- TODO 18 : Analyser toutes les methodes d'une classe --- }
Procedure DetectLogicErrorsInClass;
Var
  I: Integer;
Begin
  If Not LEInitialized Then InitLogicState;
  For I := 0 to MethodCount - 1 Do
  Begin
    AnalyzeMethodForLogicErrors(I);
  End;
End;

{ --- TODO 18 : Afficher l'etat du module d'erreurs logiques --- }
Procedure DumpLogicState;
Var
  I: Integer;
Begin
  WriteLn('=== Etat du module Logic Errors ===');
  WriteLn('Initialise      : ', LEInitialized);
  WriteLn('Bugs detectes   : ', LEBugCount);
  WriteLn('Shadows detectes: ', LEShadowCount);
  WriteLn('Self-assigns    : ', LESelfCount);
  WriteLn('Total self-field: ', LETotalSelfField);
  WriteLn('Total self-local: ', LETotalSelfLocal);
  WriteLn('Total ret ignor : ', LETotalRetIgnored);
  WriteLn('Total bad comp  : ', LETotalBadCompare);
  WriteLn('Total overflow  : ', LETotalOverflow);
  WriteLn('Total masking   : ', LETotalMasking);
  WriteLn;
  If LEBugCount > 0 Then
  Begin
    WriteLn('Bugs :');
    For I := 0 to LEBugCount - 1 Do
    Begin
      WriteLn('  [', I, '] ', LEBugTypeName(LEBugs[I].BugType),
              ' PC=', LEBugs[I].PC, ' Line=', LEBugs[I].LineNum);
      WriteLn('       Class=', LEBugs[I].ClassName,
              ' Method=', LEBugs[I].MethodName);
      WriteLn('       Var=', LEBugs[I].VarName);
      WriteLn('       Details: ', LEBugs[I].Details);
    End;
  End;
  If LEShadowCount > 0 Then
  Begin
    WriteLn('Shadows :');
    For I := 0 to LEShadowCount - 1 Do
    Begin
      WriteLn('  [', I, '] Local "', LEShadows[I].LocalName,
              '" masque champ "', LEShadows[I].FieldName, '"');
    End;
  End;
End;

{ --- TODO 18 : Accesseurs pour le module d'erreurs logiques --- }
Function GetLEInitialized: Boolean;
Begin
  GetLEInitialized := LEInitialized;
End;

Function GetLEBugCount: Integer;
Begin
  GetLEBugCount := LEBugCount;
End;

Function GetLEShadowCount: Integer;
Begin
  GetLEShadowCount := LEShadowCount;
End;

Function GetLETotalSelfField: Integer;
Begin
  GetLETotalSelfField := LETotalSelfField;
End;

Function GetLETotalSelfLocal: Integer;
Begin
  GetLETotalSelfLocal := LETotalSelfLocal;
End;

Function GetLETotalRetIgnored: Integer;
Begin
  GetLETotalRetIgnored := LETotalRetIgnored;
End;

Function GetLETotalBadCompare: Integer;
Begin
  GetLETotalBadCompare := LETotalBadCompare;
End;

Function GetLETotalOverflow: Integer;
Begin
  GetLETotalOverflow := LETotalOverflow;
End;

Function GetLETotalMasking: Integer;
Begin
  GetLETotalMasking := LETotalMasking;
End;

Function GetLEBugType(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < LEBugCount) Then
    GetLEBugType := LEBugs[Idx].BugType
  Else
    GetLEBugType := LE_NONE;
End;

Function GetLEBugPC(Idx: Integer): LongWord;
Begin
  If (Idx >= 0) and (Idx < LEBugCount) Then
    GetLEBugPC := LEBugs[Idx].PC
  Else
    GetLEBugPC := 0;
End;

Function GetLEBugLine(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < LEBugCount) Then
    GetLEBugLine := LEBugs[Idx].LineNum
  Else
    GetLEBugLine := 0;
End;

{ ============================================================================ }
{ TODO 19 [IMPLEMENTE] - Detecteur : problemes d'internationalisation          }
{ ============================================================================ }

{ --- TODO 19 : Initialisation du module d'internationalisation --- }
Procedure InitI18NState;
Var
  I: Integer;
Begin
  I18NInitialized := True;
  I18NBugCount := 0;
  I18NCallCount := 0;
  I18NLabelNum := 0;
  I18NTotalGetBytes := 0;
  I18NTotalCaseConv := 0;
  I18NTotalNewString := 0;
  I18NTotalBoxing := 0;
  I18NTotalFormat := 0;
  I18NTotalStringCtor := 0;
  I18NCurrentPC := 0;
  I18NCurrentLine := 0;
  For I := 0 to MAX_I18N_BUGS - 1 do
  Begin
    I18NBugs[I].BugType := IN_NONE;
    I18NBugs[I].PC := 0;
    I18NBugs[I].LineNum := 0;
    I18NBugs[I].ClassName := '';
    I18NBugs[I].MethodName := '';
    I18NBugs[I].CallName := '';
    I18NBugs[I].Details := '';
  End;
  For I := 0 to MAX_I18N_CALLS - 1 do
  Begin
    I18NCalls[I].CallType := IC_CAT_NONE;
    I18NCalls[I].PC := 0;
    I18NCalls[I].LineNum := 0;
    I18NCalls[I].ClassName := '';
    I18NCalls[I].MethodName := '';
    I18NCalls[I].Descriptor := '';
    I18NCalls[I].HasLocale := False;
    I18NCalls[I].HasCharset := False;
  End;
End;

{ --- TODO 19 : Generation d'un label unique pour le module --- }
Function GenI18NLabel: String;
Begin
  Inc(I18NLabelNum);
  GenI18NLabel := '@I18N_' + IntToStr_(I18NLabelNum);
End;

{ --- TODO 19 : Conversion du type de bug en chaine --- }
Function I18NBugTypeName(BugType: Integer): String;
Begin
  Case BugType of
    IN_NONE:                        I18NBugTypeName := 'IN_NONE';
    DM_DEFAULT_ENCODING:            I18NBugTypeName := 'DM_DEFAULT_ENCODING';
    DM_STRING_CTOR:                 I18NBugTypeName := 'DM_STRING_CTOR';
    DM_CONVERT_CASE:                I18NBugTypeName := 'DM_CONVERT_CASE';
    DM_BOXED_PRIMITIVE_FOR_COMPARE: I18NBugTypeName := 'DM_BOXED_PRIMITIVE_FOR_COMPARE';
    DM_FP_NUMBER_CTOR:              I18NBugTypeName := 'DM_FP_NUMBER_CTOR';
    DM_NUMBER_CTOR:                 I18NBugTypeName := 'DM_NUMBER_CTOR';
    DM_STRING_FORMAT_NO_LOCALE:     I18NBugTypeName := 'DM_STRING_FORMAT_NO_LOCALE';
    DM_NEW_STRING_BYTES_NO_CHARSET: I18NBugTypeName := 'DM_NEW_STRING_BYTES_NO_CHARSET';
  Else
    I18NBugTypeName := 'I18N_UNKNOWN';
  End;
End;

{ --- TODO 19 : Conversion de la categorie d'appel en chaine --- }
Function I18NCallTypeName(CallType: Integer): String;
Begin
  Case CallType of
    IC_CAT_NONE:      I18NCallTypeName := 'NONE';
    IC_CAT_GETBYTES:  I18NCallTypeName := 'GETBYTES';
    IC_CAT_CASE_CONV: I18NCallTypeName := 'CASE_CONV';
    IC_CAT_NEW_STRING: I18NCallTypeName := 'NEW_STRING';
    IC_CAT_BOXING:    I18NCallTypeName := 'BOXING';
    IC_CAT_FORMAT:    I18NCallTypeName := 'FORMAT';
  Else
    I18NCallTypeName := 'UNKNOWN';
  End;
End;

{ --- TODO 19 : Detecter si c'est un appel String.getBytes() sans charset --- }
Function IsStringGetBytesNoArg(ClsName, MethName, Desc: String): Boolean;
Begin
  IsStringGetBytesNoArg := False;
  { String.getBytes() retourne [B (byte array) }
  If (Pos('java/lang/String', ClsName) > 0) or
     (Pos('String', ClsName) > 0) Then
  Begin
    If (MethName = 'getBytes') Then
    Begin
      { getBytes() sans argument : descriptor = ()[B }
      If (Desc = '()[B') Then
        IsStringGetBytesNoArg := True;
    End;
  End;
End;

{ --- TODO 19 : Detecter si c'est un appel toUpperCase/toLowerCase sans Locale --- }
Function IsStringCaseConvertNoLocale(ClsName, MethName, Desc: String): Boolean;
Begin
  IsStringCaseConvertNoLocale := False;
  If (Pos('java/lang/String', ClsName) > 0) or
     (Pos('String', ClsName) > 0) Then
  Begin
    { toUpperCase() ou toLowerCase() sans Locale }
    If (MethName = 'toUpperCase') or (MethName = 'toLowerCase') Then
    Begin
      { Version sans argument : ()Ljava/lang/String; }
      If (Desc = '()Ljava/lang/String;') Then
        IsStringCaseConvertNoLocale := True;
    End;
  End;
End;

{ --- TODO 19 : Detecter si c'est un new String(bytes) sans charset --- }
Function IsNewStringBytesNoCharset(ClsName, MethName, Desc: String): Boolean;
Begin
  IsNewStringBytesNoCharset := False;
  If (Pos('java/lang/String', ClsName) > 0) or
     (Pos('String', ClsName) > 0) Then
  Begin
    If (MethName = '<init>') Then
    Begin
      { new String([B) sans charset : descriptor = ([B)V }
      If (Desc = '([B)V') Then
        IsNewStringBytesNoCharset := True;
      { new String([BII) sans charset : descriptor = ([BII)V }
      If (Desc = '([BII)V') Then
        IsNewStringBytesNoCharset := True;
    End;
  End;
End;

{ --- TODO 19 : Detecter si c'est un new String(String) inutile --- }
Function IsNewStringFromString(ClsName, MethName, Desc: String): Boolean;
Begin
  IsNewStringFromString := False;
  If (Pos('java/lang/String', ClsName) > 0) or
     (Pos('String', ClsName) > 0) Then
  Begin
    If (MethName = '<init>') Then
    Begin
      { new String(String) inutile : descriptor = (Ljava/lang/String;)V }
      If (Desc = '(Ljava/lang/String;)V') Then
        IsNewStringFromString := True;
    End;
  End;
End;

{ --- TODO 19 : Detecter si c'est un constructeur de primitive wrapper --- }
Function IsPrimitiveBoxingCtor(ClsName, MethName, Desc: String): Boolean;
Begin
  IsPrimitiveBoxingCtor := False;
  If (MethName = '<init>') Then
  Begin
    { new Integer(int) : (I)V }
    If ((Pos('java/lang/Integer', ClsName) > 0) or (ClsName = 'Integer')) and
       (Desc = '(I)V') Then
      IsPrimitiveBoxingCtor := True;
    { new Long(long) : (J)V }
    If ((Pos('java/lang/Long', ClsName) > 0) or (ClsName = 'Long')) and
       (Desc = '(J)V') Then
      IsPrimitiveBoxingCtor := True;
    { new Short(short) : (S)V }
    If ((Pos('java/lang/Short', ClsName) > 0) or (ClsName = 'Short')) and
       (Desc = '(S)V') Then
      IsPrimitiveBoxingCtor := True;
    { new Byte(byte) : (B)V }
    If ((Pos('java/lang/Byte', ClsName) > 0) or (ClsName = 'Byte')) and
       (Desc = '(B)V') Then
      IsPrimitiveBoxingCtor := True;
    { new Boolean(boolean) : (Z)V }
    If ((Pos('java/lang/Boolean', ClsName) > 0) or (ClsName = 'Boolean')) and
       (Desc = '(Z)V') Then
      IsPrimitiveBoxingCtor := True;
    { new Character(char) : (C)V }
    If ((Pos('java/lang/Character', ClsName) > 0) or (ClsName = 'Character')) and
       (Desc = '(C)V') Then
      IsPrimitiveBoxingCtor := True;
  End;
End;

{ --- TODO 19 : Detecter si c'est un constructeur Double/Float --- }
Function IsFloatPointBoxingCtor(ClsName, MethName, Desc: String): Boolean;
Begin
  IsFloatPointBoxingCtor := False;
  If (MethName = '<init>') Then
  Begin
    { new Double(double) : (D)V }
    If ((Pos('java/lang/Double', ClsName) > 0) or (ClsName = 'Double')) and
       (Desc = '(D)V') Then
      IsFloatPointBoxingCtor := True;
    { new Float(float) : (F)V }
    If ((Pos('java/lang/Float', ClsName) > 0) or (ClsName = 'Float')) and
       (Desc = '(F)V') Then
      IsFloatPointBoxingCtor := True;
  End;
End;

{ --- TODO 19 : Detecter si c'est un String.format sans Locale --- }
Function IsStringFormatNoLocale(ClsName, MethName, Desc: String): Boolean;
Begin
  IsStringFormatNoLocale := False;
  If (Pos('java/lang/String', ClsName) > 0) or
     (Pos('String', ClsName) > 0) Then
  Begin
    If (MethName = 'format') Then
    Begin
      { String.format(String, Object...) : (Ljava/lang/String;[Ljava/lang/Object;)Ljava/lang/String; }
      If (Pos('Ljava/util/Locale;', Desc) = 0) and
         (Pos('Ljava/lang/String;', Desc) > 0) Then
        IsStringFormatNoLocale := True;
    End;
  End;
End;

{ --- TODO 19 : Ajouter un bug d'internationalisation --- }
Procedure AddI18NBug(BugType: Integer; PC: LongWord; LineNum: Integer;
                     ClsName, MethName, CallName, Details: String);
Begin
  If I18NBugCount < MAX_I18N_BUGS Then
  Begin
    I18NBugs[I18NBugCount].BugType := BugType;
    I18NBugs[I18NBugCount].PC := PC;
    I18NBugs[I18NBugCount].LineNum := LineNum;
    I18NBugs[I18NBugCount].ClassName := ClsName;
    I18NBugs[I18NBugCount].MethodName := MethName;
    I18NBugs[I18NBugCount].CallName := CallName;
    I18NBugs[I18NBugCount].Details := Details;
    Inc(I18NBugCount);
    { Mettre a jour les compteurs par type }
    Case BugType of
      DM_DEFAULT_ENCODING:            Inc(I18NTotalGetBytes);
      DM_CONVERT_CASE:                Inc(I18NTotalCaseConv);
      DM_NEW_STRING_BYTES_NO_CHARSET: Inc(I18NTotalNewString);
      DM_NUMBER_CTOR,
      DM_BOXED_PRIMITIVE_FOR_COMPARE: Inc(I18NTotalBoxing);
      DM_FP_NUMBER_CTOR:              Inc(I18NTotalBoxing);
      DM_STRING_FORMAT_NO_LOCALE:     Inc(I18NTotalFormat);
      DM_STRING_CTOR:                 Inc(I18NTotalStringCtor);
    End;
  End;
End;

{ --- TODO 19 : Tracker un appel i18n --- }
Procedure TrackI18NCall(CallType: Integer; PC: LongWord; LineNum: Integer;
                        ClsName, MethName, Desc: String;
                        HasLocale, HasCharset: Boolean);
Begin
  If I18NCallCount < MAX_I18N_CALLS Then
  Begin
    I18NCalls[I18NCallCount].CallType := CallType;
    I18NCalls[I18NCallCount].PC := PC;
    I18NCalls[I18NCallCount].LineNum := LineNum;
    I18NCalls[I18NCallCount].ClassName := ClsName;
    I18NCalls[I18NCallCount].MethodName := MethName;
    I18NCalls[I18NCallCount].Descriptor := Desc;
    I18NCalls[I18NCallCount].HasLocale := HasLocale;
    I18NCalls[I18NCallCount].HasCharset := HasCharset;
    Inc(I18NCallCount);
  End;
End;

{ --- TODO 19 : Extraire classe et methode d'un methodref CP --- }
Procedure GetMethodRefInfo(CPIdx: Integer; Var ClsName, MethName, Desc: String);
Var
  ClassIdx, NATIdx: Integer;
  NameIdx, DescIdx: Integer;
Begin
  ClsName := '';
  MethName := '';
  Desc := '';
  If (CP = Nil) or (CPIdx < 1) or (CPIdx >= CPCount) Then Exit;
  
  { Tag 10 = Methodref, Tag 11 = InterfaceMethodref }
  If (CP^[CPIdx].Tag = 10) or (CP^[CPIdx].Tag = 11) Then
  Begin
    ClassIdx := CP^[CPIdx].Ref1;
    NATIdx := CP^[CPIdx].Ref2;
    
    { Obtenir le nom de la classe }
    If (ClassIdx >= 1) and (ClassIdx < CPCount) Then
    Begin
      If CP^[ClassIdx].Tag = 7 Then { Class }
      Begin
        NameIdx := CP^[ClassIdx].Ref1;
        If (NameIdx >= 1) and (NameIdx < CPCount) Then
          If CP^[NameIdx].Tag = 1 Then { UTF8 }
            ClsName := CP^[NameIdx].StrVal;
      End;
    End;
    
    { Obtenir le nom et descripteur de la methode }
    If (NATIdx >= 1) and (NATIdx < CPCount) Then
    Begin
      If CP^[NATIdx].Tag = 12 Then { NameAndType }
      Begin
        NameIdx := CP^[NATIdx].Ref1;
        DescIdx := CP^[NATIdx].Ref2;
        If (NameIdx >= 1) and (NameIdx < CPCount) Then
          If CP^[NameIdx].Tag = 1 Then
            MethName := CP^[NameIdx].StrVal;
        If (DescIdx >= 1) and (DescIdx < CPCount) Then
          If CP^[DescIdx].Tag = 1 Then
            Desc := CP^[DescIdx].StrVal;
      End;
    End;
  End;
End;

{ --- TODO 19 : Extraire la classe d'un new (OP_NEW = 187) --- }
Function GetNewClassName(CPIdx: Integer): String;
Var
  NameIdx: Integer;
Begin
  GetNewClassName := '';
  If (CP = Nil) or (CPIdx < 1) or (CPIdx >= CPCount) Then Exit;
  
  { Tag 7 = Class }
  If CP^[CPIdx].Tag = 7 Then
  Begin
    NameIdx := CP^[CPIdx].Ref1;
    If (NameIdx >= 1) and (NameIdx < CPCount) Then
      If CP^[NameIdx].Tag = 1 Then
        GetNewClassName := CP^[NameIdx].StrVal;
  End;
End;

{ --- TODO 19 : Detecter les problemes d'internationalisation dans le bytecode --- }
Procedure DetectI18NIssues(MethIdx: Integer);
Var
  I: Integer;
  Opcode: Byte;
  PC: LongWord;
  LineNum: Integer;
  CPIdx: Integer;
  ClsName, MethName, Desc: String;
  LastNewClass: String;
  LastNewPC: LongWord;
  LastNewLine: Integer;
Begin
  If Instructions = Nil Then Exit;
  If InstrCount = 0 Then Exit;
  
  LastNewClass := '';
  LastNewPC := 0;
  LastNewLine := 0;
  
  For I := 0 to InstrCount - 1 do
  Begin
    Opcode := Instructions^[I].Opcode;
    PC := Instructions^[I].PC;
    LineNum := Instructions^[I].LineNum;
    I18NCurrentPC := PC;
    I18NCurrentLine := LineNum;
    
    { Tracker les OP_NEW pour detecter les constructeurs de wrapper }
    If Opcode = OP_NEW Then  { 187 = new }
    Begin
      CPIdx := Instructions^[I].Op1;
      LastNewClass := GetNewClassName(CPIdx);
      LastNewPC := PC;
      LastNewLine := LineNum;
    End;
    
    { Detecter les appels de methodes (invokevirtual, invokespecial, invokestatic) }
    If (Opcode = OP_INVOKEVIRTUAL) or   { 182 }
       (Opcode = OP_INVOKESPECIAL) or   { 183 }
       (Opcode = OP_INVOKESTATIC) or    { 184 }
       (Opcode = OP_INVOKEINTERFACE) Then { 185 }
    Begin
      CPIdx := Instructions^[I].Op1;
      GetMethodRefInfo(CPIdx, ClsName, MethName, Desc);
      
      { String.getBytes() sans charset }
      If IsStringGetBytesNoArg(ClsName, MethName, Desc) Then
      Begin
        AddI18NBug(DM_DEFAULT_ENCODING, PC, LineNum,
                   ClsName, MethName, 'getBytes()',
                   'Appel getBytes() sans charset explicite');
        TrackI18NCall(IC_CAT_GETBYTES, PC, LineNum, ClsName, MethName, Desc,
                      False, False);
      End;
      
      { toUpperCase/toLowerCase sans Locale }
      If IsStringCaseConvertNoLocale(ClsName, MethName, Desc) Then
      Begin
        AddI18NBug(DM_CONVERT_CASE, PC, LineNum,
                   ClsName, MethName, MethName + '()',
                   'Appel ' + MethName + '() sans Locale explicite');
        TrackI18NCall(IC_CAT_CASE_CONV, PC, LineNum, ClsName, MethName, Desc,
                      False, False);
      End;
      
      { new String([B) sans charset }
      If IsNewStringBytesNoCharset(ClsName, MethName, Desc) Then
      Begin
        AddI18NBug(DM_NEW_STRING_BYTES_NO_CHARSET, PC, LineNum,
                   ClsName, MethName, 'new String(byte[])',
                   'Constructeur String(byte[]) sans charset');
        TrackI18NCall(IC_CAT_NEW_STRING, PC, LineNum, ClsName, MethName, Desc,
                      False, False);
      End;
      
      { new String(String) inutile }
      If IsNewStringFromString(ClsName, MethName, Desc) Then
      Begin
        AddI18NBug(DM_STRING_CTOR, PC, LineNum,
                   ClsName, MethName, 'new String(String)',
                   'Constructeur new String(String) inutile');
        TrackI18NCall(IC_CAT_NEW_STRING, PC, LineNum, ClsName, MethName, Desc,
                      False, False);
      End;
      
      { Constructeurs de primitive wrapper (Integer, Long, etc.) }
      If IsPrimitiveBoxingCtor(ClsName, MethName, Desc) Then
      Begin
        AddI18NBug(DM_NUMBER_CTOR, LastNewPC, LastNewLine,
                   LastNewClass, MethName, 'new ' + LastNewClass + '(...)',
                   'Utiliser ' + LastNewClass + '.valueOf() a la place');
        TrackI18NCall(IC_CAT_BOXING, PC, LineNum, ClsName, MethName, Desc,
                      False, False);
      End;
      
      { Constructeurs Double/Float }
      If IsFloatPointBoxingCtor(ClsName, MethName, Desc) Then
      Begin
        AddI18NBug(DM_FP_NUMBER_CTOR, LastNewPC, LastNewLine,
                   LastNewClass, MethName, 'new ' + LastNewClass + '(...)',
                   'Utiliser ' + LastNewClass + '.valueOf() a la place');
        TrackI18NCall(IC_CAT_BOXING, PC, LineNum, ClsName, MethName, Desc,
                      False, False);
      End;
      
      { String.format sans Locale }
      If IsStringFormatNoLocale(ClsName, MethName, Desc) Then
      Begin
        AddI18NBug(DM_STRING_FORMAT_NO_LOCALE, PC, LineNum,
                   ClsName, MethName, 'String.format(...)',
                   'Appel String.format() sans Locale explicite');
        TrackI18NCall(IC_CAT_FORMAT, PC, LineNum, ClsName, MethName, Desc,
                      False, False);
      End;
    End;
  End;
End;

{ --- TODO 19 : Analyser une methode pour les problemes d'internationalisation --- }
Procedure AnalyzeMethodForI18N(MethIdx: Integer);
Begin
  If Not I18NInitialized Then
    InitI18NState;
  
  { Reinitialiser les bugs pour cette methode }
  I18NBugCount := 0;
  I18NCallCount := 0;
  
  { Decoder les instructions si necessaire }
  If (MethIdx >= 0) and (MethIdx < MethodCount) Then
  Begin
    If Methods[MethIdx].CodeLen > 0 Then
    Begin
      DecodeInstructions(Methods[MethIdx]);
      DetectI18NIssues(MethIdx);
    End;
  End;
End;

{ --- TODO 19 : Analyser toutes les methodes d'une classe --- }
Procedure AnalyzeClassForI18N;
Var
  M: Integer;
Begin
  If Not I18NInitialized Then
    InitI18NState;
  
  For M := 0 to MethodCount - 1 do
    AnalyzeMethodForI18N(M);
End;

{ --- TODO 19 : Afficher l'etat du module d'internationalisation --- }
Procedure DumpI18NState;
Var
  I: Integer;
Begin
  WriteLn('=== I18N State ===');
  WriteLn('  Initialized: ', I18NInitialized);
  WriteLn('  Bug count: ', I18NBugCount);
  WriteLn('  Call count: ', I18NCallCount);
  WriteLn('  Label num: ', I18NLabelNum);
  WriteLn('  Totals:');
  WriteLn('    GetBytes no charset: ', I18NTotalGetBytes);
  WriteLn('    Case conv no Locale: ', I18NTotalCaseConv);
  WriteLn('    New String no charset: ', I18NTotalNewString);
  WriteLn('    Boxing ctors: ', I18NTotalBoxing);
  WriteLn('    Format no Locale: ', I18NTotalFormat);
  WriteLn('    String ctor: ', I18NTotalStringCtor);
  If I18NBugCount > 0 Then
  Begin
    WriteLn('  Bugs:');
    For I := 0 to I18NBugCount - 1 do
    Begin
      WriteLn('    [', I, '] ', I18NBugTypeName(I18NBugs[I].BugType),
              ' at PC=', I18NBugs[I].PC,
              ' line=', I18NBugs[I].LineNum);
      WriteLn('        ', I18NBugs[I].CallName, ': ', I18NBugs[I].Details);
    End;
  End;
  If I18NCallCount > 0 Then
  Begin
    WriteLn('  Tracked calls:');
    For I := 0 to I18NCallCount - 1 do
      WriteLn('    [', I, '] ', I18NCallTypeName(I18NCalls[I].CallType),
              ' ', I18NCalls[I].ClassName, '.', I18NCalls[I].MethodName);
  End;
End;

{ --- TODO 19 : Accesseurs pour le module d'internationalisation --- }
Function IsI18NInitialized: Boolean;
Begin
  IsI18NInitialized := I18NInitialized;
End;

Function GetI18NBugCount: Integer;
Begin
  GetI18NBugCount := I18NBugCount;
End;

Function GetI18NCallCount: Integer;
Begin
  GetI18NCallCount := I18NCallCount;
End;

Function GetI18NLabelNum: Integer;
Begin
  GetI18NLabelNum := I18NLabelNum;
End;

Function GetI18NTotalGetBytes: Integer;
Begin
  GetI18NTotalGetBytes := I18NTotalGetBytes;
End;

Function GetI18NTotalCaseConv: Integer;
Begin
  GetI18NTotalCaseConv := I18NTotalCaseConv;
End;

Function GetI18NTotalNewString: Integer;
Begin
  GetI18NTotalNewString := I18NTotalNewString;
End;

Function GetI18NTotalBoxing: Integer;
Begin
  GetI18NTotalBoxing := I18NTotalBoxing;
End;

Function GetI18NTotalFormat: Integer;
Begin
  GetI18NTotalFormat := I18NTotalFormat;
End;

Function GetI18NTotalStringCtor: Integer;
Begin
  GetI18NTotalStringCtor := I18NTotalStringCtor;
End;

Function GetI18NBugType(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < I18NBugCount) Then
    GetI18NBugType := I18NBugs[Idx].BugType
  Else
    GetI18NBugType := IN_NONE;
End;

Function GetI18NBugPC(Idx: Integer): LongWord;
Begin
  If (Idx >= 0) and (Idx < I18NBugCount) Then
    GetI18NBugPC := I18NBugs[Idx].PC
  Else
    GetI18NBugPC := 0;
End;

Function GetI18NBugLine(Idx: Integer): Integer;
Begin
  If (Idx >= 0) and (Idx < I18NBugCount) Then
    GetI18NBugLine := I18NBugs[Idx].LineNum
  Else
    GetI18NBugLine := 0;
End;

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
