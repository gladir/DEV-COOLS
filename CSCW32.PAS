{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur C# (C Sharp) vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  CSCW32.PAS - Compilateur C# (C Sharp) vers assembleur
  80386 pour Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte toutes les instructions de CSC86.PAS et les exemples
  SAMPLES\CSHARP\*

  CSCW32 est un compilateur C# (C Sharp) ciblant l assembleur
  Intel 80386 pour Windows 32 bits. Il prend en entree des
  fichiers .cs en langage C# (compatible avec le sous-ensemble
  supporte par CSC86.PAS) et produit de l assembleur 80386
  compatible MASM pour Windows 32 bits (PE). Toutes les donnees
  entieres sont 32 bits (int = 4 octets, pointeurs = 4 octets).

  PLAN DE DEVELOPPEMENT - 25 TODOS
  =================================

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [IMPLEMENTE]
            Constantes de base (version, limites des tables).
            Constantes PE/COFF (DOS stub, signature PE, en-tete
              COFF, en-tete optionnel, sections, imports).
            TOptions (SrcFile, OutFile, Verbose, DebugMode,
              Warnings, AsmOutput, ObjOnly).
            ParseArgs : analyser argv (source.cs [sortie.exe]
              [-v] [-d] [-w] [-obj] [-asm]).
            -obj : produire uniquement un fichier .OBJ (COFF).
            -asm : produire egalement un fichier .ASM lisible.
            Par defaut : produire un .EXE (PE Windows 32 bits).
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE.
            Detecter l extension .cs du fichier source.
            Programme principal : validation et appel Run.
            Version, Date, aide en ligne (-h ou /?).
            Utilitaires : IntToStr, StrUpper, ExtractExt,
              ChangeExt, FileExists.

  TODO 02 - LEXEUR (TOKENS C#) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING,
              TK_CHAR, TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT.
            LexInit, LexClose, LexNextToken, LexScanIdent,
              LexScanNumber, LexScanString, LexScanCharLit.
            Sequences d echappement : \n \t \r \0 \\ \" \' \x41.
            Commentaires : // (ligne) et /* ... */ (multi-lignes).
            Mots-cles C# : abstract as base bool break byte case
              catch char class const continue decimal default
              delegate do double else enum event explicit extern
              false finally fixed float for foreach goto if
              implicit in int interface internal is lock long
              namespace new null object operator out override
              params private protected public readonly ref return
              sbyte sealed short sizeof stackalloc static string
              struct switch this throw true try typeof uint ulong
              unchecked unsafe ushort using virtual void volatile
              while.
            Operateurs multi-caracteres : ++ -- += -= *= /= %=
              &= |= ^= <<= >>= == != <= >= && || << >> -> ??.
            Ponctuation : ( ) [ ] { } ; , . : ? ~ ! #.
            Mode debug -d : affichage de chaque token.

  TODO 03 - DIRECTIVES USING ET IMPORTS [IMPLEMENTE]
            using namespace; : declaration d importation.
            using System; : acces aux classes du namespace System.
            Espaces de noms standard integres en built-in
              (pas de fichier externe necessaire) :
              System : Console, Math, String, Array, Object,
                Convert, Environment, Int32, Boolean, Char.
              System.Collections : ArrayList (stub).
              System.IO : File, StreamReader, StreamWriter (stubs).
            Le compilateur reconnait les using et enregistre
              les namespaces actifs pour la resolution de noms.
            Verification des using non utilises (avertissement).

  TODO 04 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..4294967295 (32 bits non signe).
            Entiers hexadecimaux : 0xFF -> valeur 32 bits.
            Suffixes entiers : u/U (unsigned), l/L (long), ul/UL.
            Flottants : 3.14, 1.0e10 (reconnus, tronques en entier).
            Caracteres : 'A' -> valeur ordinale 32 bits.
              Echappement : '\n'=10, '\t'=9, '\r'=13, '\0'=0,
                '\\'=92, '\''=39, '\"'=34, '\x41'=65.
            Chaines : "abc" -> pointeur vers donnees .DATA.
              Label _CSCK_N dans le segment .DATA.
            Chaines verbatim : @"c:\path" (echappement desactive).
            Constantes booleennes : true (1), false (0).
            null : pointeur nul (0).
            Expressions constantes : const int X = 10;.

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
            TSymCat : SC_VAR, SC_PARAM, SC_METHOD, SC_CLASS,
              SC_FIELD, SC_ENUM_VAL, SC_LABEL, SC_STATIC,
              SC_NAMESPACE, SC_CONST.
            TSymRec : Name, MangledName, Cat, TypeIdx, Offset,
              Scope, ScopeId, IsGlobal, IsStatic, IsConst.
            SymAdd, SymFind, SymFindInScope, SymMangle.
            CurScope : compteur de portee imbriquee.
            SymEnterScope / SymLeaveScope : gestion des portees.
            Portees : globale, classe, methode, bloc {}.
            Prefixes de mangling : _CSCV_ (var), _CSCF_ (methode),
              _CSCK_ (chaine const), _CSCRT_ (runtime),
              _CSCL_ (label), _CSCA_ (tableau), _CSCC_ (classe),
              _CSCN_ (namespace), _CSCE_ (enum).
            Methodes standard pre-enregistrees en built-in :
              Console.Write, Console.WriteLine, Console.ReadLine,
              int.Parse, int.ToString, Math.Abs, Math.Max,
              Math.Min, Convert.ToInt32, Convert.ToString.

  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
            TTypeKind : TKP_VOID, TKP_INT (32 bits signe),
              TKP_UINT (32 bits non signe), TKP_LONG (64 bits stub),
              TKP_BOOL (8 bits), TKP_CHAR (16 bits Unicode stub,
              stocke 8 bits ASCII), TKP_BYTE (8 bits non signe),
              TKP_SHORT (16 bits signe), TKP_FLOAT (stub entier),
              TKP_DOUBLE (stub entier), TKP_DECIMAL (stub entier),
              TKP_STRING (pointeur 32 bits), TKP_OBJECT (pointeur),
              TKP_ARRAY, TKP_CLASS, TKP_ENUM.
            TypeTab, TypeInit : enregistrer types primitifs.
            TypeSizeof : void=0, bool=1, byte=1, char=1, short=2,
              int=4, uint=4, long=4, float=4, double=8,
              string=4, object=4, pointeur=4.
            TypeCompatible : verification de compatibilite.
            TypeCoerce : conversions implicites
              (byte->int, short->int, char->int).

  TODO 07 - EMETTEUR DE CODE ASM 80386 [IMPLEMENTE]
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose.
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces).
            EmitComment, EmitBlankLine.
            LabelSeq global (compteur unique _CSCL_NNNNN).
            GenLabel : generer un label unique _CSCL_NNNNN.
            Prefixes 32 bits : _CSCV_ (variable), _CSCF_ (methode),
              _CSCK_ (chaine const), _CSCRT_ (runtime),
              _CSCL_ (label).
            EmitHeader : .386 / .MODEL FLAT, STDCALL
              EXTRN _ExitProcess@4:NEAR
              EXTRN _GetStdHandle@4:NEAR
              EXTRN _WriteFile@20:NEAR
              EXTRN _ReadFile@20:NEAR
              EXTRN _GetProcessHeap@0:NEAR
              EXTRN _HeapAlloc@12:NEAR
              EXTRN _HeapFree@12:NEAR
              .DATA section et .CODE section.
            EmitProlog : PUSH EBP / MOV EBP,ESP / SUB ESP,locals.
            EmitEpilog : MOV ESP,EBP / POP EBP / RET.
            EmitDataSeg : ecrire .DATA avec toutes les entrees.

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
            TDataKind (DK_DWORD/DK_BYTE/DK_STR/DK_ARRAY/DK_ZERO).
            TDataRec (LblName/Kind/IntVal/StrVal/ElemCount).
            DataTab[0..MAX_DATA-1], DataCount.
            DataAdd (generique), DataAddStr (DB "abc",0),
              DataAddDWord (DD val), DataAddByte (DB val),
              DataAddArray (DB n DUP(0)), DataAddZero (DB n DUP(0)).
            DataAddGlobalVar(nom, typeIdx) : cree _CSCV_nom.
            DataAddStaticVar(classe, var, typeIdx) : cree _CSCST_N.
            DataInit : tampons I/O, handles, CRLF.
            EmitDataSeg reecrit pour emettre tout DataTab.
            Run : DataInit, DataTab peuple pour variables statiques.

  TODO 09 - VARIABLES ET DECLARATIONS [IMPLEMENTE]
            Champs statiques de classe : segment .DATA,
              acces par [_CSCV_nom].
            Variables locales : pile EBP, acces [EBP-offset].
            Parametres de methode : [EBP+8+...] (cdecl 32 bits).
            Declaration : type nom [= init];
              int a; int b = 10; bool ok = true; char c = 'A';
            Declarations multiples : int a, b, c;
            Qualificateurs : const, static, readonly.
            Portee de bloc : { int x = 0; ... }.
            Initialisation locale : MOV [EBP-offset], valeur.

  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
            ParsePrimary : literal entier, literal chaine,
              true, false, null, ident, appel de methode.
            Acces variable statique : MOV EAX,[_CSCV_nom].
            Acces variable locale : MOV EAX,[EBP-offset].
            Acces parametre : MOV EAX,[EBP+offset].
            Appel de methode : CALL _CSCF_nom -> EAX.
            Parentheses : (expr) pour forcer la precedence.
            new type[taille] : allocation de tableau.
            Acces tableau : expr[index] ->
              base + index*sizeof(elem).

  TODO 11 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt).
            Arithmetique 32 bits : ADD/SUB/IMUL/IDIV
              pour +, -, *, /.
            Modulo : IDIV -> resultat dans EDX (reste) pour %.
            Decalages : SHL/SHR pour << >>.
            Comparaison : CMP + SETcc pour == != < <= > >=.
            Logique AND : && (court-circuit, JZ vers false).
            Logique OR  : || (court-circuit, JNZ vers true).
            Logique NOT : !expr -> TEST EAX,EAX / SETZ AL / MOVZX.
            Complement bit a bit : ~expr -> NOT EAX.
            ET bit a bit : & -> AND EAX, valeur.
            OU bit a bit : | -> OR EAX, valeur.
            OU exclusif   : ^ -> XOR EAX, valeur.
            Negation unaire : -expr -> NEG EAX.
            Precedence (du plus fort au plus faible) :
              1. () [] . (postfixe)
              2. ++ -- + - ! ~ new typeof sizeof (prefixe/unaire)
              3. * / % (multiplicatif)
              4. + - (additif)
              5. << >> (decalage)
              6. < <= > >= is as (relationnel)
              7. == != (egalite)
              8. & (ET bit a bit)
              9. ^ (OU exclusif)
              10. | (OU bit a bit)
              11. && (ET logique)
              12. || (OU logique)
              13. ?? (null-coalescing)
              14. = += -= *= /= %= &= |= ^= <<= >>= (affectation)

  TODO 12 - AFFECTATIONS ET OPERATEURS COMPOSES
            Affectation simple : var = expr -> MOV [var], EAX.
            Affectation composee += : var += expr -> ADD.
            Affectation composee -= : var -= expr -> SUB.
            Affectation composee *= : var *= expr -> IMUL + MOV.
            Affectation composee /= : var /= expr -> IDIV + MOV.
            Affectation composee %= : var %= expr -> IDIV + MOV EDX.
            Affectation composee &= : var &= expr -> AND.
            Affectation composee |= : var |= expr -> OR.
            Affectation composee ^= : var ^= expr -> XOR.
            Affectation composee <<= : var <<= expr -> SHL.
            Affectation composee >>= : var >>= expr -> SHR.
            Post-increment ++ : val = var; var += 1 -> MOV + INC.
            Post-decrement -- : val = var; var -= 1 -> MOV + DEC.
            Pre-increment ++ : var += 1; val = var -> INC + MOV.
            Pre-decrement -- : var -= 1; val = var -> DEC + MOV.

  TODO 13 - INSTRUCTIONS DE CONTROLE (if / else)
            ParseIfStmt : if (cond) { stmts } [else { stmts }].
            Emission TEST EAX,EAX / JZ pour condition fausse.
            Labels : _CSCL_ELSE_N, _CSCL_ENDIF_N.
            if imbriques : else if (cond) { stmts } ...
            ParseCompoundStmt : { stmt; stmt; ... }.
            Bloc d instructions avec portee locale.
            SymEnterScope / SymLeaveScope pour variables de bloc.

  TODO 14 - BOUCLES (for / while / do-while)
            ParseForStmt :
              for (init; cond; incr) { stmts }.
              Trois expressions optionnelles separees par ;.
              Labels : _CSCL_FTEST_N, _CSCL_FINCR_N, _CSCL_FEND_N.
            ParseWhileStmt : while (cond) { stmts }.
              Labels : _CSCL_WTEST_N, _CSCL_WEND_N.
            ParseDoWhileStmt : do { stmts } while (cond);.
              Labels : _CSCL_DBEG_N, _CSCL_DEND_N.
            LoopPush / LoopPop : pile de labels pour break/continue.
            break : saut vers la fin de la boucle englobante.
            continue : saut vers l increment/test de la boucle.

  TODO 15 - SWITCH / CASE / DEFAULT
            ParseSwitchStmt : switch (expr) { case val: stmts }.
            Expression de controle : entier dans EAX, sauvee
              sur pile.
            case valeur : branche pour une valeur (CMP + JE).
            case val1: case val2: : valeurs multiples.
            default : branche par defaut.
            break : sortie du switch (JMP vers fin).
            Labels : _CSCL_CASE_N, _CSCL_CDEF_N, _CSCL_CEND_N.
            SwitchPush / SwitchPop : pile pour switch imbriques.

  TODO 16 - METHODES STATIQUES
            ParseMethodDecl : declaration de methode statique.
              static type Nom(type1 param1, type2 param2, ...)
              { corps }.
            Convention cdecl 32 bits : appelant nettoie la pile.
              Parametres empiles de droite a gauche (PUSH).
              Offsets : [EBP+8], [EBP+12], [EBP+16], ...
              Valeur de retour dans EAX.
            Variables locales : [EBP-4], [EBP-8], ...
            Prologue : PUSH EBP / MOV EBP,ESP / SUB ESP,n.
            Epilogue : MOV ESP,EBP / POP EBP / RET.
            Main() : point d entree (_CSCF_Main).
            Appel : evaluer args, PUSH, CALL, ADD ESP,n.
            Methodes void : pas de valeur de retour.
            Recursion : appels recursifs supportes.

  TODO 17 - CLASSES ET MEMBRES STATIQUES
            ParseClassDecl : class Nom { membres }.
            Membres statiques : champs static et methodes static.
            Portee de classe : acces aux membres par NomClasse.Membre.
            Classe Program : classe contenant Main() (point d entree).
            Un seul niveau de classe (pas d heritage dans le
              sous-ensemble minimal).
            Visibilite : public, private, internal (stub, non verifie
              dans le sous-ensemble minimal).
            Constructeurs statiques (stub optionnel).

  TODO 18 - ESPACES DE NOMS (namespace)
            ParseNamespaceDecl : namespace Nom { classes }.
            Namespace englobant le programme entier.
            Resolution de noms qualifies : Namespace.Classe.Methode.
            Espaces de noms imbriques : namespace A.B { ... }.
            Table des namespaces actifs (via using).
            Mangling : _CSCN_Namespace_Classe_Methode.

  TODO 19 - TABLEAUX
            Declaration : type[] nom = new type[taille];
              int[] arr = new int[5];
              Taille = nombre_elements * sizeof(type).
            Acces : arr[index] -> base + index * sizeof(type).
            Allocation statique dans .DATA pour variables globales.
            Allocation sur la pile pour variables locales.
            Propriete Length : arr.Length -> taille du tableau.
            Initialisation element par element :
              arr[0] = 10; arr[1] = 20; ...
            Passage de tableau a methode : par reference (pointeur).
            Types supportes : int[], bool[], char[].

  TODO 20 - CHAINES ET OPERATIONS SUR LES CHAINES
            Chaines C# : type string, reference vers donnees.
            Stockage : DB "abc",0 dans .DATA (ASCIIZ en interne).
            Variable string : pointeur vers chaine (DWORD).
            Concatenation : s1 + s2 -> appel _CSCRT_STRCAT.
            Concatenation mixte : "texte" + valeur_int
              -> conversion int vers string puis concatenation.
            Comparaison : == != via _CSCRT_STRCMP.
            Propriete Length : s.Length -> _CSCRT_STRLEN.
            Chaines litterales : "abc" -> label _CSCK_N dans .DATA.

  TODO 21 - ENTREES/SORTIES (Console)
            Console.WriteLine(expr) : sortie avec saut de ligne.
              Surcharges : int -> _CSCRT_PRINTINT + _CSCRT_PRINTCRLF.
                string -> _CSCRT_PRINTSTR + _CSCRT_PRINTCRLF.
                bool -> "True"/"False" + _CSCRT_PRINTCRLF.
                char -> _CSCRT_PRINTCHAR + _CSCRT_PRINTCRLF.
                sans argument -> _CSCRT_PRINTCRLF.
            Console.Write(expr) : sortie sans saut de ligne.
              Memes surcharges que WriteLine, sans CRLF.
            Console.ReadLine() : lire une ligne depuis stdin
              -> _CSCRT_READSTR -> EAX (pointeur string).
            Detection automatique du type de l argument pour
              choisir la routine runtime appropriee.

  TODO 22 - GOTO, BREAK, CONTINUE, RETURN
            goto label; : saut inconditionnel vers label.
              label: stmt; -> definition du label.
              Verification : label defini dans la meme methode.
            break; : sortie de la boucle ou switch englobant.
              JMP vers label de fin.
              Erreur si utilise hors d une boucle ou switch.
            continue; : passage a l iteration suivante.
              JMP vers label d increment/test.
              Erreur si utilise hors d une boucle.
            return expr; : retour de methode avec valeur.
              MOV EAX, valeur -> JMP vers epilogue.
            return; : retour de methode void.

  TODO 23 - CAST, TYPEOF ET SIZEOF
            Cast explicite : (type)expr.
              (int)c : promotion char -> int (MOVZX).
              (char)i : troncature int -> char (AND 0xFF).
              (byte)i : troncature int -> byte (AND 0xFF).
              (bool)i : i != 0 -> true.
            typeof(type) : retourne le nom du type (stub string).
            sizeof(type) : taille en octets.
              sizeof(int) -> 4, sizeof(char) -> 1,
              sizeof(bool) -> 1, sizeof(byte) -> 1.
            Conversions implicites : byte->int, short->int,
              char->int.

  TODO 24 - RUNTIME MINIMAL WIN32
            _CSCRT_PRINTSTR(ESI=msg) : WriteFile sur hStdOut.
            _CSCRT_PRINTINT(EAX=n) : conversion + WriteFile.
            _CSCRT_PRINTCRLF : ecriture CR+LF.
            _CSCRT_PRINTCHAR(EAX=c) : afficher un caractere.
            _CSCRT_PRINTBOOL(EAX=b) : afficher "True" ou "False".
            _CSCRT_NUMTOSTR(EAX=n, EDI=buf) : entier -> ASCII.
            _CSCRT_STRTONUM(ESI=str) : ASCII -> entier -> EAX.
            _CSCRT_STRLEN(ESI=str) : longueur ASCIIZ -> EAX.
            _CSCRT_STRCMP(ESI=s1, EDI=s2) : comparaison -> drapeaux.
            _CSCRT_STRCPY(ESI=src, EDI=dst) : copie de chaine.
            _CSCRT_STRCAT(ESI=s1, EDI=s2) : concatenation -> EAX.
            _CSCRT_READINT -> EAX : lire entier depuis stdin.
            _CSCRT_READSTR(EDI=buf) : lire ligne depuis stdin.
            _CSCRT_READCHAR -> EAX : lire un caractere.
            _CSCRT_READLN : consommer jusqu au prochain CR+LF.
            _CSCRT_MALLOC(EAX=taille) : HeapAlloc -> EAX=ptr.
            _CSCRT_FREE(EAX=ptr) : HeapFree.
            _CSCRT_MEMCPY(ESI=src, EDI=dst, ECX=len) : copie.
            _CSCRT_MEMSET(EDI=dst, EAX=val, ECX=len) : remplissage.
            _CSCRT_PANIC(ESI=msg) : message + ExitProcess(1).
            Heap Win32 : GetProcessHeap + HeapAlloc / HeapFree.
            Handles : hStdOut, hStdIn via GetStdHandle.

  TODO 25 - GENERATION PE/COFF ET FICHIERS EXEMPLES
            Generation PE (.EXE Windows 32 bits) :
              DOS stub + signature PE + en-tete COFF + en-tete
              optionnel.
              Sections : .text (code), .rdata (imports),
                .data (donnees).
              Table d imports : kernel32.dll (ExitProcess,
                GetStdHandle, WriteFile, ReadFile,
                GetProcessHeap, HeapAlloc, HeapFree).
              Point d entree : _CSCF_Main.
            Generation COFF (.OBJ) : option -obj.
              En-tete COFF + sections .text/.data +
              table symboles.
              Relocations pour les references externes.
            Generation ASM (.ASM) : option -asm.
              Fichier assembleur MASM lisible en plus du binaire.
            EmitClose : finalisation du fichier de sortie.
            Run : pipeline complet LexInit -> Parse -> Emit ->
              Binary.
            Fichiers SAMPLES\CSHARP\*.cs existants :
              test01_hello.cs, test02_vars.cs, test03_arith.cs,
              test04_cond.cs, test05_while.cs, test06_for.cs,
              test07_fonct.cs, test08_string.cs, test09_array.cs,
              test10_recurs.cs.
            Smoke tests : CSCW32.EXE -v SAMPLES\CSHARP\*.cs.

  ============================================================ *)

