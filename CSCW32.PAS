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

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF
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

Begin
  WriteLn('CSCW32 - Compilateur C# (C Sharp) vers assembleur 80386 pour Windows 32 bits');
  WriteLn('Pas encore implemente. Voir les 25 TODOs dans le fichier source.');
End.
