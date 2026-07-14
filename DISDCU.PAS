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
  TAG_RESSTR_OLD     = $32;   { '2', Ver<10 }
  TAG_RESSTR_NEW     = $33;   { '3', Ver>=10 }
  TAG_THREADVAR_OLD  = $31;   { '1', Ver<10 }
  TAG_UNITFLAGS      = $96;
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

Function FmtOrd(V: LongInt): TString;
Begin
  If V < 0 Then
    FmtOrd := '-$' + IntToHex(-V, 1)
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

Function DefRange(Const Kind: TString): Integer;
Var
  Lo, Hi: LongInt;
Begin
  Lo := ReadSIndex;
  Hi := ReadSIndex;
  DefRange := RegisterType(FmtOrd(Lo) + '..' + FmtOrd(Hi) +
    ' { ' + Kind + ' }');
End;

Function DefPtr: Integer;
Var
  Target: LongInt;
Begin
  Target := ReadUIndex;
  DefPtr := RegisterType('^' + TypeRefText(Target));
End;

Function DefSet: Integer;
Var
  Base: LongInt;
Begin
  Base := ReadUIndex;
  DefSet := RegisterType('set of ' + TypeRefText(Base));
End;

Function DefFloat: Integer;
Var
  Kind: Byte;
  S: TString;
Begin
  Kind := RB;
  Case Kind Of
    0: S := 'Single';
    1: S := 'Double';
    2: S := 'Extended';
    3: S := 'Comp';
    4: S := 'Currency';
  Else
    S := 'float(kind ' + IntToStr(Kind) + ')';
  End;
  DefFloat := RegisterType(S);
End;

Function DefVoid: Integer;
Begin
  DefVoid := RegisterType('void');
End;

{ ------------------------------------------------------------ }
{ Emission de declarations Delphi lisibles dans le fichier .pas   }
{ de sortie.                                                       }
{ ------------------------------------------------------------ }

Procedure EmitUses(Const UnitName: TString);
Begin
  WriteLn(OutF, '  ', UnitName, ';');
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
{ Traitement d une definition de type NOMMEE (drType/drTypeP) :   }
{ Name (TNameStr) + hDef (TNDX, index vers le type deja           }
{ enregistre juste avant, dans TypeText).                          }
{ ------------------------------------------------------------ }

Procedure ProcessNamedType;
Var
  Name: TString;
  HDef: LongInt;
Begin
  Name := ReadIdentStr;
  HDef := ReadUIndex;
  WriteLn(OutF, '  ', Name, ' = ', TypeRefText(HDef), ';');
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
  Name, ImpName, ImportList: TString;
  HPack, Inf, L1, X: LongInt;
  RTTISz, LVal: LongInt;
  Cnt: Integer;
Begin
  Name := ReadIdentStr;

  If Ver >= 8 Then HPack := ReadUIndex;

  If Ver >= 10 Then
    Inf := ReadUIndex
  Else
    Inf := LongInt(RUL);

  If (Ver = 7) Or ((Ver >= 8) And (TagRq = TAG_DLL)) Then
    L1 := LongInt(RUL);

  If Ver >= 12 Then
    X := ReadUIndex;

  { Liste imbriquee des imports NOMMES (drImpType/drImpTypeDef pour un   }
  { TYPE, drImpVal pour une routine/adresse) - structure et etiquettes     }
  { REELLES confirmees contre le vrai code source DCU32.pas (TUnit.        }
  { ReadUses). drStop2 peut apparaitre entre deux imports (un octet          }
  { supplementaire depuis Ver>=8) sans mettre fin a la liste - on reboucle.    }
  ImportList := '';
  Cnt := 0;
  Repeat
    CurTag := RB;
    Case CurTag Of
      TAG_IMPTYPE, TAG_IMPTYPEDEF:
        Begin
          ImpName := ReadIdentStr;
          If CurTag = TAG_IMPTYPEDEF Then RTTISz := ReadUIndex;
          LVal := LongInt(RUL);
          If Cnt > 0 Then ImportList := ImportList + ', ';
          ImportList := ImportList + 'T:' + ImpName;
          Inc(Cnt);
        End;
      TAG_IMPVAL:
        Begin
          ImpName := ReadIdentStr;
          LVal := LongInt(RUL);
          If Cnt > 0 Then ImportList := ImportList + ', ';
          ImportList := ImportList + 'A:' + ImpName;
          Inc(Cnt);
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

  If ImportList <> '' Then
    EmitUses(Name + '  { ' + ImportList + ' }')
  Else
    EmitUses(Name);

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
  B, B1, Inf: LongInt;
  HDT, Ofs: LongInt;
Begin
  Name := ReadIdentStr;
  B := ReadUIndex;
  If Ver >= 8 Then B1 := ReadUIndex;
  If (B And $40) <> 0 Then Inf := RUL;

  HDT := ReadUIndex;
  Ofs := ReadUIndex;

  EmitVar(Name, HDT, Tag = TAG_SPECVAR);
End;

{ ------------------------------------------------------------ }
{ Traitement d une signature de procedure/fonction (TProcInf) :   }
{ NF (TNameFDecl, comme ci-dessus), B0 (TNDX, drapeaux), Sz (TNDX). }
{ Le corps reel (TProcData - arguments, bloc de code) n est PAS     }
{ decode (portee documentee) : on s arrete sciemment a la              }
{ signature et on emet un corps vide.                                    }
{ ------------------------------------------------------------ }