Program CSCW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF      }
{           [IMPLEMENTE]                                        }
{ ============================================================ }

Const
  CSCW32_VERSION = '0.1';
  CSCW32_DATE    = '2026';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { PE/COFF format constants }
  PE_DOS_MAGIC    = $5A4D;       { 'MZ'                              }
  PE_PE_SIG       = $00004550;   { 'PE\0\0'                          }
  PE_MACHINE_I386 = $014C;       { i386                               }
  PE_OPT_SIZE     = 224;         { sizeof IMAGE_OPTIONAL_HEADER32     }
  PE_MAGIC_32     = $010B;       { PE32                               }
  PE_IMG_BASE     = $00400000;   { default image base                 }
  PE_SEC_ALIGN    = $1000;       { section alignment (4KB)            }
  PE_FILE_ALIGN   = $0200;       { file alignment (512)               }
  PE_SUBSYS_CUI   = 3;           { console subsystem                  }
  PE_SCN_TEXT     = $60000020;   { CODE | EXECUTE | READ              }
  PE_SCN_RDATA    = $40000040;   { INIT_DATA | READ                   }
  PE_SCN_BSS      = LongInt($C0000040);   { INIT_DATA | READ | WRITE (data section) }
  MAX_BIN_CODE    = 65536;       { 64 KB max code section             }
  MAX_BIN_DATA    = 65536;       { 64 KB max data section             }
  MAX_BIN_LBL     = 4096;        { max labels                         }
  MAX_BIN_FIX     = 8192;        { max fixups                         }
  PE_NUM_API      = 7;           { number of imported Win32 APIs      }
  COFF_RELOC_DIR32  = 6;         { IMAGE_REL_I386_DIR32               }
  COFF_RELOC_REL32  = 20;        { IMAGE_REL_I386_REL32               }

Type
  TString = String;

  { Types binaires }
  TBinFixKind = (BFK_ABS32, BFK_REL32, BFK_IAT32);
  TBinFixup = Record
    Offset : LongInt;
    Kind   : TBinFixKind;
    Target : TString;
    InCode : Boolean;
  End;
  TBinLabel = Record
    Name   : TString;
    Offset : LongInt;
    InCode : Boolean;
  End;

  TOptions = Record
    SrcFile   : TString;   { fichier source (.cs)                 }
    OutFile   : TString;   { fichier sortie (.exe, .obj)          }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : afficher les avertissements     }
    AsmOutput : Boolean;   { -asm : produire aussi un .ASM        }
    ObjOnly   : Boolean;   { -obj : produire seulement un .OBJ    }
  End;

Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;

  { Fichier de sortie interne (pour future emission) }
  OutF       : Text;
  OutFOpen   : Boolean;

  { Emetteur ASM (TODO 07) }
  AsmFileName : TString;       { nom du fichier .asm                 }
  LabelSeq    : LongInt;       { compteur global pour labels uniques }

  { Segment de donnees (TODO 08) }

Const
  MAX_DATA = 512;               { max entrees dans DataTab            }

Type
  TDataKind = (DK_DWORD, DK_BYTE, DK_STR, DK_ARRAY, DK_ZERO);

  TDataRec = Record
    LblName   : TString;        { label ASM dans .DATA                }
    Kind      : TDataKind;      { type de donnee                      }
    IntVal    : LongInt;        { valeur entiere (pour DK_DWORD/BYTE) }
    StrVal    : TString;        { contenu chaine (pour DK_STR)        }
    ElemCount : Integer;        { taille en octets (DK_ARRAY/DK_ZERO) }
  End;

Var
  DataTab     : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount   : Integer;        { nombre d entrees dans DataTab       }
  StaticSeq   : Integer;        { compteur de sequence pour _CSCST_N  }

  { Variables locales et parametres (TODO 09) }
  LocalOffset : Integer;        { offset negatif courant [EBP-n]      }
  ParamOffset : Integer;        { offset positif courant [EBP+n]      }

  { Variables binaires }
  BinCode     : Array[0..MAX_BIN_CODE - 1] of Byte;
  BinCodeLen  : LongInt;
  BinData     : Array[0..MAX_BIN_DATA - 1] of Byte;
  BinDataLen  : LongInt;
  BinLabels   : Array[0..MAX_BIN_LBL - 1] of TBinLabel;
  BinLblCount : Integer;
  BinFixups   : Array[0..MAX_BIN_FIX - 1] of TBinFixup;
  BinFixCount : Integer;
  BinInCode   : Boolean;

Const
  BinAPIDecorated : Array[0..PE_NUM_API - 1] Of String[32] = (
    '_ExitProcess@4', '_GetStdHandle@4', '_WriteFile@20',
    '_ReadFile@20', '_GetProcessHeap@0', '_HeapAlloc@12',
    '_HeapFree@12'
  );
  BinAPIName : Array[0..PE_NUM_API - 1] Of String[20] = (
    'ExitProcess', 'GetStdHandle', 'WriteFile', 'ReadFile',
    'GetProcessHeap', 'HeapAlloc', 'HeapFree'
  );

{ ------------------------------------------------------------ }
{ Fonctions utilitaires                                        }
{ ------------------------------------------------------------ }

Function IntToStr_(V : LongInt) : TString;
Var S : TString;
Begin
  Str(V, S);
  IntToStr_ := S;
End;

