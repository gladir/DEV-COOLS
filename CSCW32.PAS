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

  TODO 12 - AFFECTATIONS ET OPERATEURS COMPOSES [IMPLEMENTE]
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

  TODO 13 - INSTRUCTIONS DE CONTROLE (if / else) [IMPLEMENTE]
            ParseIfStmt : if (cond) { stmts } [else { stmts }].
            Emission TEST EAX,EAX / JZ pour condition fausse.
            Labels via GenLabel.
            if imbriques : else if (cond) { stmts } ...
            Accolades optionnelles : if (cond) stmt; sans accolades.
            Bloc d instructions avec portee locale.
            SymEnterScope / SymLeaveScope pour variables de bloc.

  TODO 14 - BOUCLES (for / while / do-while) [IMPLEMENTE]
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

  TODO 15 - SWITCH / CASE / DEFAULT [IMPLEMENTE]
            ParseSwitchStmt : switch (expr) { case val: stmts }.
            Expression de controle : entier dans EAX, sauvee
              sur pile (PUSH EAX).
            case valeur : branche pour une valeur (CMP + JE).
            case val1: case val2: : valeurs multiples.
            default : branche par defaut.
            break : sortie du switch (JMP vers fin).
            Labels : _CSCL_CASE_N, _CSCL_CDEF_N, _CSCL_CEND_N.
            SwitchPush / SwitchPop : pile pour switch imbriques.

  TODO 16 - METHODES STATIQUES [IMPLEMENTE]
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
            FuncTab : table des methodes declarees.
            FindMethod / AddMethod : recherche / ajout dans FuncTab.
            MethExitLbl global : accessible depuis ParseStatement
              pour JMP a l epilogue sur return.

  TODO 17 - CLASSES ET MEMBRES STATIQUES [IMPLEMENTE]
            ParseClassDecl : class Nom { membres }.
            Membres statiques : champs static et methodes static.
            Portee de classe : acces aux membres par NomClasse.Membre.
            Classe Program : classe contenant Main() (point d entree).
            Un seul niveau de classe (pas d heritage dans le
              sous-ensemble minimal).
            Visibilite : public, private, internal (stub, non verifie
              dans le sous-ensemble minimal).
            Constructeurs statiques (stub optionnel).
            ClassTab : TClassEntry (Name/MangledName/SymIdx/MethStart/
              MethCount/FieldCount/HasMain).
            FindClass / AddClass : recherche / ajout.
            CurClassName : nom de la classe en cours d analyse.
            IsVisibilityKw / SkipVisibility : qualificateurs de
              visibilite ignores dans le sous-ensemble minimal.
            Plusieurs classes par fichier : supportees.
            Fichier test : test24_classes.cs.

  TODO 18 - ESPACES DE NOMS (namespace) [IMPLEMENTE]
            ParseNamespaceDecl : namespace Nom { classes }.
            Namespace englobant le programme entier.
            Resolution de noms qualifies : Namespace.Classe.Methode.
            Espaces de noms imbriques : namespace A.B { ... }.
            Table des namespaces declares : NsTab (TNsEntry).
              MAX_NS=32. NsTab[0..31] / NsCount / CurNsName / NsDepth.
            FindNs / AddNs : recherche / ajout dans NsTab.
            ParseNamespaceDecl : namespace Nom { classes }.
              Consomme namespace, lit le nom (qualifie A.B.C),
              ajoute dans NsTab, ouvre accolade, parse les classes
              et declarations internes, ferme accolade.
            Table des namespaces importes (via using) : UsingTab
              (deja implemente en TODO 05).
            Mangling : _CSCN_Namespace_Classe_Methode.
            Fichier test : test25_namespaces.cs.

  TODO 19 - TABLEAUX [IMPLEMENTE]
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

  TODO 20 - CHAINES ET OPERATIONS SUR LES CHAINES [IMPLEMENTE]
            Chaines C# : type string, reference vers donnees.
            Stockage : DB "abc",0 dans .DATA (ASCIIZ en interne).
            Variable string : pointeur vers chaine (DWORD).
            Concatenation : s1 + s2 -> appel _CSCRT_STRCAT.
            Concatenation mixte : "texte" + valeur_int
              -> conversion int vers string puis concatenation.
            Comparaison : == != via _CSCRT_STRCMP.
            Propriete Length : s.Length -> _CSCRT_STRLEN.
            Chaines litterales : "abc" -> label _CSCK_N dans .DATA.
            Suivi du type de l expression courante (CurExprType)
              pour determiner quand utiliser les operations chaines.
            Compteur StringOpCount pour les statistiques.
            Fichier test : test27_strings.cs.

  TODO 21 - ENTREES/SORTIES (Console) [IMPLEMENTE]
            Console.WriteLine(expr) : sortie avec saut de ligne.
              Surcharges : int -> _CSCRT_PRINTINT + _CSCRT_PRINTCRLF.
                string -> _CSCRT_PRINTSTR + _CSCRT_PRINTCRLF.
                bool -> _CSCRT_PRINTBOOL + _CSCRT_PRINTCRLF.
                char -> _CSCRT_PRINTCHAR + _CSCRT_PRINTCRLF.
                sans argument -> _CSCRT_PRINTCRLF.
            Console.Write(expr) : sortie sans saut de ligne.
              Memes surcharges que WriteLine, sans CRLF.
            Console.ReadLine() : lire une ligne depuis stdin
              -> _CSCRT_READSTR -> EAX (pointeur string).
            Detection automatique du type de l argument pour
              choisir la routine runtime appropriee.
            Compteur ConsoleOpCount pour les statistiques.
            Fichier test : test28_console.cs.

  TODO 22 - GOTO, BREAK, CONTINUE, RETURN [IMPLEMENTE]
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
            Fichier test : test29_goto.cs.

  TODO 23 - CAST, TYPEOF ET SIZEOF [IMPLEMENTE]
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
            Fichier test : test30_cast.cs.

  TODO 24 - RUNTIME MINIMAL WIN32 [IMPLEMENTE]
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
            EmitEntryPoint : point d entree _CSCF_MAIN, init
              handles (GetStdHandle), init heap (GetProcessHeap),
              CALL _CSCF_Main, PUSH 0/CALL ExitProcess.
            EmitRuntimeHelpers : 20 routines runtime emises apres
              le code utilisateur et avant le segment .DATA.
            RuntimeHelpCount : compteur du nombre de routines
              runtime emises.

  TODO 25 - GENERATION PE/COFF ET FICHIERS EXEMPLES [IMPLEMENTE]
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

{ Pile de boucles pour break/continue (TODO 14) }

Const
  MAX_LOOP_DEPTH = 32;          { profondeur maximale de boucles imbriquees }

Type
  TLoopEntry = Record
    BreakLbl    : TString;      { label de sortie (break -> JMP ici)     }
    ContinueLbl : TString;      { label continue (continue -> JMP ici)   }
  End;

Var
  LoopStack : Array[0..MAX_LOOP_DEPTH - 1] Of TLoopEntry;
  LoopDepth : Integer;          { profondeur courante de la pile         }

{ Pile de switch pour break dans switch (TODO 15) }

Const
  MAX_SWITCH_DEPTH = 32;        { profondeur maximale de switch imbriques }

Type
  TSwitchEntry = Record
    BreakLbl : TString;         { label de fin du switch (break -> JMP)  }
  End;

Var
  SwitchStack : Array[0..MAX_SWITCH_DEPTH - 1] Of TSwitchEntry;
  SwitchDepth : Integer;        { profondeur courante de la pile switch  }

{ Table des labels utilisateur pour goto (TODO 22) }

Const
  MAX_GOTO_LABELS = 64;           { nombre max de labels par methode     }

Type
  TGotoLabelEntry = Record
    Name    : TString;            { nom du label utilisateur             }
    AsmLbl  : TString;            { nom ASM _CSCL_USR_labelname          }
    Defined : Boolean;            { True si label: a ete rencontre       }
  End;

Var
  GotoLabelTab   : Array[0..MAX_GOTO_LABELS - 1] Of TGotoLabelEntry;
  GotoLabelCount : Integer;       { nombre de labels dans la table       }

{ Table des methodes declarees (TODO 16) }

Const
  MAX_METHODS = 256;            { nombre maximal de methodes declarees   }