Procedure ProcessProc(Tag: Byte);
Var
  Name: TString;
  B, B1, Inf: LongInt;
  B0, Sz, X: LongInt;
Begin
  Name := ReadIdentStr;
  B := ReadUIndex;
  If Ver >= 8 Then B1 := ReadUIndex;
  If (B And $40) <> 0 Then Inf := RUL;

  B0 := ReadUIndex;
  Sz := ReadUIndex;
  If Ver >= 14 Then X := RB;

  { La ou s arreterait normalement la lecture de TProcData (corps :  }
  { arguments + bloc de code) - non decodee ici (portee documentee).  }
  Fail('signature de "' + Name + '" lue, mais le corps (TProcData : ' +
    'arguments + bloc de code drCBlock) n est pas encore decode - ' +
    'voir la portee documentee en tete de ce programme');
End;

{ ------------------------------------------------------------ }
{ Dispatcher principal : un enregistrement a la fois.             }
{ ------------------------------------------------------------ }

Procedure ProcessOneRecord;
Var
  Tag: Byte;
Begin
  Tag := CurTag;
  Case Tag Of
    TAG_UNIT, TAG_UNIT1:
      Begin
        { ProcessUsesUnit gere elle-meme CurTag jusqu au bout (liste       }
        { d import de longueur variable, puis eventuel drProcAddInfo) -     }
        { ne PAS laisser le code commun ci-dessous relire une etiquette.      }
        ProcessUsesUnit(Tag);
        Exit;
      End;

    TAG_VAR, TAG_VARC, TAG_ABSVAR, TAG_SPECVAR, TAG_RESSTR_OLD,
    TAG_RESSTR_NEW, TAG_THREADVAR_OLD:
      ProcessVarLike(Tag);

    TAG_CONST:
      { drConst (TConstDef) utilise TConstVal, une structure DIFFERENTE }
      { de TVarInf (Sz:TNDX + Val de taille variable selon Sz) dont      }
      { l encodage exact n est pas confirme (voir portee documentee) -    }
      { la traiter comme TVarInf serait une DEVINETTE : arret propre.       }
      FailUnknownTag(Tag, 'constante (TConstDef/TConstVal non confirme)');

    TAG_PROC, TAG_SYSPROC:
      ProcessProc(Tag);

    TAG_TYPE, TAG_TYPEP:
      ProcessNamedType;

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

    TAG_EXPORT:
      { drExport (TExportInf) : hSym+Index, deux TNDX simples - purement   }
      { une marque de visibilite publique, rien a imprimer de plus.          }
      Begin
        ReadUIndex;
        ReadUIndex;
      End;

    TAG_UNITFLAGS, TAG_UNIT_ADD_INFO, TAG_STRCONSTREC,
    TAG_PROC_ADD_INFO, TAG_CONST_ADD_INFO, TAG_INFO98:
      Fail('etiquette de metadonnees $' + IntToHex(Tag, 2) +
        ' rencontree hors de l en-tete - structure non prise en charge ' +
        'a cet endroit (portee documentee)');

    TAG_RECDEF, TAG_CLASSDEF, TAG_OBJDEF, TAG_OBJVMTDEF, TAG_PROCTYPEDEF,
    TAG_ENUMDEF, TAG_SHORTSTRDEF, TAG_ARRAYDEF, TAG_FILEDEF, TAG_TEXTDEF,
    TAG_STRINGDEF, TAG_VARIANTDEF, TAG_INTERFACEDEF, TAG_WIDESTRDEF,
    TAG_METACLASSDEF, TAG_DYNARRAYDEF, TAG_UNICODESTRDEF:
      FailUnknownTag(Tag, 'definition de type complexe');

    TAG_SRC:
      ProcessSrcInf('source');
    TAG_OBJ:
      ProcessSrcInf('objet');
    TAG_ASM:
      ProcessSrcInf('asm');
    TAG_RES:
      ProcessSrcInf('ressource');

    TAG_DLL, TAG_LABEL:
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
  WriteLn(OutF, '{ ATTENTION : decompilation partielle - voir l entete de ',
    'DISDCU.PAS pour la portee exacte (types complexes et corps de ',
    'routines non decompiles). }');
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

  { Note de portee : les enregistrements ne sont PAS strictement       }
  { groupes par categorie dans le flux reel (confirme empiriquement -   }
  { un enregistrement "source" (drSrc) precede souvent le tout premier    }
  { "uses", et d autres entrelacements sont possibles) - "uses" et         }
  { "interface" sont donc simplement imprimes une fois ici, puis TOUS       }
  { les enregistrements sont traites par une seule boucle ; un drUnit        }
  { rencontre plus tard dans le flux imprime quand meme sa ligne "  Nom;"      }
  { a l endroit ou il apparait (resultat lisible mais pas forcement            }
  { un .pas syntaxiquement ideal - acceptable pour un OUTIL DE LECTURE,          }
  { pas un recompilateur).                                                        }
  WriteLn(OutF, 'uses');
  WriteLn(OutF);
  WriteLn(OutF, 'interface');
  WriteLn(OutF);

  While (Not Stopped) And (CurTag <> TAG_STOP_A) And (CurTag <> TAG_STOP) Do
    ProcessOneRecord;

  If Not Stopped Then
  Begin
    WriteLn(OutF);
    WriteLn(OutF, 'implementation');
    WriteLn(OutF);
    WriteLn(OutF, 'end.');
  End
  Else
    WriteLn(OutF, #10, '{ *** ARRET ICI - voir le message ci-dessus/dans ',
      'la sortie d erreur *** }');

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