Function StrUpperCase(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'a') And (Tmp[I] <= 'z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) - 32);
  StrUpperCase := Tmp;
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

{ Retourne l extension d un chemin (avec le point, en minuscules) }
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

{ Remplace l extension d un chemin }
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

{ Retourne le repertoire d un chemin (avec le separateur final) }
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

{ Verifie si un fichier existe }
Function FileExists(Const Path : TString) : Boolean;
Var F : Text;
Begin
  Assign(F, Path);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    Close(F);
    FileExists := True;
  End
  Else
    FileExists := False;
End;

{ ------------------------------------------------------------ }
{ FatalError / WarnMsg                                         }
{ ------------------------------------------------------------ }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('CSCW32: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('CSCW32: warning: ', Msg);
  Inc(WarnCount);
End;

{ ------------------------------------------------------------ }
{ InitOptions                                                  }
{ ------------------------------------------------------------ }

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
  Opts.AsmOutput := False;
  Opts.ObjOnly   := False;
End;

{ ------------------------------------------------------------ }
{ ShowHelp                                                     }
{ ------------------------------------------------------------ }

Procedure ShowHelp;
Begin
  WriteLn('CSCW32 v', CSCW32_VERSION, ' (', CSCW32_DATE,
          ') - Compilateur C# (C Sharp) vers 80386 (Windows PE 32 bits)');
  WriteLn('CSCW32 - Cette commande permet de lancer le compilateur C# ',
          '(C Sharp) pour l''assembleur du microprocesseur 80386 (en ',
          'executable Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : CSCW32 <source.cs> [sortie] [options]');
  WriteLn;
  WriteLn('Sortie :');
  WriteLn('  Par defaut un .EXE (PE Windows 32 bits)');
  WriteLn('  -obj           Produire seulement un fichier .OBJ (COFF)');
  WriteLn('  -asm           Produire egalement un fichier .ASM lisible');
  WriteLn;
  WriteLn('General :');
  WriteLn('  -v             Mode verbeux (banniere + statistiques)');
  WriteLn('  -d             Debug tokens (affiche chaque token)');
  WriteLn('  -w             Afficher les avertissements');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  CSCW32 hello.cs');
  WriteLn('  CSCW32 hello.cs hello.exe -v');
  WriteLn('  CSCW32 prog.cs -asm');
  WriteLn('  CSCW32 module.cs -obj');
  Halt(EXIT_OK);
End;

{ ------------------------------------------------------------ }
{ ParseArgs                                                    }
{ ------------------------------------------------------------ }

Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
  Ext : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowHelp;

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Or
       (Arg = '/h') Or (Arg = '/H') Then
      ShowHelp
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg = '-asm' Then
      Opts.AsmOutput := True
    Else If Arg = '-obj' Then
      Opts.ObjOnly := True
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
      FatalError('Option inconnue: ' + Arg)
    Else
    Begin
      { Argument positionnel : fichier source ou sortie }
      If Opts.SrcFile = '' Then
        Opts.SrcFile := Arg
      Else If Opts.OutFile = '' Then
        Opts.OutFile := Arg
      Else
        FatalError('Argument inattendu: ' + Arg);
    End;

    Inc(I);
  End;

  { Validation : fichier source requis }
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('CSCW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .cs }
  Ext := ExtractExt(Opts.SrcFile);
  If Ext <> '.cs' Then
    WarnMsg('extension attendue .cs, trouvee: ' + Ext);

  { Fichier de sortie par defaut }
  If Opts.OutFile = '' Then
  Begin
    If Opts.ObjOnly Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj')
    Else
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe');
  End;
End;

{ ------------------------------------------------------------ }
{ ShowBanner / ShowStats                                       }
{ ------------------------------------------------------------ }

Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('CSCW32 v', CSCW32_VERSION, ' (', CSCW32_DATE,
          ') - Compilateur C# (C Sharp) -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.AsmOutput Then
    WriteLn('ASM      : ', ReplaceExt(Opts.OutFile, '.asm'));
  WriteLn;
End;

Procedure ShowStats; Forward;

{ Forward declarations for TODO 08 }
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Procedure DataInit; Forward;

{ Forward declarations for TODO 09 }
Function  AllocLocal(Size : Integer) : Integer; Forward;
Procedure ParseVarDecl(Const VarType : TString; IsStatic : Boolean;
                       Const ClassName : TString); Forward;

{ Forward declarations for TODO 10 }
Procedure ParseExpr; Forward;
Procedure ParsePrimary; Forward;

{ Forward declarations for TODO 11 }
Procedure ParseExprPrec(MinPrec : Integer); Forward;

{ ============================================================ }
{ TODO 02 - LEXEUR (TOKENS C#)                                 }
{           [IMPLEMENTE]                                        }
{ ============================================================ }

Const
  MAX_STR = 255;

Type
  TTokenKind = (
    TK_EOF,
    TK_INTEGER,
    TK_FLOAT,
    TK_STRING,
    TK_CHAR,
    TK_IDENT,
    TK_KEYWORD,
    TK_OP,
    TK_PUNCT
  );

  TToken = Record
    Kind    : TTokenKind;
    Val     : TString;      { texte du token                     }
    IntVal  : LongInt;      { valeur entiere si TK_INTEGER/CHAR  }
    Line    : Integer;      { numero de ligne source (1-based)   }
    Col     : Integer;      { colonne dans la ligne (1-based)    }
  End;

Var
  { Lexeur }
  LexSrcF     : Text;       { handle du fichier source           }
  LexOpened   : Boolean;     { fichier ouvert ?                   }
  LexLine     : TString;    { ligne courante                     }
  LexLineNo   : Integer;    { numero de ligne courante           }
  LexColNo    : Integer;    { colonne courante dans LexLine      }
  LexEOF      : Boolean;    { fin de fichier atteinte ?          }
  CurToken    : TToken;     { token courant                      }
  TokenCount  : LongInt;    { nombre de tokens produits          }

{ ------------------------------------------------------------ }
{ Fonctions de classification de caracteres                    }
{ ------------------------------------------------------------ }

Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or
                 ((Ch >= '0') And (Ch <= '9'));
End;

Function IsDigit(Ch : Char) : Boolean;
Begin
  IsDigit := (Ch >= '0') And (Ch <= '9');
End;

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
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

{ ------------------------------------------------------------ }
{ IsKeyword : mots-cles du langage C#                          }
{ ------------------------------------------------------------ }

Function IsKeyword(Const S : TString) : Boolean;
Begin
  IsKeyword :=
    (S = 'abstract')  Or (S = 'as')        Or (S = 'base')     Or
    (S = 'bool')      Or (S = 'break')     Or (S = 'byte')     Or
    (S = 'case')      Or (S = 'catch')     Or (S = 'char')     Or
    (S = 'class')     Or (S = 'const')     Or (S = 'continue') Or
    (S = 'decimal')   Or (S = 'default')   Or (S = 'delegate') Or
    (S = 'do')        Or (S = 'double')    Or (S = 'else')     Or
    (S = 'enum')      Or (S = 'event')     Or (S = 'explicit') Or
    (S = 'extern')    Or (S = 'false')     Or (S = 'finally')  Or
    (S = 'fixed')     Or (S = 'float')     Or (S = 'for')      Or
    (S = 'foreach')   Or (S = 'goto')      Or (S = 'if')       Or
    (S = 'implicit')  Or (S = 'in')        Or (S = 'int')      Or
    (S = 'interface') Or (S = 'internal')  Or (S = 'is')       Or
    (S = 'lock')      Or (S = 'long')      Or (S = 'namespace')Or
    (S = 'new')       Or (S = 'null')      Or (S = 'object')   Or
    (S = 'operator')  Or (S = 'out')       Or (S = 'override') Or
    (S = 'params')    Or (S = 'private')   Or (S = 'protected')Or
    (S = 'public')    Or (S = 'readonly')  Or (S = 'ref')      Or
    (S = 'return')    Or (S = 'sbyte')     Or (S = 'sealed')   Or
    (S = 'short')     Or (S = 'sizeof')    Or (S = 'stackalloc')Or
    (S = 'static')    Or (S = 'string')    Or (S = 'struct')   Or
    (S = 'switch')    Or (S = 'this')      Or (S = 'throw')    Or
    (S = 'true')      Or (S = 'try')       Or (S = 'typeof')   Or
    (S = 'uint')      Or (S = 'ulong')     Or (S = 'unchecked')Or
    (S = 'unsafe')    Or (S = 'ushort')    Or (S = 'using')    Or
    (S = 'virtual')   Or (S = 'void')      Or (S = 'volatile') Or
    (S = 'while');
End;

{ ------------------------------------------------------------ }
{ LexNextLine : lire la prochaine ligne du source               }
{ ------------------------------------------------------------ }

Procedure LexNextLine;
Begin
  If LexEOF Then Exit;
  If EOF(LexSrcF) Then
  Begin
    LexEOF   := True;
    LexLine  := '';
    LexColNo := 1;
  End
  Else
  Begin
    {$I-}
    ReadLn(LexSrcF, LexLine);
    {$I+}
    If IOResult <> 0 Then
    Begin
      LexEOF   := True;
      LexLine  := '';
      LexColNo := 1;
      Exit;
    End;
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

{ ------------------------------------------------------------ }
{ LexInit / LexClose                                           }
{ ------------------------------------------------------------ }

Procedure LexInit;
Begin
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexLine   := '';
  TokenCount := 0;
  CurToken.Kind   := TK_EOF;
  CurToken.Val    := '';
  CurToken.IntVal := 0;
  CurToken.Line   := 0;
  CurToken.Col    := 0;
  LexNextLine;
End;

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    {$I-}
    Close(LexSrcF);
    {$I+}
    If IOResult <> 0 Then { ignorer };
    LexOpened := False;
  End;
End;

{ ------------------------------------------------------------ }
{ Gestion des commentaires                                     }
{ ------------------------------------------------------------ }

Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

Procedure LexSkipBlockComment;
Begin
  Inc(LexColNo, 2);  { sauter / et * }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      Inc(LexColNo, 2);
      Exit;
    End
    Else
      Inc(LexColNo);
  End;
  WarnMsg('commentaire /* non ferme a la fin du fichier');
End;

{ ------------------------------------------------------------ }
{ LexScanEscape : sequences d echappement C#                   }
{ ------------------------------------------------------------ }

Function LexScanEscape : Integer;
Var V : Integer;
    Count : Integer;
Begin
  If LexColNo > Length(LexLine) Then
  Begin
    LexScanEscape := Ord('\');
    Exit;
  End;
  Case LexLine[LexColNo] Of
    'n'  : Begin LexScanEscape := 10;  Inc(LexColNo); End;
    't'  : Begin LexScanEscape := 9;   Inc(LexColNo); End;
    'r'  : Begin LexScanEscape := 13;  Inc(LexColNo); End;
    '0'  : Begin LexScanEscape := 0;   Inc(LexColNo); End;
    '\' : Begin LexScanEscape := 92;  Inc(LexColNo); End;
    '"'  : Begin LexScanEscape := 34;  Inc(LexColNo); End;
    '''' : Begin LexScanEscape := 39;  Inc(LexColNo); End;
    'a'  : Begin LexScanEscape := 7;   Inc(LexColNo); End;
    'b'  : Begin LexScanEscape := 8;   Inc(LexColNo); End;
    'f'  : Begin LexScanEscape := 12;  Inc(LexColNo); End;
    'v'  : Begin LexScanEscape := 11;  Inc(LexColNo); End;
    'x', 'X' :
    Begin
      Inc(LexColNo);
      V := 0;
      Count := 0;
      While (LexColNo <= Length(LexLine)) And
            IsHexDigit(LexLine[LexColNo]) And (Count < 4) Do
      Begin
        V := V * 16 + HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
        Inc(Count);
      End;
      LexScanEscape := V And $FF;
    End;
    'u', 'U' :
    Begin
      Inc(LexColNo);
      V := 0;
      Count := 0;
      While (LexColNo <= Length(LexLine)) And
            IsHexDigit(LexLine[LexColNo]) And (Count < 4) Do
      Begin
        V := V * 16 + HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
        Inc(Count);
      End;
      LexScanEscape := V And $FF;
    End;
  Else
    LexScanEscape := Ord(LexLine[LexColNo]);
    Inc(LexColNo);
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanString : chaine entre guillemets "abc"                 }
{ ------------------------------------------------------------ }

Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo);  { sauter le guillemet ouvrant }
  While (LexColNo <= Length(LexLine)) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '"' Then
    Begin
      Inc(LexColNo);  { sauter le guillemet fermant }
      Break;
    End
    Else If Ch = '\' Then
    Begin
      Inc(LexColNo);  { sauter le \ }
      If Length(S) < MAX_STR Then
        S := S + Chr(LexScanEscape And $FF);
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ------------------------------------------------------------ }
{ LexScanVerbatimString : chaine verbatim @"c:\path"            }
{ ------------------------------------------------------------ }

Procedure LexScanVerbatimString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo);  { sauter le guillemet ouvrant (@ deja consomme) }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      { Les chaines verbatim peuvent etre multi-lignes }
      If Length(S) < MAX_STR Then
        S := S + #10;
      LexNextLine;
    End
    Else
    Begin
      Ch := LexLine[LexColNo];
      If Ch = '"' Then
      Begin
        Inc(LexColNo);
        { "" dans une chaine verbatim = guillemet litteral }
        If (LexColNo <= Length(LexLine)) And
           (LexLine[LexColNo] = '"') Then
        Begin
          If Length(S) < MAX_STR Then
            S := S + '"';
          Inc(LexColNo);
        End
        Else
          Break;
      End
      Else
      Begin
        If Length(S) < MAX_STR Then
          S := S + Ch;
        Inc(LexColNo);
      End;
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ------------------------------------------------------------ }
{ LexScanCharLit : caractere entre apostrophes 'A' '\n'         }
{ ------------------------------------------------------------ }

Procedure LexScanCharLit;
Var V : Integer;
Begin
  Inc(LexColNo);  { sauter l apostrophe ouvrante }
  V := 0;
  If (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] <> '''') Then
  Begin
    If LexLine[LexColNo] = '\' Then
    Begin
      Inc(LexColNo);
      V := LexScanEscape;
    End
    Else
    Begin
      V := Ord(LexLine[LexColNo]);
      Inc(LexColNo);
    End;
  End;
  { Sauter l apostrophe fermante }
  If (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] = '''') Then
    Inc(LexColNo);
  CurToken.Kind   := TK_CHAR;
  CurToken.Val    := Chr(V And $FF);
  CurToken.IntVal := V;
End;

{ ------------------------------------------------------------ }
{ LexScanIdent : identificateurs et mots-cles                  }
{ ------------------------------------------------------------ }

Procedure LexScanIdent;
Var S : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And
        IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
  If IsKeyword(S) Then
    CurToken.Kind := TK_KEYWORD
  Else
    CurToken.Kind := TK_IDENT;
End;

{ ------------------------------------------------------------ }
{ LexScanNumber : entiers dec/hex, flottants, suffixes          }
{ ------------------------------------------------------------ }

Procedure LexScanNumber;
Var
  N       : LongInt;
  Ch      : Char;
  NumStr  : TString;
  IsFloat : Boolean;
Begin
  N       := 0;
  NumStr  := '';
  IsFloat := False;
  Ch      := LexLine[LexColNo];

  { Hexadecimal : 0x... ou 0X... }
  If (Ch = '0') And (LexColNo < Length(LexLine)) And
     ((LexLine[LexColNo + 1] = 'x') Or
      (LexLine[LexColNo + 1] = 'X')) Then
  Begin
    NumStr := '0x';
    Inc(LexColNo, 2);
    While (LexColNo <= Length(LexLine)) And
          IsHexDigit(LexLine[LexColNo]) Do
    Begin
      N := N * 16 + HexVal(LexLine[LexColNo]);
      NumStr := NumStr + LexLine[LexColNo];
      Inc(LexColNo);
    End;
    { Suffixes u/U/l/L ignores }
    While (LexColNo <= Length(LexLine)) And
          ((LexLine[LexColNo] = 'u') Or (LexLine[LexColNo] = 'U') Or
           (LexLine[LexColNo] = 'l') Or (LexLine[LexColNo] = 'L')) Do
      Inc(LexColNo);
    CurToken.Kind   := TK_INTEGER;
    CurToken.Val    := NumStr;
    CurToken.IntVal := N;
    Exit;
  End;

  { Decimal (ou flottant) }
  While (LexColNo <= Length(LexLine)) And
        IsDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    NumStr := NumStr + LexLine[LexColNo];
    Inc(LexColNo);
  End;

  { Partie fractionnaire .ddd }
  If (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     IsDigit(LexLine[LexColNo + 1]) Then
  Begin
    IsFloat := True;
    NumStr := NumStr + '.';
    Inc(LexColNo);
    While (LexColNo <= Length(LexLine)) And
          IsDigit(LexLine[LexColNo]) Do
    Begin
      NumStr := NumStr + LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;

  { Exposant E[+-]ddd }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'e') Or (LexLine[LexColNo] = 'E')) Then
  Begin
    IsFloat := True;
    NumStr := NumStr + LexLine[LexColNo];
    Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And
       ((LexLine[LexColNo] = '+') Or (LexLine[LexColNo] = '-')) Then
    Begin
      NumStr := NumStr + LexLine[LexColNo];
      Inc(LexColNo);
    End;
    While (LexColNo <= Length(LexLine)) And
          IsDigit(LexLine[LexColNo]) Do
    Begin
      NumStr := NumStr + LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;

  { Suffixes f/F/d/D/m/M/u/U/l/L }
  While (LexColNo <= Length(LexLine)) And
        ((LexLine[LexColNo] = 'u') Or (LexLine[LexColNo] = 'U') Or
         (LexLine[LexColNo] = 'l') Or (LexLine[LexColNo] = 'L') Or
         (LexLine[LexColNo] = 'f') Or (LexLine[LexColNo] = 'F') Or
         (LexLine[LexColNo] = 'd') Or (LexLine[LexColNo] = 'D') Or
         (LexLine[LexColNo] = 'm') Or (LexLine[LexColNo] = 'M')) Do
  Begin
    If Not IsFloat Then
      If (LexLine[LexColNo] = 'f') Or (LexLine[LexColNo] = 'F') Or
         (LexLine[LexColNo] = 'd') Or (LexLine[LexColNo] = 'D') Or
         (LexLine[LexColNo] = 'm') Or (LexLine[LexColNo] = 'M') Then
        IsFloat := True;
    Inc(LexColNo);
  End;

  If IsFloat Then
  Begin
    CurToken.Kind   := TK_FLOAT;
    CurToken.Val    := NumStr;
    CurToken.IntVal := N;  { partie entiere tronquee }
  End
  Else
  Begin
    CurToken.Kind   := TK_INTEGER;
    CurToken.Val    := NumStr;
    CurToken.IntVal := N;
  End;
End;

{ ------------------------------------------------------------ }
{ LexNextToken : dispatcher principal du lexeur                 }
{ ------------------------------------------------------------ }

Procedure LexNextToken;
Var
  Ch       : Char;
  Scanning : Boolean;
Begin
  CurToken.IntVal := 0;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer a la ligne suivante si fin de ligne courante }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    { Fin de fichier }
    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Scanning := False;
      Break;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    { Espaces et tabulations }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
      Inc(LexColNo)

    { Commentaire de ligne // ou commentaire XML /// }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
      LexSkipLineComment

    { Commentaire bloc /* ... */ }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
      LexSkipBlockComment

    { Chaine verbatim @"..." }
    Else If (Ch = '@') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '"') Then
    Begin
      Inc(LexColNo);  { sauter le @ }
      LexScanVerbatimString;
      Inc(TokenCount);
      Scanning := False;
    End

    { Chaine "..." }
    Else If Ch = '"' Then
    Begin
      LexScanString;
      Inc(TokenCount);
      Scanning := False;
    End

    { Caractere '...' }
    Else If Ch = '''' Then
    Begin
      LexScanCharLit;
      Inc(TokenCount);
      Scanning := False;
    End

    { Identifiant ou mot-cle }
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Inc(TokenCount);
      Scanning := False;
    End

    { Nombre }
    Else If IsDigit(Ch) Then
    Begin
      LexScanNumber;
      Inc(TokenCount);
      Scanning := False;
    End

    { --- Operateurs 3 caracteres --- }

    { <<= }
    Else If (Ch = '<') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '<') And
            (LexLine[LexColNo + 2] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '<<=';
      Inc(LexColNo, 3); Inc(TokenCount); Scanning := False;
    End

    { >>= }
    Else If (Ch = '>') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') And
            (LexLine[LexColNo + 2] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '>>=';
      Inc(LexColNo, 3); Inc(TokenCount); Scanning := False;
    End

    { --- Operateurs 2 caracteres --- }

    { ++ }
    Else If (Ch = '+') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '+') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '++';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { -- }
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '-') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '--';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { -> }
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '->';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { += }
    Else If (Ch = '+') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '+=';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { -= }
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '-=';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { *= }
    Else If (Ch = '*') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '*=';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { /= }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '/=';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { %= }
    Else If (Ch = '%') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '%=';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { &= }
    Else If (Ch = '&') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '&=';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { |= }
    Else If (Ch = '|') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '|=';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { ^= }
    Else If (Ch = '^') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '^=';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { == }
    Else If (Ch = '=') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '==';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { != }
    Else If (Ch = '!') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '!=';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { <= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '<=';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { >= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '>=';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { && }
    Else If (Ch = '&') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '&') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '&&';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { || }
    Else If (Ch = '|') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '|') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '||';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { << }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '<') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '<<';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { >> }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '>>';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { ?? }
    Else If (Ch = '?') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '?') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '??';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { => (lambda) }
    Else If (Ch = '=') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '=>';
      Inc(LexColNo, 2); Inc(TokenCount); Scanning := False;
    End

    { --- Operateurs 1 caractere --- }
    Else If (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
            (Ch = '%') Or (Ch = '&') Or (Ch = '|') Or (Ch = '^') Or
            (Ch = '<') Or (Ch = '>') Or (Ch = '=') Or (Ch = '!') Or
            (Ch = '~') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Inc(TokenCount);
      Scanning := False;
    End

    { --- Ponctuation --- }
    Else If (Ch = '(') Or (Ch = ')') Or (Ch = '[') Or (Ch = ']') Or
            (Ch = '{') Or (Ch = '}') Or (Ch = ';') Or (Ch = ',') Or
            (Ch = '.') Or (Ch = ':') Or (Ch = '?') Or (Ch = '#') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Inc(TokenCount);
      Scanning := False;
    End

    { Caractere inconnu }
    Else
    Begin
      WarnMsg('caractere inattendu: ' + Ch + ' (ligne '
        + IntToStr_(LexLineNo) + ')');
      Inc(LexColNo);
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ PrintToken : affichage debug d un token                       }
{ ------------------------------------------------------------ }

Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF     : Write('EOF');
    TK_INTEGER : Write('INT(', T.IntVal, ')');
    TK_FLOAT   : Write('FLOAT(', T.Val, ')');
    TK_STRING  : Write('STR("', T.Val, '")');
    TK_CHAR    : Write('CHAR(', T.IntVal, ')');
    TK_IDENT   : Write('IDENT(', T.Val, ')');
    TK_KEYWORD : Write('KW(', T.Val, ')');
    TK_OP      : Write('OP(', T.Val, ')');
    TK_PUNCT   : Write('PUNCT(', T.Val, ')');
  End;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ Helpers : Consume, Expect, TokIs                              }
{ ------------------------------------------------------------ }

Procedure Consume;
Begin
  LexNextToken;
  PrintToken(CurToken);
End;

Function TokIs(Const S : TString) : Boolean;
Begin
  TokIs := (CurToken.Val = S);
End;

Function TokIsKw(Const S : TString) : Boolean;
Begin
  TokIsKw := (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = S);
End;

Function TokIsOp(Const S : TString) : Boolean;
Begin
  TokIsOp := (CurToken.Kind = TK_OP) And (CurToken.Val = S);
End;

Function TokIsPunct(Const S : TString) : Boolean;
Begin
  TokIsPunct := (CurToken.Kind = TK_PUNCT) And (CurToken.Val = S);
End;

Procedure Expect(Const S : TString);
Begin
  Consume;
  If CurToken.Val <> S Then
  Begin
    WriteLn('CSCW32: erreur ligne ', CurToken.Line, ' col ',
            CurToken.Col, ': attendu ''', S, ''' lu ''',
            CurToken.Val, '''');
    Inc(ErrorCount);
  End;
End;

Procedure ExpectKw(Const S : TString);
Begin
  Consume;
  If (CurToken.Kind <> TK_KEYWORD) Or (CurToken.Val <> S) Then
  Begin
    WriteLn('CSCW32: erreur ligne ', CurToken.Line, ' col ',
            CurToken.Col, ': attendu mot-cle ''', S, ''' lu ''',
            CurToken.Val, '''');
    Inc(ErrorCount);
  End;
End;

{ ============================================================ }
{ TODO 03 - DIRECTIVES USING ET IMPORTS                         }
{           [IMPLEMENTE]                                        }
{ ============================================================ }

Const
  MAX_USING = 32;

Type
  TUsingEntry = Record
    Name     : TString;     { nom complet du namespace, ex. 'System' }
    IsStd    : Boolean;     { true si namespace standard reconnu     }
    Used     : Boolean;     { true si le namespace a ete utilise     }
    Line     : Integer;     { ligne source de la directive using     }
  End;

Var
  UsingTab   : Array[1..MAX_USING] Of TUsingEntry;
  UsingCount : Integer;

{ ------------------------------------------------------------ }
{ IsStandardNamespace : reconnu en built-in par le compilateur  }
{ ------------------------------------------------------------ }

Function IsStandardNamespace(Const S : TString) : Boolean;
Begin
  IsStandardNamespace :=
    (S = 'System')              Or
    (S = 'System.Collections')  Or
    (S = 'System.IO');
End;

{ ------------------------------------------------------------ }
{ InitUsingTable                                                }
{ ------------------------------------------------------------ }

Procedure InitUsingTable;
Begin
  UsingCount := 0;
End;

{ ------------------------------------------------------------ }
{ AddUsing : ajouter un namespace a la table des using          }
{ Retourne l index (1-based) ou 0 si la table est pleine       }
{ Pas de doublons : si deja present, retourne l index existant  }
{ ------------------------------------------------------------ }

Function AddUsing(Const Name : TString; Ln : Integer) : Integer;
Var I : Integer;
Begin
  { Verifier les doublons }
  For I := 1 To UsingCount Do
    If UsingTab[I].Name = Name Then
    Begin
      WarnMsg('using duplique : ' + Name +
              ' (ligne ' + IntToStr_(Ln) + ')');
      AddUsing := I;
      Exit;
    End;

  { Ajouter }
  If UsingCount >= MAX_USING Then
  Begin
    WriteLn('CSCW32: erreur ligne ', Ln,
            ': trop de directives using (max ', MAX_USING, ')');
    Inc(ErrorCount);
    AddUsing := 0;
    Exit;
  End;

  Inc(UsingCount);
  UsingTab[UsingCount].Name  := Name;
  UsingTab[UsingCount].IsStd := IsStandardNamespace(Name);
  UsingTab[UsingCount].Used  := False;
  UsingTab[UsingCount].Line  := Ln;
  AddUsing := UsingCount;
End;

{ ------------------------------------------------------------ }
{ FindUsing : chercher un namespace dans la table des using     }
{ Retourne l index (1-based) ou 0 si non trouve                 }
{ ------------------------------------------------------------ }

Function FindUsing(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := 1 To UsingCount Do
    If UsingTab[I].Name = Name Then
    Begin
      FindUsing := I;
      Exit;
    End;
  FindUsing := 0;
End;

{ ------------------------------------------------------------ }
{ MarkUsingUsed : marquer un namespace comme utilise             }
{ ------------------------------------------------------------ }

Procedure MarkUsingUsed(Const Name : TString);
Var I : Integer;
Begin
  I := FindUsing(Name);
  If I > 0 Then
    UsingTab[I].Used := True;
End;

{ ------------------------------------------------------------ }
{ ParseUsingDirective : lire une directive using namespace;      }
{   using System;                                               }
{   using System.Collections;                                   }
{   using System.IO;                                            }
{ Le token 'using' a deja ete lu par le dispatcher.             }
{ ------------------------------------------------------------ }

Procedure ParseUsingDirective;
Var
  NsName : TString;
  ULine  : Integer;
  Idx    : Integer;
Begin
  ULine := CurToken.Line;

  { Lire le nom du namespace (potentiellement pointe A.B.C) }
  Consume;  { premier identifiant apres 'using' }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    WriteLn('CSCW32: erreur ligne ', CurToken.Line, ' col ',
            CurToken.Col,
            ': identifiant attendu apres ''using''');
    Inc(ErrorCount);
    { Resynchroniser jusqu au ; }
    While (CurToken.Kind <> TK_EOF) And
          (Not TokIsPunct(';')) Do
      Consume;
    If TokIsPunct(';') Then Consume;
    Exit;
  End;

  NsName := CurToken.Val;
  Consume;

  { Lire les segments supplementaires : .Ident }
  While TokIsPunct('.') Do
  Begin
    NsName := NsName + '.';
    Consume;  { consomme le '.' }
    If CurToken.Kind <> TK_IDENT Then
    Begin
      WriteLn('CSCW32: erreur ligne ', CurToken.Line, ' col ',
              CurToken.Col,
              ': identifiant attendu apres ''.'' dans namespace');
      Inc(ErrorCount);
      Break;
    End;
    NsName := NsName + CurToken.Val;
    Consume;
  End;

  { Enregistrer le namespace }
  Idx := AddUsing(NsName, ULine);

  { Avertissement pour namespaces non standards }
  If (Idx > 0) And (Not UsingTab[Idx].IsStd) Then
    WarnMsg('namespace non reconnu (ignore) : ' + NsName +
            ' (ligne ' + IntToStr_(ULine) + ')');

  { Attendre le ';' }
  If TokIsPunct(';') Then
    Consume
  Else
  Begin
    WriteLn('CSCW32: erreur ligne ', CurToken.Line, ' col ',
            CurToken.Col,
            ': '';'' attendu apres directive using');
    Inc(ErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseUsingSection : lire toutes les directives using en tete  }
{ ------------------------------------------------------------ }

Procedure ParseUsingSection;
Begin
  While (CurToken.Kind <> TK_EOF) And TokIsKw('using') Do
    ParseUsingDirective;
End;

{ ------------------------------------------------------------ }
{ CheckUnusedUsings : avertissement pour using non utilises      }
{ ------------------------------------------------------------ }

Procedure CheckUnusedUsings;
Var I : Integer;
Begin
  For I := 1 To UsingCount Do
    If (Not UsingTab[I].Used) And UsingTab[I].IsStd Then
      WarnMsg('using non utilise : ' + UsingTab[I].Name +
              ' (ligne ' + IntToStr_(UsingTab[I].Line) + ')');
End;

{ ============================================================ }
{ TODO 04 - LITTERAUX ET CONSTANTES                             }
{           [IMPLEMENTE]                                        }
{ ============================================================ }

Const
  MAX_STR_LIT = 1024;          { max litteraux chaines en .DATA     }
  MAX_CONST   = 256;           { max constantes nommees             }
  CSC_STR_PFX = '_CSCK_';     { prefixe labels chaines .DATA       }

Type
  TStrLitEntry = Record
    Text    : TString;          { contenu de la chaine               }
    AsmLbl  : TString;          { label ASM (_CSCK_1, _CSCK_2 ...)  }
  End;

  TConstEntry = Record
    Name    : TString;          { nom de la constante (ex. 'X')      }
    Value   : LongInt;          { valeur entiere evaluee             }
    StrVal  : TString;          { valeur chaine si applicable        }
    IsStr   : Boolean;          { true si constante chaine           }
    Line    : Integer;          { ligne source de la declaration     }
  End;

Var
  StrLitTab    : Array[1..MAX_STR_LIT] Of TStrLitEntry;
  StrLitCount  : Integer;      { nombre de litteraux chaines         }
  StrLitSeq    : Integer;      { compteur de sequence pour labels    }
  ConstTab     : Array[1..MAX_CONST] Of TConstEntry;
  ConstCount   : Integer;      { nombre de constantes nommees        }

{ ------------------------------------------------------------ }
{ InitStrLitTable : initialiser la table des litteraux chaines  }
{ ------------------------------------------------------------ }

Procedure InitStrLitTable;
Begin
  StrLitCount := 0;
  StrLitSeq   := 0;
End;

{ ------------------------------------------------------------ }
{ AddStrLit : ajouter un litteral chaine avec deduplication     }
{   Retourne le label ASM _CSCK_N                              }
{ ------------------------------------------------------------ }

Function AddStrLit(Const S : TString) : TString;
Var
  I   : Integer;
  Lbl : TString;
Begin
  { Deduplication : chercher si deja present }
  For I := 1 To StrLitCount Do
    If StrLitTab[I].Text = S Then
    Begin
      AddStrLit := StrLitTab[I].AsmLbl;
      Exit;
    End;

  { Ajouter nouveau }
  If StrLitCount >= MAX_STR_LIT Then
  Begin
    WriteLn('CSCW32: erreur: table des litteraux chaines pleine (max ',
            MAX_STR_LIT, ')');
    Inc(ErrorCount);
    AddStrLit := CSC_STR_PFX + '0';
    Exit;
  End;

  Inc(StrLitCount);
  Inc(StrLitSeq);
  Lbl := CSC_STR_PFX + IntToStr_(StrLitSeq);
  StrLitTab[StrLitCount].Text   := S;
  StrLitTab[StrLitCount].AsmLbl := Lbl;
  AddStrLit := Lbl;
End;

{ ------------------------------------------------------------ }
{ InitConstTable : initialiser la table des constantes nommees  }
{ ------------------------------------------------------------ }

Procedure InitConstTable;
Begin
  ConstCount := 0;
End;

{ ------------------------------------------------------------ }
{ AddConst : ajouter une constante nommee                       }
{   Retourne l index (1-based) ou 0 si table pleine            }
{ ------------------------------------------------------------ }

Function AddConst(Const Name : TString; Value : LongInt;
                  Const SVal : TString; IsS : Boolean;
                  Ln : Integer) : Integer;
Var I : Integer;
Begin
  { Verifier doublon }
  For I := 1 To ConstCount Do
    If ConstTab[I].Name = Name Then
    Begin
      WriteLn('CSCW32: erreur ligne ', Ln,
              ': constante deja definie : ', Name,
              ' (ligne ', ConstTab[I].Line, ')');
      Inc(ErrorCount);
      AddConst := I;
      Exit;
    End;

  If ConstCount >= MAX_CONST Then
  Begin
    WriteLn('CSCW32: erreur: table des constantes pleine (max ',
            MAX_CONST, ')');
    Inc(ErrorCount);
    AddConst := 0;
    Exit;
  End;

  Inc(ConstCount);
  ConstTab[ConstCount].Name   := Name;
  ConstTab[ConstCount].Value  := Value;
  ConstTab[ConstCount].StrVal := SVal;
  ConstTab[ConstCount].IsStr  := IsS;
  ConstTab[ConstCount].Line   := Ln;
  AddConst := ConstCount;
End;

{ ------------------------------------------------------------ }
{ FindConst : chercher une constante par nom                    }
{   Retourne l index (1-based) ou 0 si non trouvee             }
{ ------------------------------------------------------------ }

Function FindConst(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := 1 To ConstCount Do
    If ConstTab[I].Name = Name Then
    Begin
      FindConst := I;
      Exit;
    End;
  FindConst := 0;
End;

{ ------------------------------------------------------------ }
{ EvalConstExpr : evaluer une expression constante simple       }
{   Supporte : entier, hex, char, true/false, null,             }
{              negation unaire (-), identifiant const            }
{   Retourne la valeur LongInt                                  }
{ ------------------------------------------------------------ }

Function EvalConstExpr(Var IsStr : Boolean;
                       Var SVal : TString) : LongInt;
Var
  V     : LongInt;
  Neg   : Boolean;
  Idx   : Integer;
Begin
  V     := 0;
  IsStr := False;
  SVal  := '';
  Neg   := False;

  { Negation unaire }
  If TokIsOp('-') Then
  Begin
    Neg := True;
    Consume;
  End;

  Case CurToken.Kind Of
    TK_INTEGER :
    Begin
      V := CurToken.IntVal;
      Consume;
    End;
    TK_FLOAT :
    Begin
      V := CurToken.IntVal;  { partie entiere tronquee }
      Consume;
    End;
    TK_CHAR :
    Begin
      V := CurToken.IntVal;
      Consume;
    End;
    TK_STRING :
    Begin
      IsStr := True;
      SVal  := CurToken.Val;
      V     := 0;
      Consume;
    End;
    TK_KEYWORD :
    Begin
      If CurToken.Val = 'true' Then
        V := 1
      Else If CurToken.Val = 'false' Then
        V := 0
      Else If CurToken.Val = 'null' Then
        V := 0
      Else
      Begin
        WriteLn('CSCW32: erreur ligne ', CurToken.Line,
                ': mot-cle inattendu dans expression constante : ',
                CurToken.Val);
        Inc(ErrorCount);
      End;
      Consume;
    End;
    TK_IDENT :
    Begin
      Idx := FindConst(CurToken.Val);
      If Idx > 0 Then
      Begin
        V     := ConstTab[Idx].Value;
        IsStr := ConstTab[Idx].IsStr;
        SVal  := ConstTab[Idx].StrVal;
      End
      Else
      Begin
        WriteLn('CSCW32: erreur ligne ', CurToken.Line,
                ': identifiant inconnu dans expression constante : ',
                CurToken.Val);
        Inc(ErrorCount);
      End;
      Consume;
    End;
  Else
    WriteLn('CSCW32: erreur ligne ', CurToken.Line,
            ': valeur attendue dans expression constante');
    Inc(ErrorCount);
    Consume;
  End;

  If Neg Then V := -V;
  EvalConstExpr := V;
End;

{ ------------------------------------------------------------ }
{ ParseConstDecl : analyser  const type nom = expr;             }
{   Le mot-cle 'const' a deja ete consomme                     }
{ ------------------------------------------------------------ }

Procedure ParseConstDecl;
Var
  TypeName  : TString;
  ConstName : TString;
  V         : LongInt;
  IsStr     : Boolean;
  SVal      : TString;
  Ln        : Integer;
Begin
  Ln := CurToken.Line;

  { Type (int, string, bool, char, etc.) }
  If (CurToken.Kind <> TK_KEYWORD) And (CurToken.Kind <> TK_IDENT) Then
  Begin
    WriteLn('CSCW32: erreur ligne ', Ln,
            ': type attendu apres ''const''');
    Inc(ErrorCount);
    { Resynchroniser }
    While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct(';')) Do
      Consume;
    If TokIsPunct(';') Then Consume;
    Exit;
  End;
  TypeName := CurToken.Val;
  Consume;

  { Nom de la constante }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    WriteLn('CSCW32: erreur ligne ', Ln,
            ': identifiant attendu pour le nom de constante');
    Inc(ErrorCount);
    While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct(';')) Do
      Consume;
    If TokIsPunct(';') Then Consume;
    Exit;
  End;
  ConstName := CurToken.Val;
  Consume;

  { Signe = }
  If Not TokIsOp('=') Then
  Begin
    WriteLn('CSCW32: erreur ligne ', Ln,
            ': ''='' attendu apres le nom de constante');
    Inc(ErrorCount);
    While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct(';')) Do
      Consume;
    If TokIsPunct(';') Then Consume;
    Exit;
  End;
  Consume;

  { Expression constante }
  V := EvalConstExpr(IsStr, SVal);

  { Si c est une chaine, l ajouter a la table des litteraux }
  If IsStr Then
    AddStrLit(SVal);

  { Enregistrer la constante }
  AddConst(ConstName, V, SVal, IsStr, Ln);

  { Attendre ; }
  If TokIsPunct(';') Then
    Consume
  Else
  Begin
    WriteLn('CSCW32: erreur ligne ', CurToken.Line,
            ': '';'' attendu apres declaration de constante');
    Inc(ErrorCount);
  End;

  If Opts.Verbose Then
  Begin
    Write('  const ', TypeName, ' ', ConstName, ' = ');
    If IsStr Then
      WriteLn('"', SVal, '"')
    Else
      WriteLn(V);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseLiteral : reconnaitre un litteral et retourner sa valeur }
{   int/hex -> IntVal; char -> IntVal (ordinal);                }
{   string/verbatim -> ajoute a StrLitTab, retourne label;      }
{   true -> 1; false -> 0; null -> 0                            }
{   Retourne True si un litteral a ete reconnu                  }
{ ------------------------------------------------------------ }

Function ParseLiteral(Var IntV : LongInt; Var StrL : TString;
                      Var IsStr : Boolean) : Boolean;
Begin
  ParseLiteral := True;
  IsStr := False;
  StrL  := '';
  IntV  := 0;

  Case CurToken.Kind Of
    TK_INTEGER :
    Begin
      IntV := CurToken.IntVal;
      Consume;
    End;
    TK_FLOAT :
    Begin
      IntV := CurToken.IntVal;  { tronque }
      Consume;
    End;
    TK_CHAR :
    Begin
      IntV := CurToken.IntVal;
      Consume;
    End;
    TK_STRING :
    Begin
      IsStr := True;
      StrL  := AddStrLit(CurToken.Val);
      IntV  := 0;
      Consume;
    End;
    TK_KEYWORD :
    Begin
      If CurToken.Val = 'true' Then
      Begin
        IntV := 1;
        Consume;
      End
      Else If CurToken.Val = 'false' Then
      Begin
        IntV := 0;
        Consume;
      End
      Else If CurToken.Val = 'null' Then
      Begin
        IntV := 0;
        Consume;
      End
      Else
        ParseLiteral := False;
    End;
  Else
    ParseLiteral := False;
  End;
End;

{ ============================================================ }
{ TODO 05 - TABLE DES SYMBOLES                                  }
{           [IMPLEMENTE]                                        }
{ ============================================================ }

Const
  MAX_SYM      = 2048;          { max symboles dans la table         }
  MAX_SCOPE    = 64;            { profondeur max de portees          }

  { Prefixes de mangling ASM 32 bits }
  CSC_VAR_PFX  = '_CSCV_';    { variables globales / champs         }
  CSC_FN_PFX   = '_CSCF_';    { methodes                            }
  { CSC_STR_PFX deja defini = '_CSCK_' pour chaines constantes     }
  CSC_RT_PFX   = '_CSCRT_';   { runtime                             }
  CSC_LBL_PFX  = '_CSCL_';    { labels internes                     }
  CSC_ARR_PFX  = '_CSCA_';    { tableaux                            }
  CSC_CLS_PFX  = '_CSCC_';    { classes                             }
  CSC_NS_PFX   = '_CSCN_';    { namespaces                          }
  CSC_ENUM_PFX = '_CSCE_';    { enumerations                        }
  CSC_ST_PFX   = '_CSCST_';   { variables statiques locales         }

  { Indices predefinis pour les types primitifs C# (TODO 06)     }
  { Definis ici pour usage dans SymInit ci-dessous               }
  TY_IDX_VOID    = 0;
  TY_IDX_INT     = 1;
  TY_IDX_UINT    = 2;
  TY_IDX_LONG    = 3;
  TY_IDX_ULONG   = 4;
  TY_IDX_BOOL    = 5;
  TY_IDX_CHAR    = 6;
  TY_IDX_BYTE    = 7;
  TY_IDX_SBYTE   = 8;
  TY_IDX_SHORT   = 9;
  TY_IDX_USHORT  = 10;
  TY_IDX_FLOAT   = 11;
  TY_IDX_DOUBLE  = 12;
  TY_IDX_DECIMAL = 13;
  TY_IDX_STRING  = 14;
  TY_IDX_OBJECT  = 15;
  TY_PRIM_COUNT  = 16;         { nombre de types primitifs           }

Type
  TSymCat = (
    SC_VAR,          { variable locale ou globale                    }
    SC_PARAM,        { parametre de methode                          }
    SC_METHOD,       { methode (static ou instance)                  }
    SC_CLASS,        { declaration de classe                         }
    SC_FIELD,        { champ d instance                              }
    SC_ENUM_VAL,     { valeur d enumeration                          }
    SC_LABEL,        { label interne (goto etc.)                     }
    SC_STATIC,       { variable/champ statique                       }
    SC_NAMESPACE,    { espace de noms                                }
    SC_CONST         { constante nommee                              }
  );

  TSymRec = Record
    Name        : TString;      { nom C# original (minuscules)      }
    MangledName : TString;      { nom ASM mangled                    }
    Cat         : TSymCat;      { categorie (var/param/method etc.)  }
    TypeIdx     : Integer;      { indice dans la table des types     }
    Offset      : Integer;      { offset EBP si local, 0 si global  }
    ScopeLevel  : Integer;      { niveau de portee (0 = global)      }
    ScopeId     : Integer;      { identifiant unique du scope        }
    IsGlobal    : Boolean;      { True si symbole global             }
    IsStatic    : Boolean;      { True si static                     }
    IsConst     : Boolean;      { True si constante                  }
  End;

Var
  SymTab        : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount      : Integer;      { nombre de symboles enregistres     }
  CurScopeLevel : Integer;      { niveau courant de portee (0-based) }
  CurScopeId    : Integer;      { identifiant courant du scope       }
  ScopeIdSeq    : Integer;      { compteur pour generer des scope id }

{ ------------------------------------------------------------ }
{ SymMangle : generer le nom ASM mangled                        }
{   Le prefixe depend de la categorie du symbole                }
{ ------------------------------------------------------------ }

Function SymMangle(Const Name : TString; Cat : TSymCat) : TString;
Var
  Pfx : TString;
Begin
  Case Cat Of
    SC_VAR       : Pfx := CSC_VAR_PFX;
    SC_PARAM     : Pfx := CSC_VAR_PFX;
    SC_METHOD    : Pfx := CSC_FN_PFX;
    SC_CLASS     : Pfx := CSC_CLS_PFX;
    SC_FIELD     : Pfx := CSC_VAR_PFX;
    SC_ENUM_VAL  : Pfx := CSC_ENUM_PFX;
    SC_LABEL     : Pfx := CSC_LBL_PFX;
    SC_STATIC    : Pfx := CSC_ST_PFX;
    SC_NAMESPACE : Pfx := CSC_NS_PFX;
    SC_CONST     : Pfx := CSC_VAR_PFX;
  Else
    Pfx := CSC_VAR_PFX;
  End;
  SymMangle := Pfx + StrUpperCase(Name);
End;

{ ------------------------------------------------------------ }
{ SymFindInScope : chercher un symbole dans un scope precis     }
{   Retourne l indice (0-based) ou -1 si non trouve             }
{ ------------------------------------------------------------ }

Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I  : Integer;
  Lw : TString;
Begin
  Lw := StrLowerCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Lw) And
       (SymTab[I].ScopeLevel = Level) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  End;
  SymFindInScope := -1;
End;

{ ------------------------------------------------------------ }
{ SymAdd : ajouter un symbole dans la table                     }
{   Retourne l indice (0-based) ou -1 si table pleine           }
{   Verifie les doublons dans le scope courant                  }
{ ------------------------------------------------------------ }

Function SymAdd(Const Name : TString; Cat : TSymCat;
                TIdx : Integer) : Integer;
Var
  Lw  : TString;
  Idx : Integer;
  Dup : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    WriteLn('CSCW32: erreur: table des symboles pleine (max ',
            MAX_SYM, ')');
    Inc(ErrorCount);
    SymAdd := -1;
    Exit;
  End;

  Lw := StrLowerCase(Name);

  { Verifier doublon dans le scope courant }
  Dup := SymFindInScope(Lw, CurScopeLevel);
  If Dup >= 0 Then
  Begin
    { Doublon : avertissement et retour de l existant }
    If Opts.Warnings Then
      WarnMsg('symbole deja declare dans ce scope: ' + Name);
    SymAdd := Dup;
    Exit;
  End;

  Idx := SymCount;
  Inc(SymCount);

  SymTab[Idx].Name        := Lw;
  SymTab[Idx].MangledName := SymMangle(Lw, Cat);
  SymTab[Idx].Cat         := Cat;
  SymTab[Idx].TypeIdx     := TIdx;
  SymTab[Idx].Offset      := 0;
  SymTab[Idx].ScopeLevel  := CurScopeLevel;
  SymTab[Idx].ScopeId     := CurScopeId;
  SymTab[Idx].IsGlobal    := (CurScopeLevel = 0);
  SymTab[Idx].IsStatic    := False;
  SymTab[Idx].IsConst     := (Cat = SC_CONST);

  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', Idx, ']: ', Lw,
            ' cat=', Ord(Cat),
            ' scope=', CurScopeLevel,
            ' -> ', SymTab[Idx].MangledName);

  SymAdd := Idx;
End;

{ ------------------------------------------------------------ }
{ SymFind : chercher un symbole (du plus recent au plus ancien) }
{   Retourne l indice (0-based) ou -1 si non trouve             }
{   Parcourt du scope le plus interne vers le global            }
{ ------------------------------------------------------------ }

Function SymFind(Const Name : TString) : Integer;
Var
  I  : Integer;
  Lw : TString;
Begin
  Lw := StrLowerCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Lw) And
       (SymTab[I].ScopeLevel <= CurScopeLevel) Then
    Begin
      SymFind := I;
      Exit;
    End;
  End;
  SymFind := -1;