Type
  TMethodEntry = Record
    Name        : TString;      { nom C# de la methode                  }
    MangledName : TString;      { nom ASM mangled (_CSCF_...)            }
    ParamCount  : Integer;      { nombre de parametres                   }
    RetType     : TString;      { type de retour (void, int, ...)        }
    SymIdx      : Integer;      { indice dans SymTab                     }
    IsVoid      : Boolean;      { True si void                           }
  End;

Var
  MethodTab    : Array[0..MAX_METHODS - 1] Of TMethodEntry;
  MethodCount  : Integer;       { nombre de methodes enregistrees        }
  MethExitLbl  : TString;       { label de sortie de la methode courante }

{ Table des classes declarees (TODO 17) }

Const
  MAX_CLASSES = 64;             { nombre maximal de classes declarees    }

Type
  TClassEntry = Record
    Name        : TString;      { nom C# de la classe                   }
    MangledName : TString;      { nom ASM mangled (_CSCC_...)            }
    SymIdx      : Integer;      { indice dans SymTab                     }
    MethStart   : Integer;      { premier indice dans MethodTab          }
    MethCount   : Integer;      { nombre de methodes dans la classe      }
    FieldCount  : Integer;      { nombre de champs statiques             }
    HasMain     : Boolean;      { True si la classe contient Main()      }
  End;

Var
  ClassTab    : Array[0..MAX_CLASSES - 1] Of TClassEntry;
  ClassCount  : Integer;        { nombre de classes enregistrees         }
  CurClassName: TString;        { nom de la classe en cours d analyse    }

{ Table des namespaces declares (TODO 18) }

Const
  MAX_NS = 32;                  { nombre maximal de namespaces declares  }

Type
  TNsEntry = Record
    Name        : TString;      { nom complet du namespace (ex. A.B.C)   }
    MangledName : TString;      { nom ASM mangled (_CSCN_...)            }
    SymIdx      : Integer;      { indice dans SymTab                     }
    ClassStart  : Integer;      { premier indice dans ClassTab           }
    ClassCount  : Integer;      { nombre de classes dans ce namespace    }
    Depth       : Integer;      { profondeur d imbrication               }
  End;

Var
  NsTab       : Array[0..MAX_NS - 1] Of TNsEntry;
  NsCount     : Integer;        { nombre de namespaces enregistres       }
  CurNsName   : TString;        { nom du namespace en cours d analyse    }
  NsDepth     : Integer;        { profondeur d imbrication des namespace }

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
Procedure GenStoreVar(Idx : Integer); Forward;
Procedure ParseVarDecl(Const VarType : TString; IsStatic : Boolean;
                       Const ClassName : TString); Forward;

{ Forward declarations for TODO 10 }
Procedure ParseExpr; Forward;
Procedure ParsePrimary; Forward;

{ Forward declarations for TODO 11 }
Procedure ParseExprPrec(MinPrec : Integer); Forward;

{ Forward declarations for TODO 12 }
Function  IsAssignOp : Boolean; Forward;
Procedure ParseAssignment(Const TargetName : TString); Forward;
Procedure ParseStatement; Forward;
Procedure ParseMethodBody; Forward;

{ Forward declarations for TODO 13 }
Procedure ParseIfStmt; Forward;

{ Forward declarations for TODO 14 }
Procedure ParseForStmt; Forward;
Procedure ParseWhileStmt; Forward;
Procedure ParseDoWhileStmt; Forward;

{ Forward declarations for TODO 15 }
Procedure ParseSwitchStmt; Forward;

{ Forward declarations for TODO 16 }
Procedure ParseMethodDecl(Const RetType, MName : TString); Forward;

{ Forward declarations for TODO 17 }
Function  FindClass(Const N : TString) : Integer; Forward;
Function  AddClass(Const N : TString; SIdx : Integer) : Integer; Forward;
Procedure ParseClassDecl; Forward;

{ Forward declarations for TODO 18 }
Function  FindNs(Const N : TString) : Integer; Forward;
Function  AddNs(Const N : TString; SIdx : Integer) : Integer; Forward;
Procedure ParseNamespaceDecl; Forward;

{ Forward declarations for TODO 22 }
Function  FindGotoLabel(Const N : TString) : Integer; Forward;
Function  AddGotoLabel(Const N : TString) : Integer; Forward;
Procedure ResetGotoLabels; Forward;

{ Forward declarations for TODO 24 }
Procedure EmitEntryPoint; Forward;
Procedure EmitRuntimeHelpers; Forward;

{ Forward declarations for TODO 25 }
Procedure BinInit; Forward;
Procedure BinEmitByte(B : Byte); Forward;
Procedure BinEmitWord(W : Word); Forward;
Procedure BinEmitDWord(D : LongInt); Forward;
Procedure BinEmitDataByte(B : Byte); Forward;
Procedure BinEmitDataWord(W : Word); Forward;
Procedure BinEmitDataDWord(D : LongInt); Forward;
Procedure BinAddLabel(AName : TString; AnOfs : LongInt); Forward;
Procedure BinAddFixup(AnOfs : LongInt; AKind : TBinFixKind;
                      ATarget : TString; AInCode : Boolean); Forward;
Function  BinFindLabel(AName : TString) : LongInt; Forward;
Procedure BinAssemble; Forward;
Procedure BinWriteObj; Forward;
Procedure BinWriteExe; Forward;

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
    IsArray     : Boolean;      { True si variable tableau (TODO 19) }
    ArraySize   : Integer;      { nombre d elements (0 si inconnu)   }
  End;

Var
  SymTab        : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount      : Integer;      { nombre de symboles enregistres     }
  CurScopeLevel : Integer;      { niveau courant de portee (0-based) }
  CurScopeId    : Integer;      { identifiant courant du scope       }
  ScopeIdSeq    : Integer;      { compteur pour generer des scope id }

  { Variables pour le suivi des tableaux (TODO 19) }
  ArrayCount      : Integer;      { nombre de declarations de tableaux  }
  PendingIsArray  : Boolean;      { True si [] consomme avant decl      }
  LastNewArraySize: Integer;      { taille du dernier new T[N]          }

  { Variables pour les operations sur les chaines (TODO 20) }
  CurExprType     : Integer;      { type de l expression courante       }
  StringOpCount   : Integer;      { nombre d operations sur chaines     }

  { Variables pour les entrees/sorties Console (TODO 21) }
  ConsoleOpCount  : Integer;      { nombre d operations Console         }

  { Variables pour goto / labels utilisateur (TODO 22) }
  GotoCount       : Integer;      { nombre d instructions goto          }

  { Variables pour cast, typeof, sizeof (TODO 23) }
  CastCount       : Integer;      { nombre de cast/typeof/sizeof        }

  { Variables pour le runtime Win32 (TODO 24) }
  RuntimeHelpCount : Integer;     { nombre de routines runtime emises   }

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
  SymTab[Idx].IsArray     := False;
  SymTab[Idx].ArraySize   := 0;

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
  EmitRaw('END _CSC_ENTRY');
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

  { Chaines runtime pour PRINTBOOL (TODO 24) }
  DataAdd('_CSC_TRUE',  DK_STR, 0, 'True');
  DataAdd('_CSC_FALSE', DK_STR, 0, 'False');

  { Message d erreur pour PANIC (TODO 24) }
  DataAdd('_CSC_PANIC_MSG', DK_STR, 0, 'Runtime error: ');

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
  InitIsExpr : Boolean;        { True si init = expression generale }
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
    InitIsExpr := False;
    StrLbl    := '';

    { Verifier s il y a une initialisation = expr }
    If TokIsOp('=') Then
    Begin
      Consume;
      HasInit := True;

      { En mode codegen et variable locale : utiliser ParseExpr }
      If OutFOpen And (Not IsStatic) Then
        InitIsExpr := True
      { Evaluer l expression d initialisation simple (hors codegen) }
      Else If CurToken.Kind = TK_INTEGER Then
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
          Consume;
        End
        Else If OutFOpen Then
          InitIsExpr := True
        Else
          Consume;
      End
      Else If TokIsOp('-') Then
      Begin
        { Negation : -expr }
        If OutFOpen Then
          InitIsExpr := True
        Else
        Begin
          Consume;
          If CurToken.Kind = TK_INTEGER Then
          Begin
            InitVal := -CurToken.IntVal;
            Consume;
          End
          Else
            Consume;
        End;
      End
      Else If TokIsOp('(') Or TokIsOp('!') Or TokIsOp('~') Or
              TokIsOp('++') Or TokIsOp('--') Or TokIsKw('new') Then
      Begin
        If OutFOpen Then
          InitIsExpr := True
        Else
        Begin
          While (CurToken.Kind <> TK_EOF) And
                (Not TokIsPunct(';')) And (Not TokIsPunct(',')) Do
            Consume;
        End;
      End
      Else
      Begin
        If OutFOpen Then
          InitIsExpr := True
        Else
        Begin
          { Expression inconnue - sauter jusqu au ; ou , }
          While (CurToken.Kind <> TK_EOF) And
                (Not TokIsPunct(';')) And (Not TokIsPunct(',')) Do
            Consume;
        End;
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
        { Marquer comme tableau si declaration type[] (TODO 19) }
        If PendingIsArray Then
        Begin
          SymTab[SymIdx].IsArray := True;
          PendingIsArray := False;
        End;
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
        { Marquer comme tableau si declaration type[] (TODO 19) }
        If PendingIsArray Then
        Begin
          SymTab[SymIdx].IsArray := True;
          PendingIsArray := False;
        End;
        { Emettre l initialisation si requise }
        If HasInit Then
        Begin
          If InitIsExpr Then
          Begin
            { Expression generale : ParseExpr + GenStoreVar }
            ParseExpr;
            GenStoreVar(SymIdx);
            { Capturer la taille du tableau (TODO 19) }
            If SymTab[SymIdx].IsArray And (LastNewArraySize > 0) Then
              SymTab[SymIdx].ArraySize := LastNewArraySize;
          End
          Else If InitIsStr Then
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
  ArrLenHandled : Boolean;
  ArrDotPos : Integer;
  ArrI      : Integer;
  ArrBase   : TString;
  ArrProp   : TString;
  IsConsoleWrite   : Boolean;  { True si Console.Write (TODO 21)     }
  IsConsoleWriteLn : Boolean;  { True si Console.WriteLine (TODO 21) }
  ArgExprType      : Integer;  { type de l argument (TODO 21)        }
  CastTypeName     : TString;  { nom du type pour cast (TODO 23)     }
  CastTypeIdx      : Integer;  { indice TY_IDX_* du cast (TODO 23)   }
  SzTypeIdx        : Integer;  { indice TY_IDX_* pour sizeof (TODO 23)}
  TofTypeName      : TString;  { nom du type pour typeof (TODO 23)   }
Begin
  { --- Literal entier --- }
  If CurToken.Kind = TK_INTEGER Then
  Begin
    GenLoadConst(CurToken.IntVal);
    CurExprType := TY_IDX_INT;  { TODO 20 }
    Consume;
  End
  { --- Literal chaine --- }
  Else If CurToken.Kind = TK_STRING Then
  Begin
    Lbl := AddStrLit(CurToken.Val);
    GenLoadStr(Lbl);
    CurExprType := TY_IDX_STRING;  { TODO 20 }
    Consume;
  End
  { --- Literal caractere --- }
  Else If CurToken.Kind = TK_CHAR Then
  Begin
    If Length(CurToken.Val) > 0 Then
      GenLoadConst(Ord(CurToken.Val[1]))
    Else
      GenLoadConst(0);
    CurExprType := TY_IDX_CHAR;  { TODO 20 }
    Consume;
  End
  { --- true --- }
  Else If TokIsKw('true') Then
  Begin
    GenLoadConst(1);
    CurExprType := TY_IDX_BOOL;  { TODO 20 }
    Consume;
  End
  { --- false --- }
  Else If TokIsKw('false') Then
  Begin
    GenLoadConst(0);
    CurExprType := TY_IDX_BOOL;  { TODO 20 }
    Consume;
  End
  { --- null --- }
  Else If TokIsKw('null') Then
  Begin
    GenLoadConst(0);
    CurExprType := TY_IDX_INT;  { TODO 20 }
    Consume;
  End
  { --- Expression entre parentheses / Cast (type)expr (TODO 23) --- }
  Else If TokIsPunct('(') Then
  Begin
    Consume;  { consommer ( }
    { TODO 23 : detecter si c est un cast (type)expr }
    If IsTypeKeyword Then
    Begin
      CastTypeName := CurToken.Val;
      CastTypeIdx  := TypeFromKeyword(CastTypeName);
      Consume;  { consommer le mot-cle type }
      If TokIsPunct(')') Then
        Consume;  { consommer ) }
      ParsePrimary;  { parser l expression a caster }
      { Generer le code de cast selon le type cible }
      If (CastTypeIdx = TY_IDX_CHAR) Or (CastTypeIdx = TY_IDX_BYTE) Then
      Begin
        EmitInstr('AND', 'EAX,0FFh');
        CurExprType := CastTypeIdx;
      End
      Else If CastTypeIdx = TY_IDX_SHORT Then
      Begin
        EmitInstr('AND', 'EAX,0FFFFh');
        CurExprType := CastTypeIdx;
      End
      Else If CastTypeIdx = TY_IDX_BOOL Then
      Begin
        EmitInstr('TEST', 'EAX,EAX');
        EmitInstr('SETNZ', 'AL');
        EmitInstr('MOVZX', 'EAX,AL');
        CurExprType := TY_IDX_BOOL;
      End
      Else If CastTypeIdx = TY_IDX_INT Then
      Begin
        { Promotion vers int : MOVZX si source byte/char }
        EmitInstr('MOVZX', 'EAX,AL');
        CurExprType := TY_IDX_INT;
      End
      Else
      Begin
        { uint, long, ulong, etc. : NOP (reinterpretation) }
        CurExprType := CastTypeIdx;
      End;
      Inc(CastCount);
    End
    Else
    Begin
      { Expression entre parentheses classique }
      ParseExpr;
      If TokIsPunct(')') Then
        Consume;  { consommer ) }
    End;
  End
  { --- sizeof(type) (TODO 23) --- }
  Else If TokIsKw('sizeof') Then
  Begin
    Consume;  { consommer sizeof }
    If TokIsPunct('(') Then Consume;
    SzTypeIdx := TY_IDX_INT;  { defaut }
    If IsTypeKeyword Then
    Begin
      SzTypeIdx := TypeFromKeyword(CurToken.Val);
      Consume;
    End
    Else If CurToken.Kind = TK_IDENT Then
      Consume;
    If TokIsPunct(')') Then Consume;
    GenLoadConst(TypeSizeof(SzTypeIdx));
    CurExprType := TY_IDX_INT;
    Inc(CastCount);
  End
  { --- typeof(type) (TODO 23) --- }
  Else If TokIsKw('typeof') Then
  Begin
    Consume;  { consommer typeof }
    If TokIsPunct('(') Then Consume;
    TofTypeName := 'Object';  { defaut }
    If IsTypeKeyword Then
    Begin
      CastTypeIdx := TypeFromKeyword(CurToken.Val);
      If      CastTypeIdx = TY_IDX_INT     Then TofTypeName := 'System.Int32'
      Else If CastTypeIdx = TY_IDX_UINT    Then TofTypeName := 'System.UInt32'
      Else If CastTypeIdx = TY_IDX_LONG    Then TofTypeName := 'System.Int64'
      Else If CastTypeIdx = TY_IDX_ULONG   Then TofTypeName := 'System.UInt64'
      Else If CastTypeIdx = TY_IDX_BOOL    Then TofTypeName := 'System.Boolean'
      Else If CastTypeIdx = TY_IDX_CHAR    Then TofTypeName := 'System.Char'
      Else If CastTypeIdx = TY_IDX_BYTE    Then TofTypeName := 'System.Byte'
      Else If CastTypeIdx = TY_IDX_SBYTE   Then TofTypeName := 'System.SByte'
      Else If CastTypeIdx = TY_IDX_SHORT   Then TofTypeName := 'System.Int16'
      Else If CastTypeIdx = TY_IDX_USHORT  Then TofTypeName := 'System.UInt16'
      Else If CastTypeIdx = TY_IDX_FLOAT   Then TofTypeName := 'System.Single'
      Else If CastTypeIdx = TY_IDX_DOUBLE  Then TofTypeName := 'System.Double'
      Else If CastTypeIdx = TY_IDX_DECIMAL Then TofTypeName := 'System.Decimal'
      Else If CastTypeIdx = TY_IDX_STRING  Then TofTypeName := 'System.String'
      Else If CastTypeIdx = TY_IDX_OBJECT  Then TofTypeName := 'System.Object'
      Else                                       TofTypeName := 'System.Object';
      Consume;
    End
    Else If CurToken.Kind = TK_IDENT Then
    Begin
      TofTypeName := CurToken.Val;
      Consume;
    End;
    If TokIsPunct(')') Then Consume;
    Lbl := AddStrLit(TofTypeName);
    GenLoadStr(Lbl);
    CurExprType := TY_IDX_STRING;
    Inc(CastCount);
  End
  { --- Negation unaire -expr --- }
  Else If TokIsOp('-') Then
  Begin
    Consume;
    ParsePrimary;
    GenNeg;
    CurExprType := TY_IDX_INT;  { TODO 20 }
  End
  { --- Negation logique !expr --- }
  Else If TokIsOp('!') Then
  Begin
    Consume;
    ParsePrimary;
    GenLogNot;
    CurExprType := TY_IDX_BOOL;  { TODO 20 }
  End
  { --- Complement bit a bit ~expr --- }
  Else If TokIsOp('~') Then
  Begin
    Consume;
    ParsePrimary;
    GenBitNot;
    CurExprType := TY_IDX_INT;  { TODO 20 }
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
      CurExprType := TY_IDX_INT;  { TODO 20 }
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
      CurExprType := TY_IDX_INT;  { TODO 20 }
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
    LastNewArraySize := 0;
    If TokIsPunct('[') Then
    Begin
      Consume;
      { Capturer la taille si c est un litteral entier (TODO 19) }
      If CurToken.Kind = TK_INTEGER Then
        LastNewArraySize := CurToken.IntVal;
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
      CurExprType := TY_IDX_INT;  { pointeur (TODO 20) }
    End
    Else
    Begin
      { new Type() - simple allocation objet (stub) }
      EmitComment('new objet (stub)');
      EmitInstr('XOR', 'EAX,EAX');
      CurExprType := TY_IDX_INT;  { TODO 20 }
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

      { Detection des methodes Console (TODO 21) }
      IsConsoleWrite   := (StrLowerCase(QualName) = 'console.write');
      IsConsoleWriteLn := (StrLowerCase(QualName) = 'console.writeline');

      If IsConsoleWrite Or IsConsoleWriteLn Then
      Begin
        { Console.Write / Console.WriteLine avec type automatique }
        If TokIsPunct(')') Then
        Begin
          { Sans argument : Console.WriteLine() -> CRLF seul }
          If IsConsoleWriteLn Then
          Begin
            EmitInstr('CALL', CSC_RT_PFX + 'PRINTCRLF');
            Inc(ConsoleOpCount);
          End;
        End
        Else
        Begin
          { Avec argument : evaluer et emettre selon le type }
          ParseExpr;
          ArgExprType := CurExprType;
          Inc(ArgCount);
          { Emettre l appel type selon CurExprType }
          If ArgExprType = TY_IDX_STRING Then
          Begin
            EmitInstr('MOV', 'ESI,EAX');
            EmitInstr('CALL', CSC_RT_PFX + 'PRINTSTR');
          End
          Else If ArgExprType = TY_IDX_BOOL Then
            EmitInstr('CALL', CSC_RT_PFX + 'PRINTBOOL')
          Else If ArgExprType = TY_IDX_CHAR Then
            EmitInstr('CALL', CSC_RT_PFX + 'PRINTCHAR')
          Else
            EmitInstr('CALL', CSC_RT_PFX + 'PRINTINT');
          If IsConsoleWriteLn Then
            EmitInstr('CALL', CSC_RT_PFX + 'PRINTCRLF');
          Inc(ConsoleOpCount);
          { Consommer les arguments supplementaires s il y en a }
          While TokIsPunct(',') Do
          Begin
            Consume;
            ParseExpr;
            Inc(ArgCount);
          End;
        End;
        If TokIsPunct(')') Then Consume;
        CurExprType := TY_IDX_VOID;  { void }
      End
      Else
      Begin
        { Appel de methode generique }
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
        { Nettoyer la pile (convention CDECL : appelant nettoie) }
        If ArgCount > 0 Then
          EmitInstr('ADD', 'ESP,' + IntToStr_(ArgCount * 4));
        { Determiner le type de retour (TODO 20) }
        If Idx >= 0 Then
          CurExprType := SymTab[Idx].TypeIdx
        Else
          CurExprType := TY_IDX_INT;
      End;
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
      CurExprType := TY_IDX_INT;  { TODO 20 }
    End
    { Post-increment : ident++ }
    Else If TokIsOp('++') Then
    Begin
      Idx := SymFind(QualName);
      GenLoadVar(Idx);   { valeur avant dans EAX }
      GenIncVar(Idx);    { incrementer la variable }
      Consume;           { consommer ++ }
      CurExprType := TY_IDX_INT;  { TODO 20 }
    End
    { Post-decrement : ident-- }
    Else If TokIsOp('--') Then
    Begin
      Idx := SymFind(QualName);
      GenLoadVar(Idx);   { valeur avant dans EAX }
      GenDecVar(Idx);    { decrementer la variable }
      Consume;           { consommer -- }
      CurExprType := TY_IDX_INT;  { TODO 20 }
    End
    { Variable simple ou constante }
    Else
    Begin
      { Propriete .Length sur tableau ou chaine (TODO 19/20) }
      ArrLenHandled := False;
      ArrDotPos := 0;
      For ArrI := Length(QualName) DownTo 1 Do
        If QualName[ArrI] = '.' Then
        Begin
          ArrDotPos := ArrI;
          Break;
        End;
      If ArrDotPos > 0 Then
      Begin
        ArrBase := StrLowerCase(Copy(QualName, 1, ArrDotPos - 1));
        ArrProp := StrLowerCase(Copy(QualName, ArrDotPos + 1,
                                     Length(QualName) - ArrDotPos));
        If ArrProp = 'length' Then
        Begin
          Idx := SymFind(ArrBase);
          If (Idx >= 0) And SymTab[Idx].IsArray Then
          Begin
            GenLoadConst(SymTab[Idx].ArraySize);
            CurExprType := TY_IDX_INT;  { TODO 20 }
            ArrLenHandled := True;
          End
          Else If (Idx >= 0) And
                  (SymTab[Idx].TypeIdx = TY_IDX_STRING) Then
          Begin
            { String.Length -> _CSCRT_STRLEN (TODO 20) }
            GenLoadVar(Idx);
            EmitInstr('MOV', 'ESI,EAX');
            EmitInstr('CALL', CSC_RT_PFX + 'STRLEN');
            CurExprType := TY_IDX_INT;
            ArrLenHandled := True;
            Inc(StringOpCount);
          End;
        End;
      End;
      If Not ArrLenHandled Then
      Begin
        Idx := SymFind(QualName);
        If Idx >= 0 Then
        Begin
          GenLoadVar(Idx);
          CurExprType := SymTab[Idx].TypeIdx;  { TODO 20 }
        End
        Else
        Begin
          { Peut etre une constante nommee }
          Idx := FindConst(StrLowerCase(QualName));
          If Idx > 0 Then
          Begin
            If ConstTab[Idx].IsStr Then
            Begin
              GenLoadStr(AddStrLit(ConstTab[Idx].StrVal));
              CurExprType := TY_IDX_STRING;  { TODO 20 }
            End
            Else
            Begin
              GenLoadConst(ConstTab[Idx].Value);
              CurExprType := TY_IDX_INT;  { TODO 20 }
            End;
          End
          Else
          Begin
            EmitComment('symbole inconnu: ' + QualName);
            EmitInstr('XOR', 'EAX,EAX');
            CurExprType := TY_IDX_INT;  { TODO 20 }
          End;
        End;
      End;
    End;
  End
  { --- Literal flottant (stub : tronque en entier) --- }
  Else If CurToken.Kind = TK_FLOAT Then
  Begin
    GenLoadConst(CurToken.IntVal);
    CurExprType := TY_IDX_INT;  { TODO 20 }
    Consume;
  End
  { --- Token inconnu --- }
  Else
  Begin
    EmitComment('expression primaire inattendue: ' + CurToken.Val);
    EmitInstr('XOR', 'EAX,EAX');
    CurExprType := TY_IDX_INT;  { TODO 20 }
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
  LeftType : Integer;    { type du LHS pour operations chaines (TODO 20) }
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
      CurExprType := TY_IDX_BOOL;  { TODO 20 }
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
      CurExprType := TY_IDX_BOOL;  { TODO 20 }
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
      LeftType := CurExprType;  { sauver le type du LHS (TODO 20) }
      GenPushEAX;
      ParseExprPrec(Prec + 1);
      { Concatenation de chaines avec + (TODO 20) }
      If (Op = '+') And
         ((LeftType = TY_IDX_STRING) Or
          (CurExprType = TY_IDX_STRING)) Then
      Begin
        { Convertir l operande droit en chaine si necessaire }
        If CurExprType <> TY_IDX_STRING Then
        Begin
          EmitInstr('MOV', 'EDI,OFFSET _CSC_NUMBUF');
          EmitInstr('CALL', CSC_RT_PFX + 'NUMTOSTR');
          EmitInstr('MOV', 'EAX,OFFSET _CSC_NUMBUF');
        End;
        GenPopEBX;
        { Convertir l operande gauche en chaine si necessaire }
        If LeftType <> TY_IDX_STRING Then
        Begin
          EmitInstr('PUSH', 'EAX');
          EmitInstr('MOV', 'EAX,EBX');
          EmitInstr('MOV', 'EDI,OFFSET _CSC_NUMBUF');
          EmitInstr('CALL', CSC_RT_PFX + 'NUMTOSTR');
          EmitInstr('MOV', 'EBX,OFFSET _CSC_NUMBUF');
          EmitInstr('POP', 'EAX');
        End;
        { ESI = chaine gauche, EDI = chaine droite }
        EmitInstr('MOV', 'ESI,EBX');
        EmitInstr('MOV', 'EDI,EAX');
        EmitInstr('CALL', CSC_RT_PFX + 'STRCAT');
        CurExprType := TY_IDX_STRING;
        Inc(StringOpCount);
      End
      { Comparaison de chaines avec == ou != (TODO 20) }
      Else If ((Op = '==') Or (Op = '!=')) And
              ((LeftType = TY_IDX_STRING) Or
               (CurExprType = TY_IDX_STRING)) Then
      Begin
        GenPopEBX;
        EmitInstr('MOV', 'ESI,EBX');
        EmitInstr('MOV', 'EDI,EAX');
        EmitInstr('CALL', CSC_RT_PFX + 'STRCMP');
        If Op = '==' Then
        Begin
          EmitInstr('TEST', 'EAX,EAX');
          EmitInstr('SETE', 'AL');
          EmitInstr('MOVZX', 'EAX,AL');
        End
        Else
        Begin
          EmitInstr('TEST', 'EAX,EAX');
          EmitInstr('SETNE', 'AL');
          EmitInstr('MOVZX', 'EAX,AL');
        End;
        CurExprType := TY_IDX_BOOL;
        Inc(StringOpCount);
      End
      Else
      Begin
        GenPopEBX;
        GenBinOp(Op);
      End;
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

{ ============================================================ }
{ TODO 12 - AFFECTATIONS ET OPERATEURS COMPOSES                 }
{           [IMPLEMENTE]                                        }
{ ============================================================ }
{                                                               }
{  Affectation simple : var = expr -> ParseExpr, GenStoreVar.   }
{  Affectations composees : += -= *= /= %= &= |= ^= <<= >>=   }
{  Pre/post increment/decrement : ++var, var++, --var, var--    }
{  (deja geres dans ParsePrimary pour les expressions).         }
{  Affectation de tableau : arr[i] = expr.                      }
{                                                               }
{  ParseAssignment : analyse une affectation ou expression      }
{    en tant qu instruction (appel, affectation, inc/dec).       }
{  ParseStatement  : dispatcher pour une instruction C#.         }
{  ParseMethodBody : analyse le corps d une methode.             }
{                                                               }
{ ============================================================ }

Const
  METHOD_STACK_SIZE = 1024;  { taille generique du cadre de pile }

{ ------------------------------------------------------------ }
{ GenVarRef : retourne l operand memoire d une variable         }
{   Ex: DWORD PTR [EBP-4] ou DWORD PTR [_CSCST_X]             }
{ ------------------------------------------------------------ }

Function GenVarRef(Idx : Integer) : TString;
Var
  S   : TString;
  Off : Integer;
Begin
  If Idx < 0 Then
  Begin
    GenVarRef := 'DWORD PTR [0]';
    Exit;
  End;

  Off := SymTab[Idx].Offset;

  If (SymTab[Idx].Cat = SC_VAR) And (Not SymTab[Idx].IsGlobal) Then
  Begin
    Str(Off, S);
    If Off < 0 Then
      GenVarRef := 'DWORD PTR [EBP' + S + ']'
    Else
      GenVarRef := 'DWORD PTR [EBP+' + S + ']';
  End
  Else If SymTab[Idx].Cat = SC_PARAM Then
  Begin
    Str(Off, S);
    GenVarRef := 'DWORD PTR [EBP+' + S + ']';
  End
  Else
    GenVarRef := 'DWORD PTR [' + SymTab[Idx].MangledName + ']';
End;

{ ------------------------------------------------------------ }
{ IsAssignOp : True si le token courant est un operateur        }
{   d affectation (= += -= *= /= %= &= |= ^= <<= >>=)         }
{ ------------------------------------------------------------ }

Function IsAssignOp : Boolean;
Begin
  IsAssignOp := TokIsOp('=') Or TokIsOp('+=') Or TokIsOp('-=') Or
                TokIsOp('*=') Or TokIsOp('/=') Or TokIsOp('%=') Or
                TokIsOp('&=') Or TokIsOp('|=') Or TokIsOp('^=') Or
                TokIsOp('<<=') Or TokIsOp('>>=');
End;

{ ------------------------------------------------------------ }
{ GenCompoundAssign : generer le code pour une affectation       }
{   composee. EAX contient la valeur RHS, Idx est la variable   }
{   cible. Op est l operateur (+=, -=, etc.).                   }
{   Resultat : la variable est mise a jour, EAX = nouveau val.  }
{ ------------------------------------------------------------ }

Procedure GenCompoundAssign(Const Op : TString; Idx : Integer);
Var
  Ref : TString;
Begin
  If Idx < 0 Then Exit;
  Ref := GenVarRef(Idx);

  If Op = '+=' Then
  Begin
    { Concatenation de chaines avec += (TODO 20) }
    If (Idx >= 0) And (SymTab[Idx].TypeIdx = TY_IDX_STRING) Then
    Begin
      EmitInstr('MOV', 'EDI,EAX');
      EmitInstr('MOV', 'ESI,' + Ref);
      EmitInstr('CALL', CSC_RT_PFX + 'STRCAT');
      EmitInstr('MOV', Ref + ',EAX');
      Inc(StringOpCount);
    End
    Else
    Begin
      EmitInstr('MOV', 'EBX,EAX');
      EmitInstr('MOV', 'EAX,' + Ref);
      EmitInstr('ADD', 'EAX,EBX');
      EmitInstr('MOV', Ref + ',EAX');
    End;
  End
  Else If Op = '-=' Then
  Begin
    EmitInstr('MOV', 'EBX,EAX');
    EmitInstr('MOV', 'EAX,' + Ref);
    EmitInstr('SUB', 'EAX,EBX');
    EmitInstr('MOV', Ref + ',EAX');
  End
  Else If Op = '*=' Then
  Begin
    EmitInstr('MOV', 'EBX,EAX');
    EmitInstr('MOV', 'EAX,' + Ref);
    EmitInstr('IMUL', 'EAX,EBX');
    EmitInstr('MOV', Ref + ',EAX');
  End
  Else If Op = '/=' Then
  Begin
    EmitInstr('MOV', 'ECX,EAX');
    EmitInstr('MOV', 'EAX,' + Ref);
    EmitInstr('CDQ', '');
    EmitInstr('IDIV', 'ECX');
    EmitInstr('MOV', Ref + ',EAX');
  End
  Else If Op = '%=' Then
  Begin
    EmitInstr('MOV', 'ECX,EAX');
    EmitInstr('MOV', 'EAX,' + Ref);
    EmitInstr('CDQ', '');
    EmitInstr('IDIV', 'ECX');
    EmitInstr('MOV', Ref + ',EDX');
    EmitInstr('MOV', 'EAX,EDX');
  End
  Else If Op = '&=' Then
  Begin
    EmitInstr('AND', Ref + ',EAX');
    EmitInstr('MOV', 'EAX,' + Ref);
  End
  Else If Op = '|=' Then
  Begin
    EmitInstr('OR', Ref + ',EAX');
    EmitInstr('MOV', 'EAX,' + Ref);
  End
  Else If Op = '^=' Then
  Begin
    EmitInstr('XOR', Ref + ',EAX');
    EmitInstr('MOV', 'EAX,' + Ref);
  End
  Else If Op = '<<=' Then
  Begin
    EmitInstr('MOV', 'ECX,EAX');
    EmitInstr('SHL', Ref + ',CL');
    EmitInstr('MOV', 'EAX,' + Ref);
  End
  Else If Op = '>>=' Then
  Begin
    EmitInstr('MOV', 'ECX,EAX');
    EmitInstr('SHR', Ref + ',CL');
    EmitInstr('MOV', 'EAX,' + Ref);
  End
  Else
    EmitComment('affectation composee inconnue: ' + Op);
End;

{ ------------------------------------------------------------ }
{ ParseAssignment : analyser une affectation ou expression      }
{   TargetName est le nom de l identifiant deja consomme.       }
{   Gere : var = expr, var op= expr, appel(), arr[i] = expr,   }
{          var++, var--.                                        }
{ ------------------------------------------------------------ }

Procedure ParseAssignment(Const TargetName : TString);
Var
  QualName  : TString;
  Idx       : Integer;
  Op        : TString;
  ArgCount  : Integer;
  IsConsoleWrite   : Boolean;  { TODO 21 }
  IsConsoleWriteLn : Boolean;  { TODO 21 }
  ArgExprType      : Integer;  { TODO 21 }
Begin
  QualName := TargetName;
  While TokIsPunct('.') Do
  Begin
    Consume;
    If CurToken.Kind = TK_IDENT Then
    Begin
      QualName := QualName + '.' + CurToken.Val;
      Consume;
    End;
  End;

  { --- Appel de methode : ident(...) --- }
  If TokIsPunct('(') Then
  Begin
    Idx := SymFind(QualName);
    Consume;
    ArgCount := 0;

    { Detection des methodes Console (TODO 21) }
    IsConsoleWrite   := (StrLowerCase(QualName) = 'console.write');
    IsConsoleWriteLn := (StrLowerCase(QualName) = 'console.writeline');

    If IsConsoleWrite Or IsConsoleWriteLn Then
    Begin
      If TokIsPunct(')') Then
      Begin
        { Sans argument : Console.WriteLine() -> CRLF seul }
        If IsConsoleWriteLn Then
        Begin
          EmitInstr('CALL', CSC_RT_PFX + 'PRINTCRLF');
          Inc(ConsoleOpCount);
        End;
      End
      Else
      Begin
        ParseExpr;
        ArgExprType := CurExprType;
        Inc(ArgCount);
        If ArgExprType = TY_IDX_STRING Then
        Begin
          EmitInstr('MOV', 'ESI,EAX');
          EmitInstr('CALL', CSC_RT_PFX + 'PRINTSTR');
        End
        Else If ArgExprType = TY_IDX_BOOL Then
          EmitInstr('CALL', CSC_RT_PFX + 'PRINTBOOL')
        Else If ArgExprType = TY_IDX_CHAR Then
          EmitInstr('CALL', CSC_RT_PFX + 'PRINTCHAR')
        Else
          EmitInstr('CALL', CSC_RT_PFX + 'PRINTINT');
        If IsConsoleWriteLn Then
          EmitInstr('CALL', CSC_RT_PFX + 'PRINTCRLF');
        Inc(ConsoleOpCount);
        While TokIsPunct(',') Do
        Begin
          Consume;
          ParseExpr;
          Inc(ArgCount);
        End;
      End;
      If TokIsPunct(')') Then Consume;
    End
    Else
    Begin
      While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct(')')) Do
      Begin
        ParseExpr;
        GenPushEAX;
        Inc(ArgCount);
        If TokIsPunct(',') Then Consume;
      End;
      If TokIsPunct(')') Then Consume;
      If Idx >= 0 Then
        EmitInstr('CALL', SymTab[Idx].MangledName)
      Else
        EmitInstr('CALL', CSC_FN_PFX + StrUpperCase(QualName));
      { Nettoyer la pile (convention CDECL : appelant nettoie) }
      If ArgCount > 0 Then
        EmitInstr('ADD', 'ESP,' + IntToStr_(ArgCount * 4));
    End;
    If TokIsPunct(';') Then Consume;
  End
  { --- Indexation tableau : ident[i] ... --- }
  Else If TokIsPunct('[') Then
  Begin
    Idx := SymFind(QualName);
    GenLoadVar(Idx);
    GenPushEAX;
    Consume;  { [ }
    ParseExpr;
    If TokIsPunct(']') Then Consume;
    EmitInstr('SHL', 'EAX,2');
    GenPopEBX;
    EmitInstr('ADD', 'EBX,EAX');
    { Affectation : arr[i] = expr }
    If TokIsOp('=') Then
    Begin
      GenPushEAX;   { sauver adresse = EBX (recalcul via push) }
      EmitInstr('PUSH', 'EBX');
      Consume;
      ParseExpr;
      EmitInstr('POP', 'EBX');
      EmitInstr('MOV', 'DWORD PTR [EBX],EAX');
    End
    Else
    Begin
      EmitInstr('MOV', 'EAX,DWORD PTR [EBX]');
    End;
    If TokIsPunct(';') Then Consume;
  End
  { --- Affectation simple : var = expr --- }
  Else If TokIsOp('=') Then
  Begin
    Idx := SymFind(QualName);
    Consume;
    ParseExpr;
    GenStoreVar(Idx);
    If TokIsPunct(';') Then Consume;
  End
  { --- Affectation composee : var op= expr --- }
  Else If TokIsOp('+=') Or TokIsOp('-=') Or TokIsOp('*=') Or
          TokIsOp('/=') Or TokIsOp('%=') Or TokIsOp('&=') Or
          TokIsOp('|=') Or TokIsOp('^=') Or TokIsOp('<<=') Or
          TokIsOp('>>=') Then
  Begin
    Idx := SymFind(QualName);
    Op := CurToken.Val;
    Consume;
    ParseExpr;
    GenCompoundAssign(Op, Idx);
    If TokIsPunct(';') Then Consume;
  End
  { --- Post-increment : var++ --- }
  Else If TokIsOp('++') Then
  Begin
    Idx := SymFind(QualName);
    GenLoadVar(Idx);
    GenIncVar(Idx);
    Consume;
    If TokIsPunct(';') Then Consume;
  End
  { --- Post-decrement : var-- --- }
  Else If TokIsOp('--') Then
  Begin
    Idx := SymFind(QualName);
    GenLoadVar(Idx);
    GenDecVar(Idx);
    Consume;
    If TokIsPunct(';') Then Consume;
  End
  { --- Expression comme instruction : effet de bord --- }
  Else
  Begin
    While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct(';')) And
          (Not TokIsPunct('}')) Do
      Consume;
    If TokIsPunct(';') Then Consume;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseStatement : analyser une instruction C#                   }
{   Dispatcher : declaration, affectation, appel, return, bloc. }
{ ------------------------------------------------------------ }

Procedure ParseStatement;
Var
  VarType   : TString;
  SavedName : TString;
  Idx       : Integer;
Begin
  { Instruction vide }
  If TokIsPunct(';') Then
  Begin
    Consume;
    Exit;
  End;

  { return [expr]; (TODO 16 : JMP vers epilogue) }
  If TokIsKw('return') Then
  Begin
    Consume;
    If Not TokIsPunct(';') Then
      ParseExpr;  { resultat dans EAX }
    If MethExitLbl <> '' Then
      EmitInstr('JMP', MethExitLbl);
    If TokIsPunct(';') Then Consume;
    Exit;
  End;

  (* if (cond) stmt_ou_bloc [else stmt_ou_bloc] *)
  If TokIsKw('if') Then
  Begin
    ParseIfStmt;
    Exit;
  End;

  (* for (init; cond; incr) { stmts } *)
  If TokIsKw('for') Then
  Begin
    ParseForStmt;
    Exit;
  End;

  (* while (cond) { stmts } *)
  If TokIsKw('while') Then
  Begin
    ParseWhileStmt;
    Exit;
  End;

  (* do { stmts } while (cond); *)
  If TokIsKw('do') Then
  Begin
    ParseDoWhileStmt;
    Exit;
  End;

  (* switch (expr) { case val: stmts } *)
  If TokIsKw('switch') Then
  Begin
    ParseSwitchStmt;
    Exit;
  End;

  (* break; -- fonctionne dans boucles ET switch *)
  If TokIsKw('break') Then
  Begin
    Consume;
    If LoopDepth > 0 Then
      EmitInstr('JMP', LoopStack[LoopDepth - 1].BreakLbl)
    Else
      FatalError('break en dehors d''une boucle ou d''un switch');
    If TokIsPunct(';') Then Consume;
    Exit;
  End;

  (* continue; *)
  If TokIsKw('continue') Then
  Begin
    Consume;
    If LoopDepth > 0 Then
      EmitInstr('JMP', LoopStack[LoopDepth - 1].ContinueLbl)
    Else
      FatalError('continue en dehors d''une boucle');
    If TokIsPunct(';') Then Consume;
    Exit;
  End;

  (* goto label; (TODO 22) *)
  If TokIsKw('goto') Then
  Begin
    Consume;
    If CurToken.Kind = TK_IDENT Then
    Begin
      Idx := AddGotoLabel(CurToken.Val);
      If Idx >= 0 Then
        EmitInstr('JMP', GotoLabelTab[Idx].AsmLbl);
      Inc(GotoCount);
      Consume;
    End
    Else
      FatalError('nom de label attendu apres goto');
    If TokIsPunct(';') Then Consume;
    Exit;
  End;

  { Declaration de variable locale : type ident [= expr]; }
  If IsTypeKeyword Then
  Begin
    VarType := CurToken.Val;
    Consume;
    PendingIsArray := False;
    If TokIsPunct('[') Then
    Begin
      Consume;
      If TokIsPunct(']') Then Consume;
      PendingIsArray := True;
      Inc(ArrayCount);
    End;
    If CurToken.Kind = TK_IDENT Then
      ParseVarDecl(VarType, False, '');
    If TokIsPunct(';') Then Consume;
    Exit;
  End;

  { Pre-increment : ++ident; }
  If TokIsOp('++') Then
  Begin
    Consume;
    If CurToken.Kind = TK_IDENT Then
    Begin
      Idx := SymFind(CurToken.Val);
      Consume;
      GenIncVar(Idx);
      GenLoadVar(Idx);
    End;
    If TokIsPunct(';') Then Consume;
    Exit;
  End;

  { Pre-decrement : --ident; }
  If TokIsOp('--') Then
  Begin
    Consume;
    If CurToken.Kind = TK_IDENT Then
    Begin
      Idx := SymFind(CurToken.Val);
      Consume;
      GenDecVar(Idx);
      GenLoadVar(Idx);
    End;
    If TokIsPunct(';') Then Consume;
    Exit;
  End;

  { Bloc d instructions imbriquees }
  If TokIsPunct('{') Then
  Begin
    Consume;
    SymEnterScope;
    While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct('}')) Do
      ParseStatement;
    If TokIsPunct('}') Then Consume;
    SymLeaveScope;
    Exit;
  End;

  { Identifiant : label utilisateur OU affectation/appel/expression }
  If CurToken.Kind = TK_IDENT Then
  Begin
    SavedName := CurToken.Val;
    Consume;
    { Detection de label utilisateur : ident ':' (TODO 22) }
    If TokIsPunct(':') Then
    Begin
      Consume;
      Idx := AddGotoLabel(SavedName);
      If Idx >= 0 Then
      Begin
        GotoLabelTab[Idx].Defined := True;
        EmitLabel(GotoLabelTab[Idx].AsmLbl);
      End;
      { Le label peut etre suivi d une instruction }
      If (CurToken.Kind <> TK_EOF) And (Not TokIsPunct('}')) Then
        ParseStatement;
      Exit;
    End;
    ParseAssignment(SavedName);
    Exit;
  End;

  { Token inconnu : sauter }
  Consume;
