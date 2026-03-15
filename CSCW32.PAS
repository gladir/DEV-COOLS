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

  TODO 02 - LEXEUR (TOKENS C#)
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

  TODO 03 - DIRECTIVES USING ET IMPORTS
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

  TODO 04 - LITTERAUX ET CONSTANTES
            Entiers decimaux : 0..4294967295 (32 bits non signe).
            Entiers hexadecimaux : 0xFF -> valeur 32 bits.
            Suffixes entiers : u/U (unsigned), l/L (long), ul/UL.
            Flottants : 3.14, 1.0e10 (reconnus, tronques en entier).
            Caracteres : 'A' -> valeur ordinale 32 bits.
              Echappement : '\n'=10, '\t'=9, '\r'=13, '\0'=0,
                '\\'=92, '\''=39, '\"'=34, '\x41'=65.
            Chaines : "abc" -> pointeur vers donnees .DATA.
            Chaines verbatim : @"c:\path" (echappement desactive).
            Constantes booleennes : true (1), false (0).
            null : pointeur nul (0).
            Expressions constantes : const int X = 10;.

  TODO 05 - TABLE DES SYMBOLES
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

  TODO 06 - SYSTEME DE TYPES
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

  TODO 07 - EMETTEUR DE CODE ASM 80386
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose.
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces).
            EmitComment, EmitBlankLine.
            LabelGen global (compteur unique _CSCL_NNNNN).
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

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_DWORD/DK_BYTE/DK_STR/
              DK_ARRAY/DK_ZERO), IntVal, StrVal.
            DataTab[0..MAX_DATA-1], DataCount.
            DataAdd, DataAddStr, DataAddDWord, DataAddByte,
              DataAddArray, DataAddZero : variantes d ajout.
            DataAddGlobalVar(nom, typeIdx) : cree _CSCV_nom.
            DataAddStaticVar(classe, var, typeIdx) : cree _CSCST_N.
            Variables globales (champs statiques de classe) :
              DD/DB dans .DATA avec label _CSCV_nom.
            Constantes chaines : DB "abc",0 dans .DATA
              avec label _CSCK_N.
            Tampons I/O : INBUF (256 octets), NUMBUF (16 octets).
            Variables de handles : HSTDOUT, HSTDIN, HHEAP (DWORD).

  TODO 09 - VARIABLES ET DECLARATIONS
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

  TODO 10 - EXPRESSIONS PRIMAIRES
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

  TODO 11 - OPERATEURS ET PRECEDENCE
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

Procedure ShowStats;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('Lignes analysees : ', TotalLines);
  WriteLn('Erreurs          : ', ErrorCount);
  WriteLn('Avertissements   : ', WarnCount);
End;

{ ------------------------------------------------------------ }
{ Run (stub pour les prochains TODOs)                          }
{ ------------------------------------------------------------ }

Procedure Run;
Begin
  WriteLn('CSCW32: Compilation de ', Opts.SrcFile, ' ...');

  { Verifier que le fichier source existe }
  If Not FileExists(Opts.SrcFile) Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);

  WriteLn('CSCW32: Infrastructure OK (TODO 01 implemente)');
  WriteLn('CSCW32: Les TODOs 02..25 ne sont pas encore implementes.');
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