End;

{ ------------------------------------------------------------ }
{ SymEnterScope : entrer dans un nouveau scope                  }
{ ------------------------------------------------------------ }

Procedure SymEnterScope;
Begin
  If CurScopeLevel >= MAX_SCOPE Then
  Begin
    WriteLn('CSCW32: erreur: profondeur de scope maximale atteinte');
    Inc(ErrorCount);
    Exit;
  End;
  Inc(CurScopeLevel);
  Inc(ScopeIdSeq);
  CurScopeId := ScopeIdSeq;
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScopeLevel,
            ' id=', CurScopeId);
End;

{ ------------------------------------------------------------ }
{ SymLeaveScope : quitter le scope courant                      }
{   Les symboles restent dans la table mais ne seront plus      }
{   trouves par SymFind car ScopeLevel > CurScopeLevel          }
{ ------------------------------------------------------------ }

Procedure SymLeaveScope;
Begin
  If CurScopeLevel <= 0 Then
  Begin
    If Opts.Warnings Then
      WarnMsg('tentative de quitter le scope global');
    Exit;
  End;
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE: level=', CurScopeLevel);
  Dec(CurScopeLevel);
  If CurScopeLevel = 0 Then
    CurScopeId := 0
  Else
    CurScopeId := CurScopeLevel;
End;

{ ------------------------------------------------------------ }
{ SymInit : initialiser la table et pre-enregistrer les         }
{   methodes standard C# built-in                              }
{ ------------------------------------------------------------ }

Procedure SymInit;
Var
  Idx : Integer;
Begin
  SymCount      := 0;
  CurScopeLevel := 0;
  CurScopeId    := 0;
  ScopeIdSeq    := 0;

  { Methodes standard C# pre-enregistrees (built-in) }
  { Console.Write (int/string/bool/char) -> void }
  Idx := SymAdd('Console.Write', SC_METHOD, TY_IDX_VOID);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].MangledName := CSC_RT_PFX + 'PRINT';
    SymTab[Idx].IsStatic := True;
  End;

  { Console.WriteLine (int/string/bool/char) -> void }
  Idx := SymAdd('Console.WriteLine', SC_METHOD, TY_IDX_VOID);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].MangledName := CSC_RT_PFX + 'PRINTLN';
    SymTab[Idx].IsStatic := True;
  End;

  { Console.ReadLine -> string }
  Idx := SymAdd('Console.ReadLine', SC_METHOD, TY_IDX_STRING);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].MangledName := CSC_RT_PFX + 'READSTR';
    SymTab[Idx].IsStatic := True;
  End;

  { int.Parse -> int }
  Idx := SymAdd('int.Parse', SC_METHOD, TY_IDX_INT);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].MangledName := CSC_RT_PFX + 'STRTONUM';
    SymTab[Idx].IsStatic := True;
  End;

  { int.ToString -> string }
  Idx := SymAdd('int.ToString', SC_METHOD, TY_IDX_STRING);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].MangledName := CSC_RT_PFX + 'NUMTOSTR';
    SymTab[Idx].IsStatic := True;
  End;

  { Math.Abs -> int }
  Idx := SymAdd('Math.Abs', SC_METHOD, TY_IDX_INT);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].MangledName := CSC_RT_PFX + 'ABS';
    SymTab[Idx].IsStatic := True;
  End;

  { Math.Max -> int }
  Idx := SymAdd('Math.Max', SC_METHOD, TY_IDX_INT);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].MangledName := CSC_RT_PFX + 'MAX';
    SymTab[Idx].IsStatic := True;
  End;

  { Math.Min -> int }
  Idx := SymAdd('Math.Min', SC_METHOD, TY_IDX_INT);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].MangledName := CSC_RT_PFX + 'MIN';
    SymTab[Idx].IsStatic := True;
  End;

  { Convert.ToInt32 -> int }
  Idx := SymAdd('Convert.ToInt32', SC_METHOD, TY_IDX_INT);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].MangledName := CSC_RT_PFX + 'STRTONUM';
    SymTab[Idx].IsStatic := True;
  End;

  { Convert.ToString -> string }
  Idx := SymAdd('Convert.ToString', SC_METHOD, TY_IDX_STRING);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].MangledName := CSC_RT_PFX + 'NUMTOSTR';
    SymTab[Idx].IsStatic := True;
  End;
End;

{ ------------------------------------------------------------ }
{ SymCatName : nom textuel d une categorie de symbole           }
{ ------------------------------------------------------------ }

Function SymCatName(Cat : TSymCat) : TString;
Begin
  Case Cat Of
    SC_VAR       : SymCatName := 'VAR';
    SC_PARAM     : SymCatName := 'PARAM';
    SC_METHOD    : SymCatName := 'METHOD';
    SC_CLASS     : SymCatName := 'CLASS';
    SC_FIELD     : SymCatName := 'FIELD';
    SC_ENUM_VAL  : SymCatName := 'ENUM_VAL';
    SC_LABEL     : SymCatName := 'LABEL';
    SC_STATIC    : SymCatName := 'STATIC';
    SC_NAMESPACE : SymCatName := 'NAMESPACE';
    SC_CONST     : SymCatName := 'CONST';
  Else
    SymCatName := '?';
  End;
End;

{ ============================================================ }
{ TODO 06 - SYSTEME DE TYPES                                    }
{           [IMPLEMENTE]                                        }
{ ============================================================ }

Const
  MAX_TYPE      = 256;          { max types dans la table            }