End;

(* ============================================================ *)
(* TODO 22 - GOTO, BREAK, CONTINUE, RETURN                      *)
(*           [IMPLEMENTE]                                        *)
(* ============================================================ *)
(*                                                               *)
(*  goto label; -> JMP _CSCL_USR_labelname                       *)
(*  label: stmt -> EmitLabel(_CSCL_USR_labelname)                *)
(*  Table de labels utilisateur par methode (max 64).            *)
(*  break/continue/return : deja geres par TODO 14/15/16.        *)
(*                                                               *)
(* ============================================================ *)

{ ------------------------------------------------------------ }
{ FindGotoLabel : chercher un label utilisateur dans la table   }
{   Retourne l indice ou -1 si non trouve.                     }
{ ------------------------------------------------------------ }

Function FindGotoLabel(Const N : TString) : Integer;
Var I : Integer;
Begin
  FindGotoLabel := -1;
  For I := 0 To GotoLabelCount - 1 Do
    If GotoLabelTab[I].Name = N Then
    Begin
      FindGotoLabel := I;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ AddGotoLabel : ajouter un label utilisateur dans la table     }
{   Retourne l indice du label ajoute.                         }
{ ------------------------------------------------------------ }

Function AddGotoLabel(Const N : TString) : Integer;
Var Idx : Integer;
Begin
  Idx := FindGotoLabel(N);
  If Idx >= 0 Then
  Begin
    AddGotoLabel := Idx;
    Exit;
  End;
  If GotoLabelCount >= MAX_GOTO_LABELS Then
  Begin
    FatalError('trop de labels utilisateur');
    AddGotoLabel := -1;
    Exit;
  End;
  Idx := GotoLabelCount;
  GotoLabelTab[Idx].Name    := N;
  GotoLabelTab[Idx].AsmLbl  := '_CSCL_USR_' + N;
  GotoLabelTab[Idx].Defined := False;
  Inc(GotoLabelCount);
  AddGotoLabel := Idx;
End;

{ ------------------------------------------------------------ }
{ ResetGotoLabels : reinitialiser la table des labels goto      }
{   Appelee au debut de chaque methode.                        }
{ ------------------------------------------------------------ }

Procedure ResetGotoLabels;
Begin
  GotoLabelCount := 0;
End;

{ ------------------------------------------------------------ }
{ ParseMethodBody : analyser le corps d une methode             }
{   L accolade ouvrante est deja consommee.                     }
{   Analyse les instructions jusqu au accolade fermante.        }
{ ------------------------------------------------------------ }

Procedure ParseMethodBody;
Begin
  While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct('}')) Do
    ParseStatement;
End;

(* ============================================================ *)
(* TODO 13 - INSTRUCTIONS DE CONTROLE (if / else)                *)
(*           [IMPLEMENTE]                                        *)
(* ============================================================ *)
(*                                                               *)
(*  ParseIfStmt : if (cond) stmt [else stmt]                     *)
(*  Genere :                                                     *)
(*    condition -> TEST EAX,EAX / JZ lbl_else                    *)
(*    bloc then -> instructions                                  *)
(*    JMP lbl_endif                                              *)
(*    lbl_else: [else if -> chain / else -> instructions]         *)
(*    lbl_endif:                                                  *)
(*  Accolades optionnelles : if (cond) stmt; sans accolades.     *)
(*  else if imbriques : enchainement automatique.                 *)
(*                                                               *)
(* ============================================================ *)

{ ------------------------------------------------------------ }
{ ParseIfStmt                                                   }
{   if ( expr ) stmt_ou_bloc [else stmt_ou_bloc]                }
{   Genere TEST EAX,EAX / JZ / JMP avec labels.                }
{ ------------------------------------------------------------ }

Procedure ParseIfStmt;
Var
  LblElse  : TString;
  LblEnd   : TString;
Begin
  { Consommer 'if' }
  Consume;

  { Parenthese ouvrante }
  If TokIsPunct('(') Then
    Consume
  Else
    FatalError('( attendu apres if');

  { Evaluer la condition -> resultat dans EAX }
  ParseExpr;

  { Parenthese fermante }
  If TokIsPunct(')') Then
    Consume
  Else
    FatalError(') attendu apres condition if');

  { Generer labels }
  LblElse := GenLabel;
  LblEnd  := GenLabel;

  { TEST EAX,EAX / JZ lbl_else }
  EmitInstr('TEST', 'EAX, EAX');
  EmitInstr('JZ', LblElse);

  { Bloc then : avec ou sans accolades }
  If TokIsPunct('{') Then
  Begin
    Consume;
    SymEnterScope;
    While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct('}')) Do
      ParseStatement;
    If TokIsPunct('}') Then Consume;
    SymLeaveScope;
  End
  Else
    ParseStatement;

  { Verifier s il y a un else }
  If TokIsKw('else') Then
  Begin
    { JMP lbl_end pour sauter le bloc else }
    EmitInstr('JMP', LblEnd);

    { Label else }
    EmitLabel(LblElse);

    { Consommer 'else' }
    Consume;

    { else if imbrique ? }
    If TokIsKw('if') Then
      ParseIfStmt
    Else If TokIsPunct('{') Then
    Begin
      Consume;
      SymEnterScope;
      While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct('}')) Do
        ParseStatement;
      If TokIsPunct('}') Then Consume;
      SymLeaveScope;
    End
    Else
      ParseStatement;

    { Label endif }
    EmitLabel(LblEnd);
  End
  Else
  Begin
    { Pas de else : le label else pointe ici directement }
    EmitLabel(LblElse);
    { LblEnd n est pas utilise dans ce cas, mais on l emet }
    { au meme endroit pour la coherence.                   }
  End;
End;

(* ============================================================ *)
(* TODO 14 - BOUCLES (for / while / do-while)                    *)
(*           [IMPLEMENTE]                                        *)
(* ============================================================ *)
(*                                                               *)
(*  LoopPush / LoopPop : pile de labels pour break / continue.   *)
(*  ParseWhileStmt : while (cond) { stmts }                      *)
(*    Genere : lbl_test -> ParseExpr -> TEST/JZ lbl_end          *)
(*             -> stmts -> JMP lbl_test -> lbl_end               *)
(*  ParseDoWhileStmt : do { stmts } while (cond);                *)
(*    Genere : lbl_beg -> stmts -> ParseExpr -> TEST/JNZ lbl_beg *)
(*             -> lbl_end                                        *)
(*  ParseForStmt : for (init; cond; incr) { stmts }              *)
(*    Genere : init -> lbl_test -> cond -> JZ lbl_end            *)
(*             -> JMP lbl_body -> lbl_incr -> incr               *)
(*             -> JMP lbl_test -> lbl_body -> stmts              *)
(*             -> JMP lbl_incr -> lbl_end                        *)
(*  break -> JMP BreakLbl,  continue -> JMP ContinueLbl.         *)
(*                                                               *)
(* ============================================================ *)

{ ------------------------------------------------------------ }
{ LoopPush : empiler les labels de boucle                       }
{ ------------------------------------------------------------ }

Procedure LoopPush(Const BrkLbl, ContLbl : TString);
Begin
  If LoopDepth >= MAX_LOOP_DEPTH Then
  Begin
    FatalError('profondeur maximale de boucles imbriquees atteinte');
    Exit;
  End;
  LoopStack[LoopDepth].BreakLbl    := BrkLbl;
  LoopStack[LoopDepth].ContinueLbl := ContLbl;
  Inc(LoopDepth);
End;

{ ------------------------------------------------------------ }
{ LoopPop : depiler les labels de boucle                        }
{ ------------------------------------------------------------ }

Procedure LoopPop;
Begin
  If LoopDepth > 0 Then
    Dec(LoopDepth);
End;

(* ------------------------------------------------------------ *)
(* ParseWhileStmt : while (cond) stmts                           *)
(*   Labels : lbl_test (debut de boucle), lbl_end (sortie).      *)
(*   continue -> JMP lbl_test,  break -> JMP lbl_end.            *)
(* ------------------------------------------------------------ *)

Procedure ParseWhileStmt;
Var
  LblTest : TString;
  LblEnd  : TString;
Begin
  { Consommer 'while' }
  Consume;

  { Generer les labels }
  LblTest := GenLabel;
  LblEnd  := GenLabel;

  { Empiler les labels pour break/continue }
  LoopPush(LblEnd, LblTest);

  { Label du test de condition }
  EmitLabel(LblTest);

  { Parenthese ouvrante }
  If TokIsPunct('(') Then
    Consume
  Else
    FatalError('( attendu apres while');

  { Evaluer la condition -> resultat dans EAX }
  ParseExpr;

  { Parenthese fermante }
  If TokIsPunct(')') Then
    Consume
  Else
    FatalError(') attendu apres condition while');

  { TEST EAX,EAX / JZ lbl_end (si condition fausse, sortir) }
  EmitInstr('TEST', 'EAX, EAX');
  EmitInstr('JZ', LblEnd);

  { Corps de la boucle }
  If TokIsPunct('{') Then
  Begin
    Consume;
    SymEnterScope;
    While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct('}')) Do
      ParseStatement;
    If TokIsPunct('}') Then Consume;
    SymLeaveScope;
  End
  Else
    ParseStatement;

  { Retour au test }
  EmitInstr('JMP', LblTest);

  { Label de sortie }
  EmitLabel(LblEnd);

  { Depiler les labels }
  LoopPop;
End;

(* ------------------------------------------------------------ *)
(* ParseDoWhileStmt : do stmts while (cond);                     *)
(*   Labels : lbl_beg (debut corps), lbl_end (sortie).           *)
(*   continue -> JMP lbl_beg,  break -> JMP lbl_end.             *)
(* ------------------------------------------------------------ *)

Procedure ParseDoWhileStmt;
Var
  LblBeg : TString;
  LblEnd : TString;
Begin
  { Consommer 'do' }
  Consume;

  { Generer les labels }
  LblBeg := GenLabel;
  LblEnd := GenLabel;

  { Empiler les labels pour break/continue }
  LoopPush(LblEnd, LblBeg);

  { Label de debut du corps }
  EmitLabel(LblBeg);

  { Corps de la boucle }
  If TokIsPunct('{') Then
  Begin
    Consume;
    SymEnterScope;
    While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct('}')) Do
      ParseStatement;
    If TokIsPunct('}') Then Consume;
    SymLeaveScope;
  End
  Else
    ParseStatement;

  { Consommer 'while' }
  If TokIsKw('while') Then
    Consume
  Else
    FatalError('while attendu apres do { ... }');

  { Parenthese ouvrante }
  If TokIsPunct('(') Then
    Consume
  Else
    FatalError('( attendu apres while');

  { Evaluer la condition -> resultat dans EAX }
  ParseExpr;

  { Parenthese fermante }
  If TokIsPunct(')') Then
    Consume
  Else
    FatalError(') attendu apres condition while');

  { TEST EAX,EAX / JNZ lbl_beg (si condition vraie, reboucler) }
  EmitInstr('TEST', 'EAX, EAX');
  EmitInstr('JNZ', LblBeg);

  { Label de sortie }
  EmitLabel(LblEnd);

  { Point-virgule final }
  If TokIsPunct(';') Then Consume;

  { Depiler les labels }
  LoopPop;
End;

(* ------------------------------------------------------------ *)
(* ParseForStmt : for (init; cond; incr) stmts                   *)
(*   Labels : lbl_test (test condition), lbl_incr (increment),   *)
(*            lbl_body (corps), lbl_end (sortie).                *)
(*   continue -> JMP lbl_incr,  break -> JMP lbl_end.            *)
(*   Portee de bloc pour la variable d initialisation.           *)
(* ------------------------------------------------------------ *)

Procedure ParseForStmt;
Var
  LblTest  : TString;
  LblIncr  : TString;
  LblBody  : TString;
  LblEnd   : TString;
  VarType  : TString;
  SavedName: TString;
  Idx      : Integer;
Begin
  { Consommer 'for' }
  Consume;

  { Generer les labels }
  LblTest := GenLabel;
  LblIncr := GenLabel;
  LblBody := GenLabel;
  LblEnd  := GenLabel;

  { Ouvrir le scope du for (pour la variable d init) }
  SymEnterScope;

  { Parenthese ouvrante }
  If TokIsPunct('(') Then
    Consume
  Else
    FatalError('( attendu apres for');

  { --- INIT --- }
  { init peut etre : declaration (int i = 0), expression, ou vide }
  If Not TokIsPunct(';') Then
  Begin
    If IsTypeKeyword Then
    Begin
      { Declaration de variable : int i = 0 }
      VarType := CurToken.Val;
      Consume;
      If CurToken.Kind = TK_IDENT Then
        ParseVarDecl(VarType, False, '');
    End
    Else If CurToken.Kind = TK_IDENT Then
    Begin
      { Expression (affectation typique) }
      SavedName := CurToken.Val;
      Consume;
      ParseAssignment(SavedName);
    End
    Else
      ParseExpr;
  End;
  { Consommer le ; apres init }
  If TokIsPunct(';') Then Consume;

  { Empiler les labels pour break/continue }
  LoopPush(LblEnd, LblIncr);

  { --- CONDITION --- }
  { Label du test de condition }
  EmitLabel(LblTest);

  If Not TokIsPunct(';') Then
  Begin
    { Evaluer la condition -> EAX }
    ParseExpr;
    { TEST EAX,EAX / JZ lbl_end }
    EmitInstr('TEST', 'EAX, EAX');
    EmitInstr('JZ', LblEnd);
  End;
  { Consommer le ; apres cond }
  If TokIsPunct(';') Then Consume;

  { Sauter par-dessus l increment vers le corps }
  EmitInstr('JMP', LblBody);

  { --- INCREMENT --- }
  EmitLabel(LblIncr);

  If Not TokIsPunct(')') Then
  Begin
    If CurToken.Kind = TK_IDENT Then
    Begin
      SavedName := CurToken.Val;
      Consume;
      ParseAssignment(SavedName);
    End
    Else If TokIsOp('++') Then
    Begin
      Consume;
      If CurToken.Kind = TK_IDENT Then
      Begin
        Idx := SymFind(CurToken.Val);
        Consume;
        GenIncVar(Idx);
      End;
    End
    Else If TokIsOp('--') Then
    Begin
      Consume;
      If CurToken.Kind = TK_IDENT Then
      Begin
        Idx := SymFind(CurToken.Val);
        Consume;
        GenDecVar(Idx);
      End;
    End
    Else
      ParseExpr;
  End;

  { Retour au test de condition }
  EmitInstr('JMP', LblTest);

  { Parenthese fermante }
  If TokIsPunct(')') Then
    Consume
  Else
    FatalError(') attendu apres for (init; cond; incr');

  { --- CORPS --- }
  EmitLabel(LblBody);

  If TokIsPunct('{') Then
  Begin
    Consume;
    SymEnterScope;
    While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct('}')) Do
      ParseStatement;
    If TokIsPunct('}') Then Consume;
    SymLeaveScope;
  End
  Else
    ParseStatement;

  { Saut vers l increment }
  EmitInstr('JMP', LblIncr);

  { Label de sortie }
  EmitLabel(LblEnd);

  { Depiler les labels }
  LoopPop;

  { Fermer le scope du for }
  SymLeaveScope;
End;

(* ============================================================ *)
(* TODO 15 - SWITCH / CASE / DEFAULT                            *)
(*                                                               *)
(*  ParseSwitchStmt : switch (expr) { case val: stmts }.         *)
(*    Expression de controle -> EAX, sauvee sur la pile (PUSH).  *)
(*    case valeur : CMP EAX,val / JE label_case.                 *)
(*    case val1: case val2: : CMP successifs avec JE vers meme   *)
(*      label de corps.                                          *)
(*    default : branche par defaut (JMP label_default).          *)
(*    break : sortie du switch (JMP vers label_end) via LoopPush.*)
(*    Pas de fall-through implicite (C# exige break).            *)
(*  SwitchPush / SwitchPop : pile pour switch imbriques.         *)
(*                                                               *)
(* ============================================================ *)

{ ------------------------------------------------------------ }
{ SwitchPush : empiler le contexte de switch                    }
{ ------------------------------------------------------------ }

Procedure SwitchPush(Const BrkLbl : TString);
Begin
  If SwitchDepth >= MAX_SWITCH_DEPTH Then
  Begin
    FatalError('profondeur maximale de switch imbriques atteinte');
    Exit;
  End;
  SwitchStack[SwitchDepth].BreakLbl := BrkLbl;
  Inc(SwitchDepth);
End;

{ ------------------------------------------------------------ }
{ SwitchPop : depiler le contexte de switch                     }
{ ------------------------------------------------------------ }

Procedure SwitchPop;
Begin
  If SwitchDepth > 0 Then
    Dec(SwitchDepth);
End;

{ ------------------------------------------------------------ }
{ ParseSwitchStmt : switch (expr) - case val: stmts             }
{   Evaluation de l expression dans EAX, sauvee sur pile.       }
{   Pour chaque case : reload EAX + CMP EAX,val + JE.          }
{   default : saut inconditionnel.                              }
{   break : JMP vers LblEnd (via LoopPush).                     }
{ ------------------------------------------------------------ }

Procedure ParseSwitchStmt;
Var
  LblEnd     : TString;        { label de fin du switch (apres cleanup) }
  LblClean   : TString;        { label de nettoyage de la pile         }
  LblNext    : TString;        { label du prochain test de case       }
  LblBody    : TString;        { label du corps du case courant       }
  CaseVal    : LongInt;        { valeur entiere du case               }
  HasDefault : Boolean;        { True si default present              }
  S          : TString;        { chaine temporaire pour IntToStr      }
Begin
  { Consommer 'switch' }
  Consume;

  { Parenthese ouvrante }
  If TokIsPunct('(') Then
    Consume
  Else
    FatalError('( attendu apres switch');

  { Evaluer l expression de controle -> EAX }
  ParseExpr;

  { Parenthese fermante }
  If TokIsPunct(')') Then
    Consume
  Else
    FatalError(') attendu apres switch (expr');

  { Sauvegarder la valeur de controle sur la pile }
  EmitInstr('PUSH', 'EAX');

  { Labels }
  LblClean   := GenLabel;      { label cleanup : ADD ESP,4             }
  LblEnd     := GenLabel;      { label apres cleanup                   }
  HasDefault := False;

  { Empiler le switch pour break (via LoopPush et SwitchPush)          }
  { break saute vers LblClean qui nettoie la pile puis tombe sur LblEnd }
  LoopPush(LblClean, '');
  SwitchPush(LblClean);

  { Accolade ouvrante }
  If TokIsPunct('{') Then
    Consume
  Else
    FatalError('{ attendu apres switch (expr)');

  { Generer le saut vers le premier test de case }
  LblNext := GenLabel;
  EmitInstr('JMP', LblNext);

  { Boucle sur les case / default }
  While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct('}')) Do
  Begin
    { --- case val: [case val2:] stmts --- }
    If TokIsKw('case') Then
    Begin
      { Emettre le label du test suivant }
      EmitLabel(LblNext);

      { Boucle pour valeurs multiples (case val1: case val2:) }
      LblBody := GenLabel;
      While TokIsKw('case') Do
      Begin
        Consume;

        { Recharger la valeur de controle depuis la pile }
        { (POP dans EAX puis PUSH pour la garder)       }
        EmitInstr('MOV', 'EAX,DWORD PTR [ESP]');

        { Lire la valeur du case }
        If CurToken.Kind = TK_INTEGER Then
        Begin
          CaseVal := CurToken.IntVal;
          Consume;
        End
        Else If CurToken.Kind = TK_CHAR Then
        Begin
          CaseVal := CurToken.IntVal;
          Consume;
        End
        Else If TokIsOp('-') Then
        Begin
          Consume;
          If CurToken.Kind = TK_INTEGER Then
          Begin
            CaseVal := -CurToken.IntVal;
            Consume;
          End
          Else
          Begin
            FatalError('valeur entiere attendue apres case -');
            CaseVal := 0;
          End;
        End
        Else
        Begin
          FatalError('valeur entiere ou caractere attendue apres case');
          CaseVal := 0;
          If CurToken.Kind <> TK_EOF Then Consume;
        End;

        { Deux-points apres la valeur }
        If TokIsPunct(':') Then
          Consume
        Else
          FatalError(': attendu apres case val');

        { Comparer et sauter vers le corps si egal }
        Str(CaseVal, S);
        EmitInstr('CMP', 'EAX,' + S);
        EmitInstr('JE', LblBody);
      End;

      { Si aucune valeur ne correspond, sauter au prochain test }
      LblNext := GenLabel;
      EmitInstr('JMP', LblNext);

      { Emettre le label du corps }
      EmitLabel(LblBody);

      { Parser les instructions du corps du case }
      While (CurToken.Kind <> TK_EOF) And
            (Not TokIsPunct('}')) And
            (Not TokIsKw('case')) And
            (Not TokIsKw('default')) Do
        ParseStatement;
    End

    { --- default: stmts --- }
    Else If TokIsKw('default') Then
    Begin
      { Emettre le label du test suivant (le JMP du case precedent) }
      EmitLabel(LblNext);

      Consume;
      If TokIsPunct(':') Then
        Consume
      Else
        FatalError(': attendu apres default');

      { Le default n a pas besoin de comparaison }
      HasDefault := True;

      { Parser les instructions du corps du default }
      While (CurToken.Kind <> TK_EOF) And
            (Not TokIsPunct('}')) And
            (Not TokIsKw('case')) And
            (Not TokIsKw('default')) Do
        ParseStatement;

      { Preparer le prochain label si d autres case suivent }
      LblNext := GenLabel;
    End

    Else
    Begin
      { Token inattendu dans le switch }
      Consume;
    End;
  End;

  { Si le dernier LblNext n a pas ete emis (pas de default apres) }
  If Not HasDefault Then
    EmitLabel(LblNext);

  { Accolade fermante }
  If TokIsPunct('}') Then
    Consume;

  { Label de nettoyage : break saute ici }
  EmitLabel(LblClean);

  { Depiler la valeur de controle }
  EmitInstr('ADD', 'ESP,4');

  { Label de fin }
  EmitLabel(LblEnd);

  { Depiler le switch }
  SwitchPop;
  LoopPop;
End;

{ ============================================================ }
{ TODO 16 - METHODES STATIQUES                                  }
{           [IMPLEMENTE]                                        }
{ ============================================================ }
(*                                                               *)
(*  ParseMethodDecl : declaration de methode statique.           *)
(*    static type Nom(type1 param1, type2 param2, ...) { ... }   *)
(*  Convention cdecl 32 bits : appelant nettoie la pile.         *)
(*    Parametres : [EBP+8], [EBP+12], ...                        *)
(*    Locals : [EBP-4], [EBP-8], ...                             *)
(*  FuncTab : table des methodes declarees.                      *)
(*  FindMethod / AddMethod : recherche / ajout.                  *)
(*  MethExitLbl : label global pour return -> JMP.               *)
(*                                                               *)
{ ============================================================ }

{ ------------------------------------------------------------ }
{ FindMethod : trouver une methode dans MethodTab               }
{   Retourne l indice ou -1 si non trouvee                      }
{ ------------------------------------------------------------ }

Function FindMethod(Const N : TString) : Integer;
Var I : Integer;
    UN : TString;
Begin
  UN := StrUpperCase(N);
  FindMethod := -1;
  For I := 0 To MethodCount - 1 Do
    If StrUpperCase(MethodTab[I].Name) = UN Then
    Begin
      FindMethod := I;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ AddMethod : ajouter une methode dans MethodTab                }
{   Retourne l indice ou -1 si plein                            }
{ ------------------------------------------------------------ }