Type
  TTypeKind = (
    TKP_VOID,        { void - pas de valeur                          }
    TKP_INT,         { int  - 32 bits signe                          }
    TKP_UINT,        { uint - 32 bits non signe                      }
    TKP_LONG,        { long - 64 bits stub (tronque a 32 bits)       }
    TKP_ULONG,       { ulong - 64 bits non signe stub (tronque 32)   }
    TKP_BOOL,        { bool - 8 bits (stocke comme DWORD)            }
    TKP_CHAR,        { char - 16 bits Unicode stub (stocke 8 bits)   }
    TKP_BYTE,        { byte - 8 bits non signe                       }
    TKP_SBYTE,       { sbyte - 8 bits signe                          }
    TKP_SHORT,       { short - 16 bits signe                         }
    TKP_USHORT,      { ushort - 16 bits non signe                    }
    TKP_FLOAT,       { float - 32 bits flottant (stub entier)        }
    TKP_DOUBLE,      { double - 64 bits flottant (stub entier)       }
    TKP_DECIMAL,     { decimal - 128 bits stub (stocke 64 bits)      }
    TKP_STRING,      { string - pointeur 32 bits vers ASCIIZ         }
    TKP_OBJECT,      { object - pointeur 32 bits generique           }
    TKP_ARRAY,       { tableau                                       }
    TKP_CLASS,       { classe utilisateur                             }
    TKP_ENUM         { enumeration                                    }
  );

  TTypeRec = Record
    Name     : TString;         { nom C# du type (minuscules)        }
    Kind     : TTypeKind;       { categorie du type                   }
    Size     : Integer;         { taille en octets (32 bits)          }
    Signed   : Boolean;         { True si type signe                  }
    ElemType : Integer;         { index du type element (array/ptr)   }
  End;

Var
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;          { nombre de types enregistres         }

{ ------------------------------------------------------------ }
{ TypeAdd : ajouter un type dans la table                       }
{   Retourne l indice du type ajoute, ou -1 si table pleine     }
{ ------------------------------------------------------------ }

Function TypeAdd(Const AName : TString; AKind : TTypeKind;
                 ASize : Integer; ASigned : Boolean;
                 AElem : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
  Begin
    WriteLn('CSCW32: erreur: table des types pleine (max ',
            MAX_TYPE, ')');
    Inc(ErrorCount);
    TypeAdd := -1;
    Exit;
  End;
  Idx := TypeCount;
  Inc(TypeCount);
  TypeTab[Idx].Name     := AName;
  TypeTab[Idx].Kind     := AKind;
  TypeTab[Idx].Size     := ASize;
  TypeTab[Idx].Signed   := ASigned;
  TypeTab[Idx].ElemType := AElem;
  TypeAdd := Idx;
End;

{ ------------------------------------------------------------ }
{ TypeInit : initialiser les types primitifs C# predefinis      }
{   Les indices doivent correspondre aux TY_IDX_* constants     }
{ ------------------------------------------------------------ }

Procedure TypeInit;
Begin
  TypeCount := 0;

  { 0 : void }
  TypeAdd('void',    TKP_VOID,    0, False, -1);
  { 1 : int (System.Int32) }
  TypeAdd('int',     TKP_INT,     4, True,  -1);
  { 2 : uint (System.UInt32) }
  TypeAdd('uint',    TKP_UINT,    4, False, -1);
  { 3 : long (System.Int64) - stub tronque a 32 bits }
  TypeAdd('long',    TKP_LONG,    4, True,  -1);
  { 4 : ulong (System.UInt64) - stub tronque a 32 bits }
  TypeAdd('ulong',   TKP_ULONG,   4, False, -1);
  { 5 : bool (System.Boolean) }
  TypeAdd('bool',    TKP_BOOL,    1, False, -1);
  { 6 : char (System.Char) - stub 8 bits ASCII }
  TypeAdd('char',    TKP_CHAR,    1, False, -1);
  { 7 : byte (System.Byte) }
  TypeAdd('byte',    TKP_BYTE,    1, False, -1);
  { 8 : sbyte (System.SByte) }
  TypeAdd('sbyte',   TKP_SBYTE,   1, True,  -1);
  { 9 : short (System.Int16) }
  TypeAdd('short',   TKP_SHORT,   2, True,  -1);
  { 10 : ushort (System.UInt16) }
  TypeAdd('ushort',  TKP_USHORT,  2, False, -1);
  { 11 : float (System.Single) - stub entier }
  TypeAdd('float',   TKP_FLOAT,   4, True,  -1);
  { 12 : double (System.Double) - stub entier }
  TypeAdd('double',  TKP_DOUBLE,  8, True,  -1);
  { 13 : decimal (System.Decimal) - stub entier }
  TypeAdd('decimal', TKP_DECIMAL, 8, True,  -1);
  { 14 : string (System.String) }
  TypeAdd('string',  TKP_STRING,  4, False, -1);
  { 15 : object (System.Object) }
  TypeAdd('object',  TKP_OBJECT,  4, False, -1);

  If Opts.DebugMode Then
    WriteLn('  TYPE_INIT: ', TypeCount, ' types primitifs enregistres');
End;

{ ------------------------------------------------------------ }
{ TypeFind : chercher un type par nom                           }
{   Retourne l indice (0-based) ou -1 si non trouve             }
{   Gere les alias System.* (System.Int32 -> int, etc.)         }
{ ------------------------------------------------------------ }

Function TypeFind(Const Name : TString) : Integer;
Var
  I    : Integer;
  Lw   : TString;
  Alias: TString;
Begin
  Lw := StrLowerCase(Name);

  { Gerer les alias .NET Framework vers mots-cles C# }
  Alias := Lw;
  If Lw = 'system.int32'   Then Alias := 'int'
  Else If Lw = 'system.uint32'  Then Alias := 'uint'
  Else If Lw = 'system.int64'   Then Alias := 'long'
  Else If Lw = 'system.uint64'  Then Alias := 'ulong'
  Else If Lw = 'system.boolean' Then Alias := 'bool'
  Else If Lw = 'system.char'    Then Alias := 'char'
  Else If Lw = 'system.byte'    Then Alias := 'byte'
  Else If Lw = 'system.sbyte'   Then Alias := 'sbyte'
  Else If Lw = 'system.int16'   Then Alias := 'short'
  Else If Lw = 'system.uint16'  Then Alias := 'ushort'
  Else If Lw = 'system.single'  Then Alias := 'float'
  Else If Lw = 'system.double'  Then Alias := 'double'
  Else If Lw = 'system.decimal' Then Alias := 'decimal'
  Else If Lw = 'system.string'  Then Alias := 'string'
  Else If Lw = 'system.object'  Then Alias := 'object'
  Else If Lw = 'system.void'    Then Alias := 'void'
  Else If Lw = 'int32'          Then Alias := 'int'
  Else If Lw = 'uint32'         Then Alias := 'uint'
  Else If Lw = 'int64'          Then Alias := 'long'
  Else If Lw = 'uint64'         Then Alias := 'ulong'
  Else If Lw = 'int16'          Then Alias := 'short'
  Else If Lw = 'uint16'         Then Alias := 'ushort'
  Else If Lw = 'single'         Then Alias := 'float';

  For I := 0 To TypeCount - 1 Do
  Begin
    If TypeTab[I].Name = Alias Then
    Begin
      TypeFind := I;
      Exit;
    End;
  End;
  TypeFind := -1;
End;

{ ------------------------------------------------------------ }
{ TypeFromKeyword : mapper un mot-cle C# de type vers TypeIdx   }
{   Retourne l indice du type ou -1 si pas un type reconnu      }
{ ------------------------------------------------------------ }

Function TypeFromKeyword(Const Kw : TString) : Integer;
Var
  Lw : TString;
Begin
  Lw := StrLowerCase(Kw);
  If      Lw = 'void'    Then TypeFromKeyword := TY_IDX_VOID
  Else If Lw = 'int'     Then TypeFromKeyword := TY_IDX_INT
  Else If Lw = 'uint'    Then TypeFromKeyword := TY_IDX_UINT
  Else If Lw = 'long'    Then TypeFromKeyword := TY_IDX_LONG
  Else If Lw = 'ulong'   Then TypeFromKeyword := TY_IDX_ULONG
  Else If Lw = 'bool'    Then TypeFromKeyword := TY_IDX_BOOL
  Else If Lw = 'char'    Then TypeFromKeyword := TY_IDX_CHAR
  Else If Lw = 'byte'    Then TypeFromKeyword := TY_IDX_BYTE
  Else If Lw = 'sbyte'   Then TypeFromKeyword := TY_IDX_SBYTE
  Else If Lw = 'short'   Then TypeFromKeyword := TY_IDX_SHORT
  Else If Lw = 'ushort'  Then TypeFromKeyword := TY_IDX_USHORT
  Else If Lw = 'float'   Then TypeFromKeyword := TY_IDX_FLOAT
  Else If Lw = 'double'  Then TypeFromKeyword := TY_IDX_DOUBLE
  Else If Lw = 'decimal' Then TypeFromKeyword := TY_IDX_DECIMAL
  Else If Lw = 'string'  Then TypeFromKeyword := TY_IDX_STRING
  Else If Lw = 'object'  Then TypeFromKeyword := TY_IDX_OBJECT
  Else                         TypeFromKeyword := -1;
End;

{ ------------------------------------------------------------ }
{ TypeSizeof : retourner la taille en octets d un type          }
{   Si l indice est invalide, retourne 4 (taille par defaut)    }
{ ------------------------------------------------------------ }

Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 4;  { defaut : DWord 32 bits }
End;

{ ------------------------------------------------------------ }
{ TypeKindOf : retourner le TTypeKind d un type                 }
{ ------------------------------------------------------------ }

Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Kind
  Else
    TypeKindOf := TKP_INT;  { defaut }
End;

{ ------------------------------------------------------------ }
{ TypeKindName : nom textuel d un TTypeKind                     }
{ ------------------------------------------------------------ }

Function TypeKindName(K : TTypeKind) : TString;
Begin
  Case K Of
    TKP_VOID    : TypeKindName := 'void';
    TKP_INT     : TypeKindName := 'int';
    TKP_UINT    : TypeKindName := 'uint';
    TKP_LONG    : TypeKindName := 'long';
    TKP_ULONG   : TypeKindName := 'ulong';
    TKP_BOOL    : TypeKindName := 'bool';
    TKP_CHAR    : TypeKindName := 'char';
    TKP_BYTE    : TypeKindName := 'byte';
    TKP_SBYTE   : TypeKindName := 'sbyte';
    TKP_SHORT   : TypeKindName := 'short';
    TKP_USHORT  : TypeKindName := 'ushort';
    TKP_FLOAT   : TypeKindName := 'float';
    TKP_DOUBLE  : TypeKindName := 'double';
    TKP_DECIMAL : TypeKindName := 'decimal';
    TKP_STRING  : TypeKindName := 'string';
    TKP_OBJECT  : TypeKindName := 'object';
    TKP_ARRAY   : TypeKindName := 'array';
    TKP_CLASS   : TypeKindName := 'class';
    TKP_ENUM    : TypeKindName := 'enum';
  Else
    TypeKindName := '?';
  End;
End;

{ ------------------------------------------------------------ }
{ TypeIsNumeric : True si le type est un type numerique         }
{ ------------------------------------------------------------ }

Function TypeIsNumeric(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsNumeric :=
    (K = TKP_INT)    Or (K = TKP_UINT)    Or
    (K = TKP_LONG)   Or (K = TKP_ULONG)   Or
    (K = TKP_BYTE)   Or (K = TKP_SBYTE)   Or
    (K = TKP_SHORT)  Or (K = TKP_USHORT)  Or
    (K = TKP_FLOAT)  Or (K = TKP_DOUBLE)  Or
    (K = TKP_DECIMAL) Or (K = TKP_CHAR);
End;

{ ------------------------------------------------------------ }
{ TypeIsIntegral : True si le type est un entier (pas float)    }
{ ------------------------------------------------------------ }

Function TypeIsIntegral(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsIntegral :=
    (K = TKP_INT)   Or (K = TKP_UINT)   Or
    (K = TKP_LONG)  Or (K = TKP_ULONG)  Or
    (K = TKP_BYTE)  Or (K = TKP_SBYTE)  Or
    (K = TKP_SHORT) Or (K = TKP_USHORT) Or
    (K = TKP_CHAR);
End;

{ ------------------------------------------------------------ }
{ TypeCompatible : verification de compatibilite d affectation  }
{   True si une valeur de type FromType peut etre affectee      }
{   a une variable de type ToType (avec conversion implicite)   }
{ ------------------------------------------------------------ }

Function TypeCompatible(FromType, ToType : Integer) : Boolean;
Var
  FK, TK : TTypeKind;
Begin
  { Meme type : toujours compatible }
  If FromType = ToType Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Types invalides : non compatible }
  If (FromType < 0) Or (FromType >= TypeCount) Or
     (ToType < 0) Or (ToType >= TypeCount) Then
  Begin
    TypeCompatible := False;
    Exit;
  End;

  FK := TypeTab[FromType].Kind;
  TK := TypeTab[ToType].Kind;

  { void n est compatible avec rien }
  If (FK = TKP_VOID) Or (TK = TKP_VOID) Then
  Begin
    TypeCompatible := False;
    Exit;
  End;

  { object accepte tout (boxing implicite) }
  If TK = TKP_OBJECT Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Conversions implicites numeriques elargissantes (widening) }
  { byte/sbyte/short/ushort/char -> int OK }
  If TK = TKP_INT Then
  Begin
    TypeCompatible :=
      (FK = TKP_BYTE)  Or (FK = TKP_SBYTE) Or
      (FK = TKP_SHORT) Or (FK = TKP_USHORT) Or
      (FK = TKP_CHAR);
    Exit;
  End;

  { byte/sbyte/short/ushort/char/int/uint -> long OK }
  If TK = TKP_LONG Then
  Begin
    TypeCompatible :=
      (FK = TKP_BYTE)   Or (FK = TKP_SBYTE)  Or
      (FK = TKP_SHORT)  Or (FK = TKP_USHORT) Or
      (FK = TKP_CHAR)   Or (FK = TKP_INT)    Or
      (FK = TKP_UINT);
    Exit;
  End;

  { byte/ushort/char -> uint OK }
  If TK = TKP_UINT Then
  Begin
    TypeCompatible :=
      (FK = TKP_BYTE)  Or (FK = TKP_USHORT) Or
      (FK = TKP_CHAR);
    Exit;
  End;

  { byte/ushort/uint/char -> ulong OK }
  If TK = TKP_ULONG Then
  Begin
    TypeCompatible :=
      (FK = TKP_BYTE)   Or (FK = TKP_USHORT) Or
      (FK = TKP_UINT)   Or (FK = TKP_CHAR);
    Exit;
  End;

  { entiers -> float/double/decimal OK }
  If (TK = TKP_FLOAT) Or (TK = TKP_DOUBLE) Or
     (TK = TKP_DECIMAL) Then
  Begin
    TypeCompatible := TypeIsNumeric(FromType);
    Exit;
  End;

  { Aucune autre conversion implicite }
  TypeCompatible := False;
End;

{ ------------------------------------------------------------ }
{ TypeCoerce : conversion implicite d un type petit vers int    }
{   Retourne TY_IDX_INT si le type source est un petit entier   }
{   (byte, sbyte, short, ushort, char) ; sinon retourne le      }
{   type source tel quel.                                       }
{ ------------------------------------------------------------ }

Function TypeCoerce(FromType : Integer) : Integer;
Var
  FK : TTypeKind;
Begin
  If (FromType < 0) Or (FromType >= TypeCount) Then
  Begin
    TypeCoerce := FromType;
    Exit;
  End;
  FK := TypeTab[FromType].Kind;
  If (FK = TKP_BYTE)   Or (FK = TKP_SBYTE) Or
     (FK = TKP_SHORT)  Or (FK = TKP_USHORT) Or
     (FK = TKP_CHAR) Then
    TypeCoerce := TY_IDX_INT
  Else
    TypeCoerce := FromType;
End;

{ ============================================================ }
{ TODO 07 - EMETTEUR DE CODE ASM 80386                         }
{ ============================================================ }
{                                                               }
{  Emetteur de code assembleur Intel 80386, format MASM/TASM.   }
{  Gere l ouverture/fermeture du fichier .asm, l ecriture       }
{  de lignes brutes, labels, instructions, commentaires.        }
{  Genere l en-tete (.386, .MODEL FLAT, EXTRN) et les           }
{  prologues/epilogues de sous-programmes (PUSH EBP, etc.).     }
{                                                               }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ GenLabel                                                      }
{   Generer un label unique _CSCL_NNNNN                         }
{ ------------------------------------------------------------ }

Function GenLabel : TString;
Var S : TString;
Begin
  Str(LabelSeq, S);
  While Length(S) < 5 Do
    S := '0' + S;
  GenLabel := '_CSCL_' + S;
  Inc(LabelSeq);
End;

{ ------------------------------------------------------------ }
{ EmitOpen                                                      }
{   Ouvrir le fichier .asm pour l emission                      }
{ ------------------------------------------------------------ }

Procedure EmitOpen;
Begin
  AsmFileName := ReplaceExt(Opts.SrcFile, '.asm');
  Assign(OutF, AsmFileName);
  {$I-}
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible de creer le fichier ASM: ' + AsmFileName);
  OutFOpen := True;
  If Opts.DebugMode Then
    WriteLn('  EMIT_OPEN: ', AsmFileName);
End;

{ ------------------------------------------------------------ }
{ EmitClose                                                     }
{   Fermer le fichier .asm                                      }
{ ------------------------------------------------------------ }

Procedure EmitClose;
Begin
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    If Opts.DebugMode Then
      WriteLn('  EMIT_CLOSE: ', AsmFileName);
  End;
End;

{ ------------------------------------------------------------ }
{ EmitRaw(s)                                                    }
{   Ecrire une ligne brute dans le fichier .asm                 }
{ ------------------------------------------------------------ }

Procedure EmitRaw(S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

{ ------------------------------------------------------------ }
{ EmitLabel(lbl)                                                }
{   Ecrire un label suivi de ':' dans le fichier .asm           }
{ ------------------------------------------------------------ }

Procedure EmitLabel(Lbl : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, Lbl, ':');
End;

{ ------------------------------------------------------------ }
{ EmitInstr(op, args)                                           }
{   Ecrire une instruction avec indentation de 8 espaces        }
{ ------------------------------------------------------------ }

Procedure EmitInstr(Op : TString; Args : TString);
Begin
  If OutFOpen Then
  Begin
    If Args = '' Then
      WriteLn(OutF, '        ', Op)
    Else
      WriteLn(OutF, '        ', Op, ' ', Args);
  End;
End;

{ ------------------------------------------------------------ }
{ EmitComment(msg)                                              }
{   Ecrire un commentaire ; msg                                 }
{ ------------------------------------------------------------ }

Procedure EmitComment(Msg : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '; ', Msg);
End;

{ ------------------------------------------------------------ }
{ EmitBlankLine                                                 }
{   Ecrire une ligne vide                                       }
{ ------------------------------------------------------------ }

Procedure EmitBlankLine;
Begin
  If OutFOpen Then
    WriteLn(OutF);
End;

{ ------------------------------------------------------------ }
{ EmitHeader                                                    }
{   Ecrire l en-tete du fichier assembleur :                    }
{   .386 / .MODEL FLAT, STDCALL / EXTRN APIs                   }
{ ------------------------------------------------------------ }

Procedure EmitHeader;
Begin
  EmitComment('Genere par CSCW32 - Compilateur C# vers 80386 Win32');
  EmitComment('Source : ' + Opts.SrcFile);
  EmitBlankLine;
  EmitRaw('.386');
  EmitRaw('.MODEL FLAT, STDCALL');
  EmitBlankLine;
  EmitComment('Imports Win32 API (kernel32.dll)');
  EmitRaw('EXTRN _ExitProcess@4:NEAR');
  EmitRaw('EXTRN _GetStdHandle@4:NEAR');
  EmitRaw('EXTRN _WriteFile@20:NEAR');
  EmitRaw('EXTRN _ReadFile@20:NEAR');
  EmitRaw('EXTRN _GetProcessHeap@0:NEAR');
  EmitRaw('EXTRN _HeapAlloc@12:NEAR');
  EmitRaw('EXTRN _HeapFree@12:NEAR');
  EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ EmitDataSeg                                                   }
{   Ecrire le segment .DATA depuis DataTab et StrLitTab         }
{ ------------------------------------------------------------ }

Procedure EmitDataSeg;
Var
  I, J  : Integer;
  S     : TString;
  Ch    : Char;
  InStr : Boolean;
Begin
  EmitRaw('.DATA');
  EmitBlankLine;

  { Emettre les constantes chaines du StrLitTab }
  EmitComment('Constantes chaines');
  For I := 1 To StrLitCount Do
  Begin
    EmitRaw(StrLitTab[I].AsmLbl + ' DB "' + StrLitTab[I].Text + '",0');
  End;
  EmitBlankLine;

  { Emettre les entrees du DataTab }
  EmitComment('Donnees statiques (DataTab)');
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_DWORD :
        EmitRaw(DataTab[I].LblName + ' DD ' +
                IntToStr_(DataTab[I].IntVal));
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + ' DB ' +
                IntToStr_(DataTab[I].IntVal));
      DK_STR :
      Begin
        { Gerer les caracteres de controle en numerique }
        S := '';
        InStr := False;
        For J := 1 To Length(DataTab[I].StrVal) Do
        Begin
          Ch := DataTab[I].StrVal[J];
          If (Ord(Ch) < 32) Or (Ord(Ch) > 126) Then
          Begin
            If InStr Then
            Begin
              S := S + '",';
              InStr := False;
            End;
            S := S + IntToStr_(Ord(Ch)) + ',';
          End
          Else
          Begin
            If Not InStr Then
            Begin
              S := S + '"';
              InStr := True;
            End;
            S := S + Ch;
          End;
        End;
        If InStr Then
          S := S + '",';
        S := S + '0';
        EmitRaw(DataTab[I].LblName + ' DB ' + S);
      End;
      DK_ARRAY :
        EmitRaw(DataTab[I].LblName + ' DB ' +
                IntToStr_(DataTab[I].ElemCount) + ' DUP(0)');
      DK_ZERO :
        EmitRaw(DataTab[I].LblName + ' DB ' +
                IntToStr_(DataTab[I].ElemCount) + ' DUP(0)');
    End;
  End;
  EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ EmitCodeSeg                                                   }
{   Ouvrir le segment .CODE                                     }
{ ------------------------------------------------------------ }

Procedure EmitCodeSeg;
Begin
  EmitRaw('.CODE');
  EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ EmitProlog(locals)                                            }
{   PUSH EBP / MOV EBP,ESP / SUB ESP,locals                    }
{ ------------------------------------------------------------ }

Procedure EmitProlog(Locals : Integer);
Var S : TString;
Begin
  EmitInstr('PUSH', 'EBP');
  EmitInstr('MOV', 'EBP,ESP');
  If Locals > 0 Then
  Begin
    Str(Locals, S);
    EmitInstr('SUB', 'ESP,' + S);
  End;
End;

{ ------------------------------------------------------------ }
{ EmitEpilog                                                    }
{   MOV ESP,EBP / POP EBP / RET                                }
{ ------------------------------------------------------------ }

Procedure EmitEpilog;
Begin
  EmitInstr('MOV', 'ESP,EBP');
  EmitInstr('POP', 'EBP');
  EmitInstr('RET', '');
End;

{ ------------------------------------------------------------ }
{ EmitFooter                                                    }
{   Ecrire la fin du fichier assembleur (END directive)         }
{ ------------------------------------------------------------ }

Procedure EmitFooter;
Begin
  EmitBlankLine;
  EmitRaw('END _CSCF_MAIN');
End;

{ ============================================================ }
{ TODO 08 - SEGMENT DE DONNEES ET STATIQUES                     }
{ ============================================================ }
{                                                               }
{  Gestion du segment de donnees (.DATA) avec une table         }
{  generique DataTab. Chaque entree decrit un label dans le     }
{  segment .DATA avec son type (DWORD, BYTE, chaine, tableau,   }
{  bloc zero). DataInit pre-peuple la table avec les tampons    }
{  I/O, handles et CRLF. DataAddGlobalVar et DataAddStaticVar   }
{  permettent de declarer des variables globales et statiques.   }
{                                                               }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ DataAdd                                                       }
{   Ajouter une entree generique dans DataTab                   }
{   Retourne l index dans DataTab ou -1 si plein                }
{ ------------------------------------------------------------ }

Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    FatalError('segment DATA plein (max=' + IntToStr_(MAX_DATA) + ')');
    DataAdd := -1;
    Exit;
  End;
  DataTab[DataCount].LblName   := Lbl;
  DataTab[DataCount].Kind      := Kind;
  DataTab[DataCount].IntVal    := AIntVal;
  DataTab[DataCount].StrVal    := AStrVal;
  DataTab[DataCount].ElemCount := 0;
  DataAdd := DataCount;
  Inc(DataCount);
End;

{ ------------------------------------------------------------ }
{ DataAddStr                                                    }
{   Ajouter une constante chaine DB "abc",0 dans DataTab        }
{   Deduplique : si la chaine existe deja, retourne son index   }
{   Retourne l index dans DataTab                               }
{ ------------------------------------------------------------ }

Function DataAddStr(Const S : TString) : Integer;
Var
  I   : Integer;
  Lbl : TString;
Begin
  { Rechercher un doublon existant }
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataAddStr := I;
      Exit;
    End;
  { Nouvelle entree }
  Inc(StrLitSeq);
  Lbl := CSC_STR_PFX + IntToStr_(StrLitSeq);
  DataAddStr := DataAdd(Lbl, DK_STR, 0, S);
End;

{ ------------------------------------------------------------ }
{ DataAddDWord                                                  }
{   Ajouter un DWORD (DD valeur) dans DataTab                   }
{ ------------------------------------------------------------ }

Function DataAddDWord(Const Lbl : TString; Val : LongInt) : Integer;
Begin
  DataAddDWord := DataAdd(Lbl, DK_DWORD, Val, '');
End;

{ ------------------------------------------------------------ }
{ DataAddByte                                                   }
{   Ajouter un BYTE (DB valeur) dans DataTab                    }
{ ------------------------------------------------------------ }

Function DataAddByte(Const Lbl : TString; Val : Integer) : Integer;
Begin
  DataAddByte := DataAdd(Lbl, DK_BYTE, Val, '');
End;

{ ------------------------------------------------------------ }
{ DataAddArray                                                  }
{   Ajouter un tableau (DB count DUP(0)) dans DataTab           }
{   count = nombre d octets a reserver                          }
{ ------------------------------------------------------------ }

Function DataAddArray(Const Lbl : TString; Count : Integer) : Integer;
Var Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_ARRAY, 0, '');
  If Idx >= 0 Then
    DataTab[Idx].ElemCount := Count;
  DataAddArray := Idx;
End;

{ ------------------------------------------------------------ }
{ DataAddZero                                                   }
{   Ajouter un bloc initialise a zero (DB size DUP(0))          }
{ ------------------------------------------------------------ }

Function DataAddZero(Const Lbl : TString; Size : Integer) : Integer;
Var Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_ZERO, 0, '');
  If Idx >= 0 Then
    DataTab[Idx].ElemCount := Size;
  DataAddZero := Idx;
End;

{ ------------------------------------------------------------ }
{ DataAddGlobalVar                                              }
{   Creer une variable globale _CSCV_nom dans .DATA             }
{   selon le type : DD pour 4 octets, DB pour 1 octet, etc.    }
{ ------------------------------------------------------------ }

Function DataAddGlobalVar(Const VarName : TString; TypeIdx : Integer) : Integer;
Var
  Lbl  : TString;
  Size : Integer;
Begin
  Lbl := '_CSCV_' + VarName;
  Size := TypeSizeof(TypeIdx);
  If Size >= 4 Then
    DataAddGlobalVar := DataAddDWord(Lbl, 0)
  Else If Size = 1 Then
    DataAddGlobalVar := DataAddByte(Lbl, 0)
  Else
    DataAddGlobalVar := DataAddZero(Lbl, Size);
End;

{ ------------------------------------------------------------ }
{ DataAddStaticVar                                              }
{   Creer une variable statique _CSCST_N dans .DATA             }
{ ------------------------------------------------------------ }

Function DataAddStaticVar(Const ClassName, VarName : TString;
                          TypeIdx : Integer) : Integer;
Var
  Lbl  : TString;
  Size : Integer;
  S    : TString;
Begin
  Inc(StaticSeq);
  Str(StaticSeq, S);
  Lbl := '_CSCST_' + S;
  Size := TypeSizeof(TypeIdx);
  If Size >= 4 Then
    DataAddStaticVar := DataAddDWord(Lbl, 0)
  Else If Size = 1 Then
    DataAddStaticVar := DataAddByte(Lbl, 0)
  Else
    DataAddStaticVar := DataAddZero(Lbl, Size);
End;

{ ------------------------------------------------------------ }
{ DataInit                                                      }
{   Pre-peupler le segment DATA avec les donnees de base :      }
{   CRLF, tampons I/O, handles, etc.                            }
{ ------------------------------------------------------------ }