Function AddMethod(Const N, Mangled, RType : TString;
                   PCount : Integer;
                   SIdx   : Integer) : Integer;
Begin
  If MethodCount >= MAX_METHODS Then
  Begin
    WarnMsg('table des methodes pleine');
    AddMethod := -1;
    Exit;
  End;
  MethodTab[MethodCount].Name        := N;
  MethodTab[MethodCount].MangledName := Mangled;
  MethodTab[MethodCount].ParamCount  := PCount;
  MethodTab[MethodCount].RetType     := RType;
  MethodTab[MethodCount].SymIdx      := SIdx;
  MethodTab[MethodCount].IsVoid      := (StrUpperCase(RType) = 'VOID');
  AddMethod := MethodCount;
  Inc(MethodCount);
End;

{ ------------------------------------------------------------ }
{ GetMethodParamCount : retourne le nombre de parametres        }
{   d une methode identifiee par son nom qualifie.              }
{   Retourne -1 si methode inconnue.                            }
{ ------------------------------------------------------------ }

Function GetMethodParamCount(Const N : TString) : Integer;
Var MI : Integer;
Begin
  MI := FindMethod(N);
  If MI >= 0 Then
    GetMethodParamCount := MethodTab[MI].ParamCount
  Else
    GetMethodParamCount := -1;
End;

{ ------------------------------------------------------------ }
{ ParseMethodDecl : analyser une declaration de methode         }
{   static type Nom(type1 p1, type2 p2, ...) corps              }
{   RetType et MName sont deja consommes par l appelant.        }
{ ------------------------------------------------------------ }

Procedure ParseMethodDecl(Const RetType, MName : TString);
Var
  SymIdx     : Integer;
  ParamCnt   : Integer;
  PType      : TString;
  Mangled    : TString;
  ParamSyms  : Array[0..31] Of Integer;
  I, J, TmpOfs : Integer;
Begin
  { Ajouter la methode dans la table des symboles }
  SymIdx := SymAdd(MName, SC_METHOD, TypeFromKeyword(RetType));
  If SymIdx >= 0 Then
    SymTab[SymIdx].IsStatic := True;

  Mangled := SymMangle(MName, SC_METHOD);

  { Reinitialiser les compteurs de pile locale }
  ResetLocals;

  { Compter et enregistrer les parametres }
  ParamCnt := 0;
  Consume;  { consommer ( }
  While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct(')')) Do
  Begin
    { Lire le type du parametre }
    If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
    Begin
      PType := CurToken.Val;
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
                         TypeFromKeyword(PType));
        If SymIdx >= 0 Then
        Begin
          SymTab[SymIdx].Offset := RegisterParam;
          If ParamCnt <= 31 Then
            ParamSyms[ParamCnt] := SymIdx;
        End;
        Inc(ParamCnt);
        Consume;
      End;
    End
    Else
      Consume;
    { Sauter la virgule }
    If TokIsPunct(',') Then Consume;
  End;
  If TokIsPunct(')') Then Consume;

  { Inverser les offsets des parametres pour correspondre }
  { a l ordre de push gauche-a-droite (left-to-right)    }
  If ParamCnt > 1 Then
    For I := 0 To (ParamCnt Div 2) - 1 Do
    Begin
      J := ParamCnt - 1 - I;
      If (I <= 31) And (J <= 31) Then
      Begin
        TmpOfs := SymTab[ParamSyms[I]].Offset;
        SymTab[ParamSyms[I]].Offset := SymTab[ParamSyms[J]].Offset;
        SymTab[ParamSyms[J]].Offset := TmpOfs;
      End;
    End;

  { Enregistrer dans FuncTab }
  AddMethod(MName, Mangled, RetType, ParamCnt, SymIdx);

  If Opts.Verbose Then
    WriteLn('  static method ', RetType, ' ', MName,
            '(', ParamCnt, ' params)');
End;

{ ============================================================ }
{ TODO 17 - CLASSES ET MEMBRES STATIQUES                         }
{           [IMPLEMENTE]                                        }
{ ============================================================ }
(*                                                               *)
(*  ParseClassDecl : declaration de classe.                      *)
(*    [public|private|internal] class Nom { membres }            *)
(*  Membres statiques :                                          *)
(*    Champs static : variables globales (.DATA).                *)
(*      static int count; -> _CSCST_COUNT DD 0.                  *)
(*    Methodes static : fonctions autonomes.                     *)
(*      static void Print() { ... } -> _CSCF_PRINT.             *)
(*  Portee de classe : acces aux membres par NomClasse.Membre.   *)
(*  Classe Program : classe contenant Main() (point d entree).   *)
(*  Visibilite : public, private, protected, internal            *)
(*    (reconnus mais non verifies dans le sous-ensemble minimal). *)
(*  Plusieurs classes par fichier : supportees.                  *)
(*  ClassTab : TClassEntry (Name/MangledName/SymIdx/MethStart/   *)
(*    MethCount/FieldCount/HasMain).                             *)
(*  FindClass / AddClass : recherche / ajout.                    *)
(*  CurClassName : nom de la classe en cours d analyse.          *)
(*                                                               *)
{ ============================================================ }

{ ------------------------------------------------------------ }
{ FindClass : trouver une classe dans ClassTab                  }
{   Retourne l indice ou -1 si non trouvee                      }
{ ------------------------------------------------------------ }

Function FindClass(Const N : TString) : Integer;
Var I : Integer;
    UN : TString;
Begin
  UN := StrUpperCase(N);
  FindClass := -1;
  For I := 0 To ClassCount - 1 Do
    If StrUpperCase(ClassTab[I].Name) = UN Then
    Begin
      FindClass := I;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ AddClass : ajouter une classe dans ClassTab                   }
{   Retourne l indice ou -1 si plein                            }
{ ------------------------------------------------------------ }

Function AddClass(Const N : TString; SIdx : Integer) : Integer;
Var CI : Integer;
Begin
  If ClassCount >= MAX_CLASSES Then
  Begin
    WarnMsg('table des classes pleine');
    AddClass := -1;
    Exit;
  End;
  CI := ClassCount;
  ClassTab[CI].Name        := N;
  ClassTab[CI].MangledName := CSC_CLS_PFX + StrUpperCase(N);
  ClassTab[CI].SymIdx      := SIdx;
  ClassTab[CI].MethStart   := MethodCount;
  ClassTab[CI].MethCount   := 0;
  ClassTab[CI].FieldCount  := 0;
  ClassTab[CI].HasMain     := False;
  AddClass := CI;
  Inc(ClassCount);
End;

{ ------------------------------------------------------------ }
{ IsVisibilityKw : verifier si le token courant est un          }
{   qualificateur de visibilite (public, private, protected,    }
{   internal).                                                  }
{ ------------------------------------------------------------ }

Function IsVisibilityKw : Boolean;
Begin
  IsVisibilityKw :=
    TokIsKw('public') Or TokIsKw('private') Or
    TokIsKw('protected') Or TokIsKw('internal');
End;

{ ------------------------------------------------------------ }
{ SkipVisibility : consommer les qualificateurs de visibilite   }
{   (public, private, protected, internal). Dans le sous-       }
{   ensemble minimal, la visibilite est ignoree (tout est       }
{   traite comme public).                                       }
{ ------------------------------------------------------------ }

Procedure SkipVisibility;
Begin
  While IsVisibilityKw Do
    Consume;
End;

{ ------------------------------------------------------------ }
{ ParseClassDecl : analyser une declaration de classe            }
{   [visibilite] class Nom (accolade) membres (accolade)         }
{   Le mot-cle 'class' a deja ete consomme par l appelant.       }
{   Les membres sont des champs et methodes statiques.           }
{ ------------------------------------------------------------ }

Procedure ParseClassDecl;
Var
  ClsIdx     : Integer;
  SymIdx     : Integer;
  Off        : Integer;
  VarType    : TString;
  MethName   : TString;
  MethRetType: TString;
  InBody     : Boolean;
  Depth      : Integer;
  MethStartSave : Integer;
Begin
  If CurToken.Kind <> TK_IDENT Then
  Begin
    WarnMsg('nom de classe attendu apres "class"');
    Exit;
  End;

  { Enregistrer la classe }
  CurClassName := CurToken.Val;
  SymIdx := SymAdd(CurClassName, SC_CLASS, 0);
  ClsIdx := AddClass(CurClassName, SymIdx);
  MethStartSave := MethodCount;

  If Opts.Verbose Then
    WriteLn('  class ', CurClassName);
  Consume;

  { Attendre l accolade ouvrante }
  If Not TokIsPunct('{') Then
  Begin
    { Pas d accolade : la boucle Run gerera le reste }
    Exit;
  End;
  Consume;
  SymEnterScope;
  Depth := 1;
  InBody := True;

  { Analyser les membres de la classe }
  While InBody And (CurToken.Kind <> TK_EOF) Do
  Begin
    { Sauter les qualificateurs de visibilite }
    SkipVisibility;

    If CurToken.Kind = TK_EOF Then Break;

    { Mot-cle static : champ ou methode statique }
    If TokIsKw('static') Then
    Begin
      Consume;
      { Lire le type de retour / type de champ }
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        VarType := CurToken.Val;
        Consume;
        { Si c est un tableau (int[] etc.) on saute les [] (TODO 19) }
        PendingIsArray := False;
        If TokIsPunct('[') Then
        Begin
          Consume;
          If TokIsPunct(']') Then Consume;
          PendingIsArray := True;
          Inc(ArrayCount);
        End;
        { Nom du membre }
        If CurToken.Kind = TK_IDENT Then
        Begin
          MethName := CurToken.Val;
          MethRetType := VarType;
          Consume;
          { Si suivi de ( -> c est une methode statique }
          If TokIsPunct('(') Then
          Begin
            ParseMethodDecl(MethRetType, MethName);
            { Verifier si c est Main }
            If StrLowerCase(MethName) = 'main' Then
            Begin
              If ClsIdx >= 0 Then
                ClassTab[ClsIdx].HasMain := True;
            End;
            If ClsIdx >= 0 Then
              Inc(ClassTab[ClsIdx].MethCount);
            { Parser le corps de la methode }
            If TokIsPunct('{') Then
            Begin
              Inc(Depth);
              Consume;
              SymEnterScope;
              EmitBlankLine;
              EmitComment('--- method ' + MethName + ' ---');
              EmitLabel(SymMangle(MethName, SC_METHOD));
              EmitProlog(METHOD_STACK_SIZE);
              MethExitLbl := GenLabel;
              ResetGotoLabels;  { TODO 22 }
              ParseMethodBody;
              EmitLabel(MethExitLbl);
              If StrLowerCase(MethName) = 'main' Then
              Begin
                EmitInstr('PUSH', '0');
                EmitInstr('CALL', '_ExitProcess@4');
              End;
              EmitEpilog;
              MethExitLbl := '';
              { Consommer accolade fermante du corps }
              If TokIsPunct('}') Then
              Begin
                Dec(Depth);
                SymLeaveScope;
                Consume;
              End;
            End;
          End
          Else
          Begin
            { C est un champ statique : static type name [= val]; }
            SymIdx := SymAdd(MethName, SC_STATIC,
                             TypeFromKeyword(VarType));
            If SymIdx >= 0 Then
            Begin
              SymTab[SymIdx].IsStatic := True;
              SymTab[SymIdx].IsGlobal := True;
              Off := DataAddStaticVar(CurClassName, MethName,
                                      TypeFromKeyword(VarType));
              { Gerer l initialisation = valeur }
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
                    DataAddStaticVar(CurClassName, CurToken.Val,
                                     TypeFromKeyword(VarType));
                  End;
                  Consume;
                End;
              End;
              If ClsIdx >= 0 Then
                Inc(ClassTab[ClsIdx].FieldCount);
            End;
            If Opts.DebugMode Then
              WriteLn('  FIELD_STATIC: ', MethName, ' type=', VarType);
          End;
        End;
      End;
    End
    { Declarations const dans la classe }
    Else If TokIsKw('const') Then
    Begin
      Consume;
      ParseConstDecl;
    End
    { Declarations readonly dans la classe }
    Else If TokIsKw('readonly') Then
    Begin
      Consume; { ignorer readonly, traite comme const implicite }
    End
    { Declarations de type dans la classe (variables d instance ignorees) }
    Else If IsTypeKeyword Then
    Begin
      VarType := CurToken.Val;
      Consume;
      { Sauter [] si tableau (TODO 19) }
      PendingIsArray := False;
      If TokIsPunct('[') Then
      Begin
        Consume;
        If TokIsPunct(']') Then Consume;
        PendingIsArray := True;
        Inc(ArrayCount);
      End;
      If CurToken.Kind = TK_IDENT Then
        ParseVarDecl(VarType, True, CurClassName);
    End
    { Accolade fermante de la classe }
    Else If TokIsPunct('}') Then
    Begin
      Dec(Depth);
      If Depth <= 0 Then
      Begin
        SymLeaveScope;
        Consume;
        InBody := False;
      End
      Else
      Begin
        SymLeaveScope;
        Consume;
      End;
    End
    { Accolade ouvrante imbriquee }
    Else If TokIsPunct('{') Then
    Begin
      Inc(Depth);
      SymEnterScope;
      Consume;
    End
    Else
      Consume;
  End;

  { Mettre a jour le nombre de methodes de la classe }
  If ClsIdx >= 0 Then
    ClassTab[ClsIdx].MethCount := MethodCount - MethStartSave;
End;

{ ============================================================ }
{ TODO 18 - ESPACES DE NOMS (namespace)                         }
{           [IMPLEMENTE]                                        }
{ ============================================================ }
(*                                                               *)
(*  ParseNamespaceDecl : namespace Nom { classes }.              *)
(*    Le namespace englobe les declarations de classes.           *)
(*    Namespace comme enveloppe syntaxique : la declaration       *)
(*    est reconnue et le nom enregistre dans NsTab, mais         *)
(*    n affecte pas la generation de code dans le sous-           *)
(*    ensemble minimal.                                          *)
(*  Noms qualifies : namespace A.B.C { ... } reconnus,           *)
(*    traites comme un seul namespace de nom A.B.C.              *)
(*  FindNs / AddNs : recherche / ajout dans NsTab.              *)
(*  NsDepth : profondeur d imbrication des namespaces.           *)
(*  CurNsName : nom du namespace en cours d analyse.             *)
(*                                                               *)

{ ------------------------------------------------------------ }
{ FindNs : recherche un namespace par nom dans NsTab            }
{   Retourne l indice (0..NsCount-1) ou -1 si non trouve        }
{ ------------------------------------------------------------ }

Function FindNs(Const N : TString) : Integer;
Var I : Integer;
Begin
  FindNs := -1;
  For I := 0 To NsCount - 1 Do
    If NsTab[I].Name = N Then
    Begin
      FindNs := I;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ AddNs : ajoute un namespace dans NsTab                        }
{   N    = nom C# du namespace (ex. MyApp.Models)                }
{   SIdx = indice dans SymTab du symbole namespace               }
{   Retourne l indice dans NsTab ou -1 si table pleine           }
{ ------------------------------------------------------------ }

Function AddNs(Const N : TString; SIdx : Integer) : Integer;
Var Idx : Integer;
Begin
  AddNs := -1;
  { Verifier si deja declare }
  Idx := FindNs(N);
  If Idx >= 0 Then
  Begin
    AddNs := Idx;
    Exit;
  End;
  { Verifier la capacite }
  If NsCount >= MAX_NS Then
  Begin
    FatalError('trop de namespaces declares (max=' + IntToStr_(MAX_NS) + ')');
    Exit;
  End;
  Idx := NsCount;
  NsTab[Idx].Name        := N;
  NsTab[Idx].MangledName := CSC_NS_PFX + StrUpperCase(N);
  NsTab[Idx].SymIdx      := SIdx;
  NsTab[Idx].ClassStart  := ClassCount;
  NsTab[Idx].ClassCount  := 0;
  NsTab[Idx].Depth       := NsDepth;
  Inc(NsCount);
  AddNs := Idx;
End;

{ ------------------------------------------------------------ }
{ ParseNamespaceDecl : parse namespace Nom ...                  }
{   Attend : le mot-cle 'namespace' deja consomme, le curseur   }
{   pointe sur le nom du namespace.                              }
{   Parse le nom (eventuellement qualifie A.B.C), ouvre          }
{   l accolade, parse les classes et declarations internes,     }
{   puis ferme l accolade.                                      }
{ ------------------------------------------------------------ }

Procedure ParseNamespaceDecl;
Var
  NName      : TString;
  NIdx       : Integer;
  SIdx       : Integer;
  SaveNsName : TString;
Begin
  { Lire le nom du namespace }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    FatalError('nom de namespace attendu');
    Exit;
  End;

  NName := CurToken.Val;
  Consume;

  { Gerer les noms qualifies : namespace A.B.C }
  While TokIsPunct('.') Do
  Begin
    Consume;
    If CurToken.Kind = TK_IDENT Then
    Begin
      NName := NName + '.' + CurToken.Val;
      Consume;
    End
    Else
    Begin
      FatalError('identificateur attendu apres . dans le nom de namespace');
      Exit;
    End;
  End;

  { Enregistrer le symbole dans la table des symboles }
  SIdx := SymAdd(NName, SC_NAMESPACE, 0);

  { Ajouter dans la table des namespaces }
  NIdx := AddNs(NName, SIdx);

  If Opts.Verbose Then
    WriteLn('  namespace ', NName, ' (idx=', NIdx, ')');

  { Sauvegarder l etat du namespace courant }
  SaveNsName := CurNsName;
  CurNsName  := NName;
  Inc(NsDepth);

  { Attendre l accolade ouvrante }
  If Not TokIsPunct('{') Then
  Begin
    FatalError('accolade ouvrante attendue apres le nom de namespace');
    CurNsName := SaveNsName;
    Dec(NsDepth);
    Exit;
  End;
  Consume;

  { Parser le contenu du namespace }
  While (CurToken.Kind <> TK_EOF) And (Not TokIsPunct('}')) Do
  Begin
    { Reconnaitre les declarations internes }
    If TokIsKw('namespace') Then
    Begin
      Consume;
      ParseNamespaceDecl;
    End
    Else If TokIsKw('class') Then
    Begin
      Consume;
      ParseClassDecl;
      { Incrementer le compteur de classes du namespace }
      If NIdx >= 0 Then
        Inc(NsTab[NIdx].ClassCount);
    End
    Else If (TokIsKw('public') Or TokIsKw('private') Or
             TokIsKw('protected') Or TokIsKw('internal')) Then
    Begin
      Consume; { ignorer la visibilite }
      { Si suivi de class -> ParseClassDecl }
      If TokIsKw('class') Then
      Begin
        Consume;
        ParseClassDecl;
        If NIdx >= 0 Then
          Inc(NsTab[NIdx].ClassCount);
      End
      { Si suivi de static -> on ne consomme pas, le niveau parent gerera }
      Else If TokIsKw('static') Then
      Begin
        { Ne rien faire, le static sera traite par la boucle suivante }
      End
      Else If TokIsKw('namespace') Then
      Begin
        Consume;
        ParseNamespaceDecl;
      End;
    End
    Else If TokIsKw('const') Then
    Begin
      Consume;
      ParseConstDecl;
    End
    Else If CurToken.Kind = TK_STRING Then
    Begin
      AddStrLit(CurToken.Val);
      Consume;
    End
    Else
    Begin
      { Token non reconnu dans le namespace, avancer }
      Consume;
    End;
  End;

  { Consommer l accolade fermante }
  If TokIsPunct('}') Then
    Consume
  Else
    FatalError('accolade fermante attendue pour fermer le namespace ' + NName);

  { Restaurer l etat }
  CurNsName := SaveNsName;
  Dec(NsDepth);
End;

{ ============================================================ }
{ TODO 24 - RUNTIME MINIMAL WIN32                               }
{           [IMPLEMENTE]                                        }
{ ============================================================ }
{                                                               }
{  Routines runtime emises directement dans le segment .CODE    }
{  du fichier assembleur genere. Ces routines fournissent les   }
{  services de base : affichage, lecture, chaines, memoire.     }
{  EmitEntryPoint genere le point d entree _CSCF_MAIN qui      }
{  initialise les handles Win32 et appelle _CSCF_Main.          }
{  EmitRuntimeHelpers genere les 20 routines _CSCRT_*.          }
{                                                               }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ EmitEntryPoint                                                }
{   Generer le point d entree _CSCF_MAIN :                     }
{   - GetStdHandle(STD_OUTPUT_HANDLE) -> _CSC_HSTDOUT           }
{   - GetStdHandle(STD_INPUT_HANDLE)  -> _CSC_HSTDIN            }
{   - GetProcessHeap -> _CSC_HHEAP                              }
{   - CALL _CSCF_Main                                           }
{   - PUSH 0 / CALL ExitProcess                                 }
{ ------------------------------------------------------------ }

Procedure EmitEntryPoint;
Begin
  EmitBlankLine;
  EmitComment('=== Point d entree Win32 (TODO 24) ===');
  EmitLabel('_CSC_ENTRY');
  EmitInstr('PUSH', 'EBP');
  EmitInstr('MOV', 'EBP,ESP');
  EmitBlankLine;

  { GetStdHandle(STD_OUTPUT_HANDLE = -11) -> _CSC_HSTDOUT }
  EmitComment('Initialiser handle stdout');
  EmitInstr('PUSH', '-11');
  EmitInstr('CALL', '_GetStdHandle@4');
  EmitInstr('MOV', 'DWORD PTR [_CSC_HSTDOUT],EAX');
  EmitBlankLine;

  { GetStdHandle(STD_INPUT_HANDLE = -10) -> _CSC_HSTDIN }
  EmitComment('Initialiser handle stdin');
  EmitInstr('PUSH', '-10');
  EmitInstr('CALL', '_GetStdHandle@4');
  EmitInstr('MOV', 'DWORD PTR [_CSC_HSTDIN],EAX');
  EmitBlankLine;

  { GetProcessHeap -> _CSC_HHEAP }
  EmitComment('Initialiser handle heap');
  EmitInstr('CALL', '_GetProcessHeap@0');
  EmitInstr('MOV', 'DWORD PTR [_CSC_HHEAP],EAX');
  EmitBlankLine;

  { Appeler Main() }
  EmitComment('Appeler le point d entree utilisateur');
  EmitInstr('CALL', '_CSCF_MAIN');
  EmitBlankLine;

  { ExitProcess(0) }
  EmitComment('Terminer le processus');
  EmitInstr('PUSH', '0');
  EmitInstr('CALL', '_ExitProcess@4');

  EmitInstr('MOV', 'ESP,EBP');
  EmitInstr('POP', 'EBP');
  EmitInstr('RET', '');
  EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ EmitRuntimeHelpers                                            }
{   Generer les 20 routines runtime _CSCRT_* dans le .CODE      }
{ ------------------------------------------------------------ }