Procedure DataInit;
Begin
  DataCount := 0;
  StaticSeq := 0;

  { Retour chariot CRLF }
  DataAdd('_CSC_CRLF', DK_STR, 0, #13#10);

  { Chaine vide }
  DataAdd('_CSC_EMPTY', DK_STR, 0, '');

  { Tampons I/O }
  DataAddArray('_CSC_INBUF',  256);    { tampon lecture 256 octets       }
  DataAddArray('_CSC_NUMBUF', 16);     { tampon conversion nombre        }

  { Handles et variables systeme }
  DataAddDWord('_CSC_HSTDOUT', 0);     { handle stdout                   }
  DataAddDWord('_CSC_HSTDIN',  0);     { handle stdin                    }
  DataAddDWord('_CSC_HHEAP',   0);     { handle heap                     }
  DataAddDWord('_CSC_WRITTEN', 0);     { octets ecrits (WriteFile)       }
  DataAddDWord('_CSC_READCNT', 0);     { octets lus (ReadFile)           }

  { Ajouter les constantes chaines du StrLitTab existant }
  { (Elles seront peuplees pendant l analyse, puis emises }
  {  par EmitDataSeg)                                      }
End;

{ ============================================================ }
{ TODO 09 - VARIABLES ET DECLARATIONS                           }
{           [IMPLEMENTE]                                        }
{ ============================================================ }
{                                                               }
{  Gestion des declarations de variables C# :                   }
{  - Champs statiques de classe : segment .DATA via DataTab     }
{  - Variables locales : pile [EBP-offset] avec LocalOffset     }
{  - Parametres de methode : [EBP+8], [EBP+12], ...             }
{  - Declarations simples, avec init et multiples               }
{  - Qualificateurs const, static, readonly                     }
{  - Portee de bloc (variables locales au bloc)                  }
{                                                               }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ AlignDWord : aligner une taille sur 4 octets (32 bits)        }
{   Retourne la taille alignee vers le haut                     }
{ ------------------------------------------------------------ }

Function AlignDWord(Size : Integer) : Integer;
Begin
  If Size <= 0 Then
    AlignDWord := 4
  Else If (Size Mod 4) = 0 Then
    AlignDWord := Size
  Else
    AlignDWord := Size + (4 - (Size Mod 4));
End;

{ ------------------------------------------------------------ }
{ AllocLocal : allouer une variable locale sur la pile          }
{   Decremente LocalOffset de Size octets (aligne a 4)         }
{   Retourne le nouvel offset negatif [EBP-n]                   }
{ ------------------------------------------------------------ }

Function AllocLocal(Size : Integer) : Integer;
Var Aligned : Integer;
Begin
  Aligned := AlignDWord(Size);
  LocalOffset := LocalOffset + Aligned;
  AllocLocal := -LocalOffset;
End;

{ ------------------------------------------------------------ }
{ RegisterParam : enregistrer un parametre de methode           }
{   Assigne [EBP+offset] (8, 12, 16, ...) au parametre         }
{   Retourne l offset positif attribue                          }
{ ------------------------------------------------------------ }

Function RegisterParam : Integer;
Var Off : Integer;
Begin
  Off := ParamOffset;
  Inc(ParamOffset, 4);  { chaque parametre occupe 4 octets sur x86-32 }
  RegisterParam := Off;
End;

{ ------------------------------------------------------------ }
{ ResetLocals : reinitialiser les compteurs de pile             }
{   Appele au debut de chaque methode                           }
{ ------------------------------------------------------------ }

Procedure ResetLocals;
Begin
  LocalOffset := 0;
  ParamOffset := 8;  { EBP+0 = old EBP, EBP+4 = ret addr, EBP+8 = 1st param }
End;

{ ------------------------------------------------------------ }
{ IsTypeKeyword : verifier si un token est un mot-cle de type   }
{   Retourne True si le token courant est un type C# primitif   }
{ ------------------------------------------------------------ }

Function IsTypeKeyword : Boolean;
Begin
  IsTypeKeyword :=
    (TokIsKw('int'))     Or (TokIsKw('string'))  Or
    (TokIsKw('bool'))    Or (TokIsKw('char'))    Or
    (TokIsKw('double'))  Or (TokIsKw('float'))   Or
    (TokIsKw('long'))    Or (TokIsKw('short'))   Or
    (TokIsKw('byte'))    Or (TokIsKw('sbyte'))   Or
    (TokIsKw('uint'))    Or (TokIsKw('ulong'))   Or
    (TokIsKw('ushort'))  Or (TokIsKw('decimal')) Or
    (TokIsKw('object'))  Or (TokIsKw('void'));
End;

{ ------------------------------------------------------------ }
{ GenInitLocal : emettre le code d initialisation d une         }
{   variable locale [EBP+off] = valeur                          }
{   Valeur est un entier immediat                               }
{ ------------------------------------------------------------ }

Procedure GenInitLocal(Off : Integer; Val : LongInt);
Var
  SzOff : TString;
  SzVal : TString;
Begin
  If Not OutFOpen Then Exit;  { pas encore en phase d emission }
  Str(Off, SzOff);
  Str(Val, SzVal);
  If Off < 0 Then
    EmitInstr('MOV', 'DWORD PTR [EBP' + SzOff + '],' + SzVal)
  Else
    EmitInstr('MOV', 'DWORD PTR [EBP+' + SzOff + '],' + SzVal);
End;

{ ------------------------------------------------------------ }
{ GenInitLocalStr : emettre le code d initialisation d une      }
{   variable locale [EBP+off] = OFFSET label_chaine             }
{ ------------------------------------------------------------ }

Procedure GenInitLocalStr(Off : Integer; Const Lbl : TString);
Var
  SzOff : TString;
Begin
  If Not OutFOpen Then Exit;  { pas encore en phase d emission }
  Str(Off, SzOff);
  If Off < 0 Then
    EmitInstr('MOV', 'DWORD PTR [EBP' + SzOff + '],OFFSET ' + Lbl)
  Else
    EmitInstr('MOV', 'DWORD PTR [EBP+' + SzOff + '],OFFSET ' + Lbl);
End;

{ ------------------------------------------------------------ }
{ ParseVarDecl : analyser une declaration de variable           }
{   Appelee quand VarType est deja connu (mot-cle de type lu)   }
{   Gere les declarations simples, avec init et multiples       }
{   IsStatic = True pour les champs statiques de classe         }
{   ClassName = nom de la classe (pour les statiques)           }
{ ------------------------------------------------------------ }

Procedure ParseVarDecl(Const VarType : TString; IsStatic : Boolean;
                       Const ClassName : TString);
Var
  VarName  : TString;
  TIdx     : Integer;
  SymIdx   : Integer;
  Off      : Integer;
  HasInit  : Boolean;
  InitVal  : LongInt;
  InitStr  : TString;
  InitIsStr: Boolean;
  StrLbl   : TString;          { label ASM de la chaine (_CSCK_N)    }
  First    : Boolean;
Begin
  TIdx := TypeFromKeyword(VarType);

  First := True;
  Repeat
    If Not First Then
    Begin
      { Sauter la virgule pour les declarations multiples }
      If TokIsPunct(',') Then
        Consume
      Else
        Exit;
    End;
    First := False;

    { Lire le nom de la variable }
    If CurToken.Kind <> TK_IDENT Then Exit;
    VarName := CurToken.Val;
    Consume;

    HasInit   := False;
    InitVal   := 0;
    InitStr   := '';
    InitIsStr := False;
    StrLbl    := '';

    { Verifier s il y a une initialisation = expr }
    If TokIsOp('=') Then
    Begin
      Consume;
      HasInit := True;

      { Evaluer l expression d initialisation simple }
      If CurToken.Kind = TK_INTEGER Then
      Begin
        InitVal := CurToken.IntVal;
        Consume;
      End
      Else If CurToken.Kind = TK_CHAR Then
      Begin
        If Length(CurToken.Val) > 0 Then
          InitVal := Ord(CurToken.Val[1])
        Else
          InitVal := 0;
        Consume;
      End
      Else If CurToken.Kind = TK_STRING Then
      Begin
        InitIsStr := True;
        InitStr   := CurToken.Val;
        StrLbl    := AddStrLit(InitStr);
        Consume;
      End
      Else If TokIsKw('true') Then
      Begin
        InitVal := 1;
        Consume;
      End
      Else If TokIsKw('false') Then
      Begin
        InitVal := 0;
        Consume;
      End
      Else If TokIsKw('null') Then
      Begin
        InitVal := 0;
        Consume;
      End
      Else If CurToken.Kind = TK_IDENT Then
      Begin
        { Verifier si c est une constante connue }
        SymIdx := FindConst(CurToken.Val);
        If SymIdx >= 0 Then
        Begin
          If ConstTab[SymIdx].IsStr Then
          Begin
            InitIsStr := True;
            InitStr   := ConstTab[SymIdx].StrVal;
            StrLbl    := AddStrLit(InitStr);
          End
          Else
            InitVal := ConstTab[SymIdx].Value;
        End;
        Consume;
      End
      Else If TokIsOp('-') Then
      Begin
        { Negation : -expr }
        Consume;
        If CurToken.Kind = TK_INTEGER Then
        Begin
          InitVal := -CurToken.IntVal;
          Consume;
        End
        Else
          Consume; { skip unknown }
      End
      Else
      Begin
        { Expression inconnue - sauter jusqu au ; ou , }
        While (CurToken.Kind <> TK_EOF) And
              (Not TokIsPunct(';')) And (Not TokIsPunct(',')) Do
          Consume;
      End;
    End;

    { Ajouter le symbole et allouer le stockage }
    If IsStatic Then
    Begin
      { Variable statique -> segment .DATA }
      SymIdx := SymAdd(VarName, SC_STATIC, TIdx);
      If SymIdx >= 0 Then
      Begin
        SymTab[SymIdx].IsStatic := True;
        SymTab[SymIdx].IsGlobal := True;
        Off := DataAddStaticVar(ClassName, VarName, TIdx);
        { Si init avec valeur, mettre la valeur dans DataTab }
        If HasInit And (Off >= 0) Then
        Begin
          If InitIsStr Then
          Begin
            { Pour une chaine statique, stocker un DWORD pointeur }
            DataTab[Off].Kind   := DK_DWORD;
            DataTab[Off].IntVal := 0;  { sera resolu par le linker }
          End
          Else
            DataTab[Off].IntVal := InitVal;
        End;
        If Opts.DebugMode Then
          WriteLn('  VAR_STATIC: ', VarName, ' type=', VarType,
                  ' data=', Off);
      End;
    End
    Else
    Begin
      { Variable locale -> pile [EBP-offset] }
      Off := AllocLocal(TypeSizeof(TIdx));
      SymIdx := SymAdd(VarName, SC_VAR, TIdx);
      If SymIdx >= 0 Then
      Begin
        SymTab[SymIdx].Offset := Off;
        { Emettre l initialisation si requise }
        If HasInit Then
        Begin
          If InitIsStr Then
          Begin
            If Length(StrLbl) > 0 Then
              GenInitLocalStr(Off, StrLbl)
            Else
              GenInitLocal(Off, 0);
          End
          Else
            GenInitLocal(Off, InitVal);
        End
        Else
        Begin
          { Initialisation par defaut a zero }
          GenInitLocal(Off, 0);
        End;
      End;
      If Opts.DebugMode Then
        WriteLn('  VAR_LOCAL: ', VarName, ' type=', VarType,
                ' offset=[EBP', Off, ']');
    End;
  Until TokIsPunct(';') Or (CurToken.Kind = TK_EOF);
End;

{ ============================================================ }
{ TODO 10 - EXPRESSIONS PRIMAIRES                               }
{           [IMPLEMENTE]                                        }
{ ============================================================ }
{                                                               }
{  Generateurs de code pour charger des valeurs dans EAX :      }
{  - GenLoadConst : immediat entier -> MOV EAX,valeur           }
{  - GenLoadStr : label chaine -> MOV EAX,OFFSET label          }
{  - GenLoadVar : variable/parametre/statique -> MOV EAX,[...]  }
{  - GenPushEAX / GenPopEBX : sauvegarde sur la pile            }
{  - GenNeg : negation arithmetique -> NEG EAX                  }
{  - GenLogNot : negation logique -> TEST+SETZ+MOVZX            }
{  - GenBitNot : complement bit a bit -> NOT EAX                }
{  - GenIncVar / GenDecVar : ++/-- sur variable                 }
{                                                               }
{  ParsePrimary : analyse d une expression primaire C# :        }
{  - literal entier, chaine, true, false, null                  }
{  - identificateur (variable, parametre, champ statique)       }
{  - appel de methode ident(args)                               }
{  - expression entre parentheses (expr)                        }
{  - operateurs unaires prefixes : - ! ~ ++ --                  }
{  - operateur new type[taille]                                 }
{  - suffixes post-increment/decrement : expr++ expr--          }
{  - indexation tableau : expr[index]                           }
{                                                               }
{  ParseExpr : appelle ParseExprPrec(0) (voir TODO 11)           }
{                                                               }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ GenLoadConst : charger une constante entiere dans EAX         }
{   MOV EAX, valeur                                             }
{ ------------------------------------------------------------ }

Procedure GenLoadConst(Val : LongInt);
Var S : TString;
Begin
  Str(Val, S);
  EmitInstr('MOV', 'EAX,' + S);
End;

{ ------------------------------------------------------------ }
{ GenLoadStr : charger l adresse d une chaine dans EAX          }
{   MOV EAX, OFFSET label                                      }
{ ------------------------------------------------------------ }

Procedure GenLoadStr(Const Lbl : TString);
Begin
  EmitInstr('MOV', 'EAX,OFFSET ' + Lbl);
End;

{ ------------------------------------------------------------ }
{ GenLoadVar : charger une variable dans EAX                    }
{   Selon la categorie du symbole :                             }
{   - SC_VAR locale : MOV EAX,[EBP-offset]                     }
{   - SC_PARAM      : MOV EAX,[EBP+offset]                     }
{   - SC_STATIC     : MOV EAX,[_CSCST_label]                   }
{   - SC_VAR globale: MOV EAX,[_CSCV_nom]                      }
{   - SC_CONST      : MOV EAX,valeur constante                 }
{ ------------------------------------------------------------ }

Procedure GenLoadVar(Idx : Integer);
Var
  S : TString;
  Off : Integer;
  CI : Integer;
Begin
  If Idx < 0 Then
  Begin
    EmitComment('GenLoadVar: symbole inconnu');
    EmitInstr('XOR', 'EAX,EAX');
    Exit;
  End;

  { Constante nommee : charger sa valeur }
  If SymTab[Idx].Cat = SC_CONST Then
  Begin
    CI := FindConst(SymTab[Idx].Name);
    If CI > 0 Then
    Begin
      If ConstTab[CI].IsStr Then
        EmitInstr('MOV', 'EAX,OFFSET ' +
                  AddStrLit(ConstTab[CI].StrVal))
      Else
      Begin
        Str(ConstTab[CI].Value, S);
        EmitInstr('MOV', 'EAX,' + S);
      End;
    End
    Else
      EmitInstr('XOR', 'EAX,EAX');
    Exit;
  End;

  Off := SymTab[Idx].Offset;

  { Variable locale ou parametre : acces via EBP }
  If (SymTab[Idx].Cat = SC_VAR) And (Not SymTab[Idx].IsGlobal) Then
  Begin
    Str(Off, S);
    If Off < 0 Then
      EmitInstr('MOV', 'EAX,DWORD PTR [EBP' + S + ']')
    Else
      EmitInstr('MOV', 'EAX,DWORD PTR [EBP+' + S + ']');
  End
  Else If SymTab[Idx].Cat = SC_PARAM Then
  Begin
    Str(Off, S);
    EmitInstr('MOV', 'EAX,DWORD PTR [EBP+' + S + ']');
  End
  { Variable statique ou globale : acces par label }
  Else If (SymTab[Idx].Cat = SC_STATIC) Or
          (SymTab[Idx].IsGlobal) Then
  Begin
    EmitInstr('MOV', 'EAX,DWORD PTR [' +
              SymTab[Idx].MangledName + ']');
  End
  Else
  Begin
    { Fallback : acces par label mangled }
    EmitInstr('MOV', 'EAX,DWORD PTR [' +
              SymTab[Idx].MangledName + ']');
  End;
End;

{ ------------------------------------------------------------ }
{ GenStoreVar : stocker EAX dans une variable                   }
{   Selon la categorie du symbole :                             }
{   - SC_VAR locale : MOV [EBP-offset],EAX                     }
{   - SC_PARAM      : MOV [EBP+offset],EAX                     }
{   - SC_STATIC     : MOV [_CSCST_label],EAX                   }
{   - SC_VAR globale: MOV [_CSCV_nom],EAX                      }
{ ------------------------------------------------------------ }

Procedure GenStoreVar(Idx : Integer);
Var
  S : TString;
  Off : Integer;
Begin
  If Idx < 0 Then
  Begin
    EmitComment('GenStoreVar: symbole inconnu');
    Exit;
  End;

  Off := SymTab[Idx].Offset;

  If (SymTab[Idx].Cat = SC_VAR) And (Not SymTab[Idx].IsGlobal) Then
  Begin
    Str(Off, S);
    If Off < 0 Then
      EmitInstr('MOV', 'DWORD PTR [EBP' + S + '],EAX')
    Else
      EmitInstr('MOV', 'DWORD PTR [EBP+' + S + '],EAX');
  End
  Else If SymTab[Idx].Cat = SC_PARAM Then
  Begin
    Str(Off, S);
    EmitInstr('MOV', 'DWORD PTR [EBP+' + S + '],EAX');
  End
  Else If (SymTab[Idx].Cat = SC_STATIC) Or
          (SymTab[Idx].IsGlobal) Then
  Begin
    EmitInstr('MOV', 'DWORD PTR [' +
              SymTab[Idx].MangledName + '],EAX');
  End
  Else
  Begin
    EmitInstr('MOV', 'DWORD PTR [' +
              SymTab[Idx].MangledName + '],EAX');
  End;
End;

{ ------------------------------------------------------------ }
{ GenPushEAX : sauvegarder EAX sur la pile                      }
{ ------------------------------------------------------------ }

Procedure GenPushEAX;
Begin
  EmitInstr('PUSH', 'EAX');
End;

{ ------------------------------------------------------------ }
{ GenPopEBX : restaurer la valeur dans EBX depuis la pile       }
{ ------------------------------------------------------------ }

Procedure GenPopEBX;
Begin
  EmitInstr('POP', 'EBX');
End;

{ ------------------------------------------------------------ }
{ GenNeg : negation arithmetique (NEG EAX)                      }
{ ------------------------------------------------------------ }

Procedure GenNeg;
Begin
  EmitInstr('NEG', 'EAX');
End;

{ ------------------------------------------------------------ }
{ GenLogNot : negation logique                                  }
{   TEST EAX,EAX / SETZ AL / MOVZX EAX,AL                     }
{   Resultat : EAX = 1 si etait 0, 0 sinon                     }
{ ------------------------------------------------------------ }

Procedure GenLogNot;
Begin
  EmitInstr('TEST', 'EAX,EAX');
  EmitInstr('SETZ', 'AL');
  EmitInstr('MOVZX', 'EAX,AL');
End;

{ ------------------------------------------------------------ }
{ GenBitNot : complement bit a bit (NOT EAX)                    }
{ ------------------------------------------------------------ }

Procedure GenBitNot;
Begin
  EmitInstr('NOT', 'EAX');
End;

{ ------------------------------------------------------------ }
{ GenIncVar : incrementer une variable                          }
{   INC DWORD PTR [var]                                         }
{ ------------------------------------------------------------ }

Procedure GenIncVar(Idx : Integer);
Var
  S : TString;
  Off : Integer;
Begin
  If Idx < 0 Then Exit;
  Off := SymTab[Idx].Offset;

  If (SymTab[Idx].Cat = SC_VAR) And (Not SymTab[Idx].IsGlobal) Then
  Begin
    Str(Off, S);
    If Off < 0 Then
      EmitInstr('INC', 'DWORD PTR [EBP' + S + ']')
    Else
      EmitInstr('INC', 'DWORD PTR [EBP+' + S + ']');
  End
  Else If SymTab[Idx].Cat = SC_PARAM Then
  Begin
    Str(Off, S);
    EmitInstr('INC', 'DWORD PTR [EBP+' + S + ']');
  End
  Else
    EmitInstr('INC', 'DWORD PTR [' + SymTab[Idx].MangledName + ']');
End;

{ ------------------------------------------------------------ }
{ GenDecVar : decrementer une variable                          }
{   DEC DWORD PTR [var]                                         }
{ ------------------------------------------------------------ }

Procedure GenDecVar(Idx : Integer);
Var
  S : TString;
  Off : Integer;
Begin
  If Idx < 0 Then Exit;
  Off := SymTab[Idx].Offset;

  If (SymTab[Idx].Cat = SC_VAR) And (Not SymTab[Idx].IsGlobal) Then
  Begin
    Str(Off, S);
    If Off < 0 Then
      EmitInstr('DEC', 'DWORD PTR [EBP' + S + ']')
    Else
      EmitInstr('DEC', 'DWORD PTR [EBP+' + S + ']');
  End
  Else If SymTab[Idx].Cat = SC_PARAM Then
  Begin
    Str(Off, S);
    EmitInstr('DEC', 'DWORD PTR [EBP+' + S + ']');
  End
  Else
    EmitInstr('DEC', 'DWORD PTR [' + SymTab[Idx].MangledName + ']');
End;

{ ------------------------------------------------------------ }
{ ParsePrimary : analyser une expression primaire C#            }
{   Resultat dans EAX.                                          }
{   Gere : literaux, idents, appels, parentheses, unaires,     }
{          new type[taille], indexation, post-inc/dec.           }
{ ------------------------------------------------------------ }

Procedure ParsePrimary;
Var
  SavedName : TString;
  QualName  : TString;
  Idx       : Integer;
  Lbl       : TString;
  ArgCount  : Integer;
Begin
  { --- Literal entier --- }
  If CurToken.Kind = TK_INTEGER Then
  Begin
    GenLoadConst(CurToken.IntVal);
    Consume;
  End
  { --- Literal chaine --- }
  Else If CurToken.Kind = TK_STRING Then
  Begin
    Lbl := AddStrLit(CurToken.Val);
    GenLoadStr(Lbl);
    Consume;
  End
  { --- Literal caractere --- }
  Else If CurToken.Kind = TK_CHAR Then
  Begin
    If Length(CurToken.Val) > 0 Then
      GenLoadConst(Ord(CurToken.Val[1]))
    Else
      GenLoadConst(0);
    Consume;
  End
  { --- true --- }
  Else If TokIsKw('true') Then
  Begin
    GenLoadConst(1);
    Consume;
  End
  { --- false --- }
  Else If TokIsKw('false') Then
  Begin
    GenLoadConst(0);
    Consume;
  End
  { --- null --- }
  Else If TokIsKw('null') Then
  Begin
    GenLoadConst(0);
    Consume;
  End
  { --- Expression entre parentheses --- }
  Else If TokIsPunct('(') Then
  Begin
    Consume;  { consommer ( }
    ParseExpr;
    If TokIsPunct(')') Then
      Consume;  { consommer ) }
  End
  { --- Negation unaire -expr --- }
  Else If TokIsOp('-') Then
  Begin
    Consume;
    ParsePrimary;
    GenNeg;
  End
  { --- Negation logique !expr --- }
  Else If TokIsOp('!') Then
  Begin
    Consume;
    ParsePrimary;
    GenLogNot;
  End
  { --- Complement bit a bit ~expr --- }
  Else If TokIsOp('~') Then
  Begin
    Consume;
    ParsePrimary;
    GenBitNot;
  End
  { --- Pre-increment ++ident --- }
  Else If TokIsOp('++') Then
  Begin
    Consume;
    If CurToken.Kind = TK_IDENT Then
    Begin
      Idx := SymFind(CurToken.Val);
      Consume;
      GenIncVar(Idx);
      GenLoadVar(Idx);
    End
    Else
    Begin
      ParsePrimary;
      { Fallback : ne peut pas incrementer un non-ident }
    End;
  End
  { --- Pre-decrement --ident --- }
  Else If TokIsOp('--') Then
  Begin
    Consume;
    If CurToken.Kind = TK_IDENT Then
    Begin
      Idx := SymFind(CurToken.Val);
      Consume;
      GenDecVar(Idx);
      GenLoadVar(Idx);
    End
    Else
    Begin
      ParsePrimary;
    End;
  End
  { --- new type[taille] : allocation de tableau --- }
  Else If TokIsKw('new') Then
  Begin
    Consume;
    { Lire le type de l element }
    If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Consume;
    { Lire [taille] }
    If TokIsPunct('[') Then
    Begin
      Consume;
      ParseExpr;  { taille dans EAX }
      If TokIsPunct(']') Then Consume;
      { Multiplier par sizeof(element) = 4 (DWORD par defaut) }
      EmitInstr('SHL', 'EAX,2');  { *4 }
      { Appeler HeapAlloc(hHeap, flags, size)  STDCALL }
      { Arguments pushes en ordre inverse }
      EmitInstr('PUSH', 'EAX');                   { dwBytes  }
      EmitInstr('PUSH', '0');                      { dwFlags  }
      EmitInstr('CALL', '_GetProcessHeap@0');
      EmitInstr('PUSH', 'EAX');                   { hHeap    }
      EmitInstr('CALL', '_HeapAlloc@12');
      { Resultat : EAX = pointeur vers le bloc alloue }
    End
    Else
    Begin
      { new Type() - simple allocation objet (stub) }
      EmitComment('new objet (stub)');
      EmitInstr('XOR', 'EAX,EAX');
    End;
  End
  { --- Identificateur --- }
  Else If CurToken.Kind = TK_IDENT Then
  Begin
    SavedName := CurToken.Val;
    Consume;

    { Construire un nom qualifie (ex: Console.WriteLine) }
    QualName := SavedName;
    While TokIsPunct('.') Do
    Begin
      Consume;
      If CurToken.Kind = TK_IDENT Then
      Begin
        QualName := QualName + '.' + CurToken.Val;
        Consume;
      End;
    End;

    { Appel de methode : ident(...) }
    If TokIsPunct('(') Then
    Begin
      Idx := SymFind(QualName);
      Consume;  { consommer ( }
      ArgCount := 0;
      { Evaluer et empiler les arguments }
      While (CurToken.Kind <> TK_EOF) And
            (Not TokIsPunct(')')) Do
      Begin
        ParseExpr;
        GenPushEAX;
        Inc(ArgCount);
        If TokIsPunct(',') Then Consume;
      End;
      If TokIsPunct(')') Then Consume;
      { Appeler la methode }
      If Idx >= 0 Then
        EmitInstr('CALL', SymTab[Idx].MangledName)
      Else
      Begin
        EmitComment('appel methode inconnue: ' + QualName);
        EmitInstr('CALL', CSC_FN_PFX + StrUpperCase(QualName));
      End;
      { Nettoyer la pile (convention CDECL pour les args) }
      { Note: les built-in sont STDCALL, le callee nettoie }
      { Pour les methodes utilisateur on utilise aussi STDCALL }
    End
    { Indexation tableau : ident[index] }
    Else If TokIsPunct('[') Then
    Begin
      Idx := SymFind(QualName);
      GenLoadVar(Idx);
      GenPushEAX;  { sauver l adresse de base }
      Consume;  { consommer [ }
      ParseExpr;  { index dans EAX }
      If TokIsPunct(']') Then Consume;
      { Calculer l adresse : base + index*4 }
      EmitInstr('SHL', 'EAX,2');     { index * 4 }
      GenPopEBX;                      { base dans EBX }
      EmitInstr('ADD', 'EAX,EBX');   { adresse element }
      EmitInstr('MOV', 'EAX,DWORD PTR [EAX]');  { charger valeur }
    End
    { Post-increment : ident++ }
    Else If TokIsOp('++') Then
    Begin
      Idx := SymFind(QualName);
      GenLoadVar(Idx);   { valeur avant dans EAX }
      GenIncVar(Idx);    { incrementer la variable }
      Consume;           { consommer ++ }
    End
    { Post-decrement : ident-- }
    Else If TokIsOp('--') Then
    Begin
      Idx := SymFind(QualName);
      GenLoadVar(Idx);   { valeur avant dans EAX }
      GenDecVar(Idx);    { decrementer la variable }
      Consume;           { consommer -- }
    End
    { Variable simple ou constante }
    Else
    Begin
      Idx := SymFind(QualName);
      If Idx >= 0 Then
        GenLoadVar(Idx)
      Else
      Begin
        { Peut etre une constante nommee }
        Idx := FindConst(StrLowerCase(QualName));
        If Idx > 0 Then
        Begin
          If ConstTab[Idx].IsStr Then
            GenLoadStr(AddStrLit(ConstTab[Idx].StrVal))
          Else
            GenLoadConst(ConstTab[Idx].Value);
        End
        Else
        Begin
          EmitComment('symbole inconnu: ' + QualName);
          EmitInstr('XOR', 'EAX,EAX');
        End;
      End;
    End;
  End
  { --- Literal flottant (stub : tronque en entier) --- }
  Else If CurToken.Kind = TK_FLOAT Then
  Begin
    GenLoadConst(CurToken.IntVal);
    Consume;
  End
  { --- Token inconnu --- }
  Else
  Begin
    EmitComment('expression primaire inattendue: ' + CurToken.Val);
    EmitInstr('XOR', 'EAX,EAX');
    Consume;
  End;
End;

{ ============================================================ }
{ TODO 11 - OPERATEURS ET PRECEDENCE                            }
{           [IMPLEMENTE]                                        }
{ ============================================================ }
{                                                               }
{  GetBinOpPrec : retourne la precedence d un operateur binaire }
{    0 si pas un operateur binaire.                             }
{  GenBinOp(Op) : generer le code pour Op avec LHS=EBX RHS=EAX }
{  ParseExprPrec(MinPrec) : boucle de precedence Pratt          }
{    avec court-circuit pour && || et ?? (null-coalescing).     }
{  ParseExpr : appelle ParseExprPrec(0).                        }
{                                                               }
{  Precedence (du plus fort au plus faible) :                   }
{    12 : * / %           (multiplicatif)                       }
{    11 : + -             (additif)                             }
{    10 : << >>           (decalage)                            }
{     9 : < <= > >=       (relationnel)                         }
{     8 : == !=           (egalite)                             }
{     7 : &               (ET bit a bit)                        }
{     6 : ^               (OU exclusif)                         }
{     5 : |               (OU bit a bit)                        }
{     4 : &&              (ET logique, court-circuit)            }
{     3 : ||              (OU logique, court-circuit)            }
{     2 : ??              (null-coalescing)                      }
{                                                               }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ GetBinOpPrec : retourner la precedence d un operateur binaire }
{   Retourne 0 si ce n est pas un operateur binaire connu.      }
{   Plus la valeur est haute, plus l operateur lie fort.         }
{ ------------------------------------------------------------ }

Function GetBinOpPrec : Integer;
Begin
  If CurToken.Kind <> TK_OP Then
  Begin
    GetBinOpPrec := 0;
    Exit;
  End;

  If (CurToken.Val = '*') Or (CurToken.Val = '/') Or
     (CurToken.Val = '%') Then
    GetBinOpPrec := 12
  Else If (CurToken.Val = '+') Or (CurToken.Val = '-') Then
    GetBinOpPrec := 11
  Else If (CurToken.Val = '<<') Or (CurToken.Val = '>>') Then
    GetBinOpPrec := 10
  Else If (CurToken.Val = '<') Or (CurToken.Val = '<=') Or
          (CurToken.Val = '>') Or (CurToken.Val = '>=') Then
    GetBinOpPrec := 9
  Else If (CurToken.Val = '==') Or (CurToken.Val = '!=') Then
    GetBinOpPrec := 8
  Else If CurToken.Val = '&' Then
    GetBinOpPrec := 7
  Else If CurToken.Val = '^' Then
    GetBinOpPrec := 6
  Else If CurToken.Val = '|' Then
    GetBinOpPrec := 5
  Else If CurToken.Val = '&&' Then
    GetBinOpPrec := 4
  Else If CurToken.Val = '||' Then
    GetBinOpPrec := 3
  Else If CurToken.Val = '??' Then
    GetBinOpPrec := 2
  Else
    GetBinOpPrec := 0;
End;

{ ------------------------------------------------------------ }
{ GenBinOp : generer le code pour un operateur binaire          }
{   LHS dans EBX (pop), RHS dans EAX.                          }
{   Resultat dans EAX.                                          }
{ ------------------------------------------------------------ }

Procedure GenBinOp(Const Op : TString);
Begin
  { Addition : EBX + EAX }
  If Op = '+' Then
    EmitInstr('ADD', 'EAX,EBX')
  { Soustraction : EBX - EAX }
  Else If Op = '-' Then
  Begin
    EmitInstr('SUB', 'EBX,EAX');
    EmitInstr('MOV', 'EAX,EBX');
  End
  { Multiplication : EAX * EBX }
  Else If Op = '*' Then
    EmitInstr('IMUL', 'EAX,EBX')
  { Division entiere signee : EBX / EAX }
  Else If Op = '/' Then
  Begin
    EmitInstr('MOV', 'ECX,EAX');
    EmitInstr('MOV', 'EAX,EBX');
    EmitInstr('CDQ', '');
    EmitInstr('IDIV', 'ECX');
  End
  { Modulo : EBX % EAX -> reste dans EDX }
  Else If Op = '%' Then
  Begin
    EmitInstr('MOV', 'ECX,EAX');
    EmitInstr('MOV', 'EAX,EBX');
    EmitInstr('CDQ', '');
    EmitInstr('IDIV', 'ECX');
    EmitInstr('MOV', 'EAX,EDX');
  End
  { Decalage gauche : EBX << EAX }
  Else If Op = '<<' Then
  Begin
    EmitInstr('MOV', 'ECX,EAX');
    EmitInstr('MOV', 'EAX,EBX');
    EmitInstr('SHL', 'EAX,CL');
  End
  { Decalage droit : EBX >> EAX }
  Else If Op = '>>' Then
  Begin
    EmitInstr('MOV', 'ECX,EAX');
    EmitInstr('MOV', 'EAX,EBX');
    EmitInstr('SHR', 'EAX,CL');
  End
  { Egalite : EBX == EAX }
  Else If Op = '==' Then
  Begin
    EmitInstr('CMP', 'EBX,EAX');
    EmitInstr('SETE', 'AL');
    EmitInstr('MOVZX', 'EAX,AL');
  End
  { Inegalite : EBX != EAX }
  Else If Op = '!=' Then
  Begin
    EmitInstr('CMP', 'EBX,EAX');
    EmitInstr('SETNE', 'AL');
    EmitInstr('MOVZX', 'EAX,AL');
  End
  { Inferieur : EBX < EAX }
  Else If Op = '<' Then
  Begin
    EmitInstr('CMP', 'EBX,EAX');
    EmitInstr('SETL', 'AL');
    EmitInstr('MOVZX', 'EAX,AL');
  End
  { Inferieur ou egal : EBX <= EAX }
  Else If Op = '<=' Then
  Begin
    EmitInstr('CMP', 'EBX,EAX');
    EmitInstr('SETLE', 'AL');
    EmitInstr('MOVZX', 'EAX,AL');
  End
  { Superieur : EBX > EAX }
  Else If Op = '>' Then
  Begin
    EmitInstr('CMP', 'EBX,EAX');
    EmitInstr('SETG', 'AL');
    EmitInstr('MOVZX', 'EAX,AL');
  End
  { Superieur ou egal : EBX >= EAX }
  Else If Op = '>=' Then
  Begin
    EmitInstr('CMP', 'EBX,EAX');
    EmitInstr('SETGE', 'AL');
    EmitInstr('MOVZX', 'EAX,AL');
  End
  { ET bit a bit : EBX & EAX }
  Else If Op = '&' Then
    EmitInstr('AND', 'EAX,EBX')
  { OU bit a bit : EBX | EAX }
  Else If Op = '|' Then
    EmitInstr('OR', 'EAX,EBX')
  { OU exclusif : EBX ^ EAX }
  Else If Op = '^' Then
    EmitInstr('XOR', 'EAX,EBX')
  Else
    EmitComment('operateur binaire inconnu: ' + Op);
End;

{ ------------------------------------------------------------ }
{ ParseExprPrec : boucle de precedence Pratt                    }
{   MinPrec : precedence minimale pour continuer a parser.      }
{   Resultat dans EAX.                                          }
{   Les operateurs && et || utilisent le court-circuit.         }
{   L operateur ?? teste si EAX est null (0).                   }
{ ------------------------------------------------------------ }

Procedure ParseExprPrec(MinPrec : Integer);
Var
  Op       : TString;
  Prec     : Integer;
  LblA     : TString;
  LblEnd   : TString;
Begin
  ParsePrimary;

  While True Do
  Begin
    Prec := GetBinOpPrec;
    If (Prec = 0) Or (Prec < MinPrec) Then
      Break;

    Op := CurToken.Val;
    Consume;

    { --- Court-circuit pour && (ET logique) --- }
    If Op = '&&' Then
    Begin
      LblA   := GenLabel;
      LblEnd := GenLabel;
      EmitInstr('TEST', 'EAX,EAX');
      EmitInstr('JZ', LblA);
      ParseExprPrec(Prec + 1);
      EmitInstr('TEST', 'EAX,EAX');
      EmitInstr('JZ', LblA);
      EmitInstr('MOV', 'EAX,1');
      EmitInstr('JMP', LblEnd);
      EmitLabel(LblA);
      EmitInstr('XOR', 'EAX,EAX');
      EmitLabel(LblEnd);
    End
    { --- Court-circuit pour || (OU logique) --- }
    Else If Op = '||' Then
    Begin
      LblA   := GenLabel;
      LblEnd := GenLabel;
      EmitInstr('TEST', 'EAX,EAX');
      EmitInstr('JNZ', LblA);
      ParseExprPrec(Prec + 1);
      EmitInstr('TEST', 'EAX,EAX');
      EmitInstr('JNZ', LblA);
      EmitInstr('XOR', 'EAX,EAX');
      EmitInstr('JMP', LblEnd);
      EmitLabel(LblA);
      EmitInstr('MOV', 'EAX,1');
      EmitLabel(LblEnd);
    End
    { --- Null-coalescing ?? (associatif a droite) --- }
    Else If Op = '??' Then
    Begin
      LblEnd := GenLabel;
      EmitInstr('TEST', 'EAX,EAX');
      EmitInstr('JNZ', LblEnd);
      ParseExprPrec(Prec);
      EmitLabel(LblEnd);
    End
    { --- Operateurs binaires standards --- }
    Else
    Begin
      GenPushEAX;
      ParseExprPrec(Prec + 1);
      GenPopEBX;
      GenBinOp(Op);
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseExpr : analyser une expression complete                  }
{   Appelle ParseExprPrec avec precedence minimale 0.           }
{ ------------------------------------------------------------ }

Procedure ParseExpr;
Begin
  ParseExprPrec(0);
End;

{ ------------------------------------------------------------ }
{ ShowStats (corps)                                             }
{ ------------------------------------------------------------ }

Procedure ShowStats;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('Lignes analysees : ', TotalLines);
  WriteLn('Tokens           : ', TokenCount);
  WriteLn('Usings           : ', UsingCount);
  WriteLn('Litteraux chaine : ', StrLitCount);
  WriteLn('Constantes       : ', ConstCount);
  WriteLn('Symboles         : ', SymCount);
  WriteLn('Types            : ', TypeCount);
  WriteLn('Donnees .DATA    : ', DataCount);
  WriteLn('Taille pile loc  : ', LocalOffset);
  WriteLn('Labels generes   : ', LabelSeq);
  WriteLn('Erreurs          : ', ErrorCount);
  WriteLn('Avertissements   : ', WarnCount);
End;

{ ------------------------------------------------------------ }
{ Run                                                          }
{ ------------------------------------------------------------ }

Procedure Run;
Var
  I          : Integer;
  SymIdx     : Integer;
  Off        : Integer;        { offset data pour variables statiques }
  NsName     : TString;       { nom du namespace courant           }
  ClsName    : TString;       { nom de la classe courante          }
  MethName   : TString;       { nom de la methode courante         }
  VarType    : TString;       { type d une variable                }
  VarName    : TString;       { nom d une variable                 }
  InClass    : Boolean;       { True si on est dans une classe     }
  InMethod   : Boolean;       { True si on est dans une methode    }
  BraceDepth : Integer;       { profondeur des accolades           }
  ClassDepth : Integer;       { profondeur a l entree de la classe }
  MethDepth  : Integer;       { profondeur a l entree de la methode }
Begin
  WriteLn('CSCW32: Compilation de ', Opts.SrcFile, ' ...');

  { Verifier que le fichier source existe }
  If Not FileExists(Opts.SrcFile) Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);

  { Ouvrir le fichier source }
  Assign(LexSrcF, Opts.SrcFile);
  {$I-}
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened := True;

  { Initialiser le lexeur }
  LexInit;

  { Initialiser la table des using }
  InitUsingTable;

  { Initialiser les tables de litteraux et constantes (TODO 04) }
  InitStrLitTable;
  InitConstTable;

  { Initialiser le systeme de types (TODO 06) }
  TypeInit;

  { Initialiser la table des symboles (TODO 05) }
  SymInit;

  { Initialiser l emetteur (TODO 07) }
  LabelSeq := 0;

  { Initialiser le segment de donnees (TODO 08) }
  DataInit;

  { Initialiser les variables locales (TODO 09) }
  ResetLocals;

  { Lire le premier token }
  Consume;

  { Analyser les directives using en tete }
  ParseUsingSection;

  { Afficher les namespaces importes }
  If Opts.Verbose Then
  Begin
    If UsingCount > 0 Then
    Begin
      WriteLn('Namespaces importes :');
      For I := 1 To UsingCount Do
      Begin
        Write('  using ', UsingTab[I].Name);
        If UsingTab[I].IsStd Then
          Write(' [standard]')
        Else
          Write(' [inconnu]');
        WriteLn;
      End;
    End;
  End;

  { Scanner les tokens restants : reconnaitre les declarations    }
  { namespace, class, methodes, variables, const, litteraux       }
  NsName     := '';
  ClsName    := '';
  MethName   := '';
  InClass    := False;
  InMethod   := False;
  BraceDepth := 0;
  ClassDepth := 0;
  MethDepth  := 0;

  While CurToken.Kind <> TK_EOF Do
  Begin
    { Reconnaitre les litteraux chaines pour la table .DATA }
    If CurToken.Kind = TK_STRING Then
    Begin
      AddStrLit(CurToken.Val);
      Consume;
    End
    { Reconnaitre les declarations const }
    Else If TokIsKw('const') Then
    Begin
      Consume;
      ParseConstDecl;
    End
    { Reconnaitre les declarations namespace }
    Else If TokIsKw('namespace') Then
    Begin
      Consume;
      If CurToken.Kind = TK_IDENT Then
      Begin
        NsName := CurToken.Val;
        SymIdx := SymAdd(NsName, SC_NAMESPACE, 0);
        If Opts.Verbose Then
          WriteLn('  namespace ', NsName);
        Consume;
        { Gerer les noms qualifies A.B.C }
        While TokIsPunct('.') Do
        Begin
          Consume;
          If CurToken.Kind = TK_IDENT Then
          Begin
            NsName := NsName + '.' + CurToken.Val;
            Consume;
          End;
        End;
      End;
    End
    { Reconnaitre les declarations class }
    Else If TokIsKw('class') Then
    Begin
      Consume;
      If CurToken.Kind = TK_IDENT Then
      Begin
        ClsName := CurToken.Val;
        SymIdx := SymAdd(ClsName, SC_CLASS, 0);
        InClass := True;
        ClassDepth := BraceDepth;
        If Opts.Verbose Then
          WriteLn('  class ', ClsName);
        Consume;
      End;
    End
    { Reconnaitre les accolades pour la gestion des scopes }
    Else If TokIsPunct('{') Then
    Begin
      Inc(BraceDepth);
      SymEnterScope;
      Consume;
    End
    Else If TokIsPunct('}') Then
    Begin
      Dec(BraceDepth);
      SymLeaveScope;
      If InMethod And (BraceDepth <= MethDepth) Then
        InMethod := False;
      If InClass And (BraceDepth <= ClassDepth) Then
        InClass := False;
      Consume;
    End
    { Reconnaitre static void/int/... Main/nom -> methode }
    Else If TokIsKw('static') Then
    Begin
      Consume;
      { Lire le type de retour }
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        VarType := CurToken.Val;
        Consume;
        { Si c est un tableau (int[] etc.) on saute les [] }
        If TokIsPunct('[') Then
        Begin
          Consume;
          If TokIsPunct(']') Then Consume;
        End;
        { Nom de la methode }
        If CurToken.Kind = TK_IDENT Then
        Begin
          MethName := CurToken.Val;
          Consume;
          { Si suivi de ( -> c est une methode }
          If TokIsPunct('(') Then
          Begin
            SymIdx := SymAdd(MethName, SC_METHOD,
                             TypeFromKeyword(VarType));
            If SymIdx >= 0 Then
              SymTab[SymIdx].IsStatic := True;
            InMethod := True;
            MethDepth := BraceDepth;
            ResetLocals;  { Reinitialiser le compteur de pile (TODO 09) }
            If Opts.Verbose Then
              WriteLn('  static method ', VarType, ' ', MethName);
            { Lire les parametres }
            Consume;  { consommer ( }
            While (CurToken.Kind <> TK_EOF) And
                  (Not TokIsPunct(')')) Do
            Begin
              { Lire type param }
              If (CurToken.Kind = TK_KEYWORD) Or
                 (CurToken.Kind = TK_IDENT) Then
              Begin
                VarType := CurToken.Val;
                Consume;
                { Sauter [] si tableau }
                If TokIsPunct('[') Then
                Begin
                  Consume;
                  If TokIsPunct(']') Then Consume;
                End;
                { Nom du parametre }
                If CurToken.Kind = TK_IDENT Then
                Begin
                  SymIdx := SymAdd(CurToken.Val, SC_PARAM,
                                   TypeFromKeyword(VarType));
                  { Assigner l offset EBP+n au parametre (TODO 09) }
                  If SymIdx >= 0 Then
                    SymTab[SymIdx].Offset := RegisterParam;
                  Consume;
                End;
              End
              Else
                Consume;
              { Sauter la virgule }
              If TokIsPunct(',') Then Consume;
            End;
            If TokIsPunct(')') Then Consume;
          End
          Else
          Begin
            { C est une variable statique : static type name [= val]; }
            { Le nom (MethName) est deja lu. Ajouter le symbole. }
            SymIdx := SymAdd(MethName, SC_STATIC,
                             TypeFromKeyword(VarType));
            If SymIdx >= 0 Then
            Begin
              SymTab[SymIdx].IsStatic := True;
              SymTab[SymIdx].IsGlobal := True;
              Off := DataAddStaticVar(ClsName, MethName,
                                      TypeFromKeyword(VarType));
              { Gerer l initialisation = valeur (TODO 09) }
              If TokIsOp('=') Then
              Begin
                Consume;
                If CurToken.Kind = TK_INTEGER Then
                Begin
                  If Off >= 0 Then
                    DataTab[Off].IntVal := CurToken.IntVal;
                  Consume;
                End
                Else If CurToken.Kind = TK_CHAR Then
                Begin
                  If (Off >= 0) And (Length(CurToken.Val) > 0) Then
                    DataTab[Off].IntVal := Ord(CurToken.Val[1]);
                  Consume;
                End
                Else If CurToken.Kind = TK_STRING Then
                Begin
                  AddStrLit(CurToken.Val);
                  Consume;
                End
                Else If TokIsKw('true') Then
                Begin
                  If Off >= 0 Then DataTab[Off].IntVal := 1;
                  Consume;
                End
                Else If TokIsKw('false') Then
                Begin
                  If Off >= 0 Then DataTab[Off].IntVal := 0;
                  Consume;
                End
                Else If TokIsKw('null') Then
                Begin
                  Consume;
                End
                Else If TokIsOp('-') Then
                Begin
                  Consume;
                  If CurToken.Kind = TK_INTEGER Then
                  Begin
                    If Off >= 0 Then
                      DataTab[Off].IntVal := -CurToken.IntVal;
                    Consume;
                  End;
                End
                Else
                  Consume;
              End;
              { Declarations multiples : static int a, b; }
              While TokIsPunct(',') Do
              Begin
                Consume;
                If CurToken.Kind = TK_IDENT Then
                Begin
                  SymIdx := SymAdd(CurToken.Val, SC_STATIC,
                                   TypeFromKeyword(VarType));
                  If SymIdx >= 0 Then
                  Begin
                    SymTab[SymIdx].IsStatic := True;
                    SymTab[SymIdx].IsGlobal := True;
                    DataAddStaticVar(ClsName, CurToken.Val,
                                     TypeFromKeyword(VarType));
                  End;
                  Consume;
                End;
              End;
            End;
            If Opts.DebugMode Then
              WriteLn('  VAR_STATIC: ', MethName, ' type=', VarType);
          End;
        End;
      End;
    End
    { Reconnaitre readonly comme qualificateur (TODO 09) }
    Else If TokIsKw('readonly') Then
    Begin
      Consume; { ignorer readonly, traite comme const implicite }
    End
    { Reconnaitre les declarations de variables locales (TODO 09)  }
    { Mots-cles de type : int, string, bool, char, double, etc.   }
    Else If InMethod And IsTypeKeyword Then
    Begin
      VarType := CurToken.Val;
      Consume;
      { Sauter [] si tableau }
      If TokIsPunct('[') Then
      Begin
        Consume;
        If TokIsPunct(']') Then Consume;
      End;
      { Si le suivant est un identifiant, c est une declaration }
      If CurToken.Kind = TK_IDENT Then
      Begin
        VarName := CurToken.Val;
        { Regarder apres le nom si c est une declaration }
        { (suivi de ; , = ) ou un appel/acces (suivi de ( . [ etc.) }
        { On utilise ParseVarDecl qui gere tout (TODO 09) }
        ParseVarDecl(VarType, False, ClsName);
      End;
    End
    { Variables statiques hors methode avec type en tete (TODO 09) }
    Else If InClass And (Not InMethod) And IsTypeKeyword Then
    Begin
      VarType := CurToken.Val;
      Consume;
      { Sauter [] si tableau }
      If TokIsPunct('[') Then
      Begin
        Consume;
        If TokIsPunct(']') Then Consume;
      End;
      If CurToken.Kind = TK_IDENT Then
        ParseVarDecl(VarType, True, ClsName);
    End
    Else
      Consume;
  End;

  { Marquer System comme utilise (toujours implicitement utilise) }
  MarkUsingUsed('System');

  { Verifier les using non utilises }
  CheckUnusedUsings;

  { Fermer le fichier source }
  LexClose;

  { Afficher bilan analyse }
  WriteLn('CSCW32: Lexer OK (', TotalLines, ' lignes, ',
          TokenCount, ' tokens, ', UsingCount, ' using, ',
          StrLitCount, ' chaines, ', ConstCount, ' constantes, ',
          SymCount, ' symboles, ', TypeCount, ' types, ',
          DataCount, ' data)');

  { Emettre le fichier .asm (TODO 07) }
  EmitOpen;
  EmitHeader;
  EmitDataSeg;
  EmitCodeSeg;

  { Stub : point d entree minimal }
  EmitComment('Point d entree');
  EmitLabel('_CSCF_MAIN');
  EmitProlog(LocalOffset);
  EmitComment('--- initialisations locales (TODO 09) ---');
  EmitComment('--- code a generer (TODO 11+) ---');
  EmitInstr('PUSH', '0');
  EmitInstr('CALL', '_ExitProcess@4');
  EmitEpilog;

  EmitFooter;
  EmitClose;

  WriteLn('CSCW32: ASM genere -> ', AsmFileName);
  WriteLn('CSCW32: Les TODOs 12..25 ne sont pas encore implementes.');
End;

{ ------------------------------------------------------------ }
{ Cleanup                                                      }
{ ------------------------------------------------------------ }

Procedure Cleanup;
Begin
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================ }
{ Programme principal                                          }
{ ============================================================ }

BEGIN
  If (ParamCount > 0) And
     ((ParamStr(1) = '/?') Or (ParamStr(1) = '--help') Or
      (ParamStr(1) = '-h') Or (ParamStr(1) = '/h') Or
      (ParamStr(1) = '/H')) Then
  Begin
    ShowHelp;
    Halt(EXIT_OK);
  End;

  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;

  ParseArgs;
  ShowBanner;
  Run;
  Cleanup;
  If Opts.Verbose Then ShowStats;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
END.