Procedure EmitRuntimeHelpers;
Var
  Lbl1, Lbl2, Lbl3, Lbl4 : TString;
Begin
  RuntimeHelpCount := 0;

  EmitBlankLine;
  EmitComment('=== Routines runtime Win32 (TODO 24) ===');
  EmitBlankLine;

  { ---- _CSCRT_STRLEN ---- }
  { ESI = chaine ASCIIZ, retour EAX = longueur }
  EmitComment('_CSCRT_STRLEN : longueur chaine ASCIIZ');
  EmitLabel('_CSCRT_STRLEN');
  EmitInstr('PUSH', 'ECX');
  EmitInstr('PUSH', 'EDI');
  EmitInstr('MOV', 'EDI,ESI');
  EmitInstr('XOR', 'ECX,ECX');
  EmitInstr('DEC', 'ECX');            { ECX = -1 = 0FFFFFFFFh }
  EmitInstr('XOR', 'EAX,EAX');       { AL = 0 (chercher le 0) }
  EmitInstr('REPNE', 'SCASB');
  EmitInstr('NOT', 'ECX');
  EmitInstr('DEC', 'ECX');            { ECX = longueur sans le 0 final }
  EmitInstr('MOV', 'EAX,ECX');
  EmitInstr('POP', 'EDI');
  EmitInstr('POP', 'ECX');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_PRINTSTR ---- }
  { ESI = chaine ASCIIZ -> WriteFile(hStdOut, ESI, len, &written, 0) }
  EmitComment('_CSCRT_PRINTSTR : afficher chaine ASCIIZ');
  EmitLabel('_CSCRT_PRINTSTR');
  EmitInstr('PUSHAD', '');
  EmitInstr('CALL', '_CSCRT_STRLEN');  { EAX = longueur }
  EmitInstr('TEST', 'EAX,EAX');
  Lbl1 := GenLabel;
  EmitInstr('JZ', Lbl1);
  EmitInstr('PUSH', '0');              { lpOverlapped = NULL }
  EmitInstr('PUSH', 'OFFSET _CSC_WRITTEN');
  EmitInstr('PUSH', 'EAX');           { nNumberOfBytesToWrite }
  EmitInstr('PUSH', 'ESI');           { lpBuffer }
  EmitInstr('PUSH', 'DWORD PTR [_CSC_HSTDOUT]');
  EmitInstr('CALL', '_WriteFile@20');
  EmitLabel(Lbl1);
  EmitInstr('POPAD', '');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_PRINTCRLF ---- }
  EmitComment('_CSCRT_PRINTCRLF : afficher CR+LF');
  EmitLabel('_CSCRT_PRINTCRLF');
  EmitInstr('PUSH', 'ESI');
  EmitInstr('MOV', 'ESI,OFFSET _CSC_CRLF');
  EmitInstr('CALL', '_CSCRT_PRINTSTR');
  EmitInstr('POP', 'ESI');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_PRINTCHAR ---- }
  { EAX = caractere a afficher }
  EmitComment('_CSCRT_PRINTCHAR : afficher un caractere (EAX)');
  EmitLabel('_CSCRT_PRINTCHAR');
  EmitInstr('PUSHAD', '');
  EmitInstr('PUSH', 'EAX');           { mettre le char sur la pile }
  EmitInstr('MOV', 'ESI,ESP');        { ESI pointe sur le char }
  EmitInstr('PUSH', '0');
  EmitInstr('PUSH', 'OFFSET _CSC_WRITTEN');
  EmitInstr('PUSH', '1');             { 1 octet }
  EmitInstr('PUSH', 'ESI');           { pointeur sur le char }
  EmitInstr('PUSH', 'DWORD PTR [_CSC_HSTDOUT]');
  EmitInstr('CALL', '_WriteFile@20');
  EmitInstr('ADD', 'ESP,4');          { enlever le char de la pile }
  EmitInstr('POPAD', '');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_NUMTOSTR ---- }
  { EAX = entier signe, EDI = tampon destination }
  { Convertit l entier en chaine ASCII terminee par 0 }
  EmitComment('_CSCRT_NUMTOSTR : entier signe -> ASCII (EAX->EDI)');
  EmitLabel('_CSCRT_NUMTOSTR');
  EmitInstr('PUSHAD', '');
  EmitInstr('MOV', 'ESI,EDI');        { sauver debut du tampon }
  EmitInstr('TEST', 'EAX,EAX');
  Lbl1 := GenLabel;
  EmitInstr('JNS', Lbl1);            { si positif, sauter }
  EmitInstr('MOV', 'BYTE PTR [EDI],45'); { '-' }
  EmitInstr('INC', 'EDI');
  EmitInstr('NEG', 'EAX');
  EmitLabel(Lbl1);
  { Division successive par 10, empiler les chiffres }
  EmitInstr('MOV', 'ECX,0');          { compteur de chiffres }
  EmitInstr('MOV', 'EBX,10');
  Lbl2 := GenLabel;
  EmitLabel(Lbl2);
  EmitInstr('XOR', 'EDX,EDX');
  EmitInstr('DIV', 'EBX');           { EAX = quotient, EDX = reste }
  EmitInstr('ADD', 'DL,48');         { reste + '0' }
  EmitInstr('PUSH', 'EDX');          { empiler le chiffre }
  EmitInstr('INC', 'ECX');
  EmitInstr('TEST', 'EAX,EAX');
  EmitInstr('JNZ', Lbl2);
  { Depiler les chiffres dans l ordre }
  Lbl3 := GenLabel;
  EmitLabel(Lbl3);
  EmitInstr('POP', 'EAX');
  EmitInstr('MOV', 'BYTE PTR [EDI],AL');
  EmitInstr('INC', 'EDI');
  EmitInstr('DEC', 'ECX');
  EmitInstr('JNZ', Lbl3);
  EmitInstr('MOV', 'BYTE PTR [EDI],0'); { terminateur nul }
  EmitInstr('POPAD', '');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_PRINTINT ---- }
  { EAX = entier signe -> convertir et afficher }
  EmitComment('_CSCRT_PRINTINT : afficher entier signe (EAX)');
  EmitLabel('_CSCRT_PRINTINT');
  EmitInstr('PUSHAD', '');
  EmitInstr('MOV', 'EDI,OFFSET _CSC_NUMBUF');
  EmitInstr('CALL', '_CSCRT_NUMTOSTR');
  EmitInstr('MOV', 'ESI,OFFSET _CSC_NUMBUF');
  EmitInstr('CALL', '_CSCRT_PRINTSTR');
  EmitInstr('POPAD', '');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_PRINTBOOL ---- }
  { EAX = 0 -> "False", sinon -> "True" }
  EmitComment('_CSCRT_PRINTBOOL : afficher "True" ou "False" (EAX)');
  EmitLabel('_CSCRT_PRINTBOOL');
  EmitInstr('PUSH', 'ESI');
  EmitInstr('TEST', 'EAX,EAX');
  Lbl1 := GenLabel;
  EmitInstr('JZ', Lbl1);
  EmitInstr('MOV', 'ESI,OFFSET _CSC_TRUE');
  Lbl2 := GenLabel;
  EmitInstr('JMP', Lbl2);
  EmitLabel(Lbl1);
  EmitInstr('MOV', 'ESI,OFFSET _CSC_FALSE');
  EmitLabel(Lbl2);
  EmitInstr('CALL', '_CSCRT_PRINTSTR');
  EmitInstr('POP', 'ESI');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_STRTONUM ---- }
  { ESI = chaine ASCII -> EAX = entier signe }
  EmitComment('_CSCRT_STRTONUM : ASCII -> entier signe (ESI->EAX)');
  EmitLabel('_CSCRT_STRTONUM');
  EmitInstr('PUSH', 'EBX');
  EmitInstr('PUSH', 'ECX');
  EmitInstr('PUSH', 'EDX');
  EmitInstr('XOR', 'EAX,EAX');       { resultat = 0 }
  EmitInstr('XOR', 'ECX,ECX');       { signe = 0 (positif) }
  EmitInstr('MOV', 'BL,BYTE PTR [ESI]');
  EmitInstr('CMP', 'BL,45');         { '-' ? }
  Lbl1 := GenLabel;
  EmitInstr('JNE', Lbl1);
  EmitInstr('MOV', 'ECX,1');          { signe negatif }
  EmitInstr('INC', 'ESI');
  EmitLabel(Lbl1);
  EmitInstr('CMP', 'BL,43');         { '+' ? }
  Lbl2 := GenLabel;
  EmitInstr('JNE', Lbl2);
  EmitInstr('INC', 'ESI');
  EmitLabel(Lbl2);
  { Boucle de lecture des chiffres }
  Lbl3 := GenLabel;
  Lbl4 := GenLabel;
  EmitLabel(Lbl3);
  EmitInstr('MOVZX', 'EBX,BYTE PTR [ESI]');
  EmitInstr('TEST', 'BL,BL');
  EmitInstr('JZ', Lbl4);
  EmitInstr('SUB', 'BL,48');         { BL = BL - '0' }
  EmitInstr('CMP', 'BL,9');
  EmitInstr('JA', Lbl4);             { pas un chiffre -> fin }
  EmitInstr('IMUL', 'EAX,10');
  EmitInstr('ADD', 'EAX,EBX');
  EmitInstr('INC', 'ESI');
  EmitInstr('JMP', Lbl3);
  EmitLabel(Lbl4);
  { Appliquer le signe }
  EmitInstr('TEST', 'ECX,ECX');
  Lbl1 := GenLabel;
  EmitInstr('JZ', Lbl1);
  EmitInstr('NEG', 'EAX');
  EmitLabel(Lbl1);
  EmitInstr('POP', 'EDX');
  EmitInstr('POP', 'ECX');
  EmitInstr('POP', 'EBX');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_STRCMP ---- }
  { ESI = s1, EDI = s2 -> drapeaux (ZF si egal) }
  EmitComment('_CSCRT_STRCMP : comparer deux chaines (ESI,EDI->flags)');
  EmitLabel('_CSCRT_STRCMP');
  EmitInstr('PUSH', 'ESI');
  EmitInstr('PUSH', 'EDI');
  Lbl1 := GenLabel;
  Lbl2 := GenLabel;
  EmitLabel(Lbl1);
  EmitInstr('MOV', 'AL,BYTE PTR [ESI]');
  EmitInstr('MOV', 'AH,BYTE PTR [EDI]');
  EmitInstr('CMP', 'AL,AH');
  EmitInstr('JNE', Lbl2);
  EmitInstr('TEST', 'AL,AL');
  EmitInstr('JZ', Lbl2);
  EmitInstr('INC', 'ESI');
  EmitInstr('INC', 'EDI');
  EmitInstr('JMP', Lbl1);
  EmitLabel(Lbl2);
  EmitInstr('POP', 'EDI');
  EmitInstr('POP', 'ESI');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_STRCPY ---- }
  { ESI = source, EDI = destination }
  EmitComment('_CSCRT_STRCPY : copier chaine (ESI->EDI)');
  EmitLabel('_CSCRT_STRCPY');
  EmitInstr('PUSH', 'ESI');
  EmitInstr('PUSH', 'EDI');
  Lbl1 := GenLabel;
  EmitLabel(Lbl1);
  EmitInstr('MOV', 'AL,BYTE PTR [ESI]');
  EmitInstr('MOV', 'BYTE PTR [EDI],AL');
  EmitInstr('INC', 'ESI');
  EmitInstr('INC', 'EDI');
  EmitInstr('TEST', 'AL,AL');
  EmitInstr('JNZ', Lbl1);
  EmitInstr('POP', 'EDI');
  EmitInstr('POP', 'ESI');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_STRCAT ---- }
  { ESI = s1, EDI = s2 -> EAX = nouvelle chaine (HeapAlloc) }
  EmitComment('_CSCRT_STRCAT : concatener chaines (ESI+EDI->EAX)');
  EmitLabel('_CSCRT_STRCAT');
  EmitInstr('PUSHAD', '');
  { Calculer longueur s1 }
  EmitInstr('CALL', '_CSCRT_STRLEN'); { EAX = len(s1) }
  EmitInstr('MOV', 'EBX,EAX');       { EBX = len(s1) }
  { Calculer longueur s2 }
  EmitInstr('PUSH', 'ESI');
  EmitInstr('MOV', 'ESI,EDI');
  EmitInstr('CALL', '_CSCRT_STRLEN'); { EAX = len(s2) }
  EmitInstr('POP', 'ESI');
  EmitInstr('ADD', 'EBX,EAX');       { EBX = len(s1) + len(s2) }
  EmitInstr('INC', 'EBX');            { +1 pour le 0 final }
  { Allouer la memoire }
  EmitInstr('PUSH', 'EBX');           { taille }
  EmitInstr('PUSH', '0');              { flags = 0 }
  EmitInstr('PUSH', 'DWORD PTR [_CSC_HHEAP]');
  EmitInstr('CALL', '_HeapAlloc@12');
  EmitInstr('MOV', 'DWORD PTR [ESP+28],EAX'); { sauver dans POPAD.EAX }
  { Copier s1 }
  EmitInstr('MOV', 'ECX,EAX');       { ECX = dest }
  EmitInstr('PUSH', 'EDI');           { sauver s2 }
  EmitInstr('MOV', 'EDI,ECX');
  EmitInstr('CALL', '_CSCRT_STRCPY');
  { Trouver la fin de la copie }
  Lbl1 := GenLabel;
  EmitLabel(Lbl1);
  EmitInstr('CMP', 'BYTE PTR [EDI],0');
  Lbl2 := GenLabel;
  EmitInstr('JE', Lbl2);
  EmitInstr('INC', 'EDI');
  EmitInstr('JMP', Lbl1);
  EmitLabel(Lbl2);
  { Copier s2 a la fin }
  EmitInstr('POP', 'ESI');            { ESI = s2 (sauve avant) }
  EmitInstr('CALL', '_CSCRT_STRCPY');
  EmitInstr('POPAD', '');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_READSTR ---- }
  { EDI = tampon destination, lit une ligne depuis stdin }
  EmitComment('_CSCRT_READSTR : lire ligne stdin (EDI=buf)');
  EmitLabel('_CSCRT_READSTR');
  EmitInstr('PUSHAD', '');
  EmitInstr('PUSH', '0');              { lpOverlapped }
  EmitInstr('PUSH', 'OFFSET _CSC_READCNT');
  EmitInstr('PUSH', '254');            { nNumberOfBytesToRead }
  EmitInstr('PUSH', 'EDI');            { lpBuffer }
  EmitInstr('PUSH', 'DWORD PTR [_CSC_HSTDIN]');
  EmitInstr('CALL', '_ReadFile@20');
  { Retirer CR/LF en fin de ligne }
  EmitInstr('MOV', 'ECX,DWORD PTR [_CSC_READCNT]');
  Lbl1 := GenLabel;
  Lbl2 := GenLabel;
  EmitInstr('TEST', 'ECX,ECX');
  EmitInstr('JZ', Lbl2);
  EmitLabel(Lbl1);
  EmitInstr('DEC', 'ECX');
  EmitInstr('CMP', 'BYTE PTR [EDI+ECX],13');  { CR }
  Lbl3 := GenLabel;
  EmitInstr('JE', Lbl3);
  EmitInstr('CMP', 'BYTE PTR [EDI+ECX],10');  { LF }
  EmitInstr('JE', Lbl3);
  EmitInstr('INC', 'ECX');            { pas CR/LF, garder }
  EmitInstr('JMP', Lbl2);
  EmitLabel(Lbl3);
  EmitInstr('TEST', 'ECX,ECX');
  EmitInstr('JNZ', Lbl1);
  EmitLabel(Lbl2);
  EmitInstr('MOV', 'BYTE PTR [EDI+ECX],0');  { terminateur nul }
  EmitInstr('POPAD', '');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_READINT ---- }
  { Lire une ligne depuis stdin, convertir en entier -> EAX }
  EmitComment('_CSCRT_READINT : lire entier depuis stdin -> EAX');
  EmitLabel('_CSCRT_READINT');
  EmitInstr('PUSH', 'EDI');
  EmitInstr('PUSH', 'ESI');
  EmitInstr('MOV', 'EDI,OFFSET _CSC_INBUF');
  EmitInstr('CALL', '_CSCRT_READSTR');
  EmitInstr('MOV', 'ESI,OFFSET _CSC_INBUF');
  EmitInstr('CALL', '_CSCRT_STRTONUM');
  EmitInstr('POP', 'ESI');
  EmitInstr('POP', 'EDI');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_READCHAR ---- }
  { Lire un seul caractere depuis stdin -> EAX }
  EmitComment('_CSCRT_READCHAR : lire un caractere stdin -> EAX');
  EmitLabel('_CSCRT_READCHAR');
  EmitInstr('PUSH', 'EBX');
  EmitInstr('XOR', 'EAX,EAX');
  EmitInstr('PUSH', 'EAX');           { buffer 1 byte sur la pile }
  EmitInstr('MOV', 'EBX,ESP');        { EBX pointe sur le buffer }
  EmitInstr('PUSH', '0');
  EmitInstr('PUSH', 'OFFSET _CSC_READCNT');
  EmitInstr('PUSH', '1');
  EmitInstr('PUSH', 'EBX');
  EmitInstr('PUSH', 'DWORD PTR [_CSC_HSTDIN]');
  EmitInstr('CALL', '_ReadFile@20');
  EmitInstr('POP', 'EAX');           { recuperer le caractere }
  EmitInstr('AND', 'EAX,0FFh');
  EmitInstr('POP', 'EBX');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_READLN ---- }
  { Consommer caracteres jusqu au prochain CR+LF }
  EmitComment('_CSCRT_READLN : consommer jusqu au CR+LF');
  EmitLabel('_CSCRT_READLN');
  EmitInstr('PUSH', 'EDI');
  EmitInstr('MOV', 'EDI,OFFSET _CSC_INBUF');
  EmitInstr('CALL', '_CSCRT_READSTR');
  EmitInstr('POP', 'EDI');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_MALLOC ---- }
  { EAX = taille -> EAX = pointeur }
  EmitComment('_CSCRT_MALLOC : allouer memoire (EAX=size->EAX=ptr)');
  EmitLabel('_CSCRT_MALLOC');
  EmitInstr('PUSH', 'EAX');           { taille }
  EmitInstr('PUSH', '0');              { flags = 0 }
  EmitInstr('PUSH', 'DWORD PTR [_CSC_HHEAP]');
  EmitInstr('CALL', '_HeapAlloc@12');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_FREE ---- }
  { EAX = pointeur a liberer }
  EmitComment('_CSCRT_FREE : liberer memoire (EAX=ptr)');
  EmitLabel('_CSCRT_FREE');
  EmitInstr('PUSH', 'EAX');           { lpMem }
  EmitInstr('PUSH', '0');              { dwFlags = 0 }
  EmitInstr('PUSH', 'DWORD PTR [_CSC_HHEAP]');
  EmitInstr('CALL', '_HeapFree@12');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_MEMCPY ---- }
  { ESI = src, EDI = dst, ECX = len }
  EmitComment('_CSCRT_MEMCPY : copie memoire (ESI->EDI, ECX octets)');
  EmitLabel('_CSCRT_MEMCPY');
  EmitInstr('PUSH', 'ESI');
  EmitInstr('PUSH', 'EDI');
  EmitInstr('PUSH', 'ECX');
  EmitInstr('REP', 'MOVSB');
  EmitInstr('POP', 'ECX');
  EmitInstr('POP', 'EDI');
  EmitInstr('POP', 'ESI');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_MEMSET ---- }
  { EDI = dst, EAX = val (AL), ECX = len }
  EmitComment('_CSCRT_MEMSET : remplissage memoire (EDI,AL,ECX)');
  EmitLabel('_CSCRT_MEMSET');
  EmitInstr('PUSH', 'EDI');
  EmitInstr('PUSH', 'ECX');
  EmitInstr('REP', 'STOSB');
  EmitInstr('POP', 'ECX');
  EmitInstr('POP', 'EDI');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);

  { ---- _CSCRT_PANIC ---- }
  { ESI = message d erreur -> afficher et ExitProcess(1) }
  EmitComment('_CSCRT_PANIC : message d erreur + ExitProcess(1)');
  EmitLabel('_CSCRT_PANIC');
  EmitInstr('PUSH', 'ESI');
  EmitInstr('MOV', 'ESI,OFFSET _CSC_PANIC_MSG');
  EmitInstr('CALL', '_CSCRT_PRINTSTR');
  EmitInstr('POP', 'ESI');
  EmitInstr('CALL', '_CSCRT_PRINTSTR');
  EmitInstr('CALL', '_CSCRT_PRINTCRLF');
  EmitInstr('PUSH', '1');
  EmitInstr('CALL', '_ExitProcess@4');
  EmitInstr('RET', '');
  EmitBlankLine;
  Inc(RuntimeHelpCount);
End;

{ ============================================================ }
{ TODO 25 - GENERATION PE/COFF ET FICHIERS EXEMPLES             }
{           [IMPLEMENTE]                                        }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ BinInit - Initialiser les buffers binaires                    }
{ ------------------------------------------------------------ }

Procedure BinInit;
Begin
  BinCodeLen := 0;
  BinDataLen := 0;
  BinLblCount := 0;
  BinFixCount := 0;
  BinInCode := True;
End;

{ ------------------------------------------------------------ }
{ Emission d octets dans les buffers code et donnees            }
{ ------------------------------------------------------------ }

Procedure BinEmitByte(B : Byte);
Begin
  If BinCodeLen < MAX_BIN_CODE Then
  Begin
    BinCode[BinCodeLen] := B;
    Inc(BinCodeLen);
  End;
End;

Procedure BinEmitWord(W : Word);
Begin
  BinEmitByte(Byte(W And $FF));
  BinEmitByte(Byte((W Shr 8) And $FF));
End;

Procedure BinEmitDWord(D : LongInt);
Begin
  BinEmitByte(Byte(D And $FF));
  BinEmitByte(Byte((D Shr 8) And $FF));
  BinEmitByte(Byte((D Shr 16) And $FF));
  BinEmitByte(Byte((D Shr 24) And $FF));
End;

Procedure BinEmitDataByte(B : Byte);
Begin
  If BinDataLen < MAX_BIN_DATA Then
  Begin
    BinData[BinDataLen] := B;
    Inc(BinDataLen);
  End;
End;

Procedure BinEmitDataWord(W : Word);
Begin
  BinEmitDataByte(Byte(W And $FF));
  BinEmitDataByte(Byte((W Shr 8) And $FF));
End;

Procedure BinEmitDataDWord(D : LongInt);
Begin
  BinEmitDataByte(Byte(D And $FF));
  BinEmitDataByte(Byte((D Shr 8) And $FF));
  BinEmitDataByte(Byte((D Shr 16) And $FF));
  BinEmitDataByte(Byte((D Shr 24) And $FF));
End;

{ ------------------------------------------------------------ }
{ Labels et fixups                                              }
{ ------------------------------------------------------------ }

Procedure BinAddLabel(AName : TString; AnOfs : LongInt);
Begin
  If BinLblCount < MAX_BIN_LBL Then
  Begin
    BinLabels[BinLblCount].Name := AName;
    BinLabels[BinLblCount].Offset := AnOfs;
    BinLabels[BinLblCount].InCode := BinInCode;
    Inc(BinLblCount);
  End;
End;

Function BinFindLabel(AName : TString) : LongInt;
Var I : Integer;
    UName : TString;
Begin
  UName := StrUpperCase(AName);
  For I := 0 To BinLblCount - 1 Do
    If StrUpperCase(BinLabels[I].Name) = UName Then
    Begin
      BinFindLabel := I;
      Exit;
    End;
  BinFindLabel := -1;
End;

Procedure BinAddFixup(AnOfs : LongInt; AKind : TBinFixKind;
                      ATarget : TString; AInCode : Boolean);
Begin
  If BinFixCount < MAX_BIN_FIX Then
  Begin
    BinFixups[BinFixCount].Offset := AnOfs;
    BinFixups[BinFixCount].Kind := AKind;
    BinFixups[BinFixCount].Target := ATarget;
    BinFixups[BinFixCount].InCode := AInCode;
    Inc(BinFixCount);
  End;
End;

{ ------------------------------------------------------------ }
{ File writing helpers                                          }
{ ------------------------------------------------------------ }

Procedure WriteBinByte(Var F : File; B : Byte);
Begin
  BlockWrite(F, B, 1);
End;

Procedure WriteBinWord(Var F : File; W : Word);
Var Buf : Array[0..1] Of Byte;
Begin
  Buf[0] := Byte(W And $FF);
  Buf[1] := Byte((W Shr 8) And $FF);
  BlockWrite(F, Buf, 2);
End;

Procedure WriteBinDWord(Var F : File; D : LongInt);
Var Buf : Array[0..3] Of Byte;
Begin
  Buf[0] := Byte(D And $FF);
  Buf[1] := Byte((D Shr 8) And $FF);
  Buf[2] := Byte((D Shr 16) And $FF);
  Buf[3] := Byte((D Shr 24) And $FF);
  BlockWrite(F, Buf, 4);
End;

Procedure WriteBinZeros(Var F : File; Count : LongInt);
Var
  ZBuf : Array[0..511] Of Byte;
  N    : LongInt;
Begin
  FillChar(ZBuf, SizeOf(ZBuf), 0);
  While Count > 0 Do
  Begin
    N := Count;
    If N > 512 Then N := 512;
    BlockWrite(F, ZBuf, N);
    Dec(Count, N);
  End;
End;

Procedure WriteBinString(Var F : File; Const S : TString);
Begin
  If Length(S) > 0 Then
    BlockWrite(F, S[1], Length(S));
End;

Function AlignUp(V, A : LongInt) : LongInt;
Begin
  If (V Mod A) = 0 Then
    AlignUp := V
  Else
    AlignUp := V + (A - (V Mod A));
End;

{ ------------------------------------------------------------ }
{ Mini assembleur x86 - fonctions d aide                        }
{ ------------------------------------------------------------ }

Function AsmRegIdx32(Const R : TString) : Integer;
Begin
  If R = 'EAX' Then AsmRegIdx32 := 0
  Else If R = 'ECX' Then AsmRegIdx32 := 1
  Else If R = 'EDX' Then AsmRegIdx32 := 2
  Else If R = 'EBX' Then AsmRegIdx32 := 3
  Else If R = 'ESP' Then AsmRegIdx32 := 4
  Else If R = 'EBP' Then AsmRegIdx32 := 5
  Else If R = 'ESI' Then AsmRegIdx32 := 6
  Else If R = 'EDI' Then AsmRegIdx32 := 7
  Else AsmRegIdx32 := -1;
End;

Function AsmRegIdx8(Const R : TString) : Integer;
Begin
  If R = 'AL' Then AsmRegIdx8 := 0
  Else If R = 'CL' Then AsmRegIdx8 := 1
  Else If R = 'DL' Then AsmRegIdx8 := 2
  Else If R = 'BL' Then AsmRegIdx8 := 3
  Else If R = 'AH' Then AsmRegIdx8 := 4
  Else If R = 'CH' Then AsmRegIdx8 := 5
  Else If R = 'DH' Then AsmRegIdx8 := 6
  Else If R = 'BH' Then AsmRegIdx8 := 7
  Else AsmRegIdx8 := -1;
End;

Function AsmFindAPI(Const Decorated : TString) : Integer;
Var I : Integer;
Begin
  For I := 0 To PE_NUM_API - 1 Do
    If BinAPIDecorated[I] = Decorated Then
    Begin
      AsmFindAPI := I;
      Exit;
    End;
  AsmFindAPI := -1;
End;

Function AsmParseImm(Const S : TString) : LongInt;
Var
  Code : Integer;
  V    : LongInt;
  Tmp  : TString;
Begin
  Tmp := S;
  { Remove leading + }
  If (Length(Tmp) > 0) And (Tmp[1] = '+') Then
    Delete(Tmp, 1, 1);
  { Hex with $ prefix (Pascal) }
  If (Length(Tmp) > 1) And (Tmp[1] = '$') Then
  Begin
    Val(Tmp, V, Code);
    If Code = 0 Then AsmParseImm := V
    Else AsmParseImm := 0;
    Exit;
  End;
  { Hex with 0x prefix }
  If (Length(Tmp) > 2) And (Tmp[1] = '0') And
     ((Tmp[2] = 'x') Or (Tmp[2] = 'X')) Then
  Begin
    Tmp := '$' + Copy(Tmp, 3, Length(Tmp) - 2);
    Val(Tmp, V, Code);
    If Code = 0 Then AsmParseImm := V
    Else AsmParseImm := 0;
    Exit;
  End;
  { Hex with trailing h }
  If (Length(Tmp) > 1) And
     ((Tmp[Length(Tmp)] = 'h') Or (Tmp[Length(Tmp)] = 'H')) Then
  Begin
    Tmp := '$' + Copy(Tmp, 1, Length(Tmp) - 1);
    Val(Tmp, V, Code);
    If Code = 0 Then AsmParseImm := V
    Else AsmParseImm := 0;
    Exit;
  End;
  Val(Tmp, V, Code);
  If Code = 0 Then AsmParseImm := V
  Else AsmParseImm := 0;
End;

Function AsmTrimLine(Const S : TString) : TString;
Var
  R    : TString;
  I, P : Integer;
Begin
  { Strip comment starting with ; }
  R := S;
  P := 0;
  For I := 1 To Length(R) Do
    If (R[I] = ';') And (P = 0) Then
    Begin
      P := I;
      Break;
    End;
  If P > 0 Then
    R := Copy(R, 1, P - 1);
  { Trim leading/trailing spaces and tabs }
  While (Length(R) > 0) And ((R[1] = ' ') Or (R[1] = #9)) Do
    Delete(R, 1, 1);
  While (Length(R) > 0) And
        ((R[Length(R)] = ' ') Or (R[Length(R)] = #9)) Do
    Delete(R, Length(R), 1);
  AsmTrimLine := R;
End;

Function AsmIsLabel(Const S : TString) : Boolean;
Begin
  AsmIsLabel := (Length(S) > 0) And (S[Length(S)] = ':') And
                (Pos(' ', S) = 0);
End;

Function AsmExtractLabel(Const S : TString) : TString;
Begin
  If (Length(S) > 0) And (S[Length(S)] = ':') Then
    AsmExtractLabel := Copy(S, 1, Length(S) - 1)
  Else
    AsmExtractLabel := S;
End;

Function AsmStartsWith(Const S, Prefix : TString) : Boolean;
Begin
  AsmStartsWith := (Length(S) >= Length(Prefix)) And
                   (Copy(S, 1, Length(Prefix)) = Prefix);
End;

Function AsmGetMnemonic(Const Line : TString) : TString;
Var P : Integer;
Begin
  P := Pos(' ', Line);
  If P > 0 Then
    AsmGetMnemonic := Copy(Line, 1, P - 1)
  Else
    AsmGetMnemonic := Line;
End;

Function AsmGetOperands(Const Line : TString) : TString;
Var
  P : Integer;
  R : TString;
Begin
  P := Pos(' ', Line);
  If P > 0 Then
  Begin
    R := Copy(Line, P + 1, Length(Line) - P);
    While (Length(R) > 0) And (R[1] = ' ') Do
      Delete(R, 1, 1);
    AsmGetOperands := R;
  End
  Else
    AsmGetOperands := '';
End;

Procedure AsmSplitOps(Const Ops : TString;
                      Var Op1, Op2 : TString);
Var
  P, D, I : Integer;
Begin
  { Split on comma that is not inside brackets }
  D := 0;
  P := 0;
  For I := 1 To Length(Ops) Do
  Begin
    If Ops[I] = '[' Then Inc(D);
    If Ops[I] = ']' Then Dec(D);
    If (Ops[I] = ',') And (D = 0) Then
    Begin
      P := I;
      Break;
    End;
  End;
  If P > 0 Then
  Begin
    Op1 := Copy(Ops, 1, P - 1);
    Op2 := Copy(Ops, P + 1, Length(Ops) - P);
    While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
      Delete(Op1, Length(Op1), 1);
    While (Length(Op2) > 0) And (Op2[1] = ' ') Do
      Delete(Op2, 1, 1);
  End
  Else
  Begin
    Op1 := Ops;
    Op2 := '';
  End;
End;

Function AsmExtractBracket(Const S : TString) : TString;
Var P1, P2 : Integer;
Begin
  P1 := Pos('[', S);
  P2 := Pos(']', S);
  If (P1 > 0) And (P2 > P1) Then
    AsmExtractBracket := Copy(S, P1 + 1, P2 - P1 - 1)
  Else
    AsmExtractBracket := '';
End;

Function AsmIsRegBased(Const Bracket : TString) : Boolean;
Var T : TString;
Begin
  T := Bracket;
  If Length(T) >= 3 Then
    T := Copy(T, 1, 3)
  Else
    T := '';
  AsmIsRegBased :=
    (T = 'EAX') Or (T = 'EBX') Or (T = 'ECX') Or (T = 'EDX') Or
    (T = 'ESI') Or (T = 'EDI') Or (T = 'ESP') Or (T = 'EBP');
End;

{ ------------------------------------------------------------ }
{ AsmEncodeMemory                                               }
{   Encode x86 ModRM/SIB for memory operands like [EBP-4]      }
{   Returns the reg field is passed in ARegField.               }
{   Emits ModRM + optional SIB + displacement into BinCode.     }
{   If not register-based, it is a direct label reference.      }
{   Returns True if it encoded something (register-based).      }
{ ------------------------------------------------------------ }

Function AsmEncodeMemory(Const Bracket : TString;
                         ARegField : Integer) : Boolean;
Var
  BaseReg   : TString;
  DispStr   : TString;
  Disp      : LongInt;
  BaseIdx   : Integer;
  P         : Integer;
  ModByte   : Byte;
Begin
  AsmEncodeMemory := False;
  If Length(Bracket) = 0 Then Exit;

  { Find base register }
  If Length(Bracket) >= 3 Then
    BaseReg := Copy(Bracket, 1, 3)
  Else
    Exit;

  BaseIdx := AsmRegIdx32(BaseReg);
  If BaseIdx < 0 Then Exit;

  AsmEncodeMemory := True;

  { Get displacement }
  DispStr := '';
  P := 4;
  If P <= Length(Bracket) Then
    DispStr := Copy(Bracket, P, Length(Bracket) - P + 1);

  { Remove leading whitespace from displacement }
  While (Length(DispStr) > 0) And (DispStr[1] = ' ') Do
    Delete(DispStr, 1, 1);

  If Length(DispStr) = 0 Then
    Disp := 0
  Else
    Disp := AsmParseImm(DispStr);

  { ESP needs SIB byte }
  If BaseIdx = 4 Then
  Begin
    { [ESP] or [ESP+disp] }
    If Disp = 0 Then
    Begin
      { ModRM: mod=00, reg=ARegField, r/m=100 (SIB) }
      BinEmitByte(Byte((ARegField Shl 3) Or $04));
      { SIB: scale=00, index=100(none), base=100(ESP) }
      BinEmitByte($24);
    End
    Else If (Disp >= -128) And (Disp <= 127) Then
    Begin
      BinEmitByte(Byte($44 Or (ARegField Shl 3)));
      BinEmitByte($24);
      BinEmitByte(Byte(Disp And $FF));
    End
    Else
    Begin
      BinEmitByte(Byte($84 Or (ARegField Shl 3)));
      BinEmitByte($24);
      BinEmitDWord(Disp);
    End;
  End
  Else If BaseIdx = 5 Then
  Begin
    { [EBP] or [EBP+disp] - EBP always needs disp }
    If (Disp >= -128) And (Disp <= 127) Then
    Begin
      BinEmitByte(Byte($45 Or (ARegField Shl 3)));
      BinEmitByte(Byte(Disp And $FF));
    End
    Else
    Begin
      BinEmitByte(Byte($85 Or (ARegField Shl 3)));
      BinEmitDWord(Disp);
    End;
  End
  Else
  Begin
    { Other registers }
    If Disp = 0 Then
    Begin
      ModByte := Byte((ARegField Shl 3) Or BaseIdx);
      BinEmitByte(ModByte);
    End
    Else If (Disp >= -128) And (Disp <= 127) Then
    Begin
      ModByte := Byte($40 Or (ARegField Shl 3) Or BaseIdx);
      BinEmitByte(ModByte);
      BinEmitByte(Byte(Disp And $FF));
    End
    Else
    Begin
      ModByte := Byte($80 Or (ARegField Shl 3) Or BaseIdx);
      BinEmitByte(ModByte);
      BinEmitDWord(Disp);
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ AsmEncodeInstr                                                }
{   Encode one assembly instruction into BinCode buffer.        }
{ ------------------------------------------------------------ }

Procedure AsmEncodeInstr(Const Line : TString);
Var
  Mnem, Ops, Op1, Op2 : TString;
  R1, R2              : Integer;
  Imm                 : LongInt;
  Bracket             : TString;
  LblName             : TString;
  Tmp                 : TString;
  P                   : Integer;
Begin
  Mnem := AsmGetMnemonic(Line);
  Ops := AsmGetOperands(Line);

  { -- Single-byte instructions -------------------------------- }
  If Mnem = 'RET' Then
  Begin
    If Length(Ops) > 0 Then
    Begin
      Imm := AsmParseImm(Ops);
      BinEmitByte($C2);
      BinEmitWord(Word(Imm));
    End
    Else
      BinEmitByte($C3);
    Exit;
  End;
  If Mnem = 'NOP' Then Begin BinEmitByte($90); Exit; End;
  If Mnem = 'CDQ' Then Begin BinEmitByte($99); Exit; End;
  If Mnem = 'CLD' Then Begin BinEmitByte($FC); Exit; End;
  If Mnem = 'LODSB' Then Begin BinEmitByte($AC); Exit; End;
  If Mnem = 'STOSB' Then Begin BinEmitByte($AA); Exit; End;
  If Mnem = 'MOVSB' Then Begin BinEmitByte($A4); Exit; End;
  If Mnem = 'PUSHAD' Then Begin BinEmitByte($60); Exit; End;
  If Mnem = 'POPAD' Then Begin BinEmitByte($61); Exit; End;

  { REP/REPNE prefixed instructions }
  If Mnem = 'REPNE' Then
  Begin
    { REPNE SCASB }
    BinEmitByte($F2);
    Tmp := AsmTrimLine(Ops);
    If Tmp = 'SCASB' Then
      BinEmitByte($AE);
    Exit;
  End;
  If Mnem = 'REP' Then
  Begin
    BinEmitByte($F3);
    Tmp := AsmTrimLine(Ops);
    If Tmp = 'MOVSB' Then BinEmitByte($A4)
    Else If Tmp = 'STOSB' Then BinEmitByte($AA);
    Exit;
  End;

  { -- PUSH ---------------------------------------------------- }
  If Mnem = 'PUSH' Then
  Begin
    R1 := AsmRegIdx32(Ops);
    If R1 >= 0 Then
    Begin
      BinEmitByte(Byte($50 + R1));
      Exit;
    End;
    { PUSH DWORD PTR [xxx] }
    If AsmStartsWith(Ops, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Ops);
      If AsmIsRegBased(Bracket) Then
      Begin
        BinEmitByte($FF);
        AsmEncodeMemory(Bracket, 6);
      End
      Else
      Begin
        { Push from global memory }
        BinEmitByte($FF);
        BinEmitByte($35);
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End;
      Exit;
    End;
    { PUSH OFFSET label }
    If AsmStartsWith(Ops, 'OFFSET ') Then
    Begin
      LblName := Copy(Ops, 8, Length(Ops) - 7);
      While (Length(LblName) > 0) And (LblName[1] = ' ') Do
        Delete(LblName, 1, 1);
      BinEmitByte($68);
      BinAddFixup(BinCodeLen, BFK_ABS32, LblName, True);
      BinEmitDWord(0);
      Exit;
    End;
    { PUSH immediate }
    Imm := AsmParseImm(Ops);
    If (Imm >= -128) And (Imm <= 127) Then
    Begin
      BinEmitByte($6A);
      BinEmitByte(Byte(Imm And $FF));
    End
    Else
    Begin
      BinEmitByte($68);
      BinEmitDWord(Imm);
    End;
    Exit;
  End;

  { -- POP ----------------------------------------------------- }
  If Mnem = 'POP' Then
  Begin
    R1 := AsmRegIdx32(Ops);
    If R1 >= 0 Then
      BinEmitByte(Byte($58 + R1));
    Exit;
  End;

  { -- CALL ---------------------------------------------------- }
  If Mnem = 'CALL' Then
  Begin
    { CALL DWORD PTR [_api@n] }
    If AsmStartsWith(Ops, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Ops);
      BinEmitByte($FF);
      BinEmitByte($15);
      BinAddFixup(BinCodeLen, BFK_IAT32, Bracket, True);
      BinEmitDWord(0);
      Exit;
    End;
    { CALL _api@n -> indirect call through IAT }
    If AsmFindAPI(Ops) >= 0 Then
    Begin
      BinEmitByte($FF);
      BinEmitByte($15);
      BinAddFixup(BinCodeLen, BFK_IAT32, Ops, True);
      BinEmitDWord(0);
      Exit;
    End;
    { CALL label (relative) }
    BinEmitByte($E8);
    BinAddFixup(BinCodeLen, BFK_REL32, Ops, True);
    BinEmitDWord(0);
    Exit;
  End;

  { -- JMP and conditional jumps ------------------------------- }
  If Mnem = 'JMP' Then
  Begin
    BinEmitByte($E9);
    BinAddFixup(BinCodeLen, BFK_REL32, Ops, True);
    BinEmitDWord(0);
    Exit;
  End;
  If (Mnem = 'JE') Or (Mnem = 'JZ') Then
  Begin
    BinEmitByte($0F); BinEmitByte($84);
    BinAddFixup(BinCodeLen, BFK_REL32, Ops, True);
    BinEmitDWord(0); Exit;
  End;
  If (Mnem = 'JNE') Or (Mnem = 'JNZ') Then
  Begin
    BinEmitByte($0F); BinEmitByte($85);
    BinAddFixup(BinCodeLen, BFK_REL32, Ops, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JG' Then
  Begin
    BinEmitByte($0F); BinEmitByte($8F);
    BinAddFixup(BinCodeLen, BFK_REL32, Ops, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JGE' Then
  Begin
    BinEmitByte($0F); BinEmitByte($8D);
    BinAddFixup(BinCodeLen, BFK_REL32, Ops, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JL' Then
  Begin
    BinEmitByte($0F); BinEmitByte($8C);
    BinAddFixup(BinCodeLen, BFK_REL32, Ops, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JLE' Then
  Begin
    BinEmitByte($0F); BinEmitByte($8E);
    BinAddFixup(BinCodeLen, BFK_REL32, Ops, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JA' Then
  Begin
    BinEmitByte($0F); BinEmitByte($87);
    BinAddFixup(BinCodeLen, BFK_REL32, Ops, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JAE' Then
  Begin
    BinEmitByte($0F); BinEmitByte($83);
    BinAddFixup(BinCodeLen, BFK_REL32, Ops, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JB' Then
  Begin
    BinEmitByte($0F); BinEmitByte($82);
    BinAddFixup(BinCodeLen, BFK_REL32, Ops, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JBE' Then
  Begin
    BinEmitByte($0F); BinEmitByte($86);
    BinAddFixup(BinCodeLen, BFK_REL32, Ops, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JS' Then
  Begin
    BinEmitByte($0F); BinEmitByte($88);
    BinAddFixup(BinCodeLen, BFK_REL32, Ops, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JNS' Then
  Begin
    BinEmitByte($0F); BinEmitByte($89);
    BinAddFixup(BinCodeLen, BFK_REL32, Ops, True);
    BinEmitDWord(0); Exit;
  End;

  { -- MOV ----------------------------------------------------- }
  If Mnem = 'MOV' Then
  Begin
    AsmSplitOps(Ops, Op1, Op2);

    { MOV DWORD PTR [mem],imm }
    If AsmStartsWith(Op1, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      { Check if src is a register }
      R2 := AsmRegIdx32(Op2);
      If R2 >= 0 Then
      Begin
        { MOV [mem],reg }
        BinEmitByte($89);
        If AsmIsRegBased(Bracket) Then
          AsmEncodeMemory(Bracket, R2)
        Else
        Begin
          BinEmitByte(Byte($05 Or (R2 Shl 3)));
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
        End;
        Exit;
      End;
      { MOV DWORD PTR [mem],imm32 }
      Imm := AsmParseImm(Op2);
      BinEmitByte($C7);
      If AsmIsRegBased(Bracket) Then
        AsmEncodeMemory(Bracket, 0)
      Else
      Begin
        BinEmitByte($05);
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End;
      BinEmitDWord(Imm);
      Exit;
    End;

    { MOV BYTE PTR [mem],reg8 or imm8 }
    If AsmStartsWith(Op1, 'BYTE PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      R2 := AsmRegIdx8(Op2);
      If R2 >= 0 Then
      Begin
        { MOV r/m8,r8 : opcode 88 /r }
        BinEmitByte($88);
        If AsmIsRegBased(Bracket) Then
          AsmEncodeMemory(Bracket, R2)
        Else
        Begin
          BinEmitByte(Byte($05 Or (R2 Shl 3)));
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
        End;
      End
      Else
      Begin
        { MOV r/m8,imm8 : opcode C6 /0 }
        Imm := AsmParseImm(Op2);
        BinEmitByte($C6);
        If AsmIsRegBased(Bracket) Then
          AsmEncodeMemory(Bracket, 0)
        Else
        Begin
          BinEmitByte($05);
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
        End;
        BinEmitByte(Byte(Imm And $FF));
      End;
      Exit;
    End;

    { MOV reg8,BYTE PTR [mem] }
    R1 := AsmRegIdx8(Op1);
    If (R1 >= 0) And (AsmStartsWith(Op2, 'BYTE PTR [')) Then
    Begin
      Bracket := AsmExtractBracket(Op2);
      BinEmitByte($8A);
      If AsmIsRegBased(Bracket) Then
        AsmEncodeMemory(Bracket, R1)
      Else
      Begin
        BinEmitByte(Byte($05 Or (R1 Shl 3)));
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End;
      Exit;
    End;

    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
    Begin
      { MOV reg,reg }
      R2 := AsmRegIdx32(Op2);
      If R2 >= 0 Then
      Begin
        BinEmitByte($89);
        BinEmitByte(Byte($C0 Or (R2 Shl 3) Or R1));
        Exit;
      End;
      { MOV reg,DWORD PTR [mem] }
      If AsmStartsWith(Op2, 'DWORD PTR [') Then
      Begin
        Bracket := AsmExtractBracket(Op2);
        BinEmitByte($8B);
        If AsmIsRegBased(Bracket) Then
          AsmEncodeMemory(Bracket, R1)
        Else
        Begin
          BinEmitByte(Byte($05 Or (R1 Shl 3)));
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
        End;
        Exit;
      End;
      { MOV reg,OFFSET label }
      If AsmStartsWith(Op2, 'OFFSET ') Then
      Begin
        LblName := Copy(Op2, 8, Length(Op2) - 7);
        While (Length(LblName) > 0) And (LblName[1] = ' ') Do
          Delete(LblName, 1, 1);
        BinEmitByte(Byte($B8 + R1));
        BinAddFixup(BinCodeLen, BFK_ABS32, LblName, True);
        BinEmitDWord(0);
        Exit;
      End;
      { MOV reg,[mem] without DWORD PTR prefix }
      If (Length(Op2) > 0) And (Op2[1] = '[') Then
      Begin
        Bracket := AsmExtractBracket(Op2);
        BinEmitByte($8B);
        If AsmIsRegBased(Bracket) Then
          AsmEncodeMemory(Bracket, R1)
        Else
        Begin
          BinEmitByte(Byte($05 Or (R1 Shl 3)));
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
        End;
        Exit;
      End;
      { MOV reg,imm32 }
      Imm := AsmParseImm(Op2);
      BinEmitByte(Byte($B8 + R1));
      BinEmitDWord(Imm);
      Exit;
    End;
    Exit;
  End;

  { -- LEA ----------------------------------------------------- }
  If Mnem = 'LEA' Then
  Begin
    AsmSplitOps(Ops, Op1, Op2);
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
    Begin
      Bracket := AsmExtractBracket(Op2);
      BinEmitByte($8D);
      If AsmIsRegBased(Bracket) Then
        AsmEncodeMemory(Bracket, R1)
      Else
      Begin
        BinEmitByte(Byte($05 Or (R1 Shl 3)));
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End;
    End;
    Exit;
  End;

  { -- ADD, SUB, AND, OR, XOR, CMP, TEST ---------------------- }
  If (Mnem = 'ADD') Or (Mnem = 'SUB') Or (Mnem = 'AND') Or
     (Mnem = 'OR') Or (Mnem = 'XOR') Or (Mnem = 'CMP') Or
     (Mnem = 'TEST') Then
  Begin
    AsmSplitOps(Ops, Op1, Op2);
    R1 := AsmRegIdx32(Op1);

    { ALU reg8,reg8 or reg8,imm8 }
    If R1 < 0 Then
    Begin
      R1 := AsmRegIdx8(Op1);
      If R1 >= 0 Then
      Begin
        R2 := AsmRegIdx8(Op2);
        If R2 >= 0 Then
        Begin
          { ALU reg8,reg8 }
          If Mnem = 'TEST' Then
          Begin
            BinEmitByte($84);
            BinEmitByte(Byte($C0 Or (R2 Shl 3) Or R1));
          End
          Else
          Begin
            If Mnem = 'CMP' Then BinEmitByte($38)
            Else If Mnem = 'ADD' Then BinEmitByte($00)
            Else If Mnem = 'SUB' Then BinEmitByte($28)
            Else If Mnem = 'AND' Then BinEmitByte($20)
            Else If Mnem = 'OR'  Then BinEmitByte($08)
            Else If Mnem = 'XOR' Then BinEmitByte($30);
            BinEmitByte(Byte($C0 Or (R2 Shl 3) Or R1));
          End;
          Exit;
        End;
        { ALU reg8,imm8 : opcode 80 /n ib }
        Imm := AsmParseImm(Op2);
        If Mnem = 'TEST' Then
        Begin
          BinEmitByte($F6);
          BinEmitByte(Byte($C0 Or R1));
        End
        Else
        Begin
          BinEmitByte($80);
          If Mnem = 'ADD' Then BinEmitByte(Byte($C0 Or R1))
          Else If Mnem = 'SUB' Then BinEmitByte(Byte($E8 Or R1))
          Else If Mnem = 'AND' Then BinEmitByte(Byte($E0 Or R1))
          Else If Mnem = 'OR'  Then BinEmitByte(Byte($C8 Or R1))
          Else If Mnem = 'XOR' Then BinEmitByte(Byte($F0 Or R1))
          Else If Mnem = 'CMP' Then BinEmitByte(Byte($F8 Or R1));
        End;
        BinEmitByte(Byte(Imm And $FF));
        Exit;
      End;

      { ALU BYTE PTR [mem],imm8 : opcode 80 /n ib }
      If AsmStartsWith(Op1, 'BYTE PTR [') Then
      Begin
        Bracket := AsmExtractBracket(Op1);
        Imm := AsmParseImm(Op2);
        If Mnem = 'TEST' Then
        Begin
          BinEmitByte($F6);
          R2 := 0;
        End
        Else
        Begin
          BinEmitByte($80);
          If Mnem = 'CMP' Then R2 := 7
          Else If Mnem = 'ADD' Then R2 := 0
          Else If Mnem = 'SUB' Then R2 := 5
          Else If Mnem = 'AND' Then R2 := 4
          Else If Mnem = 'OR'  Then R2 := 1
          Else If Mnem = 'XOR' Then R2 := 6
          Else R2 := 7;
        End;
        If AsmIsRegBased(Bracket) Then
          AsmEncodeMemory(Bracket, R2)
        Else
        Begin
          BinEmitByte(Byte($05 Or (R2 Shl 3)));
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
        End;
        BinEmitByte(Byte(Imm And $FF));
        Exit;
      End;
      Exit;
    End;

    If R1 >= 0 Then
    Begin
      R2 := AsmRegIdx32(Op2);
      If R2 >= 0 Then
      Begin
        { ALU reg,reg }
        If Mnem = 'TEST' Then
        Begin
          BinEmitByte($85);
          BinEmitByte(Byte($C0 Or (R2 Shl 3) Or R1));
        End
        Else
        Begin
          If Mnem = 'ADD' Then BinEmitByte($01)
          Else If Mnem = 'SUB' Then BinEmitByte($29)
          Else If Mnem = 'AND' Then BinEmitByte($21)
          Else If Mnem = 'OR'  Then BinEmitByte($09)
          Else If Mnem = 'XOR' Then BinEmitByte($31)
          Else If Mnem = 'CMP' Then BinEmitByte($39);
          BinEmitByte(Byte($C0 Or (R2 Shl 3) Or R1));
        End;
        Exit;
      End;

      { ALU reg,[mem] }
      If AsmStartsWith(Op2, 'DWORD PTR [') Or
         ((Length(Op2) > 0) And (Op2[1] = '[')) Then
      Begin
        Bracket := AsmExtractBracket(Op2);
        If Mnem = 'ADD' Then BinEmitByte($03)
        Else If Mnem = 'SUB' Then BinEmitByte($2B)
        Else If Mnem = 'AND' Then BinEmitByte($23)
        Else If Mnem = 'OR'  Then BinEmitByte($0B)
        Else If Mnem = 'XOR' Then BinEmitByte($33)
        Else If Mnem = 'CMP' Then BinEmitByte($3B)
        Else If Mnem = 'TEST' Then BinEmitByte($85);
        If AsmIsRegBased(Bracket) Then
          AsmEncodeMemory(Bracket, R1)
        Else
        Begin
          BinEmitByte(Byte($05 Or (R1 Shl 3)));
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
        End;
        Exit;
      End;

      { ALU reg,imm }
      Imm := AsmParseImm(Op2);
      If Mnem = 'TEST' Then
      Begin
        If R1 = 0 Then
        Begin
          BinEmitByte($A9);
          BinEmitDWord(Imm);
        End
        Else
        Begin
          BinEmitByte($F7);
          BinEmitByte(Byte($C0 Or R1));
          BinEmitDWord(Imm);
        End;
        Exit;
      End;
      If (Imm >= -128) And (Imm <= 127) Then
      Begin
        BinEmitByte($83);
        If Mnem = 'ADD' Then BinEmitByte(Byte($C0 Or R1))
        Else If Mnem = 'SUB' Then BinEmitByte(Byte($E8 Or R1))
        Else If Mnem = 'AND' Then BinEmitByte(Byte($E0 Or R1))
        Else If Mnem = 'OR'  Then BinEmitByte(Byte($C8 Or R1))
        Else If Mnem = 'XOR' Then BinEmitByte(Byte($F0 Or R1))
        Else If Mnem = 'CMP' Then BinEmitByte(Byte($F8 Or R1));
        BinEmitByte(Byte(Imm And $FF));
      End
      Else
      Begin
        If R1 = 0 Then
        Begin
          { Short form for EAX }
          If Mnem = 'ADD' Then BinEmitByte($05)
          Else If Mnem = 'SUB' Then BinEmitByte($2D)
          Else If Mnem = 'AND' Then BinEmitByte($25)
          Else If Mnem = 'OR'  Then BinEmitByte($0D)
          Else If Mnem = 'XOR' Then BinEmitByte($35)
          Else If Mnem = 'CMP' Then BinEmitByte($3D);
          BinEmitDWord(Imm);
        End
        Else
        Begin
          BinEmitByte($81);
          If Mnem = 'ADD' Then BinEmitByte(Byte($C0 Or R1))
          Else If Mnem = 'SUB' Then BinEmitByte(Byte($E8 Or R1))
          Else If Mnem = 'AND' Then BinEmitByte(Byte($E0 Or R1))
          Else If Mnem = 'OR'  Then BinEmitByte(Byte($C8 Or R1))
          Else If Mnem = 'XOR' Then BinEmitByte(Byte($F0 Or R1))
          Else If Mnem = 'CMP' Then BinEmitByte(Byte($F8 Or R1));
          BinEmitDWord(Imm);
        End;
      End;
      Exit;
    End;
    Exit;
  End;

  { -- INC, DEC, NEG, NOT ------------------------------------- }
  If Mnem = 'INC' Then
  Begin
    R1 := AsmRegIdx32(Ops);
    If R1 >= 0 Then
      BinEmitByte(Byte($40 + R1))
    Else If AsmStartsWith(Ops, 'DWORD PTR [') Or
            ((Length(Ops) > 0) And (Ops[1] = '[')) Then
    Begin
      Bracket := AsmExtractBracket(Ops);
      BinEmitByte($FF);
      If AsmIsRegBased(Bracket) Then
        AsmEncodeMemory(Bracket, 0)
      Else
      Begin
        BinEmitByte($05);
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End;
    End;
    Exit;
  End;
  If Mnem = 'DEC' Then
  Begin
    R1 := AsmRegIdx32(Ops);
    If R1 >= 0 Then
      BinEmitByte(Byte($48 + R1))
    Else If AsmStartsWith(Ops, 'DWORD PTR [') Or
            ((Length(Ops) > 0) And (Ops[1] = '[')) Then
    Begin
      Bracket := AsmExtractBracket(Ops);
      BinEmitByte($FF);
      If AsmIsRegBased(Bracket) Then
        AsmEncodeMemory(Bracket, 1)
      Else
      Begin
        BinEmitByte(Byte($05 Or (1 Shl 3)));
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End;
    End;
    Exit;
  End;
  If Mnem = 'NEG' Then
  Begin
    R1 := AsmRegIdx32(Ops);
    If R1 >= 0 Then
    Begin
      BinEmitByte($F7);
      BinEmitByte(Byte($D8 Or R1));
    End;
    Exit;
  End;
  If Mnem = 'NOT' Then
  Begin
    R1 := AsmRegIdx32(Ops);
    If R1 >= 0 Then
    Begin
      BinEmitByte($F7);
      BinEmitByte(Byte($D0 Or R1));
    End;
    Exit;
  End;

  { -- DIV, IDIV ----------------------------------------------- }
  If Mnem = 'DIV' Then
  Begin
    R1 := AsmRegIdx32(Ops);
    If R1 >= 0 Then
    Begin
      BinEmitByte($F7);
      BinEmitByte(Byte($F0 Or R1));
    End;
    Exit;
  End;
  If Mnem = 'IDIV' Then
  Begin
    R1 := AsmRegIdx32(Ops);
    If R1 >= 0 Then
    Begin
      BinEmitByte($F7);
      BinEmitByte(Byte($F8 Or R1));
    End;
    Exit;
  End;

  { -- IMUL ---------------------------------------------------- }
  If Mnem = 'IMUL' Then
  Begin
    AsmSplitOps(Ops, Op1, Op2);
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
    Begin
      If Length(Op2) = 0 Then
      Begin
        { Single-operand IMUL r32 }
        BinEmitByte($F7);
        BinEmitByte(Byte($E8 Or R1));
        Exit;
      End;
      { Check for 3-operand: IMUL reg,reg,imm }
      Tmp := Op2;
      P := Pos(',', Tmp);
      If P > 0 Then
      Begin
        { IMUL r1,r2,imm }
        R2 := AsmRegIdx32(Copy(Tmp, 1, P - 1));
        Imm := AsmParseImm(Copy(Tmp, P + 1, Length(Tmp) - P));
        If (Imm >= -128) And (Imm <= 127) Then
        Begin
          BinEmitByte($6B);
          BinEmitByte(Byte($C0 Or (R1 Shl 3) Or R2));
          BinEmitByte(Byte(Imm And $FF));
        End
        Else
        Begin
          BinEmitByte($69);
          BinEmitByte(Byte($C0 Or (R1 Shl 3) Or R2));
          BinEmitDWord(Imm);
        End;
        Exit;
      End;
      { IMUL r1,r2 }
      R2 := AsmRegIdx32(Op2);
      If R2 >= 0 Then
      Begin
        BinEmitByte($0F);
        BinEmitByte($AF);
        BinEmitByte(Byte($C0 Or (R1 Shl 3) Or R2));
      End;
    End;
    Exit;
  End;

  { -- SHL, SHR, SAR ------------------------------------------ }
  If (Mnem = 'SHL') Or (Mnem = 'SHR') Or (Mnem = 'SAR') Then
  Begin
    AsmSplitOps(Ops, Op1, Op2);
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
    Begin
      If Op2 = 'CL' Then
      Begin
        BinEmitByte($D3);
        If Mnem = 'SHL' Then BinEmitByte(Byte($E0 Or R1))
        Else If Mnem = 'SHR' Then BinEmitByte(Byte($E8 Or R1))
        Else BinEmitByte(Byte($F8 Or R1));
      End
      Else
      Begin
        Imm := AsmParseImm(Op2);
        If Imm = 1 Then
        Begin
          BinEmitByte($D1);
          If Mnem = 'SHL' Then BinEmitByte(Byte($E0 Or R1))
          Else If Mnem = 'SHR' Then BinEmitByte(Byte($E8 Or R1))
          Else BinEmitByte(Byte($F8 Or R1));
        End
        Else
        Begin
          BinEmitByte($C1);
          If Mnem = 'SHL' Then BinEmitByte(Byte($E0 Or R1))
          Else If Mnem = 'SHR' Then BinEmitByte(Byte($E8 Or R1))
          Else BinEmitByte(Byte($F8 Or R1));
          BinEmitByte(Byte(Imm And $FF));
        End;
      End;
    End;
    Exit;
  End;

  { -- SETcc --------------------------------------------------- }
  If AsmStartsWith(Mnem, 'SET') Then
  Begin
    R1 := AsmRegIdx8(Ops);
    If R1 < 0 Then R1 := 0;
    BinEmitByte($0F);
    If (Mnem = 'SETE') Or (Mnem = 'SETZ') Then
      BinEmitByte($94)
    Else If (Mnem = 'SETNE') Or (Mnem = 'SETNZ') Then
      BinEmitByte($95)
    Else If Mnem = 'SETG' Then BinEmitByte($9F)
    Else If Mnem = 'SETGE' Then BinEmitByte($9D)
    Else If Mnem = 'SETL' Then BinEmitByte($9C)
    Else If Mnem = 'SETLE' Then BinEmitByte($9E)
    Else If Mnem = 'SETA' Then BinEmitByte($97)
    Else If Mnem = 'SETB' Then BinEmitByte($92)
    Else BinEmitByte($94);
    BinEmitByte(Byte($C0 Or R1));
    Exit;
  End;

  { -- MOVZX -------------------------------------------------- }
  If Mnem = 'MOVZX' Then
  Begin
    AsmSplitOps(Ops, Op1, Op2);
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx8(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($0F);
      BinEmitByte($B6);
      BinEmitByte(Byte($C0 Or (R1 Shl 3) Or R2));
    End;
    Exit;
  End;

  { -- XCHG --------------------------------------------------- }
  If Mnem = 'XCHG' Then
  Begin
    AsmSplitOps(Ops, Op1, Op2);
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      If R1 = 0 Then
        BinEmitByte(Byte($90 + R2))
      Else If R2 = 0 Then
        BinEmitByte(Byte($90 + R1))
      Else
      Begin
        BinEmitByte($87);
        BinEmitByte(Byte($C0 Or (R1 Shl 3) Or R2));
      End;
    End;
    Exit;
  End;

  { Instruction not recognized - skip silently }
End;

{ ------------------------------------------------------------ }
{ AsmEncodeData                                                 }
{   Encode DB/DD data declarations in .DATA segment             }
{ ------------------------------------------------------------ }

Procedure AsmEncodeData(Const Line : TString);
Var
  Rest      : TString;
  Token     : TString;
  I, P      : Integer;
  Num       : LongInt;
  DupCount  : LongInt;
  Code      : Integer;
  IsDWord   : Boolean;
Begin
  { Format: LABEL DB ... or LABEL DD ... }
  { Find DB or DD }
  P := Pos(' DB ', Line);
  IsDWord := False;
  If P = 0 Then
  Begin
    P := Pos(' DD ', Line);
    IsDWord := True;
  End;
  If P = 0 Then Exit;

  Rest := Copy(Line, P + 4, Length(Line) - P - 3);
  While (Length(Rest) > 0) And (Rest[1] = ' ') Do
    Delete(Rest, 1, 1);

  { Parse data items separated by commas }
  While Length(Rest) > 0 Do
  Begin
    While (Length(Rest) > 0) And (Rest[1] = ' ') Do
      Delete(Rest, 1, 1);
    If Length(Rest) = 0 Then Break;

    { String literal "..." }
    If Rest[1] = '"' Then
    Begin
      I := 2;
      While (I <= Length(Rest)) And (Rest[I] <> '"') Do
        Inc(I);
      For P := 2 To I - 1 Do
      Begin
        If IsDWord Then
          BinEmitDataDWord(Ord(Rest[P]))
        Else
          BinEmitDataByte(Byte(Ord(Rest[P])));
      End;
      Delete(Rest, 1, I);
      If (Length(Rest) > 0) And (Rest[1] = ',') Then
        Delete(Rest, 1, 1);
      Continue;
    End;

    { Number or DUP }
    Token := '';
    While (Length(Rest) > 0) And (Rest[1] <> ',') Do
    Begin
      Token := Token + Rest[1];
      Delete(Rest, 1, 1);
    End;
    If (Length(Rest) > 0) And (Rest[1] = ',') Then
      Delete(Rest, 1, 1);

    { Trim token }
    While (Length(Token) > 0) And (Token[Length(Token)] = ' ') Do
      Delete(Token, Length(Token), 1);
    While (Length(Token) > 0) And (Token[1] = ' ') Do
      Delete(Token, 1, 1);

    { n DUP(0) }
    P := Pos(' DUP(', Token);
    If P = 0 Then P := Pos(' DUP (', Token);
    If P > 0 Then
    Begin
      Val(Copy(Token, 1, P - 1), DupCount, Code);
      If Code <> 0 Then DupCount := 0;
      For I := 1 To DupCount Do
      Begin
        If IsDWord Then
          BinEmitDataDWord(0)
        Else
          BinEmitDataByte(0);
      End;
      Continue;
    End;

    { Simple numeric value }
    If Length(Token) > 0 Then
    Begin
      Num := AsmParseImm(Token);
      If IsDWord Then
        BinEmitDataDWord(Num)
      Else
        BinEmitDataByte(Byte(Num And $FF));
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ AsmIsCodeData / AsmEncodeCodeData                             }
{   Handle DD/DB directives that appear in .CODE section        }
{   (alignment, embedded data tables)                           }
{ ------------------------------------------------------------ }

Function AsmIsCodeData(Const Line : TString) : Boolean;
Begin
  AsmIsCodeData := (Pos(' DD ', Line) > 0) Or
                   (Pos(' DB ', Line) > 0);
End;

Procedure AsmEncodeCodeData(Const Line : TString);
Var
  Rest    : TString;
  Token   : TString;
  P, I    : Integer;
  IsDWord : Boolean;
  Num     : LongInt;
  DupCount : LongInt;
  Code    : Integer;
Begin
  P := Pos(' DD ', Line);
  IsDWord := False;
  If P = 0 Then
  Begin
    P := Pos(' DB ', Line);
    IsDWord := False;
  End
  Else
    IsDWord := True;
  If P = 0 Then Exit;

  Rest := Copy(Line, P + 4, Length(Line) - P - 3);
  While (Length(Rest) > 0) And (Rest[1] = ' ') Do
    Delete(Rest, 1, 1);

  While Length(Rest) > 0 Do
  Begin
    While (Length(Rest) > 0) And (Rest[1] = ' ') Do
      Delete(Rest, 1, 1);
    If Length(Rest) = 0 Then Break;

    If Rest[1] = '"' Then
    Begin
      I := 2;
      While (I <= Length(Rest)) And (Rest[I] <> '"') Do
        Inc(I);
      For P := 2 To I - 1 Do
      Begin
        If IsDWord Then
          BinEmitDWord(Ord(Rest[P]))
        Else
          BinEmitByte(Byte(Ord(Rest[P])));
      End;
      Delete(Rest, 1, I);
      If (Length(Rest) > 0) And (Rest[1] = ',') Then
        Delete(Rest, 1, 1);
      Continue;
    End;

    Token := '';
    While (Length(Rest) > 0) And (Rest[1] <> ',') Do
    Begin
      Token := Token + Rest[1];
      Delete(Rest, 1, 1);
    End;
    If (Length(Rest) > 0) And (Rest[1] = ',') Then
      Delete(Rest, 1, 1);

    While (Length(Token) > 0) And (Token[Length(Token)] = ' ') Do
      Delete(Token, Length(Token), 1);
    While (Length(Token) > 0) And (Token[1] = ' ') Do
      Delete(Token, 1, 1);

    P := Pos(' DUP(', Token);
    If P = 0 Then P := Pos(' DUP (', Token);
    If P > 0 Then
    Begin
      Val(Copy(Token, 1, P - 1), DupCount, Code);
      If Code <> 0 Then DupCount := 0;
      For I := 1 To DupCount Do
      Begin
        If IsDWord Then BinEmitDWord(0)
        Else BinEmitByte(0);
      End;
      Continue;
    End;

    If Length(Token) > 0 Then
    Begin
      Num := AsmParseImm(Token);
      If IsDWord Then BinEmitDWord(Num)
      Else BinEmitByte(Byte(Num And $FF));
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ BinAssemble                                                   }
{   Read .ASM file and assemble into BinCode/BinData buffers    }
{ ------------------------------------------------------------ }

Procedure BinAssemble;
Var
  AsmF     : Text;
  RawLine  : TString;
  Line     : TString;
  LblName  : TString;
  InCode   : Boolean;
  InData   : Boolean;
Begin
  BinInit;
  InCode := False;
  InData := False;

  Assign(AsmF, AsmFileName);
  {$I-}
  Reset(AsmF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('CSCW32: Erreur: impossible d''ouvrir ', AsmFileName);
    Exit;
  End;

  While Not Eof(AsmF) Do
  Begin
    ReadLn(AsmF, RawLine);
    Line := AsmTrimLine(RawLine);
    If Length(Line) = 0 Then Continue;

    { Detect section boundaries }
    If (Line = '.CODE') Or (Line = '.code') Then
    Begin
      InCode := True;
      InData := False;
      BinInCode := True;
      Continue;
    End;
    If (Line = '.DATA') Or (Line = '.data') Then
    Begin
      InCode := False;
      InData := True;
      BinInCode := False;
      Continue;
    End;

    { Skip directives }
    If (Line = '.386') Or (Line = '.386p') Then Continue;
    If AsmStartsWith(Line, '.MODEL') Then Continue;
    If AsmStartsWith(Line, 'EXTRN') Then Continue;
    If AsmStartsWith(Line, 'PUBLIC') Then Continue;
    If AsmStartsWith(Line, 'END ') Then Continue;
    If Line = 'END' Then Continue;

    { Labels }
    If AsmIsLabel(Line) Then
    Begin
      LblName := AsmExtractLabel(Line);
      If InCode Then
        BinAddLabel(LblName, BinCodeLen)
      Else If InData Then
        BinAddLabel(LblName, BinDataLen);
      Continue;
    End;

    { Code section }
    If InCode Then
    Begin
      { Check for DB/DD in code section }
      If AsmIsCodeData(Line) Then
      Begin
        If (Pos(' DB ', Line) > 0) Or (Pos(' DD ', Line) > 0) Then
        Begin
          { Label is the first word if it has DB/DD after }
          If (Pos(' DB ', Line) > 0) Then
            LblName := Copy(Line, 1, Pos(' DB ', Line) - 1)
          Else
            LblName := Copy(Line, 1, Pos(' DD ', Line) - 1);
          While (Length(LblName) > 0) And
                (LblName[Length(LblName)] = ' ') Do
            Delete(LblName, Length(LblName), 1);
          If (Length(LblName) > 0) And (LblName[1] <> '.') And
             (LblName[1] <> 'E') Then
            BinAddLabel(LblName, BinCodeLen);
        End;
        AsmEncodeCodeData(Line);
      End
      Else
        AsmEncodeInstr(Line);
      Continue;
    End;

    { Data section }
    If InData Then
    Begin
      { Data lines: LABEL DB/DD ... }
      If (Pos(' DB ', Line) > 0) Or (Pos(' DD ', Line) > 0) Then
      Begin
        If Pos(' DB ', Line) > 0 Then
          LblName := Copy(Line, 1, Pos(' DB ', Line) - 1)
        Else
          LblName := Copy(Line, 1, Pos(' DD ', Line) - 1);
        While (Length(LblName) > 0) And
              (LblName[Length(LblName)] = ' ') Do
          Delete(LblName, Length(LblName), 1);
        If Length(LblName) > 0 Then
          BinAddLabel(LblName, BinDataLen);
        AsmEncodeData(Line);
      End;
      Continue;
    End;
  End;

  Close(AsmF);

  If Opts.Verbose Then
  Begin
    WriteLn('CSCW32: Assemble: ', BinCodeLen, ' octets de code, ',
            BinDataLen, ' octets de donnees.');
    WriteLn('CSCW32: Labels: ', BinLblCount, ', Fixups: ', BinFixCount);
  End;
End;

{ ------------------------------------------------------------ }
{ BinResolveFixups                                              }
{   Resolve all fixups with final RVAs and IAT offsets          }
{ ------------------------------------------------------------ }

Procedure BinResolveFixups(TextRVA, DataRVA, IdataRVA,
                           IatOfs : LongInt);
Var
  I            : Integer;
  LblIdx       : LongInt;
  TargetVA     : LongInt;
  FixOfs       : LongInt;
  ApiIdx       : Integer;
  IsInCode     : Boolean;
  RelVal       : LongInt;
Begin
  For I := 0 To BinFixCount - 1 Do
  Begin
    FixOfs := BinFixups[I].Offset;
    IsInCode := BinFixups[I].InCode;

    Case BinFixups[I].Kind Of
      BFK_ABS32 :
      Begin
        LblIdx := BinFindLabel(BinFixups[I].Target);
        If LblIdx >= 0 Then
        Begin
          If BinLabels[LblIdx].InCode Then
            TargetVA := PE_IMG_BASE + TextRVA +
                        BinLabels[LblIdx].Offset
          Else
            TargetVA := PE_IMG_BASE + DataRVA +
                        BinLabels[LblIdx].Offset;
          { Patch in the correct buffer }
          If IsInCode Then
          Begin
            BinCode[FixOfs]     := Byte(TargetVA And $FF);
            BinCode[FixOfs + 1] := Byte((TargetVA Shr 8) And $FF);
            BinCode[FixOfs + 2] := Byte((TargetVA Shr 16) And $FF);
            BinCode[FixOfs + 3] := Byte((TargetVA Shr 24) And $FF);
          End
          Else
          Begin
            BinData[FixOfs]     := Byte(TargetVA And $FF);
            BinData[FixOfs + 1] := Byte((TargetVA Shr 8) And $FF);
            BinData[FixOfs + 2] := Byte((TargetVA Shr 16) And $FF);
            BinData[FixOfs + 3] := Byte((TargetVA Shr 24) And $FF);
          End;
        End;
      End;

      BFK_REL32 :
      Begin
        LblIdx := BinFindLabel(BinFixups[I].Target);
        If LblIdx >= 0 Then
        Begin
          { REL32 is always code-to-code }
          TargetVA := BinLabels[LblIdx].Offset;
          RelVal := TargetVA - (FixOfs + 4);
          BinCode[FixOfs]     := Byte(RelVal And $FF);
          BinCode[FixOfs + 1] := Byte((RelVal Shr 8) And $FF);
          BinCode[FixOfs + 2] := Byte((RelVal Shr 16) And $FF);
          BinCode[FixOfs + 3] := Byte((RelVal Shr 24) And $FF);
        End;
      End;

      BFK_IAT32 :
      Begin
        ApiIdx := AsmFindAPI(BinFixups[I].Target);
        If ApiIdx >= 0 Then
        Begin
          TargetVA := PE_IMG_BASE + IdataRVA + IatOfs +
                      LongInt(ApiIdx) * 4;
          BinCode[FixOfs]     := Byte(TargetVA And $FF);
          BinCode[FixOfs + 1] := Byte((TargetVA Shr 8) And $FF);
          BinCode[FixOfs + 2] := Byte((TargetVA Shr 16) And $FF);
          BinCode[FixOfs + 3] := Byte((TargetVA Shr 24) And $FF);
        End;
      End;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ BinWriteObj                                                   }
{   Write a minimal COFF .OBJ file                              }
{ ------------------------------------------------------------ }

Procedure BinWriteObj;
Var
  F            : File;
  ObjFileName  : TString;
  NumSections  : Word;
  SymTableOfs  : LongInt;
  NumSymbols   : LongInt;
  TextSecOfs   : LongInt;
  DataSecOfs   : LongInt;
  TextRelocOfs : LongInt;
  DataRelocOfs : LongInt;
  TextRelocCnt : Word;
  DataRelocCnt : Word;
  HdrSize      : LongInt;
  I            : Integer;
  ZeroBuf      : Array[0..7] Of Byte;
  NameStr      : TString;
Begin
  ObjFileName := ReplaceExt(Opts.SrcFile, '.obj');

  NumSections := 2;
  TextRelocCnt := 0;
  DataRelocCnt := 0;

  { Count relocations }
  For I := 0 To BinFixCount - 1 Do
    If BinFixups[I].InCode Then
      Inc(TextRelocCnt)
    Else
      Inc(DataRelocCnt);

  { Layout: COFF header (20) + 2 section headers (40 each) = 100 }
  HdrSize := 20 + LongInt(NumSections) * 40;
  TextSecOfs := HdrSize;
  DataSecOfs := TextSecOfs + BinCodeLen;
  TextRelocOfs := DataSecOfs + BinDataLen;
  DataRelocOfs := TextRelocOfs + LongInt(TextRelocCnt) * 10;

  { Symbols: .text, .data, + each external API }
  NumSymbols := 2 + PE_NUM_API;
  SymTableOfs := DataRelocOfs + LongInt(DataRelocCnt) * 10;

  Assign(F, ObjFileName);
  Rewrite(F, 1);

  { COFF header }
  WriteBinWord(F, PE_MACHINE_I386);
  WriteBinWord(F, NumSections);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, SymTableOfs);
  WriteBinDWord(F, NumSymbols);
  WriteBinWord(F, 0);
  WriteBinWord(F, 0);

  { .text section header }
  WriteBinString(F, '.text');
  WriteBinZeros(F, 3);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, BinCodeLen);
  WriteBinDWord(F, TextSecOfs);
  WriteBinDWord(F, TextRelocOfs);
  WriteBinDWord(F, 0);
  WriteBinWord(F, TextRelocCnt);
  WriteBinWord(F, 0);
  WriteBinDWord(F, LongInt(PE_SCN_TEXT));

  { .data section header }
  WriteBinString(F, '.data');
  WriteBinZeros(F, 3);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, BinDataLen);
  WriteBinDWord(F, DataSecOfs);
  WriteBinDWord(F, DataRelocOfs);
  WriteBinDWord(F, 0);
  WriteBinWord(F, DataRelocCnt);
  WriteBinWord(F, 0);
  WriteBinDWord(F, LongInt(PE_SCN_BSS));

  { .text data }
  If BinCodeLen > 0 Then
    BlockWrite(F, BinCode, BinCodeLen);

  { .data data }
  If BinDataLen > 0 Then
    BlockWrite(F, BinData, BinDataLen);

  { Relocations for .text }
  For I := 0 To BinFixCount - 1 Do
    If BinFixups[I].InCode Then
    Begin
      WriteBinDWord(F, BinFixups[I].Offset);
      If BinFixups[I].Kind = BFK_REL32 Then
      Begin
        WriteBinDWord(F, 0);
        WriteBinWord(F, COFF_RELOC_REL32);
      End
      Else
      Begin
        WriteBinDWord(F, 0);
        WriteBinWord(F, COFF_RELOC_DIR32);
      End;
    End;

  { Relocations for .data }
  For I := 0 To BinFixCount - 1 Do
    If Not BinFixups[I].InCode Then
    Begin
      WriteBinDWord(F, BinFixups[I].Offset);
      WriteBinDWord(F, 0);
      WriteBinWord(F, COFF_RELOC_DIR32);
    End;

  { Symbol table (minimal) }
  FillChar(ZeroBuf, SizeOf(ZeroBuf), 0);

  { Symbol 0: .text }
  WriteBinString(F, '.text');
  WriteBinZeros(F, 3);
  WriteBinDWord(F, 0);
  WriteBinWord(F, 1);
  WriteBinWord(F, 0);
  WriteBinByte(F, 3);
  WriteBinByte(F, 1);

  { Symbol 1: .data }
  WriteBinString(F, '.data');
  WriteBinZeros(F, 3);
  WriteBinDWord(F, 0);
  WriteBinWord(F, 2);
  WriteBinWord(F, 0);
  WriteBinByte(F, 3);
  WriteBinByte(F, 1);

  { External API symbols }
  For I := 0 To PE_NUM_API - 1 Do
  Begin
    NameStr := BinAPIDecorated[I];
    If Length(NameStr) <= 8 Then
    Begin
      WriteBinString(F, NameStr);
      WriteBinZeros(F, 8 - Length(NameStr));
    End
    Else
    Begin
      WriteBinDWord(F, 0);
      WriteBinDWord(F, 4 + I * 20);
    End;
    WriteBinDWord(F, 0);
    WriteBinWord(F, 0);
    WriteBinWord(F, 0);
    WriteBinByte(F, 2);
    WriteBinByte(F, 0);
  End;

  { String table (size + strings) }
  WriteBinDWord(F, 4);

  Close(F);

  WriteLn('CSCW32: OBJ genere -> ', ObjFileName);
End;

{ ------------------------------------------------------------ }
{ BinWriteExe                                                   }
{   Write a PE Win32 .EXE file                                  }
{ ------------------------------------------------------------ }

Procedure BinWriteExe;
Var
  F             : File;
  ExeFileName   : TString;
  TextRVA       : LongInt;
  DataRVA       : LongInt;
  IdataRVA      : LongInt;
  TextFileOfs   : LongInt;
  DataFileOfs   : LongInt;
  IdataFileOfs  : LongInt;
  TextFileSize  : LongInt;
  DataFileSize  : LongInt;
  IdataFileSize : LongInt;
  TextVSize     : LongInt;
  DataVSize     : LongInt;
  IdataVSize    : LongInt;
  EntryRVA      : LongInt;
  LblIdx        : LongInt;
  ImageSize     : LongInt;
  SizeOfHeaders : LongInt;

  { Import table layout }
  IDTSize       : LongInt;
  ILTOfs        : LongInt;
  IATOfs        : LongInt;
  HintOfs       : LongInt;
  DllNameOfs    : LongInt;
  TotalIdata    : LongInt;

  { Pre-calculated hint RVAs }
  HintEntryOfs  : Array[0..PE_NUM_API - 1] Of LongInt;
  AccHint       : LongInt;

  I             : Integer;
  Pad           : LongInt;
  DosMsg        : String;
Begin
  ExeFileName := Opts.OutFile;

  { Section RVAs (aligned to PE_SEC_ALIGN = $1000) }
  SizeOfHeaders := $200;
  TextRVA := PE_SEC_ALIGN;
  TextFileSize := AlignUp(BinCodeLen, PE_FILE_ALIGN);
  TextVSize := BinCodeLen;

  DataRVA := TextRVA + AlignUp(BinCodeLen, PE_SEC_ALIGN);
  DataFileSize := AlignUp(BinDataLen, PE_FILE_ALIGN);
  DataVSize := BinDataLen;

  IdataRVA := DataRVA + AlignUp(BinDataLen, PE_SEC_ALIGN);

  { Build import table layout }
  { IDT: 1 entry + null terminator = 2 * 20 = 40 bytes }
  IDTSize := 40;
  { ILT: PE_NUM_API entries + null = (PE_NUM_API + 1) * 4 }
  ILTOfs := IDTSize;
  { IAT: same size as ILT }
  IATOfs := ILTOfs + (PE_NUM_API + 1) * 4;
  { DLL name }
  DllNameOfs := IATOfs + (PE_NUM_API + 1) * 4;
  { Hint/Name entries after DLL name (16 bytes for "kernel32.dll\0" + pad) }
  HintOfs := DllNameOfs + 16;

  { Pre-calculate hint entry offsets }
  AccHint := 0;
  For I := 0 To PE_NUM_API - 1 Do
  Begin
    HintEntryOfs[I] := AccHint;
    AccHint := AccHint + AlignUp(2 + Length(BinAPIName[I]) + 1, 2);
  End;

  TotalIdata := HintOfs + AccHint;
  IdataFileSize := AlignUp(TotalIdata, PE_FILE_ALIGN);
  IdataVSize := TotalIdata;

  { File offsets }
  TextFileOfs := SizeOfHeaders;
  DataFileOfs := TextFileOfs + TextFileSize;
  IdataFileOfs := DataFileOfs + DataFileSize;

  ImageSize := IdataRVA + AlignUp(TotalIdata, PE_SEC_ALIGN);

  { Find entry point }
  LblIdx := BinFindLabel('_CSC_ENTRY');
  If LblIdx >= 0 Then
    EntryRVA := TextRVA + BinLabels[LblIdx].Offset
  Else
    EntryRVA := TextRVA;

  { Resolve all fixups }
  BinResolveFixups(TextRVA, DataRVA, IdataRVA, IATOfs);

  { Write EXE file }
  Assign(F, ExeFileName);
  Rewrite(F, 1);

  { ---- DOS stub (128 bytes) ---- }
  { MZ header (64 bytes) }
  WriteBinWord(F, PE_DOS_MAGIC);     { 0x00 e_magic      }
  WriteBinWord(F, 128);              { 0x02 e_cblp        }
  WriteBinWord(F, 1);                { 0x04 e_cp          }
  WriteBinWord(F, 0);                { 0x06 e_crlc        }
  WriteBinWord(F, 4);                { 0x08 e_cparhdr     }
  WriteBinWord(F, 0);                { 0x0A e_minalloc    }
  WriteBinWord(F, $FFFF);            { 0x0C e_maxalloc    }
  WriteBinWord(F, 0);                { 0x0E e_ss          }
  WriteBinWord(F, $B8);              { 0x10 e_sp          }
  WriteBinWord(F, 0);                { 0x12 e_csum        }
  WriteBinWord(F, 0);                { 0x14 e_ip          }
  WriteBinWord(F, 0);                { 0x16 e_cs          }
  WriteBinWord(F, $40);              { 0x18 e_lfarlc      }
  WriteBinWord(F, 0);                { 0x1A e_ovno        }
  WriteBinZeros(F, 8);               { 0x1C e_res[4]      }
  WriteBinWord(F, 0);                { 0x24 e_oemid       }
  WriteBinWord(F, 0);                { 0x26 e_oeminfo     }
  WriteBinZeros(F, 20);              { 0x28 e_res2[10]    }
  WriteBinDWord(F, $80);             { 0x3C e_lfanew      }

  { DOS stub program at offset 0x40 }
  WriteBinByte(F, $0E);
  WriteBinByte(F, $1F);
  WriteBinByte(F, $BA);
  WriteBinWord(F, $000E);
  WriteBinByte(F, $B4);
  WriteBinByte(F, $09);
  WriteBinByte(F, $CD);
  WriteBinByte(F, $21);
  WriteBinByte(F, $B8);
  WriteBinWord(F, $4C01);
  WriteBinByte(F, $CD);
  WriteBinByte(F, $21);
  DosMsg := 'This program cannot be run in DOS mode.'#13#13#10'$';
  WriteBinString(F, DosMsg);
  Pad := 128 - 64 - 14 - Length(DosMsg);
  If Pad > 0 Then
    WriteBinZeros(F, Pad);

  { ---- PE signature ---- }
  WriteBinDWord(F, PE_PE_SIG);

  { ---- COFF file header (20 bytes) ---- }
  WriteBinWord(F, PE_MACHINE_I386);
  WriteBinWord(F, 3);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinWord(F, PE_OPT_SIZE);
  WriteBinWord(F, $0103);

  { ---- Optional header PE32 (224 bytes) ---- }
  WriteBinWord(F, PE_MAGIC_32);
  WriteBinByte(F, 1);
  WriteBinByte(F, 0);
  WriteBinDWord(F, TextFileSize);
  WriteBinDWord(F, DataFileSize + IdataFileSize);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, EntryRVA);
  WriteBinDWord(F, TextRVA);
  WriteBinDWord(F, DataRVA);

  WriteBinDWord(F, PE_IMG_BASE);
  WriteBinDWord(F, PE_SEC_ALIGN);
  WriteBinDWord(F, PE_FILE_ALIGN);
  WriteBinWord(F, 4); WriteBinWord(F, 0);
  WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinWord(F, 4); WriteBinWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, ImageSize);
  WriteBinDWord(F, SizeOfHeaders);
  WriteBinDWord(F, 0);
  WriteBinWord(F, PE_SUBSYS_CUI);
  WriteBinWord(F, 0);
  WriteBinDWord(F, $100000);
  WriteBinDWord(F, $1000);
  WriteBinDWord(F, $100000);
  WriteBinDWord(F, $1000);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 16);

  { Data directories (16 entries) }
  WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  WriteBinDWord(F, IdataRVA); WriteBinDWord(F, IDTSize);
  For I := 2 To 11 Do
  Begin WriteBinDWord(F, 0); WriteBinDWord(F, 0); End;
  WriteBinDWord(F, IdataRVA + IATOfs);
  WriteBinDWord(F, (PE_NUM_API + 1) * 4);
  For I := 13 To 15 Do
  Begin WriteBinDWord(F, 0); WriteBinDWord(F, 0); End;

  { ---- Section headers ---- }
  { .text }
  WriteBinString(F, '.text');
  WriteBinZeros(F, 3);
  WriteBinDWord(F, TextVSize);
  WriteBinDWord(F, TextRVA);
  WriteBinDWord(F, TextFileSize);
  WriteBinDWord(F, TextFileOfs);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinDWord(F, LongInt(PE_SCN_TEXT));

  { .data }
  WriteBinString(F, '.data');
  WriteBinZeros(F, 3);
  WriteBinDWord(F, DataVSize);
  WriteBinDWord(F, DataRVA);
  WriteBinDWord(F, DataFileSize);
  WriteBinDWord(F, DataFileOfs);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinDWord(F, LongInt(PE_SCN_BSS));

  { .idata }
  WriteBinString(F, '.idata');
  WriteBinZeros(F, 2);
  WriteBinDWord(F, IdataVSize);
  WriteBinDWord(F, IdataRVA);
  WriteBinDWord(F, IdataFileSize);
  WriteBinDWord(F, IdataFileOfs);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinDWord(F, LongInt(PE_SCN_BSS));

  { Pad headers to SizeOfHeaders }
  Pad := SizeOfHeaders - (128 + 4 + 20 + PE_OPT_SIZE + 3 * 40);
  If Pad > 0 Then
    WriteBinZeros(F, Pad);

  { ---- .text section ---- }
  If BinCodeLen > 0 Then
    BlockWrite(F, BinCode, BinCodeLen);
  Pad := TextFileSize - BinCodeLen;
  If Pad > 0 Then WriteBinZeros(F, Pad);

  { ---- .data section ---- }
  If BinDataLen > 0 Then
    BlockWrite(F, BinData, BinDataLen);
  Pad := DataFileSize - BinDataLen;
  If Pad > 0 Then WriteBinZeros(F, Pad);

  { ---- .idata section ---- }
  { Import Directory Table: kernel32.dll entry + null terminator }
  WriteBinDWord(F, IdataRVA + ILTOfs);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, IdataRVA + DllNameOfs);
  WriteBinDWord(F, IdataRVA + IATOfs);
  WriteBinZeros(F, 20);

  { ILT (Import Lookup Table) }
  For I := 0 To PE_NUM_API - 1 Do
    WriteBinDWord(F, IdataRVA + HintOfs + HintEntryOfs[I]);
  WriteBinDWord(F, 0);

  { IAT (Import Address Table) - same as ILT before loading }
  For I := 0 To PE_NUM_API - 1 Do
    WriteBinDWord(F, IdataRVA + HintOfs + HintEntryOfs[I]);
  WriteBinDWord(F, 0);

  { DLL name: "kernel32.dll" + null, padded to 16 bytes }
  WriteBinString(F, 'kernel32.dll');
  WriteBinByte(F, 0);
  WriteBinZeros(F, 3);

  { Hint/Name table }
  For I := 0 To PE_NUM_API - 1 Do
  Begin
    WriteBinWord(F, Word(I));
    WriteBinString(F, BinAPIName[I]);
    WriteBinByte(F, 0);
    If ((2 + Length(BinAPIName[I]) + 1) Mod 2) <> 0 Then
      WriteBinByte(F, 0);
  End;

  { Pad .idata to file alignment }
  Pad := IdataFileSize - TotalIdata;
  If Pad > 0 Then WriteBinZeros(F, Pad);

  Close(F);

  WriteLn('CSCW32: EXE genere -> ', ExeFileName,
          ' (', TextFileOfs + TextFileSize + DataFileSize +
                IdataFileSize, ' octets)');
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
  WriteLn('Methodes         : ', MethodCount);
  WriteLn('Classes          : ', ClassCount);
  WriteLn('Namespaces       : ', NsCount);
  WriteLn('Tableaux         : ', ArrayCount);
  WriteLn('Ops chaines      : ', StringOpCount);
  WriteLn('Ops Console      : ', ConsoleOpCount);
  WriteLn('Goto             : ', GotoCount);
  WriteLn('Cast/typeof/sizeof: ', CastCount);
  WriteLn('Runtime helpers   : ', RuntimeHelpCount);
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
  MethRetType: TString;       { type de retour de la methode (TODO 16) }
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

  { Initialiser la pile de boucles (TODO 14) }
  LoopDepth := 0;

  { Initialiser la pile de switch (TODO 15) }
  SwitchDepth := 0;

  { Initialiser la table des methodes (TODO 16) }
  MethodCount := 0;
  MethExitLbl := '';

  { Initialiser la table des classes (TODO 17) }
  ClassCount := 0;
  CurClassName := '';

  { Initialiser la table des namespaces (TODO 18) }
  NsCount   := 0;
  CurNsName := '';
  NsDepth   := 0;

  { Initialiser les tableaux (TODO 19) }
  ArrayCount       := 0;
  PendingIsArray   := False;
  LastNewArraySize := 0;

  { Initialiser les operations sur les chaines (TODO 20) }
  CurExprType      := TY_IDX_INT;
  StringOpCount    := 0;

  { Initialiser les entrees/sorties Console (TODO 21) }
  ConsoleOpCount   := 0;

  { Initialiser goto / labels utilisateur (TODO 22) }
  GotoCount        := 0;
  GotoLabelCount   := 0;

  { Initialiser cast/typeof/sizeof (TODO 23) }
  CastCount        := 0;

  { Initialiser le runtime Win32 (TODO 24) }
  RuntimeHelpCount := 0;

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
  NsName      := '';
  ClsName     := '';
  MethName    := '';
  MethExitLbl := '';
  InClass     := False;
  InMethod    := False;
  BraceDepth  := 0;
  ClassDepth  := 0;
  MethDepth   := 0;

  { Ouvrir le fichier ASM et emettre l en-tete + segment .CODE    }
  { AVANT la boucle principale : le code est emis pendant le scan }
  EmitOpen;
  EmitHeader;
  EmitCodeSeg;

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
    { Reconnaitre les declarations namespace (TODO 18) }
    Else If TokIsKw('namespace') Then
    Begin
      Consume;
      ParseNamespaceDecl;
    End
    { Reconnaitre les declarations class (TODO 17) }
    Else If TokIsKw('class') Then
    Begin
      Consume;
      ParseClassDecl;
    End
    { Reconnaitre les qualificateurs de visibilite avant class }
    Else If (TokIsKw('public') Or TokIsKw('private') Or
             TokIsKw('protected') Or TokIsKw('internal')) Then
    Begin
      Consume; { ignorer la visibilite, sous-ensemble minimal }
      { Si suivi de class -> ParseClassDecl }
      If TokIsKw('class') Then
      Begin
        Consume;
        ParseClassDecl;
      End
      { Si suivi de static -> c est un champ/methode hors classe }
      Else If TokIsKw('static') Then
      Begin
        { Le code existant pour static gerera le reste }
        { On ne consomme pas, la branche static ci-dessous le fera }
      End;
    End
    { Reconnaitre les accolades pour la gestion des scopes }
    Else If TokIsPunct('{') Then
    Begin
      Inc(BraceDepth);
      SymEnterScope;
      Consume;
      { Si c est l accolade ouvrante d une methode -> TODO 12 }
      If InMethod And (BraceDepth = MethDepth + 1) Then
      Begin
        EmitBlankLine;
        EmitComment('--- method ' + MethName + ' ---');
        EmitLabel(SymMangle(MethName, SC_METHOD));
        EmitProlog(METHOD_STACK_SIZE);
        MethExitLbl := GenLabel;
        ResetGotoLabels;  { TODO 22 }
        ParseMethodBody;
        EmitLabel(MethExitLbl);
        If StrLowerCase(MethName) = 'main' Then
        Begin
          EmitInstr('PUSH', '0');
          EmitInstr('CALL', '_ExitProcess@4');
        End;
        EmitEpilog;
        MethExitLbl := '';
        { Consommer accolade fermante et ajuster l etat }
        If TokIsPunct('}') Then
        Begin
          Dec(BraceDepth);
          SymLeaveScope;
          InMethod := False;
          Consume;
        End;
      End;
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
    { Reconnaitre static void/int/... Main/nom -> methode (TODO 16) }
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
          MethRetType := VarType;
          Consume;
          { Si suivi de ( -> c est une methode (TODO 16) }
          If TokIsPunct('(') Then
          Begin
            ParseMethodDecl(MethRetType, MethName);
            InMethod := True;
            MethDepth := BraceDepth;
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
          NsCount, ' namespaces, ',
          ClassCount, ' classes, ',
          MethodCount, ' methodes, ',
          DataCount, ' data)');

  { Emettre le point d entree et les routines runtime (TODO 24)   }
  EmitEntryPoint;
  EmitRuntimeHelpers;

  { Emettre le segment .DATA apres le code (TODO 12)             }
  { Le .DATA est emis apres le .CODE car toutes les chaines et   }
  { variables statiques doivent etre connues avant l emission.   }
  EmitDataSeg;
  EmitFooter;
  EmitClose;

  WriteLn('CSCW32: ASM genere -> ', AsmFileName);
  WriteLn('CSCW32: Runtime: ', RuntimeHelpCount, ' routines emises.');

  { Generation binaire (TODO 25) }
  BinAssemble;
  If Opts.ObjOnly Then
    BinWriteObj
  Else
    BinWriteExe;
  { Supprimer le fichier ASM temporaire si non demande }
  If Not Opts.AsmOutput Then
  Begin
    Assign(OutF, AsmFileName);
    {$I-}
    Erase(OutF);
    {$I+}
    If IOResult <> 0 Then;
  End;
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
